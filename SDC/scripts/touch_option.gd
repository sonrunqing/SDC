extends "res://scripts/touch_button.gd"
## A touch list in this viewport replaces mouse-driven native popup menus.
signal item_selected(index: int)
var selected: int=-1
var fit_to_longest_item: bool=true
var item_count: int:
	get:return _items.size()
var _items: Array[Dictionary]=[]
var _modal: CanvasLayer

func _init() -> void:
	clip_text=true
	text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS

func _ready() -> void:
	super._ready()
	pressed.connect(_open_options)

func add_item(caption: String,id: int=-1) -> void:
	_items.append({"text":caption,"id":_items.size() if id<0 else id,"metadata":null,"disabled":false})
	if selected<0:select(0)

func clear() -> void:
	_items.clear()
	selected=-1
	text=""
	if is_instance_valid(_modal):_modal.call("request_cancel")

func select(index: int) -> void:
	if index<0 or index>=_items.size():return
	selected=index
	text=str(_items[index].text)+"  ▾"

func set_item_metadata(index: int,metadata: Variant) -> void:
	if index>=0 and index<_items.size():_items[index].metadata=metadata

func get_item_metadata(index: int) -> Variant:
	return _items[index].metadata if index>=0 and index<_items.size() else null

func set_item_disabled(index: int,is_disabled: bool) -> void:
	if index>=0 and index<_items.size():_items[index].disabled=is_disabled

func get_item_text(index: int) -> String:
	return str(_items[index].text) if index>=0 and index<_items.size() else ""

func get_popup() -> Control:
	# Existing callers use this only to set fonts and spacing, not popup input.
	return self

func _open_options() -> void:
	if disabled or _items.is_empty() or is_instance_valid(_modal):return
	get_tree().call_group("mobile_touch_gesture","cancel_gesture")
	var input_field: Control=get_viewport().gui_get_focus_owner()
	if input_field is LineEdit:
		input_field.unedit()
		input_field.release_focus()
	var modal:=ChoiceModal.new()
	modal.choice_items=_items.duplicate(true)
	modal.choice_selected=selected
	var ancestor: Node=self
	while ancestor!=null:
		if ancestor is Control and ancestor.theme!=null:
			modal.choice_theme=ancestor.theme
			break
		ancestor=ancestor.get_parent()
	modal.chosen.connect(_choose)
	modal.tree_exiting.connect(func() -> void:_modal=null)
	_modal=modal
	modal.add_to_group("mobile_touch_modal")
	get_viewport().add_child(modal)

func _choose(index: int) -> void:
	if index<0 or index>=_items.size() or bool(_items[index].disabled):return
	select(index)
	item_selected.emit(index)

func _exit_tree() -> void:
	if is_instance_valid(_modal):_modal.call("request_cancel")

class ChoiceModal extends CanvasLayer:
	signal chosen(index: int)
	var choice_items: Array[Dictionary]=[]
	var choice_selected: int=-1
	var choice_theme: Theme
	var _root: Control
	var _panel: PanelContainer
	var _outside_pointer: int=-1
	var _outside_start:=Vector2.ZERO
	var _closing: bool=false

	func _ready() -> void:
		layer=100
		process_mode=Node.PROCESS_MODE_ALWAYS
		_root=Control.new()
		_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_root.mouse_filter=Control.MOUSE_FILTER_STOP
		if choice_theme!=null:_root.theme=choice_theme
		add_child(_root)
		var shade:=ColorRect.new()
		shade.color=Color(0,0,0,.7)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_root.add_child(shade)
		_root.gui_input.connect(_outside_input)
		_panel=PanelContainer.new()
		_panel.mouse_filter=Control.MOUSE_FILTER_STOP
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("17262e")
		style.border_color=Color("52646c")
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.content_margin_left=16
		style.content_margin_right=16
		style.content_margin_top=12
		style.content_margin_bottom=12
		_panel.add_theme_stylebox_override("panel",style)
		_root.add_child(_panel)
		var body:=VBoxContainer.new()
		body.add_theme_constant_override("separation",10)
		_panel.add_child(body)
		var header:=HBoxContainer.new()
		body.add_child(header)
		var title:=Label.new()
		title.text="选择选项"
		title.add_theme_font_size_override("font_size",24)
		title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		header.add_child(title)
		var close_button:=preload("res://scripts/touch_button.gd").new()
		close_button.text="关闭"
		close_button.minimum_touch_height=60
		close_button.custom_minimum_size=Vector2(100,60)
		close_button.pressed.connect(request_cancel)
		header.add_child(close_button)
		var scroll:=preload("res://scripts/touch_scroll.gd").new()
		scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
		body.add_child(scroll)
		var list:=VBoxContainer.new()
		list.add_theme_constant_override("separation",8)
		list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		for index: int in range(choice_items.size()):
			var item: Dictionary=choice_items[index]
			var button:=preload("res://scripts/touch_button.gd").new()
			button.text=("✓  " if index==choice_selected else "")+str(item.text)
			button.disabled=bool(item.disabled)
			button.custom_minimum_size=Vector2(0,72)
			button.add_theme_font_size_override("font_size",22)
			button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			button.pressed.connect(_select_item.bind(index))
			list.add_child(button)
		_root.resized.connect(_layout)
		call_deferred("_layout")

	func _layout() -> void:
		var safe: Vector4=AppSettings.safe_insets(_root)
		var available: Vector2=(_root.size-Vector2(safe.x+safe.z,safe.y+safe.w)).max(Vector2.ONE)
		_panel.size=Vector2(minf(720,available.x),minf(620,available.y))
		_panel.position=Vector2(safe.x,safe.y)+(available-_panel.size)*.5

	func _outside_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed and not event.canceled and _outside_pointer==-1:
				_outside_pointer=event.index
				_outside_start=event.position
			elif not event.pressed and event.index==_outside_pointer:
				_outside_pointer=-1
				if not event.canceled and event.position.distance_to(_outside_start)<=12:request_cancel()

	func _select_item(index: int) -> void:
		if _closing:return
		_closing=true
		hide()
		remove_from_group("mobile_touch_modal")
		chosen.emit(index)
		queue_free()

	func request_cancel() -> void:
		if _closing:return
		_closing=true
		hide()
		remove_from_group("mobile_touch_modal")
		queue_free()

	func _notification(what: int) -> void:
		if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and is_inside_tree():request_cancel()
