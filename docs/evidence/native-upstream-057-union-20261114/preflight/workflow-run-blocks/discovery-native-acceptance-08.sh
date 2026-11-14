set -euo pipefail
check_headless() {
  local name="$1" seconds="$2" marker="$3"
  local proof="$LUMO_DISCOVERY_EVIDENCE_DIR/headless/$name.log"
  local state="$LUMO_DISCOVERY_ROOT/xdg/$name"
  mkdir -p "$state/data" "$state/config" "$state/cache" || return 1
  XDG_DATA_HOME="$state/data" XDG_CONFIG_HOME="$state/config" XDG_CACHE_HOME="$state/cache" \
    "$LUMO_DISCOVERY_PYTHON" tools/run_godot_probe.py \
    --log "$proof" --timeout "$seconds" --required "$marker" -- \
    "$GODOT_BIN" --headless --audio-driver Dummy --path "$GITHUB_WORKSPACE" \
    --script "res://scripts/tests/$name.gd" || return $?
  if grep -En 'SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|ObjectDB instances leaked|resources still in use at exit' "$proof"; then
    return 1
  fi
  local count
  if ! count="$(grep -Fxc -- "$marker" "$proof")"; then
    return 1
  fi
  test "$count" = 1
}
{
  check_headless connect_four_return_regression 60 'CONNECT_FOUR_RETURN_PASS checks=21' || exit 1
  check_headless treasure_wisp_regression 180 '[TreasureWisp] PASS checks=14' || exit 1
  check_headless treasure_exploration_regression 420 \
    '[TreasureExploration] PASS 92 checks: branching, actual location questions, movement, legacy saves and original rewards' || exit 1
  check_headless learning_world_regression 420 '[LearningWorld] PASS checks=5347' || exit 1
} 2>&1 | tee "$LUMO_DISCOVERY_EVIDENCE_DIR/headless/runner.log"
