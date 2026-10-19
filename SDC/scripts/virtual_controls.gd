extends Control
## Shared layout geometry, three independent pointer owners, and release-only actions.
signal move_changed(value: Vector2)
signal aim_changed(value: Vector2)
signal fire_changed(pressed: bool)
signal reload_pressed
signal interact_pressed(target: int)
signal medkit_pressed
signal weapon_pressed(slot: String)
signal menu_pressed
signal layout_fallback
const Layout = preload("res://scripts/control_layout.gd")
var enabled: bool = false:
	set(value):
		enabled=value
		visible=value
		if not value:release_all()
		queue_redraw()
var preview_mode: bool = false
var preview_selected: String = ""
var preview_conflicts: Array[String]=[]
var layout_override: Dictionary={}
var safe_override := Vector4.ZERO
var _entries: Dictionary={}
var _rects: Dictionary={}
var _left_finger: int = -1
var _right_finger: int = -1
var _fire_finger: int = -1
var _action_owners: Dictionary={}
var _actions: Dictionary={}
var _move := Vector2.ZERO
var _aim := Vector2.ZERO
var _font: Font
var _medkits: int = 0
var _reloading: bool = false
var _searching: bool = false
var _interact_target: int=-1
var _weapons: Array=[]
var _fallback_active: bool=false

func _ready() -> void:
	add_to_group("mobile_touch_gesture")
	if not preview_mode:set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_font=load("res://assets/fonts/NotoSansSC.ttf")
	resized.connect(_layout_actions)
	if not preview_mode:
		AppSettings.changed.connect(_layout_actions)
		AppSettings.controls_changed.connect(_layout_actions)
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
	aim_changed.emit(_aim)
	fire_changed.emit(false)
	queue_redraw()

func cancel_gesture() -> void:
	release_all()

func _input(event: InputEvent) -> void:
	if not enabled or preview_mode:return
	if not get_tree().get_nodes_in_group("mobile_touch_modal").is_empty():
		release_all()
		return
	if event is InputEventScreenTouch:_handle_pointer(event.index,_to_design(event.position),event.pressed,event.canceled)
	elif event is InputEventScreenDrag:_drag_pointer(event.index,_to_design(event.position))

func _handle_pointer(index: int,pos: Vector2,pressed: bool,cancelled: bool) -> void:
	var owned: bool=index in [_left_finger,_right_finger,_fire_finger] or _action_owners.has(index)
	if pressed and not cancelled:
		if owned:return
		var id: String=Layout.pick(_entries,_rects,pos)
		if not _context_visible(id):return
		if id=="fire" and _fire_finger==-1:
			_fire_finger=index
			fire_changed.emit(true)
			owned=true
		elif id=="move" and _left_finger==-1:
			_left_finger=index
			_set_left(pos)
			owned=true
		elif id=="aim" and _right_finger==-1:
			_right_finger=index
			_set_right(pos)
			owned=true
		elif _actions.has(id):
			var taken: bool=false
			for record: Dictionary in _action_owners.values():
				if str(record.action)==id:taken=true
			if not taken:
				_action_owners[index]={"action":id,"start":pos,"cancel":false,"target":_interact_target if id=="interact" else -1}
				owned=true
	else:
		if index==_left_finger:
			_left_finger=-1
			_move=Vector2.ZERO
			move_changed.emit(_move)
		if index==_right_finger:
			_right_finger=-1
			_aim=Vector2.ZERO
			aim_changed.emit(_aim)
		if index==_fire_finger:
			_fire_finger=-1
			fire_changed.emit(false)
		if _action_owners.has(index):
			var record: Dictionary=_action_owners[index]
			_action_owners.erase(index)
			if not cancelled and not bool(record.cancel) and _context_visible(str(record.action)) and _actions.has(record.action) and Layout.contains(str(record.action),_actions[record.action],pos):_fire_action(str(record.action),int(record.get("target",-1)))
	if owned:get_viewport().set_input_as_handled()
	queue_redraw()

func _drag_pointer(index: int,pos: Vector2) -> void:
	var owned: bool=true
	if index==_left_finger:_set_left(pos)
	elif index==_right_finger:_set_right(pos)
	elif index==_fire_finger:pass
	elif _action_owners.has(index):
		if pos.distance_to(_action_owners[index].start)>12:_action_owners[index].cancel=true
	else:owned=false
	if owned:get_viewport().set_input_as_handled()
	queue_redraw()

func _to_design(pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse()*pos

func _stick_radius(id: String) -> float:
	return maxf(1,(_rects[id] as Rect2).size.x*.5-10*float(_entries[id].scale))

func _set_left(pos: Vector2) -> void:
	_move=((pos-(_rects.move as Rect2).get_center())/_stick_radius("move")).limit_length(1)
	if _move.length()<float(AppSettings.values.deadzone):_move=Vector2.ZERO
	move_changed.emit(_move)

func _set_right(pos: Vector2) -> void:
	_aim=((pos-(_rects.aim as Rect2).get_center())/_stick_radius("aim")*float(AppSettings.values.aim_sensitivity)).limit_length(1)
	if _aim.length()<float(AppSettings.values.deadzone):_aim=Vector2.ZERO
	aim_changed.emit(_aim)

func _layout_actions() -> void:
	if not is_inside_tree():return
	if not preview_mode:release_all()
	var safe: Vector4=safe_override if preview_mode else AppSettings.safe_insets(self)
	var raw: Dictionary=layout_override if preview_mode else AppSettings.get_control_layout()
	_entries=Layout.resolve(raw,size,safe,float(AppSettings.values.control_scale),float(AppSettings.values.control_opacity))
	_rects=Layout.rectangles(_entries,size,safe)
	if not preview_mode:
		var invalid: bool=not Layout.collisions(_entries,_rects).is_empty()
		if invalid:
			_entries=Layout.defaults(size,safe)
			_rects=Layout.rectangles(_entries,size,safe)
			if not _fallback_active:call_deferred("_report_fallback")
		_fallback_active=invalid
	_actions.clear()
	for id: String in Layout.IDS:
		# Circle shape does not imply joystick ownership: menu remains a tap action.
		if id not in ["move","aim","fire"] and Layout.visible(_entries,id):_actions[id]=_rects[id]
	queue_redraw()

func _report_fallback() -> void:
	if _fallback_active:layout_fallback.emit()

func set_preview_layout(raw: Dictionary,safe: Vector4,selected: String,conflicts: Array[String]) -> void:
	layout_override=raw
	safe_override=safe
	preview_selected=selected
	preview_conflicts=conflicts
	_layout_actions()

func get_control_rects() -> Dictionary:
	return _rects.duplicate(true)

func _color(hex_value: String,alpha: float) -> Color:
	var color:=Color(hex_value)
	color.a=alpha
	return color

func _draw() -> void:
	if not enabled or _font==null or _rects.is_empty():return
	for id: String in Layout.IDS:
		if not Layout.visible(_entries,id):continue
		if not _context_visible(id):continue
		var rect: Rect2=_rects[id]
		var opacity: float=float(_entries[id].opacity)
		if id in ["move","aim"]:
			var radius: float=rect.size.x*.5
			var direction: Vector2=_move if id=="move" else _aim
			draw_circle(rect.get_center(),radius,_color("0c1519",.6*opacity))
			draw_arc(rect.get_center(),radius,0,TAU,64,_color("d8e1dd",.8*opacity),2,true)
			draw_circle(rect.get_center()+direction*_stick_radius(id)*.68,maxf(18,radius*.33),_color("b9cbc2",.8*opacity))
			_draw_caption("移动" if id=="move" else "瞄准",rect,20,opacity)
		elif id=="fire":
			draw_circle(rect.get_center(),rect.size.x*.5,_color("b4c4bf" if _fire_finger!=-1 else "202c31",.9*opacity))
			draw_arc(rect.get_center(),rect.size.x*.5,0,TAU,64,_color("d8e1dd",opacity),2,true)
			_draw_caption("开火",rect,22,opacity)
		elif id=="menu":
			var held: bool=false
			for record: Dictionary in _action_owners.values():
				if str(record.action)==id:held=true
			_draw_menu_gear(rect,held,opacity)
		elif id=="interact":
			var held: bool=false
			for record: Dictionary in _action_owners.values():
				if str(record.action)==id:held=true
			var center: Vector2=rect.get_center()
			var radius: float=rect.size.x*.44
			draw_circle(center,radius,_color("43534f" if held else "172329",.86*opacity))
			draw_arc(center,radius,0,TAU,48,_color("b4c3bc",.72*opacity),1.5,true)
			var lens:=center+Vector2(-2,-10)*rect.size.x/64.0
			draw_arc(lens,6.0*rect.size.x/64.0,0,TAU,24,_color("eff3ef",opacity),1.8,true)
			draw_line(lens+Vector2(4,4)*rect.size.x/64.0,lens+Vector2(10,10)*rect.size.x/64.0,_color("eff3ef",opacity),2,true)
			_draw_caption("搜索",Rect2(rect.position+Vector2(0,rect.size.y*.25),Vector2(rect.size.x,rect.size.y*.75)),13,opacity)
		else:
			var held: bool=false
			for record: Dictionary in _action_owners.values():
				if str(record.action)==id:held=true
			var style:=StyleBoxFlat.new()
			style.bg_color=_color("43534f" if held else "172329",.86*opacity)
			style.border_color=_color("b4c3bc",.72*opacity)
			style.set_border_width_all(1)
			style.set_corner_radius_all(8)
			draw_style_box(style,rect)
			var caption: String=str(Layout.TITLES[id])
			if id=="reload" and _reloading:caption="换弹中"
			elif id=="heal":caption="治疗 ×%d"%_medkits if not preview_mode else "治疗"
			elif id=="interact" and _searching:caption="搜索中"
			elif id.begins_with("weapon_") and not preview_mode:
				for item: Dictionary in _weapons:
					if str(item.slot)==id.trim_prefix("weapon_"):caption=str(item.get("name","未装备"))+"\n%d / %d"%[int(item.get("ammo",0)),int(item.get("reserve",0))]
			_draw_caption(caption,rect,17,opacity)
		if preview_mode and (id==preview_selected or preview_conflicts.has(id)):
			draw_rect(rect.grow(5),Color("ec9287") if preview_conflicts.has(id) else Color("e4eeea"),false,2)

func _context_visible(id: String) -> bool:
	if preview_mode:return true
	if id=="interact":return _interact_target>=0
	if id.begins_with("weapon_"):
		var count: int=0
		var available: bool=false
		for item: Dictionary in _weapons:
			if not bool(item.get("available",false)):continue
			count+=1
			if str(item.slot)==id.trim_prefix("weapon_"):available=true
		return count>1 and available
	return true

func _draw_menu_gear(rect: Rect2,held: bool,opacity: float) -> void:
	# A 28px face at default scale inside the shared 44px circular touch target.
	var center: Vector2=rect.get_center()
	var radius: float=minf(rect.size.x,rect.size.y)*.32
	var background: Color=_color("43534f" if held else "172329",.86*opacity)
	draw_circle(center,radius,background)
	draw_arc(center,radius,0,TAU,40,_color("b4c3bc",.72*opacity),1,true)
	var teeth:=PackedVector2Array()
	for index: int in range(32):
		var angle: float=-PI*.5+TAU*float(index)/32.0
		var tooth_radius: float=radius*(.58 if index%4 in [0,1] else .45)
		teeth.append(center+Vector2(cos(angle),sin(angle))*tooth_radius)
	draw_colored_polygon(teeth,_color("eff3ef",opacity))
	draw_circle(center,radius*.23,background)

func _draw_caption(caption: String,rect: Rect2,font_size: int,opacity: float) -> void:
	var lines: PackedStringArray=caption.split("\n")
	var font_scale: float=clampf(rect.size.y/64,.8,1.25)
	var pixels: int=roundi(font_size*font_scale)
	var spacing: float=float(pixels)*1.28
	var baseline: float=rect.get_center().y-float(lines.size()-1)*spacing*.5+pixels*.34
	for index: int in range(lines.size()):
		var width: float=_font.get_string_size(lines[index],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
		draw_string(_font,Vector2(rect.position.x+maxf(5,(rect.size.x-width)*.5),baseline+index*spacing),lines[index],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-10,pixels,_color("eff3ef",opacity))

func _fire_action(action: String,expected_target: int=-1) -> void:
	if not enabled or preview_mode:return
	if action.begins_with("weapon_"):weapon_pressed.emit(action.trim_prefix("weapon_"))
	elif action=="reload":reload_pressed.emit()
	elif action=="interact" and expected_target>=0 and expected_target==_interact_target:interact_pressed.emit(expected_target)
	elif action=="heal":medkit_pressed.emit()
	elif action=="menu":menu_pressed.emit()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_PAUSED]:release_all()
	elif what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():release_all()

func set_status(medkits: int,reloading: bool,searching: bool,interact_target: int=-1) -> void:
	_medkits=medkits
	_reloading=reloading
	_searching=searching
	set_interact_target(interact_target)
	queue_redraw()

func set_interact_target(interact_target: int) -> void:
	if interact_target!=_interact_target:
		_interact_target=interact_target
		# A touch cannot survive leaving a crate or switching to a different one.
		for index: int in _action_owners.keys():
			if str(_action_owners[index].action)=="interact":_action_owners.erase(index)
	queue_redraw()

func set_weapons(weapons: Array) -> void:
	_weapons=weapons
	queue_redraw()
