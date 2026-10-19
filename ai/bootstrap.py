"""Fetch the pinned official Godot engine, checking the published SHA256."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

VERSION = "4.6.3"
ASSETS = {
    "windows": ("win64.exe", "e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90"),
    "linux-x64": ("linux.x86_64", "d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3"),
    "linux-arm64": ("linux.arm64", "90c70382eee1542904bf507b9bdc6e62a230ac73fd214bf3887a9e0a4d85aeed"),
    "macos": ("macos.universal", "30630f3e9b11e10b35c1f90ba8814185dcec43fae1a48345159be7552c64bfe8"),
}


def godot_binary(explicit: str | None = None) -> str:
    supplied = explicit or os.environ.get("GODOT_BIN")
    executable = supplied or shutil.which("godot") or shutil.which("godot4")
    if executable:
        if sys.platform == "win32" and str(executable).endswith("_console.exe"):
            gui = Path(str(executable).replace("_console.exe", ".exe"))
            if gui.is_file():
                executable = str(gui)
        version = subprocess.run([executable, "--version"], capture_output=True, text=True, timeout=20)
        if version.returncode == 0 and version.stdout.startswith(VERSION + "."):
            return str(executable)
        if supplied:
            raise RuntimeError(f"GODOT_BIN must point to Godot{VERSION}; got {version.stdout.strip()!r}")
    machine = platform.machine().lower()
    if sys.platform == "win32":
        if machine not in ("amd64", "x86_64"):
            raise RuntimeError("Set GODOT_BIN for this Windows architecture.")
        target = "windows"
    elif sys.platform == "darwin":
        target = "macos"
    elif sys.platform.startswith("linux") and machine in ("x86_64", "amd64", "aarch64", "arm64"):
        target = "linux-arm64" if machine in ("aarch64", "arm64") else "linux-x64"
    else:
        raise RuntimeError("Unsupported auto-install platform; set GODOT_BIN to Godot4.6.3.")
    suffix, digest = ASSETS[target]
    cache = Path(os.environ.get("SDC_AI_CACHE", Path.home() / ".cache" / "sdc-ai")) / VERSION / target
    binary = cache / ("Godot.app/Contents/MacOS/Godot" if target == "macos" else f"Godot_v{VERSION}-stable_{suffix}")
    if binary.is_file():
        return str(binary)
    cache.mkdir(parents=True, exist_ok=True)
    url = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_{suffix}.zip"
    print(f"Downloading official Godot{VERSION} for {target}...", file=sys.stderr, flush=True)
    with tempfile.TemporaryDirectory(prefix="download-", dir=cache) as temporary:
        archive = Path(temporary) / "engine.zip"
        request = urllib.request.Request(url, headers={"User-Agent": "SDC-AI-Player"})
        with urllib.request.urlopen(request, timeout=60) as response, archive.open("wb") as output:
            shutil.copyfileobj(response, output)
        with archive.open("rb") as source:
            actual = hashlib.file_digest(source, "sha256").hexdigest()
        if actual != digest:
            raise RuntimeError("Godot archive SHA256 mismatch; engine was not installed.")
        with zipfile.ZipFile(archive) as bundle:
            for member in bundle.infolist():
                destination = (cache / member.filename).resolve()
                if not destination.is_relative_to(cache.resolve()):
                    raise RuntimeError("Invalid engine archive path.")
            bundle.extractall(cache)
    if not binary.is_file():
        raise RuntimeError("The verified engine archive did not contain its expected executable.")
    binary.chmod(binary.stat().st_mode | 0o111)
    return str(binary)


if __name__ == "__main__":
    print(godot_binary())
