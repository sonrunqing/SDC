#!/usr/bin/env python3
"""Blender: original low-poly operator and individually equipped armor/rig models."""
import bpy,bmesh,math,json,hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/operator';(OUT/'equipment').mkdir(parents=True,exist_ok=True)
items=json.loads((ROOT/'data/items.json').read_text())['items']
materials={}
def mat(name,color,metal=0,rough=.7):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    materials[name]=m;return m
CLOTH=mat('Ripstop forest gray',(.18,.235,.21));DARK=mat('Elastic and rubber',(.028,.039,.042),.03,.8)
STITCH=mat('Fabric raised seams',(.27,.31,.25));STEEL=mat('Brushed hardware',(.23,.28,.29),.65,.38)
SKIN=mat('Skin',(.48,.34,.24));LENS=mat('Smoked optical glass',(.07,.19,.20),.45,.18)
SAND=mat('Ranger coyote',(.35,.30,.20));OLIVE=mat('Ranger green',(.22,.29,.20));GRAY=mat('Graphite',(.16,.20,.22))
PALE=mat('Worn fabric edge',(.39,.39,.31));EYE=mat('Eye highlight',(.58,.68,.63),.1,.23)
def v(p):return Vector((p[0],-p[2],p[1]))
def clear():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for mesh in list(bpy.data.meshes):
        if mesh.users==0:bpy.data.meshes.remove(mesh)
def finish(o,name,m):o.name=name;o.data.materials.append(m);return o
def box(name,p,size,m=CLOTH,bevel=.015):
    bpy.ops.mesh.primitive_cube_add(size=1,location=v(p));o=bpy.context.object;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Rounded stitched edge','BEVEL');mod.width=min(bevel,min(size)*.22);mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,m)
def ellipsoid(name,p,size,m=CLOTH):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,radius=1,location=v(p));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for poly in o.data.polygons:poly.use_smooth=True
    return finish(o,name,m)
def segment(name,a,b,r1,r2,m=CLOTH,n=12):
    d=v(b)-v(a);bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r1,radius2=r2,depth=d.length,location=(v(a)+v(b))*.5);o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    for f in o.data.polygons:f.use_smooth=True
    return finish(o,name,m)
def strap(a,b,width=.025,m=DARK):return segment('Woven strap',a,b,width,width,m,6)
def seam(name,p,size):box(name,p,size,STITCH,.001)
def export(path,item_id,kind):
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();o=bpy.context.object;o.name=item_id
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
    o.data.calc_loop_triangles();tris=len(o.data.loop_triangles)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False,export_texcoords=False)
    print('OPERATOR_ASSET',item_id,tris,flush=True)
    return dict(id=item_id,kind=kind,path='res://'+str(path.relative_to(ROOT)),triangles=tris,sha256=hashlib.sha256(path.read_bytes()).hexdigest())
def body():
    box('Pelvis',(0,.94,.025),(.37,.24,.25),CLOTH,.055)
    ellipsoid('Fitted combat blouse',(0,1.255,.015),(.245,.285,.145),CLOTH)
    box('Standing collar',(0,1.49,.0),(.25,.09,.22),CLOTH,.022)
    for side in [-1,1]:
        hip=(side*.12,.95,.025);knee=(side*.15,.57,-.018);ankle=(side*.15,.19,.04)
        segment('Trouser upper leg',knee,hip,.105,.125,CLOTH)
        segment('Trouser lower leg',ankle,knee,.075,.10,CLOTH)
        box('Cargo thigh pocket',(side*.225,.78,.035),(.075,.20,.17),CLOTH,.018)
        seam('Pocket flap',(side*.264,.84,.035),(.009,.045,.16))
        box('Articulated kneepad',(side*.15,.56,-.104),(.145,.17,.052),DARK,.023)
        for y in [.525,.58]:box('Knee pad ridges',(side*.15,y,-.135),(.105,.012,.008),STEEL,.002)
        for y in [.32,.40,.68]:
            segment('Fabric joint folds',(side*.15,y,.03),(side*.15,y+.018,.03),.083,.088,STITCH)
        box('Laced combat boot',(side*.15,.10,-.045),(.185,.20,.32),DARK,.035)
        box('Boot outsole',(side*.15,.022,-.045),(.20,.043,.34),STEEL,.009)
        for y in [.10,.135,.17]:box('Boot lace',(side*.15,y,-.19),(.11,.012,.008),STITCH,.002)
    for a,b,c in [((-.24,1.43,.01),(-.34,1.19,-.10),(-.07,1.09,-.31)),((.24,1.43,.01),(.37,1.19,-.10),(.28,1.17,-.33))]:
        ellipsoid('Blouse shoulder',a,(.105,.115,.105),CLOTH)
        segment('Upper arm sleeve',b,a,.077,.097,CLOTH)
        ellipsoid('Elbow articulation',b,(.081,.085,.079),CLOTH)
        segment('Rolled combat sleeve',c,b,.058,.078,CLOTH)
        ellipsoid('Grip glove',c,(.062,.073,.045),DARK)
        for shift in [-.025,0,.025]:box('Glove finger',(c[0]+shift,c[1]-.025,c[2]-.026),(.018,.067,.026),DARK,.006)
        box('Forearm reinforced patch',((b[0]+c[0])*.5,(b[1]+c[1])*.5-.01,(b[2]+c[2])*.5-.037),(.08,.10,.02),STITCH,.008)
    segment('Neck',(0,1.46,.0),(0,1.59,.0),.067,.065,SKIN)
    ellipsoid('Balaclava head',(0,1.67,.0),(.103,.135,.096),DARK)
    ellipsoid('Exposed eye area',(0,1.696,-.076),(.086,.032,.026),SKIN)
    for x in [-.036,.036]:
        ellipsoid('Eye socket',(x,1.697,-.101),(.021,.008,.006),DARK)
        ellipsoid('Eye reflection',(x,1.699,-.107),(.008,.004,.0025),EYE)
    box('Nose bridge',(0,1.672,-.098),(.025,.041,.028),DARK,.01)
    segment('Tactical neck scarf',(0,1.50,.0),(0,1.56,.0),.083,.087,CLOTH)
    for x in [-.06,0,.06]:box('Scarf folds',(x,1.524,-.075),(.018,.046,.025),STITCH,.003)
    box('Belt',(0,.99,.005),(.405,.055,.29),DARK,.007)
    box('Belt buckle',(0,.99,-.155),(.075,.041,.015),STEEL,.004)
    box('Pistol holster',(-.245,.91,.01),(.09,.25,.14),DARK,.018)
    strap((-.245,.83,.02),(-.245,.87,.02),.085,DARK)
    box('Thigh med pouch',(.25,.87,.04),(.08,.16,.14),OLIVE,.012)
    box('Sleeve insignia',(-.32,1.36,-.041),(.06,.065,.014),DARK,.004)
    box('Insignia green band',(-.32,1.36,-.05),(.043,.012,.006),OLIVE,.001)
def gear(item):
    cat=item['category'];level=item.get('level',1);idx=sum(map(ord,item['id']))
    color=[OLIVE,SAND,GRAY][idx%3]
    if cat=='helmet':
        ellipsoid('Ballistic shell',(0,1.766,.005),(.121+level*.001,.105,.114),color)
        box('Helmet front rim',(0,1.725,-.102),(.20,.023,.037),color,.009)
        for x in [-.114,.114]:
            box('Accessory rail',(x,1.758,.01),(.018,.033,.13),STEEL,.004)
            box('Ear communications',(x,1.672,.023),(.035,.076,.063),DARK,.01)
            segment('Chin retention',(x*.9,1.711,-.04),(x*.55,1.58,-.035),.009,.009,DARK,6)
            for z in [-.025,.015,.055]:box('Rail socket',(x*1.10,1.758,z),(.008,.015,.014),DARK,.001)
        box('Front optic plate',(0,1.775,-.109),(.058,.049,.014),STEEL,.004)
        box('Velcro top patch',(0,1.859,.005),(.07,.007,.07),DARK,.003)
        if level>=3:box('Rear counterweight',(0,1.78,.112),(.092,.067,.025),DARK,.009)
    elif cat=='visor':
        for side in [-1,1]:box('Face shield hinge',(side*.12,1.708,-.04),(.025,.029,.058),STEEL,.004)
        box('Clear ballistic face shield',(0,1.65,-.135),(.213,.15,.014),LENS,.012)
        box('Face shield edge',(0,1.576,-.138),(.212,.012,.018),DARK,.004)
        box('Shield locking tab',(.11,1.68,-.13),(.012,.04,.02),STEEL,.003)
    elif cat in ['body_armor','rig','armored_rig']:
        # A cloth rig carries pouches outside armor; it has no rigid plate bulk.
        plain_rig=cat=='rig'
        if plain_rig:color=SAND
        box('Carrier front panel',(0,1.276,-.158 if plain_rig else -.124),(.414,.425,.022 if plain_rig else .09),color,.01 if plain_rig else .045)
        box('Carrier rear panel',(0,1.275,.168 if plain_rig else .148),(.414,.41,.02 if plain_rig else .08),color,.008 if plain_rig else .04)
        for x in [-.162,.162]:
            box('Padded shoulder strap',(x,1.464,.01),(.064,.042,.29),color,.012)
            box('Quick release clip',(x,1.443,-.143),(.045,.038,.022),DARK,.004)
        for y in [1.15,1.20,1.25,1.30,1.35]:
            for x in [-.14,-.07,0,.07,.14]:box('MOLLE webbing',(x,y,-.174),(.058,.012,.009),STITCH,.002)
        count=4 if cat in ['rig','armored_rig'] and item.get('capacity',0)>=18 else 3
        for k in range(count):
            x=(k-(count-1)*.5)*.085
            box('Magazine utility pouch',(x,1.19,-.205),(.074,.175,.074),color,.01)
            box('Pouch pull tab',(x,1.28,-.243),(.038,.023,.008),DARK,.003)
        box('Chest identification patch',(.065,1.399,-.176),(.115,.038,.008),DARK,.002)
        for x in [-.22,.22]:box('Cummerbund',(x,1.19,.005),(.05,.17,.23),color,.015)
        if not plain_rig and level>=3:box('Abdomen protection',(0,1.024,-.132),(.19,.10,.04),color,.015)
    elif cat=='backpack':
        capacity=item['capacity'];h=.37+capacity*.004;w=.27+capacity*.002
        box('Main pack',(0,1.23,.26),(w,h,.22),color,.045)
        box('Top lid',(0,1.23+h*.5,.27),(w+.015,.055,.24),color,.02)
        box('External pocket',(0,1.16,.39),(w*.8,h*.45,.06),color,.018)
        for x in [-w*.5,w*.5]:
            box('Bottle side pocket',(x,1.12,.26),(.065,.16,.16),color,.015)
            box('Compression strap',(x,1.30,.26),(.023,.018,.23),DARK,.002)
        for x in [-.12,.12]:
            box('Backpack shoulder harness',(x,1.425,.02),(.048,.035,.35),color,.009)
            box('Harness clip',(x,1.41,-.12),(.035,.033,.022),DARK,.004)
        for y in [1.10,1.17,1.24]:box('Rear compression webbing',(0,y,.425),(w*.76,.014,.008),STITCH,.002)
assets=[];clear();body();assets.append(export(OUT/'operator.glb','operator','body'))
for item in items:
    if item['kind']=='armor':
        clear();gear(item);assets.append(export(OUT/'equipment'/f'{item["id"]}.glb',item['id'],item['category']))
(OUT/'LICENSE.txt').write_text('Original SDC procedural operator and equipment models.\nCC0 1.0 Universal. https://creativecommons.org/publicdomain/zero/1.0/\n')
(ROOT/'data/operator_models.json').write_text(json.dumps(dict(schema_version=1,units='metres',origin='feet, facing -Z',assets=assets),ensure_ascii=False,indent=2)+'\n')
print('OPERATOR_COMPLETE',len(assets),sum(x['triangles'] for x in assets),flush=True)
