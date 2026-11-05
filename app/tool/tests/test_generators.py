import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name, TOOL / (name + ".py"))
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


sw = module("make_sw")
scenes = module("bundle_scenes")


class Generators(unittest.TestCase):
    def test_same_size_revoice_invalidates_audio(self):
        with tempfile.TemporaryDirectory() as directory:
            clip = Path(directory) / "assets" / "audio" / "clip.mp3"
            clip.parent.mkdir(parents=True)
            clip.write_bytes(b"aaaa")
            before = sw.audio_version(directory, ["assets/audio/clip.mp3"])
            clip.write_bytes(b"bbbb")
            self.assertNotEqual(before, sw.audio_version(directory, ["assets/audio/clip.mp3"]))

    def test_generator_is_deterministic_and_avoids_unused_resources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ["index.html", "main.dart.js", "canvaskit/canvaskit.wasm",
                         "canvaskit/skwasm.wasm", "canvaskit/canvaskit.js.symbols",
                         "assets/assets/audio/a.mp3", "assets/assets/i18n/fa.json"]:
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("test")
            source_before = (sw.APP / "assets" / "audio" / "ver.json").read_bytes()
            files = sw.generate(root, sync_source=False)
            first = (root / "sw.js").read_bytes()
            sw.generate(root, sync_source=False)
            self.assertEqual(first, (root / "sw.js").read_bytes())
            self.assertIn("canvaskit/canvaskit.wasm", files)
            self.assertFalse(any("skwasm" in f or f.endswith((".mp3", ".symbols")) for f in files))
            self.assertNotIn("assets/assets/i18n/fa.json", files)
            self.assertEqual(source_before, (sw.APP / "assets" / "audio" / "ver.json").read_bytes())

    def test_published_bundle_is_current(self):
        scenes.generate(check=True)

    def test_stale_bundle_fails_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            data = Path(directory)
            (data / "scenes").mkdir()
            (data / "scenes_index.json").write_text('["one"]')
            (data / "course.json").write_text('{"sceneIds":["one"]}')
            (data / "scenes" / "one.json").write_text(json.dumps({
                "id": "one", "start": "a", "nodes": {"a": {"branches": []}}
            }))
            (data / "scenes_bundle.json").write_text("{}")
            with self.assertRaisesRegex(ValueError, "stale"):
                scenes.generate(data, check=True)
            scenes.generate(data)
            scenes.generate(data, check=True)

    def test_bad_course_reference_does_not_replace_existing_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            data = Path(directory)
            (data / "scenes_index.json").write_text("[]")
            (data / "course.json").write_text('{"sceneIds":["missing"]}')
            output = data / "scenes_bundle.json"
            output.write_text('{"previous":"preserved"}')
            with self.assertRaisesRegex(ValueError, "missing scene"):
                scenes.generate(data)
            self.assertEqual(output.read_text(), '{"previous":"preserved"}')


if __name__ == "__main__":
    unittest.main()
