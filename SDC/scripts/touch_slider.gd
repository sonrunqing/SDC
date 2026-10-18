extends Control
## A horizontal touch gesture edits the value; vertical gestures scroll the page.
signal value_changed(value: float)
var min_value: float = 0.0
var max_value: float = 1.0
var step: float = 0.01
var value: float = 0.0:
	set(next):
		var bounded: float = clampf(next,min_value,max_value)
		if step>0:bounded=clampf(min_value+roundf((bounded-min_value)/step)*step,min_value,max_value)
		if is_equal_approx(value,bounded):return
		value=bounded
		queue_redraw()
		value_changed.emit(value)
var editable: bool = true
var _pointer: int = -1
var _start := Vector2.ZERO
var _horizontal: bool = false
var _vertical: bool = false

func _ready() -> void:
	add_to_group("mobile_touch_gesture")
	mouse_filter=Control.MOUSE_FILTER_PASS
	focus_mode=Control.FOCUS_NONE
	custom_minimum_size.y=maxf(64,custom_minimum_size.y)

func _gui_input(event: InputEvent) -> void:
	if not editable:return
	var modals: Array[Node]=get_tree().get_nodes_in_group("mobile_touch_modal")
	if not modals.is_empty() and not modals.back().is_ancestor_of(self):
		_pointer=-1
		_horizontal=false
		_vertical=false
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and _pointer==-1:
			_pointer=event.index
			_start=event.position
			_horizontal=false
			_vertical=false
		elif not event.pressed and event.index==_pointer:
			var scrolling: bool=false
			var ancestor: Node=get_parent()
			while ancestor!=null:
				if bool(ancestor.get_meta("touch_scrolling",false)):scrolling=true
				ancestor=ancestor.get_parent()
			if not event.canceled and not _vertical and not scrolling and (_horizontal or event.position.distance_to(_start)<=12):
				_set_from_position(event.position)
			_pointer=-1
			_horizontal=false
			_vertical=false
			queue_redraw()
	elif event is InputEventScreenDrag and event.index==_pointer:
		var delta: Vector2=event.position-_start
		if not _horizontal and not _vertical:
			if absf(delta.y)>12 and absf(delta.y)>absf(delta.x):_vertical=true
			elif absf(delta.x)>12 and absf(delta.x)>=absf(delta.y):
				_horizontal=true
				_cancel_parent_scroll()
		if _horizontal:
			_set_from_position(event.position)
			accept_event()

func _cancel_parent_scroll() -> void:
	var ancestor: Node=get_parent()
	while ancestor!=null:
		if ancestor.has_method("cancel_gesture"):ancestor.call("cancel_gesture")
		ancestor=ancestor.get_parent()

func _set_from_position(at: Vector2) -> void:
	var span: float=maxf(1,size.x-40)
	value=lerpf(min_value,max_value,clampf((at.x-20)/span,0,1))

func _draw() -> void:
	var amount: float=0 if is_equal_approx(min_value,max_value) else (value-min_value)/(max_value-min_value)
	var left:=Vector2(20,size.y*.5)
	var right:=Vector2(maxf(20,size.x-20),size.y*.5)
	var handle:=left.lerp(right,clampf(amount,0,1))
	draw_line(left,right,Color("384b53"),8,true)
	draw_line(left,handle,Color("afc1c1"),8,true)
	draw_circle(handle,16,Color("e3eeed") if editable else Color("66777c"))
	if _horizontal:draw_circle(handle,22,Color(1,1,1,.15))

func cancel_gesture() -> void:
	_pointer=-1
	_horizontal=false
	_vertical=false
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_PAUSED] or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):cancel_gesture()
