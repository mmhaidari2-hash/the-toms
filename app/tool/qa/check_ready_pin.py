#!/usr/bin/env python3
"""Fail if a language in ready_pin.json is missing from helperComplete."""
import json, re, sys
from pathlib import Path
root = Path(__file__).resolve().parents[2]
pin_path = root / 'tool' / 'i18n' / 'ready_pin.json'
cov_path = root / 'lib' / 'core' / 'i18n' / 'coverage.g.dart'
if not pin_path.exists():
    print('BLOCK ready_pin.json missing'); sys.exit(1)
raw = json.loads(pin_path.read_text())
pinned = set(raw.keys()) if isinstance(raw, dict) else set(raw)
text = cov_path.read_text()
m = re.search(r"helperComplete = <String>\{([^}]*)\}", text)
complete = set(re.findall(r"'([a-zA-Z-]+)'", m.group(1))) if m else set()
missing = sorted(pinned - complete)
if missing:
    print('BLOCK ready langs demoted from helperComplete:', missing)
    print('  pinned:', sorted(pinned), 'complete:', sorted(complete))
    sys.exit(1)
print('ready_pin OK:', sorted(pinned), 'subset of', sorted(complete))
