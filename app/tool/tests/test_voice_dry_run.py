import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

APP = Path(__file__).resolve().parents[2]


class VoiceDryRun(unittest.TestCase):
    def test_inventory_does_not_import_paid_client_or_change_manifests(self):
        paths = [
            APP / "assets/audio/index.json",
            *(APP / "tool/audit" / name for name in [
                "voice_manifest.json", "voice_engine.json", "voice_texts.json",
                "you_neutral_v1.done",
            ]),
        ]
        before = {path: path.read_bytes() if path.exists() else None for path in paths}
        env = {k: v for k, v in os.environ.items() if not k.startswith("RENDER_")}
        code = """
import runpy, sys
sys.argv = ['tool/render_voices.py', '--dry-run']
try:
    runpy.run_path(sys.argv[0], run_name='__main__')
except SystemExit as result:
    assert result.code == 0, result.code
assert 'az_tts' not in sys.modules
"""
        result = subprocess.run(
            [sys.executable, "-c", code], cwd=APP, env=env,
            text=True, capture_output=True, check=True, timeout=60,
        )
        inventory = json.loads(result.stdout.splitlines()[-1])
        self.assertIsInstance(inventory["missing"], list)
        self.assertIsInstance(inventory["obsoleteRetained"], int)
        for path, contents in before.items():
            self.assertEqual(
                contents, path.read_bytes() if path.exists() else None, str(path)
            )


if __name__ == "__main__":
    unittest.main()
