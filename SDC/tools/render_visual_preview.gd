extends Node
## Art capture entrypoint. Run with a real rendering driver, never headless.
## Produces a source-rendered scene image; it does not simulate phone input.
const RaidWorld=preload("res://scripts/raid_world.gd")
func _ready() -> void:
	call_deferred("_capture")
func _capture() -> void:
	var destination: String="D:/aa/SDC-tools/previews/ashfront-port.png"
	var view: String="south"
	var aim:=Vector2.ZERO
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):destination=arg.trim_prefix("--out=")
		if arg.begins_with("--view="):view=arg.trim_prefix("--view=")
		if arg.begins_with("--aim="):
			var axes: PackedStringArray=arg.trim_prefix("--aim=").split(",")
			if axes.size()==2:aim=Vector2(float(axes[0]),float(axes[1])).limit_length(1)
	var root: Window=get_tree().root
	root.size=Vector2i(1600,900)
	root.content_scale_size=Vector2i(1600,900)
	DisplayServer.window_set_size(Vector2i(1600,900))
	var state: Node=root.get_node("GameState")
	state.save_path="user://art_capture_visual.json"
	state.reset_progress()
	state.begin_raid()
	var scene:=Node3D.new()
	root.add_child(scene)
	var world:=RaidWorld.new()
	scene.add_child(world)
	world.start_raid("south")
	# Freeze gameplay for an art capture; use the production scene builders.
	world.set_physics_process(false)
	if view=="warehouse":world.player.position=Vector3(-55,0,-35)
	if view=="road":world.player.position=Vector3(0,0,20)
	if view=="loot_near":
		var approach: Array=world._navigation_path(world.SPAWN,world._containers[0].position)
		world.player.position=approach[-1]
	world._focus=world._camera_focus()
	world._harbor.update_viewer_position(world.player.position)
	root.get_node("AppSettings").apply_scene(root)
	var interface: Control
	if view=="actor":
		world.set_process(false)
		world._presentation.hide()
		world.camera.position=world.player.position+Vector3(2.2,1.6,-3.5)
		world.camera.look_at(world.player.position+Vector3(0,1,0))
		world.player_model.tick_visual(Vector3(0,0,-2.5),true,.016)
	else:
		interface=load("res://scripts/main.gd").new()
		scene.add_child(interface)
		interface._world=world
		interface._lobby.hide()
		interface._hud.show()
		interface._controls.enabled=true
		# Pose the actual joystick artwork for this still, without emitting input.
		interface._controls._aim=aim
		interface._controls.queue_redraw()
		interface._update_hud(world.get_hud())
	world.set_aim(aim)
	for frame: int in range(90):
		if view!="actor":world._update_aim()
		world._update_interaction_target()
		if is_instance_valid(interface):interface._update_hud(world.get_hud())
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var error: Error=root.get_texture().get_image().save_png(destination)
	print("ART_CAPTURE ",destination," error=",error)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
	get_tree().quit(error)
