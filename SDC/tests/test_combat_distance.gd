extends SceneTree
## Real physical hit integration: same gun, same cartridge, different target distance.
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func _run() -> void:
	var state: Node = root.get_node("GameState")
	var catalog: Node = root.get_node("Catalog")
	state.save_path = "user://test_distance.json"
	state.reset_progress()
	check(state.begin_raid(), "Starter kit can enter distance integration test")
	var world: Node3D = load("res://scripts/raid_world.gd").new()
	root.add_child(world)
	world.start_raid()
	world.set_physics_process(false)
	for guard: Dictionary in world._guards: guard.hp = 0.0
	world.player.position = Vector3(0, 0, 19)
	world._aim_direction = Vector3.FORWARD
	world._weapon_stats.accuracy = 100.0
	var target: Dictionary = world._guards[0]
	var body: CharacterBody3D = target.body
	var damage_samples: Array[float] = []
	for z: float in [15.5, -10.0, -21.0]:
		body.position = Vector3(0, 0, z)
		target.hp = 100.0
		world._recoil = 0.0
		world._rng.seed = 42
		await physics_frame
		await physics_frame
		world._fire_player()
		damage_samples.append(100.0 - float(target.hp))
	check(damage_samples[0] > 0 and damage_samples[1] > 0, "Both near and distant physical guard colliders are hit")
	check(damage_samples[1] < damage_samples[0] * .97, "Actual combat applies lower damage at distant target")
	check(is_equal_approx(snappedf(damage_samples[0], .1), 22.8), "Close physical impact still rounds to 22.8")
	check(damage_samples[2] < damage_samples[1] and damage_samples[2] > 0, "Farther physical impact continues down the damage curve")
	check(damage_samples[1] > damage_samples[0] * .38, "Midrange impact remains above the distant damage floor")
	var armor_factor: float = 1.0-clampf((float(target.armor)-float(catalog.get_item("ammo_9x19_fmj").penetration))/65.0,0,.72)
	var beyond_reference: float = catalog.shot_damage("weapon_reed9", "ammo_9x19_fmj", 80)*armor_factor
	check(beyond_reference < 18.2 and beyond_reference > 0, "Damage continues below former 18.2 floor beyond the visible screen")
	var reference_distance: float = float(catalog.get_item("weapon_reed9").ballistics.screen_reference_distance)
	var edge_damage: float = catalog.shot_damage("weapon_reed9", "ammo_9x19_fmj", reference_distance)*armor_factor
	check(is_equal_approx(edge_damage,20.5), "Screen-reference distance deals 20.5 for the 22.8 baseline combination")
	check(world._magazine == state.get_loaded_ammo() and world._magazine == 27, "All three physical hits spend real loaded ammunition")
	var counts: Dictionary = {}
	world._rng.seed = 20261016
	for _sample in range(20000):
		var id: String = world._weighted_loot_id()
		counts[id] = int(counts.get(id, 0)) + 1
	check(int(counts.get("loot_statue", 0)) < 200 and int(counts.get("loot_statue", 0)) > 20, "Actual world gold-item frequency respects sub-one-percent weight")
	check(int(counts.get("loot_wire", 0)) > int(counts.get("loot_processor", 0)) * 3, "Common materials dominate actual loot generation")
	print("COMBAT DISTANCE TESTS ", "PASS" if failures == 0 else "FAIL", ": ", checks, " checks; near/mid/far actual damage=", damage_samples)
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
