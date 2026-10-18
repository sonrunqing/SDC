extends Node3D
## A small asset, touch and audio check. Gameplay can be added after setup.

const WEAPON = preload("res://assets/kenney/blaster-kit/blaster-a.glb")
const CRATE = preload("res://assets/kenney/blaster-kit/crate-small.glb")
const TARGET = preload("res://assets/kenney/blaster-kit/target-large.glb")
const FIGURE = preload("res://assets/kenney/prototype-kit/figurine-cube.glb")
const WALL = preload("res://assets/kenney/prototype-kit/wall.glb")
const CONFIRM = preload("res://assets/kenney/interface-sounds/confirmation_004.ogg")

var status: Label
var audio: AudioStreamPlayer
var checks := 0


func _ready() -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.0
	camera.position = Vector3(10, 13, 15)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.4
	add_child(light)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("142236")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b9d9ee")
	settings.ambient_light_energy = 0.6
	environment.environment = settings
	add_child(environment)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(12, 0.2, 8)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("334c63")
	floor_mesh.material = material
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.position.y = -0.1
	add_child(floor_node)
	place(FIGURE, Vector3(-1, 0, 1), 1.5)
	place(WEAPON, Vector3(-0.3, 1.1, 0.7), 1.4)
	place(CRATE, Vector3(3, 0, 1), 1.3)
	place(CRATE, Vector3(3.8, 0, 0), 1.0)
	place(TARGET, Vector3(-3, 0, -2), 1.5)
	for x in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		place(WALL, Vector3(x, 0, -3.5), 1.0)
	audio = AudioStreamPlayer.new()
	audio.stream = CONFIRM
	add_child(audio)
	build_ui()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--smoke-screenshot="):
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var error := image.save_png(argument.trim_prefix("--smoke-screenshot="))
			print("SCREENSHOT_RESULT ", error)
			get_tree().quit(error)


func place(scene: PackedScene, at: Vector3, factor: float) -> void:
	var model := scene.instantiate() as Node3D
	model.position = at
	model.scale = Vector3.ONE * factor
	add_child(model)


func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := MarginContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_constant_override("margin_left", 36)
	panel.add_theme_constant_override("margin_top", 24)
	panel.add_theme_constant_override("margin_right", 36)
	panel.add_theme_constant_override("margin_bottom", 24)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var title := Label.new()
	title.text = "2.5D SHOOTER  /  SETUP CHECK"
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "3D assets + orthographic camera + Android touch & audio"
	subtitle.modulate = Color("9db8cd")
	column.add_child(subtitle)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	status = Label.new()
	status.text = "Ready. Tap the button to check input and sound."
	column.add_child(status)
	var button := preload("res://scripts/touch_button.gd").new()
	button.text = "TAP TO TEST INPUT + SOUND"
	button.custom_minimum_size = Vector2(360, 64)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(func():
		checks += 1
		status.text = "Input OK  /  check %d" % checks
		audio.play()
	)
	column.add_child(button)
	var credits := Label.new()
	credits.text = "Prototype assets: Kenney (CC0)  |  Development scaffold"
	credits.modulate = Color("9db8cd")
	credits.add_theme_font_size_override("font_size", 14)
	column.add_child(credits)
