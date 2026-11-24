#!/usr/bin/env bash
set -euo pipefail

# Additive acceptance for the integrated art update. The unchanged complete
# driving/loop/ramp gates in validate_2014.sh remain mandatory separately.
GODOT="${GODOT_BIN:-godot}"
LOG_DIR="${LUMO_ART_LOG_DIR:-$(mktemp -d /tmp/lumo-art.XXXXXXXX)}"
mkdir -p "$LOG_DIR"
export XDG_DATA_HOME="$LOG_DIR/user-data"
export XDG_CONFIG_HOME="$LOG_DIR/user-config"
export XDG_CACHE_HOME="$LOG_DIR/user-cache"
mkdir -p "$XDG_DATA_HOME/godot/app_userdata/Lumo 3D" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
git rev-parse HEAD > "$LOG_DIR/source-sha.txt"
"$GODOT" --version > "$LOG_DIR/engine.txt"

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
        echo 'Technical art acceptance requires a real rendering server (DISPLAY or xvfb-run).' >&2
        return 1
      fi
      command=(xvfb-run -a "${command[@]}")
    fi
  fi
  timeout 240s "${command[@]}" "${args[@]}" 2>&1 | tee "$log"
  grep -F "$marker" "$log" >/dev/null
  if grep -qE 'SCRIPT ERROR|Parse Error|Assertion failed|ERROR:' "$log"; then
    echo "Technical art acceptance failed: $name" >&2
    return 1
  fi
}

run_probe kart_sonnenhafen_streetfronts_world_regression '[StreetfrontsWorld] PASS' headless
run_probe kart_sonnenhafen_streetfronts_regression '[Streetfronts] PASS' rendered
run_probe kart_harbor_race_hook_regression '[HarborRaceHook] PASS' rendered
run_probe lumo_attention_landing_regression '"failures":0' headless
run_probe lumo_kart_tick_cadence_regression '[LumoKartTickCadence] PASS' headless
run_probe lumo_gesture_contact_regression '[LumoGestureContact] PASS' headless
run_probe kart_garage_presentation_regression '[GaragePresentation] PASS' rendered
run_probe kart_air_trick_regression '[AirTrick] PASS' headless
echo "[LumoTechnicalArt] PASS: geometry, live reactions, original rig, camera and touch targets; logs $LOG_DIR"
