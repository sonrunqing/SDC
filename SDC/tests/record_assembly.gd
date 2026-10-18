extends SceneTree
## Records actual model changes from the assembly screen; never buys the draft.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.call("_select_tab","workbench")
	await create_timer(0.3).timeout
	var catalog: Node = root.get_node("Catalog")
	var gun: String = str(scene.get("_draft_weapon"))
	var actions: Array = [{"slot":"", "id":""}]
	for slot: String in ["muzzle","optic","grip","stock","magazine","laser","handguard"]:
		var parts: Array = catalog.compatible_attachments(gun,slot)
		if not parts.is_empty(): actions.append({"slot":slot,"id":str(parts[0].id)})
	actions.append({"slot":"muzzle","id":""})
	var destination := "/workspace/scratch/assembly-frames"
	DirAccess.make_dir_recursive_absolute(destination)
	var frame: int = 0
	for action: Dictionary in actions:
		if str(action.slot) != "":
			if str(action.id) == "": scene.call("_draft_remove_part",str(action.slot))
			else: scene.call("_draft_choose_part",str(action.id))
		await process_frame
		for _index in range(7):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(destination+"/frame_%04d.png"%frame)
			frame += 1
			await create_timer(0.07).timeout
	print("ASSEMBLY_RECORD frames=",frame)
	quit()
