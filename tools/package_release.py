#!/usr/bin/env python3
"""Build the actual Godot game and create portable Windows/Web archives."""
from __future__ import annotations
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def run(godot: str, *arguments: str) -> None:
    result = subprocess.run([godot, "--headless", "--path", str(ROOT), *arguments],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode or "SCRIPT ERROR:" in result.stdout or "ERROR:" in result.stdout:
        raise SystemExit(result.stdout)

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--platform", choices=["windows", "web", "all"], default="all")
    args = parser.parse_args()
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not version.startswith("4.7.2."):
        raise SystemExit(f"Godot 4.7.2 is required; found {version}")
    run(args.godot, "--editor", "--import", "--quit")
    release = ROOT / "releases"
    release.mkdir(exist_ok=True)
    platforms = ["windows", "web"] if args.platform == "all" else [args.platform]
    for platform in platforms:
        destination = ROOT / "build" / platform
        destination.mkdir(parents=True, exist_ok=True)
        target = destination / ("ProjectKlax.exe" if platform == "windows" else "index.html")
        run(args.godot, "--export-release", "Windows" if platform == "windows" else "Web", str(target))
        if platform == "windows":
            instructions = "PROJECT KLAX 0.1\n\nExtract this entire folder, then run ProjectKlax.exe. Keep ProjectKlax.pck beside it.\n\nWASD move, E scan/recover, F sample, R rover, Space pulse, Q lure, B field station, Tab tactical, X extract near lander. Esc pauses. H opens the manual. M toggles sound.\n\nCampaign saves live in Godot's user data folder for Project Klax. Surface sorties restart on launch; observations and extracted research are permanent.\n"
        else:
            instructions = "PROJECT KLAX 0.1 / WEB\n\nServe this folder through HTTP, not file://. With Python installed, run:\n  python -m http.server 8000\nThen open http://localhost:8000 in a WebGL2 browser.\n\nNo account, API key, build step, or network assets are needed. This export does not require cross-origin isolation headers. Saves are local to this browser and origin. See the in-game Field manual for controls.\n"
        (destination / "PLAY.txt").write_text(instructions)
        archive = release / f"ProjectKlax-{'Windows' if platform == 'windows' else 'Web'}.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
            for file in sorted(destination.iterdir()):
                if file.is_file() and not file.name.endswith(".import"):
                    output.write(file, file.name)
        if platform == "windows":
            parts = release / "windows-parts"
            parts.mkdir(exist_ok=True)
            for previous in parts.glob("ProjectKlax-Windows.zip.part*"):
                previous.unlink()
            data = archive.read_bytes()
            part_size = 8 * 1024 * 1024
            for i, start in enumerate(range(0, len(data), part_size)):
                (parts / f"ProjectKlax-Windows.zip.part{i+1:02d}").write_bytes(data[start:start+part_size])
        print(f"Built {archive.name}: {archive.stat().st_size:,} bytes")
    sums = []
    for file in sorted(release.glob("*.zip")):
        sums.append(f"{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.name}")
    (release / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n")

if __name__ == "__main__":
    main()
