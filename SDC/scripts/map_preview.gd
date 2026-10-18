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
var _entry_id: String = "south"
var _zone: String = ""
var _touches: Dictionary = {}
var _pinch: float = 0
var _twist_angle: float = 0
var _gesture_center := Vector2.ZERO
func _ready() -> void:
	add_to_group("mobile_touch_gesture")
	clip_contents=true
	mouse_filter=Control.MOUSE_FILTER_STOP
	_font=load("res://assets/fonts/NotoSansSC.ttf")
	var container:=SubViewportContainer.new();container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;container.show_behind_parent=true;add_child(container)
	_viewport=SubViewport.new();_viewport.size=Vector2i(1100,650);_viewport.own_world_3d=true;_viewport.gui_disable_input=true;_viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE;container.add_child(_viewport)
	_viewport.add_child(preload("res://scripts/visual_profile.gd").environment(true))
	_viewport.add_child(preload("res://scripts/visual_profile.gd").moon(true))
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
	var hint: String="单指平移 · 双指缩放 / 旋转"
	draw_string(_font,Vector2(12,size.y-14),hint,HORIZONTAL_ALIGNMENT_LEFT,size.x-24,16,Color("bac9c5"))

func _ground_point(local: Vector2) -> Variant:
	if _camera==null or size.x<=0 or size.y<=0:return null
	var point: Vector2=local*Vector2(_viewport.size)/size
	return Plane(Vector3.UP,0).intersects_ray(_camera.project_ray_origin(point),_camera.project_ray_normal(point))

func _pan(from: Vector2,to: Vector2) -> void:
	var before: Variant=_ground_point(from)
	var after: Variant=_ground_point(to)
	if before is Vector3 and after is Vector3:
		var offset: Vector3=before-after
		_target+=offset
		_target.x=clampf(_target.x,-100,100)
		_target.z=clampf(_target.z,-110,110)
		_target.y=0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			if _touches.has(event.index) or _touches.size()>=2:return
			_touches[event.index]=event.position
		else:
			if not _touches.has(event.index):return
			_touches.erase(event.index)
		_pinch=_touch_distance()
		_twist_angle=_touch_angle()
		_gesture_center=_touch_center()
		accept_event()
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index):return
		_touches[event.index]=event.position
		if _touches.size()>=2:
			var current:float=_touch_distance()
			var angle: float=_touch_angle()
			var center: Vector2=_touch_center()
			_pan(_gesture_center,center)
			if _pinch>0 and current>0:_zoom=clampf(_zoom*_pinch/current,45,260)
			_yaw-=wrapf(angle-_twist_angle,-PI,PI)
			_pinch=current
			_twist_angle=angle
			_gesture_center=center
		else:_pan(event.position-event.relative,event.position)
		_update_camera();accept_event()

func _touch_distance() -> float:
	var values:Array=_touches.values()
	return values[0].distance_to(values[1]) if values.size()>=2 else 0

func _touch_angle() -> float:
	var values: Array=_touches.values()
	return (values[1]-values[0]).angle() if values.size()>=2 else 0

func _touch_center() -> Vector2:
	var values: Array=_touches.values()
	if values.size()>=2:return (values[0]+values[1])*.5
	return values[0] if values.size()==1 else Vector2.ZERO

func cancel_gesture() -> void:
	_touches.clear()
	_pinch=0
	_twist_angle=0
	_gesture_center=Vector2.ZERO

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_PAUSED] or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		cancel_gesture()

func get_summary() -> Dictionary:
	return _map.get_summary() if _map!=null else {}
