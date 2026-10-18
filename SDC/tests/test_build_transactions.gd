extends SceneTree
## Whole-build procurement, shared-calibre conservation, and old-save migration.
var checks: int = 0
var failures: int = 0
var state: Node
var catalog: Node

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func snapshot() -> String:
	return JSON.stringify([state.credits, state.stash, state.loadout, state.weapon_builds, state.weapon_ammo, state.ammo_carry_plan, state.active_weapon_slot])

func choose(weapon_id: String, slot: String, offset: int = 0) -> String:
	var found: Array = catalog.compatible_attachments(weapon_id, slot)
	return str(found[offset]["id"]) if found.size() > offset else ""

func inventory_total(id: String) -> int:
	var total: int = int(state.stash.get(id, 0))
	for slot: String in ["primary", "secondary", "sidearm"]:
		if str(state.loadout.get(slot, "")) == id: total += 1
		for part: Variant in state.weapon_builds[slot].values():
			if str(part) == id: total += 1
	return total

func rounds_carried() -> int:
	var total: int = 0
	for value: Variant in state.raid_ammo_by_id.values(): total += int(value)
	for value: Variant in state.raid_loaded_by_slot.values(): total += int(value)
	return total

func _run() -> void:
	catalog = root.get_node("Catalog")
	state = load("res://scripts/game_state.gd").new()
	state.save_path = "user://assembly_transaction_test.json"
	root.add_child(state)
	state.reset_progress()
	var gun: String = str(state.loadout.primary)
	var muzzle: String = choose(gun,"muzzle")
	var optic: String = choose(gun,"optic")
	var draft: Dictionary = {"muzzle":muzzle,"optic":optic}
	check(state.buy(optic), "Procure one owned optic before drafting")
	var initial: String = snapshot()
	var quote: Dictionary = state.quote_build(gun,draft,"primary")
	check(snapshot() == initial, "Quoting is readonly")
	check(bool(quote.valid) and bool(quote.can_afford), "Compatible affordable build quoted")
	check(int(quote.cost) == int(catalog.get_item(muzzle).price), "Owned receiver and owned optic are reused without charge")
	check(not quote.missing.has(gun) and not quote.missing.has(optic), "Quote lists only genuinely missing parts")
	var cash_before: int = state.credits
	check(state.buy_build(gun,draft), "Whole assembly purchased and directly equipped")
	check(state.credits == cash_before - int(quote.cost), "Whole build debits its quote once")
	check(state.loadout.primary == gun and state.weapon_builds.primary == draft and state.active_weapon_slot == "primary", "Built gun is in primary with its selected components")
	check(inventory_total(gun) == 1 and inventory_total(optic) == 1 and inventory_total(muzzle) == 1, "Procurement conserves owned kit and adds one missing part")
	var complete: String = snapshot()
	check(int(state.quote_build(gun,draft).cost) == 0, "Identical reassembly is free")
	check(state.buy_build(gun,draft) and snapshot() == complete, "Repeated commit does not charge or duplicate an assembled kit")
	var alternate: String = choose(gun,"muzzle",1)
	var swapped: Dictionary = draft.duplicate()
	swapped.muzzle = alternate
	check(state.buy_build(gun,swapped), "Replacing one part buys only the replacement")
	check(int(state.stash.get(muzzle,0)) == 1 and state.weapon_builds.primary.muzzle == alternate, "Old part returns to stash rather than disappearing")
	var invalid: Dictionary = {"optic":muzzle}
	var protected_state: String = snapshot()
	check(not bool(state.quote_build(gun,invalid).valid) and not state.buy_build(gun,invalid), "Wrong interface rejects the whole purchase")
	check(snapshot() == protected_state, "Rejected build preserves money, inventory and equipped kit")
	state.credits = 0
	protected_state = snapshot()
	check(not state.buy_build("weapon_badger556",{},"secondary"), "Unfunded complete gun cannot be equipped")
	check(snapshot() == protected_state, "Insufficient money has no partial inventory or equipment effects")
	state.credits = 100000
	protected_state = snapshot()
	check(not state.buy_build("weapon_ember45",{},"primary") and not state.buy_build(gun,{},"sidearm"), "Pistol and long-gun slot restrictions apply to procurement")
	check(snapshot() == protected_state, "Invalid target leaves the existing assembly intact")
	check(state.buy_build(gun,{"muzzle":muzzle},"secondary"), "Second identical gun uses spare part but buys another receiver")
	check(inventory_total(gun) == 2 and state.weapon_builds.primary.muzzle == alternate, "Secondary procurement never steals the first gun's parts")
	check(state.buy_build("weapon_ember45",{},"sidearm"), "Handgun is independently equipped in third slot")
	var shared_ammo: String = "ammo_9x19_fmj"
	var pistol_ammo: String = "ammo_45acp_fmj"
	check(state.buy(pistol_ammo,60), "Pistol calibre is stocked")
	check(state.select_weapon_ammo("primary",shared_ammo) and state.select_weapon_ammo("secondary",shared_ammo) and state.select_weapon_ammo("sidearm",pistol_ammo), "Each gun selects a compatible round")
	check(state.set_ammo_carry(shared_ammo,90) and state.set_ammo_carry(pistol_ammo,30), "Carry plan counts shared rounds once")
	check(not state.select_weapon_ammo("primary",pistol_ammo), "Wrong-calibre loading is rejected")
	state.set_active_weapon("primary")
	state.save_game()
	var saved_builds: Dictionary = state.weapon_builds.duplicate(true)
	var saved_loadout: Dictionary = state.loadout.duplicate(true)
	check(state.load_game() and state.weapon_builds == saved_builds and state.loadout == saved_loadout, "Three equipped assemblies and ammo plan survive save/load")
	var shared_before: int = int(state.stash[shared_ammo])
	var pistol_before: int = int(state.stash[pistol_ammo])
	check(state.begin_raid(), "Three guns deploy with planned rounds")
	check(rounds_carried() == 120, "Shared-calibre initial magazines do not mint additional rounds")
	check(state.get_loaded_ammo("primary") > 0 and state.get_loaded_ammo("secondary") > 0 and state.get_loaded_ammo("sidearm") > 0, "All three magazine counts are initialized")
	var carried_before: int = rounds_carried()
	state.set_raid_loaded_ammo(state.get_loaded_ammo() - 3)
	for _cycle in range(4):
		for slot: String in ["secondary","sidearm","primary"]: state.set_active_weapon(slot)
	check(rounds_carried() == carried_before - 3, "Repeated three-gun cycling preserves fired rounds and magazines")
	state.finish_raid(true,{"remaining_magazine":state.get_loaded_ammo()})
	check(int(state.stash[shared_ammo]) == shared_before - 3 and int(state.stash[pistol_ammo]) == pistol_before, "Extraction returns all three loaded magazines and reserves exactly once")
	check(state.weapon_builds == saved_builds, "Extraction retains each independent assembly")
	check(state.begin_raid(), "Same prepared kit can enter another raid")
	var stash_in_raid: String = JSON.stringify(state.stash)
	state.finish_raid(false)
	check(state.loadout.primary == "" and state.loadout.secondary == "" and state.loadout.sidearm == "", "Death loses all three carried guns")
	check(state.weapon_builds.primary.is_empty() and state.weapon_builds.secondary.is_empty() and state.weapon_builds.sidearm.is_empty(), "Death loses every installed accessory")
	check(JSON.stringify(state.stash) == stash_in_raid, "Death does not return spent carried rounds or change protected stash")

	# Exact schema1 backup and migration keep existing player funds/kit.
	var old: Dictionary = {"schema":1,"credits":4321,"stash":{shared_ammo:100},"loadout":{"weapon":gun,"ammo":shared_ammo},"attachments":{"muzzle":muzzle},"raid_active":false,"last_result":{}}
	state.save_path = "user://assembly_migration_test.json"
	var original_text: String = JSON.stringify(old)
	var file: FileAccess = FileAccess.open(state.save_path,FileAccess.WRITE)
	file.store_string(original_text)
	file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path + ".schema1.bak"))
	check(state.load_game(), "Original single-gun save migrates")
	check(state.credits == 4321 and state.loadout.primary == gun and state.weapon_builds.primary.muzzle == muzzle and int(state.stash[shared_ammo]) == 100, "Migration preserves money, gun, components and rounds")
	check(FileAccess.get_file_as_string(state.save_path + ".schema1.bak") == original_text, "Migration retains the exact original save backup")
	var migrated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.save_path))
	check(int(migrated.schema) == 2 and migrated.weapon_builds.primary.muzzle == muzzle, "Migrated save is stored in canonical three-slot format")
	state.queue_free()
	await process_frame
	print("BUILD TRANSACTIONS ","PASS" if failures == 0 else "FAIL",": ",checks," checks; atomic whole-build purchase, three guns, shared rounds, migration")
	quit(0 if failures == 0 else 1)
