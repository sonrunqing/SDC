extends Button
## A swipe cancels activation; only a release without movement activates.
var _pointer: int = -99
var _start: Vector2
var _cancelled: bool = false
var _touch_at: int = -1000
var minimum_touch_height: float = 72
func _ready() -> void:
	button_mask=0
	mouse_filter=Control.MOUSE_FILTER_STOP
	var ancestor: Node = get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:
			mouse_filter=Control.MOUSE_FILTER_PASS
			break
		ancestor=ancestor.get_parent()
	focus_mode=Control.FOCUS_NONE
	custom_minimum_size.y=maxf(minimum_touch_height,custom_minimum_size.y)
func _gui_input(event: InputEvent) -> void:
	if disabled:return
	if event is InputEventScreenTouch:
		_touch_at=Time.get_ticks_msec()
		if event.pressed and not event.canceled:_begin(event.index,event.position)
		elif event.index==_pointer:_end(event.position,event.canceled)
	elif event is InputEventScreenDrag and event.index==_pointer:
		if event.position.distance_to(_start)>12:cancel_tap()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.device==-1 and Time.get_ticks_msec()-_touch_at<500:return
		if event.pressed:_begin(-2,event.position)
		elif _pointer==-2:_end(event.position,false)
	elif event is InputEventMouseMotion and _pointer==-2:
		if event.position.distance_to(_start)>12:cancel_tap()
func _begin(pointer: int, at: Vector2) -> void:
	if _pointer!=-99:return
	_pointer=pointer
	_start=at
	_cancelled=false
	self_modulate=Color(.84,.84,.84,1)
	button_down.emit()
func _end(at: Vector2, cancelled: bool) -> void:
	var activate: bool = not cancelled and not _cancelled and Rect2(Vector2.ZERO,size).has_point(at)
	var ancestor: Node = get_parent()
	while ancestor!=null:
		if bool(ancestor.get_meta("touch_scrolling",false)):activate=false
		ancestor=ancestor.get_parent()
	_pointer=-99
	self_modulate=Color.WHITE
	button_up.emit()
	if activate:
		AppSettings.ui_feedback()
		pressed.emit()
func cancel_tap() -> void:
	_cancelled=true
	self_modulate=Color.WHITE
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		_pointer=-99
		cancel_tap()
