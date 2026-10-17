extends ScrollContainer
var _pointer: int = -99
var _start: Vector2
var _velocity: float = 0
var _touch_at: int = -1000
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch_at=Time.get_ticks_msec()
		if event.pressed:_begin(event.index,event.position)
		elif event.index==_pointer:_end()
	elif event is InputEventScreenDrag and event.index==_pointer:_drag(event.position,event.relative)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.device==-1 and Time.get_ticks_msec()-_touch_at<500:return
		if event.pressed:_begin(-2,event.position)
		elif _pointer==-2:_end()
	elif event is InputEventMouseMotion and _pointer==-2:_drag(event.position,event.relative)
func _begin(pointer: int, at: Vector2) -> void:
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
