extends Node3D
## Ashfront ArenaDetail / ReferenceArena visual layer adapted to SDC's layout.
## Decoration has no new collision or navigation cost. All placement is deterministic.
var _groups: Dictionary={}
var _materials: Dictionary={}
var detail_count: int=0
var _rng:=RandomNumberGenerator.new()

func build(layout: Dictionary,preview: bool) -> void:
	_rng.seed=20261005
	# Crossings and stop bars belong to the existing road intersections.
	for z: float in [-57,-15,20,56]:
		for side: float in [-1,1]:
			for offset: float in [-3,-1.5,0,1.5,3]:
				_box(Vector3(2.6,.012,.72),Vector3(side*9,.058,z+offset),"a5a79b")
			_box(Vector3(.13,.012,8),Vector3(side*8.5,.057,z),"aaa997")
	# Drainage strips, expansion joints, manholes and repairs, spaced along roads.
	for z: int in range(-82,86,14):
		for side: int in [-1,1]:
			for bar: int in range(6):
				_box(Vector3(.46,.014,.045),Vector3(side*5.55,.063,z+bar*.1),"20252b")
		_box(Vector3(10,.008,.028),Vector3(0,.054,z+4),"292d32")
		if z%3==0:
			_box(Vector3(2.5,.009,1.3),Vector3(_rng.randf_range(-3,3),.044,z+2),"30343c")
	for z: float in [-70,-36,4,38,72]:
		var mesh:=CylinderMesh.new()
		mesh.top_radius=.46
		mesh.bottom_radius=.46
		mesh.height=.025
		mesh.radial_segments=16
		_add("manhole",mesh,Vector3(2.4,.052,z),Vector3.ONE,"454a4b")
		for offset: float in [-.22,-.1,.02,.14,.26]:
			_box(Vector3(.58,.009,.025),Vector3(2.4,.069,z+offset),"242a30")
	# Subtle ground contact shading also works on phones with SSAO disabled.
	var shadow:=StandardMaterial3D.new()
	shadow.albedo_texture=preload("res://assets/ashfront/contact_shadow.svg")
	shadow.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.disable_receive_shadows=true
	shadow.cull_mode=BaseMaterial3D.CULL_DISABLED
	shadow.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
	var plane:=PlaneMesh.new()
	plane.size=Vector2.ONE
	for record: Dictionary in layout.get("objects",[]):
		var dims:=Vector3(float(record.size[0]),float(record.size[1]),float(record.size[2]))
		if dims.y<.5 or not bool(record.get("collision",false)):continue
		var at:=Vector3(float(record.position[0]),float(record.position[1]),float(record.position[2]))
		if at.y>.3:continue
		var xf:=Transform3D(Basis(Vector3.UP,deg_to_rad(float(record.get("rotation",0))))*Basis.from_scale(Vector3(dims.x+1.1,1,dims.z+1.1)),at+Vector3(0,.031,0))
		_batch("contact",plane,shadow,xf,false)
	# Bay numbers, loading stripes, facade trim and roof fittings reuse each
	# enterable building's exact bounds. No opaque facade across an existing door.
	for building: Dictionary in layout.get("buildings",[]):
		var at:=Vector3(float(building.center[0]),0,float(building.center[1]))
		var width: float=float(building.size[0])
		var depth: float=float(building.size[1])
		for side: float in [-1,1]:
			_box(Vector3(.14,.016,depth+4),at+Vector3(side*(width*.5+1.4),.07,0),"a39260")
		for index: int in range(5):
			_box(Vector3(.25,.018,1.1),at+Vector3((index-2)*.85,.072,depth*.5+2.3),"b4a36b")
	for zone: Dictionary in layout.get("zones",[]):
		if str(zone.id) in ["north","south"]:continue
		var label:=Label3D.new()
		label.text=str(zone.name)
		label.font=load("res://assets/fonts/NotoSansSC.ttf")
		label.font_size=64
		label.pixel_size=.022
		label.modulate=Color(.64,.62,.52,.55)
		label.outline_size=0
		label.position=Vector3(float(zone.position[0]),.084,float(zone.position[1])+7)
		label.rotation_degrees.x=-90
		add_child(label)
	for key: String in _groups:
		var group: Dictionary=_groups[key]
		var batch:=MultiMesh.new()
		batch.transform_format=MultiMesh.TRANSFORM_3D
		batch.mesh=group.mesh
		batch.instance_count=group.transforms.size()
		for index: int in range(batch.instance_count):batch.set_instance_transform(index,group.transforms[index])
		var instance:=MultiMeshInstance3D.new()
		instance.multimesh=batch
		instance.material_override=group.material
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.position=group.origin
		if not preview:
			instance.visibility_range_end=65
			instance.visibility_range_end_margin=5
		add_child(instance)
	_groups.clear()

func _box(dims: Vector3,at: Vector3,color: String) -> void:
	var mesh:=BoxMesh.new()
	mesh.size=Vector3.ONE
	_add("box",mesh,at,dims,color)

func _add(key: String,mesh: Mesh,at: Vector3,scale_value: Vector3,color: String) -> void:
	if not _materials.has(color):_materials[color]=preload("res://scripts/visual_profile.gd").material(Color(color))
	_batch(key+color,mesh,_materials[color],Transform3D(Basis.from_scale(scale_value),at),false)

func _batch(key: String,mesh: Mesh,material: Material,xf: Transform3D,_shadow: bool) -> void:
	var origin:=Vector3(floorf(xf.origin.x/32)*32+16,0,floorf(xf.origin.z/32)*32+16)
	key+="@"+str(origin)
	if not _groups.has(key):_groups[key]={"mesh":mesh,"material":material,"origin":origin,"transforms":[]}
	xf.origin-=origin
	_groups[key].transforms.append(xf)
	detail_count+=1
