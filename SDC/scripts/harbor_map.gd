extends Node3D
## Shared geometry for the playable harbour and the selection-page 3D preview.
const DATA_PATH: String = "res://data/harbor_layout.json"
var layout: Dictionary = {}
var obstacles: Array[Rect2] = []
var used_models: Dictionary = {}
var _metadata: Dictionary = {}
var _templates: Dictionary = {}
var _groups: Dictionary = {}
var _materials: Dictionary = {}
var _preview: bool = false
var object_count: int = 0
var _cutaway_instances: Dictionary = {}
var _cutaway_state: Dictionary = {}
var modular_object_count: int = 0

func _init() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/environment_models.json"))
	for asset: Dictionary in data.get("assets",[]): _metadata[str(asset.id)] = asset
	var modules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/industrial_modules.json"))
	for asset: Dictionary in modules.get("assets",[]): _metadata[str(asset.id)] = asset

func build(preview: bool = false) -> void:
	_preview = preview
	_ground()
	for record: Dictionary in layout.get("surfaces",[]):
		var mesh := BoxMesh.new()
		mesh.size = _vec(record.size)
		_batch("surface/"+str(record.color),mesh,_material(str(record.color)),Transform3D(Basis.IDENTITY,_vec(record.position)),false)
	for record: Dictionary in layout.get("objects",[]):
		_place(record)
	_flush()
	_building_signs()
	if not preview: _lighting()

func _vec(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

func _material(color: String, metallic: float = 0) -> StandardMaterial3D:
	if _materials.has(color): return _materials[color]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = .82
	m.metallic = metallic
	_materials[color] = m
	return m

func _ground() -> void:
	var size := Vector3(float(layout.bounds[0]),.3,float(layout.bounds[1]))
	var base := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	base.mesh = mesh
	base.position.y = -.17
	var material := _material("434c4b").duplicate() as StandardMaterial3D
	if not _preview:
		var noise := FastNoiseLite.new()
		noise.frequency = .055
		var texture := NoiseTexture2D.new()
		texture.width = 128;texture.height = 128;texture.noise = noise
		var gradient := Gradient.new()
		gradient.set_color(0,Color("777e7a"));gradient.set_color(1,Color("a4aaa0"))
		texture.color_ramp = gradient
		material.albedo_texture = texture
		material.uv1_scale = Vector3(40,40,40)
	base.material_override = material
	add_child(base)
	if not _preview:
		var body := StaticBody3D.new()
		body.position = base.position
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new();box.size = size
		shape.shape = box;body.add_child(shape);add_child(body)
	# Continuous map boundary; low concrete edges retain visibility of the yard.
	var half := Vector2(size.x*.5,size.z*.5)
	for record: Array in [[Vector3(-half.x,0,0),Vector3(.5,2.4,size.z)],[Vector3(half.x,0,0),Vector3(.5,2.4,size.z)],[Vector3(0,0,-half.y),Vector3(size.x,2.4,.5)],[Vector3(0,0,half.y),Vector3(size.x,2.4,.5)]]:
		var at: Vector3 = record[0];var dims: Vector3 = record[1]
		var wall := MeshInstance3D.new();var wall_mesh := BoxMesh.new();wall_mesh.size = dims
		wall.mesh = wall_mesh;wall.position=at+Vector3(0,1.2,0);wall.material_override = _material("58615b")
		add_child(wall)
		if not _preview: _collider(at,dims,0)

func _collect(node: Node, parent: Transform3D, pieces: Array, preserve_materials: bool = false, tint: Color = Color.WHITE) -> void:
	var xf := parent
	if node is Node3D: xf = parent*node.transform
	if node is MeshInstance3D and node.mesh != null:
		var mesh: Mesh = node.mesh.duplicate()
		for index: int in range(mesh.get_surface_count()):
			var material: Material = node.get_active_material(index)
			if material is StandardMaterial3D:
				var copy := material.duplicate() as StandardMaterial3D
				if not preserve_materials: copy.albedo_color = Color(.78,.84,.85)
				copy.roughness = .78
				if preserve_materials:
					copy.albedo_color *= tint
					# Dense source normals do not describe the simplified mobile mesh.
					copy.normal_enabled = false
					copy.metallic = .08
					copy.roughness = .9
				mesh.surface_set_material(index,copy)
		pieces.append({"mesh":mesh,"transform":xf})
	for child: Node in node.get_children(): _collect(child,xf,pieces,preserve_materials,tint)

func _place(record: Dictionary) -> void:
	var model_id: String = str(record.model)
	if not _metadata.has(model_id):
		push_error("Unknown harbour asset: "+model_id);return
	var meta: Dictionary = _metadata[model_id]
	if not _templates.has(model_id):
		var packed: PackedScene = load(str(meta.path))
		if packed == null: return
		var model: Node3D = packed.instantiate()
		var pieces: Array = []
		var tint_values: Array = meta.get("material_tint",[1.0,1.0,1.0])
		var tint := Color(float(tint_values[0]),float(tint_values[1]),float(tint_values[2]))
		_collect(model,Transform3D.IDENTITY,pieces,bool(meta.get("preserve_materials",false)),tint)
		_templates[model_id] = pieces
		model.free()
	var native_size: Vector3 = _vec(meta.size)
	var desired: Vector3 = _vec(record.size)
	var scale := desired/native_size
	var angle: float = deg_to_rad(float(record.get("rotation",0)))
	var at: Vector3 = _vec(record.position)
	var pivot: Vector3 = _vec(meta.min)+Vector3(native_size.x*.5,0,native_size.z*.5)
	var xf := Transform3D(Basis(Vector3.UP,angle)*Basis.from_scale(scale),at)
	xf.origin -= xf.basis*pivot
	var pieces: Array = _templates[model_id]
	for index: int in range(pieces.size()):
		var piece: Dictionary = pieces[index]
		_batch(model_id+"/"+str(index),piece.mesh,null,xf*piece.transform,true,str(record.get("cutaway","")))
	used_models[model_id] = true
	object_count += 1
	if meta.has("colliders"): modular_object_count += 1
	if not _preview and bool(record.get("collision",false)):
		if meta.has("colliders"):
			_module_colliders(record,meta,at,desired,angle)
		elif desired.y>.18:
			_collider(at,desired,angle)

func _batch(key: String, mesh: Mesh, material: Material, xf: Transform3D, shadow: bool, cutaway: String = "") -> void:
	# Group by mesh and spatial cell for useful frustum/distance culling on mobile.
	var chunk: String = "%d/%d" % [floori(xf.origin.x/32),floori(xf.origin.z/32)]
	# Primitive surfaces of different dimensions own different meshes.
	if key.begins_with("surface/"): key += "/"+str((mesh as BoxMesh).size)
	var id: String = key+"@"+chunk+"@"+cutaway
	if not _groups.has(id): _groups[id] = {"mesh":mesh,"material":material,"transforms":[],"shadow":shadow,"cutaway":cutaway,"origin":Vector3(floorf(xf.origin.x/32)*32+16,0,floorf(xf.origin.z/32)*32+16)}
	var local := xf
	local.origin -= _groups[id].origin
	_groups[id].transforms.append(local)

func _flush() -> void:
	for id: String in _groups:
		var group: Dictionary = _groups[id]
		var instance := MultiMeshInstance3D.new()
		instance.name = "Batch_"+id.replace("/","_").replace("@","_")
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = group.mesh
		batch.instance_count = group.transforms.size()
		for index: int in range(group.transforms.size()):batch.set_instance_transform(index,group.transforms[index])
		instance.multimesh = batch
		instance.position = group.origin
		if group.material != null: instance.material_override = group.material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if not bool(group.shadow) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if not _preview:
			instance.visibility_range_end = 85
			instance.visibility_range_end_margin = 8
		add_child(instance)
		if not str(group.cutaway).is_empty():
			var key: String = str(group.cutaway)
			if not _cutaway_instances.has(key): _cutaway_instances[key] = []
			_cutaway_instances[key].append(instance)
	_groups.clear()

func update_viewer_position(at: Vector3) -> void:
	if _preview: return
	for building: Dictionary in layout.get("buildings",[]):
		var center := Vector2(float(building.center[0]),float(building.center[1]))
		var dims := Vector2(float(building.size[0]),float(building.size[1]))
		var inside: bool = Rect2(center-dims*.5,dims).grow(1.3).has_point(Vector2(at.x,at.z))
		var key: String = str(building.id)
		if _cutaway_state.get(key,null) == inside: continue
		_cutaway_state[key] = inside
		for instance: GeometryInstance3D in _cutaway_instances.get(key,[]): instance.visible = not inside

func _building_signs() -> void:
	var font: Font = load("res://assets/fonts/NotoSansSC.ttf")
	var number: int = 0
	for building: Dictionary in layout.get("buildings",[]):
		number += 1
		var x: float = float(building.center[0])
		var south: float = float(building.center[1])+float(building.size[1])*.5
		var key: String = str(building.id)
		var plate := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(3.7,.46,.08)
		plate.mesh = mesh
		plate.position = Vector3(x,2.93,south+.21)
		plate.material_override = _material("233b42")
		add_child(plate)
		var label := Label3D.new()
		label.font = font
		label.text = "%02d  %s" % [number,str(building.name)]
		label.font_size = 64
		label.pixel_size = .005
		label.outline_size = 0
		label.modulate = Color("efd6a2")
		label.position = Vector3(x,2.93,south+.257)
		add_child(label)
		if not _cutaway_instances.has(key): _cutaway_instances[key] = []
		_cutaway_instances[key].append(plate)
		_cutaway_instances[key].append(label)
		var bay := Label3D.new()
		bay.font = font
		bay.text = "%02d" % number
		bay.font_size = 64
		bay.pixel_size = .012
		bay.outline_size = 0
		bay.modulate = Color("d2ae55")
		bay.position = Vector3(x,.066,south+2.4)
		bay.rotation_degrees.x = -90
		add_child(bay)

func _module_colliders(record: Dictionary, meta: Dictionary, at: Vector3, desired: Vector3, angle: float) -> void:
	# Collision uses authored structural pieces, never the full visual bounds.
	var factor: Vector3 = desired/_vec(meta.collision_size)
	var body := StaticBody3D.new()
	body.name = "ModuleCollision_"+str(meta.key)
	body.position = at
	body.rotation.y = angle
	add_child(body)
	for piece: Dictionary in meta.colliders:
		var center: Vector3 = _vec(piece.position)*factor
		var dims: Vector3 = _vec(piece.size)*factor
		var shape := CollisionShape3D.new()
		shape.position = center
		shape.rotation_degrees = _vec(piece.get("rotation",[0,0,0]))
		if str(piece.type) == "ramp":
			var ramp := ConvexPolygonShape3D.new()
			var w: float = dims.x*.5
			var d: float = dims.z*.5
			ramp.points = PackedVector3Array([Vector3(-w,0,-d),Vector3(w,0,-d),Vector3(-w,dims.y,-d),Vector3(w,dims.y,-d),Vector3(-w,0,d),Vector3(w,0,d)])
			shape.shape = ramp
		else:
			var box := BoxShape3D.new()
			box.size = dims
			shape.shape = box
		body.add_child(shape)
		if bool(piece.get("navigation",false)) and at.y+center.y-dims.y*.5<1.2:
			var world_center: Vector3 = at+Basis(Vector3.UP,angle)*center
			var width: float = absf(cos(angle))*dims.x+absf(sin(angle))*dims.z
			var depth: float = absf(sin(angle))*dims.x+absf(cos(angle))*dims.z
			obstacles.append(Rect2(Vector2(world_center.x-width*.5,world_center.z-depth*.5),Vector2(width,depth)))

func _collider(at: Vector3, size: Vector3, angle: float) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.rotation.y = angle
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new();box.size = size
	shape.shape = box;shape.position.y = size.y*.5
	body.add_child(shape);add_child(body)
	if at.y<1.2:
		var width: float = absf(cos(angle))*size.x+absf(sin(angle))*size.z
		var depth: float = absf(sin(angle))*size.x+absf(cos(angle))*size.z
		obstacles.append(Rect2(Vector2(at.x-width*.5,at.z-depth*.5),Vector2(width,depth)))

func _lighting() -> void:
	var steel := _material("384b4e",.4)
	var lamp_material := _material("e7d3a3").duplicate() as StandardMaterial3D
	lamp_material.emission_enabled = true;lamp_material.emission = Color("e1ba77");lamp_material.emission_energy_multiplier = 2.0
	for record: Dictionary in layout.get("lights",[]):
		var at: Vector3 = _vec(record.position)
		if str(record.get("fixture","pole")) == "pole":
			var pole := MeshInstance3D.new();var pole_mesh := CylinderMesh.new()
			pole_mesh.top_radius=.075;pole_mesh.bottom_radius=.12;pole_mesh.height=at.y;pole_mesh.radial_segments=8
			pole.mesh=pole_mesh;pole.material_override=steel;pole.position=Vector3(at.x,at.y*.5,at.z);add_child(pole)
		var lamp := MeshInstance3D.new();var lamp_mesh := BoxMesh.new();lamp_mesh.size=Vector3(1.15,.12,.5)
		lamp.mesh=lamp_mesh;lamp.material_override=lamp_material;lamp.position=at;add_child(lamp)
		var cutaway: String = str(record.get("cutaway",""))
		if not cutaway.is_empty():
			if not _cutaway_instances.has(cutaway): _cutaway_instances[cutaway] = []
			_cutaway_instances[cutaway].append(lamp)
		var light := OmniLight3D.new();light.position=at-Vector3(0,.5,0);light.light_color=Color(str(record.color));light.light_energy=float(record.energy);light.omni_range=float(record.radius)
		light.shadow_enabled=false;light.distance_fade_enabled=true;light.distance_fade_begin=38;light.distance_fade_length=10;add_child(light)

func get_summary() -> Dictionary:
	return {"bounds":layout.get("bounds",[]),"area_multiplier":layout.get("area_multiplier",0),"objects":object_count,"model_types":used_models.size(),"obstacles":obstacles.size(),"modular_objects":modular_object_count,"assembled_buildings":layout.get("buildings",[]).size()}
