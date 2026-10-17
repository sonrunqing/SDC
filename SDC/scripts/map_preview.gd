extends Control
## Inspectable full-sized preview of the same layout, meshes and districts used in a raid.
signal zone_selected(zone_id: String)
var _viewport: SubViewport
var _map: Node3D
var _camera: Camera3D
var _font: Font
var _target := Vector3.ZERO
var _yaw: float = .70
var _zoom: float = 208.0
var _dragging: bool = false
var _entry_id: String = "south"
var _zone: String = ""
var _touches: Dictionary = {}
var _pinch: float = 0
func _ready() -> void:
	clip_contents=true
	mouse_filter=Control.MOUSE_FILTER_STOP
	_font=load("res://assets/fonts/NotoSansSC.ttf")
	var container:=SubViewportContainer.new();container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;container.show_behind_parent=true;add_child(container)
	_viewport=SubViewport.new();_viewport.size=Vector2i(1100,650);_viewport.own_world_3d=true;_viewport.gui_disable_input=true;_viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE;container.add_child(_viewport)
	var env:=WorldEnvironment.new();var settings:=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("142329")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("b9c8c8");settings.ambient_light_energy=.65;settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.environment=settings;_viewport.add_child(env)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-55,-28,0);key.light_color=Color("f7e6cb");key.light_energy=1.25;key.shadow_enabled=true;key.directional_shadow_max_distance=600;_viewport.add_child(key)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-35,140,0);fill.light_color=Color("91c1ce");fill.light_energy=.25;_viewport.add_child(fill)
	_map=load("res://scripts/harbor_map.gd").new();_viewport.add_child(_map);_map.build(true)
	_camera=Camera3D.new();_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;_camera.far=800;_viewport.add_child(_camera);_camera.current=true
	_update_camera()
	resized.connect(func() -> void: call_deferred("_update_camera"))
	AppSettings.call_deferred("apply_scene",_viewport)
func _update_camera() -> void:
	if _camera==null:return
	_camera.size=_zoom
	_camera.position=_target+Vector3(sin(_yaw)*210,235,cos(_yaw)*210)
	_camera.look_at(_target)
	queue_redraw()
func show_overview() -> void:
	_target=Vector3.ZERO;_zoom=208;_zone="";_update_camera()
func focus_zone(zone_id: String) -> void:
	if _map==null:return
	for zone: Dictionary in _map.layout.zones:
		if str(zone.id)==zone_id:
			_target=Vector3(float(zone.position[0]),0,float(zone.position[1]));_zoom=72;_zone=zone_id;_update_camera();zone_selected.emit(zone_id);return
func set_entry_id(entry_id: String) -> void:
	_entry_id=entry_id;queue_redraw()
func _point(at: Vector3) -> Vector2:
	var p: Vector2=_camera.unproject_position(at)
	return p*size/Vector2(_viewport.size)
func _draw() -> void:
	if _camera==null or _map==null:return
	for zone: Dictionary in _map.layout.zones:
		var at:=Vector3(float(zone.position[0]),2,float(zone.position[1]))
		var p: Vector2=_point(at)
		if not Rect2(Vector2(5,5),size-Vector2(10,10)).has_point(p):continue
		var color:=Color(str(zone.color))
		draw_circle(p,3,color)
		draw_string(_font,p+Vector2(9,4),str(zone.name),HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
	for entry: Dictionary in _map.layout.entries:
		if str(entry.id)!=_entry_id:continue
		var p: Vector2=_point(Vector3(float(entry.position[0]),.2,float(entry.position[2])))
		draw_arc(p,9,0,TAU,32,Color("e2bf77"),2,true)
		draw_circle(p,3,Color("f4e3b1"))
	var exit_array: Array=_map.layout.extraction
	var exit_p: Vector2=_point(Vector3(float(exit_array[0]),.2,float(exit_array[2])))
	draw_rect(Rect2(exit_p-Vector2(6,6),Vector2(12,12)),Color("70d3af"),false,2)
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==-1:return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:_dragging=event.pressed;accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom=clampf(_zoom*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),45,260);_update_camera();accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_yaw+=event.relative.x*.006;_update_camera();accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:_touches[event.index]=event.position
		else:_touches.erase(event.index)
		_pinch=_touch_distance();accept_event()
	elif event is InputEventScreenDrag:
		_touches[event.index]=event.position
		if _touches.size()>=2:
			var current:float=_touch_distance()
			if _pinch>0 and current>0:_zoom=clampf(_zoom*_pinch/current,45,260)
			_pinch=current
		else:_yaw+=event.relative.x*.006
		_update_camera();accept_event()
func _touch_distance() -> float:
	var values:Array=_touches.values()
	return values[0].distance_to(values[1]) if values.size()>=2 else 0
func get_summary() -> Dictionary:
	return _map.get_summary() if _map!=null else {}
