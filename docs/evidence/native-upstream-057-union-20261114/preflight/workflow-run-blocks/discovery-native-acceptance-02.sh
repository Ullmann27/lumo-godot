set -euo pipefail
LUMO_DISCOVERY_ROOT="$RUNNER_TEMP/lumo-discovery-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
LUMO_DISCOVERY_EVIDENCE_DIR="$LUMO_DISCOVERY_ROOT/evidence"
mkdir "$LUMO_DISCOVERY_ROOT"
mkdir -p "$LUMO_DISCOVERY_EVIDENCE_DIR/source" \
  "$LUMO_DISCOVERY_EVIDENCE_DIR/tests" "$LUMO_DISCOVERY_EVIDENCE_DIR/headless" \
  "$LUMO_DISCOVERY_ROOT/engine" "$LUMO_DISCOVERY_ROOT/tmp" \
  "$LUMO_DISCOVERY_ROOT/xdg/data" "$LUMO_DISCOVERY_ROOT/xdg/config" "$LUMO_DISCOVERY_ROOT/xdg/cache"
{
  printf 'LUMO_DISCOVERY_ROOT=%s\n' "$LUMO_DISCOVERY_ROOT"
  printf 'LUMO_DISCOVERY_EVIDENCE_DIR=%s\n' "$LUMO_DISCOVERY_EVIDENCE_DIR"
  printf 'GODOT_BIN=%s/engine/bin/godot\n' "$LUMO_DISCOVERY_ROOT"
  printf 'LUMO_DISCOVERY_PYTHON=%s/venv/bin/python\n' "$LUMO_DISCOVERY_ROOT"
  printf 'LUMO_DREAM_LOG_DIR=%s/dream\n' "$LUMO_DISCOVERY_EVIDENCE_DIR"
  printf 'LUMO_EXPECTED_NATIVE_SHA=%s\n' "$GITHUB_SHA"
  printf 'LUMO_EXPECTED_NATIVE_TREE=%s\n' "$(git rev-parse 'HEAD^{tree}')"
  printf 'TMPDIR=%s/tmp\n' "$LUMO_DISCOVERY_ROOT"
  printf 'XDG_DATA_HOME=%s/xdg/data\n' "$LUMO_DISCOVERY_ROOT"
  printf 'XDG_CONFIG_HOME=%s/xdg/config\n' "$LUMO_DISCOVERY_ROOT"
  printf 'XDG_CACHE_HOME=%s/xdg/cache\n' "$LUMO_DISCOVERY_ROOT"
} >> "$GITHUB_ENV"
git rev-parse HEAD > "$LUMO_DISCOVERY_EVIDENCE_DIR/source/sha-before.txt"
git rev-parse 'HEAD^{tree}' > "$LUMO_DISCOVERY_EVIDENCE_DIR/source/tree-before.txt"
git status --porcelain --untracked-files=no > "$LUMO_DISCOVERY_EVIDENCE_DIR/source/status-before.txt"
git status --porcelain --untracked-files=all > "$LUMO_DISCOVERY_EVIDENCE_DIR/source/all-status-before.txt"
git ls-files --stage > "$LUMO_DISCOVERY_EVIDENCE_DIR/source/index-before.txt"
sha256sum "$(git rev-parse --git-path index)" | cut -d ' ' -f 1 \
  > "$LUMO_DISCOVERY_EVIDENCE_DIR/source/index-sha256-before.txt"
printf 'repository=%s\nref=%s\nsource=%s\nrun=%s\nattempt=%s\njob=%s\n' \
  "$GITHUB_REPOSITORY" "$GITHUB_REF" "$GITHUB_SHA" "$GITHUB_RUN_ID" \
  "$GITHUB_RUN_ATTEMPT" "$GITHUB_JOB" > "$LUMO_DISCOVERY_EVIDENCE_DIR/source/workflow-context.txt"
test "$(cat "$LUMO_DISCOVERY_EVIDENCE_DIR/source/sha-before.txt")" = "$GITHUB_SHA"
test ! -s "$LUMO_DISCOVERY_EVIDENCE_DIR/source/status-before.txt"
