#!/usr/bin/env python3
"""Package the tracked, editable Godot project without exported game binaries."""
import hashlib
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
files = subprocess.check_output(
    ["git", "ls-files", "-z"], cwd=ROOT
).decode().split("\0")
files = [name for name in files if name and not name.startswith("releases/")]
required = {"project.godot", "scenes/main.tscn", "scripts/main.gd"}
if not required.issubset(files):
    raise SystemExit("Missing tracked Godot project entry points")
release = ROOT / "releases"
release.mkdir(exist_ok=True)
archive = release / "ProjectKlax-Godot-Source.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as output:
    for name in sorted(files):
        output.write(ROOT / name, f"ProjectKlax/{name}")
with zipfile.ZipFile(archive) as output:
    assert output.testzip() is None
    assert all(f"ProjectKlax/{name}" in output.namelist() for name in required)
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
(release / "SOURCE-SHA256SUMS.txt").write_text(f"{checksum}  {archive.name}\n")
print(f"Packaged {len(files)} source files: {archive.name}")
