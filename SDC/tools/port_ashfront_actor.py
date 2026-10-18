"""Production asset conversion: keep SDC body/equipment, reuse Ashfront's animation rig.
Run in Blender: blender --background --python this_file -- OLD_PROJECT SDC_PROJECT
Neither source GLB is overwritten. No desktop input or gameplay is transferred.
"""
import bpy, sys, math, json
from pathlib import Path
from mathutils.kdtree import KDTree

old, project = map(Path, sys.argv[sys.argv.index('--') + 1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(old / 'assets/hero/hero_animated.glb'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
reference = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
rig.data.pose_position = 'REST'
tree = KDTree(len(reference.data.vertices))
for v in reference.data.vertices:
    tree.insert(reference.matrix_world @ v.co, v.index)
tree.balance()
old_groups = {v.index: [(reference.vertex_groups[g.group].name, g.weight) for g in v.groups]
              for v in reference.data.vertices}
before = set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(project / 'assets/operator/operator.glb'))
body = next(o for o in bpy.context.scene.objects if o not in before and o.type == 'MESH')
body.name = 'SDCOperator'
# Ashfront is authored facing +Z in Godot; SDC's static mesh faces -Z.
body.rotation_mode = 'XYZ'
body.rotation_euler.z += math.pi
bpy.context.view_layer.objects.active = body
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
for bone in rig.data.bones:
    body.vertex_groups.new(name=bone.name)
for v in body.data.vertices:
    samples = tree.find_n(body.matrix_world @ v.co, 4)
    weights = {}
    for _, index, distance in samples:
        for name, weight in old_groups[index]:
            weights[name] = weights.get(name, 0) + weight / max(distance, .012) ** 3
    top = sorted(weights.items(), key=lambda x: x[1], reverse=True)[:4]
    total = sum(w for _, w in top)
    if not total:
        top, total = [('Hips', 1)], 1
    for name, weight in top:
        body.vertex_groups[name].add([v.index], weight / total, 'REPLACE')
mod = body.modifiers.new('AshfrontRig', 'ARMATURE')
mod.object = rig
body.parent = rig
bpy.data.objects.remove(reference, do_unlink=True)
rig.data.pose_position = 'POSE'
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = rig
destination = project / 'assets/ashfront'
destination.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(destination / 'operator_animated.glb'),
    export_format='GLB', use_selection=True, export_animations=True,
    export_animation_mode='ACTIONS', export_skins=True, export_yup=True)
(destination / 'gait.json').write_bytes((old / 'assets/hero/gait.json').read_bytes())
print(json.dumps({'asset': str(destination / 'operator_animated.glb'),
                  'vertices': len(body.data.vertices), 'bones': len(rig.data.bones),
                  'actions': [a.name for a in bpy.data.actions]}, ensure_ascii=False))
