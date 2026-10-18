extends LineEdit
## A valid touch release opens the phone keyboard; a vertical swipe keeps scrolling.
var _touch_owner: int=-1
var _touch_start := Vector2.ZERO
var _tap_cancelled: bool=false

func _ready() -> void:
	add_to_group("mobile_touch_gesture")
	focus_mode=Control.FOCUS_CLICK
	mouse_filter=Control.MOUSE_FILTER_PASS
	virtual_keyboard_enabled=true
	virtual_keyboard_show_on_focus=true
	shortcut_keys_enabled=false
	context_menu_enabled=false
	emoji_menu_enabled=false
	middle_mouse_paste_enabled=false
	drag_and_drop_selection_enabled=false
	clear_button_enabled=false
	custom_minimum_size.y=maxf(56,custom_minimum_size.y)
	text_submitted.connect(func(_text: String) -> void:
		unedit()
		release_focus())

func _gui_input(event: InputEvent) -> void:
	var modals: Array[Node]=get_tree().get_nodes_in_group("mobile_touch_modal")
	if not modals.is_empty() and not modals.back().is_ancestor_of(self):
		_touch_owner=-1
		_tap_cancelled=true
		return
	if not editable:return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			if _touch_owner!=-1:return
			_touch_owner=event.index
			_touch_start=event.position
			_tap_cancelled=false
		elif event.index==_touch_owner:
			_touch_owner=-1
			var activate: bool=not event.canceled and not _tap_cancelled and Rect2(Vector2.ZERO,size).has_point(event.position)
			var ancestor: Node=get_parent()
			while ancestor!=null:
				if bool(ancestor.get_meta("touch_scrolling",false)):activate=false
				ancestor=ancestor.get_parent()
			if activate:
				var scroll_parent: Node=get_parent()
				while scroll_parent!=null:
					if scroll_parent is ScrollContainer and scroll_parent.has_method("cancel_gesture"):scroll_parent.call("cancel_gesture")
					scroll_parent=scroll_parent.get_parent()
				caret_column=text.length()
				if is_editing():unedit()
				edit(true)
				accept_event()
	elif event is InputEventScreenDrag and event.index==_touch_owner:
		if event.position.distance_to(_touch_start)>12:_tap_cancelled=true

func cancel_gesture() -> void:
	_touch_owner=-1
	_tap_cancelled=true
	if is_inside_tree() and is_editing():
		unedit()
		release_focus()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_PAUSED] or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):cancel_gesture()
