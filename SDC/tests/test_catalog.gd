extends SceneTree

const CatalogScript = preload("res://scripts/catalog.gd")
var catalog: Node
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	catalog = CatalogScript.new()
	var issues: Array[String] = catalog.validate_catalog()
	_check(issues.is_empty(), "Catalog validation: " + str(issues))
	_check(catalog.items.size() == 256, "256 checked-in equipment entries")
	_check(catalog.by_kind("weapon").size() == 24, "24 weapons")
	_check(catalog.by_kind("attachment").size() >= 120, "at least 120 attachments")
	for family: String in ["smg", "rifle", "sniper", "shotgun", "machine_gun", "pistol"]:
		_check(catalog.by_category(family).size() == 4, "four weapons in " + family)
	_check(catalog.get_item("missing").is_empty(), "Unknown ID returns empty")
	_check(not catalog.compatible("missing", "att_optic_red_dot"), "Unknown weapon rejected")
	_check(not catalog.compatible("weapon_reed9", "missing"), "Unknown attachment rejected")
	_check(catalog.weapon_stats("missing").is_empty(), "Unknown weapon has no stats")

	# Same caliber alone must not make magazines or platform components interchangeable.
	_check(catalog.compatible("weapon_reed9", "att_mag_reed9_extended", "magazine"), "Reed dedicated magazine accepted")
	_check(not catalog.compatible("weapon_swift9", "att_mag_reed9_extended", "magazine"), "Swift rejects Reed magazine despite same caliber")
	_check(not catalog.compatible("weapon_reed9", "att_suppressor_556_12"), "Wrong muzzle thread rejected")
	_check(not catalog.compatible("weapon_finch9", "att_grip_vertical"), "Pistol has no invented foregrip socket")
	_check(not catalog.compatible("weapon_reed9", "att_optic_red_dot", "laser"), "Wrong installation slot rejected")
	_check(catalog.compatible("weapon_badger556", "att_mag_badger556_extended"), "Shared AR magazine on rifle")
	_check(catalog.compatible("weapon_wren556", "att_mag_badger556_extended"), "Shared AR magazine on marksman rifle")
	_check(catalog.compatible("weapon_reed9", "att_optic_red_dot"), "Universal rail optic on SMG")
	_check(catalog.compatible("weapon_heron308", "att_optic_red_dot"), "Universal rail optic on sniper")
	_check(not catalog.compatible("weapon_cedar545", "att_optic_red_dot"), "Side rail requires matching optic")

	# Both mount standards have one face shield position; A cannot cross-fit B.
	_check(catalog.visor_compatible("helmet_moss_1a", "visor_1a"), "A visor matches A helmet")
	_check(catalog.visor_compatible("helmet_moss_1a", "visor_2a"), "Second-tier A visor matches A helmet")
	_check(not catalog.visor_compatible("helmet_moss_1a", "visor_1b"), "A helmet rejects B visor")
	_check(catalog.visor_compatible("helmet_moss_1b", "visor_2b"), "B visor matches B helmet")
	_check(not catalog.visor_compatible("body_armor_fiber_1a", "visor_1a"), "Body armor is not a visor mount")
	for category: String in ["backpack", "armored_rig"]:
		var capacities: Dictionary = {}
		for item: Dictionary in catalog.by_category(category):
			_check(not item.has("level"), category + " has no level")
			capacities[item.get("capacity")] = true
		_check(capacities.size() == 4, category + " has four capacity options")

	var original: Dictionary = catalog.get_item("weapon_reed9")["stats"].duplicate(true)
	var base: Dictionary = catalog.weapon_stats("weapon_reed9")
	var suppressed: Dictionary = catalog.weapon_stats("weapon_reed9", {"muzzle": "att_suppressor_9_13"})
	_check(float(suppressed["noise"]) < float(base["noise"]), "Suppressor actually reduces noise")
	_check(float(suppressed["recoil"]) < float(base["recoil"]), "Suppressor actually changes recoil")
	var extended: Dictionary = catalog.weapon_stats("weapon_reed9", {"magazine": "att_mag_reed9_extended"})
	_check(int(extended["magazine"]) > int(base["magazine"]), "Extended magazine actually adds capacity")
	var wrong: Dictionary = catalog.weapon_stats("weapon_reed9", {"laser": "att_suppressor_9_13", "magazine": "att_mag_swift9_extended"})
	_check(wrong == base, "Invalid or wrong-slot equipment never grants stats")
	var combination: Dictionary = catalog.weapon_stats("weapon_reed9", {"grip": "att_grip_vertical", "optic": "att_optic_red_dot", "magazine": "att_mag_reed9_extended"})
	_check(float(combination["recoil"]) < float(base["recoil"]) and float(combination["accuracy"]) > float(base["accuracy"]) and int(combination["magazine"]) > int(base["magazine"]), "Multiple installed parts apply together")
	_check(catalog.get_item("weapon_reed9")["stats"] == original, "Calculating modifiers does not mutate base weapon")
	for weapon: Dictionary in catalog.by_kind("weapon"):
		var matching: Array = []
		for ammo: Dictionary in catalog.by_kind("ammo"):
			if ammo["caliber"] == weapon["caliber"]:
				matching.append(ammo)
		_check(matching.size() == 3, "Three ammo variants for " + str(weapon["id"]))
	for attachment: Dictionary in catalog.by_kind("attachment"):
		var reachable: bool = false
		for weapon: Dictionary in catalog.by_kind("weapon"):
			if catalog.compatible(weapon["id"], attachment["id"]):
				reachable = true
		_check(reachable, "Reachable: " + str(attachment["id"]))
	# Bodies and every marketed accessory own distinct files; no generic fallback.
	var metadata_only: bool = OS.get_cmdline_user_args().has("--metadata-only")
	var model_issues: Array[String] = catalog.validate_models(not metadata_only)
	_check(model_issues.is_empty(), "Independent model declarations/resources: " + str(model_issues))
	var model_paths: Dictionary = {}
	for entry: Dictionary in catalog.by_kind("weapon") + catalog.by_kind("attachment"):
		var item_id: String = str(entry["id"])
		var folder: String = "weapons" if entry["kind"] == "weapon" else "attachments"
		var path: String = catalog.model_path(item_id)
		_check(path == "res://assets/modular/%s/%s.glb" % [folder, item_id], "Independent model path matches item and folder: " + item_id)
		model_paths[path] = true
	_check(model_paths.size() == 169, "169 distinct weapon/accessory models")
	_check(catalog.model_path("missing").is_empty(), "Unknown ID never falls back to another gun model")
	_check(catalog.model_path("backpack_daypack").is_empty(), "Unmodeled gear never masquerades as a gun")
	# Every visible mount has a readable label; internal IDs are still stable.
	var interfaces: Dictionary = {}
	for weapon: Dictionary in catalog.by_kind("weapon"):
		for slot: Variant in weapon["slots"]:
			for interface_id: Variant in weapon["slots"][slot]:
				interfaces[str(interface_id)] = true
	for interface_id: String in interfaces:
		_check(catalog.interface_label(interface_id) != interface_id, "Readable interface label: " + interface_id)
	_check(catalog.interface_label("visor_rail_a") != catalog.interface_label("visor_rail_b"), "Visor standards retain distinct readable labels")
	if failures.is_empty():
		print("CATALOG TESTS PASS: %d checks; 256 items, 24 weapons, 145 attachments, 169 independent model declarations." % checks)
		catalog.free()
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		catalog.free()
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
