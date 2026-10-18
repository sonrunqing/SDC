extends SceneTree
## Real physics / raycast / delayed search / extraction smoke, with isolated user data.

var failures: Array[String] = []
var checks: int = 0
var state: Node
var catalog: Node
var world: Node3D
var hud_events: int = 0
var finished_events: int = 0
var extraction_result: bool = false

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func ticks(count: int) -> void:
	for _tick: int in range(count):
		await physics_frame

func input_for_world(direction: Vector3) -> Vector2:
	var right: Vector3 = world.camera.global_basis.x
	var down: Vector3 = world.camera.global_basis.z
	right.y = 0.0
	down.y = 0.0
	return Vector2(direction.dot(right.normalized()), direction.dot(down.normalized()))

func first_compatible(weapon_id: String, slot: String) -> String:
	for item: Dictionary in catalog.by_kind("attachment"):
		if str(item.get("slot", "")) == slot and catalog.compatible(weapon_id, str(item.id), slot):
			return str(item.id)
	return ""

func carried_ammo_total() -> int:
	var total: int = 0
	for quantity: Variant in state.raid_ammo_by_id.values():
		total += int(quantity)
	for quantity: Variant in state.raid_loaded_by_slot.values():
		total += int(quantity)
	return total

func _run() -> void:
	state = root.get_node("GameState")
	catalog = root.get_node("Catalog")
	state.save_path = "user://test_raid_gameplay.json"
	state.reset_progress()
	# Use the actual procurement/build/plan APIs to prepare three distinct calibres.
	state.credits = 100000
	var primary_id: String = str(state.loadout.primary)
	var primary_parts: Dictionary = {
		"muzzle": first_compatible(primary_id, "muzzle"),
		"optic": first_compatible(primary_id, "optic"),
	}
	var secondary_parts: Dictionary = {"optic": first_compatible("weapon_badger556", "optic")}
	var sidearm_parts: Dictionary = {"muzzle": first_compatible("weapon_ember45", "muzzle")}
	check(state.buy_build(primary_id, primary_parts, "primary"), "primary assembly equips through atomic procurement")
	check(state.buy_build("weapon_badger556", secondary_parts, "secondary"), "second long gun equips through procurement")
	check(state.buy_build("weapon_ember45", sidearm_parts, "sidearm"), "pistol equips through procurement")
	var planned_rounds: Dictionary = {"ammo_9x19_fmj": 90, "ammo_556x45_fmj": 60, "ammo_45acp_fmj": 32}
	var ammo_before_by_id: Dictionary = {}
	for id: String in planned_rounds:
		var shortfall: int = maxi(0, int(planned_rounds[id]) - int(state.stash.get(id, 0)))
		if shortfall > 0:
			check(state.buy(id, shortfall), "procures planned calibre " + id)
		check(state.set_ammo_carry(id, int(planned_rounds[id])), "sets explicit ammunition plan " + id)
		ammo_before_by_id[id] = int(state.stash.get(id, 0))
	check(state.select_weapon_ammo("primary", "ammo_9x19_fmj"), "selects primary cartridge")
	check(state.select_weapon_ammo("secondary", "ammo_556x45_fmj"), "selects secondary cartridge")
	check(state.select_weapon_ammo("sidearm", "ammo_45acp_fmj"), "selects pistol cartridge")
	check(state.set_active_weapon("primary"), "selects primary before deployment")
	var ammo_id: String = str(state.loadout.ammo)
	var ammo_before: int = int(state.stash.get(ammo_id, 0))
	check(state.begin_raid(), "valid equipped loadout starts raid")
	world = load("res://scripts/raid_world.gd").new()
	root.add_child(world)
	world.hud_changed.connect(func(_info: Dictionary) -> void: hud_events += 1)
	world.raid_finished.connect(func(extracted: bool, _details: Dictionary) -> void:
		finished_events += 1
		extraction_result = extracted)
	world.start_raid()
	world._rng.seed = 20261016
	await ticks(3)
	check(world._active and is_instance_valid(world.player), "world constructs active physical player")
	check(world._guards.size() >= 4 and world._containers.size() >= 6, "world creates guards and searchable containers")
	check(world._magazine > 0 and state.raid_loaded_ammo == world._magazine, "initial magazine uses actual reserved ammo and records its weight")
	check(carried_ammo_total() == 182, "world start preserves all planned ammo without loading a second time")
	check(world._weapon_models.size() == 3, "all three carried guns have scene assemblies")
	var distinct_models: Dictionary = {}
	for slot: String in ["primary", "secondary", "sidearm"]:
		var assembly: Node3D = world.get_weapon_model(slot)
		check(is_instance_valid(assembly) and assembly.has_method("build_summary"), "actual authored assembly used for " + slot)
		if assembly != null and assembly.has_method("build_summary"):
			var summary: Dictionary = assembly.build_summary()
			distinct_models[str(summary.weapon_id)] = true
			check(bool(summary.valid) and int(summary.mesh_count) > 2, "physical geometry and sockets valid for " + slot)
			check(summary.parts == state.weapon_builds[slot], "raid uses precisely installed pieces for " + slot)
			for socket: String in state.weapon_builds[slot]:
				check(assembly.get_socket(socket).get_node_or_null("Part_" + socket) != null, "custom piece attached to true socket " + slot + "/" + socket)
	check(distinct_models.size() == 3, "three weapon slots load distinct authored gun bodies")
	check(not world._navigation_path(world.SPAWN, world.EXIT).is_empty(), "walkable navigation path connects spawn to extraction")

	# Disable attacks to isolate deterministic input/collision assertions, retaining bodies in physics.
	for guard: Dictionary in world._guards:
		guard["hp"] = 0.0
	var start: Vector3 = world.player.position
	world.set_move(Vector2.RIGHT)
	await ticks(18)
	world.set_move(Vector2.ZERO)
	check(world.player.position.x > start.x + 1.1, "virtual movement vector moves player on live physics ticks")

	# A real barricade at (7.5,16) must block the capsule, not just map boundaries.
	world.player.position = Vector3(7.5, 0, 18)
	await ticks(2)
	world.set_move(input_for_world(Vector3.FORWARD))
	await ticks(40)
	world.set_move(Vector2.ZERO)
	check(world.player.position.z > 16.5 and world.player.position.z < 17.0, "player capsule is blocked by physical barricade")
	check(world.player.get_slide_collision_count() > 0, "blocking movement produces a physics collision")

	# Fire through the public aim input; a live ray must hit the target's physics shape.
	world.player.position = Vector3(0, 0, 19)
	var target: Dictionary = world._guards[0]
	var target_body: CharacterBody3D = target["body"]
	target_body.position = Vector3(0, 0, 15.5)
	target["hp"] = 100.0
	target["cooldown"] = 999.0
	target["patrol"] = [target_body.position, target_body.position]
	await ticks(3)
	var magazine_before: int = world._magazine
	var weight_before_shot: float = state.raid_weight()
	world.set_aim(input_for_world(Vector3.FORWARD))
	world.set_fire(true)
	await ticks(2)
	world.set_fire(false)
	check(world._magazine == magazine_before - 1 and world._shots == 1, "one physical firing interval spends one loaded round")
	check(float(target["hp"]) < 100.0, "actual projectile ray damages guard")
	check(state.raid_loaded_ammo == world._magazine, "shot synchronizes state loaded-ammo count")
	check(is_equal_approx(weight_before_shot - state.raid_weight(), float(catalog.get_item(ammo_id).weight)), "fired round leaves carried weight")
	var health_before_attack: float = world._hp
	target["cooldown"] = 0.0
	# Move beyond the brief entry grace to exercise the guard's normal shooting branch.
	world._time_left = minf(world._time_left, world.RAID_DURATION - 4.0)
	await ticks(3)
	check(world._hp < health_before_attack, "visible live guard fires a ray that damages player")
	for guard: Dictionary in world._guards:
		guard["hp"] = 0.0
	var reserve_before_reload: int = state.raid_ammo
	world.reload_weapon()
	check(world._reload_left > 0.0, "reload starts a timed action")
	await ticks(130)
	check(world._reload_left <= 0.0 and world._magazine == world._magazine_size, "live reload timer fills magazine")
	check(state.raid_ammo == reserve_before_reload - 1, "reload consumes exactly one missing round from reserve")
	check(state.raid_loaded_ammo == world._magazine, "reload synchronizes loaded round count")

	# Switching changes calibre, real stats and hand model, while preserving each magazine.
	var primary_loaded: int = world._magazine
	var primary_damage: float = float(world._weapon_stats.damage)
	check(world.switch_weapon("secondary"), "public secondary switch succeeds")
	check(world._magazine == state.get_loaded_ammo("secondary") and world._magazine > 0, "secondary receives its own preloaded magazine")
	check(state.raid_ammo_id == "ammo_556x45_fmj" and float(world._weapon_stats.damage) != primary_damage, "secondary uses its own cartridge and combat stats")
	check(world._weapon_mounts.secondary.position.is_equal_approx(Vector3(0.22, 1.05, -0.32)), "secondary authored assembly moves to hand mount")
	var secondary_magazine: int = world._magazine
	await ticks(14)
	world.set_aim(input_for_world(Vector3.FORWARD))
	world.set_fire(true)
	await ticks(2)
	world.set_fire(false)
	check(world._magazine == secondary_magazine - 1, "secondary fires its own loaded cartridge")
	var secondary_reserve: int = state.get_raid_ammo("secondary")
	world.reload_weapon()
	await ticks(2)
	check(world.switch_weapon("sidearm"), "public pistol switch succeeds during incomplete reload")
	check(world._reload_left == 0.0 and state.get_raid_ammo("secondary") == secondary_reserve, "weapon switch cancels reload without spending other calibre")
	check(state.raid_ammo_id == "ammo_45acp_fmj" and world._magazine == state.get_loaded_ammo("sidearm"), "pistol selects its own ammunition and magazine")
	var pistol_magazine: int = world._magazine
	await ticks(14)
	world.set_aim(input_for_world(Vector3.FORWARD))
	world.set_fire(true)
	await ticks(2)
	world.set_fire(false)
	check(world._magazine == pistol_magazine - 1, "pistol fires its own loaded cartridge")
	var ammo_before_cycle: int = carried_ammo_total()
	for _cycle: int in range(3):
		check(world.switch_weapon("primary") and world._magazine == primary_loaded, "primary magazine persists across switch cycle")
		check(world.switch_weapon("secondary") and world._magazine == secondary_magazine - 1, "secondary partial magazine persists across switch cycle")
		check(world.switch_weapon("sidearm") and world._magazine == pistol_magazine - 1, "pistol partial magazine persists across switch cycle")
	check(carried_ammo_total() == ammo_before_cycle, "repeated weapon switching cannot mint rounds")
	check(not world.switch_weapon("invalid") and state.active_weapon_slot == "sidearm", "invalid switch leaves active weapon unchanged")
	check(world.switch_weapon("primary"), "returns to primary for remainder of raid")
	var hud_weapons: Array = world.get_hud().get("weapons", [])
	check(hud_weapons.size() == 3 and str(world.get_hud().active_weapon_slot) == "primary", "HUD exposes all three guns and active slot")

	# The selected medical definition changes healing; using it consumes one carried unit.
	world._hp = 20.0
	var meds_before: int = state.raid_meds
	var healing: float = float(state.get_selected_medkit().get("heal", 0))
	world.use_medkit()
	check(is_equal_approx(world._hp, minf(100.0, 20.0 + healing)), "world heals by the carried medicine definition")
	check(state.raid_meds == meds_before - 1, "healing consumes a real carried medical item")

	# Container search reveals records but never awards them automatically.
	var crate: Dictionary=world._containers[0]
	var approach: Array=world._navigation_path(world.SPAWN,crate.position)
	world.player.position=approach[-1]
	world.player.velocity=Vector3.ZERO
	await ticks(2)
	check(world._open_container(0),"nearby interact opens the container")
	world.set_move(Vector2.RIGHT)
	check(world._ui_blocked and world._move==Vector2.ZERO,"search modal blocks gameplay movement")
	await ticks(300)
	check(bool(world.get_container_snapshot().complete) and state.raid_loot.is_empty(),"completed search reveals contents without awarding them")
	var selected: Dictionary=crate.search.records[0]
	check(world.take_container_item(str(selected.uid),1),"explicit selected pickup transfers one discovered item")
	check(not state.raid_loot.is_empty() and not bool(crate.opened),"unselected contents remain in the source")
	world.close_container()
	var carried_loot: Dictionary=state.raid_loot.duplicate(true)
	check(int(world.get_hud().get("loot_value",0))>0,"HUD values only the loot actually picked")

	# Exercise the normal dwell timer: leaving the zone resets progress; five still seconds finish.
	world.player.position = world.EXIT
	world.player.velocity = Vector3.ZERO
	await ticks(75)
	check(world._extract_progress > 0.4 and world._extract_progress < world.EXTRACTION_DURATION, "standing in exit advances extraction without immediate success")
	check(state.raid_active and finished_events == 0, "partial dwell has no settlement")
	world.player.position = world.EXIT + Vector3(4, 0, 0)
	await ticks(3)
	check(is_zero_approx(world._extract_progress), "leaving extraction zone resets countdown")
	world.player.position = world.EXIT
	world.player.velocity = Vector3.ZERO
	await ticks(315)
	check(finished_events == 1 and extraction_result and not state.raid_active and not world._active, "normal five-second dwell settles extraction exactly once")
	for id: String in carried_loot:
		check(int(state.stash.get(id, 0)) >= int(carried_loot[id]), "extraction banks looted item " + id)
	check(int(state.stash.get(ammo_id, 0)) >= ammo_before - 1, "world settlement returns remaining magazine and reserves")
	for id: String in ammo_before_by_id:
		var expected: int = int(ammo_before_by_id[id]) - 1 + int(carried_loot.get(id, 0))
		check(int(state.stash.get(id, 0)) == expected, "all guns return loaded+reserve exactly once for " + id)
	check(int(state.last_result.get("shots", 0)) == 3, "settlement records actual shots from all three guns")
	check(hud_events > 10, "world emits live HUD updates")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
	world.queue_free()
	await process_frame
	# The result cue intentionally outlives the world and frees itself after one second.
	await create_timer(1.15).timeout
	if failures.is_empty():
		print("RAID TESTS PASS: %d checks; movement, collision, shot ray, reload, healing, timed search, extraction" % checks)
		quit(0)
	else:
		print("RAID TESTS FAILED: ", failures.size(), " / ", checks)
		quit(1)
