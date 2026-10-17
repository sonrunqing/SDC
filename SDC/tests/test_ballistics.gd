extends SceneTree

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
	var catalog: Node = root.get_node("Catalog")
	var state: Node = root.get_node("GameState")
	for weapon: Dictionary in catalog.by_kind("weapon"):
		var weapon_id: String = weapon.id
		for ammo: Dictionary in catalog.by_kind("ammo"):
			if ammo.caliber != weapon.caliber: continue
			var profile: Dictionary = catalog.shot_profile(weapon_id, ammo.id)
			var near: float = catalog.shot_damage(weapon_id, ammo.id, 0)
			var start: float = float(profile.full_damage_distance)
			var span: float = float(profile.curve_distance)
			check(is_equal_approx(near, float(weapon.stats.damage) * float(profile.power_multiplier) + float(profile.bonus_damage)), weapon_id + " uses additive cartridge damage")
			check(is_equal_approx(near, catalog.shot_damage(weapon_id, ammo.id, -10)), "Negative distance safely behaves as contact")
			check(is_equal_approx(near, catalog.shot_damage(weapon_id, ammo.id, start)), "Contact zone keeps full damage")
			check(is_equal_approx(near, catalog.shot_damage(weapon_id, ammo.id, start+.0001)), "No damage jump at curve onset")
			var previous: float = near
			for step in range(1, 21):
				var distance: float = start + span * step / 21.0
				var damage: float = catalog.shot_damage(weapon_id, ammo.id, distance)
				check(damage > 0 and damage < previous, "Damage keeps decreasing throughout the usable curve: " + weapon_id)
				previous = damage
			var losses: Array[float] = []
			for fraction: float in [.05,.45,.85]:
				var distance: float = start + span * fraction
				losses.append(catalog.shot_damage(weapon_id, ammo.id, distance) - catalog.shot_damage(weapon_id, ammo.id, distance+1))
			check(losses[0] > 0 and losses[1] > losses[0] and losses[2] > losses[1], "Loss per metre increases with distance: " + weapon_id)
			check(losses[2] > losses[0]*3, "Far loss per metre is substantially larger than near loss")
			check(catalog.shot_damage(weapon_id, ammo.id, float(profile.zero_damage_distance)) == 0, "Zero boundary has no positive damage floor")
			check(catalog.shot_damage(weapon_id, ammo.id, 100000) == 0, "Out-of-range damage cannot become negative or recover")
			var test_distance: float = start + span * .45
			var faster_ammo: Dictionary = ammo.duplicate(true)
			faster_ammo.ballistics.velocity_multiplier = float(ammo.ballistics.velocity_multiplier) * 1.02
			var faster: Dictionary = catalog.Ballistics.profile(weapon, faster_ammo, weapon.stats)
			check(catalog.Ballistics.damage_at(faster, test_distance) > catalog.Ballistics.damage_at(profile, test_distance), "A small cartridge velocity increase retains more distant damage")
			check(is_equal_approx(catalog.Ballistics.damage_at(faster, 0), near), "Velocity alone cannot inflate contact damage")
			var faster_gun: Dictionary = weapon.duplicate(true)
			faster_gun.ballistics.muzzle_velocity = float(weapon.ballistics.muzzle_velocity)*1.02
			var faster_gun_profile: Dictionary = catalog.Ballistics.profile(faster_gun, ammo, weapon.stats)
			check(catalog.Ballistics.damage_at(faster_gun_profile,test_distance) > catalog.Ballistics.damage_at(profile,test_distance), "Gun muzzle velocity independently affects distant retention")
		var rating: int = catalog.performance_rating(weapon.stats)
		check(rating >= 0 and rating <= 100, "Performance display remains normalized")
	check(catalog.shot_damage("missing_weapon", "ammo_9x19_fmj", 1) == 0, "Unknown gun cannot cause phantom damage")
	check(catalog.shot_damage("weapon_reed9", "ammo_338lm_fmj", 1) == 0, "Wrong-caliber ammunition cannot produce damage")
	var fmj: String = "ammo_9x19_fmj"
	var hp: String = "ammo_9x19_hp"
	var ap: String = "ammo_9x19_ap"
	check(catalog.shot_damage("weapon_reed9", hp, 2) > catalog.shot_damage("weapon_reed9", fmj, 2), "Expanding cartridge gives close-range damage advantage")
	var fmj_hit: float = catalog.shot_damage("weapon_reed9", fmj, 2) * (1-clampf((45-float(catalog.get_item(fmj).penetration))/65,0,.72))
	var ap_hit: float = catalog.shot_damage("weapon_reed9", ap, 2) * (1-clampf((45-float(catalog.get_item(ap).penetration))/65,0,.72))
	check(ap_hit > fmj_hit, "AP earns its premium against armor")
	check(catalog.shot_damage("weapon_boar12", "ammo_12g_fmj", 35) / catalog.shot_damage("weapon_boar12", "ammo_12g_fmj", 1) < catalog.shot_damage("weapon_heron308", "ammo_308win_fmj", 35) / catalog.shot_damage("weapon_heron308", "ammo_308win_fmj", 1), "Shotgun and precision rifle retain distinct distance roles")
	var near_interval_loss: float = catalog.shot_damage("weapon_heron308", "ammo_308win_fmj", 0) - catalog.shot_damage("weapon_heron308", "ammo_308win_fmj", 10)
	var far_interval_loss: float = catalog.shot_damage("weapon_heron308", "ammo_308win_fmj", 150) - catalog.shot_damage("weapon_heron308", "ammo_308win_fmj", 160)
	check(far_interval_loss > near_interval_loss*10, "150-160m loses much more damage than 0-10m on a long-range gun")
	check(catalog.shot_damage("weapon_heron308", "ammo_308win_fmj", 160) > 0, "Long-range comparison remains inside the valid damage curve")
	var part: String = "att_suppressor_9_13"
	check(catalog.shot_damage("weapon_reed9", fmj, 60, {"muzzle":part}) > catalog.shot_damage("weapon_reed9", fmj, 60), "Compatible range attachment affects distant damage")
	var before: String = JSON.stringify([state.credits, state.stash, state.loadout])
	catalog.shot_damage("weapon_reed9", fmj, 50)
	check(before == JSON.stringify([state.credits, state.stash, state.loadout]), "Ballistic evaluation cannot mutate inventory")
	print("BALLISTICS TESTS ", "PASS" if failures == 0 else "FAIL", ": ", checks, " checks; accelerating loss/metre, ammo, gun velocity, armor; 0-10m loss=", near_interval_loss, ", 150-160m loss=", far_interval_loss)
	quit(0 if failures == 0 else 1)
