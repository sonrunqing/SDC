extends Node3D
## One original character, with actual owned equipment and shared modular gun assemblies.
var equipped: Dictionary = {}
var weapons: Dictionary = {}
var _body: Node3D
var _gear: Node3D
var _guns: Node3D
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
	_body = load("res://assets/operator/operator.glb").instantiate()
	apply_palette(_body)
	_body.name = "OperatorBody";add_child(_body)
	_gear = Node3D.new();_gear.name="EquippedArmor";add_child(_gear)
	_guns = Node3D.new();_guns.name="CarriedWeapons";add_child(_guns)
func set_equipment(loadout: Dictionary) -> void:
	_ensure_nodes()
	for child: Node in _gear.get_children():_gear.remove_child(child);child.queue_free()
	equipped.clear()
	for slot: String in ["helmet","visor","body_armor","armored_rig","backpack"]:
		var id: String = str(loadout.get(slot,""))
		if id.is_empty():continue
		var path: String = "res://assets/operator/equipment/"+id+".glb"
		if not ResourceLoader.exists(path):continue
		var gear: Node3D = load(path).instantiate()
		apply_palette(gear)
		gear.name="Equipment_"+slot
		gear.set_meta("item_id",id)
		_gear.add_child(gear)
		equipped[slot]=id
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
func get_summary() -> Dictionary:
	var ids: Dictionary = {}
	for slot: String in weapons:ids[slot]={"id":weapons[slot].id,"parts":weapons[slot].parts}
	return {"armor":equipped.duplicate(),"weapons":ids,"body_path":"res://assets/operator/operator.glb"}
