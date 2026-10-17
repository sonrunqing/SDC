extends SceneTree
## Validate all real models, authored sockets, factory replacement and mount transforms.
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
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_geometry.json"))
	var geometry: Dictionary = parsed.get("weapons", {})
	var assembly: Node3D = load("res://scripts/weapon_assembly.gd").new()
	root.add_child(assembly)
	var used_paths: Dictionary = {}
	for weapon: Dictionary in catalog.by_kind("weapon"):
		var id: String = str(weapon.id)
		check(assembly.call("set_build",id,{}), "Original gun body and factory components load: " + id)
		var summary: Dictionary = assembly.call("build_summary")
		check(bool(summary.valid) and int(summary.mesh_count) > 1, "Base gun has independent body and removable factory meshes: " + id)
		var bounds: AABB = assembly.call("get_bounds")
		check(bounds.size.length() > 0.1 and bounds.size.length() < 2.5, "Authored weapon uses physical metre dimensions: " + id)
		var slots: Dictionary = weapon.slots
		for slot: String in slots:
			var node: Node3D = assembly.call("get_socket",slot)
			check(node != null, "Supported interface has an actual mount node: " + id + "/" + slot)
			if node != null:
				var xyz: Array = geometry[id]["sockets"][slot]
				var expected := Vector3(float(xyz[0]),float(xyz[1]),float(xyz[2]))
				check(node.global_position.is_equal_approx(expected), "GLB socket matches authored transform rather than a bounding-box guess: " + id + "/" + slot)
		used_paths[catalog.model_path(id)] = true
	for item: Dictionary in catalog.by_kind("attachment"):
		var id: String = str(item.id)
		var compatible_gun: String = ""
		for weapon: Dictionary in catalog.by_kind("weapon"):
			if catalog.compatible(str(weapon.id),id):
				compatible_gun = str(weapon.id)
				break
		check(not compatible_gun.is_empty(), "Each independent part is mountable somewhere: " + id)
		if compatible_gun.is_empty(): continue
		var slot: String = str(item.slot)
		check(assembly.call("set_build",compatible_gun,{slot:id}), "Accessory can physically assemble with its supported body: " + id)
		var summary: Dictionary = assembly.call("build_summary")
		var installed: Dictionary = summary.installed.get(slot,{})
		check(str(installed.get("path","")) == catalog.model_path(id) and not bool(installed.get("default",true)), "Chosen accessory loads its own model: " + id)
		var mount: Node3D = assembly.call("get_socket",slot)
		check(mount != null and mount.get_child_count() == 1, "Custom part replaces factory part at the interface: " + id)
		if mount != null and mount.get_child_count() == 1:
			var part: Node3D = mount.get_child(0)
			check(part.transform.is_equal_approx(Transform3D.IDENTITY), "Accessory origin aligns with mount: " + id)
		used_paths[catalog.model_path(id)] = true
	check(used_paths.size() == 169, "24 receivers plus145accessories use169independent asset files")
	assembly.queue_free()
	await process_frame
	await process_frame
	print("MODEL TESTS ","PASS" if failures == 0 else "FAIL",": ",checks," checks; 24 bodies,145accessories, authored sockets and factory replacement")
	quit(0 if failures == 0 else 1)
