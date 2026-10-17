extends VBoxContainer
## Deployment controls. Building this view never changes the equipped kit or carry plan.

signal feedback(message: String, is_error: bool)

const PANEL := Color("14252f")
const TEAL := Color("66d8c3")
const TEXT := Color("e3eeed")
const MUTED := Color("829aab")
const SLOTS: Array[String] = ["primary", "secondary", "sidearm"]
const SLOT_NAMES: Dictionary = {"primary": "① 主武器", "secondary": "② 副武器", "sidearm": "③ 手枪"}
const MAX_ROUNDS: int = 100000

@export var compact: bool = false


func _ready() -> void:
	custom_minimum_size.x = 330
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 5 if compact else 7)
	rebuild()


func rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var title := _row(self, 6)
	title.add_child(_label("三武器配置", 14, TEAL))
	for slot: String in SLOTS:
		_weapon_row(slot)
	_ammo_plans()
	add_child(_label("携行上限  %.1f kg" % GameState.carry_capacity(), 13, TEAL))


func _weapon_row(slot: String) -> void:
	var weapon_id: String = str(GameState.loadout.get(slot, ""))
	var weapon: Dictionary = Catalog.get_item(weapon_id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL, Color("2a414d"), 7))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3 if compact else 4)
	panel.add_child(box)
	var line := _row(box, 6)
	var caption := _label(str(SLOT_NAMES[slot]), 12, MUTED)
	caption.custom_minimum_size.x = 69
	line.add_child(caption)
	var name_label := _label(str(weapon.get("name", "未装备")), 14, TEXT if not weapon.is_empty() else MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = str(weapon.get("name", "在仓库选择武器，装备到对应武器槽"))
	line.add_child(name_label)
	var active: bool = str(GameState.get("active_weapon_slot")) == slot
	var switch_button := _button("手持" if active else "切换", 43)
	switch_button.disabled = active or weapon.is_empty() or GameState.raid_active
	switch_button.tooltip_text = "当前手持武器" if active else "将此武器设为手持"
	if active:
		switch_button.add_theme_color_override("font_disabled_color", TEAL)
	switch_button.pressed.connect(func() -> void:
		var ok: bool = bool(GameState.call("set_active_weapon", slot))
		_report(ok, "已切换手持武器")
	)
	line.add_child(switch_button)
	if weapon.is_empty():
		return
	var ammo_line := _row(box, 5)
	var ammo_picker := OptionButton.new()
	ammo_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_picker.fit_to_longest_item = false
	ammo_picker.clip_text = true
	ammo_picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ammo_picker.custom_minimum_size.y = 28 if compact else 30
	ammo_picker.add_theme_font_size_override("font_size", 12)
	ammo_picker.get_popup().add_theme_font_size_override("font_size", 12)
	ammo_picker.add_theme_stylebox_override("normal", _style(Color("192f39"), Color("324d59"), 6))
	ammo_picker.add_theme_stylebox_override("hover", _style(Color("192f39"), Color("324d59"), 6))
	ammo_picker.add_item("选择装填弹药")
	ammo_picker.set_item_disabled(0, true)
	ammo_picker.tooltip_text = "只显示口径匹配的弹药；选择不会购买弹药或更改携弹数量"
	var selected_ammo: String = str(_state_dictionary("weapon_ammo").get(slot, ""))
	var selected_index: int = 0
	for ammo: Dictionary in Catalog.by_kind("ammo"):
		if str(ammo.get("caliber", "")) != str(weapon.get("caliber", "")):
			continue
		var ammo_id: String = str(ammo.get("id", ""))
		ammo_picker.add_item("%s  ·  库存 %d" % [str(ammo.get("name", ammo_id)), int(GameState.stash.get(ammo_id, 0))])
		var index: int = ammo_picker.item_count - 1
		ammo_picker.set_item_metadata(index, ammo_id)
		if selected_ammo == ammo_id:
			selected_index = index
	# Connect only after setting the selection; reconstruction has no side effects.
	ammo_picker.select(selected_index)
	ammo_picker.disabled = GameState.raid_active or ammo_picker.item_count <= 1
	ammo_picker.item_selected.connect(func(index: int) -> void:
		if index <= 0:
			return
		var ammo_id: String = str(ammo_picker.get_item_metadata(index))
		var ok: bool = bool(GameState.call("select_weapon_ammo", slot, ammo_id))
		if not ok:
			ammo_picker.select(selected_index)
		_report(ok, "已更改装填弹药，请检查携弹数量")
	)
	ammo_line.add_child(ammo_picker)
	var remove_button := _button("卸下", 43)
	remove_button.disabled = GameState.raid_active
	remove_button.tooltip_text = "将武器及已安装配件退回仓库"
	remove_button.pressed.connect(func() -> void:
		var ok: bool = GameState.unequip(slot)
		_report(ok, "武器与配件已退回仓库")
	)
	ammo_line.add_child(remove_button)


func _ammo_plans() -> void:
	var plan: Dictionary = _state_dictionary("ammo_carry_plan")
	var selections: Dictionary = _state_dictionary("weapon_ammo")
	var ammo_ids: Array[String] = []
	var usage: Dictionary = {}
	for slot: String in SLOTS:
		if str(GameState.loadout.get(slot, "")).is_empty():
			continue
		var ammo_id: String = str(selections.get(slot, ""))
		if ammo_id.is_empty():
			continue
		if not ammo_ids.has(ammo_id):
			ammo_ids.append(ammo_id)
		usage[ammo_id] = int(usage.get(ammo_id, 0)) + 1
	# Keep nonzero plans visible even after a gun or its selected ammunition changes.
	for key: Variant in plan:
		var ammo_id: String = str(key)
		if int(plan[key]) > 0 and not ammo_ids.has(ammo_id):
			ammo_ids.append(ammo_id)
	add_child(_label("携弹计划", 13, TEAL))
	if ammo_ids.is_empty():
		return
	for ammo_id: String in ammo_ids:
		var ammo: Dictionary = Catalog.get_item(ammo_id)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		add_child(box)
		var heading := _row(box, 4)
		var shared: String = " · 共用" if int(usage.get(ammo_id, 0)) > 1 else (" · 未选用" if not usage.has(ammo_id) else "")
		var caption := _label(str(ammo.get("name", ammo_id)) + shared, 12, TEXT)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.tooltip_text = str(ammo.get("name", ammo_id)) + "；出击时按此型号的总携带数量从仓库扣除"
		heading.add_child(caption)
		heading.add_child(_label("库存 %d" % int(GameState.stash.get(ammo_id, 0)), 12, MUTED))
		var line := _row(box, 6)
		var quantity := SpinBox.new()
		quantity.min_value = 0
		quantity.max_value = MAX_ROUNDS
		quantity.allow_greater = true
		quantity.allow_lesser = true
		quantity.step = 1
		quantity.rounded = true
		quantity.value = int(plan.get(ammo_id, 0))
		quantity.custom_minimum_size = Vector2(104, 29)
		quantity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quantity.add_theme_font_size_override("font_size", 13)
		quantity.get_line_edit().add_theme_stylebox_override("normal", _style(Color("0e1b24"), Color("324d59"), 6))
		quantity.get_line_edit().add_theme_font_size_override("font_size", 13)
		quantity.editable = not GameState.raid_active
		quantity.tooltip_text = "输入总携带发数，点击应用保存；不会按库存自动减少"
		line.add_child(quantity)
		line.add_child(_label("发", 12, MUTED))
		var saved := _label("已设 %d" % int(plan.get(ammo_id, 0)), 12, MUTED)
		saved.custom_minimum_size.x = 65
		line.add_child(saved)
		var apply_button := _button("应用", 48)
		apply_button.disabled = GameState.raid_active
		apply_button.pressed.connect(func() -> void: _apply_plan(ammo_id, quantity))
		line.add_child(apply_button)


func _apply_plan(ammo_id: String, quantity: SpinBox) -> void:
	var entered: String = quantity.get_line_edit().text.strip_edges()
	if not entered.is_valid_int():
		feedback.emit("携弹数量必须是整数", true)
		return
	var count: int = int(entered)
	if count < 0 or count > MAX_ROUNDS:
		feedback.emit("携弹数量须在 0 至 %d 发之间" % MAX_ROUNDS, true)
		return
	var ok: bool = bool(GameState.call("set_ammo_carry", ammo_id, count))
	_report(ok, "已保存携弹计划：%d 发" % count)


func _report(ok: bool, success_message: String) -> void:
	feedback.emit(success_message if ok else (GameState.last_error if not GameState.last_error.is_empty() else "操作失败，请检查装备与库存"), not ok)


func _state_dictionary(property: String) -> Dictionary:
	var value: Variant = GameState.get(property)
	return value if value is Dictionary else {}


func _label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _row(parent: Node, separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	parent.add_child(row)
	return row


func _button(caption: String, min_width: float) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(min_width, 26 if compact else 28)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(Color("192f39"), Color("324d59"), 6))
	button.add_theme_stylebox_override("hover", _style(Color("192f39"), Color("324d59"), 6))
	button.add_theme_stylebox_override("pressed", _style(Color("35434a"), Color("6a7b7c"), 6))
	button.add_theme_stylebox_override("disabled", _style(Color("152129"), Color("24323a"), 6))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
