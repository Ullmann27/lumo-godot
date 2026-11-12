#!/usr/bin/env bash
set -euo pipefail

# Additive live-UI and action gate. Complete route and full-field physics remain
# required by validate_2014.sh; no rendered result is substituted by headless UI.
GODOT="${GODOT_BIN:-godot}"
LOG_DIR="${LUMO_ACTION_LOG_DIR:-$(mktemp -d /tmp/lumo-action-stage.XXXXXXXX)}"
mkdir -p "$LOG_DIR"
export XDG_DATA_HOME="$LOG_DIR/user-data"
export XDG_CONFIG_HOME="$LOG_DIR/user-config"
export XDG_CACHE_HOME="$LOG_DIR/user-cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
git rev-parse HEAD > "$LOG_DIR/source-sha.txt"
"$GODOT" --version > "$LOG_DIR/engine.txt"

run_probe() {
  local name="$1" marker="$2" mode="$3"
  shift 3
  local log="$LOG_DIR/$name.log"
  local args=(--audio-driver Dummy --path . --script "scripts/tests/$name.gd")
  local command=("$GODOT")
  if [[ "$mode" == headless ]]; then
    args=(--headless "${args[@]}")
  else
    args=(--rendering-method gl_compatibility "${args[@]}")
    if [[ -z "${DISPLAY:-}" ]]; then
      if ! command -v xvfb-run >/dev/null 2>&1; then
        echo 'Live menu acceptance requires DISPLAY or xvfb-run.' >&2
        return 1
      fi
      command=(xvfb-run -a -s '-screen 0 2560x2560x24' "${command[@]}")
    fi
  fi
  python3 tools/run_godot_probe.py --log "$log" --timeout 420 --required "$marker" \
    -- "${command[@]}" "${args[@]}" "$@"
}

run_probe kart_lasso_regression '[KartLasso] PASS' headless
run_probe kart_lasso_production_regression '[KartLassoProduction] PASS' headless
run_probe kart_spatial_menu_regression '[SpatialMenu] PASS' rendered -- --capture
LUMO_ACTION_CAPTURE_DIR="$LOG_DIR/action-captures" \
  run_probe kart_roadside_action_regression '[RoadsideAction] PASS' rendered
run_probe kart_menu_flow_regression '[KartMenuFlow] PASS' rendered
echo "[LumoActionStage] PASS: native touch navigation, real 3D stage and physical roadside action; logs $LOG_DIR"
