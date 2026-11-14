set -euo pipefail
"$LUMO_DISCOVERY_PYTHON" -m unittest tools.tests.test_discovery_connections -v \
  2>&1 | tee "$LUMO_DISCOVERY_EVIDENCE_DIR/tests/discovery-originals-tests.log"
test "$(grep -Ec '^Ran 24 tests in [0-9.]+s$' "$LUMO_DISCOVERY_EVIDENCE_DIR/tests/discovery-originals-tests.log")" = 1
test "$(grep -Fxc 'OK' "$LUMO_DISCOVERY_EVIDENCE_DIR/tests/discovery-originals-tests.log")" = 1
PYTHONPATH=tools:tools/tests "$LUMO_DISCOVERY_PYTHON" -m unittest test_discovery_rasters -v \
  2>&1 | tee "$LUMO_DISCOVERY_EVIDENCE_DIR/tests/discovery-producer-reader-tests.log"
test "$(grep -Ec '^Ran 11 tests in [0-9.]+s$' "$LUMO_DISCOVERY_EVIDENCE_DIR/tests/discovery-producer-reader-tests.log")" = 1
test "$(grep -Fxc 'OK' "$LUMO_DISCOVERY_EVIDENCE_DIR/tests/discovery-producer-reader-tests.log")" = 1
