# Source-rendered presentation captures

These images come from the actual Godot 4.6.3/OpenGL production scene and grid
components. They are art captures from an isolated local save, not phone
screenshots or mobile touch/performance test results.

## SDC 0.4.13

- `SDC-v0.4.13-aim.png`: existing right aim stick posed toward the upper right;
  production character, muzzle and four-arm reticle use the same world heading.
- `SDC-v0.4.13-rarity.png`: unknown cells stay neutral; revealed gray, green,
  blue, yellow and red underlays are separate from original-color item icons.

The capture tools live in `SDC/tools/`, which is excluded from Android exports.
Build identity and scope are in `development/android-v0.4.13.json`.

## SDC 0.4.14 (final)

- `SDC-v0.4.14-aim.png`: small gear menu, touch aim crosshair; no search control
  is shown away from an accessible supply container.
- `SDC-v0.4.14-near-loot.png`: the circular search control appears near a valid
  indoor supply container, alongside the same small gear and aim crosshair.
- `SDC-v0.4.14-rarity.png`: the production grid's separate solid rarity underlay
  and original-color item artwork; unknown cells keep neutral colors.

Final build identity is `development/android-v0.4.14.json`. All captures are
local production rendering, with no simulated finger events or device results.
