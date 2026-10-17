extends SceneTree
## Bake real equipment silhouettes once; shop cards use textures instead of many 3D viewports.
var viewport: SubViewport
var camera: Camera3D
var holder: Node3D
var catalog: Node
func _initialize() -> void:
	call_deferred("run")
func material(color: String,metal: float = 0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=Color(color);m.metallic=metal;m.roughness=.5;return m
func box(at: Vector3,size: Vector3,color: String) -> void:
	var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.position=at;node.material_override=material(color);holder.add_child(node)
func cylinder(at: Vector3,radius: float,height: float,color: String,tip: bool = false) -> void:
	var node:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=radius*.28 if tip else radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=16
	node.mesh=mesh;node.position=at;node.material_override=material(color,.65);holder.add_child(node)
func collect(node: Node,bounds: Array) -> void:
	if node is MeshInstance3D and node.mesh!=null:
		var bound:AABB=node.global_transform*node.mesh.get_aabb()
		bounds.append(bound)
	for child:Node in node.get_children():collect(child,bounds)
func fit(kind: String) -> void:
	var boxes:Array=[];collect(holder,boxes)
	var bounds:AABB=boxes[0]
	for bound:AABB in boxes:bounds=bounds.merge(bound)
	var center:Vector3=bounds.get_center();var span:float=maxf(.01,bounds.size.length())
	camera.position=center+(Vector3(3.8,.8,.5) if kind in ["weapon","attachment"] else Vector3(.6,.35,-3.5)).normalized()*span*3
	camera.look_at(center);camera.size=span*1.6
	var projected:Rect2;var first:bool=true
	for x:int in range(2):
		for y:int in range(2):
			for z:int in range(2):
				var p:Vector3=bounds.position+bounds.size*Vector3(x,y,z)
				var screen:Vector2=camera.unproject_position(p)
				projected=Rect2(screen,Vector2.ZERO) if first else projected.expand(screen);first=false
	camera.size*=maxf(projected.size.x/(viewport.size.x*.84),projected.size.y/(viewport.size.y*.80))
func run() -> void:
	catalog=root.get_node("Catalog")
	viewport=SubViewport.new();viewport.size=Vector2i(320,200);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(0,0,0,0);env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("d4e0df");env.ambient_light_energy=.75;environment.environment=env;viewport.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,130,0);light.light_energy=2.2;viewport.add_child(light)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-20,-55,0);fill.light_energy=.7;fill.light_color=Color("99c1d0");viewport.add_child(fill)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.001;camera.far=300;viewport.add_child(camera);camera.current=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons/items"))
	var count:int=0
	for item:Dictionary in catalog.items.values():
		if OS.get_cmdline_user_args().has("--armor-only") and str(item.kind)!="armor":continue
		holder=Node3D.new();viewport.add_child(holder)
		var kind:String=str(item.kind)
		match kind:
			"weapon":
				var assembly:Node3D=load("res://scripts/weapon_assembly.gd").new();holder.add_child(assembly);assembly.set_build(str(item.id),{})
			"attachment":holder.add_child(load(str(item.visual_model)).instantiate())
			"armor":
				var armor:Node3D=load("res://assets/operator/equipment/"+str(item.id)+".glb").instantiate()
				load("res://scripts/operator_model.gd").apply_palette(armor)
				holder.add_child(armor)
			"ammo":
				for x:float in [-.17,0,.17]:
					cylinder(Vector3(x,.22,0),.06,.4,"b19148")
					cylinder(Vector3(x,.48,0),.058,.16,"393c40" if str(item.id).ends_with("_ap") else "b0754f",true)
			"consumable":
				box(Vector3.ZERO,Vector3(.7,.46,.24),"46665a")
				box(Vector3(0,.03,-.13),Vector3(.25,.065,.02),"d6d7c9");box(Vector3(0,.03,-.14),Vector3(.065,.25,.02),"d6d7c9")
				box(Vector3(0,.29,0),Vector3(.25,.09,.08),"3f4b45")
			"loot":
				box(Vector3.ZERO,Vector3(.65,.42,.25),"87795d");box(Vector3(0,0,-.14),Vector3(.42,.23,.02),"b2b2a1");box(Vector3(.15,.03,-.16),Vector3(.08,.13,.02),"45656d")
		fit(kind)
		await process_frame
		await RenderingServer.frame_post_draw
		var result:int=viewport.get_texture().get_image().save_png("res://assets/icons/items/"+str(item.id)+".png")
		if result!=OK:push_error("Icon save failed: "+str(item.id));quit(1);return
		viewport.remove_child(holder);holder.free();count+=1
		if count%32==0:print("ITEM_ICONS ",count)
	print("ITEM_ICONS COMPLETE ",count)
	quit()
