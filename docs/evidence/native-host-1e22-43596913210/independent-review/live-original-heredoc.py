import hashlib
import json
from pathlib import Path
import subprocess
import sys

from PIL import Image, ImageChops

out = Path(sys.argv[1])
records = []


def inspect_image(path, size):
    if not path.is_file() or path.is_symlink():
        raise ValueError(f"Original regular PNG required: {path}")
    with Image.open(path) as original:
        original.load()
        if original.format != "PNG" or original.size != size:
            raise ValueError(f"Unexpected renderer raster dimensions: {path}")
        image = original.convert("RGB")
        if all(lo == hi for lo, hi in image.getextrema()):
            raise ValueError(f"Uniform renderer image: {path}")
    records.append({"path": str(path.relative_to(out)), "width": size[0],
                    "height": size[1], "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    return image


for world in ("treasure", "learning"):
    directory = out / "captures" / world
    report = json.loads((directory / (world + ".json")).read_text())
    frames = report["frames"]
    if report["display"] == "headless" or report["renderer"] != "gl_compatibility" or len(frames) != 2:
        raise ValueError(f"Two original Compatibility frames required: {world}")
    if report.get("device_fps_measured") is not False:
        raise ValueError("Software renderer evidence cannot claim physical Android FPS")
    first, second = [inspect_image(directory / f"{world}_{i:02}.png", (f["width"], f["height"]))
                     for i, f in enumerate(frames)]
    if second.size != first.size or ImageChops.difference(first, second).getbbox() is None:
        raise ValueError(f"Actual frames do not show a changing scene: {world}")
    if frames[1]["ambience"]["animation_time"] <= frames[0]["ambience"]["animation_time"]:
        raise ValueError(f"Production animation clock did not advance: {world}")

for width, height in ((1280, 720), (412, 915), (2400, 1080)):
    inspect_image(out / "captures" / "garden" / f"learning-dream-{width}x{height}.png", (width, height))

result = {"schema": 1, "native_source": subprocess.check_output(
    ["git", "rev-parse", "HEAD"], text=True).strip(), "probes": 9,
    "original_pngs": records, "physical_android_fps_measured": False}
(out / "live-connections.json").write_text(json.dumps(result, indent=2) + "\n")
print("[LumoLiveConnections] PASS 9 original probes and 7 verified renderer PNGs")
