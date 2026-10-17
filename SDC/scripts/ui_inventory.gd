extends VBoxContainer
signal feedback(message: String,is_error: bool)
signal assembly_requested(weapon_id: String)
const Grid = preload("res://scripts/inventory_grid.gd")
const GridView = preload("res://scripts/ui_inventory_grid.gd")
const TouchButton = preload("res://scripts/touch_button.gd")
const TouchScroll = preload("res://scripts/touch_scroll.gd")
const SLOT_NAMES := {"primary":"主武器","secondary":"副武器","sidearm":"手枪","helmet":"头盔","visor":"面罩","body_armor":"防弹衣","armored_rig":"弹挂甲","backpack":"背包"}
var _views: Array = []
var _left: ScrollContainer
var _right: ScrollContainer
var _left_content: VBoxContainer
var _right_content: VBoxContainer
var _summary: Label
var _selection: Label
var _buttons: Dictionary = {}
var _loadout_signature: String = ""
var selected_uid: String = ""
var _pointer: int = -99
var _start: Vector2
var _point: Vector2
var _start_time: int = 0
var _mode: String = ""
var _source_uid: String = ""
var _last_tap_uid: String = ""
var _last_tap_time: int = 0
var _font: Font
var _ghost: PanelContainer
var _ghost_label: Label

func _ready() -> void:
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",10)
	_font=load("res://assets/fonts/NotoSansSC.ttf")
	var heading:=HBoxContainer.new()
	add_child(heading)
	_summary=_label("",20)
	_summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(_summary)
	heading.add_child(_label("点击选择 · 双击快捷转移",17,Color("a7b8b5")))
	var columns:=HBoxContainer.new()
	columns.add_theme_constant_override("separation",18)
	columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(columns)
	_left=_column(columns)
	_right=_column(columns)
	_left_content=_content(_left)
	_right_content=_content(_right)
	var toolbar:=HBoxContainer.new()
	toolbar.add_theme_constant_override("separation",8)
	add_child(toolbar)
	_selection=_label("选择物品后，可点格子放置",18)
	_selection.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_selection.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	toolbar.add_child(_selection)
	for action: String in ["旋转","拆分","快捷转移","出售","改枪"]:
		var button:=TouchButton.new()
		button.text=action
		button.custom_minimum_size=Vector2(92 if action!="快捷转移" else 132,60)
		button.pressed.connect(_action.bind(action))
		toolbar.add_child(button)
		_buttons[action]=button
	add_child(_label("长按物品后拖动；快速上下划动翻页。物品放入区块时自动选择横竖方向。",16,Color("94aaa7")))
	var drag_layer:=CanvasLayer.new()
	drag_layer.layer=30
	add_child(drag_layer)
	_ghost=PanelContainer.new()
	_ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_ghost.custom_minimum_size=Vector2(220,64)
	var ghost_style:=StyleBoxFlat.new()
	ghost_style.bg_color=Color(.06,.1,.12,.94)
	ghost_style.border_color=Color("d6dfdc")
	ghost_style.set_border_width_all(2)
	ghost_style.set_content_margin_all(12)
	_ghost.add_theme_stylebox_override("panel",ghost_style)
	drag_layer.add_child(_ghost)
	_ghost_label=_label("",18)
	_ghost_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_ghost.add_child(_ghost_label)
	_ghost.hide()
	_rebuild_equipment()
	refresh_inventory()
	resized.connect(_resize_stash)

func _column(parent: Node) -> ScrollContainer:
	var panel:=PanelContainer.new()
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("152128")
	style.border_color=Color("34474d")
	style.set_border_width_all(1)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel",style)
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var scroll:=TouchScroll.new()
	panel.add_child(scroll)
	return scroll

func _content(parent: Node) -> VBoxContainer:
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box

func _label(caption: String,font_size: int,color: Color = Color("edf0e7")) -> Label:
	var label:=Label.new()
	label.text=caption
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	return label

func _rebuild_equipment() -> void:
	_last_tap_uid=""
	_last_tap_time=0
	var saved_left: int = _left.scroll_vertical
	var saved_right: int = _right.scroll_vertical
	for box: VBoxContainer in [_left_content,_right_content]:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_views.clear()
	_left_content.add_child(_label("携行装备",24))
	var armor:=GridContainer.new()
	armor.columns=3
	armor.add_theme_constant_override("h_separation",8)
	armor.add_theme_constant_override("v_separation",8)
	_left_content.add_child(armor)
	for slot: String in ["helmet","visor","body_armor"]:_equipment(armor,slot,Vector2(100,86))
	var carrying:=GridContainer.new()
	carrying.columns=2
	carrying.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	carrying.add_theme_constant_override("h_separation",8)
	_left_content.add_child(carrying)
	for slot: String in ["armored_rig","backpack"]:_equipment(carrying,slot,Vector2(150,86))
	var guns:=HFlowContainer.new()
	guns.add_theme_constant_override("h_separation",8)
	guns.add_theme_constant_override("v_separation",8)
	_left_content.add_child(guns)
	for slot: String in ["primary","secondary","sidearm"]:_equipment(guns,slot,Vector2(170,86))
	_container("pockets","随身口袋")
	_container("rig","弹挂")
	_container("backpack","背包")
	_left_content.add_child(_label("携行负重  %.1f / %.1f kg"%[GameState.raid_weight(),GameState.carry_capacity()],19,Color("e6bf7d")))
	var overflow: Array = []
	for record: Dictionary in GameState.inventory_items:
		if str(record.container)=="overflow":overflow.append(record)
	if not overflow.is_empty():
		_left_content.add_child(_label("旧存档待归位物品",20,Color("edb27f")))
		for record: Dictionary in overflow:
			var button:=TouchButton.new()
			button.text=str(Catalog.get_item(str(record.item)).get("name",""))+" ×"+str(record.qty)+" · 归位"
			button.pressed.connect(func() -> void:_perform(GameState.inventory_transfer(str(record.uid),"stash")))
			_left_content.add_child(button)
	_right_content.add_child(_label("仓库   /   500 格",24))
	var stash:=GridView.new()
	stash.container_id="stash"
	stash.columns=10
	stash.rows=50
	stash.cell=50
	_right_content.add_child(stash)
	_views.append(stash)
	_loadout_signature=JSON.stringify([GameState.loadout,GameState.weapon_ammo])
	call_deferred("_restore_scroll",saved_left,saved_right)
	call_deferred("_resize_stash")

func _restore_scroll(left: int,right: int) -> void:
	_left.scroll_vertical=left
	_right.scroll_vertical=right

func _equipment(parent: Node,slot: String,dimensions: Vector2) -> void:
	var view:=GridView.new()
	view.equipment_slot=slot
	view.caption=SLOT_NAMES[slot]
	if slot in ["primary","secondary","sidearm"]:
		var ammo_id: String=str(GameState.weapon_ammo.get(slot,""))
		var caliber: String=str(Catalog.get_item(ammo_id).get("caliber",""))
		if not caliber.is_empty():view.caption+=" · "+caliber
	view.custom_minimum_size=dimensions
	view.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(view)
	_views.append(view)

func _container(id: String,title: String) -> void:
	var definitions: Array = Grid.blocks(id,GameState.loadout)
	var item_id: String = str(GameState.loadout.get("armored_rig" if id=="rig" else "backpack",""))
	var count: int = 0
	for block: Dictionary in definitions:count+=int(block.w)*int(block.h)
	var heading:=HBoxContainer.new()
	_left_content.add_child(heading)
	if id!="pockets" and not item_id.is_empty():
		var picture:=TextureRect.new()
		var path: String = "res://assets/icons/items/"+item_id+".png"
		if ResourceLoader.exists(path):picture.texture=preload("res://scripts/item_textures.gd").icon(item_id)
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size=Vector2(58,58)
		heading.add_child(picture)
	heading.add_child(_label(title+"  ·  "+str(count)+" 格",21,Color("d6d9bf")))
	if definitions.is_empty():
		_left_content.add_child(_label("未装备"+title,17,Color("819995")))
		return
	var flow:=HFlowContainer.new()
	flow.add_theme_constant_override("h_separation",8)
	flow.add_theme_constant_override("v_separation",8)
	_left_content.add_child(flow)
	for block: Dictionary in definitions:
		var view:=GridView.new()
		view.container_id=id
		view.block_id=str(block.id)
		view.columns=int(block.w)
		view.rows=int(block.h)
		view.cell=48
		view.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
		flow.add_child(view)
		_views.append(view)

func _resize_stash() -> void:
	for view: Control in _views:
		if view.equipment_slot.is_empty() and view.container_id=="stash":
			view.cell=maxf(42,floorf((_right.size.x-12)/10))
			view.custom_minimum_size=Vector2(10*view.cell,50*view.cell)
			view.queue_redraw()

func refresh_inventory() -> void:
	if _loadout_signature!=JSON.stringify([GameState.loadout,GameState.weapon_ammo]):_rebuild_equipment()
	_summary.text="整备仓库    /    携行 %.1f kg"%GameState.raid_weight()
	if not selected_uid.is_empty() and _selected_record().is_empty():selected_uid=""
	for view: Control in _views:
		view.selected_uid=selected_uid
		view.queue_redraw()
	var record: Dictionary = _selected_record()
	_selection.text="选择物品后，可点格子放置" if record.is_empty() else str(Catalog.get_item(str(record.item)).get("name",""))+" ×"+str(record.get("qty",1))
	for key: String in _buttons:_buttons[key].disabled=record.is_empty()
	if not record.is_empty():
		_buttons["改枪"].disabled=str(Catalog.get_item(str(record.item)).get("kind",""))!="weapon"
		_buttons["拆分"].disabled=int(record.get("qty",1))<=1
		_buttons["旋转"].disabled=selected_uid.begins_with("equip/")
		_buttons["出售"].disabled=selected_uid.begins_with("equip/")

func _selected_record() -> Dictionary:
	if selected_uid.begins_with("equip/"):
		var id: String = str(GameState.loadout.get(selected_uid.trim_prefix("equip/"),""))
		return {} if id.is_empty() else {"uid":selected_uid,"item":id,"qty":1,"rotated":false}
	return Grid.find_record(GameState.inventory_items,selected_uid)

func _hit(point: Vector2) -> Dictionary:
	for view: Control in _views:
		var hit: Dictionary = view.hit(point)
		if not hit.is_empty():return hit
	return {}

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():return
	# Ignore the mouse copy even when it arrives before the original touch.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==-1:return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:_press(event.index,event.position)
		elif _pointer==event.index:_release(event.position,event.canceled)
	elif event is InputEventScreenDrag and event.index==_pointer:_drag(event.position)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:_press(-2,event.position)
		elif _pointer==-2:_release(event.position,event.canceled)
	elif event is InputEventMouseMotion and _pointer==-2:_drag(event.position)

func _press(pointer: int,point: Vector2) -> void:
	if _pointer!=-99:return
	var hit: Dictionary = _hit(point)
	if hit.is_empty():return
	_pointer=pointer
	_start=point
	_point=point
	_start_time=Time.get_ticks_msec()
	_mode="pending"
	_source_uid=str(hit.uid)

func _drag(point: Vector2) -> void:
	_point=point
	if _mode=="pending" and point.distance_to(_start)>12:
		if not _source_uid.is_empty() and (_pointer==-2 or absf(point.x-_start.x)>absf(point.y-_start.y) or Time.get_ticks_msec()-_start_time>280):_begin_drag()
		else:_mode="scroll"
	if _mode=="drag":
		_preview_drop()
		get_viewport().set_input_as_handled()
	queue_redraw()

func _begin_drag() -> void:
	_mode="drag"
	_last_tap_uid=""
	_last_tap_time=0
	selected_uid=_source_uid
	_left.cancel_gesture()
	_right.cancel_gesture()
	AppSettings.ui_feedback()
	refresh_inventory()

func _release(point: Vector2,cancelled: bool) -> void:
	var hit: Dictionary = _hit(point)
	if not cancelled and _mode=="drag" and not hit.is_empty():_perform(GameState.inventory_transfer(_source_uid,str(hit.container),str(hit.block),hit.cell))
	elif not cancelled and _mode=="pending" and not hit.is_empty():_tap(hit)
	if _mode!="scroll":get_viewport().set_input_as_handled()
	_pointer=-99
	_mode=""
	_source_uid=""
	_ghost.hide()
	for view: Control in _views:
		view.hover_spot={}
		view.queue_redraw()
	_left.cancel_gesture()
	_right.cancel_gesture()
	queue_redraw()

func _tap(hit: Dictionary) -> void:
	var uid: String = str(hit.uid)
	var now: int = Time.get_ticks_msec()
	if not uid.is_empty() and selected_uid==uid and uid==_last_tap_uid and now-_last_tap_time<360:
		_perform(GameState.inventory_quick_transfer(uid))
		return
	if not selected_uid.is_empty() and uid!=selected_uid and (uid.is_empty() or str(hit.container).begins_with("equip/") or str(_selected_record().get("item",""))==str(Grid.find_record(GameState.inventory_items,uid).get("item","?"))):
		_perform(GameState.inventory_transfer(selected_uid,str(hit.container),str(hit.block),hit.cell))
		# A placement is complete. A following tap must select the newly equipped
		# item first, rather than turning the placement into a double-tap unequip.
		return
	else:
		selected_uid=uid
		refresh_inventory()
	_last_tap_uid=uid
	_last_tap_time=now

func _preview_drop() -> void:
	for view: Control in _views:
		view.hover_spot={}
		view.queue_redraw()
	var hit: Dictionary = _hit(_point)
	var record: Dictionary = _selected_record()
	if hit.is_empty() or record.is_empty() or str(hit.container).begins_with("equip/"):return
	var spot: Dictionary = Grid.find_spot(record,str(hit.container),GameState.inventory_items,GameState.loadout,str(hit.block),hit.cell)
	if not spot.is_empty():
		spot.size=Grid.footprint(record,bool(spot.rotated))
		hit.view.hover_spot=spot

func _process(delta: float) -> void:
	if _mode=="pending" and not _source_uid.is_empty() and _pointer>=0 and Time.get_ticks_msec()-_start_time>300:
		_begin_drag()
	if _mode=="drag":
		for scroll: ScrollContainer in [_left,_right]:
			var rectangle: Rect2 = scroll.get_global_rect()
			if rectangle.has_point(_point):
				if _point.y<rectangle.position.y+42:scroll.scroll_vertical-=roundi(420*delta)
				elif _point.y>rectangle.end.y-42:scroll.scroll_vertical+=roundi(420*delta)
		_preview_drop()
		_update_ghost()
		queue_redraw()

func _update_ghost() -> void:
	_ghost.visible=_mode=="drag"
	_ghost.position=_point+Vector2(-110,-100)
	_ghost_label.text=str(Catalog.get_item(str(_selected_record().get("item",""))).get("name",""))

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pointer=-99
		_mode=""
		if is_instance_valid(_ghost):_ghost.hide()

func _action(action: String) -> void:
	if action=="旋转":_perform(GameState.inventory_rotate(selected_uid),false)
	elif action=="拆分":_perform(GameState.inventory_split(selected_uid),false)
	elif action=="快捷转移":_perform(GameState.inventory_quick_transfer(selected_uid))
	elif action=="出售":_perform(GameState.inventory_sell(selected_uid))
	elif action=="改枪":
		var record: Dictionary = _selected_record()
		if not record.is_empty():assembly_requested.emit(str(record.item))

func _perform(ok: bool,clear_selection: bool = true) -> void:
	_last_tap_uid=""
	_last_tap_time=0
	feedback.emit("已放置" if ok else GameState.last_error,not ok)
	if ok and clear_selection:selected_uid=""
	refresh_inventory()
