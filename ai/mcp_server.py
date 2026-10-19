"""MCP2 entry: play the production SDC UI through real touch and screenshots."""
from __future__ import annotations

import base64
import json
from pathlib import Path
from typing import Any

from mcp.server import MCPServer
from mcp.types import CallToolResult, ImageContent, TextContent
from play import Player

server = MCPServer("SDC Visual Player", version="1.0.0", instructions=(
    "Start the game, inspect genuine frames, then use normalized image coordinates and raw phone gestures. "
    "Look at each returned frame and important intermediate film frames. An error-free command is not proof "
    "of a usable interaction. Each game has isolated progress. No shell/game-state shortcuts are exposed. "
    "For combat, combine move/aim/fire fingers in one touch_sequence; all fingers release at its end. "
    "Issue one action at a time. Desktop image/touch play is not a physical-phone performance or installation check."
))
player: Player | None = None
last: dict = {}


def frame(action: dict) -> CallToolResult:
    global last
    if player is None:
        raise ValueError("Call sdc_start first.")
    last = player.act(action)
    data = base64.b64encode(Path(last["image"]).read_bytes()).decode()
    return CallToolResult(content=[ImageContent(type="image", data=data, mimeType="image/png"),
                                  TextContent(type="text", text=json.dumps(last, ensure_ascii=False))],
                          structuredContent=last, isError=bool(last.get("error")))


@server.tool()
def sdc_start(width: int = 1600, height: int = 720) -> CallToolResult:
    """Start/reuse an isolated real game. Automatically fetch pinned Godot if missing. Returns its screen."""
    global player
    if player is None or player.process.poll() is not None:
        if player:
            player.close()
        player = Player(width=width, height=height)
    return frame({"op": "snapshot"})


@server.tool()
def sdc_view() -> CallToolResult:
    """Read the current real rendered screen and visible UI; inspect the image, not just metadata."""
    return frame({"op": "snapshot", "settle_ms": 0})


@server.tool()
def sdc_tap(x: float, y: float, double: bool = False) -> CallToolResult:
    """Tap normalized image coordinates. double=True makes two actual taps for quick item transfer."""
    return frame({"op": "double_tap" if double else "tap", "at": [x, y]})


@server.tool()
def sdc_swipe(start: list[float], end: list[float], duration_ms: int = 450, hold_ms: int = 0) -> CallToolResult:
    """Swipe/scroll with one real finger. For item drag use hold_ms>=350; review the returned film."""
    return frame({"op": "swipe", "from": start, "to": end, "duration_ms": duration_ms, "hold_ms": hold_ms})


@server.tool()
def sdc_touch_sequence(events: list[dict[str, Any]]) -> CallToolResult:
    """Real multitouch: ordered {ms,finger,type:'down'|'move'|'up',at:[x,y]}; max10s and160 events.
    Use separate fingers for movement, aiming and firing, or two fingers to rotate/zoom the map.
    """
    return frame({"op": "touch_sequence", "events": events})


@server.tool()
def sdc_wait(milliseconds: int = 250) -> CallToolResult:
    """Advance up to5s of real game/animation and return a fresh frame plus intermediate film."""
    return frame({"op": "wait", "ms": milliseconds})


@server.tool()
def sdc_back() -> CallToolResult:
    """Use Android-style system back, including closing the foremost contextual window first."""
    return frame({"op": "back"})


@server.tool()
def sdc_film(index: int = 0) -> CallToolResult:
    """Inspect an intermediate actual frame from the last gesture; indices are in its film list."""
    frames = last.get("film", [])
    if not 0 <= index < len(frames):
        raise ValueError(f"Film index must be between0 and{len(frames)-1}.")
    data = base64.b64encode(Path(frames[index]).read_bytes()).decode()
    return CallToolResult(content=[ImageContent(type="image", data=data, mimeType="image/png"),
                                  TextContent(type="text", text=f"Intermediate frame {index}/{len(frames)-1}")])


@server.tool()
def sdc_stop() -> dict:
    """Stop this agent's game; screenshots and its isolated save remain in the reported artifact folder."""
    global player
    if player:
        player.close()
        player = None
    return {"stopped": True}


if __name__ == "__main__":
    try:
        server.run(transport="stdio")
    finally:
        if player:
            player.close()
