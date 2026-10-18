extends SceneTree
var bounds: AABB
var started: bool = false
var triangles: int = 0
func _initialize() -> void:
	call_deferred("run")
func visit(node: Node, parent: Transform3D) -> void:
	var xf: Transform3D = parent
	if node is Node3D: xf = parent*node.transform
	if node is MeshInstance3D and node.mesh != null:
		var local: AABB = xf*node.mesh.get_aabb()
		bounds = bounds.merge(local) if started else local
		started = true
		for surface: int in range(node.mesh.get_surface_count()):
			var array: Array = node.mesh.surface_get_arrays(surface)
			triangles += array[Mesh.ARRAY_INDEX].size()/3 if array[Mesh.ARRAY_INDEX] != null and array[Mesh.ARRAY_INDEX].size()>0 else array[Mesh.ARRAY_VERTEX].size()/3
	for child: Node in node.get_children(): visit(child,xf)
func run() -> void:
	var assets: Array[Dictionary] = []
	for pack: String in ["industrial","factory","vehicles"]:
		var dir: String = "res://assets/environment/"+pack
		for filename: String in DirAccess.get_files_at(dir):
			if not filename.ends_with(".glb"): continue
			var path: String = dir+"/"+filename
			var scene: PackedScene = load(path)
			var model: Node3D = scene.instantiate()
			started = false;triangles=0
			visit(model,Transform3D.IDENTITY)
			assets.append({"id":pack+"/"+filename.get_basename(),"path":path,"min":[bounds.position.x,bounds.position.y,bounds.position.z],"size":[bounds.size.x,bounds.size.y,bounds.size.z],"triangles":triangles})
			model.free()
	var file := FileAccess.open("res://data/environment_models.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version":1,"assets":assets},"\t")+"\n");file.close()
	print("ENVIRONMENT_INSPECTED ",assets.size())
	quit()
