extends SceneTree
var checks: int=0
var failures: int=0
var state: Node
var world: Node3D
var _deadline: Timer

func _initialize() -> void:
	call_deferred("_watchdog")
	call_deferred("run")
func _watchdog() -> void:
	_deadline=Timer.new()
	_deadline.wait_time=45
	_deadline.one_shot=true
	root.add_child(_deadline)
	_deadline.timeout.connect(func() -> void:push_error("Container search check timed out");quit(1))
	_deadline.start()
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)

func total(id: String) -> int:
	return int(state.raid_loot.get(id,0))+int(state.raid_packed_extra.get(id,0))+int(state.raid_ammo_by_id.get(id,0))+(int(state.raid_medkits) if id==state.raid_medkit_id else 0)

func approach(index: int) -> bool:
	var at: Vector3=world._containers[index].position
	for radius: float in [1.2,1.8,2.1]:
		for direction: int in range(12):
			var candidate: Vector3=at+Vector3(sin(TAU*direction/12),0,cos(TAU*direction/12))*radius
			var path: Array=world._navigation_path(world.SPAWN,candidate)
			if path.is_empty() or Vector2(path[-1].x-candidate.x,path[-1].z-candidate.z).length()>.85:continue
			world.player.position=path[-1]
			if world._can_access_container(index):return true
	return false

func run() -> void:
	state=root.get_node("GameState")
	state.save_path="user://test_container_search.json"
	state.reset_progress()
	state.credits=100000
	check(state.buy("armored_rig_patrol",1) and state.equip("armored_rig_patrol"),"a plain rig is equipped through real inventory transactions")
	check(state.begin_raid(),"test loadout starts with reserved supplies")
	world=load("res://scripts/raid_world.gd").new()
	root.add_child(world)
	world.start_raid()
	world.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(world._containers.size()==26,"26 containers are organized into interior rooms")
	for index: int in range(world._containers.size()):
		var crate: Dictionary=world._containers[index]
		check(not str(crate.building).is_empty(),"every fixed loot point belongs to an enterable building")
		check(approach(index),"reachable line-of-sight approach: "+str(crate.name)+" "+str(crate.position))
	check(approach(0),"first source can be inspected")
	var before: String=JSON.stringify([state.raid_loot,state.raid_ammo_by_id,state.raid_grid_items])
	check(world._open_container(0),"opening enters container mode")
	check(world._ui_blocked and world._search_target==0,"container mode stops movement and firing")
	var source: Dictionary=world._containers[0]
	var uid: String=str(source.search.records[0].uid)
	check(not world.take_container_item(uid,1),"undiscovered items cannot be taken")
	check(JSON.stringify([state.raid_loot,state.raid_ammo_by_id,state.raid_grid_items])==before,"opening and hidden pickup attempts never award contents")
	world._update_search(.7)
	var elapsed: float=float(source.search.elapsed)
	world.toggle_container_search()
	world._update_search(2)
	check(is_equal_approx(float(source.search.elapsed),elapsed),"pause stops only the search timer")
	world.toggle_container_search()
	world._update_search(20)
	check(bool(world.get_container_snapshot().complete),"search reveals the stable item grid")
	check(state.raid_loot.is_empty(),"search completion still awards no loot")
	var saved: String=JSON.stringify(source.search.records)
	world.close_container()
	check(not world._ui_blocked and world._search_target==-1,"closing releases the gameplay block")
	check(world._open_container(0),"partly searched/full container can be reopened")
	check(JSON.stringify(source.search.records)==saved,"reopening preserves identities, positions and discovered state")
	var ammo: Dictionary={}
	for record: Dictionary in source.search.records:
		if str(root.get_node("Catalog").get_item(record.item).get("kind",""))=="ammo":ammo=record;break
	check(not ammo.is_empty(),"supply source contains a searchable ammo stack")
	if not ammo.is_empty():
		var id: String=str(ammo.item)
		var original: int=int(ammo.qty)
		var bag: int=total(id)
		check(world.take_container_item(str(ammo.uid),3),"only the selected ammo quantity transfers")
		check(int(ammo.qty)==original-3 and total(id)==bag+3,"source plus carried quantities are conserved")
		check(int(state.raid_ammo_by_id.get(id,0))>=3,"picked ammunition becomes usable reserve")
	var item: Dictionary=source.search.records[0]
	var untouched: String=JSON.stringify([source.contents,state.raid_loot,state.raid_grid_items])
	check(not world.take_container_item(str(item.uid),1,"stash"),"raid search cannot write directly into home storage")
	check(JSON.stringify([source.contents,state.raid_loot,state.raid_grid_items])==untouched,"a failed target changes neither source nor bag")
	var old_capacity: float=state.carry_capacity()
	state.raid_packed_extra["loot_statue"]=1000
	var failed: String=JSON.stringify([source.search.records,state.raid_grid_items,state.raid_loot])
	check(not world.take_container_item(str(item.uid),1),"overweight pickup is rejected")
	check(JSON.stringify([source.search.records,state.raid_grid_items,state.raid_loot])==failed,"overweight failure leaves the item in place")
	state.raid_packed_extra.erase("loot_statue")
	check(old_capacity==state.carry_capacity(),"pickup failures do not replace equipped containers")
	# Raw touch selection, release ownership and modal cancellation on real grids.
	var page: Control=load("res://scripts/ui_loot_search.gd").new()
	page.world=world
	root.add_child(page)
	await process_frame
	await process_frame
	page._refresh()
	var view: Control=page._source
	var at: Vector2=view.get_global_transform_with_canvas()*view.record_rect(item).get_center()
	var touch:=InputEventScreenTouch.new()
	touch.index=4;touch.position=at;touch.pressed=true
	page._input(touch)
	var other:=InputEventScreenTouch.new()
	other.index=7;other.position=at;other.pressed=false
	page._input(other)
	check(page._pointer==4,"another finger cannot release the owning search-grid pointer")
	touch.pressed=false
	page._input(touch)
	check(page._selected==str(item.uid),"a deliberate raw-touch release selects the revealed record")
	check(page._details.visible and page._details.body.get_child_count()>0,"selection opens real item data above the grids")
	page.cancel_gesture()
	check(page._pointer==-1 and page._last_tap.is_empty(),"modal cancellation clears pointers and pending double-tap chains")
	page.queue_free()
	world.close_container()
	# A horizontal source accessory must rotate into a vertical rig pocket.
	var accessory: String=""
	for id: String in root.get_node("Catalog").items:
		var definition: Dictionary=root.get_node("Catalog").get_item(id)
		if str(definition.get("category",""))=="suppressor" and state.Grid.item_size(id)==Vector2i(2,1):accessory=id;break
	check(not accessory.is_empty(),"catalog provides a real two-cell horizontal accessory")
	if not accessory.is_empty():
		world._add_loot_container(world.player.position,"rotation fixture",true)
		var fixture: Dictionary=world._containers.back()
		fixture.search=load("res://scripts/loot_container_state.gd").prepare({accessory:1},"rotation")
		fixture.contents={accessory:1}
		fixture.search.records[0].discovered=true
		var spot: Dictionary=state.Grid.find_spot({"uid":"incoming","item":accessory,"rotated":false},"rig",state.raid_grid_items,state.loadout)
		check(not spot.is_empty() and bool(spot.get("rotated",false)),"vertical rig blocks require smart orientation")
		check(world._open_container(world._containers.size()-1),"controlled accessory source opens")
		check(world.take_container_item(str(fixture.search.records[0].uid),1,"rig",str(spot.get("block",""))),"pickup fits the selected rig pocket")
		var rotated: bool=false
		for record: Dictionary in state.raid_grid_items:
			if str(record.item)==accessory and str(record.container)=="rig":rotated=bool(record.rotated)
		check(rotated,"the carried record uses the rotated footprint")
		world.close_container()
	await process_frame
	await process_frame
	# Exercise the actual main-page wiring and Android back path.
	var main: Control=load("res://scripts/main.gd").new()
	root.add_child(main)
	main._world=world
	main._lobby.hide()
	main._hud.show()
	main._controls.enabled=true
	world.container_opened.connect(main._show_loot_container)
	world.container_closed.connect(main._hide_loot_container)
	check(approach(1),"another indoor source can be reopened after closing")
	var fire:=InputEventScreenTouch.new()
	fire.index=19
	fire.position=main._controls.get_control_rects().get("fire",Rect2()).get_center()
	fire.pressed=true
	main._controls._input(fire)
	check(world._stick_firing,"the production fire control owns its pointer before opening")
	check(world._open_container(1),"opening another box succeeds")
	check(is_instance_valid(main._loot_overlay) and not main._controls.enabled and not world._stick_firing,"opening the real search page cancels the held fire pointer")
	main._mobile_back()
	check(world._search_target==-1 and main._controls.enabled,"Android back closes the source and restores controls")
	fire.pressed=false
	main._controls._input(fire)
	check(not world._stick_firing,"the old release cannot fire after the page closes")
	await process_frame
	await process_frame
	check(not is_instance_valid(main._loot_overlay),"the search page and its modal owner are removed")
	check(world._open_container(1),"a source can reopen after using Android back")
	world.player.position=world.SPAWN
	world._update_search(.1)
	check(world._search_target==-1 and not world._ui_blocked,"leaving the source automatically cancels searching")
	main.queue_free()
	world.queue_free()
	_deadline.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
	print("CONTAINER SEARCH ","PASS" if failures==0 else "FAIL",": ",checks," checks")
	quit(0 if failures==0 else 1)
