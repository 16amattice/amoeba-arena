"""Set per-runner Android SDK and Java locations in Godot editor settings."""
from __future__ import annotations

import os
from pathlib import Path
import re

sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
java = os.environ.get("JAVA_HOME")
if not sdk or not java:
    raise SystemExit("ANDROID_HOME/ANDROID_SDK_ROOT and JAVA_HOME must be set")

settings_dir = Path.home() / ".config" / "godot"
settings_files = list(settings_dir.glob("editor_settings-4*.tres"))
if not settings_files:
    raise SystemExit("Godot editor settings not found; run godot --headless --editor --quit first")
settings_path = max(settings_files, key=lambda p: p.stat().st_mtime)
settings = settings_path.read_text(encoding="utf-8")
for key, value in (
    ("export/android/android_sdk_path", sdk),
    ("export/android/java_sdk_path", java),
):
    line = f'{key} = "{value}"'
    pattern = re.compile(r"^" + re.escape(key) + r"\s*=.*$", re.MULTILINE)
    if pattern.search(settings):
        settings = pattern.sub(line, settings)
    else:
        settings += "\n" + line + "\n"
settings_path.write_text(settings, encoding="utf-8")
print(f"Configured Godot Android SDK paths in {settings_path}")
