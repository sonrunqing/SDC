extends RefCounted
## Shared deterministic damage calculation. Values stay out of the game HUD.

static func profile(weapon: Dictionary, ammo: Dictionary, stats: Dictionary) -> Dictionary:
	var gun: Dictionary = weapon.get("ballistics", {})
	var cartridge: Dictionary = ammo.get("ballistics", {})
	var reference_velocity := maxf(1.0, float(gun.get("reference_velocity", 360.0)))
	var velocity := maxf(1.0, float(gun.get("muzzle_velocity", reference_velocity))) * clampf(float(cartridge.get("velocity_multiplier", 1.0)), 0.9, 1.1)
	var drag := clampf(float(cartridge.get("drag_multiplier", 1.0)), 0.75, 1.3)
	var original_stats: Dictionary = weapon.get("stats", {})
	var range_factor := clampf(float(stats.get("range", 25.0)) / maxf(1.0, float(original_stats.get("range", 25.0))), 0.5, 1.8)
	# Velocity affects retained energy over distance, without replacing penetration.
	var reach_factor := range_factor * pow(velocity / reference_velocity, 1.4) / sqrt(drag)
	var start := maxf(0.0, float(gun.get("full_damage_distance", 2.0)))
	var curve_distance := maxf(1.0, float(gun.get("curve_distance", 60.0)) * reach_factor)
	return {
		"base_damage": maxf(0.0, float(stats.get("damage", 0.0))),
		"bonus_damage": maxf(0.0, float(cartridge.get("bonus_damage", 0.0))),
		"power_multiplier": clampf(float(cartridge.get("power_multiplier", 1.0)), 0.97, 1.03),
		"velocity": velocity, "full_damage_distance": start,
		"curve_distance": curve_distance, "zero_damage_distance": start + curve_distance,
		"falloff_exponent": clampf(float(gun.get("falloff_exponent", 2.0)), 1.1, 4.0),
	}

static func damage_at(shot: Dictionary, distance: float) -> float:
	if shot.is_empty(): return 0.0
	var start := float(shot["full_damage_distance"])
	var travel := maxf(0.0, distance - start)
	var curve_distance := float(shot["curve_distance"])
	if travel >= curve_distance: return 0.0
	# A power curve makes loss per metre grow with distance until damage reaches zero.
	var attenuation := 1.0 - pow(travel / curve_distance, float(shot["falloff_exponent"]))
	return (float(shot["base_damage"]) * float(shot["power_multiplier"]) + float(shot["bonus_damage"])) * attenuation

static func performance_rating(stats: Dictionary) -> int:
	var damage := sqrt(clampf(float(stats.get("damage", 0)) / 100.0, 0, 1))
	var accuracy := clampf(float(stats.get("accuracy", 0)) / 100.0, 0, 1)
	var control := 1.0 - clampf(float(stats.get("recoil", 100)) / 100.0, 0, 1)
	var handling := clampf(float(stats.get("ergonomics", 0)) / 100.0, 0, 1)
	var reach := sqrt(clampf(float(stats.get("range", 0)) / 80.0, 0, 1))
	var rate := sqrt(clampf(float(stats.get("rpm", 0)) / 900.0, 0, 1))
	var capacity := log(1.0 + maxf(0, float(stats.get("magazine", 0)))) / log(101.0)
	return clampi(roundi(100.0 * (damage*.20 + accuracy*.18 + control*.18 + handling*.16 + reach*.12 + rate*.10 + capacity*.06)), 0, 100)
