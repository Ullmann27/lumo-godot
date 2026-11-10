#!/usr/bin/env bash
set -euo pipefail

GODOT="${GODOT_BIN:-godot}"
LOG_DIR="${LUMO_2014_LOG_DIR:-$(mktemp -d /tmp/lumo-2014.XXXXXXXX)}"
mkdir -p "$LOG_DIR"
export XDG_DATA_HOME="$LOG_DIR/user-data"
export XDG_CONFIG_HOME="$LOG_DIR/user-config"
export XDG_CACHE_HOME="$LOG_DIR/user-cache"
mkdir -p "$XDG_DATA_HOME/godot/app_userdata/Lumo 3D" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"

run_probe() {
  local name="$1" marker="$2" mode="$3"
  local log="$LOG_DIR/$name.log"
  local args=(--audio-driver Dummy --path . --script "scripts/tests/$name.gd")
  local command=("$GODOT")
  if [[ "$mode" == headless ]]; then
    args=(--headless "${args[@]}")
  else
    args=(--rendering-method gl_compatibility "${args[@]}")
    if [[ -z "${DISPLAY:-}" ]]; then
      if ! command -v xvfb-run >/dev/null 2>&1; then
        echo '2014 acceptance requires a real rendering server (DISPLAY or xvfb-run).' >&2
        return 1
      fi
      command=(xvfb-run -a "${command[@]}")
    fi
  fi
  timeout 240s "${command[@]}" "${args[@]}" 2>&1 | tee "$log"
  grep -F "$marker" "$log" >/dev/null
  if grep -E 'SCRIPT ERROR|Parse Error|Assertion failed|ERROR:' "$log" \
      | grep -v 'resources still in use at exit' | grep -q .; then
    echo "2014 acceptance failed: $name" >&2
    return 1
  fi
}

run_probe kart_loop_contact_regression '[LoopContact] PASS' headless
run_probe kart_racecraft_regression '[KartRacecraft] PASS' headless
run_probe kart_rival_drift_items_regression '[KartRivalDrift] PASS' headless
run_probe kart_sonnenhafen_generation_regression '[SonnenhafenGeneration] PASS' headless
run_probe kart_stunt_continuity_regression '[StuntContinuity] PASS' rendered
run_probe kart_rival_flight_regression '[RivalFlight] PASS' rendered
run_probe kart_harbor_attraction_regression '[HarborAttraction] PASS' rendered
run_probe kart_harbor_race_hook_regression '[HarborRaceHook] PASS' rendered
echo "[Lumo2014] PASS: continuous contact, fair racecraft, earned items and living harbor; logs $LOG_DIR"
