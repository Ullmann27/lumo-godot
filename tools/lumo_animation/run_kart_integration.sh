#!/usr/bin/env bash
# Focused product-source and exported-PCK regression. No device/API access.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
OUTPUT="${1:-/tmp/lumo-kart-integration}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
cd "$ROOT"
export XDG_DATA_HOME="$OUTPUT/source-user-data"

probe() {
  local name="$1" marker="$2"
  shift 2
  if ! python3 tools/run_godot_probe.py --log "$OUTPUT/$name.log" \
      --timeout 240 --required "$marker" -- "$GODOT" "$@" \
      >"$OUTPUT/$name-runner.log" 2>&1; then
    tail -60 "$OUTPUT/$name-runner.log"
    return 1
  fi
  if rg -n 'ObjectDB instances leaked|RID allocations' "$OUTPUT/$name.log"; then
    return 1
  fi
  echo "[LumoKartIntegration] PASS $name"
}

probe import first_scan_filesystem \
  --headless --audio-driver Dummy --path "$ROOT" --editor --import --quit
probe product '[LumoKartProduction] PASS' \
  --headless --audio-driver Dummy --path "$ROOT" \
  --script res://scripts/tests/lumo_kart_production_regression.gd -- "$OUTPUT/product"

for entry in \
    'kart_physics_regression|[KartPhysics] PASS' \
    'kart_jump_regression|[KartJump] PASS' \
    'kart_race_bridge_regression|[KartRaceBridge] PASS' \
    'kart_vehicle_regression|[KartVehicle] Geometry/colours, shadows, animations, effects, LOD and hysteresis passed'; do
  IFS='|' read -r name marker <<< "$entry"
  probe "$name" "$marker" --headless --audio-driver Dummy --path "$ROOT" \
    --script "res://scripts/tests/$name.gd"
done

probe export savepack --headless --audio-driver Dummy --path "$ROOT" \
  --export-pack Linux "$OUTPUT/lumo-kart-production.pck"
test -s "$OUTPUT/lumo-kart-production.pck"
mkdir -p "$OUTPUT/packed-runtime"
cp scripts/tests/lumo_kart_production_regression.gd "$OUTPUT/packed-runtime/production_probe.gd"
export XDG_DATA_HOME="$OUTPUT/packed-user-data"
probe packed-runtime '[LumoKartProduction] PASS' \
  --headless --audio-driver Dummy --path "$OUTPUT/packed-runtime" \
  --main-pack "$OUTPUT/lumo-kart-production.pck" \
  --script "$OUTPUT/packed-runtime/production_probe.gd" -- "$OUTPUT/packed-runtime"
sha256sum "$OUTPUT/lumo-kart-production.pck" >"$OUTPUT/pck.sha256"
echo "[LumoKartIntegration] PASS source factory, existing regressions and exported PCK"
