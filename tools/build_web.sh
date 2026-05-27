#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────
# build_web.sh - CI/CD-Pipeline-Befehl fuer Lumo 3D Web-Export.
# ────────────────────────────────────────────────────────────────────────
# Voraussetzung: Godot Export-Templates fuer 4.6.3 installiert.
# Wenn nicht da, versucht das Skript sie automatisch aus dem offiziellen
# Mirror (godotengine.org) herunterzuladen und in
# ~/.local/share/godot/export_templates/4.6.3.stable/ zu entpacken.
#
# Usage:
#   tools/build_web.sh                # Release-Build nach exports/web/
#   tools/build_web.sh --debug        # Debug-Build (mit Profiler)
#
# Exit-Codes:
#   0   = Build erfolgreich
#   1   = Export-Templates konnten nicht installiert werden
#   2   = Godot Export selbst hat fehlgeschlagen
# ────────────────────────────────────────────────────────────────────────
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT_BIN:-$(command -v godot 2>/dev/null || command -v godot4 2>/dev/null || echo /home/user/tools/godot)}"
# Godot fragt seine Export-Templates an einem GEKUERZTEN Pfad ab -
# "4.6.3.stable" statt der vollen "4.6.3.stable.official.7d41c59c4".
# Wir nehmen daher nur die ersten 3 Felder.
GODOT_VERSION_RAW="$($GODOT --version | tr -d '\n')"
GODOT_VERSION="$(echo "$GODOT_VERSION_RAW" | cut -d. -f1-3).stable"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}"
EXPORT_PROFILE="${1:-Web}"
EXPORT_FLAG="--export-release"
if [[ "${1:-}" == "--debug" ]]; then
    EXPORT_FLAG="--export-debug"
    EXPORT_PROFILE="Web"
fi
OUT_DIR="$ROOT/exports/web"
OUT_HTML="$OUT_DIR/index.html"

mkdir -p "$OUT_DIR"

echo "[build_web] Godot:    $GODOT_VERSION"
echo "[build_web] Templates: $TEMPLATE_DIR"
echo "[build_web] Profile:   $EXPORT_PROFILE  (mode: $EXPORT_FLAG)"
echo "[build_web] Output:    $OUT_HTML"

# Auto-Install der Export-Templates wenn sie fehlen.
if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo "[build_web] Templates fehlen, lade .tpz (~900 MB)..."
    TPZ_URL="https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz"
    TPZ_TMP="/tmp/godot_templates.tpz"
    curl -L --max-time 600 -o "$TPZ_TMP" "$TPZ_URL"
    mkdir -p "$TEMPLATE_DIR"
    # .tpz ist ein normales ZIP. Entpackt in einen 'templates'-Ordner.
    unzip -q "$TPZ_TMP" -d "$TEMPLATE_DIR.unpack"
    mv "$TEMPLATE_DIR.unpack/templates/"* "$TEMPLATE_DIR/"
    rm -rf "$TEMPLATE_DIR.unpack" "$TPZ_TMP"
    echo "[build_web] Templates installiert."
fi

# Run the actual export.
"$GODOT" --headless --import 2>&1 | tail -5
"$GODOT" --headless "$EXPORT_FLAG" "$EXPORT_PROFILE" "$OUT_HTML" 2>&1 | tee /tmp/build_web.log

if [[ ! -f "$OUT_HTML" ]]; then
    echo "[build_web] FAIL: $OUT_HTML wurde nicht erzeugt"
    exit 2
fi

echo "[build_web] DONE."
ls -lh "$OUT_DIR"
