extends Control
signal closed(saved: bool)
const Layout = preload("res://scripts/control_layout.gd")
const TouchButton = preload("res://scripts/touch_button.gd")
const TouchOption = preload("res://scripts/touch_option.gd")
const TouchSlider = preload("res://scripts/touch_slider.gd")
var _profile: int=0
var _draft: Dictionary={}
var _selected: String="fire"
var _canvas: Control
var _preview_host: Control
var _picker: TouchOption
var _scale_slider: TouchSlider
var _scale_number: Label
var _opacity_slider: TouchSlider
var _opacity_number: Label
var _visibility_button: Button
var _status: Label
var _save_button: Button
var _source_size := Vector2.ZERO
var _source_safe := Vector4.ZERO
var _prior_paused: bool=false
var _owns_pause: bool=false
var _closing: bool=false
var _syncing: bool=false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	_profile=AppSettings.active_control_profile
	_source_size=get_viewport_rect().size
	_source_safe=AppSettings.safe_insets(self)
	_draft=Layout.resolve(AppSettings.get_control_layout(_profile),_source_size,_source_safe,float(AppSettings.values.control_scale),float(AppSettings.values.control_opacity))
	_prior_paused=get_tree().paused
	_owns_pause=true
	get_tree().paused=true
	_build()
	resized.connect(_resize_preview)
	_sync_inspector()
	call_deferred("_resize_preview")

func _button(text_value: String,callback: Callable,width: float = 0) -> Button:
	var button:=TouchButton.new()
	button.text=text_value
	button.minimum_touch_height=52
	button.custom_minimum_size=Vector2(width,52)
	button.add_theme_font_size_override("font_size",20)
	button.pressed.connect(callback)
	return button

func _label(caption: String,pixels: int = 20) -> Label:
	var label:=Label.new()
	label.text=caption
	label.add_theme_font_size_override("font_size",pixels)
	return label

func _build() -> void:
	var backdrop:=ColorRect.new()
	backdrop.color=Color("0b141a")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",roundi(_source_safe.x))
	margin.add_theme_constant_override("margin_right",roundi(_source_safe.z))
	margin.add_theme_constant_override("margin_top",roundi(_source_safe.y))
	margin.add_theme_constant_override("margin_bottom",roundi(_source_safe.w))
	add_child(margin)
	var root:=VBoxContainer.new()
	root.add_theme_constant_override("separation",12)
	margin.add_child(root)
	var header:=HBoxContainer.new()
	header.add_theme_constant_override("separation",10)
	root.add_child(header)
	var title:=_label("自定义操作按键 · 方案 %d"%(_profile+1),25)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("取消",request_cancel,90))
	header.add_child(_button("重置本方案",_reset_profile,142))
	_save_button=_button("保存并应用",_save,148)
	header.add_child(_save_button)
	var body:=HBoxContainer.new()
	body.add_theme_constant_override("separation",16)
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	root.add_child(body)
	_preview_host=Control.new()
	_preview_host.custom_minimum_size=Vector2(420,240)
	_preview_host.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_preview_host.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_preview_host.clip_contents=true
	body.add_child(_preview_host)
	_canvas=preload("res://scripts/ui_control_layout_canvas.gd").new()
	_canvas.configure(_draft,_source_size,_source_safe,_selected)
	_canvas.selection_changed.connect(_select)
	_canvas.layout_changed.connect(_layout_changed)
	_preview_host.add_child(_canvas)
	_preview_host.resized.connect(_resize_preview)
	var panel:=PanelContainer.new()
	panel.custom_minimum_size.x=286
	body.add_child(panel)
	var scroll:=preload("res://scripts/touch_scroll.gd").new()
	panel.add_child(scroll)
	var tools:=VBoxContainer.new()
	tools.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	tools.add_theme_constant_override("separation",12)
	scroll.add_child(tools)
	tools.add_child(_label("选择按键",21))
	_picker=TouchOption.new()
	_picker.custom_minimum_size=Vector2(250,52)
	for id: String in Layout.IDS:_picker.add_item(str(Layout.TITLES[id]))
	_picker.item_selected.connect(func(index: int) -> void:_select(Layout.IDS[index]))
	tools.add_child(_picker)
	var scale_parts: Array=_slider(tools,"大小",.65,1.8,.05)
	_scale_slider=scale_parts[0]
	_scale_number=scale_parts[1]
	_scale_slider.value_changed.connect(_change_scale)
	var opacity_parts: Array=_slider(tools,"透明度",.2,1,.05)
	_opacity_slider=opacity_parts[0]
	_opacity_number=opacity_parts[1]
	_opacity_slider.value_changed.connect(_change_opacity)
	tools.add_child(_label("位置微调",20))
	var arrows:=HBoxContainer.new()
	arrows.add_theme_constant_override("separation",6)
	tools.add_child(arrows)
	for data: Array in [["←",Vector2(-4,0)],["↑",Vector2(0,-4)],["↓",Vector2(0,4)],["→",Vector2(4,0)]]:
		var direction: Vector2=data[1]
		arrows.add_child(_button(str(data[0]),func() -> void:_canvas.move_selected(direction),52))
	_visibility_button=_button("",_toggle_visibility)
	tools.add_child(_visibility_button)
	tools.add_child(_button("重置所选按键",_reset_selected))
	var note:=_label("在左侧拖动按键。\n缩放与位置会同时改变实际点击范围。\n重叠位置会标红，分开后即可保存。",17)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(note)
	_status=_label("",18)
	_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y=30
	root.add_child(_status)

func _slider(parent: Node,caption: String,minimum: float,maximum: float,step_value: float) -> Array:
	var row:=HBoxContainer.new()
	parent.add_child(row)
	var title:=_label(caption)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var number:=_label("")
	row.add_child(number)
	var slider:=TouchSlider.new()
	slider.min_value=minimum
	slider.max_value=maximum
	slider.step=step_value
	slider.custom_minimum_size=Vector2(250,52)
	parent.add_child(slider)
	return [slider,number]

func _resize_preview() -> void:
	if not is_instance_valid(_preview_host) or _closing:return
	_source_size=get_viewport_rect().size
	_source_safe=AppSettings.safe_insets(self)
	_canvas.configure(_draft,_source_size,_source_safe,_selected)
	var available: Vector2=(_preview_host.size-Vector2(12,12)).max(Vector2.ONE)
	var factor: float=minf(available.x/_source_size.x,available.y/_source_size.y)
	_canvas.scale=Vector2.ONE*factor
	_canvas.position=(_preview_host.size-_source_size*factor)*.5
	_update_validation()

func _select(id: String) -> void:
	_selected=id
	_canvas.select_control(id)
	_sync_inspector()

func _sync_inspector() -> void:
	_syncing=true
	_picker.select(Layout.IDS.find(_selected))
	_scale_slider.value=float(_draft[_selected].scale)
	_opacity_slider.value=float(_draft[_selected].opacity)
	_scale_number.text="%d%%"%roundi(float(_draft[_selected].scale)*100)
	_opacity_number.text="%d%%"%roundi(float(_draft[_selected].opacity)*100)
	_visibility_button.disabled=_selected in Layout.REQUIRED
	_visibility_button.text="此按键保持显示" if _selected in Layout.REQUIRED else ("隐藏此按键" if bool(_draft[_selected].visible) else "显示此按键")
	_syncing=false
	_update_validation()

func _change_scale(value: float) -> void:
	if _syncing:return
	_draft[_selected].scale=value
	_scale_number.text="%d%%"%roundi(value*100)
	_layout_changed()

func _change_opacity(value: float) -> void:
	if _syncing:return
	_draft[_selected].opacity=value
	_opacity_number.text="%d%%"%roundi(value*100)
	_layout_changed()

func _toggle_visibility() -> void:
	if _selected in Layout.REQUIRED:return
	_draft[_selected].visible=not bool(_draft[_selected].visible)
	_layout_changed()
	_sync_inspector()

func _reset_selected() -> void:
	_draft[_selected]=Layout.defaults(_source_size,_source_safe)[_selected]
	_layout_changed()
	_sync_inspector()

func _reset_profile() -> void:
	_draft=Layout.defaults(_source_size,_source_safe)
	_canvas.cancel_drag()
	_canvas.configure(_draft,_source_size,_source_safe,_selected)
	_sync_inspector()

func _layout_changed() -> void:
	_canvas.refresh_preview()
	_update_validation()

func _update_validation() -> void:
	if not is_instance_valid(_status):return
	var conflicts: Array[String]=Layout.collisions(_draft,Layout.rectangles(_draft,_source_size,_source_safe))
	_save_button.disabled=not conflicts.is_empty()
	if conflicts.is_empty():
		_status.text="拖动调整位置，选中后调整大小和透明度。保存后应用到方案 %d。"%(_profile+1)
		_status.add_theme_color_override("font_color",Color("b3c6bd"))
	else:
		var names: Array[String]=[]
		for id: String in conflicts:names.append(str(Layout.TITLES[id]))
		_status.text="按键重叠："+"、".join(names)+"。请移动或缩小后保存。"
		_status.add_theme_color_override("font_color",Color("ec9287"))

func _save() -> void:
	if _closing:return
	_update_validation()
	if _save_button.disabled:return
	var result: Error=AppSettings.save_control_layout(_profile,_draft)
	if result!=OK:
		_status.text="布局未能保存，请检查可用存储空间后重试。"
		_status.add_theme_color_override("font_color",Color("ec9287"))
		return
	_close(true)

func request_cancel() -> void:
	_close(false)

func _close(saved: bool) -> void:
	if _closing:return
	_closing=true
	_canvas.cancel_drag()
	_restore_pause()
	closed.emit(saved)
	queue_free()

func _restore_pause() -> void:
	if _owns_pause and get_tree()!=null:
		get_tree().paused=_prior_paused
		_owns_pause=false

func _exit_tree() -> void:
	_restore_pause()
