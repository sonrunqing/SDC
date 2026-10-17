extends Control

const BG := Color("0d151b")
const PANEL := Color("18252c")
const PANEL_LIGHT := Color("26343a")
const TEAL := Color("dbb577")
const AMBER := Color("e2ba76")
const TEXT := Color("edf0e7")
const MUTED := Color("a2b3ad")
const DANGER := Color("f08677")
const CAT_NAMES: Dictionary = {"smg":"冲锋枪", "rifle":"突击步枪", "sniper":"狙击枪", "shotgun":"霰弹枪", "machine_gun":"机枪", "pistol":"手枪", "helmet":"头盔", "body_armor":"防弹衣", "backpack":"背包", "armored_rig":"弹挂甲", "visor":"面罩", "muzzle":"枪口", "grip":"握把", "stock":"枪托", "magazine":"弹匣", "optic":"瞄具", "laser":"激光指示器", "handguard":"护木", "ammo":"弹药", "loot":"物资", "consumable":"补给", "suppressor":"消音器", "flash_hider":"消焰器", "compensator":"补偿器", "muzzle_brake":"枪口制退器", "vertical_grip":"垂直握把", "angled_grip":"斜角握把", "tactical_stock":"战术枪托", "extended_mag":"扩容弹匣", "red_dot":"红点瞄具", "scope":"瞄准镜", "medical":"医疗补给", "valuable":"贵重物资"}
const SLOT_NAMES: Dictionary = {"weapon":"当前武器", "primary":"主武器", "secondary":"副武器", "sidearm":"手枪", "helmet":"头盔", "body_armor":"防弹衣", "backpack":"背包", "armored_rig":"弹挂甲", "visor":"面罩", "ammo":"弹药", "muzzle":"枪口", "grip":"握把", "stock":"枪托", "magazine":"弹匣", "optic":"瞄具", "laser":"激光", "handguard":"护木"}
var _draft_weapon: String = ""
var _draft_parts: Dictionary = {}
var _draft_target: String = "primary"
var _wb_preview: Control
var _wb_guns: OptionButton
var _wb_target: OptionButton
var _wb_sockets: VBoxContainer
var _wb_parts: VBoxContainer
var _wb_parts_title: Label
var _wb_stats: VBoxContainer
var _wb_quote: Label
var _wb_commit: Button
var _hud_weapon_buttons: Dictionary = {}
var _font: Font
var _layer: CanvasLayer
var _lobby: Control
var _lobby_design: Control
var _hud_mission: Control
var _hud_bag_panel: Control
var _hud_menu: Control
var _render_host: MarginContainer
var _content: MarginContainer
var _credits_label: Label
var _tab: String = "home"
var _selected: String = ""
var _filter: String = "all"
var _search: String = ""
var _slot: String = "muzzle"
var _list_box: Container
var _detail_box: VBoxContainer
var _world: Node3D
var _hud: Control
var _controls: Control
var _hud_hp: Label
var _hud_ammo: Label
var _hud_bag: Label
var _hud_time: Label
var _hud_objective: Label
var _hud_nearby: Label
var _hud_map: Control
var _hud_extract: ProgressBar
var _toast: Label
var _toast_time: float = 0.0
var _refresh_pending: bool = false
var _raid_starting: bool = false
var _result_overlay: Control
var _nav_buttons: Dictionary = {}
var _sidebar: Control
var _header: Control
var _header_title: Label
var _header_back: Button
var _bottom_nav: Control
var _home_preview: Control
var _map_preview: Control
var _market_group: String = ""
var _entry_id: String = "south"
var _loadout_parent: String = "home"
var _inventory_view: Control
var _settings_button: Button
var _hud_health: Control

func _ready() -> void:
	get_tree().quit_on_go_back=false
	get_tree().root.go_back_requested.connect(_mobile_back)
	_font = load("res://assets/fonts/NotoSansSC.ttf") as Font
	var theme_resource := Theme.new()
	theme_resource.default_font = _font
	theme_resource.default_font_size = 20
	for type_name: String in ["Button","OptionButton","CheckButton"]:
		theme_resource.set_stylebox("normal",type_name,_style(PANEL_LIGHT,Color("46554f"),5))
		theme_resource.set_stylebox("hover",type_name,_style(PANEL_LIGHT,Color("46554f"),5))
		theme_resource.set_stylebox("pressed",type_name,_style(Color("35434a"),Color("6a7b7c"),5))
		theme_resource.set_stylebox("disabled",type_name,_style(Color("182125"),Color("34413c"),5))
		theme_resource.set_color("font_color",type_name,TEXT)
		theme_resource.set_color("font_hover_color",type_name,TEXT)
		theme_resource.set_color("font_focus_color",type_name,TEXT)
		theme_resource.set_color("font_pressed_color",type_name,TEXT)
		theme_resource.set_color("font_hover_pressed_color",type_name,TEXT)
		theme_resource.set_font_size("font_size",type_name,20)
	for type_name: String in ["Button","OptionButton","CheckButton","CheckBox","MenuButton","LinkButton","LineEdit","TextEdit","HSlider","VSlider","SpinBox","TabBar","Tree","ItemList","ScrollContainer"]:
		theme_resource.set_stylebox("focus",type_name,StyleBoxEmpty.new())
	theme_resource.set_stylebox("panel","PanelContainer",_style(PANEL,Color("3c4d4b"),5))
	theme_resource.set_stylebox("panel","PopupMenu",_style(PANEL,Color("46554f"),5))
	theme_resource.set_stylebox("hover","PopupMenu",_style(PANEL_LIGHT,Color("46554f"),5))
	theme_resource.set_color("font_hover_color","PopupMenu",TEXT)
	theme_resource.set_font_size("font_size","PopupMenu",21)
	theme_resource.set_constant("v_separation","PopupMenu",18)
	theme_resource.set_stylebox("normal","LineEdit",_style(PANEL_LIGHT,Color("52625c"),5))
	var slider_back:=StyleBoxFlat.new()
	slider_back.bg_color=Color("45534e")
	slider_back.content_margin_top=4
	slider_back.content_margin_bottom=4
	var slider_fill:=StyleBoxFlat.new()
	slider_fill.bg_color=Color("b7c5c0")
	slider_fill.content_margin_top=4
	slider_fill.content_margin_bottom=4
	theme_resource.set_stylebox("slider","HSlider",slider_back)
	theme_resource.set_stylebox("grabber_area","HSlider",slider_fill)
	theme_resource.set_stylebox("grabber_area_highlight","HSlider",slider_fill)
	for state_name: String in ["grabber","grabber_highlight","grabber_disabled"]:
		theme_resource.set_icon(state_name,"HSlider",load("res://assets/ui/slider_handle.svg"))
	theme = theme_resource
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	_build_lobby()
	_build_hud()
	_toast = Label.new()
	_toast.theme=theme
	_toast.position = Vector2(324, 664)
	_toast.size = Vector2(720, 38)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", AMBER)
	_toast.add_theme_stylebox_override("normal", _style(Color("263338"), Color("745d3f"), 7))
	_toast.visible = false
	_layer.add_child(_toast)
	GameState.changed.connect(_state_changed)
	resized.connect(_layout_screen)
	_layout_screen()
	AppSettings.changed.connect(_layout_screen)
	_refresh()

func _process(delta: float) -> void:
	if _toast_time > 0:
		_toast_time -= delta
		_toast.visible = _toast_time > 0

func _style(color: Color = PANEL, border: Color = Color("263b46"), radius: int = 9) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(mini(6,radius))
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _label(text_value: String, font_size: int = 16, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", maxi(17,font_size))
	label.add_theme_color_override("font_color", color)
	return label

func _wrap(text_value: String, font_size: int = 15, color: Color = MUTED) -> Label:
	var label := _label(text_value, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(caption: String, callback: Callable, accent: bool = false, min_width: float = 0, min_height: float = 72) -> Button:
	var button := preload("res://scripts/touch_button.gd").new()
	button.text = caption
	button.minimum_touch_height = min_height
	button.add_theme_font_size_override("font_size",20 if min_height<60 else 22)
	button.custom_minimum_size = Vector2(min_width, min_height)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", BG if accent else TEXT)
	button.add_theme_color_override("font_hover_color", BG if accent else TEXT)
	button.add_theme_color_override("font_focus_color", BG if accent else TEXT)
	button.add_theme_color_override("font_pressed_color", BG if accent else TEXT)
	button.add_theme_color_override("font_hover_pressed_color", BG if accent else TEXT)
	button.add_theme_color_override("font_disabled_color", Color("566b76"))
	button.add_theme_stylebox_override("normal", _style(Color("cbd5d3") if accent else PANEL_LIGHT,Color("6a7b7c") if accent else Color("46554f"),7))
	button.add_theme_stylebox_override("hover", _style(Color("cbd5d3") if accent else PANEL_LIGHT,Color("6a7b7c") if accent else Color("46554f"),7))
	button.add_theme_stylebox_override("pressed", _style(Color("adbdb9") if accent else Color("35434a"),Color("6a7b7c"),7))
	button.add_theme_stylebox_override("disabled", _style(Color("152129"), Color("24323a"), 7))
	button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	if min_height<60:
		for state_name: String in ["normal","hover","pressed","disabled"]:
			var compact_style: StyleBoxFlat=button.get_theme_stylebox(state_name) as StyleBoxFlat
			compact_style.content_margin_top=5
			compact_style.content_margin_bottom=5
	button.pressed.connect(callback)
	return button

func _panel(parent: Node, min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", _style())
	parent.add_child(panel)
	return panel

func _vbox(parent: Node, spacing: int = 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", spacing)
	parent.add_child(box)
	return box

func _hbox(parent: Node, spacing: int = 12) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", spacing)
	parent.add_child(box)
	return box

func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _build_lobby() -> void:
	_lobby=Control.new()
	_lobby.theme=theme
	_lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_lobby)
	var bg: Control=load("res://scripts/ui_backdrop.gd").new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lobby.add_child(bg)
	_lobby_design=Control.new()
	_lobby.add_child(_lobby_design)
	_header=Control.new()
	_header.size=Vector2(1232,64)
	_lobby_design.add_child(_header)
	_header_back=_button("‹ 返回",_go_back,false,112)
	_header.add_child(_header_back)
	_header_title=_label("SDC / 灰港行动",27)
	_header.add_child(_header_title)
	_credits_label=_label("",21,AMBER)
	_credits_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_credits_label.size=Vector2(210,50)
	_header.add_child(_credits_label)
	_settings_button=_button("设置",func() -> void:_select_tab("settings"),false,100)
	_header.add_child(_settings_button)
	_content=MarginContainer.new()
	_lobby_design.add_child(_content)
	_bottom_nav=Control.new()
	_lobby_design.add_child(_bottom_nav)
	var nav_items: Array=[["home","大厅"],["stash","装备 / 仓库"],["market","商店"],["workbench","改枪台"],["catalog","图鉴"]]
	for index: int in range(nav_items.size()):
		var data: Array=nav_items[index]
		var id: String=str(data[0])
		var button:=_button(str(data[1]),func() -> void:_select_tab(id),false,138)
		button.position=Vector2(index*148,0)
		button.size=Vector2(138,72)
		button.add_theme_font_size_override("font_size",20)
		_bottom_nav.add_child(button)
		_nav_buttons[id]=button
	var start:=_button("开始行动  →",_start_action,true,284)
	start.name="StartAction"
	start.size=Vector2(284,72)
	start.add_theme_font_size_override("font_size",23)
	_bottom_nav.add_child(start)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
		_mobile_back()
		get_viewport().set_input_as_handled()

func _mobile_back() -> void:
	if GameState.raid_active:
		if is_instance_valid(_result_overlay):_resume_raid()
		else:_show_pause()
	elif is_instance_valid(_result_overlay):
		_result_overlay.queue_free()
		_result_overlay=null
		if not _lobby.visible:
			_lobby.show()
			_select_tab("home")
	elif _tab!="home":_go_back()
	else:
		_result_overlay=_modal("退出游戏？")
		var box: VBoxContainer=_result_overlay.get_meta("box")
		box.add_child(_button("继续整备",func() -> void:_result_overlay.queue_free();_result_overlay=null,true))
		box.add_child(_button("保存并退出",func() -> void:GameState.save_game();get_tree().quit()))

func _go_back() -> void:
	if _tab=="market" and not _market_group.is_empty():
		_market_group="";_selected="";_filter="all";_refresh();return
	_select_tab(_loadout_parent if _tab=="loadout" else "home")

func _select_tab(tab_id: String) -> void:
	var destination: String="stash" if tab_id=="loadout" else tab_id
	if _tab==destination:return
	if tab_id=="loadout":_loadout_parent="maps" if _tab in ["maps","deploy"] else "home"
	_tab = destination
	_selected = ""
	_filter = "all"
	_search = ""
	if tab_id == "market": _market_group = ""
	_refresh()

func _state_changed() -> void:
	if is_instance_valid(_credits_label):_credits_label.text="◈  %s"%_number(int(GameState.credits))
	if _tab in ["stash","loadout"] and is_instance_valid(_inventory_view):
		_inventory_view.refresh_inventory()
		return
	if _tab in ["maps","deploy"]:return
	if _refresh_pending:return
	_refresh_pending=true
	call_deferred("_refresh")

func _refresh() -> void:
	_refresh_pending = false
	if not is_instance_valid(_content): return
	_credits_label.text = "◈  %s" % _number(int(GameState.credits))
	if GameState.raid_active: return
	_inventory_view=null
	_clear(_content)
	var page_parent: Control=_content
	if _tab not in ["maps","deploy","stash","loadout","settings"]:
		var page_scroll:=preload("res://scripts/touch_scroll.gd").new()
		page_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		page_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
		_content.add_child(page_scroll)
		page_parent=page_scroll
	_render_host=MarginContainer.new()
	_render_host.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_render_host.size_flags_vertical=Control.SIZE_EXPAND_FILL
	page_parent.add_child(_render_host)
	_bottom_nav.visible = true
	_header_back.visible = _tab!="home"
	var names:Dictionary={"home":"SDC","maps":"行动区域","deploy":"行动区域","loadout":"出战整备","stash":"装备与仓库","market":"商店","workbench":"武器装配台","catalog":"装备图鉴","settings":"设置"}
	_header_title.text=str(names.get(_tab,"SDC"))
	_header_title.position.x=0 if _tab=="home" else 132
	_layout_screen()
	for id: String in _nav_buttons:
		_nav_buttons[id].add_theme_stylebox_override("normal",_style(PANEL_LIGHT,Color("46554f"),5))
	match _tab:
		"home":_render_home()
		"maps","deploy":_render_maps()
		"loadout","stash":_render_loadout()
		"settings":_render_settings()
		"workbench":_render_workbench()
		"market":
			if _market_group.is_empty():_render_market_groups()
			else:_render_browser()
		_:_render_browser()

func _number(value: int) -> String:
	var result: String = str(value)
	var offset: int = result.length() - 3
	while offset > 0:
		result = result.insert(offset, ",")
		offset -= 3
	return result

func _item_name(id: String) -> String:
	return str(Catalog.get_item(id).get("name", "未装备")) if not id.is_empty() else "未装备"

func _render_home() -> void:
	var columns:=_hbox(_render_host,18)
	_home_preview=load("res://scripts/operator_preview.gd").new()
	_home_preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_home_preview.size_flags_vertical=Control.SIZE_EXPAND_FILL
	columns.add_child(_home_preview)
	var copy:=VBoxContainer.new()
	copy.position=Vector2(28,26)
	copy.mouse_filter=Control.MOUSE_FILTER_IGNORE
	copy.add_theme_constant_override("separation",10)
	_home_preview.add_child(copy)
	copy.add_child(_label("FIELD OPERATIONS  /  SDC",17,AMBER))
	copy.add_child(_label("灰港行动",46,TEXT))
	copy.add_child(_label("准备每一次撤离",21,MUTED))
	_ignore_pointer(copy)
	var side:=_panel(columns,Vector2(330,0))
	var box:=_vbox(side,10)
	box.add_child(_label("行动准备",18,AMBER))
	box.add_child(_label("灰港 · 工业港",28))
	box.add_child(_wrap("仓储区、维修车间与集装箱货场。搜寻物资，抵达北侧撤离点。",18))
	var spacer:=Control.new()
	spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	for slot: String in ["primary","secondary","sidearm"]:
		var row:=_hbox(box,8)
		var slot_label:=_label(str(SLOT_NAMES[slot]),17,MUTED)
		slot_label.custom_minimum_size.x=78
		row.add_child(slot_label)
		var name_label:=_label(_item_name(str(GameState.loadout.get(slot,""))),19,TEXT)
		name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(name_label)
	box.add_child(_label("负重  %.1f / %.1f kg"%[GameState.raid_weight(),GameState.carry_capacity()],19,AMBER))
	box.add_child(_button("整理装备与仓库",func() -> void:_select_tab("stash")))

func _render_maps() -> void:
	var columns:=_hbox(_render_host,16)
	var preview_panel:=_panel(columns);preview_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_map_preview=load("res://scripts/map_preview.gd").new();_map_preview.custom_minimum_size=Vector2(480,240);_map_preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_map_preview.size_flags_vertical=Control.SIZE_EXPAND_FILL
	preview_panel.add_child(_map_preview)
	var side:=_panel(columns,Vector2(288,0));var box:=_vbox(side,8)
	var heading:=_hbox(box,8)
	var title:=_label("灰港 · 工业港",20)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_label("160 × 180 m",16,MUTED))
	var routes:=OptionButton.new();routes.name="EntryChoice";routes.custom_minimum_size.y=48
	var layout:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/harbor_layout.json"))
	for entry:Dictionary in layout.entries:
		routes.add_item(str(entry.name));routes.set_item_metadata(routes.item_count-1,str(entry.id))
		if str(entry.id)==_entry_id:routes.select(routes.item_count-1)
	routes.item_selected.connect(func(index:int) -> void: _entry_id=str(routes.get_item_metadata(index));_map_preview.set_entry_id(_entry_id))
	box.add_child(routes)
	box.add_child(_button("全图",func() -> void: _map_preview.show_overview(),false,0,48))
	var scroll:=preload("res://scripts/touch_scroll.gd").new();scroll.name="DistrictChoices";scroll.custom_minimum_size.y=150;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
	var districts:=_vbox(scroll,6);districts.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for zone:Dictionary in layout.zones:
		var id:String=str(zone.id)
		districts.add_child(_button(str(zone.name),func() -> void: _map_preview.focus_zone(id),false,0,48))
	var prepare:=_button("出战整备   →",func() -> void: _select_tab("loadout"),false,0,52);prepare.name="PrepareAction";box.add_child(prepare)
	_map_preview.set_entry_id(_entry_id)

func _render_loadout() -> void:
	_inventory_view=load("res://scripts/ui_inventory.gd").new()
	_inventory_view.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_inventory_view.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_inventory_view.feedback.connect(_notify)
	_inventory_view.assembly_requested.connect(_open_assembly)
	_render_host.add_child(_inventory_view)

func _render_settings() -> void:
	var settings: Control = load("res://scripts/ui_settings.gd").new()
	settings.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	settings.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_render_host.add_child(settings)

func _ignore_pointer(node: Node) -> void:
	if node is Control:node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child:Node in node.get_children():_ignore_pointer(child)

func _item_picture(item_id: String, image_size: Vector2) -> Control:
	var path:String="res://assets/icons/items/"+item_id+".png"
	if ResourceLoader.exists(path):
		var picture:=TextureRect.new();picture.texture=preload("res://scripts/item_textures.gd").icon(item_id);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size=image_size;picture.size_flags_horizontal=Control.SIZE_EXPAND_FILL;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;return picture
	var placeholder:=_label(_glyph(Catalog.get_item(item_id)),42,TEAL);placeholder.custom_minimum_size=image_size;placeholder.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;return placeholder

func _open_market_group(id: String) -> void:
	_market_group=id;_filter="all";_search="";_selected="";_refresh()

func _render_market_groups() -> void:
	var root:=_vbox(_render_host,14)
	var grid:=GridContainer.new();grid.columns=3;grid.size_flags_vertical=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",16);grid.add_theme_constant_override("v_separation",16);root.add_child(grid)
	var groups:Array=[["weapons","枪械","weapon_badger556"],["attachments","枪械配件","att_optic_scope4"],["protection","防护装备","helmet_moss_1a"],["capacity","背包与弹挂","backpack_patrol"],["ammo","弹药","ammo_9x19_fmj"],["medical","医疗补给","medkit_field"]]
	for group:Array in groups:
		var id:String=str(group[0]);var card:=_button("",func() -> void: _open_market_group(id))
		card.name="Category_"+id;card.custom_minimum_size=Vector2(330,204);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.size_flags_vertical=Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var inside:=VBoxContainer.new();inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);inside.offset_left=24;inside.offset_right=-24;inside.offset_top=12;inside.offset_bottom=-20;card.add_child(inside)
		inside.add_child(_item_picture(str(group[2]),Vector2(240,122)))
		var name:=_label(str(group[1]),24);inside.add_child(name);_ignore_pointer(inside)

func _browser_categories() -> Array:
	if _tab!="market":return ["all","weapon","armor","attachment","ammo","consumable","loot"]
	match _market_group:
		"weapons":return ["all","smg","rifle","sniper","shotgun","machine_gun","pistol"]
		"attachments":return ["all","muzzle","grip","stock","magazine","optic","laser","handguard"]
		"protection":return ["all","helmet","body_armor","visor"]
		"capacity":return ["all","backpack","armored_rig"]
		"medical":return ["all","medical"]
		"ammo":return ["all","9x19","45acp","57x28","556x45","545x39","762x39","300blk","308win","762x54r","338lm","12g","20g"]
	return ["all"]

func _belongs_to_market(item: Dictionary) -> bool:
	var kind:String=str(item.get("kind",""));var category:String=str(item.get("category",""))
	match _market_group:
		"weapons":return kind=="weapon"
		"attachments":return kind=="attachment"
		"protection":return category in ["helmet","body_armor","visor"]
		"capacity":return category in ["backpack","armored_rig"]
		"ammo":return kind=="ammo"
		"medical":return kind=="consumable"
	return true

func _render_browser() -> void:
	var root := _vbox(_render_host, 12)
	var filters := _hbox(root, 10)
	if _tab=="market":filters.add_child(_button("‹ 分类",func() -> void: _market_group="";_refresh()))
	var search := LineEdit.new();search.placeholder_text="名称 / 口径";search.text=_search;search.custom_minimum_size=Vector2(240,60);search.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	search.add_theme_stylebox_override("normal",_style(PANEL,Color("29404d"),3));search.text_changed.connect(func(value:String) -> void: _search=value;_populate_list());filters.add_child(search)
	var options:=OptionButton.new();options.custom_minimum_size=Vector2(190,60);options.add_theme_stylebox_override("normal",_style(PANEL_LIGHT))
	for category:String in _browser_categories():
		var caption:String=str({"all":"全部","weapon":"枪械","armor":"防具 / 容器","attachment":"配件","consumable":"补给"}.get(category,CAT_NAMES.get(category,category)))
		options.add_item(caption);options.set_item_metadata(options.item_count-1,category)
		if category==_filter:options.select(options.item_count-1)
	options.item_selected.connect(func(index:int) -> void: _filter=str(options.get_item_metadata(index));_selected="";_populate_list());filters.add_child(options)
	var columns:=_hbox(root,16);columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var list_panel:=_panel(columns);list_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var scroll:=preload("res://scripts/touch_scroll.gd").new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;list_panel.add_child(scroll)
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(grid);_list_box=grid
	var detail_panel:=_panel(columns,Vector2(340,0));var detail_scroll:=preload("res://scripts/touch_scroll.gd").new();detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail_panel.add_child(detail_scroll)
	_detail_box=_vbox(detail_scroll,9);_detail_box.custom_minimum_size.x=294;_detail_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_populate_list()

func _matches(item: Dictionary) -> bool:
	if _tab=="market" and not _belongs_to_market(item):return false
	if _tab == "stash" and int(GameState.stash.get(str(item.get("id", "")), 0)) <= 0 and not _equipped(str(item.get("id", ""))): return false
	if _filter != "all" and str(item.get("kind", "")) != _filter and str(item.get("category", "")) != _filter and str(item.get("slot", "")) != _filter: return false
	if not _search.is_empty():
		var haystack: String = (str(item.get("name", "")) + " " + str(item.get("caliber", "")) + " " + str(item.get("interfaces", "")) + " " + str(item.get("description", ""))).to_lower()
		if not haystack.contains(_search.to_lower()): return false
	return true

func _equipped(item_id: String) -> bool:
	if GameState.loadout.values().has(item_id):return true
	for parts:Dictionary in GameState.weapon_builds.values():
		if parts.values().has(item_id):return true
	return false

func _populate_list() -> void:
	if not is_instance_valid(_list_box): return
	_clear(_list_box)
	var matches: Array[String] = []
	for raw_id: Variant in Catalog.items:
		var item_id: String = str(raw_id)
		var item: Dictionary = Catalog.get_item(item_id)
		if _tab == "workbench":
			var weapon_id: String = str(GameState.loadout.get("weapon", ""))
			if item.get("kind") != "attachment" or not Catalog.compatible(weapon_id, item_id, _slot): continue
		else:
			if not _matches(item): continue
		matches.append(item_id)
	if matches.is_empty():
		_list_box.add_child(_label("暂无物品",16,MUTED))
	if _selected.is_empty() or not matches.has(_selected):_selected=matches[0] if not matches.is_empty() else ""
	for item_id:String in matches:
		var item:Dictionary=Catalog.get_item(item_id)
		var row:=_button("",func() -> void: _selected=item_id;_populate_list())
		row.custom_minimum_size=Vector2(202,188);row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_theme_stylebox_override("normal",_style(Color("303e43") if item_id==_selected else PANEL_LIGHT,Color("b7c5c0") if item_id==_selected else Color("46554f"),3))
		_list_box.add_child(row)
		var inner:=VBoxContainer.new();inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);inner.offset_left=12;inner.offset_right=-12;inner.offset_top=8;inner.offset_bottom=-8;row.add_child(inner)
		inner.add_child(_item_picture(item_id,Vector2(180,100)))
		var title:=_label(str(item.name),14);title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;inner.add_child(title)
		var bottom:=_hbox(inner,4)
		var owned:=_label("已装备" if _equipped(item_id) else ("×%d"%int(GameState.stash.get(item_id,0)) if _tab=="stash" else ""),12,TEAL);owned.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bottom.add_child(owned)
		bottom.add_child(_label("◈ "+_number(int(item.price)),13,AMBER))
		_ignore_pointer(inner)

	_show_detail()

func _glyph(item: Dictionary) -> String:
	match str(item.get("kind", "")):
		"weapon": return "╾"
		"armor": return "⬡"
		"attachment": return "⊕"
		"ammo": return "▥"
		"loot": return "◇"
	return "+"

func _rarity_color(item: Dictionary) -> Color:
	var level: int = int(item.get("level", 0))
	if item.get("kind") == "loot": return AMBER
	if level >= 4: return Color("c3a5e4")
	if level >= 3: return Color("8eafde")
	return TEAL

func _item_meta(item: Dictionary) -> String:
	var category: String = str(item.get("category", item.get("slot", item.get("kind", ""))))
	var parts: Array[String] = [str(CAT_NAMES.get(category, category))]
	if category in ["backpack", "armored_rig"]:
		parts.append("容量 %skg" % item.get("capacity", 0))
	elif int(item.get("level", 0)) > 0:
		parts.append("%d 级" % int(item.get("level", 0)))
	if item.has("caliber"): parts.append(str(item["caliber"]))
	if item.get("kind") == "attachment": parts.append(_interfaces(item.get("interfaces", [])))
	return " · ".join(parts)

func _stat_line(parent: Node, caption: String, value: String, color: Color = TEXT) -> void:
	var row := _hbox(parent, 6)
	var label := _label(caption, 13, MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var number := _label(value, 13, color)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(number)

func _show_detail() -> void:
	if not is_instance_valid(_detail_box): return
	_clear(_detail_box)
	var item: Dictionary = Catalog.get_item(_selected)
	if item.is_empty():
		_detail_box.add_child(_label("选择一件装备", 21))
		return
	_detail_box.add_child(_label("装备详情", 12, TEAL))
	_detail_box.add_child(_wrap(str(item.get("name", "")), 23, TEXT))
	_detail_box.add_child(_wrap(_item_meta(item), 13, _rarity_color(item)))
	_detail_box.add_child(_item_picture(_selected,Vector2(270,116)))
	_stat_line(_detail_box, "重量", "%s kg" % item.get("weight", 0))
	var kind: String = str(item.get("kind", ""))
	match kind:
		"weapon":
			var stats: Dictionary = Catalog.weapon_stats(_selected, GameState.attachments if str(GameState.loadout.get("weapon", "")) == _selected else {})
			_weapon_stats_panel(_detail_box, stats)
			var slots: Dictionary = item.get("slots", {})
			for key: Variant in slots:
				_detail_box.add_child(_wrap("%s  /  %s" % [SLOT_NAMES.get(str(key), str(key)), _interfaces(slots[key])], 12, MUTED))
		"armor":
			if str(item.get("category", "")) in ["backpack", "armored_rig"]:
				_stat_line(_detail_box, "储物容量", "%s 格" % item.get("storage_cells", item.get("capacity",0)), TEAL)
				_detail_box.add_child(_label("按容量区分 · 无装备等级", 12, TEAL))
			else:
				_stat_line(_detail_box, "防护等级", str(item.get("level", 0)))
			if item.has("protection"): _stat_line(_detail_box, "防护", str(item.get("protection")))
			if item.has("durability"): _stat_line(_detail_box, "耐久", str(item.get("durability")))
			if item.has("visor_mount"): _stat_line(_detail_box, "面罩接口", _interface(str(item["visor_mount"])))
			if item.has("visor_mounts"): _detail_box.add_child(_wrap("面罩卡槽：" + _interfaces(item["visor_mounts"]), 13, TEAL))
		"attachment":
			_stat_line(_detail_box, "安装部位", str(SLOT_NAMES.get(str(item.get("slot", "")), "配件")))
			_detail_box.add_child(_wrap("接口  " + _interfaces(item.get("interfaces", [])), 13, TEAL))
			if not item.get("weapon_ids", []).is_empty(): _detail_box.add_child(_wrap("专用枪械  " + _weapon_names(item["weapon_ids"]), 12))
			var modifiers: Dictionary = item.get("modifiers", {})
			for stat: Variant in modifiers:
				var amount: float = float(modifiers[stat])
				var beneficial: bool = amount > 0
				_stat_line(_detail_box, _stat_caption(str(stat)), ("+" if amount > 0 else "") + _decimal(amount), TEAL if beneficial else AMBER)
		"consumable":
			_stat_line(_detail_box, "生命恢复", "+%s" % item.get("heal", 0), TEAL)
		"ammo":
			_stat_line(_detail_box, "穿透", str(item.get("penetration", 0)))
			_stat_line(_detail_box, "每包发数", str(item.get("stack_size", 1)))
	_stat_line(_detail_box, "仓库存量", str(GameState.stash.get(_selected, 0)), TEAL)
	_stat_line(_detail_box, "购入 / 售出", "%s / %s" % [_number(int(item.get("price", 0))), _number(int(item.get("sell_price", 0)))], AMBER)
	var action_start: int = _detail_box.get_child_count()
	var quantity: SpinBox = null
	if kind == "ammo" or kind == "consumable" or kind == "loot":
		var quantity_row := _hbox(_detail_box)
		quantity_row.add_child(_label("数量", 13, MUTED))
		quantity = SpinBox.new()
		quantity.min_value = 1
		quantity.max_value = 999
		quantity.value = int(item.get("stack_size", 1)) if kind == "ammo" else 1
		quantity.custom_minimum_size.x = 160
		quantity_row.add_child(quantity)
	var selected_id: String = _selected
	var count_widget: SpinBox = quantity
	if _tab in ["market", "workbench"]:
		_detail_box.add_child(_button("购买%s" % ("弹药 / 输入发数" if kind == "ammo" else "至仓库"), func() -> void: _perform(GameState.buy(selected_id, int(count_widget.value) if count_widget != null else 1), "已购入仓库"), true))
	if _tab != "catalog":
		if kind == "weapon":
			var targets: Array = ["sidearm"] if item.get("category") == "pistol" else ["primary","secondary"]
			for target: String in targets:
				var equip_target := _button("装备至" + str(SLOT_NAMES[target]), func() -> void: _perform(GameState.equip_weapon(selected_id,target), "已装备至" + str(SLOT_NAMES[target])))
				equip_target.disabled = int(GameState.stash.get(selected_id,0)) <= 0 and not _equipped(selected_id)
				_detail_box.add_child(equip_target)
		if kind in ["armor", "ammo"]:
			var equip_button := _button("装备" if not _equipped(selected_id) else "已装备 · 再次选择", func() -> void: _perform(GameState.equip(selected_id), "已更新携行装备"))
			equip_button.disabled = int(GameState.stash.get(selected_id, 0)) <= 0 and not _equipped(selected_id)
			_detail_box.add_child(equip_button)
		if kind == "attachment":
			var weapon_id: String = str(GameState.loadout.get("weapon", ""))
			var compatible: bool = Catalog.compatible(weapon_id, selected_id)
			_detail_box.add_child(_wrap("可装于当前武器" if compatible else "当前武器接口不兼容", 12, TEAL if compatible else DANGER))
			var install := _button("安装到当前武器", func() -> void: _perform(GameState.install_attachment(selected_id), "配件安装完成"))
			install.disabled = not compatible or int(GameState.stash.get(selected_id, 0)) <= 0
			_detail_box.add_child(install)
		if _tab == "stash":
			var sell_button := _button("出售至商店", func() -> void: _perform(GameState.sell(selected_id, int(count_widget.value) if count_widget != null else 1), "物资已出售，资金已到账"))
			sell_button.disabled = int(GameState.stash.get(selected_id, 0)) <= 0
			_detail_box.add_child(sell_button)
			if _equipped(selected_id):
				var equip_slot: String = ""
				for key: Variant in GameState.loadout:
					if str(GameState.loadout[key]) == selected_id and str(key) not in ["weapon","ammo"]: equip_slot = str(key)
				if not equip_slot.is_empty():
					var slot_to_remove: String = equip_slot
					_detail_box.add_child(_button("卸下到仓库", func() -> void: _perform(GameState.unequip(slot_to_remove), "装备已卸下")))

	if kind == "weapon":
		_detail_box.add_child(_button("进入装配台 · 预览整套方案",func() -> void: _open_assembly(selected_id)))
	# Keep purchase/equip controls within the first screen on a phone.
	var action_nodes: Array[Node] = []
	for index in range(action_start, _detail_box.get_child_count()):
		action_nodes.append(_detail_box.get_child(index))
	for index in range(action_nodes.size()):
		_detail_box.move_child(action_nodes[index], 4 + index)

func _stat_caption(key: String) -> String:
	return str({"damage":"击发威力","rpm":"枪速","magazine":"弹匣容量","recoil":"后坐力","recoil_control":"后坐力","horizontal_control":"水平后坐力","accuracy":"精准度","ergonomics":"人机功效","range":"射程","noise":"消声能力","suppression":"消声能力"}.get(key,key))

func _weapon_stats_panel(parent: Node,stats: Dictionary) -> void:
	var heading:=_hbox(parent,8)
	heading.add_child(_label("性能参数",18,TEAL))
	var hint:=_label("数值越高越好",17,MUTED)
	hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(hint)
	var grid:=GridContainer.new()
	grid.columns=2 if parent==_wb_stats else 1
	grid.add_theme_constant_override("h_separation",18)
	grid.add_theme_constant_override("v_separation",5)
	parent.add_child(grid)
	for key: String in ["recoil_control","horizontal_control","ergonomics","range","damage","rpm","accuracy"]:
		var column:=_vbox(grid,1)
		column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var row:=_hbox(column,6)
		var caption:=_label(_stat_caption(key),17,MUTED)
		caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var value: float=float(stats.get(key,0))
		var suffix: String=" m" if key=="range" else (" 发/分" if key=="rpm" else "")
		row.add_child(_label(_decimal(value)+suffix,18,TEXT))
		var bar:=ProgressBar.new()
		bar.max_value=1200 if key=="rpm" else (120 if key=="range" else 100)
		bar.value=value
		bar.show_percentage=false
		bar.custom_minimum_size=Vector2(0,3)
		var background:=StyleBoxFlat.new()
		background.bg_color=Color("2d3c40")
		bar.add_theme_stylebox_override("background",background)
		var fill:=StyleBoxFlat.new()
		fill.bg_color=TEAL
		bar.add_theme_stylebox_override("fill",fill)
		column.add_child(bar)

func _perform(ok: bool, success_text: String) -> void:
	_notify(success_text if ok else str(GameState.last_error), not ok)
	if ok: _state_changed()

func _notify(text_value: String, is_error: bool = false) -> void:
	_toast.text = text_value if not text_value.is_empty() else "操作未完成，请检查装备与库存"
	_toast.add_theme_color_override("font_color", DANGER if is_error else TEAL)
	_toast_time = 3.4
	_toast.visible = true

func _render_workbench() -> void:
	_ensure_draft()
	var root:=_vbox(_render_host,10)
	var choices:=_hbox(root,10)
	_wb_guns=OptionButton.new()
	_wb_guns.custom_minimum_size=Vector2(330,60)
	_wb_guns.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for item: Dictionary in Catalog.by_kind("weapon"):
		_wb_guns.add_item("%s / %s"%[CAT_NAMES.get(str(item.category),"枪械"),str(item.name)])
		_wb_guns.set_item_metadata(_wb_guns.item_count-1,str(item.id))
		if str(item.id)==_draft_weapon:_wb_guns.select(_wb_guns.item_count-1)
	_wb_guns.item_selected.connect(func(index: int) -> void:_choose_draft_weapon(str(_wb_guns.get_item_metadata(index))))
	choices.add_child(_wb_guns)
	_wb_target=OptionButton.new()
	_wb_target.custom_minimum_size=Vector2(154,60)
	_wb_target.item_selected.connect(func(index: int) -> void:_draft_target=str(_wb_target.get_item_metadata(index));_update_assembly(false))
	choices.add_child(_wb_target)
	choices.add_child(_button("载入携行",_draft_load_carried))
	choices.add_child(_button("清空配件",_draft_clear_parts))
	var columns:=_hbox(root,12)
	columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var sockets_panel:=_panel(columns,Vector2(152,0))
	var socket_scroll:=preload("res://scripts/touch_scroll.gd").new()
	sockets_panel.add_child(socket_scroll)
	_wb_sockets=_vbox(socket_scroll,8)
	_wb_sockets.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var center:=_vbox(columns,8)
	center.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var preview_panel:=_panel(center)
	preview_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_wb_preview=load("res://scripts/weapon_preview.gd").new()
	_wb_preview.connect("socket_selected",_select_draft_socket)
	_wb_preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_wb_preview.size_flags_vertical=Control.SIZE_EXPAND_FILL
	preview_panel.add_child(_wb_preview)
	_wb_stats=VBoxContainer.new()
	_wb_stats.add_theme_constant_override("separation",4)
	center.add_child(_wb_stats)
	var footer:=_hbox(center,10)
	_wb_quote=_wrap("",17,AMBER)
	_wb_quote.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(_wb_quote)
	_wb_commit=_button("装备方案",_commit_draft,true,248)
	footer.add_child(_wb_commit)
	var parts_panel:=_panel(columns,Vector2(286,0))
	var parts_root:=_vbox(parts_panel,10)
	_wb_parts_title=_label("兼容配件",20,TEAL)
	parts_root.add_child(_wb_parts_title)
	var parts_scroll:=preload("res://scripts/touch_scroll.gd").new()
	parts_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	parts_root.add_child(parts_scroll)
	_wb_parts=_vbox(parts_scroll,10)
	_wb_parts.custom_minimum_size.x=246
	_wb_parts.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_update_assembly()

func _ensure_draft() -> void:
	if Catalog.get_item(_draft_weapon).is_empty():
		_draft_weapon = str(GameState.loadout.get("primary", GameState.loadout.get("weapon", "")))
		if _draft_weapon.is_empty():
			var guns: Array = Catalog.by_kind("weapon")
			if not guns.is_empty(): _draft_weapon = str(guns[0]["id"])
		_draft_parts = {}
		var builds: Dictionary = GameState.get("weapon_builds") if GameState.get("weapon_builds") is Dictionary else {}
		if str(GameState.loadout.get("primary", "")) == _draft_weapon: _draft_parts = builds.get("primary", {}).duplicate(true)
	var item: Dictionary = Catalog.get_item(_draft_weapon)
	if item.get("category") == "pistol": _draft_target = "sidearm"
	elif _draft_target == "sidearm": _draft_target = "primary"

func _choose_draft_weapon(weapon_id: String) -> void:
	if Catalog.get_item(weapon_id).get("kind") != "weapon": return
	_draft_weapon = weapon_id
	_draft_parts = {}
	_draft_target = "sidearm" if Catalog.get_item(weapon_id).get("category") == "pistol" else "primary"
	_update_assembly()

func _select_draft_socket(slot_name: String) -> void:
	var slots: Dictionary = Catalog.get_item(_draft_weapon).get("slots",{})
	if not slots.has(slot_name): return
	_slot = slot_name
	_update_assembly(false)

func _draft_choose_part(attachment_id: String) -> bool:
	var item: Dictionary = Catalog.get_item(attachment_id)
	var slot_name: String = str(item.get("slot", ""))
	if not Catalog.compatible(_draft_weapon, attachment_id, slot_name):
		_notify("此配件不匹配当前武器接口", true)
		return false
	_draft_parts[slot_name] = attachment_id
	_slot = slot_name
	_update_assembly()
	return true

func _draft_remove_part(slot_name: String) -> void:
	_draft_parts.erase(slot_name)
	_update_assembly()

func _draft_clear_parts() -> void:
	_draft_parts = {}
	_update_assembly()

func _draft_load_carried() -> void:
	var weapon_id: String = str(GameState.loadout.get(_draft_target, ""))
	if weapon_id.is_empty():
		_notify("此携行位置尚未装备武器", true)
		return
	_draft_weapon = weapon_id
	var builds: Dictionary = GameState.get("weapon_builds") if GameState.get("weapon_builds") is Dictionary else {}
	_draft_parts = builds.get(_draft_target, {}).duplicate(true)
	_update_assembly()

func _update_assembly(update_model: bool = true) -> void:
	if not is_instance_valid(_wb_preview): return
	_ensure_draft()
	var weapon: Dictionary = Catalog.get_item(_draft_weapon)
	if update_model: _wb_preview.call("set_weapon", _draft_weapon, _draft_parts)
	for index in range(_wb_guns.item_count):
		if str(_wb_guns.get_item_metadata(index)) == _draft_weapon: _wb_guns.select(index)
	_wb_target.clear()
	var targets: Array = ["sidearm"] if weapon.get("category") == "pistol" else ["primary", "secondary"]
	for target: String in targets:
		_wb_target.add_item(str(SLOT_NAMES[target]))
		_wb_target.set_item_metadata(_wb_target.item_count - 1, target)
		if target == _draft_target: _wb_target.select(_wb_target.item_count - 1)
	_clear(_wb_sockets)
	_wb_sockets.add_child(_label("安装位置", 16))
	var slots: Dictionary = weapon.get("slots", {})
	if not slots.has(_slot): _slot = str(slots.keys()[0]) if not slots.is_empty() else ""
	for raw_slot: Variant in slots:
		var slot_name: String = str(raw_slot)
		var part: String = str(_draft_parts.get(slot_name, ""))
		var caption: String = str(SLOT_NAMES.get(slot_name, slot_name)) + ("  ●" if slot_name == _slot else "")
		var slot_button := _button(caption, func() -> void: _select_draft_socket(slot_name))
		slot_button.add_theme_color_override("font_color", TEAL if slot_name == _slot else TEXT)
		_wb_sockets.add_child(slot_button)
		_wb_sockets.add_child(_wrap(_item_name(part) if not part.is_empty() else "基础部件 / 空接口", 11, TEAL if not part.is_empty() else MUTED))
	_clear(_wb_stats)
	var stats: Dictionary = Catalog.weapon_stats(_draft_weapon, _draft_parts)
	_weapon_stats_panel(_wb_stats, stats)
	_wb_preview.call("focus_socket",_slot)
	_populate_draft_parts()
	var quote: Dictionary = GameState.call("quote_build", _draft_weapon, _draft_parts, _draft_target) if GameState.has_method("quote_build") else {"valid":false,"error":"装配系统加载中"}
	var missing: Dictionary = quote.get("missing", {})
	var owned: Dictionary = quote.get("owned", {})
	var missing_count: int = 0
	var owned_count: int = 0
	for quantity: Variant in missing.values(): missing_count += int(quantity)
	for quantity: Variant in owned.values(): owned_count += int(quantity)
	var cost: int = int(quote.get("cost",0))
	_wb_quote.text = "已备 %d 件 · 缺少 %d 件\n需支付 ◈ %s  /  余额 ◈ %s" % [owned_count,missing_count,_number(cost),_number(int(GameState.credits))]
	var error: String = str(quote.get("error", ""))
	if not bool(quote.get("valid",false)): _wb_quote.text = error
	elif not bool(quote.get("can_afford",false)): _wb_quote.text += "  ·  资金不足"
	_wb_quote.add_theme_color_override("font_color", AMBER if bool(quote.get("can_afford",false)) else DANGER)
	_wb_commit.text = ("购买缺件并装备" if cost > 0 else "装备整套方案") + "  →  " + str(SLOT_NAMES.get(_draft_target,_draft_target))
	_wb_commit.disabled = not bool(quote.get("valid",false))
	_wb_commit.tooltip_text = "只购买仓库与被替换装备中缺少的部件；原装备自动回收。"

func _populate_draft_parts() -> void:
	_clear(_wb_parts)
	var weapon: Dictionary = Catalog.get_item(_draft_weapon)
	var slots: Dictionary = weapon.get("slots", {})
	_wb_parts_title.text = "%s · 兼容配件" % SLOT_NAMES.get(_slot, "接口")
	_wb_parts.add_child(_wrap(_interfaces(slots.get(_slot, [])), 11))
	var selected: String = str(_draft_parts.get(_slot, ""))
	var default_button := _button("恢复基础部件 / 不加装", func() -> void: _draft_remove_part(_slot))
	default_button.add_theme_color_override("font_color", TEAL if selected.is_empty() else TEXT)
	_wb_parts.add_child(default_button)
	var count: int = 0
	for item: Dictionary in Catalog.by_kind("attachment"):
		var item_id: String = str(item["id"])
		if not Catalog.compatible(_draft_weapon,item_id,_slot): continue
		count += 1
		var card := preload("res://scripts/touch_button.gd").new()
		card.custom_minimum_size.y = 144
		card.add_theme_stylebox_override("normal",_style(Color("303e43") if selected == item_id else PANEL_LIGHT,Color("b7c5c0") if selected == item_id else Color("46554f"),7))
		card.add_theme_stylebox_override("hover",_style(Color("303e43") if selected == item_id else PANEL_LIGHT,Color("b7c5c0") if selected == item_id else Color("46554f"),7))
		card.pressed.connect(func() -> void: _draft_choose_part(item_id))
		var inset := MarginContainer.new()
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inset.add_theme_constant_override("margin_left",10)
		inset.add_theme_constant_override("margin_right",10)
		inset.add_theme_constant_override("margin_top",8)
		inset.add_theme_constant_override("margin_bottom",8)
		card.add_child(inset)
		var text_box := _vbox(inset,5)
		text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := _wrap(str(item["name"]),14,TEAL if selected == item_id else TEXT)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.add_child(name_label)
		var stat_label := _wrap(_modifier_text(item.get("modifiers",{})),11,MUTED)
		stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.add_child(stat_label)
		var stock: int = int(GameState.stash.get(item_id,0))
		var owned_label := _label("持有 %d  ·  ◈ %s%s" % [stock,_number(int(item.get("price",0))),"  ✓ 草案" if selected == item_id else ""],12,AMBER)
		owned_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.add_child(owned_label)
		_wb_parts.add_child(card)
	if count == 0: _wb_parts.add_child(_wrap("此接口暂无可用扩展件。",13))

func _modifier_text(modifiers: Dictionary) -> String:
	var descriptions: Array[String] = []
	for key: Variant in modifiers:
		var value: float = float(modifiers[key])
		descriptions.append("%s %s%s" % [_stat_caption(str(key)),"+" if value>0 else "",_decimal(value)])
	return " · ".join(descriptions)

func _commit_draft() -> bool:
	var success: bool = bool(GameState.call("buy_build",_draft_weapon,_draft_parts,_draft_target))
	if success:
		_notify("整套方案已装备至" + str(SLOT_NAMES.get(_draft_target,_draft_target)))
		_state_changed()
	else:
		_notify(str(GameState.last_error),true)
		_update_assembly(false)
	return success

func _open_assembly(weapon_id: String) -> void:
	_draft_weapon = weapon_id
	_draft_parts = {}
	_draft_target = "sidearm" if Catalog.get_item(weapon_id).get("category") == "pistol" else "primary"
	_select_tab("workbench")

func _start_action() -> void:
	if _raid_starting or GameState.raid_active:return
	if _tab in ["maps","deploy"]:_deploy()
	else:_select_tab("maps")

func _deploy() -> void:
	if _raid_starting or GameState.raid_active: return
	_raid_starting = true
	var action: Button=_bottom_nav.get_node("StartAction") as Button
	action.disabled=true
	action.text="正在进入…"
	if not GameState.begin_raid():
		_raid_starting=false
		action.disabled=false
		action.text="开始行动  →"
		_notify(str(GameState.last_error), true)
		return
	_lobby.hide()
	_toast.hide()
	_toast_time = 0
	if is_instance_valid(_world): _world.queue_free()
	_world = load("res://scripts/raid_world.gd").new() as Node3D
	add_child(_world)
	move_child(_world, 0)
	_world.hud_changed.connect(_update_hud)
	_world.raid_finished.connect(_raid_finished)
	_hud.show()
	_controls.enabled = true
	_world.start_raid(_entry_id)
	AppSettings.apply_scene(_world)
	_update_hud(_world.get_hud())
	_raid_starting = false
	action.disabled=false
	action.text="开始行动  →"

func _build_hud() -> void:
	_hud = Control.new()
	_hud.theme=theme
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_hud)
	var top_left := PanelContainer.new()
	top_left.position = Vector2(24, 20)
	top_left.size = Vector2(290, 118)
	top_left.add_theme_stylebox_override("panel", _style(Color(0.035,0.07,0.09,0.86),Color(0.23,0.4,0.43,0.8)))
	_hud.add_child(top_left)
	_hud_health=top_left
	var info := _vbox(top_left, 7)
	_hud_hp = _label("生命 100 / 100", 22)
	info.add_child(_hud_hp)
	_hud_ammo = _label("", 14, AMBER)
	_hud_ammo.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(_hud_ammo)
	var mission := PanelContainer.new()
	mission.position = Vector2(442,20)
	mission.size = Vector2(400, 82)
	mission.add_theme_stylebox_override("panel",_style(Color(0.035,0.07,0.09,0.86),Color(0.23,0.4,0.43,0.8)))
	_hud.add_child(mission)
	_hud_mission = mission
	var mission_box := _vbox(mission,4)
	_hud_time = _label("", 18)
	_hud_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_box.add_child(_hud_time)
	_hud_objective = _label("",13,TEAL)
	_hud_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_box.add_child(_hud_objective)
	var bag_panel := PanelContainer.new()
	bag_panel.position = Vector2(961, 20)
	bag_panel.size = Vector2(295, 84)
	bag_panel.add_theme_stylebox_override("panel",_style(Color(0.035,0.07,0.09,0.86),Color(0.23,0.4,0.43,0.8)))
	_hud.add_child(bag_panel)
	_hud_bag_panel = bag_panel
	_hud_bag = _label("",15,AMBER)
	bag_panel.add_child(_hud_bag)
	var exit_button := _button("菜单", _show_pause)
	exit_button.position = Vector2(1164,120)
	exit_button.size = Vector2(90,42)
	_hud.add_child(exit_button)
	_hud_menu = exit_button
	_hud_map = preload("res://scripts/ui_minimap.gd").new()
	_hud_map.position = Vector2(1080, 176)
	_hud_map.size = Vector2(176, 178)
	_hud.add_child(_hud_map)
	_hud_nearby = _label("",16,TEXT)
	_hud_nearby.position = Vector2(360,610)
	_hud_nearby.size = Vector2(550,42)
	_hud_nearby.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_nearby.add_theme_color_override("font_shadow_color",Color.BLACK)
	_hud_nearby.add_theme_constant_override("shadow_offset_x",1)
	_hud_nearby.add_theme_constant_override("shadow_offset_y",1)
	_hud.add_child(_hud_nearby)
	_hud_extract = ProgressBar.new()
	_hud_extract.position = Vector2(442,112)
	_hud_extract.size = Vector2(400,12)
	_hud_extract.max_value = 1.0
	_hud_extract.show_percentage = false
	_hud_extract.add_theme_stylebox_override("background",_style(Color(0.03,0.08,0.09,0.8),Color("1b4845"),4))
	_hud_extract.add_theme_stylebox_override("fill",_style(TEAL,TEAL,4))
	_hud.add_child(_hud_extract)
	_controls = preload("res://scripts/virtual_controls.gd").new()
	_hud.add_child(_controls)
	_controls.move_changed.connect(func(value: Vector2) -> void: if is_instance_valid(_world): _world.set_move(value))
	_controls.aim_changed.connect(func(value: Vector2, firing: bool) -> void: if is_instance_valid(_world): _world.set_aim(value,firing))
	_controls.fire_changed.connect(func(pressed: bool) -> void: if is_instance_valid(_world): _world.set_fire(pressed))
	_controls.reload_pressed.connect(func() -> void: if is_instance_valid(_world): _world.reload_weapon())
	_controls.interact_pressed.connect(func() -> void: if is_instance_valid(_world): _world.interact())
	_controls.medkit_pressed.connect(func() -> void: if is_instance_valid(_world): _world.use_medkit())
	_controls.weapon_pressed.connect(func(slot_name: String) -> void: if is_instance_valid(_world): _world.switch_weapon(slot_name))
	_hud.hide()

func _update_hud(info: Dictionary) -> void:
	if not is_instance_valid(_hud_hp): return
	_hud_map.call("update_info", info)
	_controls.call("set_status", int(info.get("medkits",0)), bool(info.get("reloading",false)), bool(info.get("searching",false)))
	_controls.call("set_weapons",info.get("weapons",[]))
	var hp: float = float(info.get("hp",100))
	_hud_hp.text = "生命  %d / %d" % [int(hp),int(info.get("max_hp",100))]
	_hud_hp.add_theme_color_override("font_color",DANGER if hp < 35 else TEXT)
	_hud_ammo.text = "%s  ·  %d / %d  |  备弹 %d" % [str(info.get("weapon_name","")),int(info.get("ammo",0)),int(info.get("magazine",0)),int(info.get("reserve",0))]
	var seconds: int = maxi(0,int(info.get("seconds",0)))
	_hud_time.text = "剩余时间  %02d:%02d" % [seconds / 60, seconds % 60]
	_hud_objective.text = str(info.get("objective",""))
	_hud_objective.visible = not _hud_objective.text.is_empty()
	_hud_mission.size.y = 84 if _hud_objective.visible else 54
	var grid_usage: Vector2i=GameState.raid_grid_usage()
	_hud_bag.text = "战利品  ◈ %s\n负重  %.1f / %.1f kg\n储物  %d / %d 格" % [_number(int(info.get("loot_value",0))),GameState.raid_weight(),GameState.carry_capacity(),grid_usage.x,grid_usage.y]
	_hud_nearby.text = str(info.get("nearby",""))
	_hud_extract.value = float(info.get("extract_progress",0))
	_hud_extract.visible = _hud_extract.value > 0

func _show_pause() -> void:
	if is_instance_valid(_result_overlay): return
	if is_instance_valid(_world):_world.set_input_blocked(true)
	_controls.enabled = false
	_result_overlay = _modal("行动菜单")
	var box: VBoxContainer = _result_overlay.get_meta("box") as VBoxContainer
	box.add_child(_wrap("封锁区不会暂停。放弃行动将失去本次携带的装备与战利品。",15))
	box.add_child(_button("继续行动",_resume_raid,true))
	box.add_child(_button("设置",func() -> void:_show_raid_settings()))
	box.add_child(_button("放弃行动 · 损失装备",func() -> void:
		_result_overlay.queue_free()
		_result_overlay = null
		if is_instance_valid(_world):
			GameState.finish_raid(false,{"reason":"主动放弃"})
			_raid_finished(false,{"reason":"主动放弃"})))

func _resume_raid() -> void:
	if is_instance_valid(_result_overlay):_result_overlay.queue_free()
	_result_overlay=null
	_controls.enabled=true
	if is_instance_valid(_world):_world.set_input_blocked(false)

func _show_raid_settings() -> void:
	if is_instance_valid(_result_overlay):_result_overlay.queue_free()
	_result_overlay=Control.new()
	_result_overlay.theme=theme
	_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_result_overlay)
	var bg:=ColorRect.new()
	bg.color=BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.add_child(bg)
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left=36
	margin.offset_right=-36
	margin.offset_top=24
	margin.offset_bottom=-24
	_result_overlay.add_child(margin)
	var box:=_vbox(margin,14)
	box.add_child(_button("‹ 返回行动",_resume_raid,false,160))
	box.add_child(load("res://scripts/ui_settings.gd").new())

func _modal(title_text: String) -> Control:
	var overlay := Control.new()
	overlay.theme=theme
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.01,0.025,0.035,0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500,300)
	panel.add_theme_stylebox_override("panel",_style(PANEL, Color("426b6b"),12))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	center.add_child(panel)
	var box := _vbox(panel,18)
	box.add_child(_label(title_text,28,TEAL))
	overlay.set_meta("box",box)
	return overlay

func _raid_finished(extracted: bool, details: Dictionary) -> void:
	_controls.enabled = false
	_hud.hide()
	if is_instance_valid(_world):
		_world.queue_free()
		_world = null
	if is_instance_valid(_result_overlay): _result_overlay.queue_free()
	_result_overlay = _modal("撤离成功" if extracted else "行动失败")
	var box: VBoxContainer = _result_overlay.get_meta("box") as VBoxContainer
	var result: Dictionary = GameState.last_result
	box.add_child(_wrap("战利品已存入仓库，可以出售换取资金。" if extracted else "本次携带装备及战利品已丢失。仓库中的其他物资依然保留。",16,TEXT))
	var value: int = int(result.get("loot_value",details.get("loot_value",0)))
	if extracted: box.add_child(_label("带出物资价值   ◈ %s" % _number(value),22,AMBER))
	var reason: String = str(details.get("reason", ""))
	if not reason.is_empty(): box.add_child(_label(reason,14,MUTED))
	box.add_child(_button("返回整备区",func() -> void:
		_result_overlay.queue_free()
		_result_overlay = null
		_lobby.show()
		_tab = "home"
		_refresh(),true))

func capture_mode(mode: String) -> void:
	if mode == "raid": _deploy()
	elif mode == "assembly":
		_select_tab("workbench")
		for item: Dictionary in Catalog.by_kind("attachment"):
			var part_slot: String = str(item.get("slot",""))
			if not _draft_parts.has(part_slot) and Catalog.compatible(_draft_weapon,str(item["id"]),part_slot):
				_draft_parts[part_slot] = str(item["id"])
		_update_assembly()
	elif mode=="map_detail":
		_select_tab("maps");_map_preview.focus_zone("terminal")
	elif mode=="market_weapons":
		_select_tab("market");_open_market_group("weapons")
	elif mode in ["market", "workbench", "stash", "catalog", "maps", "loadout"]: _select_tab(mode)
	else: _select_tab("home")

func _decimal(value: float) -> String:
	return String.num(value, 1).trim_suffix(".0")

func _interface(interface_id: String) -> String:
	return str(Catalog.call("interface_label", interface_id)) if Catalog.has_method("interface_label") else interface_id

func _interfaces(values: Array) -> String:
	var labels: Array[String] = []
	for value: Variant in values: labels.append(_interface(str(value)))
	return " / ".join(labels)

func _weapon_names(values: Array) -> String:
	var labels: Array[String] = []
	for value: Variant in values: labels.append(_item_name(str(value)))
	return " / ".join(labels)

func _layout_screen() -> void:
	var viewport_size: Vector2=get_viewport_rect().size
	var safe: Vector4=AppSettings.safe_insets(self)
	var width: float=viewport_size.x-safe.x-safe.z
	if is_instance_valid(_lobby_design):
		_lobby_design.size=viewport_size
		_header.position=Vector2(safe.x,safe.y)
		_header.size=Vector2(width,64)
		_header_title.position=Vector2(0 if _tab=="home" else 132,12)
		_credits_label.position=Vector2(width-336,12)
		_settings_button.position=Vector2(width-104,0)
		_bottom_nav.position=Vector2(safe.x,viewport_size.y-safe.w-76)
		_bottom_nav.size=Vector2(width,76)
		_bottom_nav.get_node("StartAction").position=Vector2(width-284,0)
		_content.position=Vector2(safe.x,safe.y+78)
		_content.size=Vector2(width,viewport_size.y-safe.y-safe.w-168)
	if is_instance_valid(_hud_mission):
		_hud_health.position=Vector2(safe.x,safe.y)
		_hud_health.size=Vector2(300,94)
		_hud_mission.position=Vector2((viewport_size.x-360)*.5,safe.y)
		_hud_mission.size.x=360
		_hud_bag_panel.position=Vector2(viewport_size.x-safe.z-270,safe.y)
		_hud_bag_panel.size=Vector2(270,90)
		_hud_menu.position=Vector2(viewport_size.x-safe.z-110,safe.y+104)
		_hud_menu.size=Vector2(110,64)
		_hud_map.position=Vector2(viewport_size.x-safe.z-186,safe.y+184)
		_hud_map.size=Vector2(186,150)
		_hud_extract.position=Vector2((viewport_size.x-360)*.5,safe.y+104)
		_hud_extract.size.x=360
		_hud_nearby.position=Vector2(viewport_size.x*.5-260,viewport_size.y-safe.w-132)
		_hud_nearby.size=Vector2(520,42)
	if is_instance_valid(_toast):
		_toast.position=Vector2((viewport_size.x-720)*.5,viewport_size.y-safe.w-132)

