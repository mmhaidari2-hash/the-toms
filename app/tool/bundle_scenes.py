"""Build or validate the scene bundle actually loaded by the app."""
import argparse
import json
from pathlib import Path


DATA = Path(__file__).resolve().parent.parent / "assets" / "data"


def scene_bundle(data=DATA):
    data = Path(data)
    ids = json.loads((data / "scenes_index.json").read_text())
    if len(ids) != len(set(ids)):
        raise ValueError("Duplicate IDs in scenes_index.json")
    bundle = {}
    for scene_id in ids:
        scene = json.loads((data / "scenes" / f"{scene_id}.json").read_text())
        if scene.get("id") != scene_id:
            raise ValueError(f"Scene ID mismatch: {scene_id}")
        nodes = scene["nodes"]
        if scene["start"] not in nodes:
            raise ValueError(f"Missing start node: {scene_id}")
        for node_id, node in nodes.items():
            for branch in node.get("branches", []):
                target = branch.get("next")
                if target and target not in nodes:
                    raise ValueError(f"Missing target: {scene_id}/{node_id} -> {target}")
        bundle[scene_id] = scene

    def validate_refs(value):
        if isinstance(value, dict):
            for scene_id in value.get("sceneIds", []):
                if scene_id not in bundle:
                    raise ValueError(f"Course references missing scene: {scene_id}")
            for child in value.values():
                validate_refs(child)
        elif isinstance(value, list):
            for child in value:
                validate_refs(child)
    validate_refs(json.loads((data / "course.json").read_text()))
    return bundle


def generate(data=DATA, check=False):
    data = Path(data)
    bundle = scene_bundle(data)
    output = data / "scenes_bundle.json"
    if check:
        if json.loads(output.read_text()) != bundle:
            raise ValueError("scenes_bundle.json is stale; run python3 tool/bundle_scenes.py")
    else:
        # Validate everything before replacing a previously working bundle.
        temporary = output.with_suffix(".json.tmp")
        temporary.write_text(json.dumps(bundle, ensure_ascii=False, separators=(",", ":")))
        temporary.replace(output)
    print(f"{len(bundle)} scenes: {'validated' if check else 'bundled'}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    generate(check=args.check)
