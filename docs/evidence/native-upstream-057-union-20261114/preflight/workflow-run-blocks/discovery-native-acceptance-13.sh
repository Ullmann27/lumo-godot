set -euo pipefail
LUMO_DISCOVERY_EVIDENCE_DIR="$RUNNER_TEMP/lumo-discovery-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT/evidence"
mkdir -p "$LUMO_DISCOVERY_EVIDENCE_DIR/source"
git rev-parse HEAD > "$LUMO_DISCOVERY_EVIDENCE_DIR/source/sha-after.txt"
git rev-parse 'HEAD^{tree}' > "$LUMO_DISCOVERY_EVIDENCE_DIR/source/tree-after.txt"
git status --porcelain --untracked-files=no > "$LUMO_DISCOVERY_EVIDENCE_DIR/source/status-after.txt"
git status --porcelain --untracked-files=all > "$LUMO_DISCOVERY_EVIDENCE_DIR/source/all-status-after.txt"
git ls-files --stage > "$LUMO_DISCOVERY_EVIDENCE_DIR/source/index-after.txt"
sha256sum "$(git rev-parse --git-path index)" | cut -d ' ' -f 1 \
  > "$LUMO_DISCOVERY_EVIDENCE_DIR/source/index-sha256-after.txt"
cmp "$LUMO_DISCOVERY_EVIDENCE_DIR/source/sha-before.txt" "$LUMO_DISCOVERY_EVIDENCE_DIR/source/sha-after.txt"
cmp "$LUMO_DISCOVERY_EVIDENCE_DIR/source/tree-before.txt" "$LUMO_DISCOVERY_EVIDENCE_DIR/source/tree-after.txt"
cmp "$LUMO_DISCOVERY_EVIDENCE_DIR/source/index-before.txt" "$LUMO_DISCOVERY_EVIDENCE_DIR/source/index-after.txt"
cmp "$LUMO_DISCOVERY_EVIDENCE_DIR/source/index-sha256-before.txt" "$LUMO_DISCOVERY_EVIDENCE_DIR/source/index-sha256-after.txt"
test ! -s "$LUMO_DISCOVERY_EVIDENCE_DIR/source/status-after.txt"
"$LUMO_DISCOVERY_PYTHON" tools/verify_dream_rasters.py "$LUMO_DISCOVERY_EVIDENCE_DIR/source" \
  --snapshot-source "$GITHUB_WORKSPACE" --snapshot-phase after
"$LUMO_DISCOVERY_PYTHON" - "$LUMO_DISCOVERY_EVIDENCE_DIR/source" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
before = json.loads((root / "source-inventory-before.json").read_text())
after = json.loads((root / "source-inventory-after.json").read_text())
for key in ("head", "tree", "index_sha256", "tracked"):
    if before[key] != after[key]:
        raise SystemExit("Tracked/index source changed: " + key)
if not all(row["materialized"] is True for row in after["tracked"]):
    raise SystemExit("Full Discovery CI checkout has missing tracked source bytes")
print("Complete tracked source/index unchanged; generated imports inventoried separately")
PY
