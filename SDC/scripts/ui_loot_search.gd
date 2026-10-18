extends Control
## Phone-only container search page: live source grid + actual carried blocks.
signal close_requested
const Grid=preload("res://scripts/inventory_grid.gd")
const GridView=preload("res://scripts/ui_inventory_grid.gd")
const TouchButton=preload("res://scripts/touch_button.gd")
const TouchScroll=preload("res://scripts/touch_scroll.gd")
const TouchOption=preload("res://scripts/touch_option.gd")
const TouchQuantity=preload("res://scripts/touch_quantity.gd")
var world: Node3D
var _views: Array=[]
var _source: Control
var _scrolls: Array=[]
var _left: VBoxContainer
var _title: Label
var _status: Label
var _health: Label
var _summary: Label
var _details: Label
var _message: Label
var _pause: Button
var _take: Button
var _quantity: Control
var _destination: String=""
var _margin: MarginContainer
var _selected: String=""
var _snapshot: Dictionary={}
var _refresh_clock: float=0
var _pointer: int=-1
var _start:=Vector2.ZERO
var _point:=Vector2.ZERO
var _started: int=0
var _source_uid: String=""
var _mode: String=""
var _last_tap: String=""
var _last_time: int=0
var _ghost: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	add_to_group("mobile_touch_modal")
	add_to_group("mobile_touch_gesture")
	var background:=ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color=Color(.035,.04,.052,.97)
	add_child(background)
	_margin=MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var root:=VBoxContainer.new()
	root.add_theme_constant_override("separation",10)
	_margin.add_child(root)
	var header:=HBoxContainer.new()
	root.add_child(header)
	_title=_label("搜索容器",26)
	_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_health=_label("",18)
	header.add_child(_health)
	header.add_child(_button("关闭容器",request_cancel,164))
	var columns:=HBoxContainer.new()
	columns.add_theme_constant_override("separation",16)
	columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	_left=_column(columns)
	_summary=_label("携行装备",22)
	_left.add_child(_summary)
	var gear:=HBoxContainer.new()
	gear.add_theme_constant_override("separation",12)
	_left.add_child(gear)
	for slot: String in ["helmet","body_armor","armored_rig","backpack"]:
		var id: String=str(GameState.loadout.get(slot,""))
		if not id.is_empty():
			var label:=_label(str(Catalog.get_item(id).get("name","")),16)
			label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			gear.add_child(label)
	for container: String in ["pockets","rig","backpack"]:_carry(container)
	var right: VBoxContainer=_column(columns)
	_status=_label("正在打开容器…",22)
	right.add_child(_status)
	_source=GridView.new()
	_source.container_id="loot"
	_source.use_source_records=true
	_source.cell=64
	right.add_child(_source)
	_views.append(_source)
	var hint:=_label("搜索完成的物品可选择拿取",17)
	hint.modulate=Color("a9b3ae")
	right.add_child(hint)
	_details=_label("轻点物品查看详情；双击快捷拿取。",18)
	_details.custom_minimum_size.y=56
	_details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_details.max_lines_visible=3
	root.add_child(_details)
	var actions:=HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	root.add_child(actions)
	_pause=_button("暂停搜索",func() -> void:world.toggle_container_search();_refresh(),150)
	actions.add_child(_pause)
	var target:=TouchOption.new()
	target.custom_minimum_size=Vector2(176,64)
	for name: String in ["放入：自动","放入：背包","放入：弹挂","放入：口袋"]:target.add_item(name)
	target.item_selected.connect(func(index: int) -> void:_destination=["","backpack","rig","pockets"][index])
	actions.add_child(target)
	_quantity=TouchQuantity.new()
	_quantity.min_value=1
	_quantity.max_value=1
	_quantity.value=1
	_quantity.custom_minimum_size=Vector2(205,64)
	actions.add_child(_quantity)
	_message=_label("",17)
	_message.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	actions.add_child(_message)
	_take=_button("拿取所选",_take_selected,172)
	actions.add_child(_take)
	_ghost=_label("",20)
	_ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_ghost.add_theme_color_override("font_color",Color("f0e8cf"))
	add_child(_ghost)
	_ghost.hide()
	resized.connect(_layout)
	_layout()
	_refresh()

func _label(text: String,font_size: int) -> Label:
	var label:=Label.new()
	label.text=text
	label.add_theme_font_size_override("font_size",font_size)
	return label

func _button(text: String,action: Callable,width: float) -> Button:
	var button:=TouchButton.new()
	button.text=text
	button.minimum_touch_height=64
	button.custom_minimum_size=Vector2(width,64)
	button.pressed.connect(action)
	return button

func _column(parent: Node) -> VBoxContainer:
	var panel:=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("161e24")
	style.border_color=Color("424d51")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel",style)
	var scroll:=TouchScroll.new()
	panel.add_child(scroll)
	_scrolls.append(scroll)
	var column:=VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10)
	scroll.add_child(column)
	return column

func _carry(container: String) -> void:
	var blocks: Array=Grid.blocks(container,GameState.loadout)
	if blocks.is_empty():return
	_left.add_child(_label(str({"pockets":"随身口袋","rig":"弹挂","backpack":"背包"}[container]),20))
	var flow:=HFlowContainer.new()
	flow.add_theme_constant_override("h_separation",8)
	flow.add_theme_constant_override("v_separation",8)
	_left.add_child(flow)
	for block: Dictionary in blocks:
		var view:=GridView.new()
		view.container_id=container
		view.block_id=str(block.id)
		view.columns=int(block.w)
		view.rows=int(block.h)
		view.cell=58
		view.use_source_records=true
		flow.add_child(view)
		_views.append(view)

func _layout() -> void:
	if _margin==null:return
	var safe: Vector4=AppSettings.safe_insets(self)
	_margin.offset_left=safe.x
	_margin.offset_top=safe.y
	_margin.offset_right=-safe.z
	_margin.offset_bottom=-safe.w
	if _source!=null:
		var available: float=maxf(260,(size.x-safe.x-safe.z-68)*.5)
		_source.cell=clampf(available/maxi(1,_source.columns),42,68)
		_source.custom_minimum_size=Vector2(_source.columns,_source.rows)*_source.cell
		_source.queue_redraw()

func _selected_record() -> Dictionary:
	var source: Array=_snapshot.get("records",[])
	var record: Dictionary=Grid.find_record(source,_selected)
	if not record.is_empty() and int(record.qty)>0 and bool(record.discovered):return record
	return Grid.find_record(GameState.raid_grid_items,_selected)

func _refresh() -> void:
	if not is_instance_valid(world):return
	_snapshot=world.get_container_snapshot()
	if _snapshot.is_empty():return
	_title.text="搜索 · "+str(_snapshot.name)
	_source.columns=int(_snapshot.columns)
	_source.rows=int(_snapshot.rows)
	_source.source_records=_snapshot.records
	_source.concealed_uids={}
	for record: Dictionary in _snapshot.records:
		if not bool(record.discovered):_source.concealed_uids[str(record.uid)]=true
	_source.searching_uid=str(_snapshot.active_uid) if not bool(_snapshot.paused) and float(_snapshot.opening)<=0 else ""
	_source.search_progress=float(_snapshot.progress)
	_status.text="容器已空" if bool(_snapshot.empty) else ("正在打开容器…" if float(_snapshot.opening)>0 else ("搜索完成" if bool(_snapshot.complete) else ("已暂停搜索" if bool(_snapshot.paused) else "搜索中  %d / %d"%[int(_snapshot.discovered),int(_snapshot.total)])))
	_pause.text="继续搜索" if bool(_snapshot.paused) else "暂停搜索"
	_pause.disabled=bool(_snapshot.complete)
	var usage: Vector2i=GameState.raid_grid_usage()
	_summary.text="携行装备  %.1f / %.1f kg  ·  %d / %d 格"%[GameState.raid_weight(),GameState.carry_capacity(),usage.x,usage.y]
	var hud: Dictionary=world.get_hud()
	var seconds: int=int(hud.seconds)
	_health.text="生命 %d  ·  %02d:%02d"%[int(hud.hp),seconds/60,seconds%60]
	for view: Control in _views:
		if view!=_source:view.source_records=GameState.raid_grid_items
		view.selected_uid=_selected
		view.queue_redraw()
	var selected: Dictionary=_selected_record()
	_take.disabled=selected.is_empty() or not _selected.begins_with("loot/")
	if selected.is_empty():
		_details.text="轻点物品查看详情；双击拿取，或拖到左侧携行格子。"
	else:
		var item: Dictionary=Catalog.get_item(str(selected.item))
		var cells: Vector2i=Grid.item_size(str(selected.item))
		_details.text="%s ×%d    %d×%d 格    单件 %.2f kg    出售 ◈ %d\n%s"%[str(item.get("name","")),int(selected.qty),cells.x,cells.y,float(item.get("weight",0)),int(item.get("sell_price",0)),"容器中的物品，仅拿取所需数量。" if _selected.begins_with("loot/") else "当前携行物品，可在左侧区块内调整位置。"]
	_layout()

func _choose(uid: String) -> void:
	_selected=uid
	var record: Dictionary=_selected_record()
	_quantity.max_value=maxi(1,int(record.get("qty",1)))
	_quantity.value=_quantity.max_value
	_refresh()

func _take_selected() -> void:
	_take_to(_destination,"",Vector2i(-1,-1))

func _take_to(destination: String,block: String,cell: Vector2i) -> void:
	var record: Dictionary=_selected_record()
	if record.is_empty():return
	cancel_gesture()
	var ok: bool=false
	if _selected.begins_with("loot/"):
		ok=world.take_container_item(_selected,int(_quantity.value),destination,block,cell)
	else:ok=GameState.move_raid_item(_selected,destination,block,cell)
	_message.text="已放入携行区" if ok else GameState.last_error
	_last_tap=""
	_last_time=0
	if ok:_selected=""
	_refresh()

func _hit(point: Vector2) -> Dictionary:
	for view: Control in _views:
		var hit: Dictionary=view.hit(point)
		if not hit.is_empty():return hit
	return {}

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventScreenTouch or event is InputEventScreenDrag):return
	var modals: Array[Node]=get_tree().get_nodes_in_group("mobile_touch_modal")
	if modals.is_empty() or modals.back()!=self:return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			if _pointer!=-1:return
			var hit: Dictionary=_hit(event.position)
			if hit.is_empty():return
			_pointer=event.index
			_start=event.position
			_point=_start
			_started=Time.get_ticks_msec()
			_source_uid=str(hit.uid)
			_mode="pending"
		elif event.index==_pointer:
			var hit: Dictionary=_hit(event.position)
			if not event.canceled and not hit.is_empty():
				if _mode=="drag" and str(hit.container)!="loot":_take_to(str(hit.container),str(hit.block),hit.cell)
				elif _mode=="pending":_tap(hit)
			if _mode!="scroll":get_viewport().set_input_as_handled()
			var remembered_uid: String=_last_tap
			var remembered_time: int=_last_time
			var remember: bool=not event.canceled and _mode=="pending"
			cancel_gesture()
			if remember:
				_last_tap=remembered_uid
				_last_time=remembered_time
	elif event.index==_pointer:
		_point=event.position
		if _mode=="pending" and _point.distance_to(_start)>12:
			if not _source_uid.is_empty() and absf(_point.x-_start.x)>absf(_point.y-_start.y):_begin_drag()
			else:_mode="scroll"
		if _mode=="drag":get_viewport().set_input_as_handled()

func _tap(hit: Dictionary) -> void:
	var uid: String=str(hit.uid)
	var chosen: Dictionary=_selected_record()
	var target: Dictionary=Grid.find_record(GameState.raid_grid_items,uid)
	var stackable: bool=not target.is_empty() and str(target.item)==str(chosen.get("item","")) and Grid.stack_limit(str(target.item))>1
	if str(hit.container)!="loot" and not chosen.is_empty() and uid!=_selected and (uid.is_empty() or stackable):
		_take_to(str(hit.container),str(hit.block),hit.cell)
		return
	if _source.concealed_uids.has(uid):
		_message.text="该物品尚未完成搜索"
		return
	var now: int=Time.get_ticks_msec()
	if uid==_selected and uid==_last_tap and now-_last_time<360 and uid.begins_with("loot/"):
		_take_selected()
		return
	_choose(uid)
	_last_tap=uid
	_last_time=now

func _begin_drag() -> void:
	if _source.concealed_uids.has(_source_uid) or _source_uid.is_empty():
		_mode="scroll"
		return
	_choose(_source_uid)
	if _selected_record().is_empty():return
	_mode="drag"
	_last_tap=""
	for scroll: Control in _scrolls:scroll.cancel_gesture()
	_ghost.text=str(Catalog.get_item(str(_selected_record().item)).get("name",""))
	_ghost.show()

func _process(delta: float) -> void:
	_refresh_clock-=delta
	if _refresh_clock<=0:
		_refresh_clock=.1
		_refresh()
	if _mode=="pending" and not _source_uid.is_empty() and Time.get_ticks_msec()-_started>300:_begin_drag()
	if _mode=="drag":
		_ghost.position=_point+Vector2(12,-45)
		for scroll: ScrollContainer in _scrolls:
			var rect: Rect2=scroll.get_global_rect()
			if rect.has_point(_point):
				if _point.y<rect.position.y+40:scroll.scroll_vertical-=roundi(350*delta)
				elif _point.y>rect.end.y-40:scroll.scroll_vertical+=roundi(350*delta)
		for view: Control in _views:view.hover_spot={}
		var hit: Dictionary=_hit(_point)
		if not hit.is_empty() and str(hit.container)!="loot":
			var record: Dictionary=_selected_record()
			if record.is_empty():cancel_gesture();return
			var spot: Dictionary=Grid.find_spot(record,str(hit.container),GameState.raid_grid_items,GameState.loadout,str(hit.block),hit.cell)
			if not spot.is_empty():
				spot.size=Grid.footprint(record,bool(spot.rotated))
				hit.view.hover_spot=spot
				hit.view.queue_redraw()
		_source.queue_redraw()

func cancel_gesture() -> void:
	_pointer=-1
	_mode=""
	_source_uid=""
	_last_tap=""
	_last_time=0
	if is_instance_valid(_ghost):_ghost.hide()
	for view: Control in _views:
		view.hover_spot={}
		view.queue_redraw()
	for scroll: Control in _scrolls:scroll.cancel_gesture()

func request_cancel() -> void:
	cancel_gesture()
	close_requested.emit()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_PAUSED] or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):cancel_gesture()
