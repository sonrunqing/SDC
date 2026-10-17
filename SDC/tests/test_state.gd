extends SceneTree
## Run with isolated XDG_DATA_HOME: godot --headless --path game --script res://tests/test_state.gd

var failures: Array[String] = []
var state: Node
var catalog: Node

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func first_item(kind: String, category: String = "") -> String:
	for id: String in catalog.items:
		var item: Dictionary = catalog.get_item(id)
		if str(item.get("kind", "")) == kind and (category.is_empty() or str(item.get("category", "")) == category):
			return id
	return ""

func get_compatible_attachment(weapon: String, compatible: bool) -> String:
	for id: String in catalog.items:
		var item: Dictionary = catalog.get_item(id)
		if str(item.get("kind", "")) == "attachment" and catalog.compatible(weapon, id) == compatible:
			return id
	return ""

func _run() -> void:
	catalog = root.get_node("Catalog")
	state = load("res://scripts/game_state.gd").new()
	state.save_path = "user://test_state_lifecycle.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
	root.add_child(state)
	state.reset_progress()
	check(state.credits == state.STARTING_CREDITS, "reset gives starting funds")
	var initial_weapon: String = str(state.loadout.weapon)
	var ammo: String = str(state.loadout.ammo)
	check(not initial_weapon.is_empty() and not ammo.is_empty(), "starting weapon and compatible ammunition exist")
	check(catalog.get_item(initial_weapon).caliber == catalog.get_item(ammo).caliber, "starting caliber matches")
	check(not state.sell(initial_weapon), "equipped weapon cannot be sold")
	check(not state.buy(initial_weapon, -1), "negative purchase rejected")
	check(not state.sell(ammo, 1000000), "overselling rejected")
	var before_cash: int = state.credits
	var before_ammo: int = int(state.stash.get(ammo, 0))
	check(state.buy(ammo, 10), "ammunition purchase succeeds")
	check(state.credits == before_cash - int(catalog.get_item(ammo).price) * 10, "purchase charged exactly")
	check(int(state.stash.get(ammo, 0)) == before_ammo + 10, "purchase adds exact stock")
	check(state.sell(ammo, 10), "stash ammunition can be sold")
	check(int(state.stash.get(ammo, 0)) == before_ammo, "sale removes exact stock")

	# Attachment compatibility, inventory conservation and dedicated restrictions.
	state.credits = 1000000
	var compatible: String = get_compatible_attachment(initial_weapon, true)
	var incompatible: String = get_compatible_attachment(initial_weapon, false)
	check(not compatible.is_empty() and not incompatible.is_empty(), "catalog has compatible and incompatible interfaces")
	check(state.buy(incompatible), "buy incompatible attachment for validation")
	check(not state.install_attachment(incompatible), "incompatible attachment installation rejected")
	check(int(state.stash.get(incompatible, 0)) == 1, "rejected attachment remains in stash")
	check(state.buy(compatible) and state.install_attachment(compatible), "compatible attachment installation succeeds")
	var attach_slot: String = str(catalog.get_item(compatible).slot)
	check(str(state.attachments.get(attach_slot, "")) == compatible, "attachment stored in correct slot")
	check(int(state.stash.get(compatible, 0)) == 0, "installed attachment removed from stash")
	check(not state.sell(compatible), "installed attachment cannot be sold")
	var other_weapon: String = first_item("weapon", "rifle")
	check(state.buy(other_weapon) and state.equip(other_weapon), "weapon swap succeeds")
	check(state.attachments.is_empty(), "weapon swap detaches attachments")
	check(int(state.stash.get(compatible, 0)) == 1, "detached attachment returned to stash")
	check(int(state.stash.get(initial_weapon, 0)) == 1, "old weapon returned to stash")
	check(state.equip(initial_weapon), "original weapon can be equipped again")
	check(state.equip(ammo), "compatible ammunition selected")
	for id: String in catalog.items:
		var item: Dictionary = catalog.get_item(id)
		if str(item.get("kind", "")) == "ammo" and str(item.get("caliber", "")) != str(catalog.get_item(initial_weapon).caliber):
			state.buy(id)
			check(not state.equip(id), "wrong-caliber ammunition rejected")
			break

	# Two helmet mounts stay distinct; a swap safely returns an incompatible visor.
	var visor: String = ""
	var matching_helmet: String = ""
	var other_helmet: String = ""
	for id: String in catalog.items:
		if str(catalog.get_item(id).get("category", "")) == "visor":
			visor = id
			break
	for id: String in catalog.items:
		if str(catalog.get_item(id).get("category", "")) == "helmet":
			if catalog.visor_compatible(id, visor):
				matching_helmet = id
			else:
				other_helmet = id
	check(not matching_helmet.is_empty() and not other_helmet.is_empty(), "two helmet mount standards represented")
	state.buy(visor)
	state.buy(other_helmet)
	state.equip(other_helmet)
	check(not state.equip(visor), "wrong helmet mount rejects visor")
	state.buy(matching_helmet)
	check(state.equip(matching_helmet), "matching helmet equips")
	var head_penetration: float = maxf(0.0, float(catalog.get_item(matching_helmet).get("protection", 0.0)) - 10.0)
	var damage_without_visor: float = state.damage_after_armor(50.0, head_penetration, true)
	check(state.equip(visor), "matching visor mounts successfully")
	check(state.damage_after_armor(50.0, head_penetration, true) < damage_without_visor, "same helmet gains effective head protection from visor")
	state.buy(other_helmet)
	state.equip(other_helmet)
	check(str(state.loadout.visor).is_empty() and int(state.stash.get(visor, 0)) == 1, "helmet swap returns visor safely")
	var rig: String = first_item("armor", "armored_rig")
	state.buy(rig)
	check(state.equip(rig), "capacity-only rig can be equipped")
	check(str(state.loadout.body_armor).is_empty(), "rig and body armor do not stack")
	check(not catalog.get_item(rig).has("level"), "rig carries no armor level")
	check(state.damage_after_armor(50.0, 0.0) < state.damage_after_armor(50.0, 100.0), "penetration bypasses protection")

	# Save/load keeps inventory, credits and equipment without duplicating either.
	state.save_game()
	var saved_cash: int = state.credits
	var saved_stash: Dictionary = state.stash.duplicate(true)
	var saved_loadout: Dictionary = state.loadout.duplicate(true)
	state.credits = 0
	state.stash.clear()
	check(state.load_game(), "saved progress loads")
	check(state.credits == saved_cash and state.stash == saved_stash and state.loadout == saved_loadout, "save/load preserves exact state")

	# Extraction returns only unused ammunition and meds; loot is sold by a separate action.
	state.reset_progress()
	var loot_id: String = first_item("loot")
	check(not loot_id.is_empty(), "loot catalog available")
	var ammo_before: int = int(state.stash.get(ammo, 0))
	var cash_before_raid: int = state.credits
	check(state.begin_raid(), "raid starts with kit")
	var reserved: int = state.raid_ammo
	check(not state.buy(ammo) and not state.unequip("weapon"), "loadout and market lock during raid")
	var full_ammo_weight: float = state.raid_weight()
	var loaded_at_start: int = state.get_loaded_ammo()
	check(loaded_at_start > 5, "begin raid preloads an actual magazine once")
	state.set_raid_loaded_ammo(loaded_at_start - 5)
	check(is_equal_approx(full_ammo_weight - state.raid_weight(), 5.0 * float(catalog.get_item(ammo).weight)), "only fired rounds stop contributing to carried weight")
	var after_shots_weight: float = state.raid_weight()
	check(state.consume_raid_ammo(5) == 5, "reload moves five reserve rounds into the existing magazine")
	check(is_equal_approx(state.raid_weight(), after_shots_weight), "moving reserve rounds into magazine preserves carried weight")
	check(state.consume_raid_medkit(), "medkit consumed from carried supply")
	check(state.add_raid_loot(loot_id), "loot is collected within capacity")
	var result: Dictionary = state.finish_raid(true, {"remaining_magazine": loaded_at_start})
	check(bool(result.extracted), "successful extraction recorded")
	check(int(state.stash.get(ammo, 0)) == ammo_before - 5, "only five fired rounds are spent")
	check(int(state.stash.get(loot_id, 0)) == 1, "extracted loot reaches stash")
	check(state.credits == cash_before_raid, "loot value is not silently paid before sale")
	check(state.sell(loot_id), "extracted loot can be sold")
	check(state.credits == cash_before_raid + int(catalog.get_item(loot_id).sell_price), "loot sale converts to game credits")
	check(reserved > 0 and not state.raid_active, "raid closes after extraction")

	# Death loses carried gear and supplies while stash reserves survive.
	check(state.begin_raid(), "second raid starts")
	var stash_during_raid: Dictionary = state.stash.duplicate(true)
	state.add_raid_loot(loot_id)
	state.finish_raid(false)
	check(str(state.loadout.weapon).is_empty() and state.attachments.is_empty(), "death removes carried weapon and attachments")
	check(state.stash == stash_during_raid, "death leaves only the stash, forfeiting carried supplies and loot")
	check(not state.begin_raid(), "unarmed deployment rejected")
	check(state.buy(initial_weapon) and state.equip(initial_weapon) and state.equip(ammo), "player can regear after death")
	state.set_ammo_carry(ammo, mini(90, int(state.stash.get(ammo, 0))))
	check(state.begin_raid(), "regeared player can deploy")
	check(state.load_game(), "interrupted active raid can load")
	check(not state.raid_active and str(state.loadout.weapon).is_empty(), "interrupted raid forfeits equipment, preventing duplication")

	# Bankruptcy must not leave the game permanently unplayable.
	state.reset_progress()
	state.credits = 0
	check(state.begin_raid(), "bankrupt equipped player may raid")
	state.finish_raid(false)
	check(bool(state.last_result.get("recovery_kit", false)), "bankrupt death grants a basic recovery kit")
	check(state.begin_raid(), "recovery kit permits another raid")
	state.finish_raid(true)

	# Every medical type can be carried and its own healing definition reaches the world.
	state.reset_progress()
	state.sell("medkit_field", int(state.stash.get("medkit_field", 0)))
	check(state.buy("bandage_basic"), "bandage can be stocked")
	check(state.begin_raid(), "bandage-only raid starts")
	check(str(state.raid_medkit_id) == "bandage_basic" and int(state.get_selected_medkit().get("heal", 0)) == 25, "bandage fallback is selected with its own healing amount")
	state.finish_raid(true)
	check(state.buy("medkit_surgical"), "surgical kit can be stocked")
	check(state.begin_raid(), "mixed-medicine raid starts")
	check(str(state.raid_medkit_id) == "medkit_surgical" and int(state.get_selected_medkit().get("heal", 0)) == 85, "strongest stocked medicine selected")
	state.finish_raid(true)

	# Capacity rejection is atomic.
	state.reset_progress()
	check(state.begin_raid(), "capacity test raid starts")
	check(not state.add_raid_loot(loot_id, 100000), "overweight loot rejected")
	check(state.raid_loot.is_empty(), "rejected loot never enters inventory")
	state.finish_raid(true)
	check(not state.finish_raid(true).is_empty() and not state.raid_active, "double settlement does not repeat rewards")
	var valid_cash: int = state.credits
	var malformed: FileAccess = FileAccess.open(state.save_path, FileAccess.WRITE)
	malformed.store_string('{"schema":1,"credits":[],"stash":{},"loadout":{},"attachments":{}}')
	malformed.close()
	check(not state.load_game() and state.credits == valid_cash, "malformed save is rejected without partial mutation")
	state.save_game()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
	state.queue_free()
	if failures.is_empty():
		print("STATE TESTS PASS: economy, compatibility, inventory conservation, extraction, death, recovery, persistence")
		quit(0)
	else:
		print("STATE TESTS FAILED: ", failures.size())
		quit(1)
