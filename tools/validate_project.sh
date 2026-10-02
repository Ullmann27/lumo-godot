#!/usr/bin/env bash
set -euo pipefail
GODOT="${GODOT_BIN:-godot}"
timeout 120s "$GODOT" --headless --editor --import --quit 2>&1 | tee /tmp/lumo-import.log
if grep -qE 'SCRIPT ERROR|Parse Error|ERROR:' /tmp/lumo-import.log; then exit 1; fi
timeout 120s "$GODOT" --headless --script scripts/tests/kart_regression.gd 2>&1 | tee /tmp/lumo-kart-tests.log
if grep -qE 'SCRIPT ERROR|Parse Error|ERROR:' /tmp/lumo-kart-tests.log; then exit 1; fi
grep -qE '\[KartTests\] PASS' /tmp/lumo-kart-tests.log
timeout 120s "$GODOT" --headless --script scripts/tests/jump_regression.gd 2>&1 | tee /tmp/lumo-jump-tests.log
if grep -qE 'SCRIPT ERROR|Parse Error|ERROR:' /tmp/lumo-jump-tests.log; then exit 1; fi
grep -qE '\[JumpTests\] PASS' /tmp/lumo-jump-tests.log

timeout 120s "$GODOT" --headless --script scripts/tests/kart_touch_regression.gd 2>&1 | tee /tmp/lumo-kart-touch-tests.log
if grep -qE 'SCRIPT ERROR|Parse Error|ERROR:' /tmp/lumo-kart-touch-tests.log; then exit 1; fi
grep -qE '\[KartTouchTests\] PASS' /tmp/lumo-kart-touch-tests.log

# Real GPU state (MultiMesh colours and transforms) needs a rendering server.
if command -v xvfb-run >/dev/null 2>&1; then
  timeout 120s xvfb-run -a "$GODOT" --audio-driver Dummy --rendering-method gl_compatibility --script scripts/tests/kart_world_regression.gd 2>&1 | tee /tmp/lumo-world-tests.log
  if grep -qE "SCRIPT ERROR|Parse Error|ERROR:" /tmp/lumo-world-tests.log; then exit 1; fi
  grep -qE "\[KartWorldTests\] PASS" /tmp/lumo-world-tests.log
fi

timeout 120s "$GODOT" --headless --script scripts/tests/kart_vehicle_regression.gd 2>&1 | tee /tmp/lumo-vehicle-tests.log
if grep -qE 'SCRIPT ERROR|Parse Error|ERROR:' /tmp/lumo-vehicle-tests.log; then exit 1; fi
grep -qE '\[KartVehicle\] Geometry/colours' /tmp/lumo-vehicle-tests.log
