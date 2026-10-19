extends Node
signal changed
signal controls_changed
const ControlLayout = preload("res://scripts/control_layout.gd")
const PATH := "user://settings.cfg"
var _path: String=PATH
const DEFAULTS := {"fps":60,"resolution":1.0,"quality":1,"brightness":1.0,"camera_height":31.0,"camera_pitch":55.0,"camera_fov":45.0,"camera_shake":.65,"master":.85,"sfx":.8,"ui_audio":.55,"control_scale":1.0,"control_opacity":.8,"aim_sensitivity":1.0,"deadzone":.14,"ui_scale":1.0,"safe_margin":24,"vibration":true}
var values: Dictionary = DEFAULTS.duplicate(true)
var _click: AudioStreamPlayer
var _save_delay: float = -1
var control_profiles: Array=[{},{},{}]
var active_control_profile: int=0
func _ready() -> void:
	if OS.get_cmdline_user_args().has("--sdc-ai"):
		_path=OS.get_environment("SDC_AI_SETTINGS")
		if not _path.is_absolute_path():
			get_tree().quit(78)
			return
	var file:=ConfigFile.new()
	var loaded: bool=file.load(_path)==OK
	if loaded:
		for key: String in DEFAULTS:
			var stored: Variant = file.get_value("settings",key,DEFAULTS[key])
			if typeof(stored)==typeof(DEFAULTS[key]) or (stored is int and DEFAULTS[key] is float):values[key]=stored
		var stored_profiles: Variant=file.get_value("controls","profiles",[])
		if stored_profiles is Array:
			for index: int in range(mini(3,stored_profiles.size())):control_profiles[index]=ControlLayout.sanitize(stored_profiles[index])
		var stored_profile: Variant=file.get_value("controls","active",0)
		if stored_profile is int:active_control_profile=clampi(stored_profile,0,2)
	elif OS.has_feature("mobile"):
		var pixel_ratio: float=maxf(.5,float(DisplayServer.window_get_size().y)/720.0)
		var density: float=maxf(1.0,float(DisplayServer.screen_get_dpi())/160.0)
		values.ui_scale=clampf(44.0*density/(72.0*pixel_ratio),1.0,1.15)
	for bus: String in ["SFX","UI"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
	_click=AudioStreamPlayer.new()
	_click.stream=preload("res://assets/kenney/interface-sounds/click_001.ogg")
	_click.bus="UI"
	add_child(_click)
	apply()
func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):return
	values[key]=value
	apply(key in ["resolution","quality","brightness"])
	_save_delay=.35
	changed.emit()
func _process(delta: float) -> void:
	if _save_delay<0:return
	_save_delay-=delta
	if _save_delay<=0:
		_save_config()
func _save_config() -> Error:
	_save_delay=-1
	var file:=ConfigFile.new()
	for field: String in values:file.set_value("settings",field,values[field])
	file.set_value("controls","version",1)
	file.set_value("controls","active",active_control_profile)
	file.set_value("controls","profiles",control_profiles)
	return file.save(_path)

func get_control_layout(profile: int = -1) -> Dictionary:
	var index: int=active_control_profile if profile<0 else clampi(profile,0,2)
	return ControlLayout.sanitize(control_profiles[index])

func activate_control_profile(index: int) -> Error:
	if index<0 or index>2:return ERR_INVALID_PARAMETER
	var previous: int=active_control_profile
	active_control_profile=index
	var result: Error=_save_config()
	if result!=OK:
		active_control_profile=previous
		_save_delay=.35
		return result
	controls_changed.emit()
	return OK

func save_control_layout(profile: int,layout: Dictionary) -> Error:
	if profile<0 or profile>2:return ERR_INVALID_PARAMETER
	var sanitized: Dictionary=ControlLayout.sanitize(layout)
	if sanitized.size()!=ControlLayout.IDS.size():return ERR_INVALID_DATA
	var previous: Array=control_profiles.duplicate(true)
	var previous_active: int=active_control_profile
	control_profiles[profile]=sanitized
	active_control_profile=profile
	var result: Error=_save_config()
	if result!=OK:
		control_profiles=previous
		active_control_profile=previous_active
		_save_delay=.35
		return result
	controls_changed.emit()
	return OK
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT] and _save_delay>=0:_save_config()
func _exit_tree() -> void:
	if _save_delay>=0:_save_config()
func apply(update_scene: bool = true) -> void:
	values.fps=clampi(int(values.fps),30,120)
	values.resolution=clampf(float(values.resolution),.5,1)
	values.ui_scale=clampf(float(values.ui_scale),.85,1.2)
	values.control_scale=clampf(float(values.control_scale),.8,1.25)
	values.control_opacity=clampf(float(values.control_opacity),.3,1)
	values.aim_sensitivity=clampf(float(values.aim_sensitivity),.5,2)
	values.deadzone=clampf(float(values.deadzone),.05,.3)
	values.brightness=clampf(float(values.brightness),.6,1.4)
	values.camera_height=clampf(float(values.camera_height),25,42)
	values.camera_pitch=clampf(float(values.camera_pitch),40,70)
	values.camera_fov=clampf(float(values.camera_fov),35,60)
	values.camera_shake=clampf(float(values.camera_shake),0,1)
	values.safe_margin=clampi(int(values.safe_margin),20,48)
	Engine.max_fps=int(values.fps)
	get_tree().root.scaling_3d_scale=float(values.resolution)
	get_tree().root.content_scale_factor=float(values.ui_scale)
	for key: String in ["master","sfx","ui_audio"]:
		var index: int = AudioServer.get_bus_index({"master":"Master","sfx":"SFX","ui_audio":"UI"}[key])
		if index>=0:
			var volume: float = clampf(float(values[key]),0,1)
			AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.0001,volume)))
			AudioServer.set_bus_mute(index,volume<=.001)
	if update_scene:apply_scene(get_tree().root)
func apply_scene(node: Node) -> void:
	if node is Viewport:node.msaa_3d=Viewport.MSAA_2X if int(values.quality)>0 else Viewport.MSAA_DISABLED
	if node is WorldEnvironment and node.has_meta("ashfront_profile"):
		preload("res://scripts/visual_profile.gd").configure_environment(node,int(values.quality))
		node.environment.tonemap_exposure=1.15*float(values.brightness)
	if node is SubViewport:node.scaling_3d_scale=float(values.resolution)
	if node is DirectionalLight3D:
		if not node.has_meta("base_energy"):node.set_meta("base_energy",node.light_energy)
		if not node.has_meta("base_shadow"):node.set_meta("base_shadow",node.shadow_enabled)
		node.light_energy=float(node.get_meta("base_energy"))*float(values.brightness)
		node.shadow_enabled=int(values.quality)>0 and bool(node.get_meta("base_shadow"))
	if node is MultiMeshInstance3D and node.visibility_range_end>0:node.visibility_range_end=[60.0,85.0,110.0][clampi(int(values.quality),0,2)]
	for child: Node in node.get_children():apply_scene(child)
func safe_insets(canvas: Control) -> Vector4:
	var base: float = maxf(20,float(values.safe_margin))
	var result:=Vector4(base,base,base,base)
	if OS.has_feature("mobile"):
		var usable: Rect2i = DisplayServer.get_display_safe_area()
		var physical: Vector2i = DisplayServer.window_get_size()
		if usable.size.x>0 and physical.x>0:
			var factor: Vector2 = canvas.get_viewport_rect().size/Vector2(physical)
			result.x=maxf(base,usable.position.x*factor.x)
			result.y=maxf(base,usable.position.y*factor.y)
			result.z=maxf(base,(physical.x-usable.end.x)*factor.x)
			result.w=maxf(base,(physical.y-usable.end.y)*factor.y)
	return result
func ui_feedback() -> void:
	if _click!=null:_click.play()
	if bool(values.vibration) and OS.has_feature("mobile"):Input.vibrate_handheld(12,.25)
