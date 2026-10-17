"""Build reusable Godot scenes and explicit collision data from Blender's exports.

Run after exporting the Blender modules and expansion. Geometry bounds are exported by Blender;
collision pieces use bottom-centre coordinates in metres and remain editable here.
"""
import json, hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parents[1] / "模型库"

def box(position, size, navigation=True):
    return dict(type="box", position=position, size=size, navigation=navigation)

def definitions(key):
    if key in ('infill_1m', 'infill_2m'):
        width = 1 if key == 'infill_1m' else 2
        return [width,3,.2], [box([0,1.5,0],[width,3,.2])]
    if key == 'inner_corner':
        return [1,3,1], [box([.425,1.5,0],[.15,3,1]), box([0,1.5,-.425],[1,3,.15])]
    if key == 'window_panel': return [4,3,.2], [box([0,1.5,0],[4,3,.2])]
    if key == 'freight_frame':
        return [4.5,3,.28], [box([-2.125,1.5,0],[.25,3,.28]),
            box([2.125,1.5,0],[.25,3,.28]),box([0,2.8,0],[4,.4,.28],False)]
    if key == 'roller_shutter': return [4,2.6,.1], [box([0,1.3,0],[4,2.6,.1])]
    if key == 'loading_dock':
        return [4,.98,2], [box([0,.4,0],[4,.8,2]),
            box([0,.89,-.94],[4,.18,.12],False),
            box([-1.45,.89,.94],[1.1,.18,.12],False),box([1.45,.89,.94],[1.1,.18,.12],False)]
    if key == 'catwalk':
        return [4,1.12,2], [box([0,.06,0],[4,.12,2],False),
            box([0,.62,-.96],[4,1,.08],False),box([0,.62,.96],[4,1,.08],False)]
    if key == 'guardrail': return [2,1,.2], [box([0,.5,0],[2,1,.2])]
    if key == 'storage_rack':
        pieces=[box([x,1.2,z],[.12,2.4,.12]) for x in [-.94,.94] for z in [-.34,.34]]
        pieces += [box([0,y,0],[2,.12,.8],y<1) for y in [.28,1.20,2.18]]
        return [2,2.4,.8], pieces
    if key == 'workbench':
        return [2,1.18,.8], [box([0,.85,0],[2,.10,.8]),box([.62,.42,0],[.68,.84,.75]),
            box([-.92,.42,-.33],[.10,.84,.10]),box([-.92,.42,.33],[.10,.84,.10]),
            box([.58,1.03,0],[.38,.30,.35],False)]
    if key == 'dock_ramp':
        return [1.6,.805,2], [dict(type='ramp',position=[0,0,0],size=[1.6,.8,2],navigation=True)]
    if key == 'platform_access':
        nominal, pieces = definitions('platform')
        return nominal, [p for p in pieces if p['position'] != [.97,3.43,0]]
    if key in ("wall_straight", "wall_window", "partition"):
        depth = {"wall_straight": .2, "wall_window": .22, "partition": .18}[key]
        return [4,3,depth], [box([0,1.5,0],[4,3,depth])]
    if key == "wall_doorway":
        return [4,3,.24], [
            box([-1.25,1.5,0],[1.5,3,.24]),
            box([1.25,1.5,0],[1.5,3,.24]),
            box([0,2.6,0],[1,.8,.24],False)]
    if key == "corner":
        return [2,3,2], [box([.90,1.5,0],[.20,3,2]), box([0,1.5,-.90],[2,3,.20])]
    if key == "floor": return [4,.08,4], [box([0,.04,0],[4,.08,4],False)]
    if key == "ceiling": return [4,.12,4], [box([0,.06,0],[4,.12,4],False)]
    if key == "roof_edge": return [4,.28,.35], [box([0,.14,0],[4,.28,.35],False)]
    if key == "beam": return [4,.34,.28], [box([0,.17,0],[4,.34,.28],False)]
    if key == "pillar": return [.42,3,.42], [box([0,1.5,0],[.42,3,.42])]
    if key == "door": return [1.2,2.2,.16], [box([0,1.1,0],[1.2,2.2,.16])]
    if key == "stairs":
        rails = []
        for x in [-.77,.77]:
            rail=box([x,2.05,0],[.08,.65,5.49],False)
            rail["rotation"]=[33.11,0,0]
            rails.append(rail)
        return [1.6,3.795,4.6], [dict(type="ramp", position=[0,0,0], size=[1.6,3,4.6], navigation=True)]+rails
    if key == "platform":
        pieces = [box([0,2.94,0],[2,.14,2],False)]
        for x in [-.82,.82]:
            for z in [-.82,.82]: pieces.append(box([x,1.45,z],[.2,2.9,.2]))
        # Full north/sides, with an entrance between the two south posts.
        pieces += [box([0,3.43,-.97],[2,.85,.07],False),
                   box([-.97,3.43,0],[.07,.85,2],False),
                   box([.97,3.43,0],[.07,.85,2],False)]
        return [2.04,3.86,2.04], pieces
    raise ValueError(key)

def vec(v): return "Vector3(" + ", ".join(f"{n:.8f}" for n in v) + ")"

assets = json.loads((ROOT/"data/industrial_module_exports.json").read_text(encoding="utf-8"))["assets"]
expansion = ROOT/"data/industrial_expansion_exports.json"
if expansion.exists():
    assets += json.loads(expansion.read_text(encoding="utf-8"))["assets"]
scene_dir = ROOT/"scenes/environment/industrial_modules"
scene_dir.mkdir(parents=True, exist_ok=True)
for asset in assets:
    key = asset["key"]
    nominal, pieces = definitions(key)
    asset.update(collision_size=nominal, colliders=pieces, preserve_materials=True)
    # Tone down the pale generated surfaces under the game's outdoor lighting.
    asset['material_tint'] = ([.60,.68,.74] if key in ('ceiling','roof_edge','beam') else
        [.68,.73,.72] if key=='floor' else [.70,.80,.86] if key in
        ('wall_straight','wall_window','window_panel','infill_1m','infill_2m','corner','inner_corner','partition') else [.84,.88,.92])
    source = SOURCE/asset["source_file"]
    asset["source_sha256"] = hashlib.sha256(source.read_bytes()).hexdigest()
    asset["export_sha256"] = hashlib.sha256((ROOT/asset["path"].removeprefix("res://")).read_bytes()).hexdigest()
    asset["source"] = "User supplied Hunyuan 3D asset; original retained in D:/aa/模型库"
    native = asset["size"]
    scale = [nominal[i]/native[i] for i in range(3)]
    pivot = [asset["min"][0]+native[0]/2, asset["min"][1], asset["min"][2]+native[2]/2]
    lines = ['[gd_scene load_steps=%d format=3]' % (2+len(pieces)),
             '', '[ext_resource type="PackedScene" path="%s" id="1_visual"]' % asset["path"]]
    for i, piece in enumerate(pieces):
        lines += ["", '[sub_resource type="%s" id="Shape_%d"]' % ("ConvexPolygonShape3D" if piece["type"]=="ramp" else "BoxShape3D", i)]
        if piece["type"] == "ramp":
            w,h,d = piece["size"]
            points = [(-w/2,0,-d/2),(w/2,0,-d/2),(-w/2,h,-d/2),(w/2,h,-d/2),(-w/2,0,d/2),(w/2,0,d/2)]
            lines += ["points = PackedVector3Array(" + ", ".join(str(n) for p in points for n in p) + ")"]
        else: lines += ["size = "+vec(piece["size"])]
    lines += ["", '[node name="%s" type="Node3D"]' % key,
              'metadata/module_id = "%s"' % asset["id"],
              'metadata/grid_metres = 4.0',
              "", '[node name="Visual" parent="." instance=ExtResource("1_visual")]',
              "position = "+vec([-pivot[i]*scale[i] for i in range(3)]), "scale = "+vec(scale),
              "", '[node name="Collision" type="StaticBody3D" parent="."]']
    for i, piece in enumerate(pieces):
        lines += ["", '[node name="Piece%d" type="CollisionShape3D" parent="Collision"]' % i,
                  "position = "+vec(piece["position"]), 'shape = SubResource("Shape_%d")' % i]
        if "rotation" in piece:
            import math
            lines += ["rotation = "+vec([math.radians(n) for n in piece["rotation"]])]
    (scene_dir/(key+".tscn")).write_text("\n".join(lines)+"\n", encoding="utf-8")
(ROOT/"data/industrial_modules.json").write_text(json.dumps(dict(schema_version=1,units="metres",grid=4,assets=assets),ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("INDUSTRIAL_CATALOG", len(assets), "modules;",sum(x["triangles"] for x in assets),"unique triangles")
