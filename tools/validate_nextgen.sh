#!/usr/bin/env bash
set -euo pipefail

# This gate adds production-scene checks; all pre-existing acceptance suites
# remain mandatory in the caller. Rendered checks never accept a dummy display.
GODOT="${GODOT_BIN:-godot}"
LOG_DIR="${LUMO_NEXTGEN_LOG_DIR:-$(mktemp -d /tmp/lumo-nextgen.XXXXXXXX)}"
mkdir -p "$LOG_DIR"
LOG_DIR="$(cd "$LOG_DIR" && pwd)"
export XDG_DATA_HOME="$LOG_DIR/user-data"
export XDG_CONFIG_HOME="$LOG_DIR/user-config"
export XDG_CACHE_HOME="$LOG_DIR/user-cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
git rev-parse HEAD > "$LOG_DIR/source-sha.txt"
git status --porcelain --untracked-files=no > "$LOG_DIR/source-dirty.txt"
"$GODOT" --version > "$LOG_DIR/engine.txt"

run_probe() {
  local name="$1" marker="$2" mode="$3"
  shift 3
  local script="scripts/tests/$name.gd"
  local capture_dir="$LOG_DIR/captures/$name"
  local user_dir="$LOG_DIR/user-data/$name-$mode"
  test -s "$script"
  mkdir -p "$capture_dir" "$user_dir"
  local args=(--audio-driver Dummy --path . --script "$script")
  local command=("$GODOT")
  if [[ "$mode" == headless ]]; then
    args=(--headless "${args[@]}")
  else
    args=(--rendering-method gl_compatibility "${args[@]}")
    if [[ -z "${DISPLAY:-}" ]]; then
      if ! command -v xvfb-run >/dev/null 2>&1; then
        echo 'Nextgen visual acceptance requires DISPLAY or xvfb-run.' >&2
        return 1
      fi
      command=(xvfb-run -a -s '-screen 0 2560x2560x24' "${command[@]}")
    fi
  fi
  XDG_DATA_HOME="$user_dir" LUMO_CAPTURE_DIR="$capture_dir" LUMO_EVIDENCE_DIR="$capture_dir" \
    python3 tools/run_godot_probe.py --log "$LOG_DIR/$name-$mode.log" \
    --timeout 420 --required "$marker" -- "${command[@]}" "${args[@]}" "$@"
}

run_probe learning_world_regression '[LearningWorld] PASS' headless
run_probe jump_nextgen_regression '[JumpNextgen] PASS' headless
run_probe lumo_65bone_walk_gait_regression '[LumoGait] PASS' headless
run_probe lumo_original_jump_visual_regression '[JumpOriginalLumo] PASS' headless
run_probe build_transform_regression '[BuildTransform] PASS' headless
run_probe build_nextgen_play_regression '[BuildNextgen] PASS' headless
run_probe kart_nextgen_garage_regression '[NextGenGarage] PASS' headless
run_probe cards_table_regression 'CARDS_TABLE_RUNTIME_PASS' headless
run_probe learning_world_capture '[LearningCapture] PASS' rendered -- "--output=$LOG_DIR/captures/learning_world_capture"
run_probe jump_nextgen_capture '[JumpNextgenCapture] PASS' rendered
run_probe build_nextgen_play_regression '[BuildNextgen] PASS' rendered -- --capture
run_probe kart_nextgen_garage_regression '[NextGenGarage] PASS' rendered -- --capture
run_probe cards_table_capture 'CARDS_TABLE_RENDER_PASS' rendered -- "--output=$LOG_DIR/captures/cards_table_capture"

echo "[LumoNextgen] PASS: new production learning, platforming, building, cards and garage checks; logs $LOG_DIR"
