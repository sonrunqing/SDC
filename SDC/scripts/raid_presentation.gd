extends Control
## Screen-space visibility, damage numbers, enemy bars, hit/kill and threat cues.
## Presentation consumes world state. It never owns a touch or deals damage.
var world: Node3D
var _mask: SubViewport
var _painter: Control
var _veil: ColorRect
var _clock: float=0
var _fan: PackedVector3Array=[]
var _near: PackedVector3Array=[]
var _numbers: Array[Dictionary]=[]
var _hit_at:=Vector3.ZERO
var _hit_left: float=0
var _kill_left: float=0
var _hurt_left: float=0
var _hurt_from:=Vector3.ZERO
var _font: Font

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font=load("res://assets/fonts/NotoSansSC.ttf")
	_mask=SubViewport.new()
	_mask.size=Vector2i(640,360)
	_mask.transparent_bg=false
	_mask.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
	_mask.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	_mask.disable_3d=true
	_mask.gui_disable_input=true
	_mask.world_2d=World2D.new()
	add_child(_mask)
	var background:=ColorRect.new()
	background.color=Color.BLACK
	background.size=Vector2(_mask.size)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_mask.add_child(background)
	_painter=preload("res://scripts/vision_mask_painter.gd").new()
	_painter.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_mask.add_child(_painter)
	_veil=ColorRect.new()
	_veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader:=ShaderMaterial.new()
	shader.shader=preload("res://shaders/vision_composite.gdshader")
	shader.set_shader_parameter("visibility_mask",_mask.get_texture())
	_veil.material=shader
	add_child(_veil)
	# World shading belongs below the drawn combat cues, all below the phone HUD.
	show_behind_parent=true

func hit(at: Vector3,damage: float,killed: bool) -> void:
	_hit_at=at
	_hit_left=.18
	if killed:_kill_left=.8
	if _numbers.size()>=24:_numbers.pop_front()
	_numbers.append({"at":at+Vector3(0,.7,0),"damage":ceili(damage),"left":.75,"kill":killed})

func hurt(from: Vector3) -> void:
	_hurt_left=.65
	_hurt_from=from

func _physics_process(delta: float) -> void:
	if not is_instance_valid(world) or not world._active:return
	_clock-=delta
	if _clock>0:return
	_clock=[.075,.05,.033][clampi(int(AppSettings.values.quality),0,2)]
	var count: int=[48,72,96][clampi(int(AppSettings.values.quality),0,2)]
	var origin: Vector3=world.player.global_position+Vector3(0,.95,0)
	_fan=PackedVector3Array([world.player.global_position+Vector3(0,.04,0)])
	var facing: Vector3=world._aim_direction
	var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	for index: int in range(count+1):
		var direction: Vector3=facing.rotated(Vector3.UP,lerpf(-deg_to_rad(40),deg_to_rad(40),float(index)/count))
		_fan.append(_sight_point(space,origin,direction,38.0))
	_near=PackedVector3Array([world.player.global_position+Vector3(0,.04,0)])
	for index: int in range(25):
		_near.append(_sight_point(space,origin,Vector3.FORWARD.rotated(Vector3.UP,TAU*index/24.0),2.6))
	for guard: Dictionary in world._guards:
		var body: CharacterBody3D=guard.body
		if float(guard.hp)<=0:continue
		var toward: Vector3=body.global_position-world.player.global_position
		var distance: float=toward.length()
		var seen: bool=distance<2.6 or (distance<38 and facing.dot(toward.normalized())>cos(deg_to_rad(40)))
		if seen:
			var query:=PhysicsRayQueryParameters3D.create(origin,body.global_position+Vector3(0,.95,0),1)
			seen=space.intersect_ray(query).is_empty()
		guard["seen"]=seen
		guard.model.visible=seen
		guard.ring.visible=seen and float(guard.alert)>0

func _sight_point(space: PhysicsDirectSpaceState3D,origin: Vector3,direction: Vector3,distance: float) -> Vector3:
	var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*distance,1)
	var hit: Dictionary=space.intersect_ray(query)
	var end: Vector3=origin+direction*distance if hit.is_empty() else Vector3(hit.position)
	return Vector3(end.x,world.player.global_position.y+.04,end.z)

func _process(delta: float) -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.camera):return
	_hit_left=maxf(0,_hit_left-delta)
	_kill_left=maxf(0,_kill_left-delta)
	_hurt_left=maxf(0,_hurt_left-delta)
	for index: int in range(_numbers.size()-1,-1,-1):
		_numbers[index].left-=delta
		if float(_numbers[index].left)<=0:_numbers.remove_at(index)
	_painter.polygons.clear()
	for points: PackedVector3Array in [_fan,_near]:
		var projected:=PackedVector2Array()
		for at: Vector3 in points:
			if world.camera.is_position_behind(at):continue
			projected.append(world.camera.unproject_position(at)*Vector2(_mask.size)/get_viewport_rect().size)
		if projected.size()>2:_painter.polygons.append(projected)
	_painter.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.camera):return
	var camera: Camera3D=world.camera
	for guard: Dictionary in world._guards:
		if not bool(guard.get("seen",false)) or float(guard.hp)<=0 or (float(guard.hp)>=78 and float(guard.alert)<=0):continue
		var at: Vector3=guard.body.global_position+Vector3(0,2.05,0)
		if camera.is_position_behind(at):continue
		var screen: Vector2=camera.unproject_position(at)
		draw_rect(Rect2(screen-Vector2(29,9),Vector2(58,7)),Color(.025,.035,.04,.8))
		draw_rect(Rect2(screen-Vector2(27,7),Vector2(54*float(guard.hp)/78.0,3)),Color("d18a74"))
	for number: Dictionary in _numbers:
		if camera.is_position_behind(number.at):continue
		var at: Vector2=camera.unproject_position(number.at)+Vector2(-8,-32*(.75-float(number.left)))
		var color:=Color("e5c583") if bool(number.kill) else Color("e4e8df")
		color.a=minf(1,float(number.left)*4)
		draw_string(_font,at+Vector2(1,2),str(number.damage),HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color(0,0,0,color.a*.85))
		draw_string(_font,at,str(number.damage),HORIZONTAL_ALIGNMENT_LEFT,-1,19,color)
	if _hit_left>0 and not camera.is_position_behind(_hit_at):
		var center: Vector2=camera.unproject_position(_hit_at)
		var color:=Color("e5c583") if _kill_left>0 else Color("f0e6cc")
		for dir: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			draw_line(center+dir*5,center+dir*10,color,2,true)
	if _kill_left>0:
		var at:=Vector2(size.x*.5-32,size.y*.42)
		draw_string(_font,at,"目标倒地",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(.88,.77,.53,minf(1,_kill_left*3)))
	if _hurt_left>0:
		var source: Vector2=camera.unproject_position(_hurt_from)
		var center: Vector2=camera.unproject_position(world.player.global_position)
		var angle: float=(source-center).angle()
		draw_arc(center,55,angle-.35,angle+.35,16,Color(.85,.22,.16,_hurt_left),4,true)
		var alpha: float=_hurt_left*.22
		draw_rect(Rect2(0,0,size.x,7),Color(.6,.06,.04,alpha))
		draw_rect(Rect2(0,size.y-7,size.x,7),Color(.6,.06,.04,alpha))
