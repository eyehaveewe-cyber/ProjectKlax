#!/usr/bin/env python3
"""Recover the tested Windows package from repository parts, with checksum."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parents[1]
parts = sorted((root / 'releases/windows-parts').glob('ProjectKlax-Windows.zip.part*'))
data = b''.join(part.read_bytes() for part in parts)
expected = next(line.split()[0] for line in (root/'releases/SHA256SUMS.txt').read_text().splitlines() if line.endswith('ProjectKlax-Windows.zip'))
if hashlib.sha256(data).hexdigest() != expected:
    raise SystemExit('Package checksum mismatch. Download all parts before assembling.')
output = root/'releases/ProjectKlax-Windows.zip'
output.write_bytes(data)
print(output)
