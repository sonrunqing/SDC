extends Node
## Read-only fictional equipment data and the single compatibility authority.
## The inventory, shop, workbench, and raid all use this same catalog.

const Ballistics = preload("res://scripts/ballistics.gd")
const DATA_PATH: String = "res://data/items.json"
const WEAPON_CATEGORIES: Array[String] = ["smg", "rifle", "sniper", "shotgun", "machine_gun", "pistol"]
const STAT_KEYS: Array[String] = ["damage", "rpm", "magazine", "recoil", "accuracy", "ergonomics", "range", "noise", "recoil_control", "horizontal_control", "suppression"]
const INTERFACE_LABELS: Dictionary = {
	"thread_9_13": "9 mm M13 螺纹", "thread_45_16": ".45 M16 螺纹",
	"thread_57_10": "5.7 mm M10 螺纹", "thread_556_12": "5.56 mm 1/2 英寸螺纹",
	"thread_545_14": "5.45 mm M14 螺纹", "thread_762_14": "7.62 mm M14 螺纹",
	"thread_308_58": ".30 口径 5/8 英寸螺纹", "thread_338_34": ".338 口径 3/4 英寸螺纹",
	"thread_12_m22": "12 号 M22 螺纹", "thread_20_m20": "20 号 M20 螺纹",
	"picatinny": "皮卡汀尼导轨", "mlok": "M 型扩展槽", "keymod": "钥孔扩展槽",
	"bipod_stud": "支架固定柱", "pump_rail": "泵动前护木轨",
	"pdw_slide": "PDW 伸缩尾座", "fold_hinge": "双销折叠尾座",
	"swift_hinge": "雨燕折叠尾座", "ar_buffer": "AR 缓冲管",
	"cedar_trunnion": "雪松固定尾座", "bolt_cheek": "精确步枪贴腮座",
	"falcon_cheek": "猎隼贴腮座", "shotgun_mount": "霰弹枪缓冲尾座",
	"fox_stock": "赤狐枪托座", "bison_socket": "野牛尾座",
	"yak_socket": "牦牛尾座", "rhino_socket": "犀牛尾座", "pistol_brace": "渡鸦肩托座",
	"dovetail": "燕尾导轨", "microplate": "微型瞄具底板", "side_rail": "侧挂导轨",
	"trigger_rail": "扳机护圈卡轨", "pistol_rail": "手枪底部导轨",
	"mag_ar556": "AR 5.56 供弹座", "hg_ar556": "AR 前护木座",
	"visor_rail_a": "A 型面罩卡轨", "visor_rail_b": "B 型面罩卡轨",
}
var items: Dictionary = {}
var _load_issues: Array[String] = []


func _init() -> void:
	load_catalog()


func load_catalog(path: String = DATA_PATH) -> bool:
	items.clear()
	_load_issues.clear()
	if not FileAccess.file_exists(path):
		_load_issues.append("装备数据文件不存在：" + path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("items") is Array:
		_load_issues.append("装备数据必须包含 items 数组")
		return false
	for value: Variant in parsed["items"]:
		if not value is Dictionary:
			_load_issues.append("装备条目不是字典")
			continue
		var entry: Dictionary = value
		var item_id: String = str(entry.get("id", ""))
		if item_id.is_empty():
			_load_issues.append("装备缺少 ID")
			continue
		if items.has(item_id):
			_load_issues.append("重复装备 ID：" + item_id)
			continue
		items[item_id] = entry
	return _load_issues.is_empty()


func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})


func equipment_slot(item_id: String) -> String:
	# The saved slot name is shared by plain rigs and protective rig carriers.
	var category: String = str(get_item(item_id).get("category", ""))
	return "armored_rig" if category == "rig" else category


func is_armored_rig(item_id: String) -> bool:
	var item: Dictionary = get_item(item_id)
	return str(item.get("kind", "")) == "armor" and str(item.get("category", "")) == "armored_rig"


func model_path(item_id: String) -> String:
	return str(get_item(item_id).get("visual_model", ""))


func validate_models(check_resources: bool = false) -> Array[String]:
	var issues: Array[String] = []
	var paths: Dictionary = {}
	var modeled: Array = by_kind("weapon") + by_kind("attachment")
	for entry: Dictionary in modeled:
		var item_id: String = str(entry["id"])
		var folder: String = "weapons" if entry.get("kind", "") == "weapon" else "attachments"
		var expected: String = "res://assets/modular/%s/%s.glb" % [folder, item_id]
		var path: String = model_path(item_id)
		if path != expected:
			issues.append(item_id + " 必须声明自己的独立模型：" + expected)
		if paths.has(path):
			issues.append(item_id + " 与 " + str(paths[path]) + " 不能共用同一模型文件")
		paths[path] = item_id
		if check_resources and (path.is_empty() or not ResourceLoader.exists(path, "PackedScene")):
			issues.append(item_id + " 的独立模型不存在或尚未导入：" + path)
	if paths.size() != 169:
		issues.append("24 把武器与 145 个配件必须有 169 个独立模型声明")
	return issues


func interface_label(interface_id: String) -> String:
	if INTERFACE_LABELS.has(interface_id):
		return str(INTERFACE_LABELS[interface_id])
	# Dedicated feed/handguard sockets derive a readable name from their platform.
	for weapon: Dictionary in by_kind("weapon"):
		var sockets: Dictionary = weapon.get("slots", {})
		for slot: Variant in sockets:
			if not sockets[slot].has(interface_id):
				continue
			var platform: String = str(weapon.get("name", ""))
			if interface_id.begins_with("hg_"):
				return platform + " 专用护木座"
			if interface_id.begins_with("tube_"):
				return platform + " 弹仓管接口"
			if interface_id.begins_with("chamber_"):
				return platform + " 双管装填接口"
			if interface_id.begins_with("belt_"):
				return platform + " 弹链盒接口"
			if interface_id.begins_with("drum_"):
				return platform + " 弹鼓接口"
			if interface_id.begins_with("mag_"):
				return platform + " 专用弹匣座"
	return interface_id


func by_kind(kind: String) -> Array:
	var found: Array = []
	for entry: Dictionary in items.values():
		if entry.get("kind", "") == kind:
			found.append(entry)
	return found


func by_category(category: String) -> Array:
	var found: Array = []
	for entry: Dictionary in items.values():
		if entry.get("category", "") == category:
			found.append(entry)
	return found


func compatible(weapon_id: String, attachment_id: String, slot: String = "") -> bool:
	var weapon: Dictionary = get_item(weapon_id)
	var attachment: Dictionary = get_item(attachment_id)
	if weapon.get("kind", "") != "weapon" or attachment.get("kind", "") != "attachment":
		return false
	var attachment_slot: String = str(attachment.get("slot", ""))
	if not slot.is_empty() and slot != attachment_slot:
		return false
	var sockets: Dictionary = weapon.get("slots", {})
	if not sockets.has(attachment_slot):
		return false
	var restrictions: Array = attachment.get("weapon_ids", [])
	if not restrictions.is_empty() and not restrictions.has(weapon_id):
		return false
	var interfaces: Array = attachment.get("interfaces", [])
	for socket: Variant in sockets[attachment_slot]:
		if interfaces.has(socket):
			return true
	return false


func compatible_attachments(weapon_id: String, slot: String = "") -> Array:
	var found: Array = []
	for entry: Dictionary in by_kind("attachment"):
		if compatible(weapon_id, str(entry["id"]), slot):
			found.append(entry)
	return found


func visor_compatible(helmet_id: String, visor_id: String) -> bool:
	var helmet: Dictionary = get_item(helmet_id)
	var visor: Dictionary = get_item(visor_id)
	if helmet.get("category", "") != "helmet" or visor.get("category", "") != "visor":
		return false
	var mounts: Array = helmet.get("visor_mounts", [])
	if mounts.is_empty():
		mounts = [helmet.get("visor_mount", "")]
	var visor_mount: String = str(visor.get("visor_mount", ""))
	return not visor_mount.is_empty() and mounts.has(visor_mount)


func weapon_stats(weapon_id: String, attachments: Dictionary = {}) -> Dictionary:
	var weapon: Dictionary = get_item(weapon_id)
	if weapon.get("kind", "") != "weapon":
		return {}
	var stats: Dictionary = weapon.get("stats", {}).duplicate(true)
	stats["recoil_control"]=float(stats.get("recoil_control",100.0-float(stats.get("recoil",25))))
	stats["horizontal_control"]=float(stats.get("horizontal_control",100.0-float(stats.get("recoil",25))*.7))
	stats["suppression"]=float(stats.get("suppression",120.0-float(stats.get("noise",70))))
	for slot: Variant in attachments:
		var attachment_id: String = str(attachments[slot])
		if not compatible(weapon_id, attachment_id, str(slot)):
			continue
		var modifiers: Dictionary = get_item(attachment_id).get("modifiers", {})
		for stat: Variant in modifiers:
			if stats.has(stat):
				stats[stat] = float(stats[stat]) + float(modifiers[stat])
	stats["damage"] = maxf(1.0, float(stats.get("damage", 1.0)))
	stats["rpm"] = maxf(30.0, float(stats.get("rpm", 60.0)))
	stats["magazine"] = maxi(1, int(stats.get("magazine", 1)))
	stats["recoil_control"]=clampf(float(stats.recoil_control),0,98)
	stats["horizontal_control"]=clampf(float(stats.horizontal_control),0,98)
	stats["recoil"] = 100.0-float(stats.recoil_control)
	stats["horizontal_recoil"]=100.0-float(stats.horizontal_control)
	stats["accuracy"] = clampf(float(stats.get("accuracy", 70.0)), 10.0, 99.0)
	stats["ergonomics"] = clampf(float(stats.get("ergonomics", 50.0)), 0.0, 100.0)
	stats["range"] = maxf(3.0, float(stats.get("range", 20.0)))
	stats["suppression"]=clampf(float(stats.suppression),0,110)
	stats["noise"] = 120.0-float(stats.suppression)
	return stats


func shot_profile(weapon_id: String, ammo_id: String, parts: Dictionary = {}) -> Dictionary:
	var weapon: Dictionary = get_item(weapon_id)
	var ammo: Dictionary = get_item(ammo_id)
	if weapon.get("kind", "") != "weapon" or ammo.get("kind", "") != "ammo" or weapon.get("caliber", "") != ammo.get("caliber", ""):
		return {}
	return Ballistics.profile(weapon, ammo, weapon_stats(weapon_id, parts))


func shot_damage(weapon_id: String, ammo_id: String, distance: float, parts: Dictionary = {}) -> float:
	return Ballistics.damage_at(shot_profile(weapon_id, ammo_id, parts), distance)


func performance_rating(stats: Dictionary) -> int:
	return Ballistics.performance_rating(stats)


func validate_catalog() -> Array[String]:
	var issues: Array[String] = _load_issues.duplicate()
	issues.append_array(validate_models())
	var guns: Array = by_kind("weapon")
	var attachments: Array = by_kind("attachment")
	if guns.size() != 24:
		issues.append("武器应为 24 把")
	if attachments.size() < 120:
		issues.append("配件应不少于 120 件")
	for family: String in WEAPON_CATEGORIES:
		if by_category(family).size() != 4:
			issues.append("武器分类需各 4 把：" + family)
	var signatures: Dictionary = {}
	for entry: Dictionary in items.values():
		var item_id: String = str(entry.get("id", ""))
		for field: String in ["id", "name", "kind", "category", "price", "sell_price", "weight", "description"]:
			if not entry.has(field):
				issues.append(item_id + " 缺少字段 " + field)
		if float(entry.get("weight", -1)) < 0 or int(entry.get("sell_price", -1)) < 0:
			issues.append(item_id + " 价格/重量不能为负")
		if int(entry.get("sell_price", 0)) > int(entry.get("price", 0)):
			issues.append(item_id + " 卖价高于买价")
		var category: String = str(entry.get("category", ""))
		if category in ["backpack", "rig"] and entry.has("level"):
			issues.append(item_id + " 容量装备不应有等级")
		if category == "rig" and (entry.has("protection") or entry.has("armor_zone")):
			issues.append(item_id + " 普通弹挂不能提供防弹属性")
		if category == "armored_rig" and (int(entry.get("level", 0)) < 1 or int(entry.get("level", 0)) > 4 or float(entry.get("protection", 0)) <= 0 or str(entry.get("armor_zone", "")) != "torso"):
			issues.append(item_id + " 防弹弹挂必须具有合法的躯干防护")
		if entry.get("kind", "") == "ammo":
			if float(entry.get("penetration", -1)) < 0 or float(entry.get("damage_multiplier", 0)) <= 0:
				issues.append(item_id + " 弹药参数无效")
	for weapon: Dictionary in guns:
		var weapon_id: String = str(weapon["id"])
		var stats: Dictionary = weapon.get("stats", {})
		for stat: String in STAT_KEYS:
			if not stats.has(stat):
				issues.append(weapon_id + " 缺少参数 " + stat)
		var signature: String = JSON.stringify(weapon.get("slots", {}))
		if signatures.has(signature):
			issues.append(weapon_id + " 与 " + str(signatures[signature]) + " 接口配置完全相同")
		signatures[signature] = weapon_id
		var ammo_found: bool = false
		for ammo: Dictionary in by_kind("ammo"):
			if ammo.get("caliber", "") == weapon.get("caliber", ""):
				ammo_found = true
		if not ammo_found:
			issues.append(weapon_id + " 没有对应口径弹药")
		for slot: Variant in weapon.get("slots", {}):
			if compatible_attachments(weapon_id, str(slot)).is_empty():
				issues.append(weapon_id + " 的插槽没有配件：" + str(slot))
	for attachment: Dictionary in attachments:
		var attachment_id: String = str(attachment["id"])
		var reachable: bool = false
		if attachment.get("modifiers", {}).is_empty():
			issues.append(attachment_id + " 没有实际属性效果")
		for stat: Variant in attachment.get("modifiers", {}):
			if not STAT_KEYS.has(str(stat)):
				issues.append(attachment_id + " 修改了未知属性 " + str(stat))
		for weapon: Dictionary in guns:
			if compatible(str(weapon["id"]), attachment_id):
				reachable = true
		if not reachable:
			issues.append(attachment_id + " 无可安装武器")
		for restricted_id: Variant in attachment.get("weapon_ids", []):
			if not compatible(str(restricted_id), attachment_id):
				issues.append(attachment_id + " 专用平台不存在或接口不符：" + str(restricted_id))
	for category: String in ["helmet", "body_armor"]:
		var armors: Array = by_category(category)
		if armors.size() != 12:
			issues.append(category + " 应为 4 级各 3 款")
		for level: int in range(1, 5):
			var count: int = 0
			for armor: Dictionary in armors:
				if int(armor.get("level", 0)) == level:
					count += 1
			if count != 3:
				issues.append(category + " 第 " + str(level) + " 级数量不正确")
	for category: String in ["backpack", "rig", "armored_rig"]:
		var variants: Array = by_category(category)
		var capacities: Dictionary = {}
		if variants.size() != 4:
			issues.append(category + " 应为四款容量选项")
		for variant: Dictionary in variants:
			var capacity: float = float(variant.get("capacity", 0))
			if capacity <= 0:
				issues.append(str(variant["id"]) + " 必须提供容量")
			capacities[capacity] = true
		if capacities.size() != 4:
			issues.append(category + " 容量选项重复")
	var helmet_mounts: Dictionary = {}
	for helmet: Dictionary in by_category("helmet"):
		var mounts: Array = helmet.get("visor_mounts", [])
		if mounts.size() != 1:
			issues.append(str(helmet["id"]) + " 应仅有一个面罩位置")
		for mount: Variant in mounts:
			helmet_mounts[str(mount)] = true
	if helmet_mounts.size() != 2:
		issues.append("头盔必须覆盖两种面罩卡槽标准")
	var visors: Array = by_category("visor")
	if visors.size() != 4:
		issues.append("面罩应为两级共四款")
	for level: int in [1, 2]:
		var level_mounts: Dictionary = {}
		for visor: Dictionary in visors:
			if int(visor.get("level", 0)) == level:
				level_mounts[str(visor.get("visor_mount", ""))] = true
		if level_mounts.size() != 2:
			issues.append("面罩每级必须覆盖 A / B 两种轨道")
	for visor: Dictionary in visors:
		var found: bool = false
		for helmet: Dictionary in by_category("helmet"):
			if visor_compatible(str(helmet["id"]), str(visor["id"])):
				found = true
		if not found:
			issues.append(str(visor["id"]) + " 没有匹配头盔")
	return issues
