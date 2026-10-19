extends SceneTree
## The visible marker shares assisted direction, cover and category spread with firing.
var checks: int=0
var failures: int=0

func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)

func run() -> void:
	var state: Node=root.get_node("GameState")
	state.reset_progress()
	check(state.begin_raid(),"starter kit begins")
	var world: Node3D=load("res://scripts/raid_world.gd").new()
	root.add_child(world)
	world.start_raid()
	world.set_physics_process(false)
	for guard: Dictionary in world._guards:guard.hp=0.0
	var target: Dictionary=world._guards[0]
	target.hp=100.0
	target.body.position=world.player.position+Vector3(1,0,-10)
	world._aim_direction=Vector3.FORWARD
	await physics_frame
	await physics_frame
	var origin: Vector3=world.player.global_position+Vector3(0,.94,0)
	var expected: Vector3=world._assisted_direction(origin,world._aim_direction)
	check(expected.x>.02,"a visible offset guard activates aim assistance")
	world._update_aim_marker()
	var actual: Vector3=(Vector3(world.aim_indicator().point)-origin).normalized()
	check(actual.dot(expected)>.9999,"reticle follows the same assisted firing ray")
	var wall:=StaticBody3D.new()
	wall.position=world.player.position+Vector3(0,1,-4)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(3,2,1)
	shape.shape=box
	wall.add_child(shape)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	check(world._assisted_direction(origin,world._aim_direction).is_equal_approx(Vector3.FORWARD),"cover prevents assistance toward a hidden guard")
	world._update_aim_marker()
	check(Vector3(world.aim_indicator().point).distance_to(origin)<4.5,"reticle stops at the same cover")
	wall.queue_free()
	world._recoil=0.0
	world.player.velocity=Vector3.ZERO
	world._weapon_stats={"accuracy":100.0,"horizontal_recoil":0.0}
	state.loadout.weapon="weapon_boar12"
	check(is_equal_approx(world._shot_spread(),.09),"shotgun has its actual pellet spread minimum")
	check(is_equal_approx(float(world.aim_indicator().spread),world._shot_spread()),"visible shotgun spread reuses the firing calculation")
	state.loadout.weapon="weapon_reed9"
	check(world._shot_spread()<.09,"non-shotgun does not inherit the pellet minimum")
	world._recoil=.3
	check(world._shot_spread()>.09,"larger recoil is not clamped down to the minimum")
	world.queue_free()
	await process_frame
	print("AIM INDICATOR ","PASS" if failures==0 else "FAIL",": ",checks," checks")
	quit(0 if failures==0 else 1)
