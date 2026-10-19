"""Run the real SDC phone UI; JSON actions return genuine rendered PNG frames."""
from __future__ import annotations

import argparse
import atexit
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
from bootstrap import godot_binary

ROOT = Path(__file__).resolve().parents[1]


def validate_action(action: dict) -> None:
    """Reject the entire malformed gesture before the first touch reaches the game."""
    if not isinstance(action, dict):
        raise ValueError("Action must be an object")
    op = action.get("op", "snapshot")
    if op not in ("snapshot", "tap", "double_tap", "swipe", "touch_sequence", "wait", "back", "close"):
        raise ValueError("Unknown operation")

    def number(value):
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
            raise ValueError("Timing and coordinates must be finite numbers")
        return value

    def point(value):
        if not isinstance(value, list) or len(value) != 2 or any(not 0 <= number(v) <= 1 for v in value):
            raise ValueError("Coordinates must be normalized [x,y] within the image")

    for key in ("settle_ms", "duration_ms", "hold_ms", "ms"):
        if key in action:
            number(action[key])
    if op in ("tap", "double_tap"):
        point(action.get("at"))
    elif op == "swipe":
        point(action.get("from"))
        point(action.get("to"))
    elif op == "touch_sequence":
        events = action.get("events")
        if not isinstance(events, list) or len(events) > 160:
            raise ValueError("events must be an array of at most160 events")
        previous = 0
        fingers = set()
        for event in events:
            if not isinstance(event, dict):
                raise ValueError("Invalid touch event")
            at = number(event.get("ms"))
            finger = event.get("finger", 0)
            kind = event.get("type")
            point(event.get("at"))
            if not previous <= at <= 10000 or type(finger) is not int or not 0 <= finger <= 9:
                raise ValueError("Invalid touch timing or finger")
            if kind == "down" and finger not in fingers:
                fingers.add(finger)
            elif kind in ("move", "up") and finger in fingers:
                if kind == "up":
                    fingers.remove(finger)
            else:
                raise ValueError("Touch must be down, then move/up on its own finger")
            previous = at


class Player:
    def __init__(self, godot: str | None = None, width: int = 1600, height: int = 720):
        executable = godot_binary(godot)
        if not 800 <= width <= 2400 or not 400 <= height <= 1440 or width <= height:
            raise ValueError("Use a landscape viewport, width800..2400, height400..1440.")
        self.directory = Path(tempfile.mkdtemp(prefix="sdc-ai-"))
        self.lock = threading.Lock()
        self.sequence = 0
        self.process = None
        self.socket = None
        self.reader = None
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)
        listener.settimeout(.5)
        nonce = secrets.token_hex(24)
        env = os.environ.copy()
        env.update(SDC_AI_SAVE=str(self.directory / "save.json"), SDC_AI_SETTINGS=str(self.directory / "settings.cfg"),
                   SDC_AI_PORT=str(listener.getsockname()[1]), SDC_AI_FRAMES=str(self.directory), SDC_AI_NONCE=nonce)
        command = [executable, "--path", str(ROOT / "SDC"), "--resolution", f"{width}x{height}",
                   "--log-file", str(self.directory / "godot.log"),
                   "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--audio-driver", "Dummy",
                   "--max-fps", "60", "res://tools/ai_player.tscn", "--", "--sdc-ai"]
        if sys.platform.startswith("linux") and not env.get("DISPLAY"):
            if not shutil.which("xvfb-run"):
                listener.close()
                raise RuntimeError("Visual play needs DISPLAY or Xvfb+Mesa; use ai/Dockerfile in a cloud environment.")
            command = ["xvfb-run", "-a", "-s", f"-screen 0 {width}x{height}x24"] + command
            env.setdefault("LIBGL_ALWAYS_SOFTWARE", "1")
        startup = None
        flags = 0
        if sys.platform == "win32":
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = 0
            flags = subprocess.CREATE_NO_WINDOW
        self.log = (self.directory / "engine.log").open("wb")
        try:
            if not (ROOT / "SDC" / ".godot" / "imported").is_dir():
                print("Importing SDC resources for this checkout...", file=sys.stderr, flush=True)
                with (self.directory / "import.log").open("wb") as output:
                    imported = subprocess.run([executable, "--headless", "--path", str(ROOT / "SDC"),
                                               "--editor", "--import", "--quit", "--", "--sdc-ai"],
                                              env=env, stdout=output, stderr=subprocess.STDOUT, timeout=600)
                if imported.returncode:
                    raise RuntimeError(f"Game resource import failed; see {self.directory / 'import.log'}")
            self.process = subprocess.Popen(command, env=env, stdout=self.log, stderr=subprocess.STDOUT,
                                            stdin=subprocess.DEVNULL, startupinfo=startup, creationflags=flags)
            deadline = time.monotonic() + 90
            while True:
                try:
                    self.socket, _ = listener.accept()
                    break
                except socket.timeout:
                    if self.process.poll() is not None:
                        raise RuntimeError(f"Game exited ({self.process.returncode}); see {self.directory / 'godot.log'}")
                    if time.monotonic() >= deadline:
                        raise RuntimeError(f"Game startup timed out; see {self.directory / 'godot.log'}")
            self.socket.settimeout(40)
            self.reader = self.socket.makefile("rb")
            ready = self._read()
            if ready.get("nonce") != nonce or ready.get("type") != "ready":
                raise RuntimeError("Unexpected AI runtime handshake.")
        except Exception:
            self.close()
            raise
        finally:
            listener.close()
        atexit.register(self.close)

    def _read(self) -> dict:
        line = self.reader.readline(2_000_000)
        if not line or len(line) >= 2_000_000:
            raise RuntimeError(f"Game stopped or returned an oversized frame; see {self.directory / 'engine.log'}")
        return json.loads(line)

    def act(self, action: dict) -> dict:
        validate_action(action)
        if self.process.poll() is not None:
            raise RuntimeError(f"Game exited ({self.process.returncode}); see {self.directory / 'godot.log'}")
        with self.lock:
            self.sequence += 1
            self.socket.sendall((json.dumps({**action, "id": self.sequence}, allow_nan=False) + "\n").encode())
            result = self._read()
            if result.get("id") != self.sequence:
                raise RuntimeError("Unexpected response order.")
            if "image" in result and not result.get("saved"):
                raise RuntimeError(f"Screenshot could not be saved; see {self.directory / 'godot.log'}")
            with (self.directory / "actions.jsonl").open("a", encoding="utf-8") as journal:
                journal.write(json.dumps({"action": action, "result": result}, ensure_ascii=False) + "\n")
            return result

    def close(self):
        if self.reader:
            self.reader.close()
            self.reader = None
        if self.socket:
            self.socket.close()
            self.socket = None
        if self.process and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)
        if getattr(self, "log", None):
            self.log.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--width", type=int, default=1600)
    parser.add_argument("--height", type=int, default=720)
    parser.add_argument("--http", type=int, metavar="PORT", help="Optional loopback-only action endpoint")
    args = parser.parse_args()
    player = Player(args.godot, args.width, args.height)
    if args.http:
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                self.respond({"mode": "real-touch-and-render", "ready": player.process.poll() is None,
                              "exit_code": player.process.poll()}, 200 if self.path == "/health" else 404)

            def do_POST(self):
                try:
                    origin = self.headers.get("Origin")
                    if self.headers.get("Host") not in (f"127.0.0.1:{args.http}", f"localhost:{args.http}") or (
                        origin and origin not in (f"http://127.0.0.1:{args.http}", f"http://localhost:{args.http}")):
                        self.respond({"error": "Loopback clients only"}, 403)
                        return
                    length = int(self.headers.get("Content-Length", "0"))
                    if self.path != "/action" or not 0 < length <= 65536:
                        self.respond({"error": "Invalid route/body size"}, 400)
                        return
                    action = json.loads(self.rfile.read(length))
                    if not isinstance(action, dict):
                        raise ValueError("Action must be an object")
                    self.respond(player.act(action))
                except (OSError, ValueError, RuntimeError) as error:
                    self.respond({"error": str(error)}, 400)

            def respond(self, value, status=200):
                body = json.dumps(value, ensure_ascii=False).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *_args):
                pass
        print(json.dumps({"ready": True, "endpoint": f"http://127.0.0.1:{args.http}/action", "artifacts": str(player.directory)}), flush=True)
        try:
            ThreadingHTTPServer(("127.0.0.1", args.http), Handler).serve_forever()
        finally:
            player.close()
    else:
        try:
            for line in sys.stdin:
                try:
                    result = player.act(json.loads(line))
                except (OSError, ValueError, RuntimeError) as error:
                    result = {"error": str(error)}
                print(json.dumps(result, ensure_ascii=False), flush=True)
        finally:
            player.close()


if __name__ == "__main__":
    main()
