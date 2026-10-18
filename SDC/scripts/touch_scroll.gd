extends ScrollContainer
var _pointer: int = -99
var _start: Vector2
var _velocity: float = 0
func _ready() -> void:
	add_to_group("mobile_touch_gesture")
	mouse_filter=Control.MOUSE_FILTER_STOP
	horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
func _gui_input(event: InputEvent) -> void:
	var modals: Array[Node]=get_tree().get_nodes_in_group("mobile_touch_modal")
	if not modals.is_empty() and not modals.back().is_ancestor_of(self):
		cancel_gesture()
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:_begin(event.index,event.position)
		elif event.index==_pointer:_end()
	elif event is InputEventScreenDrag and event.index==_pointer:_drag(event.position,event.relative)
func _begin(pointer: int, at: Vector2) -> void:
	if _pointer!=-99:return
	_pointer=pointer
	_start=at
	_velocity=0
	set_meta("touch_scrolling",false)
func _drag(at: Vector2, relative: Vector2) -> void:
	if absf(at.y-_start.y)>12:set_meta("touch_scrolling",true)
	if bool(get_meta("touch_scrolling",false)):
		scroll_vertical-=roundi(relative.y)
		_velocity=-relative.y*40
		accept_event()
func _end() -> void:
	_pointer=-99
	call_deferred("_clear_scrolling")
func _clear_scrolling() -> void:set_meta("touch_scrolling",false)
func _process(delta: float) -> void:
	if _pointer==-99 and absf(_velocity)>4:
		scroll_vertical+=roundi(_velocity*delta)
		_velocity=move_toward(_velocity,0,2000*delta)
func cancel_gesture() -> void:
	_pointer=-99
	_velocity=0
	set_meta("touch_scrolling",false)
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_PAUSED] or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):cancel_gesture()
