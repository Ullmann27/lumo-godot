#!/usr/bin/env bash
# Additive Dream acceptance. Existing 52 modes, 17 rasters and Wisp stay separate.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT="${GODOT_BIN:-godot}"
export GODOT_SILENCE_ROOT_WARNING=1
export GIT_OPTIONAL_LOCKS=0

if [[ -n "${LUMO_DREAM_LOG_DIR:-}" ]]; then
  mkdir -p "$(dirname "$LUMO_DREAM_LOG_DIR")"
  mkdir "$LUMO_DREAM_LOG_DIR"
  LOG_DIR="$(cd "$LUMO_DREAM_LOG_DIR" && pwd)"
else
  LOG_DIR="$(mktemp -d /tmp/lumo-dream.XXXXXXXX)"
fi
mkdir "$LOG_DIR/captures"
printf '%s\n' "$LOG_DIR" > "$LOG_DIR/capture-root.txt"
git rev-parse HEAD > "$LOG_DIR/source-sha.txt"
git rev-parse 'HEAD^{tree}' > "$LOG_DIR/source-tree.txt"
git status --porcelain --untracked-files=no > "$LOG_DIR/source-dirty.txt"
python3 tools/verify_dream_rasters.py "$LOG_DIR" --snapshot-source "$ROOT" --snapshot-phase before
stamp_after() {
  git rev-parse HEAD > "$LOG_DIR/source-sha-after.txt"
  git rev-parse 'HEAD^{tree}' > "$LOG_DIR/source-tree-after.txt"
  git status --porcelain --untracked-files=no > "$LOG_DIR/source-dirty-after.txt"
  python3 tools/verify_dream_rasters.py "$LOG_DIR" --snapshot-source "$ROOT" --snapshot-phase after
}
trap stamp_after EXIT
if [[ -s "$LOG_DIR/source-dirty.txt" ]]; then
  echo '[LumoDreamConnections] FAIL: tracked source must be clean.' >&2
  exit 1
fi
if [[ -n "${LUMO_EXPECTED_NATIVE_SHA:-}" && "$(<"$LOG_DIR/source-sha.txt")" != "$LUMO_EXPECTED_NATIVE_SHA" ]]; then
  echo '[LumoDreamConnections] FAIL: actual Native source differs from the requested pin.' >&2
  exit 1
fi
"$GODOT" --version > "$LOG_DIR/engine.txt"

run_probe() {
  local name="$1" mode="$2" marker="$3"
  shift 3
  local timeout_seconds=120
  local script="scripts/tests/$name.gd"
  local command=("$GODOT")
  local args=(--audio-driver Dummy --path "$ROOT" --script "$script")
  if [[ ! -s "$script" ]]; then
    echo "Missing required Dream probe: $script" >&2
    return 1
  fi
  if [[ "$mode" == headless ]]; then
    args=(--headless "${args[@]}")
  else
    timeout_seconds=180
    args=(--rendering-method gl_compatibility "${args[@]}")
    if [[ -z "${DISPLAY:-}" ]]; then
      if ! command -v xvfb-run >/dev/null 2>&1; then
        echo 'Dream visual acceptance requires DISPLAY or xvfb-run.' >&2
        return 1
      fi
      command=(xvfb-run -a -s '-screen 0 2560x2560x24' "${command[@]}")
    fi
  fi
  local user_dir="$LOG_DIR/user-data/$name-$mode"
  local config_dir="$LOG_DIR/user-config/$name-$mode"
  local cache_dir="$LOG_DIR/user-cache/$name-$mode"
  mkdir -p "$user_dir" "$config_dir" "$cache_dir" || return 1
  XDG_DATA_HOME="$user_dir" XDG_CONFIG_HOME="$config_dir" XDG_CACHE_HOME="$cache_dir" \
    python3 tools/run_godot_probe.py --log "$LOG_DIR/$name-$mode.log" \
    --timeout "$timeout_seconds" --required "$marker" -- "${command[@]}" "${args[@]}" "$@" || return $?
  # The shared runner stops engine errors. Retain the Producer's leak rejection
  # and require exactly one complete marker, not a matching substring.
  if grep -En 'SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|ObjectDB instances leaked|resources still in use at exit' \
    "$LOG_DIR/$name-$mode.log"; then
    return 1
  fi
  local count
  if ! count="$(grep -Fxc -- "$marker" "$LOG_DIR/$name-$mode.log")"; then
    return 1
  fi
  [[ "$count" == 1 ]]
}

failures=()
check_probe() {
  if run_probe "$@"; then
    printf '%s\t%s\tPASS\n' "$1" "$2" >> "$LOG_DIR/results.tsv"
  else
    failures+=("$1/$2")
    printf '%s\t%s\tFAIL\n' "$1" "$2" >> "$LOG_DIR/results.tsv"
  fi
}
printf 'probe\tmode\tresult\n' > "$LOG_DIR/results.tsv"
check_probe lumo_dream_ambience_regression headless '[DreamAmbience] 170 checks, 0 failures'
check_probe dream_garden_props_regression headless '[DreamGarden] checks=544 failures=0'
check_probe lumo_dream_ambience_capture rendered-treasure \
  "[DreamAmbienceCapture] PASS treasure original frames in $LOG_DIR/captures/treasure" \
  -- --world=treasure "--capture-dir=$LOG_DIR/captures/treasure"
check_probe lumo_dream_ambience_capture rendered-learning \
  "[DreamAmbienceCapture] PASS learning original frames in $LOG_DIR/captures/learning" \
  -- --world=learning "--capture-dir=$LOG_DIR/captures/learning"
check_probe dream_garden_capture rendered '[DreamGardenCapture] failures=0' \
  -- "--output=$LOG_DIR/captures/garden"

stamp_after
trap - EXIT
if ! python3 tools/verify_dream_rasters.py "$LOG_DIR" --write; then
  failures+=("dream-original-raster-report-contract")
fi
if (( ${#failures[@]} )); then
  printf '[LumoDreamConnections] FAIL: %s\n' "${failures[*]}" >&2
  exit 1
fi
echo '[LumoDreamConnections] PASS 5 original probes and 7 verified renderer PNGs'
