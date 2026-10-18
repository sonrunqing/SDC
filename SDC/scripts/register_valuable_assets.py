"""Register original Blender exports and their exact production identities."""
import json,struct,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
if __name__=='__main__':
    definitions=json.loads((ROOT/'data/valuable_catalog.json').read_text('utf8'))
    assets=[]
    for item in definitions['items']:
        ident=item['id'];path=ROOT/'assets/valuables'/(ident+'.glb')
        icon=ROOT/'assets/icons/items'/(ident+'.png')
        blob=path.read_bytes();magic,version,length=struct.unpack_from('<III',blob)
        if magic!=0x46546c67 or version!=2 or length!=len(blob):raise ValueError('Invalid GLB '+ident)
        size,kind=struct.unpack_from('<II',blob,12)
        if kind!=0x4e4f534a:raise ValueError('No GLB JSON '+ident)
        gltf=json.loads(blob[20:20+size])
        meshes=gltf.get('meshes',[])
        if len(meshes)!=1 or not meshes[0]['name'].startswith(ident):raise ValueError('Unexpected exported scene '+ident)
        tris=sum(gltf['accessors'][p['indices']]['count']//3 for mesh in meshes for p in mesh['primitives'])
        positions=[gltf['accessors'][p['attributes']['POSITION']] for mesh in meshes for p in mesh['primitives']]
        low=[min(p['min'][axis] for p in positions) for axis in range(3)]
        high=[max(p['max'][axis] for p in positions) for axis in range(3)]
        image=icon.read_bytes()
        if image[:8]!=b'\x89PNG\r\n\x1a\n':raise ValueError('Icon missing '+ident)
        width,height=struct.unpack_from('>II',image,16)
        assets.append(dict(id=ident,name=item['name'],group=item['loot_category'],rarity=item['rarity'],
            path='res://assets/valuables/'+path.name,icon='res://assets/icons/items/'+icon.name,
            triangles=tris,position_size=[round(high[i]-low[i],6) for i in range(3)],
            bytes=len(blob),sha256=digest(path),icon_sha256=digest(icon),icon_source_size=[width,height]))
    source=ROOT.parent/'art_source/valuables/SDC-valuables.blend'
    manifest=dict(schema=1,license='CC0-1.0',generator='scripts/generate_valuables.py',
        source='art_source/valuables/SDC-valuables.blend',source_sha256=digest(source),
        blender_version='5.2.1 LTS',assets=assets)
    (ROOT/'data/valuable_models.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n','utf8')
    print('VALUABLE_ASSETS_REGISTERED',len(assets),'triangles',sum(a['triangles'] for a in assets),'bytes',sum(a['bytes'] for a in assets))
