"""Original detailed SDC valuable meshes and transparent studio icons.

Submit these native function definitions through MCP, then call init(), build(ids),
render(ids), classify(definitions) and save(). No file execution is needed.
All geometry, lettering and materials are original; no paid service.
Editable sources live outside the Godot project, exported GLBs use metre units.
"""
import bpy, json, math
from mathutils import Vector

ROOT = 'D:/aa/SDC/SDC'
OUT = ROOT+'/assets/valuables'
ICONS = ROOT+'/assets/icons/items'
SOURCE = 'D:/aa/SDC/art_source/valuables'
CATALOG = {}
TAU = math.tau
CTX = {"scene": None}
M = {}
ASSETS = {}
PARTS = []

def enum_property(owner, prop, preferred):
    properties=getattr(owner,'properties',None) or owner.bl_rna.properties
    values = {e.identifier for e in properties[prop].enum_items}
    return next(p for p in preferred if p in values)

def mat(name, color, metal=0, rough=.45):
    m=bpy.data.materials.get('V / '+name) or bpy.data.materials.new('V / '+name);m.use_nodes=True
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal
    p.inputs['Roughness'].default_value=rough
    m.diffuse_color=(*color,1)
    M[name]=m
    return m

def init():
    CTX["scene"]=bpy.data.scenes.get('SDC_Valuables_Studio') or bpy.data.scenes.new('SDC_Valuables_Studio')
    bpy.context.window.scene=CTX["scene"]
    CTX["scene"].unit_settings.scale_length=1
    CTX["scene"].render.resolution_x=640;CTX["scene"].render.resolution_y=640
    CTX["scene"].render.resolution_percentage=100;CTX["scene"].render.film_transparent=True
    CTX["scene"].render.image_settings.file_format=enum_property(CTX["scene"].render.image_settings,'file_format',['PNG'])
    CTX["scene"].render.image_settings.color_mode=enum_property(CTX["scene"].render.image_settings,'color_mode',['RGBA'])
    CTX["scene"].world=bpy.data.worlds.get('Valuables studio world') or bpy.data.worlds.new('Valuables studio world');CTX["scene"].world.use_nodes=True
    bg=next(n for n in CTX["scene"].world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.65,.71,.78,1);bg.inputs['Strength'].default_value=.55
    for args in [
        ('ivory',(.70,.72,.65),0,.57),('paper',(.82,.77,.62),0,.77),
        ('ink',(.035,.053,.064),.05,.56),('rubber',(.035,.046,.048),0,.76),
        ('steel',(.49,.57,.60),.72,.29),('aluminium',(.64,.70,.72),.68,.32),
        ('dark_metal',(.15,.20,.23),.65,.34),('brass',(.62,.43,.17),.73,.30),
        ('gold',(.72,.48,.16),.82,.26),('copper',(.65,.29,.13),.75,.30),
        ('teal',(.22,.38,.40),.15,.47),('sage',(.36,.43,.34),.1,.6),
        ('ochre',(.64,.47,.21),.10,.5),('red',(.51,.15,.12),.18,.48),
        ('blue',(.17,.36,.48),.30,.30),('glass',(.10,.34,.45),.45,.12),
        ('pcb',(.14,.28,.22),.17,.53),('ceramic',(.61,.60,.50),.16,.47),
    ]:mat(*args)
    for root in CTX["scene"].objects:
        if root.type=='EMPTY' and 'asset_record' in root:
            record=dict(root['asset_record']);record['blender_size']=list(record['blender_size'])
            ASSETS[record['id']]=dict(root=root,parts=list(root.children),record=record)
    return CTX["scene"]

def part(o,name,material):
    o.name='V / '+name
    o.data.materials.append(M[material]);PARTS.append(o)
    return o

def box(name,p,size,material='steel',bevel=.002,rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p)
    o=bpy.context.object;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        valid={e.identifier for e in bpy.types.Modifier.bl_rna.properties['type'].enum_items}
        mod=o.modifiers.new('Soft machined edges',next(x for x in valid if x=='BEVEL'))
        mod.width=min(bevel,min(size)*.22);mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if rotation:o.rotation_euler=rotation
    return part(o,name,material)

def cyl(name,a,b,r,material='steel',vertices=24,r2=None):
    a,b=Vector(a),Vector(b);direction=b-a
    if r2 is None:bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=direction.length,location=(a+b)*.5)
    else:bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r2,depth=direction.length,location=(a+b)*.5)
    o=bpy.context.object;o.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
    for poly in o.data.polygons:poly.use_smooth=len(poly.vertices)==4
    return part(o,name,material)

def sphere(name,p,scale,material='steel',segments=24,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=p)
    o=bpy.context.object;o.scale=scale
    for face in o.data.polygons:face.use_smooth=True
    return part(o,name,material)

def tube(name,p,outer,inner,height,material='steel',segments=48):
    x,y,z=p;verts=[]
    for zz,rr in [(z-height*.5,outer),(z+height*.5,outer),(z-height*.5,inner),(z+height*.5,inner)]:
        verts.extend((x+rr*math.cos(TAU*k/segments),y+rr*math.sin(TAU*k/segments),zz) for k in range(segments))
    faces=[]
    for k in range(segments):
        j=(k+1)%segments
        faces.extend([(k,j,segments+j,segments+k),(2*segments+k,3*segments+k,3*segments+j,2*segments+j),(k,2*segments+k,2*segments+j,j),(segments+k,segments+j,3*segments+j,3*segments+k)])
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);CTX["scene"].collection.objects.link(o)
    for f in me.polygons:f.use_smooth=f.index%4<2
    return part(o,name,material)

def path(name,points,r,material='rubber',cyclic=False):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=8
    curve.bevel_depth=r;curve.bevel_resolution=2
    spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
    for dest,p in zip(spline.points,points):dest.co=(*p,1)
    spline.use_cyclic_u=cyclic
    o=bpy.data.objects.new(name,curve);CTX["scene"].collection.objects.link(o)
    return part(o,name,material)

def arc(name,p,r,start,end,thick,material='steel',n=48):
    return path(name,[(p[0]+r*math.cos(start+(end-start)*i/n),p[1]+r*math.sin(start+(end-start)*i/n),p[2]) for i in range(n+1)],thick,material)

def text(value,p,size=.009,material='ink',rotation=None):
    curve=bpy.data.curves.new('Original lettering','FONT');curve.body=value
    curve.size=size;curve.align_x=enum_property(curve,'align_x',['CENTER'])
    curve.extrude=.00006;curve.resolution_u=2
    o=bpy.data.objects.new('Lettering '+value,curve);CTX["scene"].collection.objects.link(o);o.location=p
    if rotation:o.rotation_euler=rotation
    return part(o,'Lettering '+value,material)

def screw(p,r=.0024,axis=(0,0,1),material='steel'):
    d=Vector(axis)*.0012
    cyl('Flush fastener',Vector(p)-d,Vector(p)+d,r,material,8)
    # A real inset-looking dark head slot, not a texture on the whole model.
    if abs(axis[2])>.5:box('Driver slot',(p[0],p[1],p[2]+.0013),(r*1.4,.0005,.0003),'ink',0)

def wire():
    for j in range(3):
        arc('Ivory cable winding',(0,0,.014+j*.012),.063,0,TAU,.006,'ivory',64)
    for angle in [.1,2.2,4.3]:
        p=(math.cos(angle)*.063,math.sin(angle)*.063,.027)
        box('Fabric cable tie',p,(.021,.014,.043),'sage',.001,rotation=(0,0,angle))
    path('Cable tail A',[(.063,0,.038),(.088,-.017,.026),(.103,-.052,.018),(.126,-.064,.018)],.005,'ivory')
    path('Cable tail B',[(.01,-.062,.013),(.041,-.093,.014),(.085,-.099,.018),(.108,-.091,.018)],.005,'rubber')
    for p in [(.126,-.064,.018),(.108,-.091,.018)]:
        cyl('Heat shrink collar',(p[0]-.006,p[1],p[2]),(p[0]+.005,p[1],p[2]),.006,'red',16)
        for k in range(7):
            a=TAU*k/7
            cyl('Exposed copper strand',(p[0]+.005,p[1]+.0025*math.cos(a),p[2]+.0025*math.sin(a)),(p[0]+.021,p[1]+.0025*math.cos(a),p[2]+.0025*math.sin(a)),.0008,'copper',8)
    box('Cable identification tag',(-.018,-.055,.055),(.055,.025,.002),'paper',.0004)
    text('PVC 24V',(-.018,-.058,.057),.007)

def battery():
    box('Power cell housing',(0,0,.092),(.125,.085,.17),'ochre',.009)
    for z in [.014,.163]:box('Impact-resistant end cap',(0,0,z),(.131,.091,.026),'dark_metal',.004)
    box('Identification inset',(0,-.044,.092),(.092,.003,.091),'ivory',.001)
    front=(math.pi/2,0,0)
    text('DC 24V',(0,-.046,.105),.014,'ink',front)
    text('INDUSTRIAL',(0,-.046,.086),.0075,'ink',front)
    text('8.0 Ah',(0,-.046,.064),.010,'ink',front)
    for x,material in [(-.038,'red'),(.038,'dark_metal')]:
        cyl('Insulated terminal boot',(x,0,.175),(x,0,.187),.013,material)
        cyl('Copper contact',(x,0,.185),(x,0,.200),.007,'brass',16)
    for x in [-.054,.054]:
        for y in [-.031,.031]:screw((x,y,.180))
    path('Carry loop',[(-.025,.020,.18),(-.025,.020,.216),(.025,.020,.216),(.025,.020,.18)],.006,'rubber')
    for i in range(5):box('Side cooling rib',(.064,.027-i*.013,.09),(.004,.004,.09),'dark_metal',.0007)

def tools():
    box('Precision tool case',(0,0,.022),(.255,.17,.043),'teal',.008)
    box('Foam tool bed',(0,0,.045),(.231,.147,.009),'rubber',.003)
    for x in [-.103,.103]:
        box('Case latch',(x,-.087,.028),(.028,.012,.023),'steel',.002)
        cyl('Hinge',(x,.080,.048),(x+.028,.080,.048),.008,'dark_metal',16)
    # Upright, open lid leaves the machined tools clearly visible from above.
    box('Raised lid',(0,.096,.111),(.252,.019,.129),'teal',.007,rotation=(math.radians(-17),0,0))
    box('Lid lining',(0,.083,.111),(.223,.006,.105),'ivory',.003,rotation=(math.radians(-17),0,0))
    text('PRECISION / 06',(0,.073,.127),.012,'ink',(math.pi/2,0,0))
    for i in range(4):
        x=-.083+i*.041
        cyl('Driver grip',(x,-.060,.058),(x,.000,.058),.011,'ochre' if i%2 else 'sage',16)
        for y in [-.048,-.037,-.026]:cyl('Grip collar',(x,y-.001,.058),(x,y+.001,.058),.0116,'dark_metal',16)
        cyl('Precision shaft',(x,0,.058),(x,.057,.058),.003,'steel',12)
        box('Bit tip',(x,.060,.058),(.004,.009,.002),'dark_metal',.0003)
    x=.083
    box('Digital caliper rail',(x,-.005,.061),(.012,.133,.007),'aluminium',.001)
    box('Caliper readout',(x,-.015,.07),(.035,.027,.012),'dark_metal',.002)
    box('LCD',(x,-.016,.077),(.025,.016,.001),'ivory',.0004)
    text('12.40',(x,-.020,.079),.0055)
    for y in [.049,.068]:box('Caliper jaws',(x-.010,y,.06),(.040,.006,.012),'steel',.001)
    path('Open carry handle',[(-.033,-.091,.020),(-.033,-.119,.02),(.033,-.119,.02),(.033,-.091,.020)],.006,'rubber')

def filter_cartridge():
    cyl('Pleated core',(0,0,.018),(0,0,.177),.043,'paper',48)
    for k in range(64):
        angle=TAU*k/64
        box('Filter pleat',(.045*math.cos(angle),.045*math.sin(angle),.096),(.006,.002,.151),'ivory',.0003,rotation=(0,0,angle))
    for z in [.014,.183]:
        tube('Machined end ring',(0,0,z),.053,.024,.018,'aluminium')
        tube('Rubber gasket',(0,0,z+(.011 if z>.1 else -.011)),.048,.026,.006,'rubber')
    tube('Open inner core',(0,0,.100),.027,.022,.170,'dark_metal',32)
    for a in [0,TAU/3,TAU*2/3]:
        cyl('End cap spoke',(.025*math.cos(a),.025*math.sin(a),.191),(.048*math.cos(a),.048*math.sin(a),.191),.002,'steel',8)
    box('Service label',(0,-.048,.096),(.033,.003,.048),'blue',.001)
    text('F-04',(0,-.050,.101),.009,'ivory',(math.pi/2,0,0))
    text('FLOW',(0,-.050,.086),.006,'ivory',(math.pi/2,0,0))

def radio():
    box('Sealed field radio',(0,0,.101),(.132,.080,.194),'teal',.009)
    box('Protective bumper',(0,.001,.027),(.141,.089,.038),'rubber',.005)
    box('Front recessed panel',(0,-.043,.104),(.114,.008,.153),'dark_metal',.003)
    box('LCD frame',(0,-.049,.145),(.099,.006,.045),'steel',.002)
    box('Blue LCD',(0,-.053,.145),(.087,.002,.033),'blue',.001)
    text('144.025',(0,-.055,.146),.014,'ivory',(math.pi/2,0,0))
    text('ENCRYPTED',(0,-.055,.135),.0055,'ivory',(math.pi/2,0,0))
    for row in range(4):
        for col in range(3):
            x=-.032+col*.032;z=.100-row*.020
            box('Rubber keypad',(x,-.051,z),(.023,.007,.014),'rubber',.002)
            text(str(row*3+col+1) if row<3 else ['*','0','#'][col],(x,-.055,z-.003),.007,'ivory',(math.pi/2,0,0))
    for x in [-.046,.046]:
        for z in [.173,.034]:screw((x,-.055,z),axis=(0,-1,0))
    for y in [-.022,.021]:
        for z in [.08,.105,.13,.155]:box('Heat sink rib',(.068,y,z),(.004,.014,.012),'dark_metal',.001)
    for x in [-.038,.027]:
        cyl('Rotary control',(x,0,.196),(x,0,.216),.014,'rubber',24)
        for k in range(12):
            a=TAU*k/12;cyl('Knurl',(x+.013*math.cos(a),.013*math.sin(a),.198),(x+.013*math.cos(a),.013*math.sin(a),.214),.0012,'steel',6)
    cyl('Antenna boot',(-.043,.020,.21),(-.043,.020,.235),.008,'rubber',16)
    cyl('Flexible antenna',(-.043,.020,.233),(-.058,.026,.309),.003,'dark_metal',12,r2=.0016)

def processor():
    box('Layered green substrate',(0,0,.008),(.118,.118,.010),'pcb',.001)
    box('Ceramic chip package',(0,0,.018),(.073,.073,.014),'ceramic',.002)
    box('Heat spreader',(0,0,.027),(.059,.059,.006),'steel',.001)
    text('SDC C4',(0,.004,.031),.011,'ink')
    text('086 / 64',(0,-.013,.031),.006,'ink')
    for side in [-1,1]:
        for k in range(16):
            a=-.048+k*.0064
            box('Gold contact',(side*.055,a,.014),(.008,.003,.002),'gold',.0003)
            box('Gold contact',(a,side*.055,.014),(.003,.008,.002),'gold',.0003)
    for x in [-.047,.047]:
        for y in [-.032,0,.032]:
            box('Surface capacitor',(x,y,.016),(.007,.012,.005),'ivory',.0004)
            for dy in [-.0055,.0055]:box('Solder joint',(x,y+dy,.016),(.008,.002,.005),'steel',.0002)
    for x in [-.043,-.025,0,.025,.043]:
        path('Etched copper trace',[(x,.037,.014),(x,.043,.014),(x+.005,.048,.014)],.00045,'brass')
    for x in [-.052,.052]:
        for y in [-.052,.052]:tube('Alignment via',(x,y,.014),.0024,.001,.0015,'gold',12)

def watch():
    cyl('Watch case',(0,0,.018),(0,0,.033),.036,'steel',64)
    tube('Gold bezel',(0,0,.036),.036,.030,.007,'gold',64)
    cyl('Ivory dial',(0,0,.032),(0,0,.036),.030,'ivory',64)
    for k in range(60):
        a=TAU*k/60;r=.027
        box('Minute index',(r*math.sin(a),r*math.cos(a),.037),(.0008,.003 if k%5 else .006,.0007),'ink',0,rotation=(0,0,-a))
    for x,y in [(-.011,.005),(.011,.005),(0,-.012)]:
        tube('Chronograph rim',(x,y,.0375),.006,.005,.0007,'brass',24)
        cyl('Chronograph hand',(x,y,.038),(x+.003,y+.002,.038),.0005,'ink',8)
    for a,length,width,material in [(-.96,.019,.0015,'ink'),(.78,.023,.001,'ink'),(2.5,.025,.00055,'red')]:
        cyl('Dial hand',(0,0,.039),(length*math.sin(a),length*math.cos(a),.039),width,material,8)
    cyl('Hand pivot',(0,0,.039),(0,0,.041),.002,'gold',16)
    text('AUTOMATIC',(0,.013,.0377),.0031,'ink')
    for side in [-1,1]:
        for k in range(5):
            y=side*(.040+k*.011);z=.023-k*.0028
            box('Bracelet link',(0,y,z),(.034,.009,.008),'steel',.0014)
            box('Gold centre link',(0,y,z+.0045),(.014,.008,.002),'gold',.0006)
        for x in [-.014,.014]:box('Watch lug',(x,side*.035,.025),(.009,.016,.010),'steel',.001)
    cyl('Crown',(.034,0,.026),(.044,0,.026),.006,'gold',20)
    for y in [-.015,.015]:cyl('Chronograph pusher',(.032,y,.026),(.039,y,.026),.003,'steel',12)
    arc('Polished bezel reflection',(0,0,.040),.034,.25,1.25,.0008,'ivory',16)

def statue():
    box('Stepped obsidian plinth',(0,0,.015),(.130,.105,.03),'ink',.005)
    box('Gold plinth band',(0,0,.034),(.118,.093,.009),'brass',.002)
    box('Upper stone pedestal',(0,0,.046),(.104,.080,.018),'dark_metal',.003)
    box('Foundry name plate',(0,-.042,.043),(.069,.002,.013),'gold',.0005)
    text('HARBOUR 1896',(0,-.044,.040),.005,'ink',(math.pi/2,0,0))
    for x in [-.026,.026]:
        cyl('Falcon leg',(x,0,.055),(x,-.002,.104),.007,'gold',12)
        for y in [-.015,0,.015]:cyl('Grasping talon',(x,0,.063),(x-.004,y-.017,.056),.0028,'brass',10)
    sphere('Sculpted falcon body',(0,.003,.135),(.038,.033,.063),'gold')
    sphere('Falcon head',(0,-.014,.199),(.030,.027,.030),'gold')
    cyl('Beak',(0,-.036,.203),(0,-.065,.187),.012,'brass',12,r2=.001)
    for side in [-1,1]:
        sphere('Obsidian eye',(side*.024,-.027,.208),(.004,.004,.004),'ink',16,8)
        cyl('Sculpted brow',(side*.014,-.033,.216),(side*.030,-.020,.217),.003,'gold',10)
        # Overlapping, individually shaped flight feathers make the sculpture legible.
        for k in range(9):
            a=k/8;start=(side*.025,.010,.170-a*.022)
            end=(side*(.055+a*.065),.005+a*.020,.172-a*.077)
            cyl('Layered primary feather',start,end,.0075,'gold',10,r2=.0018)
            cyl('Engraved feather ridge',Vector(start)+Vector((0,-.005,.002)),Vector(end)+Vector((0,-.003,.002)),.001,'brass',6)
        for k in range(5):
            cyl('Shoulder covert',(side*.022,.0,.178-k*.008),(side*.055,.002,.169-k*.009),.008,'brass',10,r2=.002)
    for k in range(5):cyl('Tail feather',((k-2)*.008,.023,.112),((k-2)*.012,.053,.072),.007,'gold',10,r2=.002)

def documents():
    box('Leather-backed archive',(0,0,.011),(.199,.142,.020),'sage',.003)
    for k in range(9):box('Individual page edge',(.001*k/9,.001*k/9,.022+k*.0012),(.186,.132,.0007),'ivory',.0001)
    box('Manila archive cover',(0,0,.035),(.200,.145,.004),'paper',.001)
    box('Leather spine',(-.086,0,.037),(.026,.148,.009),'teal',.002)
    for y in [-.060,.060]:box('Brass corner protector',(.092,y,.039),(.015,.015,.003),'brass',.001)
    text('RESTRICTED',(.012,.032,.038),.014,'red')
    text('HARBOUR / 07',(.012,.011,.038),.008,'ink')
    for k in range(5):box('Printed index line',(.020,-.012-k*.007,.038),(.10-k*.005,.001,.0002),'ink',0)
    path('Archive sealing cord',[(-.101,-.030,.039),(0,-.030,.040),(.101,-.030,.039)],.0016,'ivory')
    cyl('Wax security seal',(.049,-.029,.040),(.049,-.029,.045),.016,'red',32)
    tube('Embossed seal ring',(.049,-.029,.046),.012,.0105,.001,'brass',32)
    text('S',(.049,-.035,.046),.013,'ivory')

def lens():
    cyl('Lens housing',(0,0,.010),(0,0,.040),.064,'dark_metal',64)
    for z in [.011,.039]:tube('Machined lens ring',(0,0,z),.067,.054,.008,'steel',64)
    tube('Front retaining ring',(0,0,.046),.061,.050,.006,'rubber',64)
    sphere('Coated convex optic',(0,0,.043),(.050,.050,.010),'glass',48,16)
    for k in range(72):
        a=TAU*k/72
        cyl('Fine knurled rim',(.064*math.cos(a),.064*math.sin(a),.018),(.064*math.cos(a),.064*math.sin(a),.035),.0012,'steel',6)
    for k in range(3):
        a=TAU*k/3;screw((.056*math.cos(a),.056*math.sin(a),.050),r=.002)
    arc('Cool optical highlight',(0,0,.052),.038,.35,1.65,.0012,'ivory',28)
    arc('Warm secondary reflection',(0,0,.051),.043,3.1,4.0,.0007,'blue',20)
    text('62 / OPTICAL',(0,-.055,.050),.006,'ivory')

def fuel():
    box('Pressed steel jerrycan',(0,0,.113),(.160,.083,.214),'red',.015)
    box('Welded rim',(0,0,.113),(.164,.087,.010),'brass',.002)
    box('Rubber base',(0,0,.016),(.165,.090,.022),'rubber',.004)
    for y in [-.044,.044]:
        cyl('Pressed X reinforcement',(-.055,y,.055),(.055,y,.172),.004,'red',12)
        cyl('Cross reinforcement',(.055,y,.055),(-.055,y,.172),.004,'red',12)
    for x in [-.050,.018]:box('Handle upright',(x,.003,.244),(.015,.035,.063),'red',.004)
    box('Open carry handle',(-.016,.003,.273),(.083,.035,.018),'red',.005)
    cyl('Filler neck',(.054,-.006,.212),(.062,-.006,.238),.019,'dark_metal',32)
    cyl('Fuel cap',(.062,-.006,.240),(.062,-.006,.249),.023,'steel',24)
    box('Cap lever',(.062,-.006,.253),(.047,.009,.006),'dark_metal',.001)
    path('Cap safety chain',[(.073,-.008,.241),(.092,-.010,.215),(.088,-.025,.185),(.067,-.041,.181)],.0014,'steel')
    box('Fuel identification label',(0,-.046,.146),(.067,.002,.041),'ivory',.001)
    text('FUEL',(0,-.048,.148),.014,'ink',(math.pi/2,0,0))
    text('5 L',(0,-.048,.132),.009,'red',(math.pi/2,0,0))

def scrap():
    # A hollow precision flange, a toothed drive gear and a separate turned shaft.
    tube('CNC flange',(-.031,.010,.026),.056,.027,.028,'aluminium',48)
    for k in range(6):
        a=TAU*k/6
        tube('Mounting eye',(-.031+.046*math.cos(a),.010+.046*math.sin(a),.045),.008,.004,.008,'steel',16)
    tube('Drive gear',(.048,-.047,.018),.040,.013,.018,'brass',48)
    for k in range(28):
        a=TAU*k/28
        box('Gear tooth',(.048+.040*math.cos(a),-.047+.040*math.sin(a),.018),(.011,.007,.018),'brass',.001,rotation=(0,0,a))
    cyl('Turned shaft',(-.064,-.060,.070),(.061,.036,.070),.009,'steel',24)
    for t in [.2,.8]:
        p=Vector((-.064,-.060,.070)).lerp(Vector((.061,.036,.070)),t)
        d=Vector((.125,.096,0)).normalized()
        cyl('Shaft shoulder',p-d*.007,p+d*.007,.015,'dark_metal',24)
    for p in [(-.066,.066),(.022,.076)]:
        cyl('Hex bolt',(p[0],p[1],.009),(p[0],p[1],.035),.006,'steel',12)
        cyl('Hex head',(p[0],p[1],.034),(p[0],p[1],.043),.011,'aluminium',6)

def lathe(name,profile,material='steel',segments=48):
    verts=[(r*math.cos(TAU*k/segments),r*math.sin(TAU*k/segments),z) for r,z in profile for k in range(segments)]
    faces=[]
    for row in range(len(profile)-1):
        for k in range(segments):
            j=(k+1)%segments;faces.append((row*segments+k,row*segments+j,(row+1)*segments+j,(row+1)*segments+k))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);CTX['scene'].collection.objects.link(o)
    for f in mesh.polygons:f.use_smooth=True
    return part(o,name,material)

def bottle(label,body='ivory',cap='teal',height=.14,radius=.035):
    lathe('Formed bottle',[(0,0),(radius*.85,0),(radius,.008),(radius,height*.68),(radius*.58,height*.81),(radius*.54,height*.92),(0,height*.92)],body)
    cyl('Screw cap',(0,0,height*.88),(0,0,height),radius*.63,cap,32)
    for k in range(24):
        a=TAU*k/24
        cyl('Cap rib',(radius*.63*math.cos(a),radius*.63*math.sin(a),height*.90),(radius*.63*math.cos(a),radius*.63*math.sin(a),height*.98),.0009,'steel',6)
    box('Paper label',(0,-radius*.97,height*.42),(radius*1.6,.002,height*.32),'paper',.001)
    text(label,(0,-radius*1.02,height*.46),radius*.31,'ink',(math.pi/2,0,0))
    text('SDC / SEALED',(0,-radius*1.02,height*.34),radius*.13,'ink',(math.pi/2,0,0))

def industrial(item_id):
    if item_id=='loot_bearing':
        tube('Outer bearing race',(0,0,.018),.062,.047,.036,'steel',64)
        tube('Inner bearing race',(0,0,.018),.030,.020,.036,'aluminium',64)
        for k in range(12):
            a=TAU*k/12;sphere('Polished bearing ball',(.039*math.cos(a),.039*math.sin(a),.019),(.009,.009,.009),'steel',16,8)
        tube('Retaining cage',(0,0,.020),.045,.034,.003,'brass',48)
        text('6206 / SDC',(0,-.055,.037),.006,'ink')
    elif item_id=='loot_gauge':
        cyl('Pressure gauge case',(0,0,.015),(0,0,.040),.059,'steel',64)
        tube('Gauge bezel',(0,0,.044),.060,.052,.008,'dark_metal',64)
        cyl('White dial',(0,0,.040),(0,0,.043),.052,'ivory',64)
        for k in range(31):
            a=math.radians(-130+k*8.66)
            box('Scale tick',(.044*math.sin(a),.044*math.cos(a),.045),(.001,.005 if k%5 else .009,.0007),'ink',0,rotation=(0,0,-a))
        cyl('Gauge needle',(0,0,.046),(.025,.024,.046),.0014,'red',10)
        cyl('Dial spindle',(0,0,.044),(0,0,.049),.004,'dark_metal',16)
        text('MPa',(0,-.025,.045),.009)
        cyl('Threaded pressure fitting',(0,.052,.022),(0,.097,.022),.010,'brass',16)
        for y in [.071,.078,.085]:cyl('Fitting thread',(0,y,.022),(0,y+.003,.022),.012,'brass',16)
    else:
        box('Temperature transducer',(0,0,.064),(.057,.042,.083),'teal',.006)
        cyl('Stainless probe',(0,0,0),(0,0,-.115),.004,'steel',24)
        cyl('Hex process fitting',(0,0,.005),(0,0,.030),.014,'brass',6)
        for z in [-.004,-.010,-.016]:tube('Probe fitting thread',(0,0,z),.010,.006,.002,'steel',24)
        cyl('Sensor plug',(0,0,.103),(0,0,.125),.013,'rubber',24)
        for a in [0,TAU/3,2*TAU/3]:cyl('Connector contact',(.006*math.cos(a),.006*math.sin(a),.124),(.006*math.cos(a),.006*math.sin(a),.135),.0017,'brass',8)
        text('PT100',(0,-.022,.070),.010,'ivory',(math.pi/2,0,0))

def everyday(item_id):
    if item_id == 'loot_tape':
        tube('Wound fabric tape', (0, 0, 0.023), 0.06, 0.026, 0.046, 'sage', 64)
        tube('Cardboard core', (0, 0, 0.023), 0.027, 0.023, 0.047, 'paper', 48)
        for r in [0.043, 0.049, 0.055]:
            tube('Tape winding seam', (0, 0, 0.047), r, r - 0.0007, 0.0003, 'ivory', 64)
        box('Loose tape end', (0.063, -0.012, 0.013), (0.063, 0.04, 0.002), 'sage', 0.0003, rotation=(0, 0.1, -0.12))
        return
    if item_id == 'loot_sewing_kit':
        box('Sewing tin', (0, 0, 0.014), (0.15, 0.11, 0.028), 'teal', 0.006)
        box('Linen lining', (0, 0, 0.03), (0.138, 0.098, 0.006), 'paper', 0.002)
        for k in range(4):
            x = -0.05 + k * 0.032
            cyl('Thread spool', (x, 0.011, 0.03), (x, 0.011, 0.069), 0.012, 'ivory', 24)
            cyl('Cotton winding', (x, 0.011, 0.035), (x, 0.011, 0.063), 0.015, ['red', 'sage', 'blue', 'ochre'][k], 24)
            for z in [0.032, 0.067]:
                cyl('Spool flange', (x, 0.011, z - 0.001), (x, 0.011, z + 0.001), 0.017, 'paper', 24)
        for x in [-0.027, 0.027]:
            tube('Scissors handle', (x, -0.035, 0.036), 0.013, 0.008, 0.003, 'steel', 24)
        cyl('Scissors blade', (-0.025, -0.03, 0.036), (0.02, 0.03, 0.037), 0.002, 'steel', 8)
        cyl('Scissors blade', (0.025, -0.03, 0.036), (-0.02, 0.03, 0.037), 0.002, 'steel', 8)
        return
    if item_id == 'loot_thermos':
        cyl('Insulated flask', (0, 0, 0.013), (0, 0, 0.18), 0.036, 'steel', 48)
        cyl('Powder-coated sleeve', (0, 0, 0.028), (0, 0, 0.149), 0.037, 'blue', 48)
        cyl('Cup cap', (0, 0, 0.164), (0, 0, 0.206), 0.039, 'dark_metal', 48)
        tube('Cap lip', (0, 0, 0.207), 0.039, 0.035, 0.004, 'steel')
        text('0.5 L', (0, -0.038, 0.098), 0.011, 'ivory', (math.pi / 2, 0, 0))
        path('Flask carry loop', [(-0.02, 0.027, 0.18), (-0.02, 0.036, 0.232), (0.02, 0.036, 0.232), (0.02, 0.027, 0.18)], 0.003, 'rubber')
        return
    if item_id == 'loot_soap':
        box('Rounded soap bar', (0, 0, 0.023), (0.11, 0.07, 0.045), 'ivory', 0.011)
        box('Paper sleeve', (0, 0, 0.024), (0.046, 0.073, 0.048), 'paper', 0.005)
        text('PURE', (0, 0.005, 0.05), 0.014, 'teal')
        text('SOAP', (0, -0.014, 0.05), 0.008, 'teal')
        return
    if item_id == 'loot_toothbrush':
        path('Moulded toothbrush', [(-0.01, -0.09, 0.014), (0, -0.04, 0.013), (0.007, 0.025, 0.015), (0.006, 0.075, 0.022)], 0.009, 'ivory')
        box('Soft grip', (0, -0.042, 0.021), (0.013, 0.06, 0.004), 'blue', 0.001)
        box('Brush head', (0.006, 0.078, 0.023), (0.02, 0.039, 0.008), 'ivory', 0.003)
        for x in [-0.005, 0.005, 0.015]:
            for y in [0.065, 0.073, 0.081, 0.089]:
                cyl('Bristle tuft', (x, y, 0.027), (x, y, 0.038), 0.0022, 'teal' if x == 0.005 else 'ivory', 8)
        return
    if item_id == 'loot_toothpaste':
        o = cyl('Soft toothpaste tube', (0, -0.075, 0.022), (0, 0.055, 0.022), 0.023, 'ivory', 32)
        o.scale.x = 1.4
        o.scale.y = 0.65
        box('Crimped tube end', (0, -0.079, 0.022), (0.064, 0.009, 0.012), 'steel', 0.001)
        cyl('Screw cap', (0, 0.053, 0.022), (0, 0.08, 0.022), 0.017, 'blue', 24)
        box('Label colour band', (0, -0.017, 0.038), (0.045, 0.071, 0.002), 'teal', 0.001)
        text('DENTAL', (0, -0.02, 0.041), 0.009, 'ivory')
        return
    if item_id == 'loot_canned_food':
        cyl('Sealed food can', (0, 0, 0.006), (0, 0, 0.082), 0.047, 'steel', 48)
        cyl('Printed wrap', (0, 0, 0.012), (0, 0, 0.075), 0.0474, 'red', 48)
        for z in [0.008, 0.08]:
            tube('Rolled can rim', (0, 0, z), 0.049, 0.045, 0.005, 'aluminium', 48)
        tube('Pull tab', (0, -0.009, 0.085), 0.013, 0.007, 0.002, 'steel', 24)
        box('Front cream label', (0, -0.047, 0.045), (0.066, 0.002, 0.038), 'paper', 0.001)
        text('STEW', (0, -0.049, 0.045), 0.016, 'ink', (math.pi / 2, 0, 0))
        return
    if item_id == 'loot_coffee':
        bottle('COFFEE', 'brass', 'dark_metal', 0.145, 0.044)
        for k in range(12):
            sphere('Visible coffee bean', (0.025 * math.cos(k * 2.4), -0.035, 0.016 + k * 0.003), (0.005, 0.003, 0.007), 'ink', 12, 6)
        return
    if item_id == 'loot_lighter':
        box('Brushed lighter body', (0, 0, 0.043), (0.052, 0.018, 0.083), 'steel', 0.006)
        box('Flip lid', (-0.033, 0, 0.085), (0.048, 0.02, 0.028), 'steel', 0.004, rotation=(0, -0.7, 0))
        box('Perforated wind guard', (0, 0, 0.092), (0.029, 0.014, 0.021), 'dark_metal', 0.002)
        for x in [-0.008, 0, 0.008]:
            for z in [0.088, 0.096]:
                cyl('Wind guard recess', (x, -0.0075, z), (x, -0.009, z), 0.002, 'ink', 12)
        cyl('Flint wheel', (0.013, -0.006, 0.106), (0.013, 0.006, 0.106), 0.006, 'brass', 16)
        text('SDC', (0, -0.01, 0.045), 0.011, 'ink', (math.pi / 2, 0, 0))
        return
    if item_id == 'loot_flashlight':
        cyl('Flashlight grip', (0, 0, 0.014), (0, 0, 0.135), 0.022, 'sage', 32)
        for k in range(12):
            a = TAU * k / 12
            cyl('Grip flute', (0.022 * math.cos(a), 0.022 * math.sin(a), 0.025), (0.022 * math.cos(a), 0.022 * math.sin(a), 0.11), 0.0016, 'rubber', 8)
        cyl('Reflector head', (0, 0, 0.132), (0, 0, 0.166), 0.038, 'dark_metal', 48, r2=0.043)
        tube('Head bezel', (0, 0, 0.169), 0.044, 0.036, 0.008, 'steel', 48)
        cyl('Reflector', (0, 0, 0.169), (0, 0, 0.173), 0.035, 'ivory', 48)
        cyl('LED centre', (0, 0, 0.173), (0, 0, 0.176), 0.008, 'paper', 16)
        sphere('Rubber switch', (0, -0.022, 0.121), (0.008, 0.003, 0.01), 'red', 16, 8)
        return
    if item_id == 'loot_matches':
        box('Matchbox sleeve', (0, 0, 0.015), (0.074, 0.052, 0.029), 'paper', 0.002)
        box('Striking strip', (0.038, 0, 0.015), (0.002, 0.047, 0.014), 'red', 0.0003)
        box('Sliding match tray', (0, 0.02, 0.025), (0.064, 0.072, 0.009), 'ivory', 0.001)
        for x in [-0.023, -0.012, 0, 0.012, 0.023]:
            cyl('Wooden match', (x, -0.012, 0.033), (x, 0.051, 0.033), 0.0018, 'paper', 8)
            sphere('Match head', (x, 0.053, 0.033), (0.003, 0.005, 0.003), 'red', 12, 6)
        text('MATCHES', (0, -0.007, 0.038), 0.008, 'ink')
        return
    if item_id == 'loot_aa_cells':
        box('Battery pack backing', (0, 0.011, 0.007), (0.095, 0.135, 0.006), 'paper', 0.002)
        for x in [-0.027, 0.027]:
            for y in [-0.033, 0.031]:
                cyl('AA cell', (x, y - 0.025, 0.019), (x, y + 0.025, 0.019), 0.012, 'ochre', 24)
                cyl('Negative cell end', (x, y - 0.026, 0.019), (x, y - 0.021, 0.019), 0.012, 'dark_metal', 24)
                cyl('Positive cell cap', (x, y + 0.025, 0.019), (x, y + 0.028, 0.019), 0.006, 'steel', 16)
        text('LR6 / 4 PACK', (0, 0.06, 0.013), 0.008, 'ink')
        return
    if item_id == 'loot_book':
        for z in [0.005, 0.043]:
            box('Hardback cover', (0, 0, z), (0.123, 0.174, 0.009), 'blue', 0.002)
        box('Paper block', (0.003, 0, 0.024), (0.11, 0.16, 0.03), 'ivory', 0.001)
        box('Cloth spine', (-0.058, 0, 0.024), (0.013, 0.171, 0.04), 'teal', 0.002)
        for k in range(8):
            box('Page layer', (0.06, 0, 0.011 + k * 0.0035), (0.0005, 0.155, 0.0005), 'paper', 0)
        text('FIELD', (0, 0.027, 0.049), 0.021, 'paper')
        text('JOURNAL', (0, -0.002, 0.049), 0.015, 'paper')
        text('07 / GREY HARBOUR', (0, -0.055, 0.049), 0.006, 'paper')
        return
    tube('Glazed ceramic mug', (0, 0, 0.048), 0.042, 0.035, 0.09, 'ivory', 48)
    cyl('Mug base', (0, 0, 0.001), (0, 0, 0.006), 0.041, 'ivory', 48)
    tube('Blue glazed rim', (0, 0, 0.095), 0.043, 0.034, 0.006, 'blue', 48)
    path('Ceramic loop handle', [(0.042 + 0.027 * math.cos(TAU * k / 40), 0, 0.048 + 0.033 * math.sin(TAU * k / 40)) for k in range(41)], 0.006, 'ivory')
    text('PORT', (0, -0.043, 0.052), 0.012, 'teal', (math.pi / 2, 0, 0))

def metal_ingot(item_id):
    materials={'loot_copper_ingot':('copper','Cu / 99.9'), 'loot_aluminium_ingot':('aluminium','Al / 6061'), 'loot_titanium_ingot':('dark_metal','Ti / GRADE 5'),'loot_gold_bar':('gold','Au / 999.9')}
    material,label=materials[item_id]
    if item_id=='loot_gold_bar':
        for x,y,z in [(-.019,.012,.018),(.022,-.025,.042)]:
            verts=[(x+sx*w,y+sy*.072,zz) for zz,w in [(z-.017,.036),(z+.017,.030)] for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)]]
            faces=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
            me=bpy.data.meshes.new('Cast gold ingot');me.from_pydata(verts,[],faces);me.update()
            o=bpy.data.objects.new('Cast gold ingot',me);CTX['scene'].collection.objects.link(o);part(o,'Cast gold ingot','gold')
            text('Au',(x,y+.020,z+.018),.025,'brass');text('999.9 / 500 g',(x,y-.025,z+.018),.008,'brass')
    else:
        size=(.150,.068,.034) if item_id!='loot_titanium_ingot' else (.112,.085,.043)
        box('Machined metal billet',(0,0,size[2]/2),size,material,.005)
        text(label,(0,.012,size[2]+.001),.011,'ink' if material!='dark_metal' else 'ivory')
        text('LOT 0086',(0,-.017,size[2]+.001),.007,'ink' if material!='dark_metal' else 'ivory')
        if item_id=='loot_aluminium_ingot':
            for x in [-.060,.060]:tube('Milled bore',(x,0,size[2]),.009,.005,.003,'steel',24)
        else:
            for y in [-.029,-.025]:box('Machining groove',(0,y,size[2]+.0002),(.126,.0008,.0005),'steel',0)

def collectibles(item_id):
    if item_id=='loot_silver_coin':
        cyl('Silver commemorative coin',(0,0,.003),(0,0,.010),.052,'steel',64)
        for k in range(80):
            a=TAU*k/80;cyl('Reeded coin edge',(.052*math.cos(a),.052*math.sin(a),.004),(.052*math.cos(a),.052*math.sin(a),.009),.0005,'aluminium',6)
        tube('Raised coin border',(0,0,.012),.049,.046,.002,'aluminium',64)
        cyl('Anchor stem',(0,-.027,.013),(0,.024,.013),.002,'aluminium',10)
        tube('Anchor ring',(0,.029,.013),.006,.0035,.002,'aluminium',24)
        arc('Anchor flukes',(0,0,.013),.025,math.pi,TAU,.002,'aluminium',24)
        text('PORT 1912',(0,-.037,.013),.006,'ink')
    elif item_id=='loot_gem_ring':
        path('Gold ring band',[(.028*math.cos(TAU*k/64),0,.034+.028*math.sin(TAU*k/64)) for k in range(65)],.004,'gold')
        for x in [-.009,.009]:
            for y in [-.008,.008]:cyl('Gemstone claw',(x,y,.057),(x,y,.079),.0015,'gold',8)
        verts=[(r*math.cos(TAU*k/8),r*math.sin(TAU*k/8),z) for r,z in [(.003,.058),(.016,.071),(.010,.082)] for k in range(8)]
        faces=[tuple(range(16,24))]
        for row in range(2):
            for k in range(8):faces.append((row*8+k,row*8+(k+1)%8,(row+1)*8+(k+1)%8,(row+1)*8+k))
        me=bpy.data.meshes.new('Faceted gemstone');me.from_pydata(verts,[],faces);me.update()
        o=bpy.data.objects.new('Faceted gemstone',me);CTX['scene'].collection.objects.link(o);part(o,'Cut blue gemstone','glass')
    elif item_id=='loot_antique_compass':
        cyl('Brass compass case',(0,0,.008),(0,0,.027),.053,'brass',64)
        tube('Compass bezel',(0,0,.031),.055,.047,.007,'gold',64)
        cyl('Compass face',(0,0,.028),(0,0,.030),.047,'ivory',64)
        for k in range(32):
            a=TAU*k/32;box('Compass graduation',(.042*math.sin(a),.042*math.cos(a),.031),(.001,.005,.0006),'ink',0,rotation=(0,0,-a))
        for label,x,y in [('N',0,.027),('S',0,-.035),('E',.032,0),('W',-.032,0)]:text(label,(x,y,.032),.008,'ink')
        cyl('Red north needle',(0,0,.034),(.009,.025,.034),.002,'red',8,r2=.0001)
        cyl('South needle',(0,0,.034),(-.009,-.025,.034),.002,'steel',8,r2=.0001)
        lid=tube('Open compass cover',(0,0,0),.052,.045,.006,'brass',64);lid.location=(0,.064,.053);lid.rotation_euler.x=math.radians(65)
        path('Leather lanyard',[(-.037,-.03,.01),(-.070,-.065,.008),(-.015,-.10,.006),(.045,-.075,.005)],.002,'rubber')
    else:
        lathe('Antique porcelain vase',[(0,0),(.026,0),(.029,.014),(.041,.043),(.048,.079),(.038,.115),(.020,.143),(.018,.168),(.030,.183),(.028,.19),(.022,.19),(.015,.166)],'ivory',64)
        for z,r in [(.012,.029),(.175,.023),(.188,.029)]:tube('Gilt porcelain trim',(0,0,z),r,r-.0015,.004,'gold',64)
        for k in range(8):
            a=TAU*k/8;x=.047*math.cos(a);y=.047*math.sin(a)
            sphere('Cobalt floral medallion',(x,y,.079),(.006,.006,.021),'blue',16,8)
            for dz in [-.029,.029]:sphere('Cobalt leaf',(x*.82,y*.82,.079+dz),(.004,.004,.010),'blue',12,6)
        for side in [-1,1]:path('Porcelain handle',[(side*.020,0,.148),(side*.046,0,.142),(side*.055,0,.108),(side*.038,0,.102)],.004,'blue')

def precision(item_id):
    if item_id=='loot_multimeter':
        box('Meter shock boot',(0,0,.023),(.092,.156,.042),'ochre',.009)
        box('Meter inset face',(0,0,.046),(.077,.139,.007),'dark_metal',.003)
        box('LCD window',(0,.038,.051),(.063,.031,.003),'ivory',.001)
        text('12.48',(0,.032,.055),.019,'ink')
        cyl('Selector dial',(0,-.014,.051),(0,-.014,.060),.026,'rubber',32)
        box('Dial pointer',(0,-.001,.062),(.004,.021,.003),'ivory',.0005)
        for x in [-.026,0,.026]:tube('Probe input',(x,-.057,.053),.006,.003,.005,'red' if x>0 else 'ink',24)
        for x,material in [(-.065,'rubber'),(.065,'red')]:
            path('Probe cable',[(x*.4,-.055,.015),(x,-.10,.010),(x*1.5,-.05,.010),(x*1.3,.01,.012)],.002,material)
            cyl('Insulated probe',(x*1.3,.0,.012),(x*1.3,.060,.012),.004,material,16)
            cyl('Probe tip',(x*1.3,.060,.012),(x*1.3,.083,.012),.0013,'steel',8)
    elif item_id=='loot_binoculars':
        for x in [-.043,.043]:
            cyl('Armoured optical barrel',(x,-.047,.043),(x,.046,.043),.032,'sage',32)
            cyl('Objective housing',(x,-.080,.043),(x,-.040,.043),.038,'dark_metal',40)
            cyl('Objective lens',(x,-.082,.043),(x,-.083,.043),.032,'glass',40)
            cyl('Eyecup',(x,.045,.043),(x,.078,.043),.023,'rubber',32)
            for y in [-.024,.006,.033]:cyl('Barrel grip',(x,y,.043),(x,y+.002,.043),.033,'rubber',32)
        box('Centre bridge',(0,.002,.049),(.058,.031,.018),'dark_metal',.003)
        cyl('Focusing wheel',(0,-.012,.063),(0,.026,.063),.017,'rubber',24)
        text('8 x 42',(0,.010,.076),.008,'ivory')
        path('Folded field strap',[(-.077,.023,.028),(-.105,.068,.006),(.105,.068,.006),(.077,.023,.028)],.003,'rubber')
    else:
        box('Microscope weighted foot',(0,0,.015),(.141,.159,.030),'ivory',.009)
        path('Cast microscope arm',[(0,.046,.026),(0,.059,.095),(0,.056,.202),(0,.004,.253)],.018,'ivory')
        box('Mechanical stage',(0,-.008,.117),(.123,.100,.013),'ink',.002)
        tube('Stage aperture',(0,-.016,.125),.018,.011,.003,'steel',32)
        cyl('Illuminator',(0,-.013,.036),(0,-.013,.067),.026,'dark_metal',32)
        cyl('Illuminator glass',(0,-.013,.067),(0,-.013,.069),.020,'ivory',32)
        cyl('Optical head',(0,.002,.246),(0,-.029,.285),.017,'dark_metal',32)
        cyl('Eyepiece',(0,-.029,.285),(0,-.048,.307),.013,'rubber',24)
        cyl('Objective turret',(0,.002,.200),(0,.002,.216),.031,'steel',32)
        for a in [0,TAU/3,2*TAU/3]:
            p=Vector((.021*math.cos(a),.002+.021*math.sin(a),.201));cyl('Microscope objective',p,p-Vector((0,0,.040)),.008,'brass',24)
        for x in [-.034,.034]:cyl('Focus adjustment wheel',(x,.052,.164),(x*1.7,.052,.164),.018,'rubber',24)
        text('MICRO 40x',(0,-.071,.031),.011,'ink')

def electronics(item_id):
    if item_id=='loot_hard_drive':
        box('Hard drive chassis',(0,0,.010),(.111,.155,.020),'dark_metal',.004)
        for x in [-.050,.050]:box('Drive side rail',(x,0,.025),(.008,.145,.018),'steel',.001)
        cyl('Exposed disk platter',(0,.017,.021),(0,.017,.025),.043,'steel',64)
        tube('Platter hub',(0,.017,.029),.013,.006,.007,'aluminium',32)
        cyl('Actuator pivot',(.033,-.050,.021),(.033,-.050,.031),.012,'steel',24)
        cyl('Read arm',(.032,-.047,.031),(-.008,.007,.031),.004,'aluminium',12)
        box('Head coil',(.028,-.051,.030),(.023,.024,.006),'copper',.001)
        for x in [-.046,.046]:
            for y in [-.065,.065]:screw((x,y,.033))
        for k in range(16):box('SATA gold contact',(-.040+k*.004,-.079,.013),(.002,.011,.001),'gold',.0002)
    elif item_id=='loot_memory':
        box('RAM printed circuit',(0,0,.004),(.145,.035,.008),'pcb',.001)
        for k in range(8):box('Memory IC',(-.061+k*.017,.003,.012),(.013,.018,.009),'ink',.0008)
        for k in range(36):box('Edge gold pad',(-.068+k*.0038,-.015,.009),(.0021,.006,.001),'gold',.0002)
        box('RAM label',(0,.003,.018),(.037,.014,.001),'paper',.0002)
        text('8 GB',(0,-.001,.020),.007)
    else:
        box('GPU backplane',(0,0,.010),(.230,.110,.012),'pcb',.002)
        box('Dual fan shroud',(0,0,.030),(.215,.100,.030),'dark_metal',.006)
        for x in [-.055,.055]:
            tube('Fan frame',(x,0,.049),.041,.036,.006,'steel',40)
            cyl('Fan centre',(x,0,.048),(x,0,.055),.012,'ink',24)
            for k in range(9):
                a=TAU*k/9
                box('Swept fan blade',(x+.024*math.cos(a),.024*math.sin(a),.050),(.027,.010,.003),'rubber',.001,rotation=(0,0,a+.6))
        for k in range(24):box('Cooling fin',(-.101+k*.0085,.050,.027),(.001,.007,.028),'steel',.0002)
        for k in range(32):box('PCIe contact',(-.085+k*.0048,-.058,.011),(.0027,.013,.001),'gold',.0002)
        box('IO bracket',(-.118,0,.027),(.007,.125,.038),'steel',.001)
        for y in [-.032,.016]:box('Output socket',(-.123,y,.028),(.005,.031,.015),'ink',.001)

def medical(item_id):
    if item_id=='loot_medical_vial':
        bottle('BUFFER A','brass','blue',.102,.023)
        text('20 mL',(0,-.024,.036),.007,'ink',(math.pi/2,0,0))
    elif item_id=='loot_blood_kit':
        box('Sample transport tray',(0,0,.018),(.151,.099,.035),'ivory',.005)
        box('Blue foam rack',(0,0,.037),(.137,.085,.008),'blue',.002)
        for x in [-.048,-.016,.016,.048]:
            cyl('Sample vial',(x,0,.039),(x,0,.092),.010,'ivory',24)
            cyl('Sample contents',(x,0,.040),(x,0,.067),.0103,'red',24)
            cyl('Sealed vial cap',(x,0,.09),(x,0,.102),.012,'blue',24)
            box('Vial ID tag',(x,-.0105,.080),(.011,.001,.015),'paper',.0002)
        text('SAMPLE / 04',(0,-.051,.018),.009,'teal',(math.pi/2,0,0))
    else:
        cyl('Cryogenic sample vessel',(0,0,.012),(0,0,.135),.043,'steel',48)
        for z in [.016,.128]:tube('Protective canister ring',(0,0,z),.047,.041,.013,'blue',48)
        cyl('Locking lid',(0,0,.136),(0,0,.156),.046,'ivory',48)
        path('Canister grip',[(-.021,0,.155),(-.021,0,.183),(.021,0,.183),(.021,0,.155)],.004,'dark_metal')
        box('Lab ID label',(0,-.044,.077),(.058,.002,.054),'paper',.001)
        text('LAB / 08',(0,-.046,.085),.010,'ink',(math.pi/2,0,0))
        text('COLD',(0,-.046,.065),.009,'blue',(math.pi/2,0,0))

def hand_tool(item_id):
    if item_id=='loot_pliers':
        for side in [-1,1]:
            cyl('Insulated plier handle',(side*.010,-.005,.015),(side*.036,-.111,.015),.009,'red',20)
            cyl('Steel plier arm',(side*.009,-.001,.016),(-side*.016,.055,.016),.005,'steel',16)
            box('Serrated jaw',(-side*.012,.067,.016),(.012,.029,.012),'steel',.001,rotation=(0,0,side*.14))
            for y in [.058,.065,.072]:box('Jaw tooth',(-side*.007,y,.021),(.006,.002,.003),'dark_metal',0)
        cyl('Plier joint',(0,0,.009),(0,0,.024),.013,'dark_metal',24)
        screw((0,0,.025),.004)
    else:
        cyl('Screwdriver handle',(0,-.085,.017),(0,-.015,.017),.016,'ochre',24)
        for k in range(6):
            a=TAU*k/6;cyl('Moulded grip rib',(.015*math.cos(a),-.075,.017+.015*math.sin(a)),(.015*math.cos(a),-.023,.017+.015*math.sin(a)),.002,'rubber',8)
        cyl('Screwdriver shaft',(0,-.014,.017),(0,.087,.017),.0035,'steel',16)
        box('Slotted driver tip',(0,.093,.017),(.007,.014,.0015),'steel',.0002)

EXTRA_IDS=['loot_gauge','loot_bearing','loot_sensor','loot_silver_coin','loot_gem_ring','loot_antique_compass','loot_antique_vase',
 'loot_tape','loot_sewing_kit','loot_thermos','loot_soap','loot_toothbrush','loot_toothpaste','loot_canned_food','loot_coffee','loot_lighter','loot_flashlight','loot_matches','loot_aa_cells','loot_book','loot_mug',
 'loot_multimeter','loot_binoculars','loot_microscope','loot_copper_ingot','loot_aluminium_ingot','loot_titanium_ingot','loot_gold_bar',
 'loot_hard_drive','loot_memory','loot_gpu','loot_medical_vial','loot_blood_kit','loot_lab_sample','loot_pliers','loot_screwdriver']
BUILDERS={'loot_wire':wire,'loot_battery':battery,'loot_tools':tools,'loot_filter':filter_cartridge,
          'loot_radio':radio,'loot_processor':processor,'loot_watch':watch,'loot_statue':statue,
          'loot_documents':documents,'loot_lens':lens,'loot_fuel':fuel,'loot_scrap':scrap}
for extra_id in EXTRA_IDS:BUILDERS[extra_id]=None

def make(item_id):
    if item_id == 'loot_wire':
        wire()
        return
    if item_id == 'loot_battery':
        battery()
        return
    if item_id == 'loot_tools':
        tools()
        return
    if item_id == 'loot_filter':
        filter_cartridge()
        return
    if item_id == 'loot_radio':
        radio()
        return
    if item_id == 'loot_processor':
        processor()
        return
    if item_id == 'loot_watch':
        watch()
        return
    if item_id == 'loot_statue':
        statue()
        return
    if item_id == 'loot_documents':
        documents()
        return
    if item_id == 'loot_lens':
        lens()
        return
    if item_id == 'loot_fuel':
        fuel()
        return
    if item_id == 'loot_scrap':
        scrap()
        return
    if item_id in ['loot_gauge', 'loot_bearing', 'loot_sensor']:
        industrial(item_id)
        return
    if item_id in ['loot_silver_coin', 'loot_gem_ring', 'loot_antique_compass', 'loot_antique_vase']:
        collectibles(item_id)
        return
    if item_id in ['loot_multimeter', 'loot_binoculars', 'loot_microscope']:
        precision(item_id)
        return
    if item_id in ['loot_copper_ingot', 'loot_aluminium_ingot', 'loot_titanium_ingot', 'loot_gold_bar']:
        metal_ingot(item_id)
        return
    if item_id in ['loot_hard_drive', 'loot_memory', 'loot_gpu']:
        electronics(item_id)
        return
    if item_id in ['loot_medical_vial', 'loot_blood_kit', 'loot_lab_sample']:
        medical(item_id)
        return
    if item_id in ['loot_pliers', 'loot_screwdriver']:
        hand_tool(item_id)
        return
    if item_id in EXTRA_IDS:
        everyday(item_id)
        return

def bounds(objects):
    points=[o.matrix_world@Vector(p) for o in objects for p in o.bound_box]
    low=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    return low,high

def export_model(item_id,parts):
    bpy.ops.object.select_all(action='DESELECT')
    copies=[]
    for original in parts:
        o=original.copy();o.data=original.data.copy();o.parent=None;o.matrix_world=original.matrix_basis.copy()
        CTX["scene"].collection.objects.link(o);o.select_set(True);copies.append(o)
    bpy.context.view_layer.objects.active=copies[0]
    target=enum_property(bpy.ops.object.convert.get_rna_type(),'target',['MESH'])
    bpy.ops.object.convert(target=target)
    bpy.ops.object.join();joined=bpy.context.object
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    joined.name=item_id;joined.data.name=item_id+' / production mesh'
    low,high=bounds([joined]);joined.location.z=-low.z
    bpy.ops.object.transform_apply(location=True,rotation=False,scale=False)
    joined['sdc_item_id']=item_id;joined['original_asset']=True;joined['license']='CC0-1.0'
    joined.data.calc_loop_triangles()
    triangles=len(joined.data.loop_triangles)
    filepath=OUT+'/'+item_id+'.glb'
    rna=bpy.ops.export_scene.gltf.get_rna_type()
    formats=[e.identifier for e in rna.properties['export_format'].enum_items]
    if not formats:
        # Blender 5.2's dynamic enum omits items from RNA; ask the operator for
        # its actual accepted values without starting an export.
        try:bpy.ops.export_scene.gltf(export_format='SDC_PROBE')
        except TypeError as error:
            formats=[x.strip().strip("'\" ") for x in str(error).split('not found in (')[-1].rstrip(')').split(',')]
    fmt=next(value for value in formats if value=='GLB')
    kwargs=dict(filepath=filepath,export_format=fmt,use_selection=True,use_active_scene=True,export_yup=True,
        export_cameras=False,export_lights=False,export_animations=False,export_extras=True,
        export_apply=True,export_texcoords=False,export_normals=True)
    bpy.ops.export_scene.gltf(**kwargs)
    size=list(high-low)
    bpy.data.objects.remove(joined,do_unlink=True)
    return dict(id=item_id,name=CATALOG.get(item_id,{}).get('name',item_id),path='res://assets/valuables/'+item_id+'.glb',
                triangles=triangles,blender_size=size)

def build(ids=None):
    if CTX["scene"] is None:init()
    bpy.context.window.scene=CTX["scene"]
    for item_id in (ids or BUILDERS.keys()):
        if item_id in ASSETS:continue
        PARTS.clear()
        make(item_id)
        parts=PARTS[:]
        record=export_model(item_id,parts)
        root=bpy.data.objects.new(item_id,None);CTX["scene"].collection.objects.link(root)
        root['sdc_item_id']=item_id;root['label']=CATALOG.get(item_id,{}).get('name',item_id);root['asset_record']=record
        for p in parts:p.parent=root
        bpy.context.view_layer.update()
        low,high=bounds(parts);extent=max(high-low)
        index=len(ASSETS);root.location=((index%4)*.48,(index//4)*.48,0)
        root.scale=(.30/extent,)*3
        ASSETS[item_id]=dict(root=root,parts=parts,record=record)
        print('VALUABLE_BUILT',item_id,record['triangles'],flush=True)
    return [a['record'] for a in ASSETS.values()]

def setup_camera(objects):
    for name in ['V studio camera','V key','V fill','V rim']:
        old=bpy.data.objects.get(name)
        if old:bpy.data.objects.remove(old,do_unlink=True)
    bpy.context.view_layer.update();low,high=bounds(objects);center=(low+high)*.5;span=max(high-low)
    data=bpy.data.cameras.new('Valuable orthographic camera')
    data.type=enum_property(data,'type',['ORTHO']);data.ortho_scale=span*1.25;data.clip_start=.001
    camera=bpy.data.objects.new('V studio camera',data);CTX["scene"].collection.objects.link(camera)
    camera.location=center+Vector((2.3,-4.5,4.0))*span
    camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();CTX["scene"].camera=camera
    # Frame actual projected vertices, keeping original proportions and transparent margins.
    bpy.context.view_layer.update()
    inverse=camera.matrix_world.inverted()
    projected=[inverse@(o.matrix_world@Vector(p)) for o in objects for p in o.bound_box]
    data.ortho_scale=max(max(p.x for p in projected)-min(p.x for p in projected),max(p.y for p in projected)-min(p.y for p in projected))/.86
    for name,offset,power,color in [('V key',(-3,-4,6),500,(1,.92,.79)),('V fill',(4,-1,3),300,(.75,.85,1)),('V rim',(1,4,5),650,(1,1,.95))]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power*span*span;data.color=color;data.shape=enum_property(data,'shape',['DISK']);data.size=span*3
        o=bpy.data.objects.new(name,data);CTX["scene"].collection.objects.link(o);o.location=center+Vector(offset)*span
        o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()

def render(ids=None):
    bpy.context.window.scene=CTX["scene"]
    for item_id in (ids or ASSETS.keys()):
        for ident,asset in ASSETS.items():
            for o in asset['parts']:o.hide_render=ident!=item_id
        setup_camera(ASSETS[item_id]['parts'])
        CTX["scene"].render.filepath=ICONS+'/'+item_id+'.png'
        bpy.ops.render.render(write_still=True)
        print('VALUABLE_RENDERED',item_id,flush=True)
    for asset in ASSETS.values():
        for o in asset['parts']:o.hide_render=False

def classify(definitions):
    groups={}
    for group in definitions['groups']:
        name='V / '+group['name']
        collection=bpy.data.collections.get(name) or bpy.data.collections.new(name)
        if collection.name not in CTX['scene'].collection.children:CTX['scene'].collection.children.link(collection)
        groups[group['id']]=collection
    for item in definitions['items']:
        asset=ASSETS.get(item['id'])
        if not asset:continue
        asset['root']['label']=item['name'];asset['root']['category']=item['loot_category']
        asset['record']['name']=item['name'];asset['record']['group']=item['loot_category']
        asset['root']['asset_record']=asset['record']
        for obj in [asset['root']]+asset['parts']:
            for old in list(obj.users_collection):old.objects.unlink(obj)
            groups[item['loot_category']].objects.link(obj)

def save():
    records=[a['record'] for a in ASSETS.values()]
    setup_camera([o for a in ASSETS.values() for o in a['parts']])
    CTX["scene"].render.film_transparent=False
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE+'/SDC-valuables.blend')
    print('VALUABLE_MANIFEST '+json.dumps(records,ensure_ascii=True),flush=True)
    print('VALUABLES_SAVED',len(records),sum(x['triangles'] for x in records),flush=True)

# Run build(ids), render(ids), save() explicitly, allowing short MCP batches.
