extends Node
## Art capture using the production page and world. Uses an isolated save file.
func _ready() -> void:call_deferred("capture")
func capture() -> void:
	var destination: String="D:/aa/SDC-tools/previews/SDC-v0.4.9-search.png"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):destination=arg.trim_prefix("--out=")
	var window: Window=get_tree().root
	window.size=Vector2i(1280,720)
	window.content_scale_size=Vector2i(1280,720)
	DisplayServer.window_set_size(window.size)
	var state: Node=get_node("/root/GameState")
	state.save_path="user://art_capture_loot.json"
	state.reset_progress()
	var interface: Control=load("res://scripts/main.gd").new()
	add_child(interface)
	await get_tree().process_frame
	interface._deploy()
	var world: Node3D=interface._world
	world.set_physics_process(false)
	var at: Vector3=world._containers[0].position
	var path: Array=world._navigation_path(world.SPAWN,at)
	world.player.position=path[-1]
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not world._open_container(0):
		push_error("Cannot approach source for art capture")
		get_tree().quit(1)
		return
	for frame: int in range(100):
		world._update_search(.016)
		await get_tree().process_frame
	var page: Control=interface._loot_overlay
	page._refresh()
	for record: Dictionary in page._snapshot.records:
		if bool(record.discovered):page._choose(str(record.uid));break
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var result: Error=window.get_texture().get_image().save_png(destination)
	print("LOOT_ART_CAPTURE ",destination," result=",result)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
	get_tree().quit(result)
