"""Place the repaired expansion modules in the playable industrial quarter."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def extend(layout):
    modules = {a['key']:a for a in json.loads((ROOT/'data/industrial_modules.json').read_text(encoding='utf-8'))['assets']}
    objects, surfaces = layout['objects'], layout['surfaces']
    original_buildings = list(layout['buildings'])

    def add(key, x, z, y=0, angle=0, size=None, building='', cutaway=''):
        a = modules[key]
        record = dict(model=a['id'],position=[x,y,z],size=size or a['collision_size'],rotation=angle,collision=True)
        if building: record['building'] = building
        if cutaway: record['cutaway'] = cutaway
        objects.append(record)
        return record

    def prop(model, x, z, size, y=0, angle=0, building=''):
        record=dict(model=model,position=[x,y,z],size=size,rotation=angle,collision=False)
        if building:record['building']=building
        objects.append(record)

    def paint(x,z,w,d,color,y=.057):
        surfaces.append(dict(position=[x,y,z],size=[w,.009,d],color=color))

    # Swap stretched placeholders for the correctly sized, repaired panels.
    for record in objects:
        if record['model'] == 'industrial_modular/wall_window':
            record['model'] = 'industrial_modular/window_panel'
            record['size'] = modules['window_panel']['collision_size']
        elif record['model'] == 'industrial_modular/wall_straight' and record['size'][0] == 2:
            record['model'] = 'industrial_modular/infill_2m'
            record['size'] = modules['infill_2m']['collision_size']
        elif record['model'] == 'industrial_modular/platform' and record['position'] == [-43,0,-34]:
            record['model'] = 'industrial_modular/platform_access'

    # Finish the four freight entrances. Their raised curtains leave 2.25 m headroom.
    for b in original_buildings:
        cx,cz=b['center'];w,d=b['size'];north=cz-d/2;south=cz+d/2;bid=b['id']
        add('freight_frame',cx,south,building=bid,cutaway=bid)
        add('roller_shutter',cx,south+.015,y=2.25,size=[4,.35,.1],building=bid,cutaway=bid)
        for x in [cx-w/2-.5,cx+w/2+.5]:
            add('guardrail',x,south+2.1,angle=90)
        # Wall racks leave the central entrance-to-loot aisle clear.
        racks = [cx-3,cx,cx+3] if w==16 else [cx-2,cx+1]
        if bid=='repair_shop': racks=[cx+1.2]
        for x in racks:
            add('storage_rack',x,north+.7,building=bid)
            # Small packages sit directly on shelf surfaces and share no new collision.
            for shelf_y in [.34,1.26,2.24]:
                prop('factory/box-small',x-.40,north+.7,[.55,.40,.48],y=shelf_y,building=bid)
                prop('factory/box-wide',x+.40,north+.7,[.65,.34,.5],y=shelf_y,building=bid)
        if bid=='repair_shop':
            add('workbench',cx-3,north+.65,building=bid)
            add('workbench',cx+5.35,cz+.4,angle=270,building=bid)
        elif bid=='assembly_shop':
            add('workbench',cx-4.9,cz+.8,angle=90,building=bid)
        elif bid=='dispatch_office':
            add('workbench',cx-4.9,cz,angle=90,building=bid)
        paint(cx,south+2.1,.10,3.5,'d2ae55')

    # A compact parts store uses the 1 m corners/infills without stretching 4 m walls.
    bid='parts_store';cx,cz=-18,-36;w,d=8,6
    left,right,north,south=cx-w/2,cx+w/2,cz-d/2,cz+d/2
    layout['buildings'].append(dict(id=bid,name='备件与耗材库',center=[cx,cz],size=[w,d],entry=[left-1,0,cz],roof_height=3))
    # Clear pre-existing random dressing from its footprint and the narrow service alley.
    objects[:]=[o for o in objects if o['model'].startswith('industrial_modular/') or
        not(left-1.7<o['position'][0]<right+1 and north-1<o['position'][2]<south+5)]
    for x,z,angle in [(right-.5,north+.5,0),(left+.5,north+.5,90),
        (left+.5,south-.5,180),(right-.5,south-.5,270)]:
        add('inner_corner',x,z,angle=angle,building=bid,cutaway=bid if z>cz or x>cx else '')
    for x in [left+2,left+4,left+6]:add('infill_2m',x,north,building=bid)
    for x in [left+1.5,right-1.5]:add('infill_1m',x,south,building=bid,cutaway=bid)
    add('freight_frame',cx,south,building=bid,cutaway=bid)
    add('roller_shutter',cx,south+.015,building=bid,cutaway=bid)
    # Two metre side entrance remains open while the freight curtain is closed.
    for z in [north+1.5,south-1.5]:add('infill_1m',left,z,angle=90,building=bid)
    add('freight_frame',left,cz,angle=90,size=[2.25,3,.28],building=bid)
    add('window_panel',right,cz,angle=90,building=bid,cutaway=bid)
    for x in [left+2,left+6]:
        for z in [north+1,north+3,north+5]:
            add('floor',x,z,y=-.065,size=[4,.08,2],building=bid)
            add('ceiling',x,z,y=3.01,size=[4,.12,2],building=bid,cutaway=bid)
        for z in [north,south]:add('roof_edge',x,z,y=3.13,building=bid,cutaway=bid)
        add('beam',x,cz,y=2.67,building=bid,cutaway=bid)
    for x in [left,right]:
        for z in [north+1.5,south-1.5]:add('roof_edge',x,z,y=3.13,angle=90,size=[3,.28,.35],building=bid,cutaway=bid)
    add('storage_rack',cx-1.6,north+.7,building=bid)
    add('storage_rack',cx+1.3,north+.7,building=bid)
    add('workbench',right-.65,cz+.7,angle=270,building=bid)
    layout['loot'].append(dict(position=[cx-.5,0,cz+.6],name='备件与耗材箱'))
    layout['lights'].append(dict(position=[cx,2.8,cz],color='e3d4ae',energy=1.0,radius=7,fixture='ceiling',cutaway=bid))
    paint(cx,south+2.2,9,4.2,'525b56')
    for x in [cx-2.4,cx+2.4]:paint(x,south+2.1,.12,3.8,'d2ae55',.069)

    # Side loading deck at customs and a dock in front of the closed parts-store bay.
    add('loading_dock',-60,-27.8)
    add('dock_ramp',-57,-27.8,angle=90)
    add('loading_dock',cx,south+1.2)
    add('dock_ramp',cx,south+3.2)
    # Reach the 3 m inspection bridge via the existing stairs and opened east platform.
    add('catwalk',-40,-34,y=2.88)
    add('guardrail',-38,-34,y=3.0,angle=90)
    for x in [-41,-39]:paint(x,-34,.10,1.4,'b19b57')
    # Remove crates originally scattered across the platform/stair service corridor.
    objects[:]=[o for o in objects if o['model'].startswith('industrial_modular/') or
        not(-44.4<o['position'][0]<-37.7 and -35.3<o['position'][2]<-25.8)]
    layout['industrial_revision']=2
    layout['industrial_notes'].update(assemblies=5,expansion_sources=11,
        entrances='Four raised freight curtains and one closed storage curtain with an open 2 m side entrance.',
        elevated_route='Existing stairs -> east-open inspection platform -> legless catwalk with end guardrail.',
        loading='0.8 m decks with separate shallow access ramps; main freight aisles remain clear.')
    return layout
