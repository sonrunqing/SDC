extends SceneTree
## Independent geometry, live swapping, orbit/pinch, and readonly preview regression.
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func touch(preview: Control, finger: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = at
	event.pressed = pressed
	preview.call("_gui_input", event)

func drag(preview: Control, finger: int, at: Vector2, delta: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = at
	event.relative = delta
	preview.call("_gui_input", event)

func _run() -> void:
	var state: Node = root.get_node("GameState")
	var catalog: Node = root.get_node("Catalog")
	var original_cash: int = state.credits
	var original_stash: String = JSON.stringify(state.stash)
	var original_loadout: String = JSON.stringify(state.loadout)
	var preview: Control = load("res://scripts/weapon_preview.gd").new()
	root.add_child(preview)
	preview.size = Vector2(520, 300)
	preview.call("set_weapon", "weapon_reed9", {})
	await process_frame
	var base: Dictionary = preview.call("get_build_summary")
	check(bool(base.get("valid", false)), "Base gun must have real imported geometry")
	var chosen: Dictionary = {}
	for raw_slot: Variant in catalog.get_item("weapon_reed9").get("slots", {}):
		var slot: String = str(raw_slot)
		var available: Array = catalog.compatible_attachments("weapon_reed9", slot)
		if not available.is_empty(): chosen[slot] = str(available[0]["id"])
	preview.call("set_weapon", "weapon_reed9", chosen)
	var assembled: Dictionary = preview.call("get_build_summary")
	check(bool(assembled.get("valid", false)), "Selected parts must form a valid physical assembly")
	check(assembled.get("parts", {}) == chosen, "Model uses the actual selected item IDs")
	var assembly: Node3D = preview.get("_assembly")
	for slot: String in chosen:
		var installed: Dictionary = assembled.get("installed", {}).get(slot, {})
		check(str(installed.get("path", "")) == str(catalog.get_item(chosen[slot]).get("visual_model", "")), "Slot loads its independent accessory asset: " + slot)
		var socket: Node3D = assembly.call("get_socket", slot)
		check(socket != null and socket.get_child_count() == 1, "Slot replaces factory geometry rather than stacking: " + slot)
		if socket != null and socket.get_child_count() == 1:
			var part: Node3D = socket.get_child(0)
			check(part.transform.is_equal_approx(Transform3D.IDENTITY), "Physical socket origin aligns selected model: " + slot)
	preview.call("set_weapon", "weapon_reed9", {})
	var removed: Dictionary = preview.call("get_build_summary")
	check(removed.get("parts", {}).is_empty() and bool(removed.get("valid", false)), "Removing preview parts restores base/default model")
	var yaw_before: float = preview.get("_yaw")
	touch(preview, 4, Vector2(100, 100), true)
	drag(preview, 4, Vector2(140, 110), Vector2(40, 10))
	check(not is_equal_approx(float(preview.get("_yaw")), yaw_before), "Single finger rotates the rendered assembly")
	touch(preview, 4, Vector2(140, 110), false)
	preview.call("reset_view")
	var zoom_before: float = preview.get("_zoom")
	touch(preview, 1, Vector2(100, 100), true)
	touch(preview, 2, Vector2(200, 100), true)
	drag(preview, 2, Vector2(280, 100), Vector2(80, 0))
	check(float(preview.get("_zoom")) < zoom_before, "Pinching fingers apart zooms into the actual model")
	touch(preview, 1, Vector2(100, 100), false)
	touch(preview, 2, Vector2(280, 100), false)
	check(state.credits == original_cash and JSON.stringify(state.stash) == original_stash and JSON.stringify(state.loadout) == original_loadout, "Preview edits cannot mutate money, stash, or equipped kit")
	preview.queue_free()
	await process_frame
	await process_frame
	print("PREVIEW TESTS ", "PASS" if failures == 0 else "FAIL", ": ", checks, " checks; independent parts, live swaps, orbit/pinch, readonly draft")
	quit(0 if failures == 0 else 1)
