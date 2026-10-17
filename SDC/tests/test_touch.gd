extends SceneTree
## Multi-touch regression: both sticks plus a third action finger.
var failures: int = 0
var observed: Dictionary = {"move": Vector2.ZERO, "aim": Vector2.ZERO, "firing": false, "heal": 0, "reload": 0, "weapon": ""}

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func touch(control: Control, finger: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = position
	event.pressed = pressed
	control.call("_input", event)

func _run() -> void:
	var script: Script = load("res://scripts/virtual_controls.gd")
	var control: Control = script.new()
	root.add_child(control)
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.size = Vector2(1280, 720)
	control.move_changed.connect(func(value: Vector2): observed["move"] = value)
	control.aim_changed.connect(func(value: Vector2, firing: bool):
		observed["aim"] = value
		observed["firing"] = firing)
	control.medkit_pressed.connect(func(): observed["heal"] += 1)
	control.reload_pressed.connect(func(): observed["reload"] += 1)
	control.weapon_pressed.connect(func(slot: String): observed["weapon"] = slot)
	control.call("set_weapons",[{"slot":"primary","available":true},{"slot":"secondary","available":true},{"slot":"sidearm","available":true}])
	control.set("enabled", true)
	touch(control, 4, Vector2(190, 565), true)
	touch(control, 8, Vector2(1145, 551), true)
	check((observed["move"] as Vector2).x > 0.2, "Left touch must move independently")
	check(bool(observed["firing"]), "Right touch must fire while left held")
	touch(control, 12, Vector2(1220, 653), true)
	check(int(observed["heal"]) == 1, "Third finger must trigger heal while both joysticks held")
	touch(control, 12, Vector2(1220, 653), false)
	touch(control, 14, Vector2(640, 678), true)
	check(observed["weapon"] == "secondary" and bool(observed["firing"]), "Third finger can switch to the second gun while both sticks are held")
	touch(control, 14, Vector2(640, 678), false)
	touch(control, 14, Vector2(798, 678), true)
	check(observed["weapon"] == "sidearm", "Third gun button selects the handgun")
	touch(control, 14, Vector2(798, 678), false)
	touch(control, 4, Vector2(190, 565), false)
	check((observed["move"] as Vector2).is_zero_approx(), "Releasing left touch must stop movement")
	check(bool(observed["firing"]), "Releasing left must preserve right shooting")
	touch(control, 8, Vector2(1145, 551), false)
	check(not bool(observed["firing"]), "Releasing right must stop firing")
	touch(control, 1, Vector2(190, 565), true)
	touch(control, 2, Vector2(1145, 551), true)
	control.set("enabled", false)
	check((observed["move"] as Vector2).is_zero_approx() and not bool(observed["firing"]), "Disabling controls must release both sticks")
	control.queue_free()
	await process_frame
	print("TOUCH_TEST failures=", failures)
	quit(0 if failures == 0 else 1)
