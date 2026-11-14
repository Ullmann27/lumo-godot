set -euo pipefail
printf '%s  %s\n' \
  55591b4478d2074135ea4950fb00200d68a3f9bede286b39642d7fc17aa586da tools/verify_discovery_rasters.py \
  f7296a802d15c382dbcc77640373a0f53e30306fcaab3de869549ff1656de89d tools/verify_dream_rasters.py \
  e1836029a196e4dcd4a4f47fd8c2010c5b460ec5bf4c0578e90e75d3a5d2ea13 tools/run_godot_probe.py \
  | sha256sum -c - | tee "$LUMO_DISCOVERY_EVIDENCE_DIR/source/helper-sha256.log"
test "$(git hash-object tools/verify_discovery_rasters.py)" = 219e691fc8aa119cc80221b3db6c77e63caf8bfe
test "$(git hash-object tools/verify_dream_rasters.py)" = da8eed7d6383fcbc82a03596518a5fcc3b9a00c5
test "$(git hash-object tools/run_godot_probe.py)" = c23859ece2d62101d000d7a89556fda5d3fe4105
"$LUMO_DISCOVERY_PYTHON" tools/verify_dream_rasters.py "$LUMO_DISCOVERY_EVIDENCE_DIR/source" \
  --snapshot-source "$GITHUB_WORKSPACE" --snapshot-phase before
