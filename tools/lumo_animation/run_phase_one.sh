#!/usr/bin/env bash
# Strict, focused regression runner. No network, voice, rewards or save changes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
OUTPUT="${1:-/tmp/lumo-animation-review}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
cd "$ROOT"
export XDG_DATA_HOME="${LUMO_REVIEW_USER_DATA:-$OUTPUT/user-data}"
run() {
  local name="$1" script="$2" target="$3"
  if ! "$GODOT" --headless --audio-driver Dummy --path "$ROOT" --script "$script" -- "$target" >"$OUTPUT/$name.log" 2>&1; then
    tail -70 "$OUTPUT/$name.log"
    return 1
  fi
  if rg -n '(^ERROR:|SCRIPT ERROR:|Parse Error:|ObjectDB instances leaked|RID allocations)' "$OUTPUT/$name.log"; then
    return 1
  fi
  tail -2 "$OUTPUT/$name.log"
}
run character scripts/tests/lumo_rigged_animation_capture.gd "$OUTPUT/character"
run kart scripts/tests/lumo_kart_animation_review.gd "$OUTPUT/kart"
# Run the benchmark last and alone; concurrent Godot jobs distort timings.
run cpu scripts/tests/lumo_animation_cpu_benchmark.gd "$OUTPUT/cpu-benchmark.json"
node tools/lumo_animation/inspect_glb.mjs assets/characters/lumo_animated/Lumo-Animated-Mobile.glb "$OUTPUT/glb-audit.json"
echo "[LumoAnimationPhaseOne] PASS focused headless tests and GLB audit"
