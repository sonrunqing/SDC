"""Run in Blender through MCP. Keep raw sources and author game-sized expansion parts."""
import bpy, bmesh, json, math
from mathutils import Vector, Matrix

ROOT = 'D:/aa/SDC/SDC'
SOURCE = 'D:/aa/模型库/'
OUT = ROOT + '/assets/environment/industrial_modular/'
SPECS = [
    ('infill_1m', '工业仓库一米补墙模块.glb', (1, .20, 3), 1400, 512),
    ('infill_2m', '工业仓库两米补墙模块.glb', (2, .20, 3), 1800, 512),
    ('inner_corner', '工业仓库内转角模块.glb', (1, 1, 3), 2800, 512),
    ('window_panel', '工业仓库带窗墙体模块.glb', (4, .20, 3), 3200, 1024),
    ('freight_frame', '工业仓库货运卷帘门框.glb', (4.5, .28, 3), 3200, 1024),
    ('roller_shutter', '工业仓库卷帘门帘.glb', (4, .10, 2.6), 2000, 512),
    ('loading_dock', '工业仓库装卸台模块.glb', (4, 2, .98), 2200, 1024),
    ('catwalk', '工业建筑二层直线栈桥模块.glb', (4, 2, 1.12), 3800, 1024),
    ('guardrail', '工业建筑护栏直线模块.glb', (2, .20, 1), 1800, 512),
    ('storage_rack', '工业仓库三层货架.glb', (2, .8, 2.4), 4000, 1024),
    ('workbench', '工业维修工作台.glb', (2, .8, 1.18), 4000, 1024),
]

def ensure_scene():
    scene = bpy.data.scenes.get('ExpansionLibrary')
    if scene is None:
        scene = bpy.data.scenes.new('ExpansionLibrary')
    bpy.context.window.scene = scene
    scene.unit_settings.system = 'METRIC'
    return scene

def bounds(mesh):
    return (Vector(tuple(min(v.co[i] for v in mesh.vertices) for i in range(3))),
            Vector(tuple(max(v.co[i] for v in mesh.vertices) for i in range(3))))

def import_sources():
    scene = ensure_scene()
    report = []
    for key, filename, target, budget, res in SPECS:
        col = bpy.data.collections.get('RAW_NEXT_' + key)
        if col is None:
            before = set(bpy.data.objects)
            bpy.ops.import_scene.gltf(filepath=SOURCE + filename)
            col = bpy.data.collections.new('RAW_NEXT_' + key)
            scene.collection.children.link(col)
            for obj in set(bpy.data.objects) - before:
                for c in list(obj.users_collection):
                    c.objects.unlink(obj)
                col.objects.link(obj)
        for obj in col.objects:
            if obj.type == 'MESH':
                mesh = obj.data.copy()
                mesh.transform(obj.matrix_world)
                lo, hi = bounds(mesh)
                report.append(dict(key=key, object=obj.name, min=list(lo), size=list(hi-lo), faces=len(mesh.polygons)))
                bpy.data.meshes.remove(mesh)
        col.hide_render = True
        col.hide_viewport = True
    print('EXPANSION_SOURCES ' + json.dumps(report))

def material(name, color, metallic=.12):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    p = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = .85
    p.inputs['Metallic'].default_value = metallic
    mat.diffuse_color = (*color, 1)
    return mat

def clip(mesh, axis, value, keep_below, cap_index):
    bm = bmesh.new()
    bm.from_mesh(mesh)
    normal = Vector((0, 0, 0)); normal[axis] = 1
    point = Vector((0, 0, 0)); point[axis] = value
    result = bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
        dist=.000001, plane_co=point, plane_no=normal,
        clear_outer=keep_below, clear_inner=not keep_below)
    edges = [e for e in result['geom_cut'] if isinstance(e, bmesh.types.BMEdge) and e.is_boundary]
    if edges:
        caps = bmesh.ops.holes_fill(bm, edges=edges, sides=0)
        for face in caps.get('faces', []): face.material_index = cap_index
    loose = [v for v in bm.verts if not v.link_faces]
    if loose: bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free(); mesh.update()

def remove_inside_portal(mesh):
    bm = bmesh.new(); bm.from_mesh(mesh)
    remove = []
    for f in bm.faces:
        p = f.calc_center_median()
        if abs(p.x) < 2.005 and p.z < 2.6: remove.append(f)
    bmesh.ops.delete(bm, geom=remove, context='FACES')
    loose = [v for v in bm.verts if not v.link_faces]
    if loose: bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.to_mesh(mesh); bm.free(); mesh.update()

def prepare_one(key):
    ensure_scene()
    spec = next(s for s in SPECS if s[0] == key)
    _, filename, target, budget, resolution = spec
    game = bpy.data.collections.get('SDC_ExpansionModules')
    if game is None:
        game = bpy.data.collections.new('SDC_ExpansionModules')
        bpy.context.scene.collection.children.link(game)
    old = bpy.data.objects.get('Industrial_' + key)
    if old is not None: bpy.data.objects.remove(old, do_unlink=True)
    src = next(o for o in bpy.data.collections['RAW_NEXT_'+key].objects if o.type == 'MESH')
    mesh = src.data.copy(); mesh.transform(src.matrix_world)
    obj = bpy.data.objects.new('Industrial_'+key, mesh); game.objects.link(obj)
    if key in ['infill_1m', 'infill_2m', 'catwalk', 'guardrail']:
        mesh.transform(Matrix.Rotation(math.pi/2, 4, 'Z'))
    cap = material('SDC_Expansion_CutEdges', (.24, .32, .36))
    cap_index = len(mesh.materials); mesh.materials.append(cap)
    lo, hi = bounds(mesh); dim = hi-lo
    repair = 'Grounded, axes aligned, optimised; source retained.'
    deck_reference = None
    if key == 'window_panel':
        # Isolate the window-bearing front wall and discard the other three walls/roof.
        clip(mesh, 1, lo.y+dim.y*.145, True, cap_index)
        clip(mesh, 2, lo.z+dim.z*.755, True, cap_index)
        clip(mesh, 0, lo.x+dim.x*.035, False, cap_index)
        clip(mesh, 0, hi.x-dim.x*.035, True, cap_index)
        repair = 'Single window wall extracted from generated room; roof and return walls removed, cuts capped.'
    elif key == 'roller_shutter':
        clip(mesh, 0, lo.x+dim.x*.145, False, cap_index)
        clip(mesh, 0, hi.x-dim.x*.145, True, cap_index)
        clip(mesh, 2, lo.z+dim.z*.805, True, cap_index)
        repair = 'Only curtain retained; side jambs and top roller removed; independent 4 x 2.6 m panel.'
    elif key == 'catwalk':
        deck_reference = lo.z + dim.z*.61
        clip(mesh, 2, lo.z+dim.z*.54, False, cap_index)
        repair = 'Support legs removed; floor top calibrated at 0.12 m; open ends retained.'
    lo, hi = bounds(mesh); dim = hi-lo
    for v in mesh.vertices:
        x = (v.co.x-(lo.x+hi.x)/2)/dim.x*target[0]
        y = (v.co.y-(lo.y+hi.y)/2)/dim.y*target[1]
        z = (v.co.z-lo.z)/dim.z
        if key == 'freight_frame':
            # Preserve a four metre clear opening with quarter-metre jambs.
            t = abs(x)/(target[0]/2)
            x = (1 if x >= 0 else -1)*(t/.76*2 if t < .76 else 2+(t-.76)/.24*.25)
        if key == 'catwalk':
            split = (deck_reference-lo.z)/dim.z
            z = z/split*.12 if z <= split else .12+(z-split)/(1-split)
        elif key == 'loading_dock':
            z = z/.85*.8 if z <= .85 else .8+(z-.85)/.15*.18
        elif key == 'workbench':
            z = z/.79*.9 if z <= .79 else .9+(z-.79)/.21*.28
        else: z *= target[2]
        v.co = (x, y, z)
    mesh.update()
    if key == 'freight_frame':
        remove_inside_portal(mesh)
        repair = 'Freight opening cleared to 4 x 2.6 m; no door leaf or floor remains.'
    if key == 'loading_dock':
        bm=bmesh.new();bm.from_mesh(mesh)
        remove=[f for f in bm.faces if abs(f.calc_center_median().x)<.88
            and f.calc_center_median().y<-.83 and f.calc_center_median().z>.805]
        bmesh.ops.delete(bm,geom=remove,context='FACES')
        loose=[v for v in bm.verts if not v.link_faces]
        if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
        bm.to_mesh(mesh);bm.free();mesh.update()
        repair='Dock surface calibrated at 0.8 m; central front rail opened for the ramp.'
    images = {}
    for slot, mat in enumerate(list(mesh.materials)):
        if not mat: continue
        copy = mat.copy(); copy.name = 'SDC_'+key+'_Material'; copy.use_backface_culling = False
        mesh.materials[slot] = copy
        for node in copy.node_tree.nodes:
            if node.type == 'TEX_IMAGE' and node.image:
                image_key = node.image.name
                if image_key not in images:
                    im = node.image.copy(); im.name = 'SDC_'+key+'_'+str(len(images))
                    im.scale(resolution, resolution); im.pack(); images[image_key] = im
                node.image = images[image_key]
    bpy.ops.object.select_all(action='DESELECT')
    obj.hide_set(False); obj.select_set(True); bpy.context.view_layer.objects.active = obj
    triangles = sum(len(p.vertices)-2 for p in mesh.polygons)
    if triangles > budget:
        modifier = obj.modifiers.new('Mobile_Budget', 'DECIMATE')
        modifier.ratio = budget/triangles; modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.validate(); obj.data.update()
    obj['module_id'] = key; obj['source_file'] = filename; obj['repair'] = repair; obj['units'] = 'metres'
    # GLB is the existing project's export format; this Blender reports no dynamic format enum list.
    bpy.ops.export_scene.gltf(filepath=OUT+key+'.glb', export_format='GLB', use_selection=True, use_active_scene=True,
        export_extras=True, export_image_format='JPEG', export_jpeg_quality=88)
    lo, hi = bounds(obj.data); dim = hi-lo
    result = dict(id='industrial_modular/'+key, key=key, source_file=filename,
        path='res://assets/environment/industrial_modular/'+key+'.glb',
        min=[lo.x,lo.z,-hi.y], size=[dim.x,dim.z,dim.y],
        triangles=sum(len(p.vertices)-2 for p in obj.data.polygons),
        texture_resolution=resolution, object=obj.name, repair=repair)
    obj['export_record'] = json.dumps(result)
    index = [s[0] for s in SPECS].index(key)
    obj.location = ((index%4)*6, (index//4)*5, 0)
    return result

def prepare_batch(keys):
    results = [prepare_one(key) for key in keys]
    preview = bpy.data.collections.get('Expansion_Working')
    if preview is not None: preview.hide_viewport = True; preview.hide_render = True
    print('EXPANSION_EXPORTS '+json.dumps(results))

def prepare_utility_parts():
    ensure_scene()
    game = bpy.data.collections['SDC_ExpansionModules']
    results = []
    for key in ['platform_access','dock_ramp']:
        old=bpy.data.objects.get('Industrial_'+key)
        if old is not None:bpy.data.objects.remove(old,do_unlink=True)
    # Reuse the existing elevated platform; open its east handrail to connect the new bridge.
    mesh = bpy.data.objects['Industrial_platform'].data.copy()
    bm = bmesh.new(); bm.from_mesh(mesh)
    remove = [f for f in bm.faces if f.calc_center_median().x > .78
        and abs(f.calc_center_median().y) < .83 and f.calc_center_median().z > 3.08]
    bmesh.ops.delete(bm, geom=remove, context='FACES')
    loose = [v for v in bm.verts if not v.link_faces]
    if loose: bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.to_mesh(mesh); bm.free(); mesh.update()
    obj = bpy.data.objects.new('Industrial_platform_access', mesh); game.objects.link(obj)
    objects = [('platform_access', obj, '工业建筑二层金属平台.glb', 1024,
        'Existing platform east rail opened for a continuous stair-to-catwalk route.')]
    # A simple dock access ramp keeps the 0.8 m loading decks reachable.
    vertices = [(-.8,1,0),(.8,1,0),(-.8,1,.8),(.8,1,.8),(-.8,-1,0),(.8,-1,0)]
    faces = [(0,1,3,2),(0,4,5,1),(2,3,5,4),(0,2,4),(1,5,3)]
    mesh = bpy.data.meshes.new('DockRampMesh'); mesh.from_pydata(vertices, [], faces); mesh.update()
    mesh.materials.append(material('SDC_Dock_RampConcrete', (.30,.34,.35)))
    mesh.materials.append(material('SDC_Dock_RampYellow', (.82,.63,.15)))
    mesh.materials.append(material('SDC_Dock_RampDark', (.07,.10,.12)))
    bm = bmesh.new(); bm.from_mesh(mesh)
    for x1,x2 in [(-.79,-.70),(.70,.79)]:
        for i in range(10):
            a=-1+i*.2; b=a+.2
            vs=[bm.verts.new((x1,a,(a+1)*.4+.005)),bm.verts.new((x2,a,(a+1)*.4+.005)),
                bm.verts.new((x2,b,(b+1)*.4+.005)),bm.verts.new((x1,b,(b+1)*.4+.005))]
            f=bm.faces.new(vs);f.material_index=1 if i%2==0 else 2
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new('Industrial_dock_ramp',mesh);game.objects.link(obj)
    objects.append(('dock_ramp',obj,'工业仓库装卸台模块.glb',0,'Authored 1.6 x 2 m access ramp; high end matches 0.8 m dock surface.'))
    for i,(key,obj,source,res,repair) in enumerate(objects):
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        bpy.ops.export_scene.gltf(filepath=OUT+key+'.glb',export_format='GLB',use_selection=True,
            use_active_scene=True,export_extras=True,export_image_format='JPEG',export_jpeg_quality=88)
        lo,hi=bounds(obj.data);d=hi-lo
        record=dict(id='industrial_modular/'+key,key=key,source_file=source,
            path='res://assets/environment/industrial_modular/'+key+'.glb',
            min=[lo.x,lo.z,-hi.y],size=[d.x,d.z,d.y],
            triangles=sum(len(p.vertices)-2 for p in obj.data.polygons),texture_resolution=res,
            object=obj.name,repair=repair)
        obj['export_record']=json.dumps(record);obj['module_id']=key;obj['repair']=repair
        obj.location=(i*6,15,0);results.append(record)
    print('EXPANSION_EXPORTS '+json.dumps(results))

if __name__ == '__main__':
    import_sources()
    prepare_batch([s[0] for s in SPECS])
    prepare_utility_parts()
