"""Package the reproducible Blender render as lightweight WebP preview art.

Requires Pillow in the artist's Python environment. It does not change runtime
models or turn the composed preview into gameplay evidence.
"""
from pathlib import Path
from PIL import Image
import argparse
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/creative/lumo_world"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--flutter-root", type=Path)
    args = parser.parse_args()
    source = ART / "world_cover_render.png"
    target = ROOT / "assets/games/hub/world.webp"
    target.parent.mkdir(parents=True, exist_ok=True)
    image = Image.open(source).convert("RGB")
    image.save(target, format="WEBP", quality=91, method=6)
    data = target.read_bytes()
    manifest_path = ART / "world_cover_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["delivery"] = {"path": target.relative_to(ROOT).as_posix(), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "width": image.width, "height": image.height}
    manifest["attribution"] = "Original Lumo model: Meshy, CC BY 4.0; original reference authorized by project owner. Existing model notices remain at assets/characters/lumo_animated/ATTRIBUTION.md and assets/characters/lumo_facial/ATTRIBUTION.md."
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if args.flutter_root:
        flutter_target = args.flutter_root / "assets/lumo_design/spielwelt/cover_world.webp"
        flutter_target.parent.mkdir(parents=True, exist_ok=True)
        flutter_target.write_bytes(data)
        print(flutter_target)
    print(json.dumps(manifest["delivery"]))


if __name__ == "__main__":
    main()
