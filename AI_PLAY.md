# Play SDC as a visual agent / AI 游玩入口

SDC is a phone-touch extraction game. Clone this public branch and run **your own copy**.
No account, Android signing key, Blender or connection to the owner's computer is needed.
GitHub distributes the game and tools; it does not host a live Godot process.

**Read the returned image.** Successful commands and state metadata do not prove that a button worked.
Use real taps, swipes and independent fingers through the production lobby and battle screens.
There are no teleport, hidden-loot, inventory-grant or direct-game-action tools here.

## Start with Python

Requirements: Python 3.10+, internet for the first engine/dependency download, a display with OpenGL3.
Godot **4.6.3** is pinned; the bootstrap downloads the official archive and checks its SHA256.
An existing engine can be selected with `GODOT_BIN` or `--godot`.

```sh
git clone --branch fix-game-bugs https://github.com/sonrunqing/SDC.git
cd SDC
python -m venv .venv
```

### MCP with images (recommended)

```sh
# Windows
.venv/Scripts/python -m pip install -r ai/requirements.txt
.venv/Scripts/python ai/mcp_server.py
# Linux/macOS
.venv/bin/python -m pip install -r ai/requirements.txt
.venv/bin/python ai/mcp_server.py
```

Let your agent's MCP client launch that command with an **absolute Python path and script path**.
Example: [ai/mcp.config.example.json](ai/mcp.config.example.json). Substitute your checkout and venv paths.
The server speaks stdio MCP; do not send interactive shell text to its stdin.
The first start imports the game assets; allow up to10 minutes in the client's tool timeout.
Issue actions sequentially in each game instance so the last gesture's film has one clear owner.

Call `sdc_start`, inspect its PNG, then use these tools:

| Tool | Input / result |
| --- | --- |
| `sdc_start` | Optional width/height, default1600×720; new isolated profile or existing session |
| `sdc_view` | Current genuine rendered frame; does not advance battle |
| `sdc_tap` | x,y in0..1 of the image; `double=true` makes two actual taps |
| `sdc_swipe` | start/end pairs, duration_ms; hold_ms≥350 for item drag |
| `sdc_touch_sequence` | Ordered `{ms,finger,type,at}` events; types down/move/up |
| `sdc_wait` | Advance animation/combat up to5000ms |
| `sdc_back` | Android-style system back, top contextual window first |
| `sdc_film` | Index into the last action's genuine intermediate frame list |
| `sdc_stop` | Stop this agent's game; retain its isolated save and screenshots |

Every action returns the final PNG, visible text/rectangles and intermediate frame paths.
Its isolated artifact folder also retains `actions.jsonl` with raw inputs and returned frame references.
MCP includes image content directly; `sdc_film` returns an intermediate image.
Visible UI metadata includes open selectors, but inspect the actual image for clipping and overlap.
All fingers are released after an action. World simulation freezes while the agent thinks;
UI animation still renders. This development pacing is not an Android performance measurement.

### Standard-library JSON interface

No MCP dependency is needed for this transport:

```sh
python ai/play.py
```

Write one JSON object per stdin line; read one result line from stdout. For example:

```json
{"op":"snapshot"}
{"op":"tap","at":[0.15,0.91]}
{"op":"double_tap","at":[0.58,0.335]}
{"op":"swipe","from":[0.7,0.7],"to":[0.7,0.35],"duration_ms":450}
{"op":"swipe","from":[0.58,0.335],"to":[0.65,0.55],"duration_ms":500,"hold_ms":450}
{"op":"back"}
{"op":"close"}
```

Read the returned `image` file using your image tool; `film` contains actual frames captured during the gesture.
`screen` is a lobby tab identifier and may remain `maps` during a battle. It is not a gameplay verdict.
For optional local HTTP use `python ai/play.py --http 8771`, POST the same objects to
`http://127.0.0.1:8771/action`, and GET `/health` for process status. It binds loopback only.

### Three-finger example

Use the current frame to locate controls. With the default1600×720 layout, this example moves and aims,
then adds the independent upper-left fire finger. Move/aim alone must leave ammunition unchanged.

```json
{"op":"touch_sequence","events":[
  {"ms":0,"finger":0,"type":"down","at":[0.089,0.733]},
  {"ms":30,"finger":0,"type":"move","at":[0.089,0.60]},
  {"ms":60,"finger":1,"type":"down","at":[0.889,0.67]},
  {"ms":90,"finger":1,"type":"move","at":[0.94,0.57]},
  {"ms":300,"finger":2,"type":"down","at":[0.06,0.26]},
  {"ms":900,"finger":2,"type":"up","at":[0.06,0.26]},
  {"ms":1100,"finger":1,"type":"up","at":[0.94,0.57]},
  {"ms":1150,"finger":0,"type":"up","at":[0.089,0.60]}
]}
```

At most10 fingers,160 events and10 seconds per sequence. Malformed sequences are rejected before
the first touch. Use shorter actions near enemies/doors and inspect intermediate frames.

## Cloud / Linux display

Godot's dummy headless renderer cannot produce game images. Use a real display or Xvfb with Mesa.
On Linux without DISPLAY, the launcher automatically uses `xvfb-run` if installed.
The supplied [Dockerfile](ai/Dockerfile) includes the display libraries and MCP server:

```sh
docker build -f ai/Dockerfile -t sdc-visual-player .
docker run --rm -i sdc-visual-player
```

Configure an MCP client to launch that `docker run` command with stdin attached.
For a JSON client instead: `docker run --rm -i --entrypoint python sdc-visual-player ai/play.py`.
The agent needs permission to run subprocesses and inspect returned images. No public tunnel is required.

## Player journey and checks

1. Inspect the lobby, open equipment/stash, select an item, inspect the adjacent window and close it.
2. Try tap placement, double transfer, long drag and scrolling. The grids must stay in place.
3. Buy/equip through the shop. Check the actual balance, gear and preserved list position.
4. Inspect workbench and settings; test the custom HUD editor without firing gameplay actions.
5. Start action → inspect/pan/pinch the map → choose entry → start the real raid.
6. Move/aim independently; add a third fire finger, reload, heal, open and resume the gear menu.
7. Approach an indoor container. Only the nearby round search key should open it.
8. Watch unknown cells reveal over time. Select only desired items with the same three inventory gestures.
9. Close the source, reach the northern extraction area and inspect the countdown and result.

Each run uses a unique temporary directory for save/settings/screenshots/logs. It never loads the owner's
normal player profile. Agent scripts live under `SDC/tools/`, excluded from the Android export.
Do not expose private signing material to an agent or commit profiles into the repository.

Windows1600×720 and1280×576 real rendering/raw touch and stdio MCP were exercised for this change.
See [visual acceptance evidence](docs/VISUAL_ACCEPTANCE_0_4_16.md) for the exact completed paths and limits.
The Windows fresh engine download and pinned SHA256 check also passed. Linux/Docker/macOS remain
unverified in this Windows session.

Fast boundary regression: `python -m unittest discover -s ai -p 'test_*.py'`.
Player feedback is recorded in [docs/PLAYER_FEEDBACK.md](docs/PLAYER_FEEDBACK.md).
