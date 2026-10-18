# SDC valuable models

48 original, editable Blender assets. Source geometry remains separate under each
item's root, with original materials and editable lettering. The default startup
scene is not exported. Production GLBs each contain one joined mesh, in metres.

`SDC/scripts/generate_valuables.py` is compatible with the installed Blender MCP
safe mode: it uses bpy and pure math/json, with no file execution, external asset
loading, subprocess, handler, timer or driver. Read the script outside Blender,
submit its code through MCP, then explicitly call `init()`, `build(ids)`,
`render(ids)` in small batches, and `save()`. `init()` recovers completed assets
from the scene's root metadata. Create output folders before invoking Blender.
Set ROOT/OUT/ICONS/SOURCE in the submitted code for another checkout.

Icons are real orthographic renders of these same models, with transparency and
fixed studio lighting. Master PNGs are 640×640; Godot imports limit them to 320px
for phone memory. `register_valuable_assets.py` registers the final exported files.
The catalog, categories, rarity, price, dimensions and descriptions are owned by
`data/valuable_catalog.json`, merged by `sync_valuable_catalog.py`.

All original meshes and rendered icons are CC0-1.0. No third-party or service-
generated model data is included.
