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
  The game targets phone touch only. Do not add keyboard/mouse gameplay, UI
  fallbacks, shortcuts, or touch-to-mouse emulation. Settings, pickers, scrolling
  and previews must directly handle ScreenTouch/ScreenDrag. Keep Android system
  back and the phone text/number keyboard. Opening a modal must cancel existing
  gestures immediately, including touches released after that modal is closed.
  Custom HUD layouts must share rendering and hit geometry, keep required
  controls accessible, and never emit gameplay actions from the layout editor.
- Inventory/equipment changes must conserve item counts and quantities. A
  failed placement must restore inventory, equipment, money and contents;
  loading a save or replacing a container must not discard items. Backpack
  and rig slots are independent. Plain rigs provide storage and can be worn
  with body armor; combined armored rigs replace body armor. A faded armor-slot
  alias must reference the same rig UID without adding a second item. Do not
  treat a completed placement as the first
  tap of a new double-tap unequip action.
- Keep Android application ID `org.prototype.shooter25d`, the established
  fixed signing certificate, increasing versionCode and compatible saves.
  Missing signing material must be restored from a backup, never regenerated
  as a workaround. The user approved a one-time reinstall when switching from
  the original cloud 0.3.0 to local 0.4.3; routine later updates must not clear data.

Code review and desktop source inspection do not require Android private keys.

## Player feedback and visual acceptance

- Read `docs/PLAYER_FEEDBACK.md` before changing UI or interaction design. It
  separates explicit user requests from inferred preferences; later explicit
  feedback wins. Persist new feedback and read it back in the same turn.
- Secondary details, instructions and contextual item actions appear only on
  demand in windows above the page. They must not reserve empty space or shrink
  inventory/product grids. Item details are an adjacent bounded popover.
- Player acceptance requires actual production frames and raw ScreenTouch /
  ScreenDrag journeys, including multitouch. Do not treat successful commands,
  state snapshots, static source inspection or APK export as proof of usable UI.
  Development AI tooling runs an isolated profile and submits real phone events;
  this is not authorization to restore human keyboard/mouse fallback controls.
Keys, credentials, APKs and Godot import caches stay outside Git. See
`SDC/AGENTS.md` and `SDC/docs/ANDROID_UPDATES.md` for the signing identity.
Report bugs with the affected flow and code location; distinguish static
findings, export checks and device results. Do not claim phone validation
without an actual device run. Do not merge a PR just because review was requested.
