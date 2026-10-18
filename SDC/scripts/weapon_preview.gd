extends Control
## Interactive view of the same independently modeled assembly used in a raid.
signal socket_selected(slot: String)
var _viewport: SubViewport
var _orbit: Node3D
var _assembly: Node3D
var _camera: Camera3D
var _weapon_id: String = ""
var _attachments: Dictionary = {}
var _selected_socket: String = ""
var _yaw: float = 0.08
var _pitch: float = -0.03
var _zoom: float = 3.6
var _drag_distance: float = 0.0
var _tap_index: int = -1
var _touches: Dictionary = {}
var _pinch_distance: float = 0.0
var _font: Font
var _outline_material: ShaderMaterial
const SLOT_LABELS: Dictionary = {"muzzle":"枪口", "grip":"握把", "stock":"枪托", "magazine":"弹匣", "optic":"瞄具", "laser":"激光", "handguard":"护木"}

func _ready() -> void:
	add_to_group("mobile_touch_gesture")
	custom_minimum_size = Vector2(260, 150)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load("res://assets/fonts/NotoSansSC.ttf") as Font
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.show_behind_parent = true
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(720, 460)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(_viewport)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.045, 0.075, 0.095, 0)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b8c9cf")
	settings.ambient_light_energy = 0.85
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("8295a5")
	sky_material.sky_horizon_color = Color("d7e1e5")
	sky_material.ground_bottom_color = Color("344854")
	sky_material.ground_horizon_color = Color("a6b5bf")
	sky.sky_material = sky_material
	settings.sky = sky
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.environment = settings
	_viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 70, -10)
	key.light_color = Color("f3ede1")
	key.light_energy = 2.1
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -100, 0)
	fill.light_color = Color("78bac4")
	fill.light_energy = 1.0
	_viewport.add_child(fill)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = _zoom
	_camera.position = Vector3(3.8, 0.85, 0.35)
	_camera.near = 0.05
	_camera.far = 30.0
	_viewport.add_child(_camera)
	_camera.look_at(Vector3.ZERO)
	_camera.current = true
	_orbit = Node3D.new()
	_orbit.rotation = Vector3(_pitch, _yaw, 0)
	_viewport.add_child(_orbit)
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_front; void vertex() { VERTEX += NORMAL * 0.0017; } void fragment() { ALBEDO = vec3(0.3, 0.9, 0.72); }"
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = shader
	resized.connect(func(): call_deferred("_fit_preview"))
	if not _weapon_id.is_empty(): _rebuild()
	AppSettings.call_deferred("apply_scene",_viewport)

func set_weapon(weapon_id: String, installed: Dictionary = {}) -> void:
	_weapon_id = weapon_id
	_attachments = installed.duplicate(true)
	if is_instance_valid(_orbit): _rebuild()

func set_build(weapon_id: String, installed: Dictionary = {}) -> void:
	set_weapon(weapon_id, installed)

func focus_socket(slot: String) -> void:
	_selected_socket = slot
	_highlight_socket()
	queue_redraw()

func set_selected_socket(slot: String) -> void:
	focus_socket(slot)

func reset_view() -> void:
	_yaw = 0.08
	_pitch = -0.03
	_update_camera()
	_fit_preview()

func get_build_summary() -> Dictionary:
	if is_instance_valid(_assembly) and _assembly.has_method("build_summary"):
		return _assembly.call("build_summary")
	return {}

func _rebuild() -> void:
	if is_instance_valid(_assembly):
		_orbit.remove_child(_assembly)
		_assembly.queue_free()
	if not ResourceLoader.exists("res://scripts/weapon_assembly.gd"):
		return
	_assembly = load("res://scripts/weapon_assembly.gd").new() as Node3D
	_orbit.add_child(_assembly)
	if not bool(_assembly.call("set_build", _weapon_id, _attachments)):
		queue_redraw()
		return
	var bounds: AABB = _assembly.call("get_bounds")
	var factor: float = 2.75 / maxf(0.05, maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)))
	_assembly.scale = Vector3.ONE * factor
	_assembly.position = -bounds.get_center() * factor
	_update_camera()
	_highlight_socket()
	call_deferred("_fit_preview")

func _fit_preview() -> void:
	if not is_instance_valid(_assembly) or not is_instance_valid(_camera) or size.x < 10 or size.y < 10:
		return
	var bounds: AABB = _assembly.call("get_bounds")
	var projected := Rect2()
	for index in range(8):
		var point: Vector2 = _camera.unproject_position(_assembly.global_transform * bounds.get_endpoint(index))
		projected = Rect2(point, Vector2.ZERO) if index == 0 else projected.expand(point)
	var available: Vector2 = Vector2(_viewport.size) * Vector2(0.87, 0.77)
	var ratio: float = maxf(projected.size.x / maxf(1.0, available.x), projected.size.y / maxf(1.0, available.y))
	_zoom = clampf(_zoom * ratio, 0.55, 6.0)
	_update_camera()

func _highlight_socket() -> void:
	if not is_instance_valid(_assembly) or _outline_material == null: return
	for old: Node in _assembly.find_children("PreviewOutline", "MeshInstance3D", true, false):
		old.get_parent().remove_child(old)
		old.queue_free()
	var socket: Node3D = _assembly.call("get_socket", _selected_socket)
	if socket == null: return
	var originals: Array[Node] = socket.find_children("*", "MeshInstance3D", true, false)
	for original: Node in originals:
		var mesh_node := original as MeshInstance3D
		var outline := MeshInstance3D.new()
		outline.name = "PreviewOutline"
		outline.mesh = mesh_node.mesh
		outline.material_override = _outline_material
		outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_node.add_child(outline)

func _update_camera() -> void:
	if is_instance_valid(_orbit): _orbit.rotation = Vector3(_pitch, _yaw, 0)
	if is_instance_valid(_camera): _camera.size = _zoom
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not touch.canceled:
			if _touches.has(touch.index) or _touches.size()>=2:return
			if _touches.is_empty():
				_drag_distance = 0.0
				_tap_index = touch.index
			else:
				_tap_index = -1
			_touches[touch.index] = touch.position
		else:
			if not _touches.has(touch.index):return
			var activate: bool = not touch.canceled and touch.index==_tap_index and _touches.size()==1 and _drag_distance<8.0 and Rect2(Vector2.ZERO,size).has_point(touch.position)
			_touches.erase(touch.index)
			_tap_index = -1
			if activate: _pick_socket(touch.position)
		_pinch_distance = _touch_distance()
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _touches.has(drag.index):return
		_touches[drag.index] = drag.position
		_drag_distance += drag.relative.length()
		if _touches.size() >= 2:
			var distance: float = _touch_distance()
			if _pinch_distance > 1 and distance > 1:
				_zoom = clampf(_zoom * _pinch_distance / distance, 0.55, 6.0)
			_pinch_distance = distance
		else:
			_yaw += drag.relative.x * 0.012
			_pitch = clampf(_pitch + drag.relative.y * 0.009, -0.9, 0.9)
		_update_camera()
		accept_event()

func _touch_distance() -> float:
	if _touches.size() < 2: return 0.0
	var values: Array = _touches.values()
	return (values[0] as Vector2).distance_to(values[1] as Vector2)

func _socket_point(slot: String) -> Vector2:
	if not is_instance_valid(_assembly) or not is_instance_valid(_camera): return Vector2(-1000, -1000)
	var node: Node3D = _assembly.call("get_socket", slot)
	if not is_instance_valid(node) or _camera.is_position_behind(node.global_position): return Vector2(-1000, -1000)
	var point: Vector2 = _camera.unproject_position(node.global_position)
	var viewport_size: Vector2 = Vector2(_viewport.size)
	return point * size / viewport_size.max(Vector2.ONE)

func _pick_socket(at: Vector2) -> void:
	var closest: String = ""
	var distance: float = 25.0
	var sockets: Dictionary = Catalog.get_item(_weapon_id).get("slots", {})
	for raw_slot: Variant in sockets:
		var slot: String = str(raw_slot)
		var delta: float = _socket_point(slot).distance_to(at)
		if delta < distance:
			distance = delta
			closest = slot
	if not closest.is_empty():
		_selected_socket = closest
		socket_selected.emit(closest)
		queue_redraw()

func _draw() -> void:
	if not _font: return
	if not _selected_socket.is_empty():
		var point: Vector2 = _socket_point(_selected_socket)
		if point.x >= 0 and point.x <= size.x and point.y >= 0 and point.y <= size.y - 20:
			draw_circle(point, 5, Color("70dfc8"))
			draw_arc(point, 10, 0, TAU, 32, Color(0.44, 0.87, 0.78, 0.55), 1.2, true)
			draw_string(_font, point + Vector2(14, -10), str(SLOT_LABELS.get(_selected_socket, _selected_socket)), HORIZONTAL_ALIGNMENT_LEFT, 100, 12, Color("a4f5e4"))

func cancel_gesture() -> void:
	_touches.clear()
	_drag_distance = 0.0
	_tap_index = -1
	_pinch_distance = 0.0

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_PAUSED] or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		cancel_gesture()
