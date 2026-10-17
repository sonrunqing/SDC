extends SceneTree
## Capture the shared map geometry for environment art review, without loading a save.
var harbor: Node3D
var camera: Camera3D

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	print("CAPTURE_USER_DATA ",OS.get_user_data_dir())
	root.size = Vector2i(1440,900)
	if "--raid" in OS.get_cmdline_user_args():
		await _capture_raid()
		return
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	harbor = load("res://scripts/harbor_map.gd").new()
	scene.add_child(harbor)
	harbor.build(false)
	# Overview cameras sit farther away than the raid camera's mobile draw range.
	for child: Node in harbor.get_children():
		if child is GeometryInstance3D: child.visibility_range_end = 0
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("778b98")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("c4d9df")
	sky.ambient_light_energy = .45
	sky.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = sky
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-30,0)
	sun.light_color = Color("fff0d5")
	sun.light_energy = .85
	sun.shadow_enabled = true
	scene.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 500
	scene.add_child(camera)
	camera.make_current()
	var destination := "D:/aa/SDC-tools/previews"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): destination = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(destination)
	var shots: Array = [
		["harbor_overview",Vector3(0,0,0),Vector3(80,160,120),205.0,Vector3(0,0,80)],
		["industrial_district",Vector3(-45,0,-23),Vector3(28,55,44),65.0,Vector3(0,0,80)],
		["warehouse_interior",Vector3(-54,0,-35),Vector3(11.5,26,20.5),25.0,Vector3(-55,0,-35)],
		["service_platform",Vector3(-41,1.5,-33),Vector3(12,12,17),17.0,Vector3(0,0,80)],
		["repair_interior",Vector3(-30,0,-37),Vector3(9,20,16),18.0,Vector3(-30,0,-37)],
		["parts_store",Vector3(-18,0,-36),Vector3(10,19,17),17.0,Vector3(-18,0,-36)],
		["loading_docks",Vector3(-56,0,-28),Vector3(12,16,18),23.0,Vector3(-55,0,-35)]]
	for shot: Array in shots:
		harbor.update_viewer_position(shot[4])
		camera.size = float(shot[3])
		camera.position = shot[1]+shot[2]
		camera.look_at(shot[1],Vector3.UP)
		await create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		var path: String = destination+"/"+str(shot[0])+".png"
		var error: Error = root.get_texture().get_image().save_png(path)
		print("ENVIRONMENT_CAPTURE ",path," result=",error)
	print("HARBOR_BUILD ",harbor.get_summary())
	quit()

func _capture_raid() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(.5).timeout
	main.capture_mode("raid")
	await create_timer(.5).timeout
	var world: Node3D = main._world
	world.player.position = Vector3(-55,.1,-33)
	world.camera.position = world._camera_focus()+world.CAMERA_OFFSET
	world.camera.look_at(world._camera_focus()+Vector3(0,.4,0))
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	var destination: String = "D:/aa/SDC-tools/previews"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): destination = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(destination)
	print("RAID_CAPTURE ",root.get_texture().get_image().save_png(destination+"/industrial_raid.png"))
	quit()
