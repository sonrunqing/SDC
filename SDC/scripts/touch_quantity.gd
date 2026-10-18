extends HBoxContainer
## Large touch controls retain the quantity interface used by shop and loadout.
signal value_changed(value: float)
const TouchButton=preload("res://scripts/touch_button.gd")
const TouchLineEdit=preload("res://scripts/touch_line_edit.gd")
var min_value: float=0
var max_value: float=999
var step: float=1
var rounded: bool=true
var allow_greater: bool=false
var allow_lesser: bool=false
var editable: bool=true:
	set(next):
		editable=next
		_edit.editable=next
		if is_instance_valid(_minus):_minus.disabled=not next
		if is_instance_valid(_plus):_plus.disabled=not next
var _stored_value: float=0
var value: float:
	get:return _stored_value
	set(next):
		_store_value(next,true)
var _edit: LineEdit=TouchLineEdit.new()
var _minus: Button
var _plus: Button

func _ready() -> void:
	custom_minimum_size.y=maxf(64,custom_minimum_size.y)
	add_theme_constant_override("separation",6)
	_minus=_make_button("−",-1)
	add_child(_minus)
	_edit.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_NUMBER
	_edit.alignment=HORIZONTAL_ALIGNMENT_CENTER
	_edit.custom_minimum_size=Vector2(76,64)
	_edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_edit.text=_number(value)
	_edit.editable=editable
	_edit.text_changed.connect(_entered)
	add_child(_edit)
	_plus=_make_button("+",1)
	add_child(_plus)

func get_line_edit() -> LineEdit:
	return _edit

func _make_button(caption: String,direction: int) -> Button:
	var button:=TouchButton.new()
	button.text=caption
	button.minimum_touch_height=64
	button.custom_minimum_size=Vector2(60,64)
	button.disabled=not editable
	button.pressed.connect(func() -> void:
		if not editable:return
		var entered: String=_edit.text.strip_edges()
		var current: float=float(entered) if entered.is_valid_float() else value
		value=clampf(current+step*direction,min_value,max_value))
	return button

func _entered(entered: String) -> void:
	if not entered.is_valid_float():return
	# Keep the input text and caret intact while the phone keyboard is composing.
	_store_value(float(entered),false)

func _store_value(next: float,rewrite_text: bool) -> void:
	var bounded: float=next
	if not allow_lesser:bounded=maxf(min_value,bounded)
	if not allow_greater:bounded=minf(max_value,bounded)
	if rounded:bounded=roundf(bounded)
	var changed: bool=not is_equal_approx(_stored_value,bounded)
	_stored_value=bounded
	if rewrite_text and _edit.text!=_number(value):_edit.text=_number(value)
	if changed:value_changed.emit(value)

func _number(number: float) -> String:
	return str(roundi(number)) if rounded else str(number)
