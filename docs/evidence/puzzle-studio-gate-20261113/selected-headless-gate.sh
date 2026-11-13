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
  local puzzle_menu_evidence="$capture"
  if [[ "$mode" == headless ]]; then
    puzzle_menu_evidence="$LOG_DIR/evidence/$script-$mode"
  fi
  mkdir -p "$capture" "$user" "$puzzle_menu_evidence"
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
    TREASURE_EXPLORATION_CAPTURE_DIR="$capture" LUMO_PUZZLE_MENU_EVIDENCE_DIR="$puzzle_menu_evidence" \
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

check_probe puzzle_menu_lifecycle_regression '[PuzzleMenuLifecycle] PASS' headless 180
if (( ${#failures[@]} )); then exit 1; fi
