extends SceneTree
var checks:int=0
var failures:int=0
func _initialize() -> void:call_deferred("run")
func check(condition:bool,message:String) -> void:
	checks+=1
	if not condition:failures+=1;push_error(message)
func run() -> void:
	var state:Node=root.get_node("GameState");state.reset_progress();state.begin_raid()
	var world:Node3D=load("res://scripts/raid_world.gd").new();root.add_child(world);world.start_raid();world.set_physics_process(false)
	var summary:Dictionary=world._harbor.get_summary()
	check(float(summary.area_multiplier)>=10,"Playable map area is at least ten times the old map")
	check(summary.bounds==[160.0,180.0],"Physical map dimensions match selection page")
	check(int(summary.model_types)>=70 and int(summary.objects)>=250,"Large map actually places dozens of distinct models")
	check(world._containers.size()>=27,"Expanded districts have distributed loot")
	check(world._guards.size()>=15,"Expanded districts have actual guards")
	check(world._nav.region.size==Vector2i(160,180),"Navigation covers the whole expanded map")
	for entry:Dictionary in world._harbor.layout.entries:
		var p:Vector3=Vector3(float(entry.position[0]),0,float(entry.position[2]))
		var path:Array=world._navigation_path(p,world.EXIT)
		check(not path.is_empty(),"Entry connects to extraction: "+str(entry.id))
		check(Vector2(path[0].x-p.x,path[0].z-p.z).length()<2,"Entry is not inside a physical obstruction: "+str(entry.id))
	for record:Dictionary in world._harbor.layout.loot:
		var p:Vector3=Vector3(float(record.position[0]),0,float(record.position[2]))
		var path:Array=world._navigation_path(world.SPAWN,p)
		check(not path.is_empty(),"Search box connects to entry "+str(record.position))
		if not path.is_empty():check(Vector2(path[-1].x-p.x,path[-1].z-p.z).length()<2,"Search box is reachable within interaction radius "+str(record.position))
	world.player.position=Vector3(54,0,81)
	await physics_frame;await physics_frame
	var excluded:Array[RID]=[world.player.get_rid()]
	var hit:Dictionary=world._ray(Vector3(54,.94,81),Vector3(54,.94,60),excluded)
	check(not hit.is_empty(),"A new distant district building has real bullet collision")
	var cell:Vector2i=world._walkable_cell(Vector2i(0,65))
	check(cell.y>26,"Traversal is no longer clamped to old map bounds")
	world.start_raid("east");world.set_physics_process(false)
	check(world.entry_position.is_equal_approx(Vector3(70,0,58)),"Chosen eastern entry reaches actual raid spawn")
	check(world.player.position.is_equal_approx(world.entry_position),"Player body spawns at the chosen entry")
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/operator_models.json"))
	check(manifest.assets.size()==37,"Original body plus all 36 armor/container items have individual models")
	for asset:Dictionary in manifest.assets:
		check(ResourceLoader.exists(str(asset.path),"PackedScene"),"Operator model imports: "+str(asset.id))
	print("HARBOR MAP TESTS ","PASS" if failures==0 else "FAIL",": ",checks," checks; ",summary)
	world.queue_free();await process_frame;await process_frame
	quit(0 if failures==0 else 1)
