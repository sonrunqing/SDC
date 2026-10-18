extends PanelContainer
## Inline, read-only details for the selected inventory instance.
const Grid = preload("res://scripts/inventory_grid.gd")
const Rarity = preload("res://scripts/item_rarity.gd")
const TouchButton = preload("res://scripts/touch_button.gd")
const TouchScroll = preload("res://scripts/touch_scroll.gd")
const TYPE_NAMES := {"smg":"冲锋枪","rifle":"突击步枪","sniper":"精确步枪","shotgun":"霰弹枪","machine_gun":"机枪","pistol":"手枪","helmet":"头盔","visor":"面罩","body_armor":"防弹衣","rig":"弹挂","armored_rig":"防弹弹挂","backpack":"背包","compensator":"补偿器","flash_hider":"消焰器","muzzle_brake":"制退器","suppressor":"消音器","grip":"握把","handguard":"护木","laser":"激光指示器","magazine":"弹匣 / 供弹组件","optic":"瞄具","stock":"枪托","medical":"医疗用品","valuable":"战利品"}
const SLOT_NAMES := {"primary":"主武器","secondary":"副武器","sidearm":"手枪","helmet":"头盔","visor":"面罩","body_armor":"防弹衣","armored_rig":"弹挂","backpack":"背包","muzzle":"枪口","grip":"握把","stock":"枪托","magazine":"供弹组件","optic":"瞄具","laser":"激光","handguard":"护木"}
const STAT_NAMES := {"recoil_control":"后坐力控制","horizontal_control":"水平后坐力控制","ergonomics":"人机功效","range":"射程","damage":"击发威力","rpm":"射速","accuracy":"精准度","magazine":"弹容量","suppression":"消音能力"}
const CALIBERS := {"9x19":"9×19 mm","45acp":".45 ACP","57x28":"5.7×28 mm","556x45":"5.56×45 mm","545x39":"5.45×39 mm","762x39":"7.62×39 mm","300blk":".300 BLK","308win":".308 Win","762x54r":"7.62×54R","338lm":".338 LM","12g":"12 号霰弹","20g":"20 号霰弹"}
const LOOT_DESCRIPTIONS := {
	"loot_wire":"绝缘包覆的导线物资，适合在有限携行空间中按价值取舍。",
	"loot_battery":"工业用电源物资，携行时可对照单件重量与出售价值。",
	"loot_tools":"精密作业工具组；单件重量较高，可比较每格收益后决定是否带走。",
	"loot_filter":"净化用滤芯耗材，可作为战利品带回并出售。",
	"loot_radio":"加密通信设备，属于稀有电子战利品。",
	"loot_processor":"运算用电子芯片，重量较低，属于稀有战利品。",
	"loot_watch":"机械计时器，属于稀有贵重物资。",
	"loot_statue":"金像类贵重藏品，单件价值较高，也会占用较多负重。",
	"loot_documents":"密封保存的档案材料，属于稀有战利品。",
	"loot_lens":"光学镜片器件，可带回仓库换取游戏币。",
	"loot_fuel":"装有燃料的容器，单位重量较高，携行时需留意负重。",
	"loot_scrap":"合金工业零件，可在撤离后出售。"
}
var _title: Label
var _toggle: TouchButton
var _scroll: TouchScroll
var _text: Label
var _drag_hint: Label
var _expanded: bool = true
var _signature: String = ""
var _uid: String = ""

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_PASS
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("17252b")
	style.border_color=Color("3b5057")
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",4)
	add_child(column)
	var heading:=HBoxContainer.new()
	column.add_child(heading)
	_title=Label.new()
	_title.add_theme_font_size_override("font_size",19)
	_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	heading.add_child(_title)
	_toggle=TouchButton.new()
	_toggle.minimum_touch_height=44
	_toggle.custom_minimum_size=Vector2(98,44)
	_toggle.pressed.connect(_toggle_expanded)
	heading.add_child(_toggle)
	_scroll=TouchScroll.new()
	_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y=100
	column.add_child(_scroll)
	var body:=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)
	_text=Label.new()
	_text.add_theme_font_size_override("font_size",17)
	_text.add_theme_color_override("font_color",Color("d6e2df"))
	_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_text.mouse_filter=Control.MOUSE_FILTER_PASS
	body.add_child(_text)
	_drag_hint=Label.new()
	_drag_hint.text="拖动物品中，松手放置。"
	_drag_hint.add_theme_font_size_override("font_size",17)
	_drag_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	body.add_child(_drag_hint)
	_drag_hint.hide()
	_show_empty()

func set_available_height(height: float) -> void:
	# Keep the inventory grid available even on short landscape screens.
	_scroll.custom_minimum_size.y=clampf(height*.23,48,138)

func present(record: Dictionary,dragging: bool = false) -> void:
	_toggle.disabled=dragging
	_text.visible=not dragging
	_drag_hint.visible=dragging
	if dragging:
		# Preserve the allocated panel space during a drag, so cells do not move
		# beneath the owning finger. This panel never overlays the grid.
		_scroll.cancel_gesture()
		return
	if record.is_empty():
		_show_empty()
		return
	var item: Dictionary=Catalog.get_item(str(record.get("item","")))
	if item.is_empty():
		_show_empty()
		return
	var next_uid: String=str(record.get("uid",""))
	var signature: String=JSON.stringify([record,GameState.weapon_builds,GameState.weapon_ammo,GameState.loadout,GameState.inventory_items])
	if next_uid!=_uid:
		_scroll.cancel_gesture()
		_scroll.scroll_vertical=0
	_uid=next_uid
	if signature!=_signature:
		_signature=signature
		_title.text="%s ×%d · 物品详情"%[str(item.get("name","物品")),int(record.get("qty",1))]
		_text.text=_describe(item,record)
	_update_expanded()

func _show_empty() -> void:
	_uid=""
	_signature=""
	_title.text="物品详情"
	_text.text="轻点物品查看说明与规格。\n选中后可点格子放置，也可双击快捷转移。"
	_text.show()
	_drag_hint.hide()
	_scroll.cancel_gesture()
	_scroll.scroll_vertical=0
	_update_expanded()

func _toggle_expanded() -> void:
	_expanded=not _expanded
	_scroll.cancel_gesture()
	_update_expanded()

func _update_expanded() -> void:
	_scroll.visible=_expanded
	_toggle.text="收起详情" if _expanded else "展开详情"

func _describe(item: Dictionary,record: Dictionary) -> String:
	var lines: Array[String]=[]
	var kind: String=str(item.get("kind",""))
	var category: String=str(item.get("category",""))
	lines.append(str(TYPE_NAMES.get(category,"弹药" if kind=="ammo" else "物品")))
	var description: String=_description(item)
	if not description.is_empty():lines.append(description)
	lines.append("")
	lines.append("【规格】")
	match kind:
		"weapon":_weapon_details(lines,item,record)
		"attachment":_attachment_details(lines,item)
		"ammo":_ammo_details(lines,item)
		"armor":_armor_details(lines,item,record)
		"consumable":
			_field(lines,item,"heal","生命恢复"," 点",true)
			_field(lines,item,"uses","每件可用次数"," 次")
		"loot":
			lines.append("物资分类："+Rarity.group_label(item))
			lines.append("稀有度："+Rarity.label(item))
			lines.append("获取方式：行动中搜获，成功撤离后带回仓库。")
	var dimensions: Vector2i=Grid.footprint(record,bool(record.get("rotated",false)))
	lines.append("当前占格：%d × %d（%d 格）"%[dimensions.x,dimensions.y,dimensions.x*dimensions.y])
	lines.append("数量：%d / 每叠上限 %d"%[int(record.get("qty",1)),Grid.stack_limit(str(item.get("id","")))])
	_field(lines,item,"weight","单件重量"," kg")
	if int(record.get("qty",1))>1 and item.has("weight"):
		lines.append("本叠总重：%s kg"%_number(float(item.weight)*int(record.qty)))
	lines.append("位置："+_location(record))
	lines.append("")
	lines.append("【交易】")
	if kind=="loot":lines.append("商店不出售该战利品。")
	else:_field(lines,item,"price","购入单价"," 游戏币")
	_field(lines,item,"sell_price","出售单价"," 游戏币")
	if item.has("sell_price") and int(record.get("qty",1))>1:
		lines.append("本叠出售总额：%d 游戏币"%(int(item.sell_price)*int(record.qty)))
	if str(record.get("uid","")).begins_with("equip/"):
		lines.append("已装备物品需先卸下，才可出售。")
	return "\n".join(lines)

func _description(item: Dictionary) -> String:
	var kind: String=str(item.get("kind",""))
	var category: String=str(item.get("category",""))
	if kind=="loot":return str(item.get("description",LOOT_DESCRIPTIONS.get(str(item.get("id","")),"")))
	if kind=="attachment":
		var context: String=str({
			"compensator":"枪口补偿组件，改善连续射击时的控枪表现。",
			"flash_hider":"枪口消焰组件，提供下列控枪、精准或消音增益。",
			"muzzle_brake":"枪口制退组件，着重改善后坐力控制。",
			"suppressor":"枪口消音组件，改善消音表现；安装标准须与枪口匹配。",
			"grip":"前端握持组件，用于调整控枪与人机功效。",
			"handguard":"枪械护木组件，按机匣平台和专用接口安装。",
			"laser":"辅助指向组件，提供下列精准度和操控增益。",
			"magazine":"供弹组件；实际弹容量取决于所配枪械与该组件的容量增益。",
			"optic":"瞄准组件，按瞄具底座标准选装；具体增益见下方。",
			"stock":"枪械尾部支撑组件，调整后坐力控制和人机功效。"
		}.get(category,""))
		return _description_with_context(item,context)
	if kind=="ammo":
		var id: String=str(item.get("id",""))
		var type: String="穿甲弹" if id.ends_with("_ap") else ("扩张弹" if id.ends_with("_hp") else "普通弹")
		return _description_with_context(item,"%s口径%s，只能用于同口径枪械。穿透和弹道加成如下。"%[_caliber(str(item.get("caliber",""))),type])
	return str(item.get("description",""))

func _description_with_context(item: Dictionary,context: String) -> String:
	var original: String=str(item.get("description",""))
	if original.is_empty():return context
	return original if context.is_empty() or context==original else original+"\n"+context

func _weapon_details(lines: Array[String],item: Dictionary,record: Dictionary) -> void:
	var slot: String=str(record.get("uid","")).trim_prefix("equip/")
	var equipped: bool=str(record.get("uid","")).begins_with("equip/")
	var parts: Dictionary=GameState.weapon_builds.get(slot,{}) if equipped else {}
	var stats: Dictionary=Catalog.weapon_stats(str(item.get("id","")),parts)
	lines.append("配置："+("当前已装备配置" if equipped else "基础枪械配置"))
	if item.has("caliber"):lines.append("口径："+_caliber(str(item.caliber)))
	for key: String in ["recoil_control","horizontal_control","ergonomics","range","damage","rpm","accuracy","magazine","suppression"]:
		var suffix: String=" m" if key=="range" else (" 发 / 分钟" if key=="rpm" else (" 发" if key=="magazine" else ""))
		_field(lines,stats,key,str(STAT_NAMES[key]),suffix)
	var ballistics: Dictionary=item.get("ballistics",{})
	_field(lines,ballistics,"muzzle_velocity","基础弹丸初速"," m/s")
	if not parts.is_empty():
		lines.append("已安装配件：")
		var assembly_weight: float=float(item.get("weight",0))
		for mount: Variant in parts:
			lines.append("  %s · %s"%[str(SLOT_NAMES.get(str(mount),str(mount))),_item_name(str(parts[mount]))])
			assembly_weight+=float(Catalog.get_item(str(parts[mount])).get("weight",0))
		lines.append("含当前配件总重：%s kg"%_number(assembly_weight))
	var slots: Dictionary=item.get("slots",{})
	if not slots.is_empty():
		lines.append("安装接口：")
		for mount: Variant in slots:
			lines.append("  %s · %s"%[str(SLOT_NAMES.get(str(mount),str(mount))),_interfaces(slots[mount])])
	var ammo_names: Array[String]=[]
	for ammo: Dictionary in Catalog.by_kind("ammo"):
		if str(ammo.get("caliber",""))==str(item.get("caliber","")):ammo_names.append(str(ammo.get("name","")))
	if not ammo_names.is_empty():lines.append("可用弹药："+"、".join(ammo_names))
	if equipped:
		var ammo_id: String=str(GameState.weapon_ammo.get(slot,""))
		if not ammo_id.is_empty():lines.append("当前弹药选择："+_item_name(ammo_id))

func _attachment_details(lines: Array[String],item: Dictionary) -> void:
	var slot: String=str(item.get("slot",""))
	lines.append("安装部位："+str(SLOT_NAMES.get(slot,slot)))
	if item.has("interfaces"):lines.append("安装接口："+_interfaces(item.interfaces))
	var modifiers: Dictionary=item.get("modifiers",{})
	for key: Variant in modifiers:
		var suffix: String=" m" if str(key)=="range" else (" 发 / 分钟" if str(key)=="rpm" else (" 发" if str(key)=="magazine" else ""))
		_field(lines,modifiers,str(key),str(STAT_NAMES.get(str(key),str(key)))+"增益",suffix,true)
	var names: Array[String]=[]
	var capacities: Array[String]=[]
	for weapon: Dictionary in Catalog.by_kind("weapon"):
		var weapon_id: String=str(weapon.get("id",""))
		if not Catalog.compatible(weapon_id,str(item.get("id",""))):continue
		names.append(str(weapon.get("name",""))+"（"+_caliber(str(weapon.get("caliber","")))+"）")
		if slot=="magazine":
			var build: Dictionary={slot:str(item.get("id",""))}
			var stats: Dictionary=Catalog.weapon_stats(weapon_id,build)
			if stats.has("magazine"):capacities.append("%s：%d 发"%[str(weapon.get("name","")),int(stats.magazine)])
	lines.append("兼容枪械："+("、".join(names) if not names.is_empty() else "当前目录中没有兼容平台"))
	if not capacities.is_empty():lines.append("安装后弹容量："+"；".join(capacities))

func _ammo_details(lines: Array[String],item: Dictionary) -> void:
	if item.has("caliber"):lines.append("口径："+_caliber(str(item.caliber)))
	_field(lines,item,"penetration","穿透值")
	var ballistics: Dictionary=item.get("ballistics",{})
	_field(lines,ballistics,"bonus_damage","弹药伤害加成"," 点",true)
	_field(lines,ballistics,"power_multiplier","击发威力系数"," 倍")
	_field(lines,ballistics,"velocity_multiplier","初速系数"," 倍")
	_field(lines,ballistics,"drag_multiplier","飞行阻力系数"," 倍")
	var weapons: Array[String]=[]
	for weapon: Dictionary in Catalog.by_kind("weapon"):
		if str(weapon.get("caliber",""))==str(item.get("caliber","")):weapons.append(str(weapon.get("name","")))
	lines.append("兼容枪械："+("、".join(weapons) if not weapons.is_empty() else "当前目录中没有同口径枪械"))

func _armor_details(lines: Array[String],item: Dictionary,record: Dictionary) -> void:
	var category: String=str(item.get("category",""))
	if category=="rig":lines.append("防护：无；普通弹挂只提供分区收纳。")
	else:
		_field(lines,item,"level","防护等级"," 级")
		_field(lines,item,"protection","防护值")
		_field(lines,item,"durability","耐久上限")
		if record.has("durability"):_field(lines,record,"durability","当前耐久")
	if category!="rig" and item.has("armor_zone"):
		var zone: String=str(item.armor_zone)
		lines.append("防护部位："+str({"head":"头部","face":"面部","torso":"躯干","none":"无防弹覆盖"}.get(zone,zone)))
	if category in ["backpack","rig","armored_rig"]:
		var container: String="backpack" if category=="backpack" else "rig"
		var equipment_slot: String=Catalog.equipment_slot(str(item.get("id","")))
		var blocks: Array=Grid.blocks(container,{equipment_slot:str(item.get("id",""))})
		var cells: int=0
		var groups: Dictionary={}
		for block: Dictionary in blocks:
			cells+=int(block.w)*int(block.h)
			var shape: String="%d×%d"%[int(block.w),int(block.h)]
			groups[shape]=int(groups.get(shape,0))+1
		var layout: Array[String]=[]
		for shape: String in groups:layout.append("%s 区块 ×%d"%[shape,int(groups[shape])])
		lines.append("实际储物容量：%d 格"%cells)
		lines.append("分区布局："+"；".join(layout))
		_field(lines,item,"capacity","装备后的负重上限增加"," kg",true)
		if category=="backpack":lines.append("可与普通弹挂或防弹弹挂同时装备。")
		elif category=="rig":lines.append("可与防弹衣和背包同时装备。")
		else:lines.append("一件实物同时占用弹挂与防弹衣穿戴位；防弹衣栏淡色图映射同一件装备。可配背包，与独立防弹衣互斥。")
		if str(record.get("uid",""))=="equip/"+equipment_slot:
			var used: int=0
			for stored: Dictionary in GameState.inventory_items:
				if str(stored.get("container",""))==container:
					var dimensions: Vector2i=Grid.footprint(stored,bool(stored.get("rotated",false)))
					used+=dimensions.x*dimensions.y
			lines.append("当前已占用：%d / %d 格"%[used,cells])
	if category=="body_armor":lines.append("可同时装备普通弹挂和背包；与防弹弹挂互斥。")
	if category=="helmet":
		if item.has("visor_mounts"):lines.append("面罩接口："+_interfaces(item.visor_mounts))
		var names: Array[String]=[]
		for visor: Dictionary in Catalog.by_category("visor"):
			if Catalog.visor_compatible(str(item.get("id","")),str(visor.get("id",""))):names.append(str(visor.get("name","")))
		lines.append("兼容面罩："+("、".join(names) if not names.is_empty() else "无"))
	elif category=="visor":
		if item.has("visor_mount"):lines.append("安装接口："+Catalog.interface_label(str(item.visor_mount)))
		var names: Array[String]=[]
		for helmet: Dictionary in Catalog.by_category("helmet"):
			if Catalog.visor_compatible(str(helmet.get("id","")),str(item.get("id",""))):names.append(str(helmet.get("name","")))
		lines.append("兼容头盔："+("、".join(names) if not names.is_empty() else "无"))

func _location(record: Dictionary) -> String:
	var uid: String=str(record.get("uid",""))
	if uid.begins_with("equip/"):return "已装备 · "+str(SLOT_NAMES.get(uid.trim_prefix("equip/"),uid.trim_prefix("equip/")))
	var container: String=str(record.get("container",""))
	var name: String=str({"stash":"仓库","pockets":"随身口袋","rig":"弹挂","backpack":"背包","overflow":"待归位区"}.get(container,"物品栏"))
	if record.has("x") and record.has("y"):
		name+=" · 第%d区 / 第%d列第%d行"%[int(record.get("block",0))+1,int(record.x)+1,int(record.y)+1]
	return name

func _interfaces(ids: Array) -> String:
	var names: Array[String]=[]
	for id: Variant in ids:names.append(Catalog.interface_label(str(id)))
	return "、".join(names)

func _item_name(id: String) -> String:
	return str(Catalog.get_item(id).get("name",id))

func _caliber(id: String) -> String:
	return str(CALIBERS.get(id,id))

func _field(lines: Array[String],source: Dictionary,key: String,title: String,suffix: String = "",positive: bool = false) -> void:
	if not source.has(key):return
	var value: float=float(source[key])
	lines.append(title+"："+("+" if positive and value>=0 else "")+_number(value)+suffix)

func _number(value: float) -> String:
	var formatted: String="%.3f"%value
	while formatted.ends_with("0"):formatted=formatted.trim_suffix("0")
	return formatted.trim_suffix(".")
