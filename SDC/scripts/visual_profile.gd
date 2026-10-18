extends RefCounted
## Ashfront Look.cs / Materials.cs translated for SDC's phone renderer.
## One profile is shared by raids, map inspection, dressing room and gunsmith.
const CAMERA_PITCH: float = 55.0
const CAMERA_HEIGHT: float = 31.0
const CAMERA_FOV: float = 45.0
const SKY_TOP := Color(.10,.13,.20)
const SKY_HORIZON := Color(.30,.32,.40)
const FOG := Color(.20,.23,.30)

static func environment(preview: bool = false) -> WorldEnvironment:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color=SKY_TOP
	sky_material.sky_horizon_color=SKY_HORIZON
	sky_material.ground_bottom_color=Color(.06,.065,.075)
	sky_material.ground_horizon_color=Color(.16,.17,.20)
	sky_material.sky_curve=.15
	var sky := Sky.new()
	sky.sky_material=sky_material
	var settings := Environment.new()
	settings.background_mode=Environment.BG_SKY
	settings.sky=sky
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("b5b8c0")
	# Forward+ exposure 2 / sky energy 4.4 cannot be numerically copied to LDR GL.
	settings.ambient_light_energy=.68 if preview else .56
	settings.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	settings.tonemap_mode=Environment.TONE_MAPPER_ACES
	settings.tonemap_exposure=1.15
	settings.tonemap_white=6.0
	settings.fog_enabled=not preview
	settings.fog_light_color=FOG
	settings.fog_light_energy=.45
	settings.fog_density=.0022
	settings.fog_aerial_perspective=.22
	settings.fog_sky_affect=.15
	settings.adjustment_enabled=true
	settings.adjustment_saturation=.96
	settings.adjustment_contrast=1.04
	var node := WorldEnvironment.new()
	node.name="AshfrontEnvironment"
	node.environment=settings
	node.set_meta("ashfront_profile",true)
	configure_environment(node,int(AppSettings.values.quality))
	return node

static func configure_environment(node: WorldEnvironment, quality: int) -> void:
	var env: Environment=node.environment
	# Godot 4.6 Compatibility supports SSAO and glow; SSIL and volumetrics are
	# Forward+ only. Keep those off on phones and retain the original light pools.
	env.ssao_enabled=quality>=2
	env.ssao_radius=1.5
	env.ssao_intensity=1.25
	env.ssao_power=2.0
	env.glow_enabled=quality>0
	env.glow_intensity=.55
	env.glow_strength=1.1
	env.glow_bloom=.035
	env.glow_hdr_threshold=.9
	env.ssao_light_affect=.08
	env.volumetric_fog_enabled=false
	env.ssil_enabled=false

static func moon(preview: bool = false) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name="AshfrontMoon"
	light.rotation_degrees=Vector3(-64,35,0)
	light.light_color=Color(.76,.80,.91)
	light.light_energy=.65 if preview else .55
	light.shadow_enabled=true
	light.directional_shadow_max_distance=320 if preview else 72
	light.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.shadow_bias=.06
	light.shadow_normal_bias=1.5
	return light

static func offset() -> Vector3:
	return Vector3(0,CAMERA_HEIGHT,CAMERA_HEIGHT/tan(deg_to_rad(CAMERA_PITCH)))

static func material(color: Color, roughness: float = .85, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color=color
	result.roughness=roughness
	result.metallic=metallic
	return result
