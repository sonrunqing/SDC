extends Control
## Full character dressing-room scene; no inventory mutation.
var _viewport: SubViewport
var _model: Node3D
var _camera: Camera3D
var _orbit: Node3D
var _touch_index: int = -1
var _yaw: float = -.13
var _time: float = 0
func _ready() -> void:
	add_to_group("mobile_touch_gesture")
	clip_contents=true
	mouse_filter=Control.MOUSE_FILTER_STOP
	var container := SubViewportContainer.new();container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(container)
	_viewport=SubViewport.new();_viewport.size=Vector2i(1280,600);_viewport.own_world_3d=true
	_viewport.gui_disable_input=true;_viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE;container.add_child(_viewport)
	var environment := WorldEnvironment.new();var settings := Environment.new()
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("111b20")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("b1c2ca");settings.ambient_light_energy=.28
	settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var sky:=Sky.new();var sky_material:=ProceduralSkyMaterial.new();sky_material.sky_top_color=Color("809ca7");sky_material.sky_horizon_color=Color("a8b8bc");sky_material.ground_bottom_color=Color("343e40");sky.sky_material=sky_material
	settings.sky=sky;settings.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	environment.environment=settings;_viewport.add_child(environment)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-42,145,0);key.light_color=Color("ffead0");key.light_energy=.95;key.shadow_enabled=true;_viewport.add_child(key)
	var rim:=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-25,-40,0);rim.light_color=Color("80d3df");rim.light_energy=.32;_viewport.add_child(rim)
	_room()
	_orbit=Node3D.new();_viewport.add_child(_orbit)
	_model=load("res://scripts/operator_model.gd").new();_orbit.add_child(_model)
	_model.set_loadout(GameState.loadout,GameState.weapon_builds,GameState.active_weapon_slot)
	_camera=Camera3D.new();_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;_camera.size=2.35;_camera.keep_aspect=Camera3D.KEEP_HEIGHT;_camera.position=Vector3(1.2,1.25,-4.65);_viewport.add_child(_camera)
	_camera.look_at(Vector3(.15,.95,0));_camera.current=true
	_orbit.rotation.y=_yaw
	set_process(true)
	AppSettings.call_deferred("apply_scene",_viewport)
func _material(color: String,metallic: float = 0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=Color(color);m.metallic=metallic;m.roughness=.7;return m
func _box(size: Vector3,at: Vector3,color: String,metallic: float = 0) -> void:
	var instance:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;instance.mesh=mesh
	instance.position=at;instance.material_override=_material(color,metallic);_viewport.add_child(instance)
func _room() -> void:
	_box(Vector3(18,.1,15),Vector3(0,-.07,0),"27302f",.04)
	_box(Vector3(18,5,.25),Vector3(0,2.4,3),"243033",.25)
	for x: float in [-6,-3,0,3,6]:
		_box(Vector3(.11,4.8,.3),Vector3(x,2.3,2.8),"455358",.6)
		_box(Vector3(2.4,.035,.035),Vector3(x,2.65,2.63),"859888",.3)
	for x: float in [-.7,.7]:
		_box(Vector3(.05,.015,2.0),Vector3(x,.001,0),"958a61")
	for at: Vector3 in [Vector3(-1.8,0,.9),Vector3(-1.5,.4125,1.1),Vector3(1.8,0,1.5)]:
		var crate: Node3D=load("res://assets/environment/factory/box-large.glb").instantiate()
		crate.position=at;crate.scale=Vector3(.75,.75,.75);_viewport.add_child(crate)
	# Pinned gear panel and a steel equipment bench in the rear of the room.
	_box(Vector3(1.6,1.4,.10),Vector3(2,1.5,2.67),"142025",.45)
	for y: float in [.95,1.2,1.45,1.7,1.95]:_box(Vector3(1.4,.02,.02),Vector3(2,y,2.59),"3d4f50",.5)
	_box(Vector3(1.7,.08,.6),Vector3(-1.7,.8,2),"414e4e",.5)
	for x: float in [-2.4,-1.0]:_box(Vector3(.07,.8,.07),Vector3(x,.4,2),"303b40",.6)
func _process(delta: float) -> void:
	_time+=delta
	if _orbit!=null:
		_orbit.rotation.y=_yaw
		_model.position.y=sin(_time*1.5)*.0025
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			if _touch_index!=-1:return
			_touch_index=event.index
		else:
			if event.index!=_touch_index:return
			cancel_gesture()
		accept_event()
	elif event is InputEventScreenDrag and event.index==_touch_index:
		_yaw+=event.relative.x*.008
		accept_event()
func cancel_gesture() -> void:
	_touch_index=-1
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_PAUSED] or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		cancel_gesture()
func get_loadout_summary() -> Dictionary:
	return _model.get_summary() if _model!=null else {}
func refresh_equipment() -> void:
	if _model!=null:_model.set_loadout(GameState.loadout,GameState.weapon_builds,GameState.active_weapon_slot)
