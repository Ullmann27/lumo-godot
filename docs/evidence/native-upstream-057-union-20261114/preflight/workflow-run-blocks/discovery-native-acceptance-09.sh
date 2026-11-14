set -euo pipefail
test ! -e "$LUMO_DREAM_LOG_DIR"
test ! -L "$LUMO_DREAM_LOG_DIR"
test "$LUMO_EXPECTED_NATIVE_SHA" = "$GITHUB_SHA"
bash tools/validate_dream_connections.sh 2>&1 | tee "$LUMO_DISCOVERY_EVIDENCE_DIR/dream-runner.log"
test "$(grep -Fxc '[LumoDreamConnections] PASS 5 original probes and 7 verified renderer PNGs' \
  "$LUMO_DISCOVERY_EVIDENCE_DIR/dream-runner.log")" = 1
