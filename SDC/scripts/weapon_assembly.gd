extends Node3D
## Physical, origin-at-mount composition. Workbench and raid share this assembler.
## Models authored in metres; receiver origin, +Y up, firing -Z.
const GEOMETRY_PATH: String = "res://data/weapon_geometry.json"
var weapon_id: String = ""
var parts: Dictionary = {}
var body: Node3D
var _catalog: Node
var _geometry: Dictionary = {}
var _issues: Array = []
var _installed: Dictionary = {}
var _default_slots: Array = []

func _init() -> void:
	_catalog = load("res://scripts/catalog.gd").new()
	if FileAccess.file_exists(GEOMETRY_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY_PATH))
		if parsed is Dictionary:
			_geometry = parsed.get("weapons", {})

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_catalog):
		_catalog.free()

func set_build(new_weapon_id: String, new_parts: Dictionary = {}) -> bool:
	_issues.clear()
	var weapon: Dictionary = _catalog.get_item(new_weapon_id)
	if weapon.get("kind", "") != "weapon":
		_issues.append("Unknown weapon: " + new_weapon_id)
		return false
	for slot: Variant in new_parts:
		if not _catalog.compatible(new_weapon_id, str(new_parts[slot]), str(slot)):
			_issues.append("Incompatible part: " + str(slot) + " / " + str(new_parts[slot]))
	if not _issues.is_empty():
		return false
	var path: String = "res://assets/modular/weapons/" + new_weapon_id + ".glb"
	var next_body: Node3D = _load_model(path)
	if next_body == null:
		return false
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	weapon_id = new_weapon_id
	parts = new_parts.duplicate(true)
	_installed.clear()
	_default_slots.clear()
	body = next_body
	body.name = "WeaponBody"
	add_child(body)
	var defaults: Dictionary = _geometry.get(weapon_id, {}).get("defaults", {})
	for slot: Variant in weapon.get("slots", {}):
		var socket: Node3D = get_socket(str(slot))
		if socket == null:
			_issues.append("Missing authored socket: " + str(slot))
			continue
		var model_path: String = ""
		var part_id: String = ""
		if parts.has(slot):
			part_id = str(parts[slot])
			model_path = "res://assets/modular/attachments/" + part_id + ".glb"
		elif defaults.has(slot):
			model_path = str(defaults[slot])
			_default_slots.append(str(slot))
		if not model_path.is_empty():
			var model: Node3D = _load_model(model_path)
			if model != null:
				model.name = "Part_" + str(slot)
				socket.add_child(model)
				model.transform = Transform3D.IDENTITY
				_installed[str(slot)] = {"id": part_id, "path": model_path, "default": part_id.is_empty()}
	return _issues.is_empty()

func _load_model(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		_issues.append("Missing model: " + path)
		return null
	var resource: Resource = load(path)
	if not resource is PackedScene:
		_issues.append("Invalid model scene: " + path)
		return null
	var model: Node = (resource as PackedScene).instantiate()
	if not model is Node3D:
		model.free()
		_issues.append("Model root must be Node3D: " + path)
		return null
	return model as Node3D

func get_socket(slot: String) -> Node3D:
	if not is_instance_valid(body):
		return null
	return body.find_child("Socket_" + slot, true, false) as Node3D

func get_bounds() -> AABB:
	var result: AABB = AABB()
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(self, meshes)
	var first: bool = true
	for instance: MeshInstance3D in meshes:
		if instance.mesh == null:
			continue
		var local_to_assembly: Transform3D = _relative_transform(instance)
		var bounds: AABB = local_to_assembly * instance.mesh.get_aabb()
		if first:
			result = bounds
			first = false
		else:
			result = result.merge(bounds)
	return result

func _relative_transform(node: Node3D) -> Transform3D:
	var result: Transform3D = node.transform
	var current: Node = node.get_parent()
	while current != self and current != null:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			output.append(child as MeshInstance3D)
		_collect_meshes(child, output)

func build_summary() -> Dictionary:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(self, meshes)
	return {"weapon_id": weapon_id, "parts": parts.duplicate(true), "installed": _installed.duplicate(true), "defaults": _default_slots.duplicate(), "mesh_count": meshes.size(), "bounds": get_bounds(), "valid": validate_build().is_empty()}

func validate_build() -> Array:
	var result: Array = _issues.duplicate()
	if weapon_id.is_empty() or not is_instance_valid(body):
		result.append("No assembled weapon")
		return result
	for slot: Variant in parts:
		if not _catalog.compatible(weapon_id, str(parts[slot]), str(slot)):
			result.append("Incompatible part: " + str(parts[slot]))
		if not _installed.has(str(slot)):
			result.append("Missing installed geometry: " + str(slot))
	return result
