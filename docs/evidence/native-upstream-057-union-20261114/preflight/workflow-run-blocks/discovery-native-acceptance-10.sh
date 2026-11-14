set -euo pipefail
"$LUMO_DISCOVERY_PYTHON" tools/collect_discovery_connections.py \
  --project "$GITHUB_WORKSPACE" --output "$LUMO_DISCOVERY_EVIDENCE_DIR/discovery" \
  --expected-native-sha "$GITHUB_SHA" --expected-native-tree "$LUMO_EXPECTED_NATIVE_TREE" \
  --godot "$GODOT_BIN" 2>&1 | tee "$LUMO_DISCOVERY_EVIDENCE_DIR/discovery-collector.log"
test "$(grep -Fxc '[DiscoveryOriginals] PASS 10 exact probes, 38 decoded PNGs and 2 original reports' \
  "$LUMO_DISCOVERY_EVIDENCE_DIR/discovery-collector.log")" = 1
"$LUMO_DISCOVERY_PYTHON" tools/verify_discovery_connections.py "$LUMO_DISCOVERY_EVIDENCE_DIR/discovery" \
  --expected-native-sha "$GITHUB_SHA" --expected-native-tree "$LUMO_EXPECTED_NATIVE_TREE" \
  > "$LUMO_DISCOVERY_EVIDENCE_DIR/discovery-read-only-replay.log"
test "$(grep -Fxc '[DiscoveryOriginals] PASS 10 exact probes, 38 decoded PNGs and 2 original reports' \
  "$LUMO_DISCOVERY_EVIDENCE_DIR/discovery-read-only-replay.log")" = 1
