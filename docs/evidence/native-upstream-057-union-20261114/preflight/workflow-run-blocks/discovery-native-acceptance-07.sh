set -euo pipefail
timeout --signal=TERM --kill-after=5s 420s "$GODOT_BIN" \
  --headless --audio-driver Dummy --path "$GITHUB_WORKSPACE" --editor --import --quit \
  2>&1 | tee "$LUMO_DISCOVERY_EVIDENCE_DIR/import.log"
if grep -En 'SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|ObjectDB instances leaked|resources still in use at exit' \
  "$LUMO_DISCOVERY_EVIDENCE_DIR/import.log"; then
  exit 1
fi
