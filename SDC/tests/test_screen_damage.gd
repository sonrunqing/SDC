extends SceneTree
## Calibrate against the real production camera; damage itself remains world-distance based.
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func _run() -> void:
	var catalog: Node = root.get_node("Catalog")
	var weapon_id: String = "weapon_reed9"
	var ammo_id: String = "ammo_9x19_fmj"
	var armor_factor: float = 1.0-clampf((22.0-float(catalog.get_item(ammo_id).penetration))/65.0,0,.72)
	var reference_distance: float = float(catalog.get_item(weapon_id).ballistics.screen_reference_distance)
	var screens: Array[Dictionary] = []
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1680,720)]:
		var view := SubViewport.new()
		view.size = resolution
		view.own_world_3d = true
		root.add_child(view)
		var world: Node3D = load("res://scripts/raid_world.gd").new()
		view.add_child(world)
		var player := CharacterBody3D.new()
		world.add_child(player)
		world.player = player
		world._build_camera()
		await process_frame
		var camera: Camera3D = world.camera
		var maximum: float = 0
		for point: Vector2 in [Vector2.ZERO,Vector2(resolution.x,0),Vector2(resolution),Vector2(0,resolution.y),Vector2(resolution.x*.5,0),Vector2(resolution.x,resolution.y*.5),Vector2(resolution.x*.5,resolution.y),Vector2(0,resolution.y*.5)]:
			var ray_origin: Vector3 = camera.project_ray_origin(point)
			var ray_direction: Vector3 = camera.project_ray_normal(point)
			var hit: Variant = Plane(Vector3.UP,.94).intersects_ray(ray_origin,ray_direction)
			check(hit is Vector3, "Camera edge ray reaches chest-height target plane")
			if not hit is Vector3: continue
			var distance: float = Vector3(0,.94,0).distance_to(hit)
			maximum = maxf(maximum,distance)
			var damage: float = catalog.shot_damage(weapon_id,ammo_id,distance)*armor_factor
			check(damage >= 20.5-.0001 and damage <=22.8, "Normal phone viewport stays within the requested 22.8 to 20.5 range")
		var worst_damage: float = catalog.shot_damage(weapon_id,ammo_id,maximum)*armor_factor
		screens.append({"width":resolution.x,"height":resolution.y,"farthest_visible_distance":maximum,"lowest_visible_damage":worst_damage})
		if resolution.x == 1680:
			check(is_equal_approx(maximum,reference_distance), "Balance reference matches the actual widest camera projection")
			check(is_equal_approx(worst_damage,20.5), "Farthest calibrated mobile screen corner deals 20.5")
		view.queue_free()
		await process_frame
	var curve: Array[Dictionary] = []
	for distance: float in [0,10,20,30,reference_distance,50,80,100]:
		curve.append({"distance":distance,"damage":catalog.shot_damage(weapon_id,ammo_id,distance)*armor_factor})
	var samples: Array[Dictionary] = []
	for distance: int in range(121):
		var damage: float = catalog.shot_damage(weapon_id,ammo_id,float(distance))*armor_factor
		var next_damage: float = catalog.shot_damage(weapon_id,ammo_id,float(distance+1))*armor_factor
		samples.append({"distance":distance,"damage":damage,"loss_next_metre":damage-next_damage})
	var report: Dictionary = {"camera_pose":"normal player follow", "reference_gun":weapon_id,"reference_ammo":ammo_id,"guard_armor":22,"near_damage":22.8,"screen_edge_damage":20.5,"screens":screens,"curve":curve,"samples":samples,"model":"accelerating power curve; no positive damage floor; stops at zero"}
	var path: String = ProjectSettings.globalize_path("res://docs/damage-curve-report.json")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	file.close()
	print("SCREEN DAMAGE TESTS ","PASS" if failures==0 else "FAIL",": ",checks," checks; 16:9,20:9,21:9 projected screen bounds ",screens)
	quit(0 if failures==0 else 1)
