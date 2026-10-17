# SDC repository

The Godot project is in `SDC/`, with `SDC/project.godot` as its entry point.
Runtime code is GDScript in `SDC/scripts/`; scene and catalog data are in
`SDC/scenes/` and `SDC/data/`. Art sources, models, icons and licenses are
included in `SDC/assets/`. Godot 4.6.3 is the established project version.

## Code Review Rules

- Mobile movement, aiming and firing must have independent pointer ownership.
  Flag input changes that fire while moving/aiming, reuse another finger's
  release, or activate a button after a scroll/drag. Keep deliberate tap,
  double-tap and drag interactions available.
  Custom HUD layouts must share rendering and hit geometry, keep required
  controls accessible, and never emit gameplay actions from the layout editor.
- Inventory/equipment changes must conserve item counts and quantities. A
  failed placement must restore inventory, equipment, money and contents;
  loading a save or replacing a container must not discard items. Backpack
  and armored-rig slots are independent; only body armor versus armored rig
  is intentionally exclusive. Do not treat a completed placement as the first
  tap of a new double-tap unequip action.
- Keep Android application ID `org.prototype.shooter25d`, the established
  fixed signing certificate, increasing versionCode and compatible saves.
  Missing signing material must be restored from a backup, never regenerated
  as a workaround. The user approved a one-time reinstall when switching from
  the original cloud 0.3.0 to local 0.4.3; routine later updates must not clear data.

Code review and desktop source inspection do not require Android private keys.
Keys, credentials, APKs and Godot import caches stay outside Git. See
`SDC/AGENTS.md` and `SDC/docs/ANDROID_UPDATES.md` for the signing identity.
Report bugs with the affected flow and code location; distinguish static
findings, export checks and device results. Do not claim phone validation
without an actual device run. Do not merge a PR just because review was requested.
