extends SceneTree
var main:Control
var index:int=0
var directory:String="/workspace/scratch/sdc-v030-frontend-frames"
func _initialize() -> void:call_deferred("run")
func frames(count:int,orbit_map:bool=false) -> void:
	for frame:int in range(count):
		if orbit_map:
			main._map_preview._yaw+=.003
			main._map_preview._update_camera()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory+"/frame_%04d.png"%index)
		index+=1
		await create_timer(.05).timeout
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	await process_frame;await frames(24)
	main._bottom_nav.get_node("StartAction").pressed.emit();await process_frame;await frames(24,true)
	main._map_preview.focus_zone("terminal");await process_frame;await frames(24,true)
	main._content.find_child("PrepareAction",true,false).pressed.emit();await process_frame;await frames(24)
	main._select_tab("market");await process_frame;await frames(20)
	main._content.find_child("Category_weapons",true,false).pressed.emit();await process_frame;await frames(24)
	main._select_tab("workbench");await process_frame
	var gun:String=main._draft_weapon
	var catalog:Node=root.get_node("Catalog")
	var choices:Array=catalog.compatible_attachments(gun,"muzzle")
	main._draft_choose_part(str(choices[0].id));await process_frame;await frames(24)
	main._select_tab("home");await process_frame;await frames(16)
	print("FRONTEND_RECORD frames=",index)
	quit()
