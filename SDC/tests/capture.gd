extends SceneTree
## Visual QA harness. Run on a real or virtual display with isolated XDG_DATA_HOME.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var mode := "lobby"
	var destination := "/workspace/builds/sdc/lobby.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--output="):
			destination = argument.trim_prefix("--output=")
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = scene.instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(0.5).timeout
	if mode != "lobby":
		if main.has_method("capture_mode"):
			main.call("capture_mode", mode)
		else:
			push_error("Main.capture_mode missing for " + mode)
			quit(1)
			return
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(destination)
	print("CAPTURE ", mode, " result=", error, " path=", destination)
	quit(error)
