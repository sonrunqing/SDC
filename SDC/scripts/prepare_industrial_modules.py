import bpy,bmesh,json,math
from mathutils import Vector,Matrix
library=bpy.data.scenes.get('ModuleLibrary')
if library is not None:bpy.context.window.scene=library
SOURCE_DIR='D:/aa/模型库/'
OUT='D:/aa/SDC/SDC/assets/environment/industrial_modular/'
SPECS=[
('wall_straight','工业港仓库直墙模块.glb',(4.0,.20,3.0),4000,1024),
('wall_window','工业仓库带窗墙体glb.glb',(4.0,.22,3.0),3500,1024),
('wall_doorway','工业建筑门洞墙体.glb',(4.0,.24,3.0),3500,1024),
('corner','工业仓库L形墙角模块.glb',(2.0,2.0,3.0),4500,1024),
('partition','工业办公楼室内隔断墙.glb',(4.0,.16,3.0),2000,1024),
('floor','正方形工业建筑地板模块.glb',(4.0,4.0,.08),800,512),
('roof_edge','工业建筑屋顶边缘模块.glb',(4.0,.35,.28),1200,512),
('pillar','工业仓库方形支撑柱.glb',(.42,.42,3.0),1800,512),
('beam','工业建筑横向钢梁.glb',(4.0,.28,.34),1600,512),
('stairs','工业建筑直线金属楼梯.glb',(1.6,4.6,3.0),6000,1024),
('platform','工业建筑二层金属平台.glb',(2.0,2.0,3.0),6500,1024),
('door','工业建筑单扇铁门.glb',(1.2,.16,2.2),3500,1024),
('ceiling','工业建筑室内天花板模块.glb',(4.0,4.0,.12),600,512)]
src_root=bpy.data.collections.get('SDC_SourceModules')
if src_root is None:
    src_root=bpy.data.collections.new('SDC_SourceModules')
    bpy.context.scene.collection.children.link(src_root)
for key,file,target,budget,res in SPECS:
    if bpy.data.collections.get('SRC_'+key) is None:
        before=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=SOURCE_DIR+file)
        col=bpy.data.collections.new('SRC_'+key)
        src_root.children.link(col)
        for obj in set(bpy.data.objects)-before:
            for c in list(obj.users_collection):c.objects.unlink(obj)
            col.objects.link(obj)
old=bpy.data.collections.get('SDC_GameModules')
if old:
    for obj in list(old.objects):bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.collections.remove(old)
game=bpy.data.collections.new('SDC_GameModules')
bpy.context.scene.collection.children.link(game)
for c in src_root.children:
    c.hide_viewport=True
    c.hide_render=True
def bounds(mesh):
    vs=mesh.vertices
    return Vector(tuple(min(v.co[i] for v in vs) for i in range(3))),Vector(tuple(max(v.co[i] for v in vs) for i in range(3)))
def crop(mesh,axis,threshold,greater):
    bm=bmesh.new();bm.from_mesh(mesh)
    remove=[]
    for f in bm.faces:
        p=f.calc_center_median()
        if (greater and p[axis]>threshold) or (not greater and p[axis]<threshold):remove.append(f)
    bmesh.ops.delete(bm,geom=remove,context='FACES')
    loose=[v for v in bm.verts if not v.link_faces]
    if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
    bm.to_mesh(mesh);bm.free();mesh.update()
def plain_material(name,color):
    mat=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes=True
    p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=.78
    p.inputs['Metallic'].default_value=.35
    return mat
steel=plain_material('SDC_Platform_Steel',(.25,.31,.33))
yellow=plain_material('SDC_Platform_Safety',(.78,.59,.12))
def add_box_to_mesh(name,center,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=center)
    o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for c in list(o.users_collection):c.objects.unlink(o)
    game.objects.link(o);o.data.materials.append(mat)
    return o
def rebuild_straight_wall():
    steel_wall=plain_material('SDC_Wall_BlueSteel',(.18,.30,.36))
    trim=plain_material('SDC_Wall_Trim',(.35,.43,.45))
    concrete=plain_material('SDC_Wall_Concrete',(.30,.33,.31))
    parts=[add_box_to_mesh('Panel',(0,0,1.7),(4,.11,2.6),steel_wall),
           add_box_to_mesh('Plinth',(0,0,.2),(4,.2,.4),concrete)]
    for x in [-1.96,1.96]:parts.append(add_box_to_mesh('Edge',(x,0,1.7),(.08,.18,2.6),trim))
    for z in [.44,2.96]:parts.append(add_box_to_mesh('Trim',(0,0,z),(4,.18,.08),trim))
    for i in range(40):
        parts.append(add_box_to_mesh('Rib',(-1.9+i*3.8/39,0,1.7),(.032,.15,2.46),steel_wall))
    bpy.ops.object.select_all(action='DESELECT')
    for part in parts:part.select_set(True)
    obj=parts[0];bpy.context.view_layer.objects.active=obj;bpy.ops.object.join()
    for v in obj.data.vertices:v.co+=obj.location
    obj.location=(0,0,0);obj.name='Industrial_wall_straight'
    obj['repair']='Continuous corrugation rebuilt; original closed source mesh retained.'
    return obj
results=[]
for idx,(key,file,target,budget,res) in enumerate(SPECS):
    src=next(o for o in bpy.data.collections['SRC_'+key].objects if o.type=='MESH')
    mesh=src.data.copy();mesh.transform(src.matrix_world)
    obj=bpy.data.objects.new('Industrial_'+key,mesh);game.objects.link(obj)
    lo,hi=bounds(mesh);original_lo=lo.copy();original_hi=hi.copy();d=hi-lo
    if key=='wall_straight':crop(mesh,0,lo.x+d.x*.115,True)
    if key=='wall_window':crop(mesh,2,lo.z+d.z*.88,True)
    if key=='wall_doorway':crop(mesh,0,hi.x-d.x*.19,False)
    if key in ['wall_straight','wall_window','wall_doorway','partition','roof_edge','beam']:
        mesh.transform(Matrix.Rotation(math.pi/2,4,'Z'))
    lo,hi=bounds(mesh);d=hi-lo
    if key=='platform':
        original_lo=lo.copy();original_hi=hi.copy()
        deck_z=lo.z+d.z*.792
        crop(mesh,2,deck_z-.022,False)
        sx=target[0]/d.x;sy=target[1]/d.y;sz=3.0/(deck_z-lo.z)
        for v in mesh.vertices:
            v.co=Vector(((v.co.x-(lo.x+hi.x)/2)*sx,(v.co.y-(lo.y+hi.y)/2)*sy,(v.co.z-lo.z)*sz))
    else:
        sz=target[2]/d.z
        if key=='stairs':
            upper=[]
            for p in mesh.polygons:
                if p.normal.z>.75 and abs(p.center.x-(lo.x+hi.x)/2)<d.x*.3:
                    upper.append(p.center.z)
            top_tread=max(upper)
            sz=3.0/(top_tread-lo.z)
        sx=target[0]/d.x;sy=target[1]/d.y
        for v in mesh.vertices:
            v.co=Vector(((v.co.x-(lo.x+hi.x)/2)*sx,(v.co.y-(lo.y+hi.y)/2)*sy,(v.co.z-lo.z)*sz))
    mesh.update()
    copied_images={}
    for slot,mat in enumerate(list(mesh.materials)):
        if not mat:continue
        copy=mat.copy();copy.name='SDC_'+key+'_Material';copy.use_backface_culling=False
        mesh.materials[slot]=copy
        for node in copy.node_tree.nodes:
            if node.type=='TEX_IMAGE' and node.image:
                name=node.image.name
                if name not in copied_images:
                    im=node.image.copy();im.name='SDC_'+key+'_'+str(len(copied_images))
                    im.scale(res,res);im.pack();copied_images[name]=im
                node.image=copied_images[name]
    bpy.ops.object.select_all(action='DESELECT')
    obj.hide_set(False);obj.select_set(True);bpy.context.view_layer.objects.active=obj
    triangles=sum(len(p.vertices)-2 for p in mesh.polygons)
    if triangles>budget:
        mod=obj.modifiers.new('SDC_GameSimplification','DECIMATE')
        mod.ratio=budget/triangles;mod.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if key=='platform':
        bm=bmesh.new();bm.from_mesh(obj.data)
        remove=[f for f in bm.faces if f.calc_center_median().y<-.78 and abs(f.calc_center_median().x)<.81 and f.calc_center_median().z>3.08]
        bmesh.ops.delete(bm,geom=remove,context='FACES')
        loose=[v for v in bm.verts if not v.link_faces]
        if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
        bm.to_mesh(obj.data);bm.free()
        pieces=[obj]
        for y in [-.94,.94]:pieces.append(add_box_to_mesh('Apron',(0,y,2.88),(2,.16,.30),steel))
        for x in [-.94,.94]:pieces.append(add_box_to_mesh('Apron',(x,0,2.88),(.16,2,.30),steel))
        for x in [-.83,.83]:pieces.append(add_box_to_mesh('EntrancePost',(x,-.93,3.42),(.07,.07,.88),steel))
        for x in [-.82,.82]:
            for y in [-.82,.82]:
                pieces.append(add_box_to_mesh('PlatformLeg',(x,y,1.45),(.20,.20,2.90),steel))
                pieces.append(add_box_to_mesh('PlatformFoot',(x,y,.05),(.36,.36,.10),steel))
                pieces.append(add_box_to_mesh('PlatformSafetyBand',(x,y,.18),(.212,.212,.14),yellow))
        bpy.ops.object.select_all(action='DESELECT')
        for piece in pieces:piece.select_set(True)
        bpy.context.view_layer.objects.active=obj;bpy.ops.object.join()
    if key=='wall_straight':
        bpy.data.objects.remove(obj,do_unlink=True)
        obj=rebuild_straight_wall()
        res=0
    obj['module_id']=key;obj['source_file']=file;obj['units']='metres';obj['collision_authoring']='data/industrial_modules.json'
    obj.data.validate();obj.data.update()
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    fmt='GLB'  # Validated against the connected Blender exporter; dynamic RNA enum lists are empty.
    bpy.ops.export_scene.gltf(filepath=OUT+key+'.glb',export_format=fmt,use_selection=True,use_active_scene=True,export_extras=True)
    lo,hi=bounds(obj.data);d=hi-lo
    result={'id':'industrial_modular/'+key,'key':key,'source_file':file,'path':'res://assets/environment/industrial_modular/'+key+'.glb','min':[lo.x,lo.z,-hi.y],'size':[d.x,d.z,d.y],'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),'texture_resolution':res,'object':obj.name}
    results.append(result)
    obj.location=((idx%5)*6.5,(idx//5)*7.0,0)
bpy.context.scene['sdc_module_manifest']=json.dumps(results,ensure_ascii=False)
bpy.context.scene.name='ModuleLibrary'
bpy.context.scene.unit_settings.system='METRIC'
bpy.ops.wm.save_as_mainfile(filepath='D:/aa/SDC-tools/blender/SDC_Industrial_Authoring.blend')
print('SDC_MODULES '+json.dumps(results,ensure_ascii=False))

