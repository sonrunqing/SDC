extends Node3D
## One original character, with actual owned equipment and shared modular gun assemblies.
var equipped: Dictionary = {}
var weapons: Dictionary = {}
var _body: Node3D
var _gear: Node3D
var _guns: Node3D
var _animation: AnimationPlayer
var _skeleton: Skeleton3D
var _clips: Dictionary={}
var _gait: Dictionary={}
var _bone_rest: Dictionary={}
var _dead: bool=false
var _shot_left: float=0
var _hit_left: float=0
var _held: Node3D
var _held_scale:=Vector3.ONE
var _grip_basis:=Basis.IDENTITY
var _held_offset:=Vector3.ZERO
var _left_target: Node3D
var body_asset: String="res://assets/ashfront/operator_animated.glb"
const PALETTE: Dictionary = {
	"Ripstop forest gray":"3e4b43", "Fabric raised seams":"626b58",
	"Elastic and rubber":"182122", "Ranger green":"526044",
	"Ranger coyote":"7b6b4e", "Graphite":"414d4e",
	"Worn fabric edge":"797c65", "Eye highlight":"6e8179",
}
static func apply_palette(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for index: int in range(node.mesh.get_surface_count()):
			var material: Material = node.get_active_material(index)
			if material is StandardMaterial3D and PALETTE.has(material.resource_name):
				var adjusted := material.duplicate() as StandardMaterial3D
				adjusted.albedo_color = Color(str(PALETTE[material.resource_name]))
				adjusted.roughness = .86
				node.set_surface_override_material(index,adjusted)
	for child: Node in node.get_children(): apply_palette(child)
func _ready() -> void:
	_ensure_nodes()
func _ensure_nodes() -> void:
	if _body != null:return
	_body = load(body_asset).instantiate()
	_body.rotation.y=PI
	apply_palette(_body)
	_body.name = "OperatorBody";add_child(_body)
	_animation=_body.find_child("AnimationPlayer",true,false) as AnimationPlayer
	_skeleton=_body.find_child("Skeleton3D",true,false) as Skeleton3D
	_gait=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ashfront/gait.json"))
	if _animation!=null:
		for clip: StringName in _animation.get_animation_list():
			var key: String=str(clip).get_slice("|",str(clip).get_slice_count("|")-1)
			_clips[key]=clip
			if key.begins_with("walk") or key.begins_with("run") or key in ["idle","aim","move"]:
				_animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
		_play("idle",0)
		_animation.advance(0)
	if _skeleton!=null:
		for bone: String in ["Chest","Head","Hips"]:
			var index: int=_skeleton.find_bone(bone)
			if index>=0:_bone_rest[bone]=global_transform.affine_inverse()*_skeleton.global_transform*_skeleton.get_bone_global_rest(index)
		var hand: int=_skeleton.find_bone("Hand.R")
		if hand>=0 and _animation!=null:
			_play("aim" if _clips.has("aim") else "idle",0)
			_animation.advance(0)
			# Calibrate the bone's local axes to SDC's authored -Z barrel axis.
			# Wrist rotation still transfers fully between all subsequent poses.
			var reference: Basis=global_basis.inverse()*_skeleton.global_basis*_skeleton.get_bone_global_pose(hand).basis
			_grip_basis=reference.orthonormalized().inverse()
			_play("idle",0)
			_animation.advance(0)
	process_priority=1000
	_gear = Node3D.new();_gear.name="EquippedArmor";add_child(_gear)
	_guns = Node3D.new();_guns.name="CarriedWeapons";add_child(_guns)
func set_equipment(loadout: Dictionary) -> void:
	_ensure_nodes()
	for child: Node in _gear.get_children():_gear.remove_child(child);child.queue_free()
	equipped.clear()
	for slot: String in ["helmet","visor","body_armor","armored_rig","backpack"]:
		var id: String = str(loadout.get(slot,""))
		if id.is_empty():continue
		var item: Dictionary=Catalog.get_item(id)
		var category: String=str(item.get("category",""))
		var path: String = "res://assets/operator/equipment/"+id+".glb"
		if not ResourceLoader.exists(path):
			var visual_alias: String=str(item.get("visual_alias",""))
			if not visual_alias.is_empty():path="res://assets/operator/equipment/"+visual_alias+".glb"
		if not ResourceLoader.exists(path):continue
		var gear: Node3D = load(path).instantiate()
		apply_palette(gear)
		gear.name="Equipment_"+slot
		gear.set_meta("item_id",id)
		gear.set_meta("item_category",category)
		if slot=="armored_rig":
			var armored: bool=category=="armored_rig"
			_tint_rig(gear,armored)
			if armored:_add_rig_plate(gear)
			elif category=="rig" and not str(loadout.get("body_armor","")).is_empty():
				# The shared legacy rig mesh is worn outside the separate armor layer.
				gear.scale=Vector3(1.06,1.0,1.12)
		_gear.add_child(gear)
		gear.set_meta("visual_rest",gear.transform)
		gear.set_meta("follow_bone","Head" if slot in ["helmet","visor"] else "Chest")
		equipped[slot]=id

func _play(key: String,blend: float = .16) -> void:
	if _animation==null or not _clips.has(key):return
	if _animation.current_animation!=_clips[key]:_animation.play(_clips[key],blend)

func tick_visual(velocity: Vector3,aiming: bool,delta: float) -> void:
	if _animation==null or _dead:return
	_shot_left=maxf(0,_shot_left-delta)
	_hit_left=maxf(0,_hit_left-delta)
	if _hit_left>0:return
	var planar:=Vector3(velocity.x,0,velocity.z)
	var speed: float=planar.length()
	var key: String="aim" if aiming else "idle"
	if speed>.15:
		var local: Vector3=global_basis.inverse()*planar
		var suffix: String="_f" if -local.z>=absf(local.x) else ("_b" if local.z>=absf(local.x) else ("_l" if local.x<0 else "_r"))
		key=("run" if speed>3.7 else "walk")+suffix
		var nominal: float=float(_gait.get(key,{}).get("nominalSpeed",3.5))
		_animation.speed_scale=clampf(speed/maxf(.1,nominal),.7,2.2)
	else:_animation.speed_scale=1.0
	if not _clips.has(key):key="move" if speed>.15 and _clips.has("move") else "idle"
	_play(key)

func shot() -> void:
	_shot_left=.09

func flinch() -> void:
	if _dead:return
	_hit_left=.14
	_play("hit",.04)

func bind_weapon(mount: Node3D,assembly: Node3D) -> void:
	_held=mount
	_held_scale=mount.scale if mount!=null else Vector3.ONE
	_held_offset=Vector3(0,.09,-.04) if assembly!=null else Vector3(.02,-.04,-.06)
	_left_target=assembly.get_socket("grip") if assembly!=null and assembly.has_method("get_socket") else null

func die() -> void:
	_dead=true
	if _animation!=null:
		_animation.speed_scale=1.0
		_play("death",.06)

func _process(_delta: float) -> void:
	if _skeleton==null or not is_inside_tree():return
	if is_instance_valid(_held):
		var hand: int=_skeleton.find_bone("Hand.R")
		if hand>=0:
			var pose: Transform3D=_skeleton.global_transform*_skeleton.get_bone_global_pose(hand)
			pose.basis=(pose.basis*_grip_basis).orthonormalized()
			pose.origin+=pose.basis*(_held_offset+Vector3(0,0,_shot_left*.3))
			pose.basis=pose.basis.scaled(_held_scale)
			_held.global_transform=pose
	if is_instance_valid(_left_target) and not _dead:_left_hand_ik()
	for gear: Node3D in _gear.get_children():
		var bone: String=str(gear.get_meta("follow_bone","Chest"))
		gear.transform=bone_delta(bone)*Transform3D(gear.get_meta("visual_rest",Transform3D.IDENTITY))
	for weapon: Dictionary in weapons.values():
		var assembly: Node3D=weapon.assembly
		if assembly==_held:continue
		if not assembly.has_meta("visual_rest"):assembly.set_meta("visual_rest",assembly.transform)
		assembly.transform=bone_delta("Chest")*Transform3D(assembly.get_meta("visual_rest"))

func bone_delta(bone: String = "Chest") -> Transform3D:
	if _skeleton==null or not _bone_rest.has(bone):return Transform3D.IDENTITY
	var index: int=_skeleton.find_bone(bone)
	# Rest stored in this operator's local coordinates, so world movement cancels.
	var current: Transform3D=global_transform.affine_inverse()*_skeleton.global_transform*_skeleton.get_bone_global_pose(index)
	return current*Transform3D(_bone_rest[bone]).affine_inverse()

func _left_hand_ik() -> void:
	var upper: int=_skeleton.find_bone("UpperArm.L")
	var lower: int=_skeleton.find_bone("LowerArm.L")
	var hand: int=_skeleton.find_bone("Hand.L")
	if mini(upper,mini(lower,hand))<0:return
	var target: Vector3=_skeleton.to_local(_left_target.global_position)
	var up: Transform3D=_skeleton.get_bone_global_pose(upper)
	var elbow: Vector3=_skeleton.get_bone_global_pose(lower).origin
	var hand_at: Vector3=_skeleton.get_bone_global_pose(hand).origin
	var length_a: float=up.origin.distance_to(elbow)
	var length_b: float=elbow.distance_to(hand_at)
	var distance: float=up.origin.distance_to(target)
	if distance<.001 or length_a<.001 or length_b<.001:return
	var reach: float=clampf(distance,absf(length_a-length_b)+.006,length_a+length_b-.006)
	var forward: Vector3=(target-up.origin).normalized()
	var pole: Vector3=elbow-up.origin-forward*(elbow-up.origin).dot(forward)
	if pole.length_squared()<.00001:pole=up.basis.z
	pole=pole.normalized()
	var angle: float=acos(clampf((length_a*length_a+reach*reach-length_b*length_b)/(2*length_a*reach),-1,1))
	var desired: Vector3=(forward*cos(angle)+pole*sin(angle)).normalized()
	up.basis=Basis(Quaternion((elbow-up.origin).normalized(),desired))*up.basis
	_skeleton.set_bone_global_pose(upper,up)
	var low: Transform3D=_skeleton.get_bone_global_pose(lower)
	var now: Vector3=(_skeleton.get_bone_global_pose(hand).origin-low.origin).normalized()
	var toward: Vector3=(up.origin+forward*reach-low.origin).normalized()
	low.basis=Basis(Quaternion(now,toward))*low.basis
	_skeleton.set_bone_global_pose(lower,low)

func _tint_rig(node: Node,armored: bool) -> void:
	if node is MeshInstance3D and node.mesh!=null:
		for index: int in range(node.mesh.get_surface_count()):
			var material: Material=node.get_active_material(index)
			if material is StandardMaterial3D and material.resource_name in ["Ranger green","Ranger coyote","Graphite"]:
				var fabric:=material.duplicate() as StandardMaterial3D
				var tint:=Color("3b4945") if armored else Color("897552")
				fabric.albedo_color=fabric.albedo_color.lerp(tint,.65)
				fabric.roughness=.9
				node.set_surface_override_material(index,fabric)
	for child: Node in node.get_children():_tint_rig(child,armored)

func _add_rig_plate(gear: Node3D) -> void:
	# A rigid chest insert distinguishes the combined armor rig from a cloth rig.
	var plate:=MeshInstance3D.new()
	plate.name="BallisticRigPlate"
	var mesh:=BoxMesh.new()
	mesh.size=Vector3(.30,.13,.015)
	plate.mesh=mesh
	plate.position=Vector3(0,1.335,-.188)
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("29383d")
	material.roughness=.72
	plate.material_override=material
	gear.add_child(plate)
	var marking:=MeshInstance3D.new()
	marking.name="BallisticPlateMark"
	var marking_mesh:=BoxMesh.new()
	marking_mesh.size=Vector3(.035,.05,.005)
	marking.mesh=marking_mesh
	marking.position=Vector3(-.09,1.35,-.198)
	var marking_material:=StandardMaterial3D.new()
	marking_material.albedo_color=Color("abb5ad")
	marking_material.roughness=.9
	marking.material_override=marking_material
	gear.add_child(marking)

func set_loadout(loadout: Dictionary, builds: Dictionary, active_slot: String = "primary") -> void:
	set_equipment(loadout)
	for child: Node in _guns.get_children():_guns.remove_child(child);child.queue_free()
	weapons.clear()
	for slot: String in ["primary","secondary","sidearm"]:
		var id: String = str(loadout.get(slot,""))
		if id.is_empty():continue
		var assembly: Node3D = load("res://scripts/weapon_assembly.gd").new()
		assembly.name="Weapon_"+slot
		_guns.add_child(assembly)
		assembly.set_build(id,builds.get(slot,{}))
		if slot == active_slot:
			assembly.position=Vector3(.02,1.20,-.29)
			assembly.rotation=Vector3(0,-PI*.5,-.20)
		elif slot=="sidearm":
			assembly.position=Vector3(-.25,.96,-.06)
			assembly.rotation=Vector3(-PI*.5,0,0)
		else:
			assembly.position=Vector3(.19,1.17,.28)
			assembly.rotation=Vector3(PI*.48,0,.16)
		weapons[slot]={"id":id,"parts":builds.get(slot,{}).duplicate(true),"assembly":assembly}
	if weapons.has(active_slot):bind_weapon(weapons[active_slot].assembly,weapons[active_slot].assembly)
func get_summary() -> Dictionary:
	var ids: Dictionary = {}
	for slot: String in weapons:ids[slot]={"id":weapons[slot].id,"parts":weapons[slot].parts}
	return {"armor":equipped.duplicate(),"weapons":ids,"body_path":body_asset,"animation_clips":_clips.size()}
