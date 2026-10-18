extends SceneTree
## Regression coverage for skinned equipment, death attachments, LOS and FX budget.
var failures: int=0
var checks: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error(message)

func _run() -> void:
	var state: Node=root.get_node("GameState")
	var original: String=JSON.stringify([state.loadout,state.stash,state.inventory_items,state.credits])
	var world: Node3D=load("res://scripts/raid_world.gd").new()
	root.add_child(world)
	world.start_raid("south")
	world.set_physics_process(false)
	var actor: Node3D=world.player_model
	check(actor._clips.size()>=17,"all original locomotion and one-shot clips import")
	check(actor._skeleton.get_bone_count()==20,"the source rig has twenty bones")
	for frame: int in range(4):await process_frame
	var weapon: Node3D=actor._held
	var hand: int=actor._skeleton.find_bone("Hand.R")
	var pose: Transform3D=actor._skeleton.global_transform*actor._skeleton.get_bone_global_pose(hand)
	check(weapon.global_position.distance_to(pose.origin)<.15,"held receiver remains within the grip calibration distance")
	check(weapon.global_basis.orthonormalized().is_equal_approx((pose.basis*actor._grip_basis).orthonormalized()),"weapon orientation follows the animated wrist with authored-axis calibration")
	actor._animation.play(actor._clips.aim,0)
	actor._animation.advance(0)
	actor._process(0)
	check((-weapon.global_basis.z.normalized()).dot(-actor.global_basis.z.normalized())>.99,"the calibrated aiming pose aligns the authored barrel with the gameplay aim")
	var guard: Node3D=world._guards[0].model
	var rifle: Node3D=guard._held
	check(rifle.find_child("MuzzlePoint",true,false)!=null,"guard effects use an authored muzzle")
	guard.die()
	for frame: int in range(8):await process_frame
	var guard_hand: int=guard._skeleton.find_bone("Hand.R")
	var death_pose: Transform3D=guard._skeleton.global_transform*guard._skeleton.get_bone_global_pose(guard_hand)
	check(rifle.global_position.distance_to(death_pose.origin)<.15,"death animation retains its weapon on the hand")
	# Use the clear spawn road, then place a physical wall across the same ray.
	world._guards[0].body.position=world.player.position+Vector3(0,0,-9)
	world._aim_direction=Vector3.FORWARD
	await physics_frame
	await physics_frame
	world._presentation._clock=0
	world._presentation._physics_process(.1)
	check(bool(world._guards[0].get("seen",false)),"an unobstructed target inside the vision cone is visible")
	var wall:=StaticBody3D.new()
	wall.collision_layer=1
	wall.position=world.player.position+Vector3(0,1.4,-4.5)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(5,2.8,1)
	shape.shape=box
	wall.add_child(shape)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	world._presentation._clock=0
	world._presentation._physics_process(.1)
	check(not bool(world._guards[0].get("seen",true)),"a solid wall hides the same target without hiding the whole world")
	wall.queue_free()
	var count: int=world._fx.get_child_count()
	for index: int in range(400):
		world._fx.tracer(Vector3(0,1,0),Vector3(0,1,-80),Color.WHITE,.05)
		world._fx.impact(Vector3(0,1,0),Color("ffc97a"),.08)
	check(world._fx.get_child_count()==count and count<=129,"sustained fire reuses a fixed effect-node budget")
	for effect: Dictionary in world._fx._pool:
		if float(effect.life)>.0:check(effect.node.scale.length()<27,"long ballistic rays cannot become screen-spanning beam meshes")
	check(JSON.stringify([state.loadout,state.stash,state.inventory_items,state.credits])==original,"visual scene construction conserves loadout and storage")
	world.queue_free()
	await process_frame
	await process_frame
	print("VISUAL PORT ","PASS" if failures==0 else "FAIL",": ",checks," checks")
	quit(0 if failures==0 else 1)
