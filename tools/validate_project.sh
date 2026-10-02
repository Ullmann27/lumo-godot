#!/usr/bin/env bash
set -euo pipefail
GODOT="${GODOT_BIN:-godot}"
"$GODOT" --headless --editor --import --quit 2>&1 | tee /tmp/lumo-import.log
if grep -qE 'SCRIPT ERROR|Parse Error|ERROR:' /tmp/lumo-import.log; then exit 1; fi
"$GODOT" --headless --script scripts/tests/kart_regression.gd 2>&1 | tee /tmp/lumo-kart-tests.log
if grep -qE 'SCRIPT ERROR|Parse Error|ERROR:' /tmp/lumo-kart-tests.log; then exit 1; fi
grep -qE '\[KartTests\] PASS' /tmp/lumo-kart-tests.log
