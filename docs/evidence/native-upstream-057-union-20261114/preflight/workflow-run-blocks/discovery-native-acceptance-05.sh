set -euo pipefail
"$LUMO_DISCOVERY_PYTHON" -m unittest tools.tests.test_dream_rasters -v \
  2>&1 | tee "$LUMO_DISCOVERY_EVIDENCE_DIR/tests/dream-raster-tests.log"
test "$(grep -Ec '^Ran 12 tests in [0-9.]+s$' "$LUMO_DISCOVERY_EVIDENCE_DIR/tests/dream-raster-tests.log")" = 1
test "$(grep -Fxc 'OK' "$LUMO_DISCOVERY_EVIDENCE_DIR/tests/dream-raster-tests.log")" = 1
