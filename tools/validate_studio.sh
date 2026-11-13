#!/usr/bin/env bash
set -euo pipefail

GODOT="${GODOT_BIN:-godot}"
LOG_DIR="${LUMO_STUDIO_LOG_DIR:-$(mktemp -d /tmp/lumo-studio.XXXXXXXX)}"
mkdir -p "$LOG_DIR"
LOG_DIR="$(cd "$LOG_DIR" && pwd)"
git rev-parse HEAD > "$LOG_DIR/source-sha.txt"
git rev-parse 'HEAD^{tree}' > "$LOG_DIR/source-tree.txt"
git status --porcelain --untracked-files=no > "$LOG_DIR/source-dirty.txt"
"$GODOT" --version > "$LOG_DIR/engine.txt"
failures=()
printf 'probe\tmode\tresult\n' > "$LOG_DIR/results.tsv"

run_probe() {
  local script="$1" marker="$2" mode="$3" seconds="$4"
  shift 4
  local capture="$LOG_DIR/captures/$script"
  local user="$LOG_DIR/data/$script-$mode"
  mkdir -p "$capture" "$user"
  local command=("$GODOT")
  local args=(--path . --audio-driver Dummy --script "scripts/tests/$script.gd")
  if [[ "$mode" == headless ]]; then
    args=(--headless "${args[@]}")
  else
    args=(--rendering-method gl_compatibility "${args[@]}")
    if [[ -z "${DISPLAY:-}" ]]; then
      if ! command -v xvfb-run >/dev/null 2>&1; then
        echo 'Studio capture requires an actual display or xvfb-run.' >&2
        return 1
      fi
      command=(xvfb-run -a -s '-screen 0 2560x2560x24' "${command[@]}")
    fi
  fi
  XDG_DATA_HOME="$user" XDG_CONFIG_HOME="$user/config" XDG_CACHE_HOME="$user/cache" \
    LUMO_CAPTURE_DIR="$capture" PUZZLE_ROTATION_CAPTURE_DIR="$capture" \
    TREASURE_EXPLORATION_CAPTURE_DIR="$capture" \
    python3 tools/run_godot_probe.py --log "$LOG_DIR/$script-$mode.log" \
    --timeout "$seconds" --required "$marker" -- "${command[@]}" "${args[@]}" "$@"
}

check_probe() {
  if run_probe "$@"; then
    printf '%s\t%s\tPASS\n' "$1" "$3" >> "$LOG_DIR/results.tsv"
  else
    failures+=("$1/$3")
    printf '%s\t%s\tFAIL\n' "$1" "$3" >> "$LOG_DIR/results.tsv"
  fi
}

check_probe learning_sharing_regression '[LearningSharing] PASS' headless 180
check_probe learning_studio_regression '[LearningStudio] PASS' headless 180
check_probe lumo_studio_motion_regression '[LumoStudioMotion] PASS' headless 180
check_probe puzzle_rotation_regression '[PuzzleRotation] PASS' headless 180
check_probe treasure_exploration_regression '[TreasureExploration] PASS' headless 180
check_probe learning_sharing_capture '[LearningSharingCapture] PASS' rendered 600 \
  -- "--output=$LOG_DIR/captures/learning_sharing_capture"
check_probe lumo_studio_motion_capture '[LumoStudioCapture] PASS' rendered 420
check_probe puzzle_rotation_regression '[PuzzleRotation] PASS' rendered 600
check_probe treasure_exploration_regression '[TreasureExploration] PASS' rendered 600

# A logic PASS in a display process is insufficient: require the native rasters.
if ! python3 - "$LOG_DIR" <<'PY'
import hashlib
import json
from pathlib import Path
import struct
import sys
root = Path(sys.argv[1])
required = {'learning_sharing_capture': 6, 'lumo_studio_motion_capture': 8,
            'puzzle_rotation_regression': 7, 'treasure_exploration_regression': 3}
images = []
for probe, count in required.items():
    found = sorted((root / 'captures' / probe).glob('*.png'))
    assert len(found) == count, (probe, len(found), count)
    for path in found:
        data = path.read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n', str(path)
        width, height = struct.unpack('>II', data[16:24])
        assert width >= 360 and height >= 360, str(path)
        images.append({'path': path.relative_to(root).as_posix(), 'width': width, 'height': height,
                       'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
(root / 'renderer-images.json').write_text(json.dumps({'images': images}, indent=2) + '\n')
print('[StudioRasterRoster] PASS', len(images), 'actual PNG files')
PY
then
  failures+=("renderer-roster")
fi

if (( ${#failures[@]} )); then
  printf '[LumoStudio] FAIL: %s\n' "${failures[*]}" >&2
  exit 1
fi
echo '[LumoStudio] PASS: source-bound learning, character, puzzle and exploration evidence'
