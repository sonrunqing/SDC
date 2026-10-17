#!/usr/bin/env python3
"""Build the shared, traversable 160x180 harbour layout. Deterministic and data driven."""
import json,random,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
metadata={x['id']:x for x in json.loads((ROOT/'data/environment_models.json').read_text())['assets']}
rng=random.Random(17032026);objects=[];surfaces=[];lights=[]
def add(model,x,z,size=None,y=0,angle=0,collision=True):
    m=metadata[model]
    size=size or m['size']
    objects.append(dict(model=model,position=[x,y,z],size=size,rotation=angle,collision=collision))
def surface(x,z,w,d,color,y=.012,h=.015):surfaces.append(dict(position=[x,y,z],size=[w,h,d],color=color))
# Main roads, cross streets, sidewalks and original central test barricade.
surface(0,0,12,178,'26343b')
for z in [-57,-15,20,56]:surface(0,z,158,9,'29383e')
for x in [-6.6,6.6]:surface(x,0,1.2,178,'4c5350',.025,.06)
for z in range(-84,85,6):surface(0,z,.12,2.7,'b6a05d',.035)
for z in [-57,-15,20,56]:
    for x in range(-74,75,6):
        if abs(x)>8:surface(x,z,2.7,.12,'ae9c60',.035)
# Marked pedestrian crossings.
for center in [-58,-16,19,55]:
    for z in range(6):surface(0,center-2+z,.0+10,.38,'b9b8a3',.042)
add('factory/box-long',7.5,16,[3.4,1.02,.78])
for x,z in [(-5.7,7),(5.9,-2.3),(-5.8,-17)]:add('factory/warning-traffic',x,z,[1.9,1.0,.45])
# Eight districts with different building profiles and yards.
buildings=[('building-a',-55,-35,[15,8,12]),('building-b',-30,-37,[13,7.5,11]),
 ('building-c',-58,-8,[15,6,12]),('building-d',-34,-4,[13,6,12]),
 ('building-e',-58,28,[16,8,12]),('building-f',-55,64,[16,7,12]),
 ('building-g',-30,66,[11,6,10]),('building-h',54,65,[16,7.5,12]),
 ('building-i',30,66,[12,5.5,12]),('building-j',58,42,[14,6.5,11]),
 ('building-k',58,2,[15,7,12]),('building-l',32,-28,[13,7,10]),
 ('building-m',60,-32,[14,7,10]),('building-n',58,-68,[14,8,11]),
 ('building-o',28,-70,[12,7,11]),('building-p',-30,-68,[13,6.5,10]),
 ('building-q',-66,-69,[12,7,10]),('building-r',-36,30,[12,6,10]),
 ('building-s',-20,4,[5,4.5,15]),('building-t',20,-6,[5,4.5,15])]
for model,x,z,size in buildings:
    add('industrial/'+model,x,z,size)
    # Roof services, loading aprons, and roadside parked pallets.
    surface(x,z+size[2]*.5+2,size[0]+2,3,'4a504c')
    for k in range(3):
        name=['factory/box-small','factory/box-wide','factory/box-large'][(k+len(objects))%3]
        add(name,x-size[0]*.45+k*1.8,z+size[2]*.5+3,[1.2,.9,1.05])
# Container terminal, with access aisles and stacked rows.
for x in [18,26,34,42]:
    for z in [-2,9,31,42]:
        model='industrial/shipping-container-'+rng.choice('abc')
        add(model,x,z,[2.65,2.55,6.2])
        if rng.random()<.3:add(model,x,z,[2.65,2.55,6.2],y=2.55)
# Tank farm and mechanical piping.
for x in [22,34,46]:
    for z in [-44,-50]:add('industrial/detail-tank-large',x,z,[5,6.2,5])
for x in [18,25,32,39,46,53]:
    add('factory/pipe-large-long',x,-37,[5.8,1.2,1.2],y=1.7,collision=False)
for x in [18,53]:add('factory/pipe-large-bend',x,-40,[1.8,2.3,1.8],y=.3)
add('industrial/water-tower',65,-49,[7,18,7])
# Power services and a solar field.
for x in [-68,-58,-48,-38,-28]:
    for z in [-81,-76]:add('industrial/solar-panel-landscape-group',x,z,[6,1.7,3.8],collision=True)
for x,z in [(-72,-52),(72,-75)]:add('industrial/windmill',x,z,[8,24,8])
# Factories have distinct machinery on concrete pads.
factory_names=['machine','machine-bed','machine-connection-hole','machine-connection-pipe','machine-fortified','machine-window','machine-window-bar','conveyor','conveyor-corner','conveyor-long','conveyor-sides','conveyor-stripe','conveyor-bars','conveyor-bars-fence','conveyor-junction-t','hopper-high-round','hopper-high-square','hopper-round','hopper-square','robot-arm-a','robot-arm-b','scanner-high','scanner-low','screen-wide','screen-panel-wide','lever-double','pipe-large-valve','pipe-large-junction','pipe-glass-large-valve','pipe-glass-large-cross','piston-round','piston-square','catwalk-straight','catwalk-corner','catwalk-stairs','crane','crane-lift','crane-magnet','structure-high','structure-window','door-wide-open','warning-orange','cone','box-large','box-wide','box-small']
for k,name in enumerate(factory_names):
    # Four outdoor maintenance yards, keeping the arterial road clear.
    cluster=k%4;cx,cz=[(-55,9),(-28,44),(49,-14),(53,19)][cluster]
    row=k//4;col=row%3;line=row//3
    x=cx+(col-1)*3.4;z=cz+(line-1.5)*3.1
    m=metadata['factory/'+name];w,h,d=m['size']
    scale=1.35 if name.startswith(('machine','robot','crane')) else 1.05
    add('factory/'+name,x,z,[w*scale,h*scale,d*scale],collision=not name.startswith(('screen','catwalk','pipe-glass')))
# Small set dressing: edges, service lanes and loading bays.
for k in range(85):
    x=rng.choice([-1,1])*rng.uniform(11,71);z=rng.uniform(-80,80)
    if any(abs(z-cross)<6 for cross in [-57,-15,20,56]):continue
    if any(abs(x-bx)<s[0]*.5+1.5 and abs(z-bz)<s[2]*.5+1.5 for _,bx,bz,s in buildings):continue
    model=rng.choice(['factory/cone','factory/box-long','factory/box-small','factory/pipe-large-valve','factory/warning-orange'])
    dims=metadata[model]['size'];scale=rng.uniform(.65,1.3)
    add(model,x,z,[v*scale for v in dims],angle=rng.choice([0,90,180,270]))
# Southern gate is a dressed arrival district, with cover near the first screen.
for side in [-1,1]:
    add('industrial/building-i',side*14,73,[5.5,3.8,6])
    for z in [62,69,81]:
        add('industrial/shipping-container-b',side*12.7,z,[2.65,2.55,6.2],angle=90)
    for z in [65,76,84]:
        add('factory/warning-traffic',side*7.9,z,[1.8,1,.5])
        add('factory/box-wide',side*9.3,z+1,[1.3,.8,1.0])
    for xoffset in [0,1.7]:
        add('factory/box-large',side*(17+xoffset),77,[1.5,1.0,1.3])
# Service vehicles, loading trucks and scattered mechanical debris.
vehicles=[('truck',-38,50,[2.7,3.3,7]),('truck-flat',24,56,[2.7,2.8,7]),('delivery',-12,53,[2.2,2.4,5.1]),('delivery-flat',12,46,[2.2,2.4,5.4]),('van',11,77,[2.1,2.3,4.8]),('suv',-10,83,[2.1,2.1,4.6]),('sedan',-24,-15,[1.9,1.7,4.5]),('tractor',-65,35,[2.3,2.6,4.1]),('tractor-shovel',49,-59,[2.7,3.1,5]),('garbage-truck',70,-12,[2.8,3.4,7]),('police',-17,-58,[2,1.8,4.7])]
for model,x,z,size in vehicles:add('vehicles/'+model,x,z,size,angle=90 if abs(z-56)<3 else 0)
for k,name in enumerate(['debris-tire','debris-drivetrain','debris-drivetrain-axle','debris-door','debris-bumper','debris-plate-a','debris-plate-b','debris-spoiler-a','debris-door-window']):
    add('vehicles/'+name,-25+(k%3)*2,44+(k//3)*2,collision=False)
# Lighting is spatially limited and shadow-free for mobile.
for z in [-76,-44,-9,25,63,81]:
    for x in [-8,8]:
        lights.append(dict(position=[x,7,z],color='ffd79a' if x<0 else '9dd4dc',energy=2.2,radius=17))
# Search boxes: seven original positions retained; new boxes spread across all districts.
loot=[dict(position=[x,0,z],name=n) for x,z,n in [(-2.7,17.2,'工具箱'),(7,19,'医疗补给'),(-6,10.7,'军用物资'),(7.1,1.2,'附件箱'),(-8,-3.6,'封存货箱'),(15.6,-16.5,'电子物资'),(-7,-19.5,'保险货箱')]]
for k,(x,z) in enumerate([(-14,70),(15,69),(-42,70),(42,58),(-68,48),(-42,26),(54,28),(68,16),(-62,12),(-34,14),(-62,-21),(-33,-22),(32,-40),(49,-55),(-17,-68),(54,-79),(-57,-82),(14,-76),(-70,-45),(66,69)]):
    loot.append(dict(position=[x,0,z],name=['物资箱','工业补给','工具箱','电子物资','医疗补给'][k%5]))
zones=[dict(id=i,name=n,position=[x,z],color=c) for i,n,x,z,c in [('south','南港货闸',0,65,'cfaf6c'),('rail','铁路仓储',-48,40,'899d9e'),('terminal','集装箱码头',30,22,'6da4ac'),('customs','海关仓库',-45,-22,'b5aa8a'),('fuel','油罐区',39,-46,'b18b6d'),('power','能源站',-48,-71,'83aaa4'),('north','北侧撤离区',0,-75,'68d9ba')]]
entries=[dict(id='south',name='南港货闸',position=[0,0,78]),dict(id='east',name='东侧维修区',position=[70,0,58]),dict(id='west',name='西侧铁路',position=[-68,0,55])]
# Relocate any search box swallowed by a large building/vehicle footprint.
def blocked(x,z,margin=1.1):
    for obj in objects:
        if not obj['collision'] or obj['position'][1]>=1.2:continue
        a=math.radians(obj['rotation']);w,h,d=obj['size'];px,py,pz=obj['position']
        hw=(abs(math.cos(a))*w+abs(math.sin(a))*d)*.5+margin
        hd=(abs(math.sin(a))*w+abs(math.cos(a))*d)*.5+margin
        if abs(x-px)<=hw and abs(z-pz)<=hd:return True
    return False
for record in loot:
    px,_,pz=record['position']
    if blocked(px,pz):
        candidates=[(px+dx,pz+dz) for radius in range(1,15) for dx in range(-radius,radius+1) for dz in range(-radius,radius+1) if max(abs(dx),abs(dz))==radius]
        for x,z in candidates:
            if abs(x)<77 and abs(z)<87 and not blocked(x,z):record['position']=[x,0,z];break
layout=dict(schema_version=1,id='gray_harbor',name='灰港 · 工业港',bounds=[160,180],previous_bounds=[48,52],area_multiplier=160*180/(48*52),objects=objects,surfaces=surfaces,lights=lights,loot=loot,zones=zones,entries=entries,extraction=[0,0,-77])
from industrial_layout import assemble
layout=assemble(layout)
(ROOT/'data/harbor_layout.json').write_text(json.dumps(layout,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('HARBOR_LAYOUT',len(objects),'placements',len(set(x['model'] for x in objects)),'model types',len(loot),'loot locations; area x',layout['area_multiplier'])
