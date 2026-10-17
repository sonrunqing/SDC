extends Node
## Persistent extraction economy. Canonical equipment has three independent weapon slots.

signal changed

const STARTING_CREDITS: int = 12000
const SAVE_VERSION: int = 3
const Grid = preload("res://scripts/inventory_grid.gd")
const InventoryState = preload("res://scripts/inventory_state.gd")
const DEFAULT_SAVE_PATH: String = "user://extraction_save_v1.json"
const WEAPON_SLOTS: Array[String] = ["primary", "secondary", "sidearm"]
const ARMOR_SLOTS: Array[String] = ["helmet", "body_armor", "backpack", "armored_rig", "visor"]
const EQUIPMENT_SLOTS: Array[String] = ["primary", "secondary", "sidearm", "helmet", "body_armor", "backpack", "armored_rig", "visor"]
const MAX_STACK: int = 100000

var save_path: String = DEFAULT_SAVE_PATH
var credits: int = STARTING_CREDITS
var stash: Dictionary = {}
var loadout: Dictionary = {}
var active_weapon_slot: String = "primary"
var weapon_builds: Dictionary = {"primary": {}, "secondary": {}, "sidearm": {}}
var weapon_ammo: Dictionary = {"primary": "", "secondary": "", "sidearm": ""}
var ammo_carry_plan: Dictionary = {}
var raid_active: bool = false
var raid_loot: Dictionary = {}
var last_result: Dictionary = {}
var last_error: String = ""
var raid_ammo_by_id: Dictionary = {}
var raid_loaded_by_slot: Dictionary = {"primary": 0, "secondary": 0, "sidearm": 0}
var raid_medkits: int = 0
var raid_medkit_id: String = ""
var inventory_items: Array = []
var raid_grid_items: Array = []
var raid_packed_extra: Dictionary = {}
var _grid_defer: bool = false
var _grid_preferred: String = ""
var _grid_carried_first: bool = false

# Legacy aliases always refer to the currently active gun. Never store duplicate equipment here.
var attachments: Dictionary:
	get:
		return weapon_builds.get(active_weapon_slot, {})
	set(value):
		weapon_builds[active_weapon_slot] = value
var raid_ammo: int:
	get:
		return get_raid_ammo()
	set(value):
		var ammo_id: String = str(weapon_ammo.get(active_weapon_slot, ""))
		if not ammo_id.is_empty():
			raid_ammo_by_id[ammo_id] = maxi(0, value)
var raid_loaded_ammo: int:
	get:
		return get_loaded_ammo()
	set(value):
		raid_loaded_by_slot[active_weapon_slot] = maxi(0, value)
var raid_ammo_id: String:
	get:
		return str(weapon_ammo.get(active_weapon_slot, ""))
var raid_meds: int:
	get:
		return raid_medkits
	set(value):
		raid_medkits = maxi(0, value)

func _ready() -> void:
	if not load_game():
		reset_progress()

func _empty_loadout() -> Dictionary:
	var result: Dictionary = {"weapon": "", "ammo": ""}
	for slot: String in EQUIPMENT_SLOTS:
		result[slot] = ""
	return result

func _empty_weapon_builds() -> Dictionary:
	return {"primary": {}, "secondary": {}, "sidearm": {}}

func _empty_weapon_ammo() -> Dictionary:
	return {"primary": "", "secondary": "", "sidearm": ""}

func _sync_aliases() -> void:
	loadout["weapon"] = str(loadout.get(active_weapon_slot, ""))
	loadout["ammo"] = str(weapon_ammo.get(active_weapon_slot, ""))

func _choose_active() -> void:
	if not str(loadout.get(active_weapon_slot, "")).is_empty():
		_sync_aliases()
		return
	active_weapon_slot = "primary"
	for slot: String in WEAPON_SLOTS:
		if not str(loadout.get(slot, "")).is_empty():
			active_weapon_slot = slot
			break
	_sync_aliases()

func _fail(message: String) -> bool:
	last_error = message
	return false

func _commit() -> void:
	_sync_aliases()
	if _grid_defer:return
	inventory_items=Grid.reconcile(inventory_items,stash,loadout)
	last_error = ""
	save_game()
	changed.emit()

func _item(id: String) -> Dictionary:
	return Catalog.get_item(id)

func _count(id: String) -> int:
	return int(stash.get(id, 0))

func _give(id: String, quantity: int = 1) -> void:
	if not id.is_empty() and quantity > 0:
		stash[id] = _count(id) + quantity

func _take(id: String, quantity: int = 1) -> bool:
	if quantity <= 0 or _count(id) < quantity:
		return false
	var remaining: int = _count(id) - quantity
	if remaining > 0:
		stash[id] = remaining
	else:
		stash.erase(id)
	Grid.remove_quantity(inventory_items,id,quantity,_grid_preferred,_grid_carried_first)
	return true

func _cheapest(kind: String, category: String = "", caliber: String = "", owned_only: bool = false) -> String:
	var best: String = ""
	var lowest: int = 2147483647
	for id: String in Catalog.items:
		var item: Dictionary = _item(id)
		if str(item.get("kind", "")) != kind:
			continue
		if not category.is_empty() and str(item.get("category", "")) != category:
			continue
		if not caliber.is_empty() and str(item.get("caliber", "")) != caliber:
			continue
		if owned_only and _count(id) <= 0:
			continue
		if int(item.get("price", 0)) < lowest:
			best = id
			lowest = int(item.get("price", 0))
	return best

func _preferred(id: String, kind: String, category: String = "", caliber: String = "") -> String:
	return id if not _item(id).is_empty() else _cheapest(kind, category, caliber)

func _clear_raid_supplies() -> void:
	raid_packed_extra={}
	raid_ammo_by_id = {}
	raid_loaded_by_slot = {"primary": 0, "secondary": 0, "sidearm": 0}
	raid_medkits = 0
	raid_medkit_id = ""

func reset_progress() -> void:
	credits = STARTING_CREDITS
	stash = {}
	inventory_items = []
	loadout = _empty_loadout()
	weapon_builds = _empty_weapon_builds()
	weapon_ammo = _empty_weapon_ammo()
	active_weapon_slot = "primary"
	ammo_carry_plan = {}
	raid_active = false
	raid_loot = {}
	_clear_raid_supplies()
	last_result = {}
	var weapon_id: String = _preferred("weapon_reed9", "weapon", "smg")
	if weapon_id.is_empty():
		weapon_id = _cheapest("weapon")
	loadout["primary"] = weapon_id
	var ammo_id: String = _cheapest("ammo", "", str(_item(weapon_id).get("caliber", "")))
	weapon_ammo["primary"] = ammo_id
	_give(ammo_id, 180)
	ammo_carry_plan[ammo_id] = 90
	loadout["helmet"] = _preferred("helmet_moss_1a", "armor", "helmet")
	loadout["body_armor"] = _preferred("body_armor_fiber_1a", "armor", "body_armor")
	loadout["backpack"] = _preferred("backpack_daypack", "armor", "backpack")
	_give(_preferred("medkit_field", "consumable"), 6)
	_pack_initial_inventory()
	_commit()

func buy(id: String, quantity: int = 1) -> bool:
	if raid_active:
		return _fail("行动中无法交易物品")
	var item: Dictionary = _item(id)
	if item.is_empty() or quantity < 1 or quantity > MAX_STACK:
		return _fail("物品或购买数量无效")
	if str(item.get("kind", "")) == "loot":
		return _fail("战利品只能在行动中搜获")
	var cost: int = int(item.get("price", 0)) * quantity
	if cost <= 0 or credits < cost:
		return _fail("资金不足")
	if _count(id) + quantity > MAX_STACK:
		return _fail("仓库中该物品已满")
	var proposed: Dictionary = stash.duplicate(true)
	proposed[id]=int(proposed.get(id,0))+quantity
	if Grid.overflow_count(Grid.reconcile(inventory_items,proposed,loadout))>Grid.overflow_count(inventory_items):
		return _fail("仓库 500 格已满，请整理空位")
	credits -= cost
	_give(id, quantity)
	_commit()
	return true

func sell(id: String, quantity: int = 1) -> bool:
	if raid_active:
		return _fail("行动中无法交易物品")
	if quantity < 1 or quantity > MAX_STACK or _item(id).is_empty():
		return _fail("物品或出售数量无效")
	if _count(id) < quantity:
		return _fail("仓库数量不足；已装备或安装的物品需要先卸下")
	var value: int = int(_item(id).get("sell_price", 0)) * quantity
	if value <= 0:
		return _fail("此物品无法出售")
	_take(id, quantity)
	credits += value
	_commit()
	return true

func _valid_weapon_target(weapon_id: String, target_slot: String) -> bool:
	if not WEAPON_SLOTS.has(target_slot):
		return false
	var weapon: Dictionary = _item(weapon_id)
	if str(weapon.get("kind", "")) != "weapon":
		return false
	var is_pistol: bool = str(weapon.get("category", "")) == "pistol"
	return is_pistol if target_slot == "sidearm" else not is_pistol

func _add_count(counts: Dictionary, id: String, quantity: int = 1) -> void:
	if not id.is_empty() and quantity > 0:
		counts[id] = int(counts.get(id, 0)) + quantity

func _target_inventory(target_slot: String) -> Dictionary:
	var available: Dictionary = stash.duplicate(true)
	_add_count(available, str(loadout.get(target_slot, "")))
	var old_parts: Dictionary = weapon_builds.get(target_slot, {})
	for id: Variant in old_parts.values():
		_add_count(available, str(id))
	return available

func _invalid_quote(message: String) -> Dictionary:
	return {"valid": false, "error": message, "cost": 0, "can_afford": false, "missing": {}, "owned": {}, "required": {}}

func quote_build(weapon_id: String, parts: Dictionary, target_slot: String = "primary") -> Dictionary:
	# Pure calculation: drafting and quoting never change inventory, equipped gear, or money.
	if raid_active:
		return _invalid_quote("行动中无法购买或更换整枪")
	if not _valid_weapon_target(weapon_id, target_slot):
		return _invalid_quote("武器或目标栏位无效：手枪使用手枪栏，长枪使用主/副武器栏")
	var required: Dictionary = {weapon_id: 1}
	for key: Variant in parts:
		if not key is String or not parts[key] is String:
			return _invalid_quote("配件选择必须使用有效插槽和物品编号")
		var part_id: String = str(parts[key])
		if part_id.is_empty() or not Catalog.compatible(weapon_id, part_id, str(key)):
			return _invalid_quote("配件接口或专用枪械型号不兼容：" + str(key))
		_add_count(required, part_id)
	var available: Dictionary = _target_inventory(target_slot)
	var missing: Dictionary = {}
	var owned: Dictionary = {}
	var cost: int = 0
	for id: String in required:
		var need: int = int(required[id])
		var have: int = mini(need, int(available.get(id, 0)))
		if have > 0:
			owned[id] = have
		if have < need:
			var price: int = int(_item(id).get("price", 0))
			if price <= 0:
				return _invalid_quote("所选物品不支持购买")
			missing[id] = need - have
			cost += price * (need - have)
	return {"valid": true, "error": "", "cost": cost, "can_afford": credits >= cost, "missing": missing, "owned": owned, "required": required}

func buy_build(weapon_id: String, parts: Dictionary, target_slot: String = "primary") -> bool:
	var quote: Dictionary = quote_build(weapon_id, parts, target_slot)
	if not bool(quote["valid"]):
		return _fail(str(quote["error"]))
	if not bool(quote["can_afford"]):
		return _fail("资金不足，整套装配未购买，仓库与装备保持原样")
	# Compute the complete post-transaction stash before changing any live state.
	var next_stash: Dictionary = _target_inventory(target_slot)
	var owned: Dictionary = quote["owned"]
	for id: String in owned:
		var remainder: int = int(next_stash.get(id, 0)) - int(owned[id])
		if remainder < 0:
			return _fail("库存已发生变化，请重新获取整枪报价")
		if remainder > 0:
			next_stash[id] = remainder
		else:
			next_stash.erase(id)
	var proposed_loadout: Dictionary=loadout.duplicate(true)
	proposed_loadout[target_slot]=weapon_id
	if Grid.overflow_count(Grid.reconcile(inventory_items,next_stash,proposed_loadout))>Grid.overflow_count(inventory_items):
		return _fail("仓库没有空间回收原武器或配件")
	stash = next_stash
	credits -= int(quote["cost"])
	loadout[target_slot] = weapon_id
	weapon_builds[target_slot] = parts.duplicate(true)
	_refresh_slot_ammo(target_slot)
	active_weapon_slot = target_slot
	_commit()
	return true

func _refresh_slot_ammo(slot: String) -> void:
	var caliber: String = str(_item(str(loadout.get(slot, ""))).get("caliber", ""))
	var current_id: String = str(weapon_ammo.get(slot, ""))
	if str(_item(current_id).get("caliber", "")) != caliber or current_id.is_empty():
		current_id = _cheapest("ammo", "", caliber, true) if not caliber.is_empty() else ""
		weapon_ammo[slot] = current_id
	if not current_id.is_empty() and not ammo_carry_plan.has(current_id):
		ammo_carry_plan[current_id] = 0

func equip_weapon(id: String, target_slot: String) -> bool:
	if raid_active:
		return _fail("行动中无法更换出战装备")
	if not _grid_defer:
		for record: Dictionary in inventory_items:
			if str(record.item)==id:return inventory_transfer(str(record.uid),"equip/"+target_slot)
	if not _valid_weapon_target(id, target_slot):
		return _fail("武器与栏位不匹配，手枪只能放入手枪栏")
	if _count(id) < 1:
		return _fail("请先将武器购买或带回仓库")
	_take(id)
	_return_weapon_slot(target_slot)
	loadout[target_slot] = id
	_refresh_slot_ammo(target_slot)
	active_weapon_slot = target_slot
	_commit()
	return true

func equip(id: String) -> bool:
	if raid_active:
		return _fail("行动中无法更换出战装备")
	var item: Dictionary = _item(id)
	if item.is_empty() or _count(id) < 1:
		return _fail("请先将物品购买或带回仓库")
	var kind: String = str(item.get("kind", ""))
	if not _grid_defer and kind=="armor":
		for record: Dictionary in inventory_items:
			if str(record.item)==id:return inventory_transfer(str(record.uid),"equip/"+str(item.get("category","")))
	if kind == "weapon":
		return equip_weapon(id, "sidearm" if str(item.get("category", "")) == "pistol" else "primary")
	if kind == "ammo":
		return select_weapon_ammo(active_weapon_slot, id)
	var slot: String = str(item.get("category", ""))
	if kind != "armor" or not ARMOR_SLOTS.has(slot):
		return _fail("此物品不能放入装备栏")
	if slot == "visor" and not Catalog.visor_compatible(str(loadout.get("helmet", "")), id):
		return _fail("面罩卡槽不兼容，请更换对应接口的头盔")
	_take(id)
	_return_armor_slot(slot)
	if slot == "body_armor":
		_return_armor_slot("armored_rig")
	elif slot == "armored_rig":
		_return_armor_slot("body_armor")
	loadout[slot] = id
	if slot == "helmet":
		var visor_id: String = str(loadout.get("visor", ""))
		if not visor_id.is_empty() and not Catalog.visor_compatible(id, visor_id):
			_return_armor_slot("visor")
	_commit()
	return true

func _return_armor_slot(slot: String) -> void:
	_give(str(loadout.get(slot, "")))
	loadout[slot] = ""

func _return_weapon_slot(slot: String) -> void:
	_give(str(loadout.get(slot, "")))
	var parts: Dictionary = weapon_builds.get(slot, {})
	for id: Variant in parts.values():
		_give(str(id))
	weapon_builds[slot] = {}
	weapon_ammo[slot] = ""
	loadout[slot] = ""

func unequip(slot: String) -> bool:
	if raid_active:
		return _fail("行动中无法卸下出战装备")
	if slot == "weapon":
		slot = active_weapon_slot
	if not _grid_defer and EQUIPMENT_SLOTS.has(slot):return inventory_transfer("equip/"+slot,"stash")
	if slot == "ammo":
		weapon_ammo[active_weapon_slot] = ""
		_commit()
		return true
	if not EQUIPMENT_SLOTS.has(slot) or str(loadout.get(slot, "")).is_empty():
		return _fail("此装备栏为空")
	if WEAPON_SLOTS.has(slot):
		_return_weapon_slot(slot)
		_choose_active()
	else:
		_return_armor_slot(slot)
		if slot == "helmet":
			_return_armor_slot("visor")
	_commit()
	return true

func set_active_weapon(slot: String) -> bool:
	if not WEAPON_SLOTS.has(slot) or str(loadout.get(slot, "")).is_empty():
		return _fail("此武器栏为空")
	active_weapon_slot = slot
	_sync_aliases()
	last_error = ""
	if not raid_active:
		save_game()
	changed.emit()
	return true

func select_weapon_ammo(slot: String, ammo_id: String) -> bool:
	if raid_active:
		return _fail("行动中无法更改弹药配置")
	if not WEAPON_SLOTS.has(slot):
		return _fail("武器栏位无效")
	var weapon: Dictionary = _item(str(loadout.get(slot, "")))
	var ammo: Dictionary = _item(ammo_id)
	if str(weapon.get("kind", "")) != "weapon" or str(ammo.get("kind", "")) != "ammo" or str(weapon.get("caliber", "")) != str(ammo.get("caliber", "")):
		return _fail("弹药口径与该栏位武器不匹配")
	weapon_ammo[slot] = ammo_id
	if not ammo_carry_plan.has(ammo_id):
		ammo_carry_plan[ammo_id] = 0
	_commit()
	return true

func set_ammo_carry(ammo_id: String, quantity: int) -> bool:
	if raid_active:
		return _fail("行动中无法更改携弹数量")
	if str(_item(ammo_id).get("kind", "")) != "ammo" or quantity < 0 or quantity > MAX_STACK:
		return _fail("弹药或携带数量无效")
	ammo_carry_plan[ammo_id] = quantity
	_commit()
	return true

func install_attachment(id: String) -> bool:
	if not _grid_defer:return InventoryState.attachment_transaction(self,"install_attachment",id)
	if raid_active:
		return _fail("行动中无法改装武器")
	var item: Dictionary = _item(id)
	var slot: String = str(item.get("slot", ""))
	if str(item.get("kind", "")) != "attachment" or _count(id) < 1:
		return _fail("仓库中没有该配件")
	if not Catalog.compatible(str(loadout.get(active_weapon_slot, "")), id, slot):
		return _fail("接口或专用枪械型号不兼容")
	_take(id)
	_give(str(attachments.get(slot, "")))
	attachments[slot] = id
	_commit()
	return true

func remove_attachment(slot: String) -> bool:
	if not _grid_defer:return InventoryState.attachment_transaction(self,"remove_attachment",slot)
	if raid_active:
		return _fail("行动中无法改装武器")
	if not attachments.has(slot):
		return _fail("此接口没有安装配件")
	_give(str(attachments[slot]))
	attachments.erase(slot)
	_commit()
	return true

func weapon_stats(slot: String = "") -> Dictionary:
	if slot.is_empty():
		slot = active_weapon_slot
	return Catalog.weapon_stats(str(loadout.get(slot, "")), weapon_builds.get(slot, {}))

func get_selected_ammo() -> Dictionary:
	return _item(str(weapon_ammo.get(active_weapon_slot, "")))

func get_selected_medkit() -> Dictionary:
	return _item(raid_medkit_id)

func _packed_count(id: String) -> int:return InventoryState.packed_count(self,id)
func _pack_initial_inventory() -> void:InventoryState.initial_pack(self)
func inventory_transfer(uid: String,destination: String,block: String = "",cell: Vector2i = Vector2i(-1,-1)) -> bool:return InventoryState.transfer(self,uid,destination,block,cell)
func inventory_quick_transfer(uid: String) -> bool:return InventoryState.quick_transfer(self,uid)
func inventory_rotate(uid: String) -> bool:return InventoryState.rotate(self,uid)
func inventory_sell(uid: String) -> bool:return InventoryState.sell_record(self,uid)
func inventory_split(uid: String) -> bool:return InventoryState.split(self,uid)

func _pack_raid_grid(loot: Dictionary,include_loaded: bool = false) -> Array:
	var counts: Dictionary=loot.duplicate(true)
	for id: String in raid_packed_extra:counts[id]=int(counts.get(id,0))+int(raid_packed_extra[id])
	for id: String in raid_ammo_by_id:counts[id]=int(counts.get(id,0))+int(raid_ammo_by_id[id])
	if include_loaded:
		for slot: String in WEAPON_SLOTS:
			var id: String=str(weapon_ammo.get(slot,""))
			if not id.is_empty():counts[id]=int(counts.get(id,0))+get_loaded_ammo(slot)
	if not raid_medkit_id.is_empty():counts[raid_medkit_id]=int(counts.get(raid_medkit_id,0))+raid_medkits
	var packed: Array=Grid.reconcile(raid_grid_items,counts,loadout)
	var placed: Array=[]
	var pending: Array=[]
	for record: Dictionary in packed:
		if str(record.container) in ["rig","pockets","backpack"]:placed.append(record)
		else:pending.append(record)
	for record: Dictionary in pending:
		var found: bool=false
		for container: String in ["rig","pockets","backpack"]:
			var spot: Dictionary=Grid.find_spot(record,container,placed,loadout)
			if not spot.is_empty():
				Grid.apply_spot(record,spot)
				found=true
				break
		if not found:record.container="overflow"
		placed.append(record)
	return placed

func raid_grid_usage() -> Vector2i:
	var used: int=0
	var capacity: int=0
	for record: Dictionary in raid_grid_items:
		var size: Vector2i=Grid.footprint(record,bool(record.get("rotated",false)))
		used+=size.x*size.y
	for container: String in ["rig","pockets","backpack"]:
		for block: Dictionary in Grid.blocks(container,loadout):capacity+=int(block.w)*int(block.h)
	return Vector2i(used,capacity)

func _best_owned_medical() -> String:
	var best: String = ""
	var most_healing: float = 0.0
	for id: String in stash:
		var item: Dictionary = _item(id)
		if str(item.get("kind", "")) == "consumable" and _packed_count(id) > 0:
			var healing: float = float(item.get("heal", 0.0))
			if healing > most_healing:
				best = id
				most_healing = healing
	return best

func carry_capacity() -> float:
	var capacity: float = 12.0
	for slot: String in ["backpack", "armored_rig"]:
		capacity += float(_item(str(loadout.get(slot, ""))).get("capacity", 0.0))
	return capacity

func _weight_of(items: Dictionary) -> float:
	var weight: float = 0.0
	for id: String in items:
		weight += float(_item(id).get("weight", 0.0)) * int(items[id])
	return weight

func raid_weight() -> float:
	var weight: float = 0.0
	for slot: String in EQUIPMENT_SLOTS:
		weight += float(_item(str(loadout.get(slot, ""))).get("weight", 0.0))
	for weapon_slot: String in WEAPON_SLOTS:
		var parts: Dictionary = weapon_builds.get(weapon_slot, {})
		for id: Variant in parts.values():
			weight += float(_item(str(id)).get("weight", 0.0))
	if raid_active:
		weight += _weight_of(raid_loot) + _weight_of(raid_packed_extra) + _weight_of(raid_ammo_by_id)
		for slot: String in WEAPON_SLOTS:
			weight += float(_item(str(weapon_ammo.get(slot, ""))).get("weight", 0.0)) * get_loaded_ammo(slot)
		weight += float(_item(raid_medkit_id).get("weight", 0.0)) * raid_medkits
	else:
		weight += _weight_of(ammo_carry_plan)
		for record: Dictionary in inventory_items:
			if str(record.container) in ["rig","pockets","backpack"] and str(_item(str(record.item)).get("kind",""))!="ammo":
				weight+=float(_item(str(record.item)).get("weight",0))*int(record.qty)
	return weight

func begin_raid() -> bool:
	if raid_active:
		return _fail("已经在行动中")
	var has_weapon: bool = false
	for slot: String in WEAPON_SLOTS:
		var weapon_id: String = str(loadout.get(slot, ""))
		if weapon_id.is_empty():
			continue
		has_weapon = true
		var weapon: Dictionary = _item(weapon_id)
		var ammo_id: String = str(weapon_ammo.get(slot, ""))
		var ammo: Dictionary = _item(ammo_id)
		if not _valid_weapon_target(weapon_id, slot) or str(ammo.get("kind", "")) != "ammo" or str(ammo.get("caliber", "")) != str(weapon.get("caliber", "")):
			return _fail("请为每把出战武器选择匹配口径的弹药")
		if int(ammo_carry_plan.get(ammo_id, 0)) <= 0:
			return _fail("请为每把出战武器设置携弹数量")
	if not has_weapon:
		return _fail("请先装备一把武器")
	# Validate the complete plan and weight before reserving a single item.
	for id: Variant in ammo_carry_plan:
		var quantity: Variant = ammo_carry_plan[id]
		if not id is String or not (quantity is int or quantity is float):
			return _fail("携弹计划无效")
		if str(_item(str(id)).get("kind", "")) != "ammo" or int(quantity) < 0 or int(quantity) > MAX_STACK:
			return _fail("携弹计划中有无效弹药或数量")
		if int(quantity) > _count(str(id)):
			return _fail("仓库弹药不足，请购买补给或减少携弹计划")
	if raid_weight() > carry_capacity():
		return _fail("出战负重超出容量，请调整三把武器、配件或携弹数量")
	var next_reserve: Dictionary = {}
	for id: String in ammo_carry_plan:
		var quantity: int = int(ammo_carry_plan[id])
		if quantity > 0:
			next_reserve[id] = quantity
	var next_loaded: Dictionary = {"primary": 0, "secondary": 0, "sidearm": 0}
	for slot: String in WEAPON_SLOTS:
		if str(loadout.get(slot, "")).is_empty():
			continue
		var ammo_id: String = str(weapon_ammo.get(slot, ""))
		var loaded: int = mini(int(weapon_stats(slot).get("magazine", 0)), int(next_reserve.get(ammo_id, 0)))
		next_loaded[slot] = loaded
		next_reserve[ammo_id] = int(next_reserve.get(ammo_id, 0)) - loaded
	var medical_id: String = _best_owned_medical()
	var medical_count: int = _packed_count(medical_id)
	raid_grid_items=[]
	for record: Dictionary in inventory_items:
		if str(record.container) in ["rig","pockets","backpack"]:raid_grid_items.append(record.duplicate(true))
	_grid_carried_first=true
	for id: String in ammo_carry_plan:
		var quantity: int = int(ammo_carry_plan[id])
		if quantity > 0:
			_take(id, quantity)
	if medical_count > 0:
		_take(medical_id, medical_count)
	raid_ammo_by_id = next_reserve
	raid_loaded_by_slot = next_loaded
	raid_medkit_id = medical_id
	raid_medkits = medical_count
	raid_loot = {}
	raid_packed_extra={}
	# Other packed objects travel with the operator and are subject to extraction.
	var packed_extra: Dictionary = {}
	for record: Dictionary in inventory_items:
		if str(record.container) in ["rig","backpack","pockets"]:
			var id: String = str(record.item)
			packed_extra[id]=int(packed_extra.get(id,0))+int(record.qty)
	for id: String in packed_extra:
		_take(id,int(packed_extra[id]))
		raid_packed_extra[id]=int(packed_extra[id])
	_grid_carried_first=false
	raid_active = true
	raid_grid_items=_pack_raid_grid(raid_loot)
	last_result = {}
	_choose_active()
	_commit()
	return true

func get_raid_ammo(slot: String = "") -> int:
	if slot.is_empty():
		slot = active_weapon_slot
	return int(raid_ammo_by_id.get(str(weapon_ammo.get(slot, "")), 0))

func get_loaded_ammo(slot: String = "") -> int:
	if slot.is_empty():
		slot = active_weapon_slot
	return int(raid_loaded_by_slot.get(slot, 0))

func get_raid_supplies() -> Dictionary:
	return {"ammo": raid_ammo, "loaded_ammo": raid_loaded_ammo, "medkits": raid_medkits, "ammo_id": raid_ammo_id, "medkit_id": raid_medkit_id}

func consume_raid_ammo(quantity: int) -> int:
	if not raid_active or quantity <= 0:
		return 0
	var room: int = maxi(0, int(weapon_stats().get("magazine", 0)) - get_loaded_ammo())
	var amount: int = mini(mini(quantity, get_raid_ammo()), room)
	raid_ammo_by_id[raid_ammo_id] = get_raid_ammo() - amount
	raid_loaded_by_slot[active_weapon_slot] = get_loaded_ammo() + amount
	raid_grid_items=_pack_raid_grid(raid_loot)
	changed.emit()
	return amount

func set_raid_loaded_ammo(quantity: int) -> void:
	if raid_active:
		raid_loaded_by_slot[active_weapon_slot] = clampi(quantity, 0, int(weapon_stats().get("magazine", 0)))

func consume_medkit() -> bool:
	if not raid_active or raid_medkits <= 0:
		return _fail("携带的医疗包已用完")
	raid_medkits -= 1
	raid_grid_items=_pack_raid_grid(raid_loot)
	last_error = ""
	changed.emit()
	return true

func consume_raid_medkit() -> bool:
	return consume_medkit()

func damage_after_armor(damage: float, penetration: float, headshot: bool = false) -> float:
	var slot: String = "helmet" if headshot else "body_armor"
	var armor: Dictionary = _item(str(loadout.get(slot, "")))
	if armor.is_empty() and not headshot:
		armor = _item(str(loadout.get("armored_rig", "")))
	var protection: float = float(armor.get("protection", 0.0))
	if headshot:
		protection += float(_item(str(loadout.get("visor", ""))).get("protection", 0.0)) * 0.55
	var reduction: float = clampf((protection - maxf(0.0, penetration)) / 75.0, 0.0, 0.72)
	return maxf(0.0, damage) * (1.0 - reduction)

func add_raid_loot(id: String, quantity: int = 1) -> bool:
	if not raid_active:
		return _fail("当前没有进行中的行动")
	if quantity < 1 or quantity > MAX_STACK or _item(id).is_empty():
		return _fail("战利品无效")
	if int(raid_loot.get(id, 0)) + quantity > MAX_STACK:
		return _fail("携带数量超出上限")
	if raid_weight() + float(_item(id).get("weight", 0.0)) * quantity > carry_capacity():
		return _fail("背包已满，无法拾取更多物资")
	var proposed: Dictionary=raid_loot.duplicate(true)
	proposed[id]=int(proposed.get(id,0))+quantity
	var packed: Array=_pack_raid_grid(proposed)
	if Grid.overflow_count(packed)>0:return _fail("携行区块已满，没有适合该物品的格子")
	raid_loot[id] = int(raid_loot.get(id, 0)) + quantity
	raid_grid_items=packed
	last_error = ""
	changed.emit()
	return true

func finish_raid(extracted: bool, details: Dictionary = {}) -> Dictionary:
	if not raid_active:
		_fail("没有需要结算的行动")
		return last_result.duplicate(true)
	var loot_value: int = 0
	var loot_count: int = 0
	for id: String in raid_loot:
		var quantity: int = int(raid_loot[id])
		loot_value += int(_item(id).get("sell_price", 0)) * quantity
		loot_count += quantity
		if extracted:
			_give(id, quantity)
	if extracted:
		if details.has("remaining_magazine"):
			# Legacy worlds may provide only the active magazine; never alter other carried guns.
			raid_loaded_by_slot[active_weapon_slot] = clampi(int(details["remaining_magazine"]), 0, get_loaded_ammo())
		var returns: Dictionary = raid_ammo_by_id.duplicate(true)
		for slot: String in WEAPON_SLOTS:
			_add_count(returns, str(weapon_ammo.get(slot, "")), get_loaded_ammo(slot))
		for id: String in returns:
			_give(id, int(returns[id]))
		_give(raid_medkit_id, raid_medkits)
		for id: String in raid_packed_extra:_give(id,int(raid_packed_extra[id]))
		# Keep surviving contents in their carried cells; loose overflow returns to stash.
		for record: Dictionary in _pack_raid_grid(raid_loot,true):
			if str(record.container) in ["rig","pockets","backpack"]:inventory_items.append(record.duplicate(true))
		InventoryState.update_ammo_plan(self)
	else:
		loadout = _empty_loadout()
		weapon_builds = _empty_weapon_builds()
		weapon_ammo = _empty_weapon_ammo()
		active_weapon_slot = "primary"
	last_result = details.duplicate(true)
	last_result["extracted"] = extracted
	last_result["loot_value"] = loot_value if extracted else 0
	last_result["loot_count"] = loot_count if extracted else 0
	last_result["loot"] = raid_loot.duplicate(true) if extracted else {}
	last_result["message"] = "撤离成功：三把武器与剩余弹药已保留，物资已存入仓库" if extracted else "行动失败：所有携带武器、装备、弹药与战利品已丢失"
	raid_active = false
	raid_grid_items=[]
	raid_loot = {}
	_clear_raid_supplies()
	if not extracted:
		_ensure_recovery()
	_choose_active()
	_commit()
	return last_result.duplicate(true)

func _ensure_recovery() -> void:
	for slot: String in WEAPON_SLOTS:
		if not str(loadout.get(slot, "")).is_empty():
			return
	for id: String in stash:
		if str(_item(id).get("kind", "")) == "weapon" and _count(id) > 0:
			return
	var weapon_id: String = _cheapest("weapon", "pistol")
	if weapon_id.is_empty():
		return
	var weapon: Dictionary = _item(weapon_id)
	var ammo_id: String = _cheapest("ammo", "", str(weapon.get("caliber", "")))
	var minimum_cost: int = int(weapon.get("price", 0)) + 30 * int(_item(ammo_id).get("price", 0))
	if credits >= minimum_cost:
		return
	loadout["sidearm"] = weapon_id
	weapon_ammo["sidearm"] = ammo_id
	active_weapon_slot = "sidearm"
	_give(ammo_id, 60)
	ammo_carry_plan = {ammo_id: mini(60, _count(ammo_id))}
	_give(_preferred("medkit_field", "consumable"), 1)
	last_result["recovery_kit"] = true
	_pack_initial_inventory()
	last_result["message"] = str(last_result.get("message", "")) + "。资金不足，已发放基础救济手枪与弹药"

func save_game() -> bool:
	_sync_aliases()
	var data: Dictionary = {
		"schema": SAVE_VERSION, "credits": credits, "stash": stash, "loadout": loadout,
		"active_weapon_slot": active_weapon_slot, "weapon_builds": weapon_builds,
		"weapon_ammo": weapon_ammo, "ammo_carry_plan": ammo_carry_plan,
		"raid_active": raid_active, "last_result": last_result,
		"raid_ammo_by_id": raid_ammo_by_id, "raid_loaded_by_slot": raid_loaded_by_slot,
		"raid_medkits": raid_medkits, "raid_medkit_id": raid_medkit_id,
		"inventory_items":inventory_items,
	}
	var temp_path: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_error = "无法写入进度文件"
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	var error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(save_path))
	if error != OK:
		last_error = "无法保存进度文件"
		return false
	return true

func _is_number(value: Variant) -> bool:
	return value is int or value is float

func _valid_save_structure(data: Dictionary) -> bool:
	var version: Variant = data.get("schema", null)
	if not _is_number(version) or not [1, 2, SAVE_VERSION].has(int(version)) or not _is_number(data.get("credits", null)):
		return false
	for field: String in ["stash", "loadout"]:
		if not data.get(field, null) is Dictionary:
			return false
	for value: Variant in data["stash"].values():
		if not _is_number(value):
			return false
	for value: Variant in data["loadout"].values():
		if not value is String:
			return false
	if not data.get("raid_active", false) is bool or not data.get("last_result", {}) is Dictionary:
		return false
	if int(version) == 1:
		if not data.get("attachments", {}) is Dictionary:
			return false
		for value: Variant in data.get("attachments", {}).values():
			if not value is String:
				return false
		return true
	for field: String in ["weapon_builds", "weapon_ammo", "ammo_carry_plan"]:
		if not data.get(field, null) is Dictionary:
			return false
	for value: Variant in data["weapon_builds"].values():
		if not value is Dictionary:
			return false
		for part: Variant in value.values():
			if not part is String:
				return false
	for value: Variant in data["weapon_ammo"].values():
		if not value is String:
			return false
	for value: Variant in data["ammo_carry_plan"].values():
		if not _is_number(value):
			return false
	return data.get("active_weapon_slot", "primary") is String

func _load_parts(slot: String, stored_parts: Dictionary) -> void:
	for part_slot: Variant in stored_parts:
		var id: String = str(stored_parts[part_slot])
		if Catalog.compatible(str(loadout.get(slot, "")), id, str(part_slot)):
			weapon_builds[slot][str(part_slot)] = id
		elif str(_item(id).get("kind", "")) == "attachment":
			_give(id)

func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var original_text: String = FileAccess.get_file_as_string(save_path)
	var parsed: Variant = JSON.parse_string(original_text)
	if not parsed is Dictionary or not _valid_save_structure(parsed):
		return false
	var data: Dictionary = parsed
	var version: int = int(data["schema"])
	if version<SAVE_VERSION and not FileAccess.file_exists(save_path+".before_grid.bak"):
		var backup: FileAccess = FileAccess.open(save_path+".before_grid.bak",FileAccess.WRITE)
		if backup!=null:
			backup.store_string(original_text)
			backup.close()
	credits = clampi(int(data["credits"]), 0, 2000000000)
	stash = {}
	inventory_items = []
	for id: String in data["stash"]:
		var quantity: int = clampi(int(data["stash"][id]), 0, MAX_STACK)
		if not _item(id).is_empty() and quantity > 0:
			stash[id] = quantity
	loadout = _empty_loadout()
	weapon_builds = _empty_weapon_builds()
	weapon_ammo = _empty_weapon_ammo()
	ammo_carry_plan = {}
	var stored_loadout: Dictionary = data["loadout"]
	for slot: String in ARMOR_SLOTS:
		var id: String = str(stored_loadout.get(slot, ""))
		if str(_item(id).get("kind", "")) == "armor" and str(_item(id).get("category", "")) == slot:
			loadout[slot] = id
	if version == 1:
		var old_weapon: String = str(stored_loadout.get("weapon", ""))
		var target: String = "sidearm" if str(_item(old_weapon).get("category", "")) == "pistol" else "primary"
		if _valid_weapon_target(old_weapon, target):
			loadout[target] = old_weapon
			_load_parts(target, data.get("attachments", {}))
			var old_ammo: String = str(stored_loadout.get("ammo", ""))
			if str(_item(old_ammo).get("caliber", "")) == str(_item(old_weapon).get("caliber", "")) and str(_item(old_ammo).get("kind", "")) == "ammo":
				weapon_ammo[target] = old_ammo
				ammo_carry_plan[old_ammo] = mini(_count(old_ammo), maxi(90, int(weapon_stats(target).get("magazine", 30)) * 3))
		active_weapon_slot = target
		# Keep the exact original alongside the migrated save for review/recovery.
		if not FileAccess.file_exists(save_path + ".schema1.bak"):
			var backup: FileAccess = FileAccess.open(save_path + ".schema1.bak", FileAccess.WRITE)
			if backup != null:
				backup.store_string(original_text)
				backup.close()
	else:
		for slot: String in WEAPON_SLOTS:
			var id: String = str(stored_loadout.get(slot, ""))
			if _valid_weapon_target(id, slot):
				loadout[slot] = id
			elif str(_item(id).get("kind", "")) == "weapon":
				_give(id)
			_load_parts(slot, data["weapon_builds"].get(slot, {}))
			var ammo_id: String = str(data["weapon_ammo"].get(slot, ""))
			if str(_item(ammo_id).get("kind", "")) == "ammo" and str(_item(ammo_id).get("caliber", "")) == str(_item(str(loadout.get(slot, ""))).get("caliber", "")):
				weapon_ammo[slot] = ammo_id
		for id: String in data["ammo_carry_plan"]:
			if str(_item(id).get("kind", "")) == "ammo":
				ammo_carry_plan[id] = clampi(int(data["ammo_carry_plan"][id]), 0, MAX_STACK)
		active_weapon_slot = str(data.get("active_weapon_slot", "primary"))
		if not WEAPON_SLOTS.has(active_weapon_slot):
			active_weapon_slot = "primary"
	if not str(loadout.get("body_armor", "")).is_empty() and not str(loadout.get("armored_rig", "")).is_empty():
		_return_armor_slot("armored_rig")
	var visor: String = str(loadout.get("visor", ""))
	if not visor.is_empty() and not Catalog.visor_compatible(str(loadout.get("helmet", "")), visor):
		_return_armor_slot("visor")
	last_result = data.get("last_result", {}).duplicate(true)
	raid_loot = {}
	_clear_raid_supplies()
	raid_active = bool(data.get("raid_active", false))
	if data.get("inventory_items",null) is Array:
		inventory_items=Grid.reconcile(data.inventory_items,stash,loadout)
	else:
		_pack_initial_inventory()
	_choose_active()
	if raid_active:
		finish_raid(false, {"reason": "interrupted"})
	else:
		# Migration preserves the old kit and funds; do not silently add recovery items on migration.
		if version != 1:
			_ensure_recovery()
		_choose_active()
		if version < SAVE_VERSION:
			save_game()
	last_error = ""
	changed.emit()
	return true
