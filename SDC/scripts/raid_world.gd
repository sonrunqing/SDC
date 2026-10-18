extends Node3D
## A compact, fully simulated single-player extraction raid. All distances are metres.

signal hud_changed(info: Dictionary)
signal raid_finished(extracted: bool, details: Dictionary)

const MAP_HALF := Vector2(80.0, 90.0)
const SPAWN := Vector3(0.0, 0.0, 78.0)
const EXIT := Vector3(0.0, 0.0, -77.0)
const RAID_DURATION := 900.0
const EXTRACTION_DURATION := 5.0
const WALK_SPEED := 5.3
const CAMERA_OFFSET := Vector3(11.5, 26.0, 20.5)
const WEAPON_SLOTS := ["primary", "secondary", "sidearm"]
const CRATE_MODEL = preload("res://assets/kenney/blaster-kit/crate-small.glb")

var entry_id: String = "south"
var entry_position: Vector3 = SPAWN
var _harbor: Node3D
var player: CharacterBody3D
var player_model: Node3D
var camera: Camera3D
var aim_line: MeshInstance3D
var muzzle: Node3D
var _nav: AStarGrid2D
var _guards: Array[Dictionary] = []
var _containers: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _obstacles: Array[Rect2] = []
var _materials: Dictionary = {}
var _loot_ids: Array[String] = []
var _ammo_ids: Array[String] = []
var _attachment_ids: Array[String] = []
var _weapon_stats: Dictionary = {}
var _weapon_models: Dictionary = {}
var _weapon_mounts: Dictionary = {}
var _switch_left := 0.0
var _font: Font
var _sound: Node
var _rng := RandomNumberGenerator.new()
var _move := Vector2.ZERO
var _stick_aim := Vector2.ZERO
var _aim_direction := Vector3.FORWARD
var _stick_firing := false
var _active := false
var _ui_blocked: bool = false
var _finished := false
var _hp := 100.0
var _magazine := 0
var _magazine_size := 30
var _time_left := RAID_DURATION
var _shot_cooldown := 0.0
var _reload_left := 0.0
var _extract_progress := 0.0
var _hud_clock := 0.0
var _search_left := 0.0
var _search_target := -1
var _notice := ""
var _notice_left := 0.0
var _hit_marker := 0.0
var _kills := 0
var _shots := 0
var _looted := 0
var _recoil := 0.0
var _exit_ring: MeshInstance3D
var _player_ring: MeshInstance3D


func start_raid(selected_entry: String = "south") -> void:
	entry_id = selected_entry
	entry_position = SPAWN
	var layout_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/harbor_layout.json"))
	for entry: Dictionary in layout_data.get("entries",[]):
		if str(entry.id) == entry_id: entry_position = Vector3(float(entry.position[0]),0,float(entry.position[2]))
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_guards.clear()
	_containers.clear()
	_effects.clear()
	_obstacles.clear()
	_materials.clear()
	_loot_ids.clear()
	_ammo_ids.clear()
	_attachment_ids.clear()
	_weapon_models.clear()
	_weapon_mounts.clear()
	_rng.randomize()
	_font = load("res://assets/fonts/NotoSansSC.ttf") as Font
	_weapon_stats = GameState.weapon_stats()
	_magazine_size = maxi(1, int(_weapon_stats.get("magazine", 30)))
	# GameState reserves ammunition and preloads every carried weapon atomically.
	_magazine = GameState.get_loaded_ammo()
	_hp = 100.0
	_time_left = RAID_DURATION
	_shot_cooldown = 0.0
	_reload_left = 0.0
	_extract_progress = 0.0
	_move = Vector2.ZERO
	_stick_aim = Vector2.ZERO
	_aim_direction = Vector3.FORWARD
	_stick_firing = false
	_ui_blocked = false
	_finished = false
	_kills = 0
	_shots = 0
	_looted = 0
	_search_target = -1
	_search_left = 0.0
	_hit_marker = 0.0
	_recoil = 0.0
	_switch_left = 0.0
	_collect_loot_tables()
	_sound = load("res://scripts/raid_audio.gd").new()
	add_child(_sound)
	_build_environment()
	_build_yard()
	_build_navigation()
	_build_player()
	_build_guards()
	_build_containers()
	_build_camera()
	_active = true
	_emit_hud()


func set_move(value: Vector2) -> void:
	_move = Vector2.ZERO if _ui_blocked else value.limit_length(1.0)


func set_aim(value: Vector2) -> void:
	_stick_aim = Vector2.ZERO if _ui_blocked else value.limit_length(1.0)

func set_fire(pressed: bool) -> void:
	_stick_firing = pressed and not _ui_blocked

func set_input_blocked(blocked: bool) -> void:
	_ui_blocked=blocked
	_move=Vector2.ZERO
	_stick_aim=Vector2.ZERO
	_stick_firing=false


func switch_weapon(slot: String) -> bool:
	if not _active or slot not in WEAPON_SLOTS:
		return false
	if slot == GameState.active_weapon_slot:
		return true
	# Store the old gun first: reloading never spends reserve until its timer ends.
	GameState.set_raid_loaded_ammo(_magazine)
	if not GameState.set_active_weapon(slot):
		_notify(GameState.last_error)
		return false
	_reload_left = 0.0
	_search_left = 0.0
	_search_target = -1
	_switch_left = 0.18
	_shot_cooldown = maxf(_shot_cooldown, _switch_left)
	_recoil = 0.0
	_weapon_stats = GameState.weapon_stats()
	_magazine_size = maxi(1, int(_weapon_stats.get("magazine", 1)))
	_magazine = GameState.get_loaded_ammo()
	_update_weapon_mounts()
	_ammo_ids.clear()
	var selected_ammo := str(GameState.loadout.get("ammo", ""))
	if not selected_ammo.is_empty():
		_ammo_ids.append(selected_ammo)
	var weapon: Dictionary = Catalog.get_item(str(GameState.loadout.get("weapon", "")))
	_sound.play_event("reload")
	_notify("切换至 " + str(weapon.get("name", "武器")), 1.0)
	_emit_hud()
	return true


func get_weapon_model(slot: String = "") -> Node3D:
	return _weapon_models.get(GameState.active_weapon_slot if slot.is_empty() else slot) as Node3D


func reload_weapon() -> void:
	if not _active or _reload_left > 0.0 or _magazine >= _magazine_size:
		return
	if GameState.raid_ammo <= 0:
		_notify("备弹不足")
		return
	var ergonomics: float = float(_weapon_stats.get("ergonomics", 50.0))
	_reload_left = clampf(2.4 - ergonomics * 0.012, 1.1, 2.5)
	_sound.play_event("reload")
	_notify("正在换弹…", _reload_left)


func interact() -> void:
	if not _active or _search_left > 0.0:
		return
	var index := _nearest_container()
	if index < 0:
		_notify("")
		return
	_search_target = index
	_search_left = 1.15
	_notify("", 1.2)


func use_medkit() -> void:
	if not _active or _hp >= 100.0:
		return
	if GameState.consume_raid_medkit():
		var medical: Dictionary = GameState.get_selected_medkit()
		var healing := float(medical.get("heal", 45.0))
		_hp = minf(100.0, _hp + healing)
		_sound.play_event("heal")
		_notify("已使用%s，恢复 %d 点生命。" % [medical.get("name", "医疗包"), roundi(healing)])
		_emit_hud()
	else:
		_notify("医疗补给不足")


func get_hud() -> Dictionary:
	var weapon: Dictionary = Catalog.get_item(str(GameState.loadout.get("weapon", "")))
	var nearby := ""
	var index := _nearest_container()
	if index >= 0:
		nearby =  str(_containers[index].get("name", "物资箱"))
	elif is_instance_valid(player) and player.position.distance_to(EXIT) < 3.2:
		nearby = ""
	var objective := ""
	if _notice_left > 0.0:
		objective = _notice
	if _reload_left > 0.0:
		objective = "正在换弹  %.1f 秒" % _reload_left
	if _search_left > 0.0:
		objective = "正在搜索  %.1f 秒" % _search_left
	if _extract_progress > 0.0:
		objective = "撤离倒计时  %.1f 秒" % (EXTRACTION_DURATION - _extract_progress)
	var value := 0
	for item_id in GameState.raid_loot:
		var item: Dictionary = Catalog.get_item(str(item_id))
		value += int(item.get("sell_price", 0)) * int(GameState.raid_loot[item_id])
	var dots: Array[Dictionary] = []
	for guard in _guards:
		if float(guard["hp"]) > 0.0 and is_instance_valid(player):
			var body: CharacterBody3D = guard["body"]
			if body.position.distance_to(player.position) < 14.0:
				dots.append({"position": Vector2(body.position.x, body.position.z), "kind": "enemy"})
	for crate in _containers:
		if not bool(crate["opened"]):
			var at: Vector3 = crate["position"]
			dots.append({"position": Vector2(at.x, at.z), "kind": "loot"})
	var player_at := Vector2.ZERO
	if is_instance_valid(player):
		player_at = Vector2(player.position.x, player.position.z)
	var weapons: Array[Dictionary] = []
	for slot in WEAPON_SLOTS:
		var weapon_id := str(GameState.loadout.get(slot, ""))
		var definition: Dictionary = Catalog.get_item(weapon_id)
		var build: Dictionary = GameState.weapon_builds.get(slot, {})
		var stats: Dictionary = Catalog.weapon_stats(weapon_id, build) if not weapon_id.is_empty() else {}
		var ammo_id := str(GameState.weapon_ammo.get(slot, ""))
		weapons.append({
			"slot": slot, "id": weapon_id, "name": str(definition.get("name", "未装备")),
			"ammo": GameState.get_loaded_ammo(slot), "magazine": int(stats.get("magazine", 0)),
			"reserve": GameState.get_raid_ammo(slot), "active": slot == GameState.active_weapon_slot,
			"available": not weapon_id.is_empty(), "ammo_id": ammo_id,
			"caliber": str(definition.get("caliber", "")), "model_parts": build.size(),
		})
	return {
		"hp": ceil(_hp), "max_hp": 100, "ammo": _magazine, "magazine": _magazine_size,
		"reserve": GameState.raid_ammo, "seconds": ceili(_time_left), "objective": objective,
		"nearby": nearby, "loot_value": value, "extract_progress": _extract_progress / EXTRACTION_DURATION,
		"weapon_name": str(weapon.get("name", "未装备")), "medkits": GameState.raid_meds,
		"weight": GameState.raid_weight(), "capacity": GameState.carry_capacity(),
		"kills": _kills, "reloading": _reload_left > 0.0, "searching": _search_left > 0.0,
		"hit_marker": _hit_marker > 0.0, "player_position": player_at,
		"extraction_position": Vector2(EXIT.x, EXIT.z), "minimap": dots,
		"map_bounds": MAP_HALF * 2.0, "map_roads": _minimap_roads(), "heading": rad_to_deg(atan2(_aim_direction.x, -_aim_direction.z)),
		"extraction_distance": player_at.distance_to(Vector2(EXIT.x, EXIT.z)),
		"active_weapon_slot": GameState.active_weapon_slot, "weapons": weapons, "switching": _switch_left > 0.0,
	}


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_PAUSED]:
		_move = Vector2.ZERO
		_stick_aim = Vector2.ZERO
		_stick_firing = false


func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(player):
		return
	_time_left = maxf(0.0, _time_left - delta)
	_notice_left = maxf(0.0, _notice_left - delta)
	_hit_marker = maxf(0.0, _hit_marker - delta)
	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	_switch_left = maxf(0.0, _switch_left - delta)
	_recoil = maxf(0.0, _recoil - delta * 0.45)
	_move_player(delta)
	_update_aim()
	if _reload_left > 0.0:
		_reload_left = maxf(0.0, _reload_left - delta)
		if _reload_left <= 0.0:
			_magazine += GameState.consume_raid_ammo(_magazine_size - _magazine)
			GameState.set_raid_loaded_ammo(_magazine)
	if _stick_firing and _shot_cooldown <= 0.0 and _reload_left <= 0.0 and _search_left <= 0.0 and _switch_left <= 0.0:
		_fire_player()
	_update_guards(delta)
	_update_search(delta)
	_update_extraction(delta)
	_update_effects(delta)
	if _time_left <= 0.0:
		_finish(false, "行动超时")
	if _hp <= 0.0:
		_finish(false, "行动中失联")
	_hud_clock -= delta
	if _hud_clock <= 0.0:
		_hud_clock = 0.10
		_emit_hud()


func _process(delta: float) -> void:
	if not _active or not is_instance_valid(camera) or not is_instance_valid(player):
		return
	var wanted := _camera_focus() + CAMERA_OFFSET
	if is_instance_valid(_harbor): _harbor.update_viewer_position(player.position)
	camera.position = camera.position.lerp(wanted, 1.0 - exp(-delta * 7.0))
	camera.look_at(camera.position - CAMERA_OFFSET + Vector3(0, 0.4, 0))
	if is_instance_valid(_exit_ring):
		var pulse := 0.97 + sin(Time.get_ticks_msec() * 0.003) * 0.035
		_exit_ring.scale = Vector3(pulse, 1, pulse)


func _move_player(delta: float) -> void:
	var direction := Vector2.ZERO if _ui_blocked else _move
	var speed := WALK_SPEED
	if _reload_left > 0.0:
		speed *= 0.75
	if _search_left > 0.0 and direction.length() > 0.12:
		_search_left = 0.0
		_search_target = -1
		_notify("搜索已中断。")
	var world_direction := _screen_direction(direction)
	var fall_speed: float = player.velocity.y
	player.velocity = world_direction * speed
	player.velocity.y = -1.0 if player.is_on_floor() else maxf(fall_speed - 20.0 * delta, -30.0)
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -MAP_HALF.x+1.4, MAP_HALF.x-1.4)
	player.position.z = clampf(player.position.z, -MAP_HALF.y+1.4, MAP_HALF.y-1.4)
	if direction.length() > 0.1:
		var gait := sin(Time.get_ticks_msec() * 0.016) * 0.045
		player_model.position.y = absf(gait)
	else:
		player_model.position.y = lerpf(player_model.position.y, 0.0, delta * 10.0)


func _update_aim() -> void:
	if _stick_aim.length_squared() > 0.0001:
		var target: Vector3=_screen_direction(_stick_aim).normalized()
		var current_angle: float=atan2(_aim_direction.x,-_aim_direction.z)
		var target_angle: float=atan2(target.x,-target.z)
		var blend: float=1.0-exp(-18.0*float(AppSettings.values.aim_sensitivity)*get_physics_process_delta_time())
		var angle: float=lerp_angle(current_angle,target_angle,blend)
		_aim_direction=Vector3(sin(angle),0,-cos(angle))
	player_model.rotation.y = atan2(-_aim_direction.x, -_aim_direction.z)
	var start := _active_muzzle_position()
	if GameState.attachments.has("laser"):
		var assembly := get_weapon_model()
		if assembly != null and assembly.has_method("get_socket"):
			var laser_socket: Node3D = assembly.get_socket("laser")
			if laser_socket != null:
				start = laser_socket.global_position
	var length := 8.5 if GameState.attachments.has("laser") else 2.1
	_set_beam(aim_line, start, start + _aim_direction * length, 0.012)
	var laser_material: StandardMaterial3D = aim_line.material_override
	laser_material.albedo_color = Color(0.12, 0.9, 0.78, 0.55) if GameState.attachments.has("laser") else Color(0.27, 0.65, 0.60, 0.24)


func _fire_player() -> void:
	if _magazine <= 0:
		reload_weapon()
		_shot_cooldown = 0.20
		return
	_magazine -= 1
	GameState.set_raid_loaded_ammo(_magazine)
	_shots += 1
	_shot_cooldown = 60.0 / maxf(30.0, float(_weapon_stats.get("rpm", 550)))
	# Trace from the chest so a muzzle pushed into thin cover cannot shoot through it.
	var origin := player.position + Vector3(0, 0.94, 0)
	var muzzle_origin := _active_muzzle_position()
	var direction := _assisted_direction(origin, _aim_direction)
	var accuracy: float = float(_weapon_stats.get("accuracy", 72.0))
	if accuracy <= 1.0:
		accuracy *= 100.0
	var horizontal: float = float(_weapon_stats.get("horizontal_recoil",20.0))
	var spread := maxf(0.0035, (100.0 - accuracy) * 0.0008) + _recoil*(.45+horizontal/40.0)
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.5
	if moving:
		spread *= 1.45
	var category: String = str(Catalog.get_item(str(GameState.loadout.get("weapon", ""))).get("category", "rifle"))
	var pellets := 7 if category == "shotgun" else 1
	var ammo: Dictionary = GameState.get_selected_ammo()
	var shot: Dictionary = Catalog.shot_profile(str(GameState.loadout.get("weapon", "")), str(ammo.get("id", "")), GameState.attachments)
	var penetration := float(ammo.get("penetration", 15.0))
	if pellets > 1:
		spread = maxf(spread, 0.09)
	for pellet in range(pellets):
		var ray_direction := direction.rotated(Vector3.UP, _rng.randf_range(-spread, spread))
		var distance: float = float(shot.get("zero_damage_distance", 60.0))
		var result := _ray(origin, origin + ray_direction * distance, [player.get_rid()])
		var endpoint := origin + ray_direction * distance
		if not result.is_empty():
			endpoint = result["position"]
			var collider: Object = result["collider"]
			if collider.has_meta("guard_index"):
				var index := int(collider.get_meta("guard_index"))
				var armor := float(_guards[index].get("armor", 18.0))
				var protection := clampf((armor - penetration) / 65.0, 0.0, 0.72)
				var damage: float = Catalog.Ballistics.damage_at(shot, origin.distance_to(endpoint)) / float(pellets)
				_damage_guard(index, damage * (1.0 - protection))
			else:
				_spark(endpoint, Color("ffcb79"), 0.08)
		var tracer_start := muzzle_origin if origin.distance_to(endpoint) > 0.65 else origin
		_tracer(tracer_start, endpoint, Color("f8d893"), 0.055)
	var muzzle_item: Dictionary = Catalog.get_item(str(GameState.attachments.get("muzzle", "")))
	var muzzle_category := str(muzzle_item.get("category", ""))
	if muzzle_category not in ["suppressor", "flash_hider"]:
		_spark(muzzle_origin, Color("ffe0a0"), 0.065)
	_sound.play_shot(category, muzzle_category == "suppressor")
	_recoil = minf(0.065, _recoil + float(_weapon_stats.get("recoil", 45.0)) * 0.00014)
	var noise := float(_weapon_stats.get("noise", 25.0))
	if noise <= 2.0:
		noise *= 24.0
	else:
		noise *= 0.24
	noise = clampf(noise, 5.0, 34.0)
	for guard in _guards:
		var body: CharacterBody3D = guard["body"]
		if float(guard["hp"]) > 0 and body.position.distance_to(player.position) < noise:
			guard["alert"] = 6.0
			guard["target"] = player.position
			guard["path_clock"] = 0.0


func _assisted_direction(origin: Vector3, direction: Vector3) -> Vector3:
	var best := 0.982
	var chosen := direction
	for guard in _guards:
		if float(guard["hp"]) <= 0.0:
			continue
		var body: CharacterBody3D = guard["body"]
		var toward := body.position + Vector3(0, 0.95, 0) - origin
		toward.y = 0.0
		if toward.length() > 24.0:
			continue
		var dot := direction.dot(toward.normalized())
		if dot > best and _can_see(origin, body.position + Vector3(0, 0.95, 0), body):
			chosen = direction.lerp(toward.normalized(), 0.75).normalized()
			best = dot
	return chosen


func _update_guards(delta: float) -> void:
	for guard in _guards:
		if float(guard["hp"]) <= 0.0:
			continue
		var body: CharacterBody3D = guard["body"]
		var from := body.position + Vector3(0, 0.95, 0)
		var to := player.position + Vector3(0, 0.9, 0)
		var distance := body.position.distance_to(player.position)
		if distance > 42.0 and float(guard["alert"]) <= 0.0: continue
		var visible := _time_left < RAID_DURATION - 3.0 and distance < 12.3 and _can_see(from, to, player)
		guard["alert"] = maxf(0.0, float(guard["alert"]) - delta)
		guard["cooldown"] = maxf(0.0, float(guard["cooldown"]) - delta)
		guard["path_clock"] = float(guard["path_clock"]) - delta
		if visible:
			guard["alert"] = 5.0
			guard["target"] = player.position
		var alerted := float(guard["alert"]) > 0.0
		var target: Vector3 = guard["target"]
		if not alerted:
			var patrol: Array = guard["patrol"]
			var patrol_index := int(guard["patrol_index"])
			target = patrol[patrol_index]
			if body.position.distance_to(target) < 0.65:
				guard["patrol_index"] = (patrol_index + 1) % patrol.size()
				guard["path_clock"] = 0.0
		var direction := Vector3.ZERO
		if not (visible and distance < 8.8):
			if float(guard["path_clock"]) <= 0.0:
				guard["path"] = _navigation_path(body.position, target)
				guard["path_clock"] = 0.8 + _rng.randf() * 0.3
			var path: Array = guard["path"]
			while not path.is_empty() and body.position.distance_to(path[0]) < 0.65:
				path.pop_front()
			if not path.is_empty():
				direction = (Vector3(path[0]) - body.position).normalized()
			direction.y = 0.0
		body.velocity = direction * (2.7 if alerted else 1.2)
		body.velocity.y = -1.0
		body.move_and_slide()
		var model: Node3D = guard["model"]
		var facing := (player.position - body.position) if visible else direction
		if facing.length() > 0.1:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(-facing.x, -facing.z), minf(1.0, delta * 7.0))
		if visible and distance < 11.0 and float(guard["cooldown"]) <= 0.0:
			guard["cooldown"] = _rng.randf_range(0.85, 1.3)
			_guard_shoot(guard, from, to)
		var indicator: MeshInstance3D = guard["ring"]
		indicator.visible = alerted or distance < 6.0


func _guard_shoot(guard: Dictionary, from: Vector3, to: Vector3) -> void:
	var body: CharacterBody3D = guard["body"]
	var aimed_to := to
	if _rng.randf() < 0.15:
		aimed_to.y = player.position.y + 1.67
	var direction := (aimed_to - from).normalized().rotated(Vector3.UP, _rng.randf_range(-0.055, 0.055))
	var origin := from + direction * 0.65
	var hit := _ray(from, from + direction * 22.0, [body.get_rid()])
	var endpoint := from + direction * 22.0
	if not hit.is_empty():
		endpoint = hit["position"]
		if hit["collider"] == player:
			var headshot := endpoint.y > player.position.y + 1.5
			var incoming: float = Catalog.shot_damage("weapon_cedar545", "ammo_545x39_fmj", from.distance_to(endpoint)) * _rng.randf_range(0.47, 0.62) * (1.5 if headshot else 1.0)
			var damage: float = GameState.damage_after_armor(incoming, 18.0, headshot)
			_hp = maxf(0.0, _hp - damage)
			_sound.play_event("hit")
			_notify("受到攻击", 2.0)
			_spark(endpoint, Color("e57762"), 0.10)
	_tracer(origin, endpoint, Color("ed8e66"), 0.08)
	_spark(origin, Color("ffba79"), 0.065)
	_sound.play_shot("rifle", false, true)
	guard["target"] = player.position


func _damage_guard(index: int, damage: float) -> void:
	if index < 0 or index >= _guards.size() or float(_guards[index]["hp"]) <= 0:
		return
	var guard: Dictionary = _guards[index]
	guard["hp"] = maxf(0.0, float(guard["hp"]) - damage)
	guard["alert"] = 6.0
	guard["target"] = player.position
	if _hit_marker <= 0.0:
		_sound.play_event("hit")
	_hit_marker = 0.16
	var body: CharacterBody3D = guard["body"]
	_spark(body.position + Vector3(0, 0.9, 0), Color("ff9e71"), 0.11)
	if float(guard["hp"]) <= 0.0:
		_kills += 1
		body.collision_layer = 0
		body.collision_mask = 0
		var model: Node3D = guard["model"]
		model.rotation.z = PI * 0.5
		model.position.y = 0.20
		var ring: MeshInstance3D = guard["ring"]
		ring.visible = false
		_add_loot_container(body.position + Vector3(0.75, 0, 0.3), "守卫物资", true)
		_notify("目标倒地", 2.0)


func _update_search(delta: float) -> void:
	if _search_left <= 0.0:
		return
	if _search_target < 0 or _search_target >= _containers.size():
		_search_left = 0.0
		return
	var at: Vector3 = _containers[_search_target]["position"]
	if player.position.distance_to(at) > 2.5:
		_search_left = 0.0
		_search_target = -1
		return
	_search_left = maxf(0.0, _search_left - delta)
	if _search_left <= 0.0:
		_open_container(_search_target)
		_search_target = -1


func _open_container(index: int) -> bool:
	if index < 0 or index >= _containers.size() or bool(_containers[index]["opened"]):
		return false
	var crate: Dictionary = _containers[index]
	var contents: Dictionary = crate["contents"]
	var found: Array[String] = []
	var remaining: Dictionary = {}
	for item_id in contents:
		var quantity := int(contents[item_id])
		if GameState.add_raid_loot(str(item_id), quantity):
			var item: Dictionary = Catalog.get_item(str(item_id))
			found.append(str(item.get("name", item_id)) + (" ×%d" % quantity))
			_looted += quantity
		else:
			remaining[item_id] = quantity
	crate["contents"] = remaining
	crate["opened"] = remaining.is_empty()
	var marker: MeshInstance3D = crate["marker"]
	marker.visible = not bool(crate["opened"])
	var label: Label3D = crate["label"]
	label.text = "已搜索" if bool(crate["opened"]) else "背包已满"
	label.modulate = Color("77918f") if bool(crate["opened"]) else Color("edbd70")
	if found.is_empty():
		_notify("背包容量不足，无法装入这些物资。", 3.0)
		return false
	_notify("获得：" + "、".join(found) + (" · 仍有物资，背包已满" if not remaining.is_empty() else ""), 4.0)
	_sound.play_event("search")
	_emit_hud()
	return true


func _update_extraction(delta: float) -> void:
	var in_zone := player.position.distance_to(EXIT) < 2.5
	var stationary := Vector2(player.velocity.x, player.velocity.z).length() < 0.3
	if in_zone and stationary and _time_left < RAID_DURATION - 4.0:
		_extract_progress += delta
		if _extract_progress >= EXTRACTION_DURATION:
			_finish(true, "成功撤离")
	else:
		_extract_progress = 0.0


func _finish(extracted: bool, reason: String) -> void:
	if _finished:
		return
	_finished = true
	_active = false
	_move = Vector2.ZERO
	_stick_aim = Vector2.ZERO
	_stick_firing = false
	GameState.set_raid_loaded_ammo(_magazine)
	var details := {
		"reason": reason, "kills": _kills, "shots": _shots, "items": _looted,
		"duration": roundi(RAID_DURATION - _time_left), "remaining_magazine": _magazine,
		"location": "灰港货场", "health": roundi(_hp),
	}
	var result: Dictionary = GameState.finish_raid(extracted, details)
	_sound.play_event("extract" if extracted else "death")
	# The result UI frees this world; let its last sound finish independently.
	var finishing_sound := _sound
	remove_child(finishing_sound)
	get_tree().root.add_child(finishing_sound)
	get_tree().create_timer(1.0).timeout.connect(finishing_sound.queue_free)
	_emit_hud()
	raid_finished.emit(extracted, result)


func _collect_loot_tables() -> void:
	var selected_ammo := str(GameState.loadout.get("ammo", ""))
	for item_id in Catalog.items:
		var item: Dictionary = Catalog.items[item_id]
		match str(item.get("kind", "")):
			"loot": _loot_ids.append(str(item_id))
			"attachment":
				if float(item.get("weight", 1.0)) <= 1.5:
					_attachment_ids.append(str(item_id))
			"ammo":
				if str(item_id) == selected_ammo:
					_ammo_ids.append(str(item_id))
	if _ammo_ids.is_empty():
		for item in Catalog.by_kind("ammo"):
			_ammo_ids.append(str(item["id"]))
			break


func _minimap_roads() -> Array:
	var roads: Array = []
	if _harbor==null:return roads
	for surface:Dictionary in _harbor.layout.get("surfaces",[]):
		var dims:Array=surface.size
		if float(dims[0])>100 or float(dims[2])>100:
			roads.append({"position":Vector2(float(surface.position[0]),float(surface.position[2])),"size":Vector2(float(dims[0]),float(dims[2]))})
	return roads

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("09151f")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("7b99ae")
	settings.ambient_light_energy = 0.24
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.fog_enabled = true
	settings.fog_light_color = Color("203c50")
	settings.fog_light_energy = 0.42
	settings.fog_density = 0.009
	settings.fog_sky_affect = 0.7
	environment.environment = settings
	add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-56, -26, 0)
	moon.light_color = Color("abc1d3")
	moon.light_energy = 0.48
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 65.0
	moon.shadow_bias = 0.05
	add_child(moon)


func _build_yard() -> void:
	_harbor = load("res://scripts/harbor_map.gd").new()
	_harbor.name = "IndustrialHarbor"
	add_child(_harbor)
	_harbor.build(false)
	_obstacles.assign(_harbor.obstacles)
	_build_extraction()


func _build_extraction() -> void:
	_box(Vector3(6.7, 0.025, 6.0), EXIT + Vector3(0, 0.015, 0), _mat("244e51"))
	for x in [-3.25, 3.25]:
		_box(Vector3(0.10, 0.035, 6), EXIT + Vector3(x, 0.04, 0), _mat("4ddcc2", 1.4))
	for z in [-3.0, 3.0]:
		_box(Vector3(6.6, 0.035, 0.10), EXIT + Vector3(0, 0.04, z), _mat("4ddcc2", 1.4))
	_exit_ring = _ring(self, 2.5, EXIT + Vector3(0, 0.045, 0), _mat("46e4c5", 1.6), 0.04)
	for x in [-3.6, 3.6]:
		_box(Vector3(0.32, 2.6, 0.32), EXIT + Vector3(x, 1.3, -1.8), _mat("2b454b"))
		_box(Vector3(0.12, 1.7, 0.12), EXIT + Vector3(x, 1.6, -1.8), _mat("59f4d2", 2.5))
	_sign("撤离点 / EXFIL 01", EXIT + Vector3(0, 2.5, -1.8), 0.022, Color("79f5d6"), true)
	_light(EXIT + Vector3(0, 3, 0), Color("52ddc7"), 2.4, 8)


func _build_navigation() -> void:
	_nav = AStarGrid2D.new()
	_nav.region = Rect2i(-int(MAP_HALF.x),-int(MAP_HALF.y),int(MAP_HALF.x*2),int(MAP_HALF.y*2))
	_nav.cell_size = Vector2.ONE
	_nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_nav.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_nav.update()
	# Rasterize obstacle rectangles once, instead of checking all obstacles per cell.
	for obstacle: Rect2 in _obstacles:
		var grown: Rect2 = obstacle.grow(.55)
		var x0: int = maxi(_nav.region.position.x,floori(grown.position.x))
		var z0: int = maxi(_nav.region.position.y,floori(grown.position.y))
		var x1: int = mini(_nav.region.end.x,ceili(grown.end.x)+1)
		var z1: int = mini(_nav.region.end.y,ceili(grown.end.y)+1)
		for x: int in range(x0,x1):
			for z: int in range(z0,z1):
				if grown.has_point(Vector2(x,z)): _nav.set_point_solid(Vector2i(x,z),true)


func _navigation_path(from: Vector3, to: Vector3) -> Array:
	var start := _walkable_cell(Vector2i(roundi(from.x), roundi(from.z)))
	var end := _walkable_cell(Vector2i(roundi(to.x), roundi(to.z)))
	var result: Array = []
	for cell in _nav.get_id_path(start, end):
		result.append(Vector3(cell.x, 0, cell.y))
	return result


func _walkable_cell(cell: Vector2i) -> Vector2i:
	cell.x = clampi(cell.x, -int(MAP_HALF.x)+2, int(MAP_HALF.x)-2)
	cell.y = clampi(cell.y, -int(MAP_HALF.y)+2, int(MAP_HALF.y)-2)
	if not _nav.is_point_solid(cell):
		return cell
	for radius in range(1, 6):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var test := cell + Vector2i(x, y)
				if _nav.is_in_boundsv(test) and not _nav.is_point_solid(test):
					return test
	return Vector2i.ZERO


func _build_player() -> void:
	player = _character(entry_position, 4)
	player.name = "Raider"
	player_model = _soldier(player, Color("4d7372"), false)
	_build_carried_weapons()
	_player_ring = _ring(player, 0.58, Vector3(0, 0.045, 0), _mat("67edce", 1.8), 0.035)
	aim_line = MeshInstance3D.new()
	var beam_material := _mat("49d5b5", 1.2).duplicate() as StandardMaterial3D
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_line.material_override = beam_material
	add_child(aim_line)


func _build_guards() -> void:
	var starts := [Vector3(-4, 0, 2), Vector3(5.5, 0, -7), Vector3(-8, 0, -17.5), Vector3(15.5, 0, 8), Vector3(3, 0, -17)]
	var ends := [Vector3(-3.0, 0, 7.5), Vector3(6, 0, -14), Vector3(-15, 0, -17.5), Vector3(15.5, 0, 14), Vector3(-2, 0, -13)]
	for at: Vector3 in [Vector3(7,0,63),Vector3(-9,0,49),Vector3(-36,0,55),Vector3(56,0,55),Vector3(44,0,21),Vector3(-52,0,14),Vector3(-42,0,-19),Vector3(40,0,-37),Vector3(-22,0,-65),Vector3(20,0,-68),Vector3(-3,0,-65),Vector3(7,0,-78)]:
		starts.append(at)
		ends.append(at+Vector3(2,0,4))
	for index in range(starts.size()):
		var body := _character(starts[index], 2)
		body.name = "Guard_%02d" % index
		body.set_meta("guard_index", index)
		var model := _soldier(body, Color("7c6753"), true)
		var ring := _ring(body, 0.5, Vector3(0, 0.04, 0), _mat("df745c", 0.8), 0.026)
		ring.visible = false
		_guards.append({
			"body": body, "model": model, "ring": ring, "hp": 78.0, "armor": 22.0 + (index % 5) * 3.0,
			"alert": 0.0, "cooldown": 1.0 + index * 0.12, "path_clock": 0.0,
			"path": [], "target": Vector3(starts[index]), "patrol": [starts[index], ends[index]], "patrol_index": 1,
		})


func _build_containers() -> void:
	var records: Array = _harbor.layout.get("loot",[])
	for record: Dictionary in records:
		var point: Array = record.position
		_add_loot_container(Vector3(float(point[0]),0,float(point[2])),str(record.name),false)


func _weighted_loot_id() -> String:
	var total: float = 0.0
	for item_id: String in _loot_ids:
		total += maxf(0.0, float(Catalog.get_item(item_id).get("drop_weight", 1.0)))
	var ticket: float = _rng.randf() * total
	for item_id: String in _loot_ids:
		ticket -= maxf(0.0, float(Catalog.get_item(item_id).get("drop_weight", 1.0)))
		if ticket <= 0.0:
			return item_id
	return _loot_ids.back()


func _add_loot_container(at: Vector3, title: String, corpse: bool) -> void:
	var node := Node3D.new()
	node.position = at
	add_child(node)
	var base_size := Vector3(0.8, 0.42, 0.55) if corpse else Vector3(1.0, 0.7, 0.65)
	_visual_box(node, base_size, Vector3(0, base_size.y * 0.5, 0), _mat("555c4b") if corpse else _mat("656647"))
	_visual_box(node, Vector3(base_size.x + 0.03, 0.11, base_size.z + 0.03), Vector3(0, base_size.y, 0), _mat("929074"))
	for x in [-0.30, 0.30]:
		_visual_box(node, Vector3(0.065, base_size.y + 0.08, base_size.z + 0.05), Vector3(x, base_size.y * 0.5, 0), _mat("b6a578"))
	var marker := _ring(node, 0.9, Vector3(0, 0.035, 0), _mat("e2b76a", 1.2), 0.022)
	var label := _sign(title, at + Vector3(0, 1.35, 0), 0.013, Color("e8c483"), true)
	var contents: Dictionary = {}
	if not _loot_ids.is_empty():
		contents[_weighted_loot_id()] = 1
	if not _ammo_ids.is_empty():
		contents[_ammo_ids[0]] = _rng.randi_range(8, 20)
	if not _attachment_ids.is_empty() and (_containers.size() % 2 == 1 or corpse):
		contents[_attachment_ids[_rng.randi_range(0, _attachment_ids.size() - 1)]] = 1
	if title == "医疗补给" and Catalog.items.has("medkit_field"):
		contents["medkit_field"] = 1
	_containers.append({"node": node, "name": title, "position": at, "opened": false, "marker": marker, "label": label, "contents": contents})


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 25.0
	camera.near = 0.1
	camera.far = 100.0
	add_child(camera)
	camera.position = _camera_focus() + CAMERA_OFFSET
	camera.look_at(_camera_focus() + Vector3(0, 0.4, 0))
	camera.current = true


func _camera_focus() -> Vector3:
	return Vector3(clampf(player.position.x, -MAP_HALF.x+24, MAP_HALF.x-24), player.position.y, clampf(player.position.z - 4.5, -MAP_HALF.y+20, MAP_HALF.y-20))


func _screen_direction(value: Vector2) -> Vector3:
	# Touch sticks follow the screen, including the camera's oblique yaw.
	var right := camera.basis.x
	var down := camera.basis.z
	right.y = 0.0
	down.y = 0.0
	return (right.normalized() * value.x + down.normalized() * value.y).limit_length(1.0)


func _character(at: Vector3, layer: int) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.position = at
	body.collision_layer = layer
	body.collision_mask = 7
	body.floor_snap_length = 0.25
	body.floor_stop_on_slope = true
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.86 if layer==4 else 1.55
	shape.shape = capsule
	shape.position.y = .94 if layer==4 else .78
	body.add_child(shape)
	add_child(body)
	return body


func _soldier(parent: Node3D, color: Color, guard: bool) -> Node3D:
	if not guard:
		var operator: Node3D = load("res://scripts/operator_model.gd").new()
		parent.add_child(operator)
		operator.set_equipment(GameState.loadout)
		return operator

	var model := Node3D.new()
	parent.add_child(model)
	var cloth := _color_mat(color)
	var armor := _mat("263b3e") if not guard else _mat("46483c")
	_visual_box(model, Vector3(0.53, 0.62, 0.33), Vector3(0, 0.93, 0), cloth)
	_visual_box(model, Vector3(0.57, 0.43, 0.12), Vector3(0, 0.99, -0.20), armor)
	_visual_box(model, Vector3(0.42, 0.5, 0.21), Vector3(0, 0.92, 0.25), _mat("394846"))
	_visual_box(model, Vector3(0.18, 0.52, 0.23), Vector3(-0.16, 0.34, 0.03), _mat("334144"))
	_visual_box(model, Vector3(0.18, 0.52, 0.23), Vector3(0.16, 0.34, -0.06), _mat("334144"))
	_visual_box(model, Vector3(0.19, 0.13, 0.34), Vector3(-0.16, 0.10, -0.035), _mat("17272c"))
	_visual_box(model, Vector3(0.19, 0.13, 0.34), Vector3(0.16, 0.10, -0.12), _mat("17272c"))
	_visual_box(model, Vector3(0.17, 0.40, 0.20), Vector3(-0.33, 0.98, -0.11), cloth)
	_visual_box(model, Vector3(0.17, 0.37, 0.20), Vector3(0.33, 0.98, -0.15), cloth)
	_visual_box(model, Vector3(0.185, 0.10, 0.22), Vector3(-0.33, 1.05, -0.11), _mat("e3b663") if not guard else _mat("a75d48"))
	var helmet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.255
	sphere.height = 0.42
	sphere.radial_segments = 12
	sphere.rings = 6
	helmet.mesh = sphere
	helmet.material_override = armor
	helmet.position.y = 1.43
	model.add_child(helmet)
	_visual_box(model, Vector3(0.34, 0.12, 0.10), Vector3(0, 1.40, -0.22), _mat("2c555e") if not guard else _mat("706d59"))
	if guard:
		_visual_box(model, Vector3(0.15, 0.15, 0.75), Vector3(0.24, 1.04, -0.52), _mat("202d31"))
		_visual_box(model, Vector3(0.07, 0.075, 0.45), Vector3(0.24, 1.08, -0.97), _mat("111d22"))
		_visual_box(model, Vector3(0.10, 0.26, 0.15), Vector3(0.24, 0.87, -0.44), _mat("1a2528"))
	return model


func _build_carried_weapons() -> void:
	for slot in WEAPON_SLOTS:
		var weapon_id := str(GameState.loadout.get(slot, ""))
		if weapon_id.is_empty():
			continue
		var mount := Node3D.new()
		mount.name = "WeaponMount_" + slot
		player_model.add_child(mount)
		_weapon_mounts[slot] = mount
		if ResourceLoader.exists("res://scripts/weapon_assembly.gd"):
			var assembly: Node3D = load("res://scripts/weapon_assembly.gd").new()
			assembly.name = "Assembly_" + slot
			mount.add_child(assembly)
			if assembly.set_build(weapon_id, GameState.weapon_builds.get(slot, {})):
				_weapon_models[slot] = assembly
				continue
			mount.remove_child(assembly)
			assembly.queue_free()
		# Only used while authored assets are still being imported by the editor.
		var fallback := Node3D.new()
		fallback.name = "PendingModelImport"
		mount.add_child(fallback)
		_visual_box(fallback, Vector3(0.08, 0.11, 0.45), Vector3(0, 0, -0.1), _mat("26383b"))
		_weapon_models[slot] = fallback
	_update_weapon_mounts()


func _update_weapon_mounts() -> void:
	for slot in _weapon_mounts:
		var mount: Node3D = _weapon_mounts[slot]
		if str(slot) == GameState.active_weapon_slot:
			mount.position = Vector3(0.22, 1.05, -0.32)
			mount.rotation = Vector3.ZERO
		elif str(slot) == "sidearm":
			mount.position = Vector3(0.34, 0.62, 0.10)
			mount.rotation = Vector3(-PI * 0.5, 0, 0)
		else:
			var left := str(slot) == "primary"
			mount.position = Vector3(-0.30 if left else 0.30, 0.83, 0.43)
			mount.rotation = Vector3(PI * 0.5, 0, -0.18 if left else 0.18)


func _active_muzzle_position() -> Vector3:
	var assembly := get_weapon_model()
	if assembly != null and assembly.has_method("get_socket"):
		var socket: Node3D = assembly.get_socket("muzzle")
		if socket != null:
			return socket.global_position
	return player.position + Vector3(0, 1.05, 0) + _aim_direction * 0.65


func _container(at: Vector3, color: Color, yaw: float, serial: String) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.3, 2.65, 2.8)
	collision.shape = shape
	collision.position.y = 1.325
	body.add_child(collision)
	_visual_box(root, shape.size, Vector3(0, 1.325, 0), _color_mat(color))
	var ribs := _color_mat(color.lightened(0.12))
	var side_ribs: Array[Vector3] = []
	var roof_ribs: Array[Vector3] = []
	for x in range(16):
		var px := -3.43 + x * 0.457
		side_ribs.append(Vector3(px, 1.33, 1.43))
		side_ribs.append(Vector3(px, 1.33, -1.43))
		roof_ribs.append(Vector3(px, 2.71, 0))
	_instanced_boxes(root, Vector3(0.075, 2.35, 0.065), side_ribs, ribs)
	_instanced_boxes(root, Vector3(0.055, 0.035, 2.5), roof_ribs, ribs)
	for y in [0.12, 2.55]:
		_visual_box(root, Vector3(7.45, 0.12, 2.95), Vector3(0, y, 0), _color_mat(color.darkened(0.18)))
	_visual_box(root, Vector3(7.0, 0.035, 2.5), Vector3(0, 2.68, 0), _color_mat(color.lightened(0.05)))
	for x in [-3.69, 3.69]:
		_visual_box(root, Vector3(0.035, 2.3, 0.05), Vector3(x, 1.3, 0), _mat("89948d"))
	var label := _sign(serial, Vector3.ZERO, 0.020, Color("c0c8bb"), false)
	remove_child(label)
	root.add_child(label)
	label.position = Vector3(1.8, 1.7, 1.47)
	label.rotation = Vector3.ZERO
	var size := Vector2(7.3, 2.8) if absf(yaw) < 0.1 else Vector2(2.8, 7.3)
	_obstacles.append(Rect2(Vector2(at.x, at.z) - size * 0.5, size))


func _warehouse(at: Vector3, size: Vector3, title: String) -> void:
	_box(size, at + Vector3(0, size.y * 0.5, 0), _mat("33464c"), true)
	for z in range(-int(size.z * 0.5) + 1, int(size.z * 0.5), 3):
		var inward := 1.0 if at.x < 0 else -1.0
		var face := at + Vector3(inward * (size.x * 0.5 + 0.035), 2.65, z)
		_box(Vector3(0.06, 1.0, 1.9), face, _mat("386875", 0.25))
	_box(Vector3(size.x + 0.35, 0.28, size.z + 0.4), at + Vector3(0, size.y + 0.1, 0), _mat("263c43"))
	_sign(title, at + Vector3(0, size.y + 0.55, 0), 0.017, Color("90b1b7"), true)


func _barricade(at: Vector3) -> void:
	_box(Vector3(2.6, 0.8, 0.65), at + Vector3(0, 0.4, 0), _mat("7b806f"), true)
	for x in [-0.9, -0.3, 0.3, 0.9]:
		var stripe := _box(Vector3(0.24, 0.55, 0.018), at + Vector3(x, 0.46, 0.335), _mat("d0ae61"))
		stripe.rotation.z = -0.25


func _pallet(at: Vector3) -> void:
	for z in [-0.4, 0, 0.4]:
		_box(Vector3(1.7, 0.1, 0.27), at + Vector3(0, 0.12, z), _mat("827760"))
	_box(Vector3(1.25, 1.0, 0.95), at + Vector3(0, 0.72, 0), _mat("6d725a"), true)
	_box(Vector3(0.09, 1.04, 0.99), at + Vector3(-0.4, 0.72, 0), _mat("b29e72"))
	_box(Vector3(0.09, 1.04, 0.99), at + Vector3(0.4, 0.72, 0), _mat("b29e72"))


func _barrel(at: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.3
	cylinder.bottom_radius = 0.3
	cylinder.height = 0.85
	cylinder.radial_segments = 10
	mesh.mesh = cylinder
	mesh.material_override = _mat("79564a")
	mesh.position = at + Vector3(0, 0.43, 0)
	add_child(mesh)
	for y in [0.16, 0.67]:
		_ring(self, 0.31, at + Vector3(0, y, 0), _mat("7f8b78"), 0.022)


func _lamp(at: Vector3, color: Color, energy: float) -> void:
	_box(Vector3(0.15, 4.4, 0.15), at + Vector3(0, 2.2, 0), _mat("35494d"))
	_box(Vector3(0.95, 0.10, 0.32), at + Vector3(0.36, 4.38, 0), _mat("273d41"))
	_box(Vector3(0.55, 0.035, 0.25), at + Vector3(0.38, 4.31, 0), _color_mat(color, 3.0))
	_light(at + Vector3(0.4, 3.7, 0), color, energy, 10.5)
	# The visible pool makes the navigation space legible even on low-end GPUs.
	var pool_material := StandardMaterial3D.new()
	pool_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.12))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var fade := GradientTexture2D.new()
	fade.width = 64
	fade.height = 64
	fade.gradient = gradient
	fade.fill = GradientTexture2D.FILL_RADIAL
	fade.fill_from = Vector2(0.5, 0.5)
	fade.fill_to = Vector2(0.5, 1.0)
	pool_material.albedo_texture = fade
	var disk := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.5, 8.5)
	disk.mesh = plane
	disk.material_override = pool_material
	disk.position = at + Vector3(0.4, 0.022, 0)
	add_child(disk)


func _light(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	add_child(light)


func _box(size: Vector3, at: Vector3, material: StandardMaterial3D, collision: bool = false, obstacle: bool = true) -> Node3D:
	if not collision:
		return _visual_box(self, size, at, material)
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_visual_box(body, size, Vector3.ZERO, material)
	add_child(body)
	if obstacle:
		_obstacles.append(Rect2(Vector2(at.x - size.x * 0.5, at.z - size.z * 0.5), Vector2(size.x, size.z)))
	return body


func _visual_box(parent: Node3D, size: Vector3, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _instanced_boxes(parent: Node3D, size: Vector3, positions: Array[Vector3], material: StandardMaterial3D) -> void:
	# Corrugated steel is repeated geometry: two instanced draws per container.
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = positions.size()
	for index in range(positions.size()):
		batch.set_instance_transform(index, Transform3D(Basis.IDENTITY, positions[index]))
	var node := MultiMeshInstance3D.new()
	node.multimesh = batch
	parent.add_child(node)


func _ring(parent: Node3D, radius: float, at: Vector3, material: StandardMaterial3D, thickness: float = 0.04) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius
	mesh.rings = 24
	mesh.ring_segments = 6
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _sign(text: String, at: Vector3, pixel_size: float, color: Color, billboard: bool, floor_text: bool = false) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = _font
	label.font_size = 32
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 4
	label.outline_modulate = Color(0.04, 0.09, 0.11, 0.8)
	label.no_depth_test = false
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	if floor_text:
		label.rotation.x = -PI * 0.5
	add_child(label)
	return label


func _mat(hex: String, glow: float = 0.0) -> StandardMaterial3D:
	return _color_mat(Color(hex), glow)


func _color_mat(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := color.to_html() + ":" + str(glow)
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if glow > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	_materials[key] = material
	return material


func _ray(from: Vector3, to: Vector3, excludes: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 7, excludes)
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query)


func _can_see(from: Vector3, to: Vector3, target: CollisionObject3D) -> bool:
	# Only scenery and the intended target obstruct sight; other guards do not.
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | target.collision_layer)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target


func _nearest_container() -> int:
	if not is_instance_valid(player):
		return -1
	var chosen := -1
	var nearest := 2.25
	for index in range(_containers.size()):
		var crate: Dictionary = _containers[index]
		if bool(crate["opened"]):
			continue
		var at: Vector3 = crate["position"]
		var distance := player.position.distance_to(at)
		if distance < nearest:
			chosen = index
			nearest = distance
	return chosen


func _tracer(from: Vector3, to: Vector3, color: Color, lifetime: float) -> void:
	var node := MeshInstance3D.new()
	node.material_override = _color_mat(color, 2.0)
	add_child(node)
	_set_beam(node, from, to, 0.018)
	_effects.append({"node": node, "ttl": lifetime})


func _set_beam(node: MeshInstance3D, from: Vector3, to: Vector3, radius: float) -> void:
	var difference := to - from
	if difference.length() < 0.001:
		node.visible = false
		return
	var mesh: CylinderMesh = node.mesh as CylinderMesh
	if mesh == null:
		mesh = CylinderMesh.new()
		mesh.radial_segments = 4
		node.mesh = mesh
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = difference.length()
	node.position = (from + to) * 0.5
	node.quaternion = Quaternion(Vector3.UP, difference.normalized())
	node.visible = true


func _spark(at: Vector3, color: Color, lifetime: float) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	mesh.radial_segments = 6
	mesh.rings = 3
	node.mesh = mesh
	node.material_override = _color_mat(color, 2.5)
	node.position = at
	add_child(node)
	_effects.append({"node": node, "ttl": lifetime})


func _update_effects(delta: float) -> void:
	for index in range(_effects.size() - 1, -1, -1):
		_effects[index]["ttl"] = float(_effects[index]["ttl"]) - delta
		if float(_effects[index]["ttl"]) <= 0.0:
			var node: Node = _effects[index]["node"]
			node.queue_free()
			_effects.remove_at(index)


func _notify(message: String, duration: float = 2.5) -> void:
	_notice = message
	_notice_left = duration


func _emit_hud() -> void:
	hud_changed.emit(get_hud())


func debug_test_scenario() -> Dictionary:
	## Deterministic smoke exercised by tests after start_raid and one physics frame.
	## Uses live search, collision, actual ammo consumption, actual hit resolution and the exit timer.
	var result: Dictionary = {"world_active": _active, "guards": _guards.size(), "crates": _containers.size()}
	if not _active:
		return result
	var old_hp := _hp
	var old_player := player.position
	var crate_at: Vector3 = _containers[0]["position"]
	player.position = crate_at + Vector3(1.0, 0, 0)
	interact()
	_update_search(1.2)
	result["loot_search"] = bool(_containers[0]["opened"]) or not GameState.raid_loot.is_empty()
	var guard: Dictionary = _guards[0]
	var body: CharacterBody3D = guard["body"]
	var old_guard := body.position
	player.position = Vector3(0, 0, 19)
	body.position = Vector3(0, 0, 15.5)
	_aim_direction = Vector3.FORWARD
	var before_hp := float(guard["hp"])
	var before_mag := _magazine
	_fire_player()
	result["shot_consumes_round"] = _magazine == before_mag - 1
	result["raycast_hits_guard"] = float(guard["hp"]) < before_hp
	result["damage_applied"] = before_hp - float(guard["hp"])
	body.position = old_guard
	player.position = old_player
	_hp = old_hp
	result["exit_is_far_from_spawn"] = SPAWN.distance_to(EXIT) > 35.0
	result["normal_extraction_required"] = _extract_progress == 0.0 and _active
	result["path_to_exit"] = not _navigation_path(SPAWN, EXIT).is_empty()
	return result
