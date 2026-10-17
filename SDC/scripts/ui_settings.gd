extends HBoxContainer
const TouchButton = preload("res://scripts/touch_button.gd")
const TouchScroll = preload("res://scripts/touch_scroll.gd")
var _page: String = "画面"
var _body: VBoxContainer
var _tabs: Dictionary = {}
func _ready() -> void:
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",20)
	var tabs:=VBoxContainer.new()
	tabs.custom_minimum_size.x=176
	tabs.add_theme_constant_override("separation",12)
	add_child(tabs)
	for name: String in ["画面","声音","操控","界面"]:
		var button:=TouchButton.new()
		button.text=name
		button.custom_minimum_size=Vector2(176,72)
		button.pressed.connect(func() -> void:_page=name;_populate())
		tabs.add_child(button)
		_tabs[name]=button
	var panel:=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_child(panel)
	var scroll:=TouchScroll.new()
	panel.add_child(scroll)
	_body=VBoxContainer.new()
	_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation",14)
	scroll.add_child(_body)
	_populate()
func _populate() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	for name: String in _tabs:_tabs[name].modulate=Color.WHITE
	var title:=Label.new()
	title.text=_page+"设置"
	title.add_theme_font_size_override("font_size",28)
	_body.add_child(title)
	match _page:
		"画面":
			_choice("帧率上限","fps",["30 FPS","45 FPS","60 FPS","90 FPS","120 FPS"],[30,45,60,90,120])
			_choice("3D 渲染分辨率","resolution",["50% · 省电","67%","75%","100% · 原生"],[.5,.67,.75,1.0])
			_choice("画质","quality",["省电 · 关闭阴影","均衡","精细 · 更远视距"],[0,1,2])
			_slider("场景亮度","brightness",.6,1.4,.05)
			_note("分辨率只影响 3D 场景，文字和按钮保持清晰。实际帧率取决于设备与场景。")
		"声音":
			_slider("主音量","master",0,1,.05)
			_slider("枪声与环境音效","sfx",0,1,.05)
			_slider("界面提示音","ui_audio",0,1,.05)
			var preview:=TouchButton.new()
			preview.text="试听界面提示音"
			preview.pressed.connect(AppSettings.ui_feedback)
			_body.add_child(preview)
		"操控":
			_note("三指布局：左拇指移动，右拇指控制朝向，左上按钮独立开火。摇杆不触发射击。")
			_slider("摇杆与开火键大小","control_scale",.8,1.25,.05)
			_slider("触控透明度","control_opacity",.3,1,.05)
			_slider("瞄准灵敏度","aim_sensitivity",.5,2,.1)
			_slider("摇杆死区","deadzone",.05,.3,.01)
			var vibration:=CheckButton.new()
			vibration.text="触觉反馈"
			vibration.button_pressed=bool(AppSettings.values.vibration)
			vibration.custom_minimum_size.y=64
			vibration.toggled.connect(func(value: bool) -> void:AppSettings.set_value("vibration",value))
			_body.add_child(vibration)
		"界面":
			_slider("界面缩放","ui_scale",.85,1.2,.05)
			_choice("屏幕边缘留白","safe_margin",["标准","加宽","更宽","最大"],[24,30,40,48])
			_note("界面按屏幕比例排版，刘海和圆角区域会保留安全距离。仓库与商店使用独立的手势滚动。")
func _row(caption: String) -> HBoxContainer:
	var row:=HBoxContainer.new()
	row.custom_minimum_size.y=76
	row.add_theme_constant_override("separation",20)
	_body.add_child(row)
	var label:=Label.new()
	label.text=caption
	label.custom_minimum_size.x=228
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size",21)
	row.add_child(label)
	return row
func _choice(caption: String,key: String,labels: Array,options: Array) -> void:
	var row: HBoxContainer=_row(caption)
	var picker:=OptionButton.new()
	picker.custom_minimum_size=Vector2(310,64)
	picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	picker.add_theme_font_size_override("font_size",20)
	picker.get_popup().add_theme_font_size_override("font_size",20)
	picker.get_popup().add_theme_constant_override("v_separation",20)
	for i: int in range(labels.size()):
		picker.add_item(str(labels[i]))
		if str(AppSettings.values[key])==str(options[i]) or (options[i] is float and is_equal_approx(float(AppSettings.values[key]),float(options[i]))):picker.select(i)
	picker.item_selected.connect(func(index: int) -> void:AppSettings.set_value(key,options[index]))
	row.add_child(picker)
func _slider(caption: String,key: String,minimum: float,maximum: float,step_value: float) -> void:
	var row: HBoxContainer=_row(caption)
	var slider:=HSlider.new()
	slider.min_value=minimum
	slider.max_value=maximum
	slider.step=step_value
	slider.value=float(AppSettings.values[key])
	slider.custom_minimum_size=Vector2(250,64)
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var number:=Label.new()
	number.custom_minimum_size.x=74
	number.text="%d%%"%roundi(slider.value*100)
	row.add_child(number)
	slider.value_changed.connect(func(value: float) -> void:
		number.text="%d%%"%roundi(value*100)
		AppSettings.set_value(key,value))
func _note(text: String) -> void:
	var label:=Label.new()
	label.text=text
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_color",Color("a3b5ad"))
	_body.add_child(label)
