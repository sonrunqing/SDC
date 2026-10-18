extends Node3D
## A compact, fully simulated single-player extraction raid. All distances are metres.

signal hud_changed(info: Dictionary)
signal raid_finished(extracted: bool, details: Dictionary)
signal container_opened(index: int)
signal container_closed(reason: String)
const ContainerState=preload("res://scripts/loot_container_state.gd")

const MAP_HALF := Vector2(80.0, 90.0)
const SPAWN := Vector3(0.0, 0.0, 78.0)
const EXIT := Vector3(0.0, 0.0, -77.0)
const RAID_DURATION := 900.0
const EXTRACTION_DURATION := 5.0
const WALK_SPEED := 5.3
const Look = preload("res://scripts/visual_profile.gd")
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
var _fx: Node3D
var _presentation: Control
var _focus:=Vector3.ZERO
var _trauma: float=0
var _shake_noise:=FastNoiseLite.new()
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
var _marker_clock: float=0
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
	close_container()
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
	_build_containers()
	_build_navigation()
	_build_player()
	_build_guards()
	_build_camera()
	_fx=preload("res://scripts/raid_fx.gd").new()
	add_child(_fx)
	var presentation_layer:=CanvasLayer.new()
	presentation_layer.layer=1
	add_child(presentation_layer)
	_presentation=preload("res://scripts/raid_presentation.gd").new()
	_presentation.world=self
	presentation_layer.add_child(_presentation)
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
	if not _active or _ui_blocked or _search_target>=0:return
	var index: int=_nearest_container()
	if index>=0:_open_container(index)


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
			if body.position.distance_to(player.position) < 14.0 and bool(guard.get("seen",false)):
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
		close_container("搜索已中断")
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
	_update_container_markers(delta)
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
	var desired := _camera_focus()
	if is_instance_valid(_harbor): _harbor.update_viewer_position(player.position)
	_focus.x=lerpf(_focus.x,desired.x,1-exp(-delta*11))
	_focus.z=lerpf(_focus.z,desired.z,1-exp(-delta*11))
	_focus.y=lerpf(_focus.y,desired.y,1-exp(-delta*4.5))
	_trauma=maxf(0,_trauma-delta*1.9)
	var shake: float=_trauma*_trauma*float(AppSettings.values.camera_shake)
	var time: float=Time.get_ticks_msec()*.024
	camera.position=_focus+Vector3(0,float(AppSettings.values.camera_height),float(AppSettings.values.camera_height)/tan(deg_to_rad(float(AppSettings.values.camera_pitch))))
	camera.rotation=Vector3(-deg_to_rad(float(AppSettings.values.camera_pitch))+deg_to_rad(_shake_noise.get_noise_2d(31,time)*shake*1.2),0,deg_to_rad(_shake_noise.get_noise_2d(68,time)*shake*2.4))
	camera.fov=float(AppSettings.values.camera_fov)
	_update_weapon_pose()
	if player_model.has_method("tick_visual"):player_model.tick_visual(player.velocity,_stick_aim.length()>.15 or _stick_firing,delta)
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
	# The skeleton supplies gait; keep attached equipment at the actor's origin.


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
		_fx.muzzle(muzzle_origin,direction,true)
	else:_fx.muzzle(muzzle_origin,direction,true,false)
	_trauma=minf(.55,_trauma+.07)
	if player_model.has_method("shot"):player_model.shot()
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
		if model.has_method("tick_visual"):model.tick_visual(body.velocity,visible,delta)
		var facing := (player.position - body.position) if visible else direction
		if facing.length() > 0.1:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(-facing.x, -facing.z), minf(1.0, delta * 7.0))
		if visible and distance < 11.0 and float(guard["cooldown"]) <= 0.0:
			guard["cooldown"] = _rng.randf_range(0.85, 1.3)
			_guard_shoot(guard, from, to)
		var indicator: MeshInstance3D = guard["ring"]
		indicator.visible = bool(guard.get("seen",false)) and (alerted or distance < 6.0)


func _guard_shoot(guard: Dictionary, from: Vector3, to: Vector3) -> void:
	var body: CharacterBody3D = guard["body"]
	var aimed_to := to
	if _rng.randf() < 0.15:
		aimed_to.y = player.position.y + 1.67
	var direction := (aimed_to - from).normalized().rotated(Vector3.UP, _rng.randf_range(-0.055, 0.055))
	var origin := from + direction * 0.65
	var guard_model: Node3D=guard.model
	if guard_model.has_meta("guard_weapon"):
		var rifle: Node3D=guard_model.get_meta("guard_weapon")
		var muzzle_point: Node3D=rifle.find_child("MuzzlePoint",true,false)
		if muzzle_point!=null:origin=muzzle_point.global_position
	var hit := _ray(from, from + direction * 22.0, [body.get_rid()])
	var endpoint := from + direction * 22.0
	if not hit.is_empty():
		endpoint = hit["position"]
		if hit["collider"] == player:
			var headshot := endpoint.y > player.position.y + 1.5
			var incoming: float = Catalog.shot_damage("weapon_cedar545", "ammo_545x39_fmj", from.distance_to(endpoint)) * _rng.randf_range(0.47, 0.62) * (1.5 if headshot else 1.0)
			var damage: float = GameState.damage_after_armor(incoming, 18.0, headshot)
			_hp = maxf(0.0, _hp - damage)
			close_container("受到攻击，搜索已中断")
			_presentation.hurt(from)
			_trauma=minf(.85,_trauma+.35)
			_sound.play_event("hit")
			_notify("受到攻击", 2.0)
			_spark(endpoint, Color("e57762"), 0.10)
	_tracer(origin, endpoint, Color("ed8e66"), 0.08)
	_fx.muzzle(origin,direction,false)
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
	if guard.model.has_method("flinch"):guard.model.flinch()
	var killed: bool=float(guard["hp"])<=0
	_presentation.hit(body.position+Vector3(0,1.0,0),damage,killed)
	_trauma=minf(.65,maxf(_trauma,.30 if killed else .12))
	if float(guard["hp"]) <= 0.0:
		_kills += 1
		body.collision_layer = 0
		body.collision_mask = 0
		var model: Node3D = guard["model"]
		model.visible=true
		if model.has_method("die"):model.die()
		var ring: MeshInstance3D = guard["ring"]
		ring.visible = false
		_add_loot_container(body.position + Vector3(0.75, 0, 0.3), "守卫物资", true)
		_notify("目标倒地", 2.0)


func _can_access_container(index: int) -> bool:
	if index<0 or index>=_containers.size() or not is_instance_valid(player):return false
	var crate: Dictionary=_containers[index]
	var at: Vector3=crate.position
	if Vector2(player.position.x-at.x,player.position.z-at.z).length()>2.5:return false
	var query:=PhysicsRayQueryParameters3D.create(player.position+Vector3(0,.95,0),at+Vector3(0,.4,0),1,[player.get_rid(),crate.body.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _update_search(delta: float) -> void:
	if _search_target<0:return
	if not _active or not _can_access_container(_search_target):
		close_container("已离开容器，搜索中断")
		return
	var crate: Dictionary=_containers[_search_target]
	var revealed: int=ContainerState.advance(crate.search,delta)
	var current: Dictionary=ContainerState.current(crate.search)
	_search_left=float(crate.search.opening)+(ContainerState.duration(current)-float(crate.search.elapsed) if not current.is_empty() else 0.0)
	if revealed>0:_sound.play_event("search")

func _open_container(index: int) -> bool:
	if not _active or not _can_access_container(index) or _search_target>=0:return false
	var crate: Dictionary=_containers[index]
	if bool(crate.opened):return false
	_search_target=index
	crate.search.paused=false
	set_input_blocked(true)
	_search_left=maxf(.01,float(crate.search.opening))
	var lid: Node3D=crate.lid
	create_tween().tween_property(lid,"rotation:x",deg_to_rad(102),.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	container_opened.emit(index)
	_emit_hud()
	return true

func close_container(reason: String = "") -> void:
	if _search_target<0:return
	var index: int=_search_target
	_search_target=-1
	_search_left=0
	if index<_containers.size():
		var lid: Node3D=_containers[index].lid
		if is_instance_valid(lid):create_tween().tween_property(lid,"rotation:x",0.0,.25)
	set_input_blocked(false)
	container_closed.emit(reason)

func toggle_container_search() -> void:
	if _search_target>=0:_containers[_search_target].search.paused=not bool(_containers[_search_target].search.paused)

func get_container_snapshot() -> Dictionary:
	if _search_target<0:return {}
	var crate: Dictionary=_containers[_search_target]
	var snapshot: Dictionary=ContainerState.snapshot(crate.search)
	snapshot.name=crate.name
	snapshot.index=_search_target
	snapshot.kind=crate.kind
	return snapshot

func take_container_item(uid: String,quantity: int,destination: String = "",block: String = "",cell: Vector2i = Vector2i(-1,-1)) -> bool:
	if not _active or _search_target<0 or not _can_access_container(_search_target):return GameState._fail("已离开容器")
	var crate: Dictionary=_containers[_search_target]
	var record: Dictionary=GameState.Grid.find_record(crate.search.records,uid)
	if record.is_empty() or not bool(record.discovered) or quantity<1 or quantity>int(record.qty):
		return GameState._fail("物品尚未搜索或数量已更新")
	if not GameState.receive_container_item(str(record.item),quantity,destination,block,cell):return false
	record.qty=int(record.qty)-quantity
	crate.contents=ContainerState.remaining(crate.search)
	crate.opened=crate.contents.is_empty()
	crate.marker.visible=false
	crate.label.text="空容器" if bool(crate.opened) else str(crate.name)+" · 已搜索"
	_looted+=quantity
	_sound.play_event("search")
	_emit_hud()
	return true

func put_container_item(uid: String,quantity: int,cell: Vector2i = Vector2i(-1,-1)) -> bool:
	if not _active or _search_target<0 or not _can_access_container(_search_target):return GameState._fail("已离开容器")
	var record: Dictionary=GameState.Grid.find_record(GameState.raid_grid_items,uid)
	if record.is_empty():return GameState._fail("携行物品已更新")
	var crate: Dictionary=_containers[_search_target]
	var proposed: Dictionary=ContainerState.plan_deposit(crate.search,record,quantity,cell)
	if proposed.is_empty():return GameState._fail("容器没有合适的格子，物品仍在身上")
	if not GameState.release_raid_item(uid,quantity):return false
	crate.search=proposed
	crate.contents=ContainerState.remaining(proposed)
	crate.opened=false
	crate.label.text=str(crate.name)+" · 已搜索"
	_sound.play_event("search")
	_emit_hud()
	return true

func move_container_item(uid: String,cell: Vector2i) -> bool:
	if not _active or _search_target<0 or not _can_access_container(_search_target):return GameState._fail("已离开容器")
	var state: Dictionary=_containers[_search_target].search
	var record: Dictionary=GameState.Grid.find_record(state.records,uid)
	if record.is_empty() or int(record.qty)<=0 or not bool(record.discovered):return GameState._fail("物品尚未完成搜索")
	var spot: Dictionary=ContainerState.find_spot(record,state.records,int(state.columns),int(state.rows),cell)
	if spot.is_empty():return GameState._fail("容器没有合适的格子")
	GameState.Grid.apply_spot(record,spot)
	GameState.last_error=""
	return true

func _update_container_markers(delta: float) -> void:
	_marker_clock-=delta
	if _marker_clock>0:return
	_marker_clock=.15
	for index: int in range(_containers.size()):
		var crate: Dictionary=_containers[index]
		var nearby: bool=not bool(crate.opened) and player.position.distance_to(crate.position)<3.0
		crate.label.visible=nearby and _can_access_container(index)
		crate.marker.visible=nearby and crate.label.visible and _search_target!=index


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
	close_container()
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
	add_child(Look.environment())
	add_child(Look.moon())


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
	var self_light:=OmniLight3D.new()
	self_light.position=Vector3(0,1.6,0)
	self_light.light_color=Color(.72,.82,1.0)
	self_light.light_energy=1.5
	self_light.omni_range=6
	self_light.shadow_enabled=false
	player.add_child(self_light)
	var vision:=SpotLight3D.new()
	vision.position=Vector3(0,12,0)
	vision.rotation_degrees=Vector3(-50,0,0)
	vision.light_color=Color(.95,.94,.90)
	vision.light_energy=.8
	vision.spot_range=42
	vision.spot_angle=65
	vision.spot_angle_attenuation=.55
	vision.spot_attenuation=.35
	vision.shadow_enabled=false
	player_model.add_child(vision)
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
		_add_loot_container(Vector3(float(point[0]),float(point[1]),float(point[2])),str(record.name),false,record)


func _weighted_loot_id(candidates: Array = []) -> String:
	var pool: Array=_loot_ids if candidates.is_empty() else candidates
	var total: float = 0.0
	for item_id: String in pool:
		total += maxf(0.0, float(Catalog.get_item(item_id).get("drop_weight", 1.0)))
	var ticket: float = _rng.randf() * total
	for item_id: String in pool:
		ticket -= maxf(0.0, float(Catalog.get_item(item_id).get("drop_weight", 1.0)))
		if ticket <= 0.0:
			return item_id
	return str(pool.back())


func _add_loot_container(at: Vector3,title: String,corpse: bool,options: Dictionary = {}) -> void:
	var kind: String=str(options.get("kind","duffel" if corpse else "supply"))
	var node:=Node3D.new()
	node.name="SearchContainer_%02d"%_containers.size()
	node.position=at
	node.rotation_degrees.y=float(options.get("rotation",0))
	add_child(node)
	var dims:=Vector3(.9,.55,.65)
	if kind=="weapon":dims=Vector3(1.2,.34,.6)
	elif kind in ["tool","medical","archive"]:dims=Vector3(.74,.42,.52)
	elif corpse:dims=Vector3(.85,.30,.5)
	var tint: String=str({"supply":"485650","tool":"526272","medical":"dedaca","archive":"716449","weapon":"334545","duffel":"4c5143"}.get(kind,"485650"))
	_visual_box(node,dims,Vector3(0,dims.y*.5,0),_mat(tint))
	for x: float in [-dims.x*.4,dims.x*.4]:
		_visual_box(node,Vector3(.06,dims.y,dims.z+.012),Vector3(x,dims.y*.5,0),_mat("293435"))
	var lid:=Node3D.new()
	lid.position=Vector3(0,dims.y,dims.z*.5)
	node.add_child(lid)
	_visual_box(lid,Vector3(dims.x+.025,.065,dims.z+.025),Vector3(0,.025,-dims.z*.5),_mat(tint))
	_visual_box(lid,Vector3(.13,.07,.12),Vector3(0,.025,-dims.z-.01),_mat("b1aaa0"))
	if kind=="medical":
		_visual_box(lid,Vector3(.34,.012,.10),Vector3(0,.063,-dims.z*.5),_mat("963e3a"))
		_visual_box(lid,Vector3(.1,.012,.32),Vector3(0,.065,-dims.z*.5),_mat("963e3a"))
	var body:=StaticBody3D.new()
	body.collision_layer=0 if corpse else 1
	node.add_child(body)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=dims
	shape.shape=box
	shape.position.y=dims.y*.5
	body.add_child(shape)
	if not corpse:
		var flat:=Vector2(dims.x,dims.z)
		if int(absf(node.rotation_degrees.y))%180==90:flat=Vector2(flat.y,flat.x)
		_obstacles.append(Rect2(Vector2(at.x,at.z)-flat*.5,flat))
	var marker:=_ring(node,.65,Vector3(0,.035,0),_mat("a7b6a7",.1),.015)
	marker.visible=false
	var label:=_sign(title,at+Vector3(0,dims.y+.35,0),.012,Color("d8dccf"),true)
	label.visible=false
	var contents: Dictionary={}
	var profiles: Dictionary={"tool":["industrial","metals","tools"],"medical":["medical"],"archive":["collectibles"],"electronics":["electronics","precision"]}
	var groups: Array=profiles.get(kind,[])
	var pool: Array=[]
	if not groups.is_empty():
		for id: String in _loot_ids:
			if str(Catalog.get_item(id).get("loot_category","")) in groups:pool.append(id)
	for attempt: int in range(2 if not corpse else 1):
		var id: String=_weighted_loot_id(pool)
		# Retain the previous medical crate's 50% healing-supply roll, alongside
		# the new medical valuables rather than diluting medicine with more IDs.
		if kind=="medical" and _rng.randf()<.5:id="medkit_field"
		if Catalog.items.has(id):contents[id]=int(contents.get(id,0))+1
	if not _ammo_ids.is_empty() and kind not in ["medical","archive"]:contents[_ammo_ids[0]]=_rng.randi_range(8,24)
	if not _attachment_ids.is_empty() and kind in ["tool","weapon","supply","duffel"]:
		var id: String=str(_attachment_ids[_rng.randi_range(0,_attachment_ids.size()-1)])
		contents[id]=int(contents.get(id,0))+1
	var search: Dictionary=ContainerState.prepare(contents,str(_containers.size()),4 if kind in ["tool","medical","archive"] else 6,4)
	_containers.append({"node":node,"body":body,"lid":lid,"name":title,"position":at,"kind":kind,"opened":false,"marker":marker,"label":label,"contents":contents,"search":search,"building":str(options.get("building",""))})


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov=Look.CAMERA_FOV
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.near = 0.15
	camera.far = 250.0
	add_child(camera)
	_focus=_camera_focus()
	camera.position=_focus+Look.offset()
	camera.rotation_degrees=Vector3(-Look.CAMERA_PITCH,0,0)
	camera.current = true

func _camera_focus() -> Vector3:
	var lead: Vector3=_aim_direction*(2.5 if _stick_aim.length()>.15 else 1.2)
	return player.position+lead+Vector3(0,.4,0)


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


func _soldier(parent: Node3D, _color: Color, guard: bool) -> Node3D:
	var model: Node3D=preload("res://scripts/operator_model.gd").new()
	if guard:model.body_asset="res://assets/ashfront/"+("sniper" if int(parent.get_meta("guard_index",0))%3==0 else "rusher")+".glb"
	parent.add_child(model)
	if not guard:
		model.set_equipment(GameState.loadout)
	else:
		model.set_equipment({})
		var rifle: Node3D=load("res://assets/ashfront/guard_rifle.glb").instantiate()
		rifle.position=Vector3(.22,1.15,-.32)
		rifle.scale=Vector3(.9,.9,.9)
		model.add_child(rifle)
		model.set_meta("guard_weapon",rifle)
		model.bind_weapon(rifle,null)
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
		mount.set_meta("visual_rest",mount.transform)
	var active: String=GameState.active_weapon_slot
	if _weapon_mounts.has(active):player_model.bind_weapon(_weapon_mounts[active],get_weapon_model())

func _update_weapon_pose() -> void:
	if not is_instance_valid(player_model) or not player_model.has_method("bone_delta"):return
	var chest: Transform3D=player_model.bone_delta("Chest")
	for mount: Node3D in _weapon_mounts.values():
		if mount==player_model._held:continue
		mount.transform=chest*Transform3D(mount.get_meta("visual_rest",Transform3D.IDENTITY))


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
		if distance < nearest and _can_access_container(index):
			chosen = index
			nearest = distance
	return chosen


func _tracer(from: Vector3, to: Vector3, color: Color, lifetime: float) -> void:
	if is_instance_valid(_fx):_fx.tracer(from,to,color,lifetime)


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
	if is_instance_valid(_fx):_fx.impact(at,color,lifetime)


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
	var approach: Array=_navigation_path(SPAWN,crate_at)
	player.position=approach[-1]
	_open_container(0)
	_update_search(20)
	result["loot_search"]=bool(get_container_snapshot().get("complete",false))
	close_container()
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
