# Original modular gun models

Generated with Blender by `scripts/generate_models.py`. Each catalog gun and attachment owns an individual GLB. Factory magazines, stocks and handguards are also independent GLBs.

Metres; +Y up, firing -Z; body origin receiver center. Attachment origin is its mounting point. Identity transforms attach to `Socket_<slot>` empties.

`data/weapon_geometry.json` records physical socket positions, independent factory model paths, triangle counts and SHA-256 provenance for every asset. Factory pieces are hidden by replacement at that socket, never baked into bodies.

All meshes are original low-poly hard-surface models, CC0. They are development art with physical details and different class silhouettes, not exact branded gun reproductions.
