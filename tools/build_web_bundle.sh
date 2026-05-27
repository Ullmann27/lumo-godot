#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────
# build_web_bundle.sh - browser-lauffaehigen Web-Build erzeugen.
# ────────────────────────────────────────────────────────────────────────
#
# Hintergrund: Godot 4.6.3 `--export-release "Web"` schlaegt im Headless
# mit einem stillen Configuration-Error fehl. `--export-pack` funktioniert
# aber, und die Web-Template-Files (godot.html/js/wasm/...) liegen in den
# Export-Templates bereit. Dieses Skript:
#   1. Findet das passende Web-Template (web_nothreads_release.zip)
#   2. Entpackt es nach exports/web/
#   3. Generiert die PCK via --export-pack
#   4. Patcht die HTML-Placeholders ($GODOT_CONFIG, $GODOT_URL, ...)
#   5. Legt die _headers-Datei + README an
#
# Resultat: exports/web/ enthaelt einen lauffaehigen Web-Build (Drop in
# Netlify/Cloudflare Pages/itch.io).
# ────────────────────────────────────────────────────────────────────────
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
GODOT="${GODOT_BIN:-$(command -v godot 2>/dev/null || command -v godot4 2>/dev/null || echo /home/user/tools/godot)}"
VERSION_SHORT="$("$GODOT" --version | cut -d. -f1-3).stable"
TPL_ZIP="$HOME/.local/share/godot/export_templates/${VERSION_SHORT}/web_nothreads_release.zip"

if [[ ! -f "$TPL_ZIP" ]]; then
    echo "[build_web_bundle] FAIL: Web-Template fehlt: $TPL_ZIP"
    exit 1
fi

mkdir -p exports/web
TMP_TPL="$(mktemp -d)"
unzip -q -o "$TPL_ZIP" -d "$TMP_TPL/"
cp "$TMP_TPL/godot.html"                          exports/web/index.html
cp "$TMP_TPL/godot.js"                            exports/web/index.js
cp "$TMP_TPL/godot.wasm"                          exports/web/index.wasm
cp "$TMP_TPL/godot.audio.worklet.js"              exports/web/index.audio.worklet.js
cp "$TMP_TPL/godot.audio.position.worklet.js"     exports/web/index.audio.position.worklet.js
rm -rf "$TMP_TPL"

"$GODOT" --headless --export-pack "Web" exports/web/index.pck 2>&1 | tail -2

PCK_SIZE=$(stat -c%s exports/web/index.pck 2>/dev/null || stat -f%z exports/web/index.pck)
WASM_SIZE=$(stat -c%s exports/web/index.wasm 2>/dev/null || stat -f%z exports/web/index.wasm)

python3 - "$PCK_SIZE" "$WASM_SIZE" <<'PYEOF'
import sys
from pathlib import Path
pck_size, wasm_size = sys.argv[1], sys.argv[2]
html = Path("exports/web/index.html").read_text()
config = (
    '{\n'
    '    "args": [],\n'
    '    "canvasResizePolicy": 2,\n'
    '    "ensureCrossOriginIsolationHeaders": true,\n'
    '    "executable": "index",\n'
    '    "experimentalVK": false,\n'
    '    "focusCanvas": true,\n'
    '    "gdextensionLibs": [],\n'
    f'    "fileSizes": {{"index.pck": {pck_size}, "index.wasm": {wasm_size}}},\n'
    '    "serviceWorker": ""\n'
    '}'
)
replacements = {
    "$GODOT_PROJECT_NAME": "Lumo 3D",
    "$GODOT_HEAD_INCLUDE": "",
    "$GODOT_SPLASH_COLOR": "#0a0a14",
    "$GODOT_SPLASH_CLASSES": "show-image--false fullsize--false use-filter--true",
    "$GODOT_SPLASH": "",
    "$GODOT_URL": "index.js",
    "$GODOT_CONFIG": config,
    "$GODOT_THREADS_ENABLED": "false",
    "$GODOT_FG_COLOR": "#ffd078",
    "$GODOT_BG_COLOR": "#0a0a14",
}
for k, v in replacements.items():
    html = html.replace(k, v)
Path("exports/web/index.html").write_text(html)
import re
left = re.findall(r"\$GODOT_[A-Z_]+", html)
if left:
    print(f"[build_web_bundle] WARN leftover placeholders: {left}")
PYEOF

# _headers fuer Hoster die das beachten (Cloudflare, Netlify)
cat > exports/web/_headers <<'EOF'
/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
  Cross-Origin-Resource-Policy: cross-origin
EOF

echo
echo "[build_web_bundle] DONE"
ls -lh exports/web/index.* exports/web/_headers
