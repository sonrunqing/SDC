"""Indoor loot placement and orderly freight dressing, shared by map regeneration."""
import json, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def organize(layout):
    metadata = {}
    for filename in ['environment_models.json', 'industrial_modules.json']:
        metadata.update({a['id']: a for a in json.loads((ROOT/'data'/filename).read_text('utf8'))['assets']})
    buildings = layout['buildings']
    def inside(x, z):
        return any(abs(x-b['center'][0]) < b['size'][0]/2 and abs(z-b['center'][1]) < b['size'][1]/2 for b in buildings)
    # Keep interior shelf packages; remove isolated roadside crates. Outdoor
    # freight is rebuilt as a few aligned stacks, with the main lanes open.
    layout['objects'] = [o for o in layout['objects'] if not
        (o['model'].startswith('factory/box-') and o['position'][1] < .1 and
         not inside(o['position'][0], o['position'][2]) and not o.get('building'))]
    layout['objects'] = [o for o in layout['objects'] if not o.get('organized_freight')]
    for x,z in [(16,36),(38,36),(16,14),(38,14),(-50,58),(-32,58)]:
        for offset in [-1.1,0,1.1]:
            layout['objects'].append(dict(model='factory/box-wide',position=[x+offset,0,z],
                size=[.95,.72,.85],rotation=0,collision=True,organized_freight=True))
    obstacles = []
    for record in layout['objects']:
        if not record.get('collision'): continue
        x,y,z=record['position'];w,h,d=record['size'];angle=math.radians(record.get('rotation',0))
        c,s=math.cos(angle),math.sin(angle)
        meta=metadata[record['model']]
        if 'colliders' in meta:
            factor=[record['size'][i]/meta['collision_size'][i] for i in range(3)]
            for piece in meta['colliders']:
                center=[piece['position'][i]*factor[i] for i in range(3)]
                dims=[piece['size'][i]*factor[i] for i in range(3)]
                if piece.get('navigation') and y+center[1]-dims[1]/2<1.2:
                    obstacles.append((x+c*center[0]+s*center[2],z-s*center[0]+c*center[2],abs(c)*dims[0]+abs(s)*dims[2],abs(s)*dims[0]+abs(c)*dims[2]))
        elif y<1.2 and h>.18:
            obstacles.append((x,z,abs(c)*w+abs(s)*d,abs(s)*w+abs(c)*d))
    configurations = {
        'customs_hall':(8,['supply','archive','electronics','weapon'],'海关'),
        'repair_shop':(5,['tool','tool','supply'],'机修'),
        'dispatch_office':(5,['archive','electronics','medical'],'调度'),
        'assembly_shop':(6,['tool','supply','medical'],'装配'),
        'parts_store':(2,['tool','electronics','supply'],'备件')}
    labels={'supply':'封存补给箱','archive':'档案盒','electronics':'电子器材箱','weapon':'配件长箱','tool':'工具箱','medical':'急救箱'}
    loot=[]
    for b in buildings:
        count,kinds,prefix=configurations[b['id']]
        cx,cz=b['center'];w,d=b['size']
        candidates=[]
        for iz in range(int((d-2.0)/.5)+1):
            z=cz-d/2+1.0+iz*.5
            for ix in range(int((w-2.0)/.5)+1):
                x=cx-w/2+1.0+ix*.5
                # Dedicated central approach aisle, including the side-door store.
                if b['id']!='parts_store' and abs(x-cx)<1.45:continue
                if b['id']=='parts_store' and abs(z-cz)<.85:continue
                if b['id']=='customs_hall' and x < -56.5 and z < -36.4:continue
                if any(abs(x-ox)<ow/2+.75 and abs(z-oz)<od/2+.62 for ox,oz,ow,od in obstacles):continue
                wall_distance=min(x-(cx-w/2),(cx+w/2)-x,z-(cz-d/2),(cz+d/2)-z)
                candidates.append((wall_distance, z, x))
        candidates.sort()
        placed=[]
        for _,z,x in candidates:
            if any((x-px)**2+(z-pz)**2<1.7**2 for px,pz in placed):continue
            placed.append((x,z))
            if len(placed)==count:break
        if len(placed)!=count:
            raise ValueError(f"Not enough clear indoor positions in {b['id']}: {len(placed)}/{count}")
        for i,(x,z) in enumerate(placed):
            kind=kinds[i%len(kinds)]
            loot.append(dict(id=f"{b['id']}_{i+1:02}",name=f"{prefix}{labels[kind]} {i+1:02}",
                position=[x,0,z],kind=kind,building=b['id'],rotation=90 if abs(x-cx)>w/2-1.6 else 0))
    layout['loot']=loot
    layout['loot_revision']=3
    layout['loot_notes']={'indoor_points':len(loot),'buildings':len(buildings),
        'aisles':'Freight centre lanes and the parts-store side entrance remain clear.',
        'interaction':'Open, discover individual records, take selected quantities, close; leftovers persist.'}
    return layout

if __name__=='__main__':
    path=ROOT/'data/harbor_layout.json'
    layout=organize(json.loads(path.read_text('utf8')))
    path.write_text(json.dumps(layout,ensure_ascii=False,indent=2)+'\n','utf8')
    print('INDOOR_LOOT',len(layout['loot']),'containers in',len(layout['buildings']),'buildings')
