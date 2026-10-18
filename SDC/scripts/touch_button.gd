extends Button
## A swipe cancels activation; only a release without movement activates.
var _pointer: int = -99
var _start: Vector2
var _cancelled: bool = false
var minimum_touch_height: float = 72
func _ready() -> void:
	add_to_group("mobile_touch_gesture")
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
	var modals: Array[Node]=get_tree().get_nodes_in_group("mobile_touch_modal")
	if not modals.is_empty() and not modals.back().is_ancestor_of(self):
		_pointer=-99
		cancel_tap()
		return
	if disabled:return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:_begin(event.index,event.position)
		elif event.index==_pointer:_end(event.position,event.canceled)
	elif event is InputEventScreenDrag and event.index==_pointer:
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
		if toggle_mode:button_pressed=not button_pressed
		AppSettings.ui_feedback()
		pressed.emit()
func cancel_tap() -> void:
	_cancelled=true
	self_modulate=Color.WHITE
func cancel_gesture() -> void:
	_pointer=-99
	cancel_tap()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_PAUSED] or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		_pointer=-99
		cancel_tap()
