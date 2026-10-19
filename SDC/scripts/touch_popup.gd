extends PanelContainer
## A contextual window lives in a CanvasLayer, never in the page's layout.
const TouchButton=preload("res://scripts/touch_button.gd")
const TouchScroll=preload("res://scripts/touch_scroll.gd")
var body: VBoxContainer
var actions: GridContainer
var _title: Label
var _scroll: ScrollContainer
var _owner: Control

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("18262d")
	style.border_color=Color("778c91")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(12)
	style.shadow_color=Color(0,0,0,.45)
	style.shadow_size=12
	add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	add_child(column)
	var heading:=HBoxContainer.new()
	column.add_child(heading)
	_title=Label.new()
	_title.add_theme_font_size_override("font_size",20)
	_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(_title)
	var close:=TouchButton.new()
	close.text="×"
	close.minimum_touch_height=44
	close.custom_minimum_size=Vector2(44,44)
	close.pressed.connect(dismiss)
	heading.add_child(close)
	_scroll=TouchScroll.new()
	_scroll.custom_minimum_size=Vector2(0,60)
	_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	body=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",8)
	_scroll.add_child(body)
	actions=GridContainer.new()
	actions.columns=3
	actions.add_theme_constant_override("h_separation",6)
	actions.add_theme_constant_override("v_separation",6)
	column.add_child(actions)
	hide()

func open_at(anchor: Rect2,owner: Control,dimensions: Vector2 = Vector2(370,390)) -> void:
	_owner=owner
	var viewport_size: Vector2=get_viewport_rect().size
	var margin: float=16
	size=Vector2(minf(dimensions.x,viewport_size.x-margin*2),minf(dimensions.y,viewport_size.y*.76))
	position=Vector2(anchor.end.x+12,anchor.position.y)
	if position.x+size.x>viewport_size.x-margin:position.x=anchor.position.x-size.x-12
	position.x=clampf(position.x,margin,viewport_size.x-size.x-margin)
	position.y=clampf(position.y,margin,viewport_size.y-size.y-margin)
	if is_in_group("mobile_touch_modal"):remove_from_group("mobile_touch_modal")
	add_to_group("mobile_touch_modal")
	add_to_group("mobile_touch_popup")
	show()

func dismiss() -> void:
	if is_in_group("mobile_touch_modal"):remove_from_group("mobile_touch_modal")
	if is_in_group("mobile_touch_popup"):remove_from_group("mobile_touch_popup")
	if is_instance_valid(_scroll):_scroll.cancel_gesture()
	hide()

func _input(event: InputEvent) -> void:
	if not visible:return
	var modals: Array[Node]=get_tree().get_nodes_in_group("mobile_touch_modal")
	if not modals.is_empty() and modals.back()!=self:return
	# Dismiss on outside press, then let that same touch select/place/scroll.
	if event is InputEventScreenTouch and event.pressed and not get_global_rect().has_point(event.position):dismiss()

func _process(_delta: float) -> void:
	if visible and (not is_instance_valid(_owner) or not _owner.is_visible_in_tree()):dismiss()

func _exit_tree() -> void:
	if is_in_group("mobile_touch_modal"):remove_from_group("mobile_touch_modal")
