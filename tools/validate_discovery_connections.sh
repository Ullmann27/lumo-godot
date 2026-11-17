#!/usr/bin/env bash
# Required after validate_live_connections.sh; keeps the existing 9/7 contract intact.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
LOG_DIR="${LUMO_DISCOVERY_LOG_DIR:-$ROOT/.artifacts/discovery-connections}"
mkdir -p "$(dirname "$LOG_DIR")"
mkdir "$LOG_DIR"
LOG_DIR="$(cd "$LOG_DIR" && pwd)"
mkdir "$LOG_DIR/captures"
export GODOT_SILENCE_ROOT_WARNING=1
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"

PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=tools:tools/tests \
  python3 -m unittest test_discovery_rasters 2>&1 | tee "$LOG_DIR/evidence-checker-tests.log"

probe() {
  local name="$1" mode="$2" seconds="$3" marker="$4"
  shift 4
  local log="$LOG_DIR/${name}-${mode}.log"
  local -a args=(--path "$ROOT" --audio-driver Dummy --script "res://scripts/tests/${name}.gd" "$@")
  export XDG_DATA_HOME="$LOG_DIR/user-data/${name}-${mode}"
  export XDG_CACHE_HOME="$LOG_DIR/cache/${name}-${mode}"
  if [[ "$mode" == headless ]]; then
    timeout "${seconds}s" godot --headless "${args[@]}" 2>&1 | tee "$log"
  elif [[ -n "${DISPLAY:-}" ]]; then
    timeout "${seconds}s" godot --rendering-method gl_compatibility "${args[@]}" 2>&1 | tee "$log"
  elif command -v xvfb-run >/dev/null 2>&1; then
    timeout "${seconds}s" xvfb-run -a -s '-screen 0 2560x2560x24' \
      godot --rendering-method gl_compatibility "${args[@]}" 2>&1 | tee "$log"
  else
    local rendered="$LOG_DIR/${name}-${mode}-display"
    python3 tools/run_local_renderer.py --project "$ROOT" \
      --display "${LUMO_DISCOVERY_DISPLAY:-145}" --output "$rendered" --timeout "$seconds" \
      -- "${args[@]}" 2>&1 | tee "$log"
    cat "$rendered/godot.log" | tee -a "$log"
  fi
  if grep -En 'SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|ObjectDB instances leaked|resources still in use at exit' "$log"; then
    echo "The original discovery probe failed: $name ($mode)" >&2
    return 1
  fi
  grep -Fx "$marker" "$log"
}

probe learning_world_regression headless 150 '[LearningWorld] PASS checks=5347'
probe learning_sharing_regression headless 150 '[LearningSharing] PASS checks=1811'
probe learning_studio_regression headless 150 '[LearningStudio] PASS checks=183; runtime asset, materials, reduced motion and preserved learning'
probe game_hub_magic_regression headless 150 '[LumoHub] PASS 8 visible native game entrances, active village route, preserved child settings and 3D reduced-motion portal'
probe village_host_launch_regression headless 150 '[VillageHost] PASS Flutter village request, native boot scene and child context'
probe learning_wonder_details_regression headless 150 '[LearningWonder] checks=100 failures=0 renderer=headless invalid_scene_checked=false'
probe learning_wonder_details_regression rendered 420 '[LearningWonder] checks=108 failures=0 renderer=X11 invalid_scene_checked=true'
export LUMO_HUB_CAPTURE_DIR="$LOG_DIR/captures/hub"
probe game_hub_magic_capture rendered 180 '[LumoHubCapture] PASS 2 original current-source rendered PNGs'
probe learning_world_capture rendered 900 '[LearningCapture] PASS captures=25' \
  -- "--output=$LOG_DIR/captures/learning"
probe learning_wonder_details_capture rendered 420 '[WonderCapture] checks=136 failures=0 captures=11' \
  -- "--output=$LOG_DIR/captures/wonder"

python3 tools/verify_discovery_rasters.py "$LOG_DIR"
