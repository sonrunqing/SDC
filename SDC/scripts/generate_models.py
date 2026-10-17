#!/usr/bin/env python3
"""Original SDC modular hard-surface asset pipeline.
Run: blender --background --python scripts/generate_models.py
No external meshes/textures. All modeled meshes are original and CC0.
Blender coordinates are mapped from engine metres (+Y up, firing -Z).
Every exported weapon/part has a physical mount origin; sockets are authored empties.
"""
import bpy, bmesh, json, math, pathlib, hashlib, sys
from mathutils import Vector
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/modular'
DATA = json.loads((ROOT/'data/items.json').read_text())['items']
GUNS = [i for i in DATA if i['kind']=='weapon']
PARTS = [i for i in DATA if i['kind']=='attachment']
for folder in ['weapons','attachments','defaults']:
    (OUT/folder).mkdir(parents=True,exist_ok=True)
MATS = {}
def material(key, rgba, metallic=0.0, rough=.5):
    m=bpy.data.materials.new(key);m.diffuse_color=rgba;m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=rgba
    p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=rough
    MATS[key]=m;return m
material('Parkerized gunmetal',(0.075,.09,.105,1),.72,.32)
material('Black nitride',(0.024,.03,.035,1),.62,.35)
material('Steel edges',(.22,.26,.29,1),.8,.29)
material('Olive polymer',(.19,.22,.15,1),.05,.72)
material('Sand polymer',(.40,.32,.22,1),.05,.64)
material('Rubber',(.028,.03,.025,1),.0,.88)
material('Optical blue',(.045,.24,.31,1),.35,.15)
material('Emitter red',(.65,.055,.025,1),.25,.24)
material('Emitter green',(.08,.72,.25,1),.2,.2)
material('Brass',(.55,.36,.12,1),.7,.25)
matlist=list(MATS.values())
GUNMETAL,BLACK,STEEL,OLIVE,SAND,RUBBER,GLASS,RED,GREEN,BRASS=matlist
objects=[]
def v(p):return Vector((p[0],-p[2],p[1]))
def reset():
    global objects
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for me in list(bpy.data.meshes):
        if me.users==0:bpy.data.meshes.remove(me)
    objects=[]
def finish_obj(o,name,mat):
    o.name=name;o.data.materials.append(mat);objects.append(o);return o
def box(name, p, size, mat=GUNMETAL, bevel=.0015, angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=v(p));o=bpy.context.object
    o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if angle:o.rotation_euler.x=angle
    if bevel:
        mod=o.modifiers.new('Machined edge','BEVEL');mod.width=min(bevel,min(size)*.2);mod.segments=1
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish_obj(o,name,mat)
def cyl(name,a,b,r,mat=GUNMETAL,n=12,r2=None):
    d=v(b)-v(a);mid=(v(a)+v(b))*.5
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=d.length,location=mid)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r,radius2=r2,depth=d.length,location=mid)
    o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    return finish_obj(o,name,mat)
def tube(name,z0,z1,r,inner,mat=GUNMETAL,n=16,x=0,y=0):
    verts=[]
    for z,rr in [(z0,r),(z1,r),(z0,inner),(z1,inner)]:
        verts += [v((x+math.cos(2*math.pi*k/n)*rr,y+math.sin(2*math.pi*k/n)*rr,z)) for k in range(n)]
    faces=[]
    for k in range(n):
        j=(k+1)%n
        faces += [(k,j,n+j,n+k),(2*n+k,3*n+k,3*n+j,2*n+j),(k,2*n+k,2*n+j,j),(n+k,n+j,3*n+j,3*n+k)]
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return finish_obj(o,name,mat)
def prism(name,profile,width,mat=GUNMETAL):
    # profile is (y,z) silhouette, extruded along x for angular receiver/stock/grip.
    n=len(profile);verts=[v((x,y,z)) for x in [-width*.5,width*.5] for y,z in profile]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    for k in range(n):j=(k+1)%n;faces.append((k,j,n+j,n+k))
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return finish_obj(o,name,mat)
def empty(name,p):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=v(p);o.empty_display_size=.025;return o
def screws(x,y,z,count=2,axis='x'):
    for k in range(count):
        zz=z+k*.045
        if axis=='x':cyl('Recessed fastener',(x,y,zz),(x+(.002 if x>=0 else -.002),y,zz),.004,STEEL,8)
        else:cyl('Rail screw',(x,y,zz),(x,y+.003,zz),.003,STEEL,8)
def rail(z0,z1,y,x=0,width=.033):
    box('Dovetail rail',(x,y,(z0+z1)*.5),(width,.009,abs(z1-z0)),BLACK,.0005)
    steps=max(2,int(abs(z1-z0)/.024))
    for k in range(steps):
        z=z0+(z1-z0)*(k+.5)/steps
        box('Picatinny lug',(x,y+.006,z),(width+.008,.006,.010),GUNMETAL,.0004)
def trigger(z=.075,y=-.07,width=.048):
    # Open trigger guard, visibly separate trigger and rectangular loop.
    box('Trigger bow',(0,y-.04,z),(width,.009,.068),BLACK,.001)
    box('Front guard',(0,y-.017,z-.032),(width,.045,.009),GUNMETAL,.001)
    box('Rear guard',(0,y-.017,z+.032),(width,.045,.009),GUNMETAL,.001)
    box('Curved trigger',(0,y-.018,z+.004),(.009,.039,.012),STEEL,.002,angle=-.18)
def gun_params(g):
    cat=g['category'];idx=[a['id'] for a in GUNS if a['category']==cat].index(g['id'])
    dims={'smg':(.39,.135,.073),'rifle':(.56,.15,.078),'sniper':(.78,.17,.072),'shotgun':(.70,.16,.066),'machine_gun':(.70,.18,.105),'pistol':(.16,.065,.035)}
    front,back,w=dims[cat];front += [0,.025,-.025,-.045][idx];back += [0,.012,.0,-.008][idx]
    if g['id']=='weapon_manta300':front=.49
    if g['id']=='weapon_wren556':front=.68
    if g['id']=='weapon_elk12':front=.76
    return dict(front=round(front,4),back=back,width=w,variant=idx,category=cat)
def sockets_for(g,p):
    f,b,w=p['front'],p['back'],p['width'];pistol=g['category']=='pistol'
    possible={'muzzle':(0,0,-f),'stock':(0,0,b),'magazine':(0,-.057,.04 if pistol else -.035),
              'optic':(0,.050 if pistol else .077,-.012),'laser':((w*.5+.004) if not pistol else 0,-.035 if pistol else -.004,-.085 if pistol else -.26),
              'grip':(0,-.047,-.29),'handguard':(0,0,-.16)}
    if g['category']=='smg':possible['grip']=(0,-.044,-.23);possible['laser']=(w*.5+.004,0,-.25)
    if 'grip' in g['slots'] and 'bipod_stud' in g['slots']['grip']:possible['grip']=(0,-.048,-f*.73)
    if 'magazine' in g['slots'] and any(a.startswith('tube_') for a in g['slots']['magazine']):possible['magazine']=(0,-.038,-.14)
    if g['id']=='weapon_elk12':possible['magazine']=(0,0,-.12)
    return {slot:possible[slot] for slot in g['slots']}
def body_model(g,p):
    f,b,w=p['front'],p['back'],p['width'];idx=p['variant'];cat=g['category'];pol=[OLIVE,SAND,BLACK,OLIVE][idx]
    if cat=='pistol':
        prism('Milled slide',[(.035,b),(.043,b-.02),(.043,-f+.04),(.025,-f+.007),(-.014,-f+.007),(-.021,b)],w,GUNMETAL if idx%2==0 else STEEL)
        prism('Polymer frame',[(-.018,b),(-.015,-f+.025),(-.044,-f+.025),(-.052,-.015),(-.16,b-.009),(-.17,b+.032),(-.071,b+.014)],w*.89,pol)
        for side in [-1,1]:
            for k in range(6):box('Slide serration',(side*(w*.5+.0005),.015,b-.009-k*.006),(.002,.029,.0025),BLACK,0)
            box('Grip sidepanel',(side*w*.47,-.109,b+.012),(.003,.069,.031),RUBBER,.003,angle=-.23)
        box('Ejection opening',(w*.52,.01,-.042),(.003,.018,.042),BLACK,.001)
        box('Rear sight left',(-.012,.052,b-.01),(.007,.012,.012),BLACK)
        box('Rear sight right',(.012,.052,b-.01),(.007,.012,.012),BLACK)
        box('Front sight',(0,.048,-f+.018),(.005,.012,.012),BLACK)
        trigger(z=.005,y=-.052,width=w*.9)
        tube('Threaded barrel',-.06,-f-.006,.009,.004,BLACK,n=12)
    else:
        if cat=='smg' and idx==2:
            # Compact PDW with a distinctive broad arched receiver.
            prism('PDW shell',[(.058,b),(.07,-.16),(.04,-.27),(-.032,-.27),(-.043,b)],w,pol)
            box('PDW ejection',(w*.52,.01,-.08),(.004,.023,.055),BLACK)
        elif cat=='sniper' and idx in [0,2]:
            cyl('Bolt receiver',(0,0,b),(0,0,-.21),w*.44,GUNMETAL,n=12)
            box('Receiver bedding',(0,-.034,-.015),(w,.028,.31),pol,.005)
            cyl('Bolt handle',(w*.4,.012,.025),(w*.94,-.004,.07),.009,STEEL,8)
            cyl('Bolt knob',(w*.94,-.004,.07),(w*1.1,-.018,.078),.014,BLACK,10)
        elif cat=='shotgun' and idx==3:
            prism('Break action',[ (.043,b),(.043,-.15),(-.04,-.16),(-.049,b)],w,STEEL)
            cyl('Break action hinge',(-w*.56,-.012,-.1),(w*.56,-.012,-.1),.017,BLACK,12)
            box('Top lever',(.012,.049,.07),(.013,.012,.075),BLACK)
        else:
            top=.059 if cat!='machine_gun' else .076
            prism('Machined receiver',[(top-.014,b),(top,b-.027),(top,-.155),(top-.018,-.19),(-.047,-.175),(-.056,b)],w,GUNMETAL if idx!=1 else pol)
            box('Lower receiver',(0,-.041,.005),(w*.87,.042,.208),pol,.006)
            # Dark ejection recess with inset bolt face on the visible right side.
            box('Ejection port',(w*.505,.017,-.036),(.003,.028,.086),BLACK,.001)
            box('Bolt face',(w*.528,.012,-.026),(.002,.018,.056),STEEL,.0005)
            cyl('Charging handle',(w*.48,.034,.052),(w*.88,.034,.052),.005,BLACK,8)
        # Fixed firing grip is part of receiver, not the removable front grip.
        prism('Pistol grip',[(-.045,.069),(-.055,.126),(-.177,.176),(-.186,.127)],w*.62,RUBBER)
        for side in [-1,1]:
            for k in range(5):box('Grip texture',(side*w*.315,-.096-k*.012,.11+k*.004),(.002,.003,.043),BLACK,0)
            screws(side*(w*.51),-.016,-.11,3)
            cyl('Selector axis',(side*w*.49,-.019,.063),(side*w*.56,-.019,.063),.006,STEEL,8)
        trigger(z=.057,y=-.05,width=w*.77)
        # Core barrel stays exposed when handguard is removed.
        rad=.012 if cat in ['smg','rifle'] else (.019 if cat=='shotgun' else .014)
        tube('Rifled barrel',-.13,-f,rad,rad*.42,BLACK,n=16)
        if cat=='shotgun' and idx==3:tube('Second barrel',-.14,-f,rad,rad*.68,BLACK,n=16,x=.031)
        for zz in [-.2,-f+.018]:tube('Barrel collar',zz-.008,zz+.008,rad*1.25,rad*.9,STEEL,n=12)
        # Fixed sight block and receiver rail give each uncluttered body useful detail.
        if 'optic' in g['slots']:rail(-.125,.092,.067,width=w*.48)
        if cat in ['rifle','smg','machine_gun']:
            box('Front sight post',(0,.039,-f+.068),(.016,.052,.018),GUNMETAL)
            box('Front sight pin',(0,.068,-f+.068),(.005,.015,.007),STEEL)
        if cat=='machine_gun':
            box('Feed cover',(0,.077,-.012),(w*1.06,.018,.22),BLACK,.003)
            cyl('Carry handle left',(-w*.5,.085,-.09),(-w*.5,.14,-.09),.006,STEEL,8)
            cyl('Carry handle right',(w*.5,.085,-.09),(w*.5,.14,-.09),.006,STEEL,8)
            cyl('Carry handle cross',(-w*.5,.14,-.09),(w*.5,.14,-.09),.009,RUBBER,8)
        # Guns without removable handguards get a compact fixed cover.
        if 'handguard' not in g['slots']:
            box('Fixed fore-end',(0,-.003,-f*.49),(w*.82,.063,f*.36),pol,.008)
    for slot,pos in sockets_for(g,p).items():empty('Socket_'+slot,pos)

def muzzle_model(a):
    c=a['category'];interface=a['interfaces'][0]
    large='12_' in interface or '20_' in interface
    factor={'thread_9_13':.95,'thread_45_16':1.03,'thread_57_10':.84,'thread_556_12':1.0,'thread_545_14':.98,'thread_762_14':1.07,'thread_308_58':1.12,'thread_338_34':1.24,'thread_12_m22':1.30,'thread_20_m20':1.18}[interface]
    if c=='suppressor':
        L=.19*factor;R=.022*factor
        tube('Baffled suppressor shell',-.012,-L,R,.006*factor,BLACK,20)
        for z in [-.012,-.036,-L+.015]:tube('Suppressor locking ring',z-.006,z+.006,R*1.08,R*.95,GUNMETAL,20)
        for k in range(5):
            z=-.055-k*.022*factor;tube('Machined concentric seam',z-.001,z+.001,R*1.015,R*.99,STEEL,20)
        tube('Endcap',-L,-L-.004,R,.005*factor,STEEL,20)
    elif c=='flash_hider':
        L=.058*factor;R=.014*factor
        tube('Flash hider base',0,-.024,R,.005*factor,GUNMETAL,12)
        # Open individual prongs: the gaps are actual geometry, not painted slots.
        for k in range(4):
            angle=k*math.pi*.5
            box('Open prong',(math.cos(angle)*R*.72,math.sin(angle)*R*.72,-L*.66),(.008*factor,.008*factor,L*.73),BLACK,.0007)
        tube('Thread collar',0,-.009,R*1.08,.005*factor,STEEL,12)
    elif c=='compensator':
        L=.052*factor;R=.016*factor
        tube('Gas channel',0,-L,R*.68,.005*factor,BLACK,12)
        for k in range(3):
            z=-.012-k*.016*factor
            box('Side baffle left',(-R,0,z),(.012*factor,.023*factor,.009*factor),GUNMETAL,.001)
            box('Side baffle right',(R,0,z),(.012*factor,.023*factor,.009*factor),GUNMETAL,.001)
            box('Gas baffle top',(0,R*.7,z),(.023*factor,.008*factor,.009*factor),STEEL,.0005)
    else:
        L=.073*factor;R=.019*factor
        tube('Brake central bore',0,-L,R*.5,.005*factor,BLACK,12)
        for k in range(3):
            z=-.013-k*.025*factor
            box('Brake expansion chamber',(0,0,z),(.047*factor,.034*factor,.01*factor),GUNMETAL,.002)
            for side in [-1,1]:box('Brake chamber web',(side*.018*factor,-.01*factor,z-.008*factor),(.006*factor,.012*factor,.022*factor),BLACK,.001)
        tube('Brake exit',-L+.005,-L,R*.76,.005*factor,STEEL,12)

def grip_model(a):
    ident=a['id'];base=SAND if 'mlok' in ident else (OLIVE if 'keymod' in ident else BLACK)
    box('Attachment clamp',(0,-.006,0),(.04,.012,.057),GUNMETAL,.002)
    screws(.022,-.006,-.014,1)
    if 'bipod' in ident:
        carbon='carbon' in ident;length=.19 if carbon else .16
        for side in [-1,1]:
            cyl('Bipod pivot',(side*.018,-.012,0),(side*.034,-.024,0),.012,STEEL,12)
            cyl('Deployable bipod leg',(side*.032,-.025,0),(side*.085,-length,-.027),.007 if carbon else .009,BLACK,10)
            cyl('Leg adjuster',(side*.057,-length*.62,-.017),(side*.085,-length,-.027),.005,STEEL,10)
            box('Rubber foot',(side*.085,-length,-.028),(.032,.014,.028),RUBBER,.002)
    elif 'angled' in ident or 'stop' in ident:
        prism('Angled foregrip',[(-.012,-.027),(-.065,.025),(-.073,.045),(-.012,.039)],.033,base)
        if 'stop' in ident:box('Finger stop',(0,-.028,-.018),(.028,.036,.014),RUBBER,.002)
    elif 'pump' in ident:
        box('Pump fore-end',(0,-.022,-.01),(.061,.046,.138),OLIVE,.008)
        for k in range(7):box('Pump rib',(0,-.025,-.07+k*.017),(.066,.048,.005),RUBBER,.0008)
    else:
        prism('Vertical foregrip',[(-.011,-.018),(-.012,.023),(-.116,.016),(-.127,-.005)],.031,base)
        for k in range(5):box('Foregrip ribs',(0,-.041-k*.015,.001),(.035,.005,.031),RUBBER,.001)
        box('Battery cap',(0,-.125,.003),(.036,.007,.032),STEEL,.002)

def stock_model(a,default=False):
    ident=a['id'];heavy=any(q in ident for q in ['heavy','braced','bolt','falcon','rhino','bison','shotgun']);compact='pdw' in ident or 'brace' in ident
    L=(.20 if compact else (.28 if heavy else .235)) + (int(hashlib.sha256(ident.encode()).hexdigest()[:4],16)%13)*.002;pol=OLIVE if any(q in ident for q in ['cedar','yak','fox']) else SAND if 'light' in ident else BLACK
    if default:L*=.93
    cyl('Rear mount tube',(0,0,-.006),(0,0,L*.7),.015,STEEL,12)
    if 'pdw' in ident or 'fold_light' in ident or 'brace' in ident:
        for side in [-1,1]:cyl('Skeleton stock strut',(side*.021,-.005,.012),(side*.021,-.014,L),.006,GUNMETAL,8)
        box('Compact butt plate',(0,-.02,L),(.063,.10,.023),RUBBER,.004)
        if 'padded' in ident:box('Cheek pad',(0,.018,L*.6),(.055,.025,L*.52),pol,.006)
    else:
        prism('Stock profile',[(.024,L*.28),(.027,L-.022),(-.014,L+.006),(-.105,L+.006),(-.095,L-.053),(-.032,L*.32)],.055 if not heavy else .065,pol)
        box('Recoil pad',(0,-.043,L+.011),(.064 if not heavy else .072,.131,.022),RUBBER,.005)
        box('Cheek riser',(0,.03,L*.65),(.052,.017,L*.48),RUBBER,.004)
        if heavy:
            cyl('Riser adjustment screw',(-.04,.015,L*.62),(-.031,.015,L*.62),.009,STEEL,10)
            box('Length adjust lever',(0,-.089,L*.5),(.027,.013,.05),STEEL,.002)
    box('Sling swivel',(0,-.068,L-.032),(.016,.015,.02),STEEL,.002)
    screws(.033,-.014,L*.62,1)

def mag_for_weapon(a):
    interfaces=a.get('interfaces',[])
    for g in GUNS:
        if any(i in g['slots'].get('magazine',[]) for i in interfaces):return g
    return GUNS[0]
def magazine_model(a,default=False):
    ident=a['id'];iface=a.get('interfaces',[''])[0];g=mag_for_weapon(a);cat=g['category'];extended='extended' in ident
    if iface.startswith('tube_'):
        L=.30 if not extended else .43;rad=.013 if 'fox' in iface else .016
        tube('Shotgun magazine tube',0,-L,rad,rad*.7,BLACK,12)
        tube('Magazine end cap',-L-.005,-L-.018,rad*1.15,rad*.1,GUNMETAL,12)
        if 'follower' in ident:tube('Follower collar',-.008,-.026,rad*1.2,rad*.9,STEEL,12)
        return
    if iface.startswith('chamber_'):
        # Two visible brass shell carriers fitted into the breech, no box magazine.
        for x in [-.012,.018]:
            cyl('Shell wall',(x,0,0),(x,0,-.057),.01,BRASS,12)
            cyl('Shell rim',(x,0,.001),(x,0,.005),.012,STEEL,12)
        return
    if iface.startswith('belt_') or iface.startswith('drum_') or 'aurochs' in iface:
        if iface.startswith('drum_') or ('aurochs' in iface and extended):
            R=.09 if extended else .075
            cyl('Drum left plate',(-.04,-R+.008,.008),(.04,-R+.008,.008),R,BLACK,20)
            cyl('Drum hub',(-.042,-R+.008,.008),(-.046,-R+.008,.008),R*.3,STEEL,12)
            for k in range(8):
                t=k*math.tau/8;box('Drum reinforcing rib',(.042,-R+.008+math.sin(t)*R*.72,.008+math.cos(t)*R*.72),(.005,.018,.018),GUNMETAL,.001)
            box('Feed tower',(0,-.012,0),(.032,.05,.055),GUNMETAL,.002)
        else:
            H=.145 if extended else .112
            box('Belt ammunition box',(0,-H*.5,.027),(.108,H,.147),OLIVE,.008)
            box('Feed tower',(0,-.012,0),(.042,.035,.054),BLACK,.002)
            box('Box latch',(.057,-H*.45,.018),(.008,.038,.026),STEEL,.002)
            for k in range(4):box('Ammo box stiffener',(.056,-H*.5,-.024+k*.03),(.003,H*.72,.006),SAND,.0005)
        return
    pistol=cat=='pistol';smg=cat=='smg';sniper=cat=='sniper';cal=g['caliber']
    H=(.14 if pistol else .18 if smg else .105 if sniper else .17)* (1.42 if extended else 1.0)
    if default:H*=.90
    W={'9x19':.024,'45acp':.028,'57x28':.022,'556x45':.029,'545x39':.028,'762x39':.031,'300blk':.030,'308win':.033,'762x54r':.034,'338lm':.037,'12g':.036}.get(cal,.029)
    D=(.032 if pistol or smg else .066) + (int(hashlib.sha256(iface.encode()).hexdigest()[:4],16)%9)*.001
    curve=.0 if pistol else .025 if cal in ['762x39','545x39','12g'] else .012
    # Multi-segment curved magazine silhouette: feed lip always at mount (0,0,0).
    profile=[(0,-D*.5),(0,D*.5),(-H*.45,D*.5+curve*.2),(-H,D*.5+curve),(-H,-D*.5+curve*.8),(-H*.45,-D*.5+curve*.15)]
    prism('Stamped magazine',profile,W,BLACK if pistol else GUNMETAL)
    box('Magazine floorplate',(0,-H-.004,curve*.9),(W+.007,.012,D+.008),RUBBER,.002)
    for side in [-1,1]:
        for k in range(2 if smg else 3):
            z=-D*.28+k*D*.26
            box('Magazine stamped groove',(side*(W*.5+.0004),-H*.53,z+curve*.4),(.002,H*.72,.004),BLACK,.0004)
        for k in range(3):cyl('Witness hole',(side*W*.51,-H*.28-k*H*.19,D*.18),(side*(W*.51+.001),-H*.28-k*H*.19,D*.18),.0022,BLACK,8)
    if extended and not pistol:
        box('Extended base bumper',(0,-H+.018,curve*.9),(W+.01,.018,D+.007),SAND,.002)

def optic_model(a):
    ident=a['id'];scope='scope' in ident;micro='micro' in ident;thermal='thermal' in ident;holo='holo' in ident
    side='side_' in ident;dove='dove' in ident
    box('Optic mounting foot',(0,.008,0),(.032,.016,.061 if not micro else .031),GUNMETAL,.001)
    if side:
        box('Side rail bracket',(-.035,-.018,.008),(.014,.066,.045),STEEL,.002)
        box('Bracket bridge',(-.018,.016,0),(.04,.013,.053),BLACK,.002)
    screws(.019,.008,-.012,1)
    if scope or thermal:
        L=.25 if ('8' in ident) else .18 if scope else .14;R=.019 if '2' in ident else .025
        if '8' in ident:R=.032
        y=.047
        tube('Scope main tube',-L*.52,L*.43,.015,.011,BLACK,16,y=y)
        tube('Objective housing',-L*.54,-L*.21,R,.014,GUNMETAL,20,y=y)
        cyl('Objective lens',(0,y,-L*.545),(0,y,-L*.548),R*.87,GLASS,20)
        tube('Eyepiece focus ring',L*.27,L*.46,.022,.012,BLACK,16,y=y)
        cyl('Ocular lens',(0,y,L*.465),(0,y,L*.468),.017,GLASS,16)
        cyl('Elevation turret',(0,y+.013,0),(0,y+.035,0),.013,GUNMETAL,12)
        cyl('Windage turret',(.013,y,0),(.034,y,0),.012,GUNMETAL,12)
        for z in [-L*.16,L*.13]:
            tube('Scope ring',z-.009,z+.009,.021,.014,STEEL,16,y=y)
            box('Ring foot',(0,.024,z),(.033,.022,.021),BLACK,.001)
        if thermal:
            box('Thermal battery module',(.033,.048,-.014),(.032,.045,.073),OLIVE,.004)
            box('Screen housing',(0,.047,.073),(.071,.061,.024),BLACK,.003)
            box('OLED glass',(0,.047,.086),(.055,.044,.002),GLASS,.0005)
    elif holo:
        # Open rectangular hood with separate glass plate and electronics base.
        box('Holographic base',(0,.025,0),(.049,.026,.083),OLIVE,.004)
        for side in [-1,1]:box('Hood side',(side*.026,.058,-.012),(.008,.062,.042),BLACK,.002)
        box('Hood bridge',(0,.088,-.012),(.059,.008,.042),BLACK,.002)
        box('Holographic window',(0,.06,-.012),(.042,.042,.002),GLASS,.0005)
        box('Battery compartment',(0,.031,.045),(.037,.032,.037),BLACK,.004)
    else:
        enclosed='enclosed' in ident or 'dove' in ident or 'side' in ident
        if enclosed:
            y=.037;R=.018 if not micro else .014
            tube('Red dot housing',-.031,.031,R,R*.75,BLACK,16,y=y)
            cyl('Red dot glass',(0,y,-.032),(0,y,-.033),R*.72,GLASS,16)
            cyl('Dot adjustment',(.014,y,0),(.024,y,0),.008,GUNMETAL,10)
            box('Riser',(0,.021,0),(.025,.024,.032),BLACK,.001)
        else:
            H=.038 if micro else .049;W=.031 if micro else .039
            box('Reflex electronics',(0,.018,.007),(W,.021,.037),BLACK,.003)
            for side in [-1,1]:box('Reflex window side',(side*W*.5,H*.65,-.005),(.006,H,.012),GUNMETAL,.001)
            box('Reflex window top',(0,H*1.12,-.005),(W+.005,.006,.012),GUNMETAL,.001)
            box('Reflex optical window',(0,H*.7,-.005),(W-.006,H*.75,.0015),GLASS,.0003)

def laser_model(a):
    ident=a['id'];pistol='pistol' in ident or 'trigger' in ident;L=.045 if pistol else .074;W=.03 if pistol else .035
    # Rifle laser mounts to the +X side; pistol devices mount below barrel.
    if pistol:
        box('Pistol accessory clamp',(0,0,0),(.035,.01,L*.9),GUNMETAL,.001)
        box('Laser polymer housing',(0,-.017,-L*.16),(W,.033,L),BLACK,.004)
        x,y=0,-.02
    else:
        box('Side rail clamp',(.004,0,0),(.012,.042,L*.8),GUNMETAL,.001)
        box('Laser housing',(.021,0,-L*.18),(W,.039,L),SAND if 'mlok' in ident else BLACK,.004)
        x,y=.023,0
    cyl('Laser emitter bezel',(x,y,-L*.66),(x,y,-L*.74),.009,STEEL,12)
    cyl('Laser emitter',(x,y,-L*.745),(x,y,-L*.749),.005,GREEN if 'green' in ident else RED,12)
    if 'ir' in ident:
        cyl('IR illuminator',(.024,.019,-L*.5),(.024,.019,-L*.72),.012,BLACK,12)
    box('Activation switch',(x+(W*.5+.001),y,0),(.004,.015,.019),RUBBER,.001)
    screws(x+W*.52,y,-.015,1)

def handguard_model(a,default=False):
    ident=a['id'];g=None
    for gg in GUNS:
        if any(i in gg['slots'].get('handguard',[]) for i in a['interfaces']):g=gg;break
    if g is None:g=GUNS[4]
    p=gun_params(g);length=min(.30,p['front']-.23)
    if g['category']=='sniper':length=.38 if 'ar556' not in a['interfaces'][0] else .30
    if g['category']=='machine_gun':length=.34
    width=p['width']*.90;H=.067+(int(hashlib.sha256(ident.encode()).hexdigest()[:4],16)%7)*.0015
    pol=OLIVE if default else SAND if g['category'] in ['rifle','smg'] else BLACK
    # Four independent slats leave genuine open M-LOK/keymod vent gaps.
    for side in [-1,1]:
        box('Handguard side beam',(side*width*.5,-.002,-length*.5),(.012,H*.62,length),pol,.003)
        for k in range(max(3,int(length/.046))):
            z=-.018-k*.046
            box('Vent recess',(side*(width*.5+.006),.001,z),(.0015,.018,.028),BLACK,.0005)
            cyl('Vent fastener',(side*(width*.5+.0065),-.019,z),(side*(width*.5+.008),-.019,z),.002,STEEL,8)
    box('Handguard bottom',(0,-H*.42,-length*.5),(width,.012,length),pol,.003)
    rail(-length+.015,-.012,H*.5,width=width*.66)
    tube('Forward retaining band',-length+.008,-length+.021,width*.61,width*.48,GUNMETAL,12)
    box('Handguard rear collar',(0,-.001,-.008),(width+.016,H+.012,.021),GUNMETAL,.003)
    if g['category']=='shotgun':
        for k in range(8):box('Fore-end grip ribs',(0,-H*.44,-.023-k*.025),(width+.01,.008,.006),RUBBER,.0005)

def export(path,asset_id,kind):
    # Merge geometry to one object with material surfaces; keep socket empties distinct.
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:o.select_set(True)
    if meshes:
        bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join()
        merged=bpy.context.object;merged.name='Geometry_'+asset_id
        bm=bmesh.new();bm.from_mesh(merged.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(merged.data);bm.free()
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        merged['original_asset']=True;merged['license']='CC0-1.0';merged['mount_units']='metres'
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_cameras=False,
        export_lights=False,export_extras=True,export_apply=True,export_materials='EXPORT',export_normals=True,
        export_tangents=False,export_animations=False,export_texcoords=False)
    tris=0
    for o in bpy.context.scene.objects:
        if o.type=='MESH':o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
    return {'id':asset_id,'kind':kind,'path':'res://'+str(path.relative_to(ROOT)),'triangles':tris,'bytes':path.stat().st_size,
        'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'geometry_sha256':hashlib.sha256(str([(tuple(round(c,6) for c in v.co),) for o in bpy.context.scene.objects if o.type=='MESH' for v in o.data.vertices]).encode()).hexdigest()}

manifest={'schema_version':1,'units':'metres','up':'+Y','forward':'-Z','origin':'receiver center, attachments at physical mount',
    'provenance':{'author':'SDC original procedural hard-surface models','license':'CC0-1.0','external_meshes':False},'weapons':{},'assets':[]}
# Emit body socket transforms and factory-parts manifest before imports can race generation.
for g in GUNS:
    p=gun_params(g);default_slots=[s for s in ['stock','magazine','handguard'] if s in g['slots']]
    manifest['weapons'][g['id']]={**p,'sockets':{s:list(pos) for s,pos in sockets_for(g,p).items()},
        'defaults':{s:f"res://assets/modular/defaults/{g['id']}_{s}.glb" for s in default_slots}}
(ROOT/'data/weapon_geometry.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
for g in GUNS:
    reset();body_model(g,gun_params(g));manifest['assets'].append(export(OUT/'weapons'/(g['id']+'.glb'),g['id'],'weapon'))
    print('MODELED weapon',g['id'],flush=True)
for a in PARTS:
    reset();cat=a['category']
    if cat in ['suppressor','flash_hider','compensator','muzzle_brake']:muzzle_model(a)
    elif cat=='grip':grip_model(a)
    elif cat=='stock':stock_model(a)
    elif cat=='magazine':magazine_model(a)
    elif cat=='optic':optic_model(a)
    elif cat=='laser':laser_model(a)
    elif cat=='handguard':handguard_model(a)
    else:raise ValueError(cat)
    manifest['assets'].append(export(OUT/'attachments'/(a['id']+'.glb'),a['id'],'attachment'))
    print('MODELED attachment',a['id'],flush=True)
for g in GUNS:
    for slot in manifest['weapons'][g['id']]['defaults']:
        reset();a={'id':'factory_'+g['id']+'_'+slot,'interfaces':g['slots'][slot]}
        if slot=='stock':stock_model(a,True)
        elif slot=='magazine':magazine_model(a,True)
        elif slot=='handguard':handguard_model(a,True)
        asset_id=g['id']+'_'+slot
        manifest['assets'].append(export(OUT/'defaults'/(asset_id+'.glb'),asset_id,'factory'))
(ROOT/'data/weapon_geometry.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
(OUT/'LICENSE.txt').write_text('SDC Modular Weapon Models\nAll meshes generated originally by scripts/generate_models.py.\nReleased under CC0 1.0 Universal; https://creativecommons.org/publicdomain/zero/1.0/\nNo external model data, no extracted game assets or brand artwork.\n')
(OUT/'README.md').write_text('''# Original modular gun models\n\nGenerated with Blender by `scripts/generate_models.py`. Each catalog gun and attachment owns an individual GLB. Factory magazines, stocks and handguards are also independent GLBs.\n\nMetres; +Y up, firing -Z; body origin receiver center. Attachment origin is its mounting point. Identity transforms attach to `Socket_<slot>` empties.\n\n`data/weapon_geometry.json` records physical socket positions, independent factory model paths, triangle counts and SHA-256 provenance for every asset. Factory pieces are hidden by replacement at that socket, never baked into bodies.\n\nAll meshes are original low-poly hard-surface models, CC0. They are development art with physical details and different class silhouettes, not exact branded gun reproductions.\n''')
print('GENERATION_COMPLETE',len(GUNS),'weapons',len(PARTS),'attachments',len(manifest['assets']),'total assets',sum(x['bytes'] for x in manifest['assets']),'bytes',flush=True)
