#!/usr/bin/env bash
# Additive acceptance for the live integration; the previous 52 modes stay intact.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
LOG_DIR="${LUMO_LIVE_LOG_DIR:-$ROOT/.artifacts/live-connections}"
mkdir -p "$(dirname "$LOG_DIR")"
mkdir "$LOG_DIR"
LOG_DIR="$(cd "$LOG_DIR" && pwd)"
mkdir "$LOG_DIR/captures"
export GODOT_SILENCE_ROOT_WARNING=1

probe() {
  local name="$1" mode="$2" marker="$3"
  shift 3
  local log="$LOG_DIR/${name}-${mode}.log"
  local -a args=(--path "$ROOT" --audio-driver Dummy --script "res://scripts/tests/${name}.gd" "$@")
  if [[ "$mode" == headless ]]; then
    timeout 120s godot --headless "${args[@]}" 2>&1 | tee "$log"
  elif [[ -n "${DISPLAY:-}" ]]; then
    timeout 180s godot --rendering-method gl_compatibility "${args[@]}" 2>&1 | tee "$log"
  elif command -v xvfb-run >/dev/null 2>&1; then
    timeout 180s xvfb-run -a -s '-screen 0 2560x2560x24' \
      godot --rendering-method gl_compatibility "${args[@]}" 2>&1 | tee "$log"
  else
    local rendered="$LOG_DIR/${name}-${mode}-display"
    python3 tools/run_local_renderer.py --project "$ROOT" \
      --display "${LUMO_LIVE_DISPLAY:-144}" --output "$rendered" --timeout 180 \
      -- "${args[@]}" 2>&1 | tee "$log"
    cat "$rendered/godot.log" | tee -a "$log"
  fi
  if grep -En 'SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|ObjectDB instances leaked|resources still in use at exit' "$log"; then
    echo "The original live integration probe failed: $name ($mode)" >&2
    return 1
  fi
  grep -Fx "$marker" "$log"
}

probe lumo_dream_ambience_regression headless '[DreamAmbience] 170 checks, 0 failures'
probe dream_garden_props_regression headless '[DreamGarden] checks=544 failures=0'
probe connect_four_return_regression headless 'CONNECT_FOUR_RETURN_PASS checks=21'
probe treasure_wisp_regression headless '[TreasureWisp] PASS checks=14'
probe treasure_exploration_regression headless '[TreasureExploration] PASS 92 checks: branching, actual location questions, movement, legacy saves and original rewards'
probe treasure_wisp_regression rendered '[TreasureWisp] PASS checks=18'
probe lumo_dream_ambience_capture rendered-treasure "[DreamAmbienceCapture] PASS treasure original frames in $LOG_DIR/captures/treasure" \
  -- --world=treasure "--capture-dir=$LOG_DIR/captures/treasure"
probe lumo_dream_ambience_capture rendered-learning "[DreamAmbienceCapture] PASS learning original frames in $LOG_DIR/captures/learning" \
  -- --world=learning "--capture-dir=$LOG_DIR/captures/learning"
probe dream_garden_capture rendered '[DreamGardenCapture] failures=0' \
  -- "--output=$LOG_DIR/captures/garden"

python3 - "$LOG_DIR" <<'PY'
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
PY
