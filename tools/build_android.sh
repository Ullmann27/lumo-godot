#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────
# build_android.sh - Android-Export-Diagnose fuer Lumo 3D.
# ────────────────────────────────────────────────────────────────────────
# Prueft Schritt-fuer-Schritt was fuer einen APK-Build noetig ist:
#   1. Godot Binary
#   2. Export-Templates (4.6.3.stable/android_*.apk)
#   3. Export-Preset "Android" in export_presets.cfg
#   4. JDK (java -version)
#   5. Android SDK ($ANDROID_HOME/platform-tools/adb)
#   6. Debug-Keystore (~/.android/debug.keystore)
#
# Wenn alles PASS: versucht echten Export.
# Bei WARN/FAIL: gibt konkreten Naechster-Schritt-Hinweis aus.
#
# Exit-Codes:
#   0 = APK erfolgreich erzeugt
#   1 = Diagnose ergab kritische Luecke (kein Build moeglich)
# ────────────────────────────────────────────────────────────────────────
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT_BIN:-/home/user/tools/godot}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
NEXT_STEPS=()

step() {
    local level="$1"; local label="$2"; local detail="$3"
    echo "[$level] $label: $detail"
    case "$level" in
        PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
        WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
        FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    esac
}

echo "════════════════════════════════════════════════════"
echo "Lumo 3D Android Build Diagnostics"
echo "════════════════════════════════════════════════════"

# 1. Godot Binary
if [[ -x "$GODOT" ]]; then
    VERSION_RAW="$($GODOT --version 2>/dev/null | tr -d '\n' || true)"
    if [[ "$VERSION_RAW" == 4.6.* ]]; then
        step "PASS" "godot-binary" "$VERSION_RAW ($GODOT)"
    else
        step "WARN" "godot-binary" "Version $VERSION_RAW (erwartet 4.6.x)"
    fi
else
    step "FAIL" "godot-binary" "nicht gefunden bei $GODOT"
    NEXT_STEPS+=("Setze GODOT_BIN env oder lade Godot 4.6.3 nach /home/user/tools/")
fi

# 2. Export-Templates
VERSION_SHORT="$(echo "${VERSION_RAW:-}" | cut -d. -f1-3).stable"
TPL_DIR="$HOME/.local/share/godot/export_templates/${VERSION_SHORT}"
if [[ -f "$TPL_DIR/android_release.apk" && -f "$TPL_DIR/android_debug.apk" ]]; then
    step "PASS" "export-templates" "android_*.apk in $TPL_DIR"
else
    step "FAIL" "export-templates" "android_release.apk / android_debug.apk fehlen in $TPL_DIR"
    NEXT_STEPS+=("Lade Templates: curl -L https://github.com/godotengine/godot/releases/download/${VERSION_SHORT}/Godot_v${VERSION_SHORT}_export_templates.tpz -o /tmp/godot_templates.tpz && unzip /tmp/godot_templates.tpz -d /tmp/tpl && mkdir -p $TPL_DIR && mv /tmp/tpl/templates/* $TPL_DIR/")
fi

# 3. Export-Preset
if grep -q '^name="Android"' "$ROOT/export_presets.cfg" 2>/dev/null; then
    step "PASS" "export-preset" "Android preset in export_presets.cfg"
else
    step "FAIL" "export-preset" "kein 'Android' preset in export_presets.cfg"
    NEXT_STEPS+=("Lege Android-Preset in export_presets.cfg an (siehe Vorlage in CLAUDE.md)")
fi

# 4. JDK
if command -v java >/dev/null 2>&1; then
    JAVA_VER="$(java -version 2>&1 | head -1)"
    step "PASS" "jdk" "$JAVA_VER"
else
    step "WARN" "jdk" "java nicht gefunden - APK-Signing nicht moeglich"
    NEXT_STEPS+=("apt install -y openjdk-17-jdk-headless")
fi

# 5. Android SDK
SDK_PATH="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -n "$SDK_PATH" && -x "$SDK_PATH/platform-tools/adb" ]]; then
    step "PASS" "android-sdk" "$SDK_PATH"
else
    step "WARN" "android-sdk" "ANDROID_HOME nicht gesetzt oder adb fehlt"
    NEXT_STEPS+=("Android SDK installieren: https://developer.android.com/studio/command-line  + export ANDROID_HOME=...")
fi

# 6. Debug-Keystore
KS="$HOME/.android/debug.keystore"
if [[ -f "$KS" ]]; then
    step "PASS" "keystore" "$KS"
else
    step "WARN" "keystore" "Debug-Keystore fehlt"
    NEXT_STEPS+=("keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore $KS -storepass android -dname 'CN=Android Debug,O=Android,C=US' -validity 9999 -deststoretype pkcs12")
fi

echo "════════════════════════════════════════════════════"
echo "SUMMARY: $PASS_COUNT PASS / $WARN_COUNT WARN / $FAIL_COUNT FAIL"
echo "════════════════════════════════════════════════════"

if [[ $FAIL_COUNT -gt 0 || $WARN_COUNT -gt 0 ]]; then
    echo
    echo "NEXT STEPS:"
    for step_msg in "${NEXT_STEPS[@]}"; do
        echo "  • $step_msg"
    done
    if [[ $FAIL_COUNT -gt 0 ]]; then
        echo
        echo "RESULT: FAIL (APK-Build nicht moeglich, kritische Luecken)"
        exit 1
    fi
    echo
    echo "RESULT: WARN (APK-Build aktuell nicht moeglich, Setup-Schritte oben)"
    exit 1
fi

# Alle PASS -> versuche echten Export
echo
echo "Alle Checks PASS - versuche Android-Debug-Export..."
mkdir -p exports/android
"$GODOT" --headless --import 2>&1 | tail -3
"$GODOT" --headless --export-debug "Android" exports/android/lumo3d.apk 2>&1 | tail -20

if [[ -f exports/android/lumo3d.apk ]]; then
    echo "RESULT: PASS - APK erzeugt: exports/android/lumo3d.apk"
    ls -lh exports/android/lumo3d.apk
    exit 0
fi
echo "RESULT: FAIL - Export-Befehl lief, aber APK nicht erzeugt"
exit 1
