extends Node3D
## Ashfront Fx.cs: bounded shared meshes, no per-shot nodes/material allocation.
var _pool: Array[Dictionary]=[]
var _cursor: int=0
var _flash_light: OmniLight3D
var _flash_left: float=0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	var mesh := BoxMesh.new()
	mesh.size=Vector3.ONE
	for index: int in range(128):
		var material := StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.disable_receive_shadows=true
		var node := MeshInstance3D.new()
		node.mesh=mesh
		node.material_override=material
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		node.visible=false
		add_child(node)
		_pool.append({"node":node,"mat":material,"life":0.0,"total":1.0,"velocity":Vector3.ZERO,"gravity":0.0,"shrink":false,"color":Color.WHITE,"scale":Vector3.ONE})
	_flash_light=OmniLight3D.new()
	_flash_light.light_color=Color(1,.82,.48)
	_flash_light.omni_range=10
	_flash_light.omni_attenuation=1.4
	_flash_light.shadow_enabled=false
	_flash_light.visible=false
	add_child(_flash_light)

func _take(at: Vector3, size: Vector3, color: Color, life: float, velocity: Vector3 = Vector3.ZERO, gravity: float = 0.0, shrink: bool = false) -> Dictionary:
	var item: Dictionary=_pool[_cursor]
	_cursor=(_cursor+1)%_pool.size()
	item.node.visible=true
	item.node.position=at
	item.node.rotation=Vector3.ZERO
	item.node.scale=size
	item.mat.albedo_color=color
	item.life=life
	item.total=life
	item.velocity=velocity
	item.gravity=gravity
	item.shrink=shrink
	item.color=color
	item.scale=size
	return item

func tracer(from: Vector3,to: Vector3,color: Color,lifetime: float) -> void:
	var delta: Vector3=to-from
	var length: float=minf(delta.length(),26.0)
	if length<.05:return
	delta=delta.normalized()*length
	var item: Dictionary=_take(from+delta*.5,Vector3(.035,.035,length),color,lifetime)
	item.node.look_at(item.node.global_position+delta,Vector3.RIGHT if absf(delta.normalized().y)>.99 else Vector3.UP)

func impact(at: Vector3,color: Color,lifetime: float) -> void:
	var blood: bool=color.r>color.g*1.5 and color.g<.65
	var tint: Color=Color(.65,.12,.10) if blood else color
	_take(at,Vector3(.16,.16,.16),tint,lifetime,Vector3.ZERO,0,true)
	var count: int=3 if int(AppSettings.values.quality)==0 else 6
	for index: int in range(count):
		var velocity:=Vector3(_rng.randf_range(-1.8,1.8),_rng.randf_range(.5,2.8),_rng.randf_range(-1.8,1.8))
		var piece: Dictionary=_take(at,Vector3(.025,.025,.08),tint,.22+_rng.randf()*.2,velocity,7,true)
		piece.node.rotation=Vector3(_rng.randf()*TAU,_rng.randf()*TAU,0)
	if not blood and int(AppSettings.values.quality)>0:
		_take(at,Vector3(.3,.14,.3),Color(.42,.43,.45,.3),.42,Vector3(0,.3,0),0,true)

func muzzle(at: Vector3, direction: Vector3, player_shot: bool, flash: bool = true) -> void:
	if flash:
		var item: Dictionary=_take(at+direction*.12,Vector3(.10,.10,.32),Color(1,.83,.46),.035)
		item.node.look_at(item.node.global_position+direction)
		if player_shot and int(AppSettings.values.quality)>0:
			_flash_light.position=at
			_flash_light.visible=true
			_flash_left=.045
	if int(AppSettings.values.quality)>0:
		var right: Vector3=direction.cross(Vector3.UP)
		var casing: Dictionary=_take(at-direction*.32,Vector3(.025,.025,.07),Color(.65,.48,.23),.7,right*2+Vector3(0,1.4,0),9)
		casing.node.rotation=Vector3(1,.5,.4)

func _process(delta: float) -> void:
	for item: Dictionary in _pool:
		if float(item.life)<=0:continue
		item.life=maxf(0,float(item.life)-delta)
		if float(item.life)<=0:
			item.node.visible=false
			continue
		var ratio: float=float(item.life)/float(item.total)
		item.velocity.y-=float(item.gravity)*delta
		item.node.position+=Vector3(item.velocity)*delta
		if item.node.position.y<.03:
			item.node.position.y=.03
			item.velocity=Vector3.ZERO
		var tint: Color=item.color
		tint.a*=minf(1,ratio*3)
		item.mat.albedo_color=tint
		if bool(item.shrink):item.node.scale=Vector3(item.scale)*(.3+.7*ratio)
	_flash_left=maxf(0,_flash_left-delta)
	_flash_light.light_energy=5.5*_flash_left/.045
	_flash_light.visible=_flash_left>0
