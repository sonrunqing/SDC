extends SceneTree
var checks:int=0
var failures:int=0
func _initialize() -> void:call_deferred("run")
func check(condition:bool,message:String) -> void:
	checks+=1
	if not condition:failures+=1;push_error(message)
func run() -> void:
	var state:Node=root.get_node("GameState");var catalog:Node=root.get_node("Catalog");state.reset_progress()
	var before:String=JSON.stringify([state.credits,state.stash,state.loadout,state.weapon_builds])
	var main:Control=load("res://scenes/main.tscn").instantiate();root.add_child(main);await process_frame
	check(str(main._tab)=="home","Application opens to the character lobby")
	check(main._bottom_nav.visible,"Main lobby has bottom system navigation")
	var body:Dictionary=main._home_preview.get_loadout_summary()
	check(body.armor.get("helmet")==state.loadout.helmet and body.armor.get("backpack")==state.loadout.backpack,"Lobby displays actual worn helmet and backpack")
	check(body.weapons.primary.id==state.loadout.primary,"Lobby holds the actual equipped modular gun")
	main._bottom_nav.get_node("StartAction").pressed.emit();await process_frame
	check(str(main._tab)=="maps","Start action opens map selection without deploying")
	check(not state.raid_active,"Map selection does not spend equipment or start a raid")
	var map_summary:Dictionary=main._map_preview.get_summary()
	check(float(map_summary.area_multiplier)>=10 and int(map_summary.model_types)>=70,"Map selector renders the real expanded detailed map")
	main._map_preview.focus_zone("terminal")
	check(float(main._map_preview._zoom)<100,"District selection opens a larger inspection view")
	main._select_tab("loadout");await process_frame
	check(str(main._tab)=="stash" and main._loadout_parent=="maps","Map preparation uses the shared equipment and stash")
	var inventory: Control=main._inventory_view
	var stash_view: Control=inventory._views.back()
	var grid_before: Rect2=stash_view.get_global_rect()
	check(not inventory._details.visible,"Idle inventory has no reserved detail window")
	var record: Dictionary={}
	for candidate: Dictionary in state.inventory_items:
		if str(candidate.container)=="stash":record=candidate;break
	var touch:=InputEventScreenTouch.new()
	touch.index=0;touch.position=stash_view.get_global_transform_with_canvas()*stash_view.record_rect(record).get_center();touch.pressed=true
	inventory._input(touch)
	touch.pressed=false;inventory._input(touch)
	await process_frame
	check(inventory._details.visible,"Raw single tap opens adjacent details")
	check(stash_view.get_global_rect().is_equal_approx(grid_before),"Details never resize or move the stash grid")
	main._mobile_back();await process_frame
	check(main._tab=="stash" and not inventory._details.visible,"System back closes only the item window first")
	main._go_back();check(str(main._tab)=="maps","Preparation returns to map selection")
	main._select_tab("market");await process_frame
	check(main._market_group.is_empty(),"Shop opens with distinct category choices")
	var weapons_button:Button=main._content.find_child("Category_weapons",true,false)
	check(weapons_button!=null,"Weapon category is a real clickable shop entry")
	weapons_button.pressed.emit();await process_frame
	check(main._market_group=="weapons","Shop category click opens weapon sublist")
	check(main._matches(catalog.get_item("weapon_reed9")) and not main._matches(catalog.get_item("ammo_9x19_fmj")),"Weapon category excludes ammo and other systems")
	main._filter="rifle";main._populate_list()
	check(main._matches(catalog.get_item("weapon_badger556")) and not main._matches(catalog.get_item("weapon_reed9")),"Weapon subcategories filter actual items")
	main._go_back();check(main._market_group.is_empty(),"Back from sublist returns to shop category hub")
	main._select_tab("home");await process_frame
	check(before==JSON.stringify([state.credits,state.stash,state.loadout,state.weapon_builds]),"Navigating and inspecting never mutates kit or credits")
	state.credits=100000
	var helmet_id:String=""
	for item:Dictionary in catalog.by_category("helmet"):
		if str(item.id)!=str(state.loadout.helmet):helmet_id=str(item.id);break
	check(state.buy(helmet_id) and state.equip(helmet_id),"A different helmet is bought and equipped using actual inventory APIs")
	await process_frame;await process_frame
	body=main._home_preview.get_loadout_summary()
	check(body.armor.helmet==helmet_id,"Lobby model synchronizes after an actual equipment change")
	for item:Dictionary in catalog.items.values():
		check(load("res://scripts/item_textures.gd").icon(str(item.id))!=null,"Real equipment icon or visual alias available: "+str(item.id))
	main._bottom_nav.get_node("StartAction").pressed.emit();await process_frame
	var entry_choice:Button=main._content.find_child("EntryChoice",true,false)
	entry_choice.select(2);entry_choice.item_selected.emit(2)
	check(main._entry_id=="west","Map dropdown selects the western entry")
	main._content.find_child("PrepareAction",true,false).pressed.emit();await process_frame
	check(main._tab=="stash","Visible map preparation button opens the shared equipment and stash")
	main._go_back();await process_frame
	check(main._tab=="maps","Back from preparation preserves the map route")
	main._bottom_nav.get_node("StartAction").pressed.emit();await physics_frame;await physics_frame
	check(state.raid_active and main._world!=null and main._world._active,"Visible preparation button starts a real raid")
	check(main._world.entry_position.is_equal_approx(Vector3(-68,0,55)),"Chosen UI entry is propagated to the actual raid")
	main._world._finish(false,"frontend test cleanup")
	await create_timer(1.15).timeout
	print("FRONTEND TESTS ","PASS" if failures==0 else "FAIL",": ",checks," checks; lobby, map, preparation, store hierarchy, equipped model")
	main.queue_free();await process_frame;await process_frame
	quit(0 if failures==0 else 1)
