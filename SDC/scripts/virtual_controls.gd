extends Control
## Three independent pointer owners. Moving or aiming never starts a shot.
signal move_changed(value: Vector2)
signal aim_changed(value: Vector2, firing: bool)
signal fire_changed(pressed: bool)
signal reload_pressed
signal interact_pressed
signal medkit_pressed
signal weapon_pressed(slot: String)
var enabled: bool = false:
	set(value):
		enabled=value
		visible=value
		if not value:release_all()
		queue_redraw()
var _left_finger: int = -1
var _right_finger: int = -1
var _fire_finger: int = -1
var _action_owners: Dictionary = {}
var _action_buttons: Dictionary = {}
var _actions: Dictionary = {}
var _move:=Vector2.ZERO
var _aim:=Vector2.ZERO
var _font: Font
var _medkits: int = 0
var _reloading: bool = false
var _searching: bool = false
var _weapons: Array = []
const RADIUS:=66.0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_font=load("res://assets/fonts/NotoSansSC.ttf")
	resized.connect(_layout_actions)
	AppSettings.changed.connect(_layout_actions)
	_layout_actions()
	visible=enabled
func release_all() -> void:
	_left_finger=-1
	_right_finger=-1
	_fire_finger=-1
	_action_owners.clear()
	_move=Vector2.ZERO
	_aim=Vector2.ZERO
	move_changed.emit(_move)
	aim_changed.emit(_aim,false)
	fire_changed.emit(false)
	queue_redraw()
func _input(event: InputEvent) -> void:
	if not enabled:return
	if event is InputEventScreenTouch:_handle_pointer(event.index,_to_design(event.position),event.pressed,event.canceled)
	elif event is InputEventScreenDrag:_drag_pointer(event.index,_to_design(event.position))
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.device!=-1:_handle_pointer(-2,_to_design(event.position),event.pressed,false)
	elif event is InputEventMouseMotion and event.device!=-1:_drag_pointer(-2,_to_design(event.position))
func _handle_pointer(index: int, pos: Vector2, pressed: bool, cancelled: bool) -> void:
	var owned: bool = index in [_left_finger,_right_finger,_fire_finger] or _action_owners.has(index)
	if pressed and not cancelled:
		if _fire_rect().has_point(pos) and _fire_finger==-1:
			_fire_finger=index
			fire_changed.emit(true)
			aim_changed.emit(_aim,true)
			owned=true
		else:
			for action: String in _actions:
				if (_actions[action] as Rect2).has_point(pos):
					_action_owners[index]={"action":action,"start":pos,"cancel":false}
					owned=true
					break
			if not owned and _left_finger==-1 and pos.distance_to(_left_center())<_radius()*1.65:
				_left_finger=index
				_set_left(pos)
				owned=true
			elif not owned and _right_finger==-1 and pos.distance_to(_right_center())<_radius()*1.55:
				_right_finger=index
				_set_right(pos)
				owned=true
	else:
		if index==_left_finger:
			_left_finger=-1
			_move=Vector2.ZERO
			move_changed.emit(_move)
		if index==_right_finger:
			_right_finger=-1
			_aim=Vector2.ZERO
			aim_changed.emit(_aim,_fire_finger!=-1)
		if index==_fire_finger:
			_fire_finger=-1
			fire_changed.emit(false)
			aim_changed.emit(_aim,false)
		if _action_owners.has(index):
			var record: Dictionary = _action_owners[index]
			_action_owners.erase(index)
			if not cancelled and not record.cancel and (_actions[record.action] as Rect2).has_point(pos):_fire_action(record.action)
	if owned:get_viewport().set_input_as_handled()
	queue_redraw()
func _drag_pointer(index: int, pos: Vector2) -> void:
	var owned: bool = true
	if index==_left_finger:_set_left(pos)
	elif index==_right_finger:_set_right(pos)
	elif index==_fire_finger:pass
	elif _action_owners.has(index):
		if pos.distance_to(_action_owners[index].start)>12:_action_owners[index].cancel=true
	else:owned=false
	if owned:get_viewport().set_input_as_handled()
	queue_redraw()
func _to_design(pos: Vector2) -> Vector2:return get_global_transform_with_canvas().affine_inverse()*pos
func _set_left(pos: Vector2) -> void:
	_move=((pos-_left_center())/_radius()).limit_length(1)
	if _move.length()<float(AppSettings.values.deadzone):_move=Vector2.ZERO
	move_changed.emit(_move)
func _set_right(pos: Vector2) -> void:
	_aim=((pos-_right_center())/_radius()*float(AppSettings.values.aim_sensitivity)).limit_length(1)
	if _aim.length()<float(AppSettings.values.deadzone):_aim=Vector2.ZERO
	aim_changed.emit(_aim,_fire_finger!=-1)
func _radius() -> float:return RADIUS*float(AppSettings.values.control_scale)
func _left_center() -> Vector2:return Vector2(AppSettings.safe_insets(self).x+118,size.y-AppSettings.safe_insets(self).w-132)
func _right_center() -> Vector2:return Vector2(size.x-AppSettings.safe_insets(self).z-154,size.y-AppSettings.safe_insets(self).w-155)
func _fire_rect() -> Rect2:
	var side: float = 94*float(AppSettings.values.control_scale)
	return Rect2(Vector2(AppSettings.safe_insets(self).x+26,AppSettings.safe_insets(self).y+105),Vector2(side,side))
func _layout_actions() -> void:
	var safe: Vector4 = AppSettings.safe_insets(self)
	var bottom: float = size.y-safe.w
	var right: float = size.x-safe.z
	_actions={
		"reload":Rect2(Vector2(right-354,bottom-92),Vector2(112,72)),
		"interact":Rect2(Vector2(right-104,bottom-298),Vector2(104,72)),
		"heal":Rect2(Vector2(right-104,bottom-92),Vector2(104,72)),
		"weapon_primary":Rect2(Vector2(size.x*.5-230,bottom-76),Vector2(148,64)),
		"weapon_secondary":Rect2(Vector2(size.x*.5-74,bottom-76),Vector2(148,64)),
		"weapon_sidearm":Rect2(Vector2(size.x*.5+82,bottom-76),Vector2(148,64))}
	queue_redraw()
func _draw() -> void:
	if not enabled or _font==null:return
	var opacity: float = float(AppSettings.values.control_opacity)
	for center: Vector2 in [_left_center(),_right_center()]:
		draw_circle(center,_radius()+10,Color(.035,.06,.07,.5*opacity))
		draw_arc(center,_radius()+10,0,TAU,64,Color(.85,.91,.86,.6*opacity),2,true)
	draw_circle(_left_center()+_move*_radius()*.68,25,Color(.72,.83,.76,.8*opacity))
	draw_circle(_right_center()+_aim*_radius()*.68,25,Color(.91,.72,.4,.9*opacity))
	draw_string(_font,_left_center()+Vector2(-22,8),"移动",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color(.9,.95,.92,opacity))
	draw_string(_font,_right_center()+Vector2(-22,8),"瞄准",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color(.97,.85,.6,opacity))
	var fire: Rect2 = _fire_rect()
	draw_circle(fire.get_center(),fire.size.x*.5,Color(.83,.37,.22,.88) if _fire_finger!=-1 else Color(.12,.15,.15,.8*opacity))
	draw_arc(fire.get_center(),fire.size.x*.5,0,TAU,64,Color(.97,.72,.4,opacity),3,true)
	draw_string(_font,fire.get_center()+Vector2(-25,9),"开火",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color(.98,.88,.68,opacity))
	for action: String in _actions:
		var rect: Rect2 = _actions[action]
		var style:=StyleBoxFlat.new()
		style.bg_color=Color(.055,.08,.09,.78*opacity)
		style.border_color=Color(.65,.73,.69,.6*opacity)
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		draw_style_box(style,rect)
		var caption: String = {"reload":"换弹中" if _reloading else "换弹","heal":"治疗 ×%d"%_medkits,"interact":"搜索中" if _searching else "搜索 / 拾取"}.get(action,"")
		if action.begins_with("weapon_"):
			var slot: String = action.trim_prefix("weapon_")
			caption={"primary":"主武器","secondary":"副武器","sidearm":"手枪"}[slot]
			for item: Dictionary in _weapons:
				if str(item.slot)==slot:caption=str(item.get("name","未装备"))+"\n%d / %d"%[int(item.get("ammo",0)),int(item.get("reserve",0))]
		var lines: PackedStringArray = caption.split("\n")
		for i: int in range(lines.size()):draw_string(_font,rect.position+Vector2(10,27+i*24),lines[i],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-16,17,Color(.91,.94,.9,opacity))
func _fire_action(action: String) -> void:
	if not enabled:return
	if action.begins_with("weapon_"):weapon_pressed.emit(action.trim_prefix("weapon_"))
	elif action=="reload":reload_pressed.emit()
	elif action=="interact":interact_pressed.emit()
	elif action=="heal":medkit_pressed.emit()
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:release_all()
func set_status(medkits: int, reloading: bool, searching: bool) -> void:
	_medkits=medkits
	_reloading=reloading
	_searching=searching
	queue_redraw()
func set_weapons(weapons: Array) -> void:
	_weapons=weapons
	queue_redraw()
