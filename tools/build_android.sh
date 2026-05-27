#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────
# build_android.sh - Android-Export-Diagnose + (wenn moeglich) Build.
# ────────────────────────────────────────────────────────────────────────
# Prueft alle Voraussetzungen fuer einen Godot 4.6.3 Android-APK-Build:
#   1.  Godot Binary
#   2.  Android Export-Templates
#   3.  Android Export-Preset in export_presets.cfg
#   4.  JDK (java, keytool, jarsigner)
#   5.  ANDROID_HOME / ANDROID_SDK_ROOT Environment
#   6.  Android SDK Tools: sdkmanager, adb, apksigner
#   7.  Build-Tools Verzeichnis ($ANDROID_HOME/build-tools/<version>)
#   8.  Platform-Tools Verzeichnis ($ANDROID_HOME/platform-tools)
#   9.  Debug-Keystore (~/.android/debug.keystore)
#
# Jeder Schritt: PASS | WARN | FAIL. Bei WARN/FAIL gibt es eine konkrete
# Anweisung (apt-Befehl, sdkmanager-Befehl, setup-Skript-Aufruf, ...).
#
# Exit-Codes:
#   0 = APK wurde tatsaechlich erzeugt (alles gruen)
#   1 = irgendetwas fehlt - APK nicht gebaut, Diagnose-Bericht ausgegeben
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

next() {
    NEXT_STEPS+=("$1")
}

echo "════════════════════════════════════════════════════"
echo "Lumo 3D Android Build Diagnostics"
echo "════════════════════════════════════════════════════"

# ── 1. Godot Binary ────────────────────────────────────────────────────
VERSION_RAW=""
if [[ -x "$GODOT" ]]; then
    VERSION_RAW="$($GODOT --version 2>/dev/null | tr -d '\n' || true)"
    if [[ "$VERSION_RAW" == 4.6.* ]]; then
        step "PASS" "godot-binary" "$VERSION_RAW ($GODOT)"
    else
        step "WARN" "godot-binary" "Version $VERSION_RAW (erwartet 4.6.x)"
    fi
else
    step "FAIL" "godot-binary" "nicht gefunden bei $GODOT"
    next "GODOT_BIN env setzen oder Godot 4.6.3 nach /home/user/tools/ legen"
fi

# ── 2. Export-Templates ────────────────────────────────────────────────
VERSION_SHORT="$(echo "${VERSION_RAW:-4.6.3}" | cut -d. -f1-3).stable"
TPL_DIR="$HOME/.local/share/godot/export_templates/${VERSION_SHORT}"
if [[ -f "$TPL_DIR/android_release.apk" && -f "$TPL_DIR/android_debug.apk" ]]; then
    step "PASS" "export-templates" "$TPL_DIR (android_debug.apk + android_release.apk)"
else
    step "FAIL" "export-templates" "android_*.apk fehlen in $TPL_DIR"
    next "curl -L https://github.com/godotengine/godot/releases/download/${VERSION_SHORT}/Godot_v${VERSION_SHORT}_export_templates.tpz -o /tmp/godot_tpl.tpz && unzip /tmp/godot_tpl.tpz -d /tmp/tpl && mkdir -p $TPL_DIR && mv /tmp/tpl/templates/* $TPL_DIR/"
fi

# ── 3. Android Export-Preset ───────────────────────────────────────────
if grep -q '^name="Android"' "$ROOT/export_presets.cfg" 2>/dev/null; then
    step "PASS" "export-preset" "Android-Preset in export_presets.cfg"
else
    step "FAIL" "export-preset" "kein 'Android'-Preset"
    next "Android-Preset in export_presets.cfg anlegen (Vorlage in CLAUDE.md)"
fi

# ── 4a. JDK ────────────────────────────────────────────────────────────
if command -v java >/dev/null 2>&1; then
    JAVA_VER="$(java -version 2>&1 | head -1)"
    step "PASS" "jdk" "$JAVA_VER"
else
    step "FAIL" "jdk" "java nicht im PATH"
    next "apt install -y openjdk-17-jdk-headless"
fi

# ── 4b. keytool + jarsigner ────────────────────────────────────────────
if command -v keytool >/dev/null 2>&1; then
    step "PASS" "jdk-keytool" "$(which keytool)"
else
    step "FAIL" "jdk-keytool" "keytool nicht gefunden"
    next "JDK installieren - keytool gehoert dazu"
fi
if command -v jarsigner >/dev/null 2>&1; then
    step "PASS" "jdk-jarsigner" "$(which jarsigner)"
else
    step "WARN" "jdk-jarsigner" "jarsigner fehlt - APK-Signierung evtl. nicht moeglich"
    next "JDK mit Tools installieren: apt install -y openjdk-17-jdk-headless"
fi

# ── 5. ANDROID_HOME / ANDROID_SDK_ROOT ─────────────────────────────────
SDK_PATH="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -n "$SDK_PATH" && -d "$SDK_PATH" ]]; then
    step "PASS" "android-sdk-env" "ANDROID_HOME=$SDK_PATH"
else
    step "FAIL" "android-sdk-env" "ANDROID_HOME + ANDROID_SDK_ROOT unset oder ungueltig"
    next "Android SDK installieren (z.B. https://developer.android.com/studio#command-line-tools-only) und dann: export ANDROID_HOME=\$HOME/Android/Sdk; export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools"
fi

# ── 6a. sdkmanager ─────────────────────────────────────────────────────
if command -v sdkmanager >/dev/null 2>&1; then
    step "PASS" "android-sdkmanager" "$(which sdkmanager)"
elif [[ -n "$SDK_PATH" && -x "$SDK_PATH/cmdline-tools/latest/bin/sdkmanager" ]]; then
    step "PASS" "android-sdkmanager" "$SDK_PATH/cmdline-tools/latest/bin/sdkmanager"
else
    step "WARN" "android-sdkmanager" "nicht im PATH"
    next "sdkmanager liegt in \$ANDROID_HOME/cmdline-tools/latest/bin/ - PATH erweitern"
fi

# ── 6b. adb ────────────────────────────────────────────────────────────
ADB_BIN=""
if command -v adb >/dev/null 2>&1; then
    ADB_BIN="$(which adb)"
elif [[ -n "$SDK_PATH" && -x "$SDK_PATH/platform-tools/adb" ]]; then
    ADB_BIN="$SDK_PATH/platform-tools/adb"
fi
if [[ -n "$ADB_BIN" ]]; then
    step "PASS" "android-adb" "$ADB_BIN ($($ADB_BIN --version 2>&1 | head -1))"
else
    step "WARN" "android-adb" "adb fehlt - APK-Install auf Handy nicht moeglich"
    next "sdkmanager 'platform-tools' installieren"
fi

# ── 6c. apksigner ──────────────────────────────────────────────────────
APKSIGNER_BIN=""
if command -v apksigner >/dev/null 2>&1; then
    APKSIGNER_BIN="$(which apksigner)"
elif [[ -n "$SDK_PATH" ]]; then
    APKSIGNER_BIN="$(find "$SDK_PATH/build-tools" -name apksigner -type f 2>/dev/null | sort -V | tail -1)"
fi
if [[ -n "$APKSIGNER_BIN" && -x "$APKSIGNER_BIN" ]]; then
    step "PASS" "android-apksigner" "$APKSIGNER_BIN"
else
    step "WARN" "android-apksigner" "apksigner fehlt - APK-Validierung nicht moeglich"
    next "sdkmanager 'build-tools;34.0.0' installieren - bringt apksigner mit"
fi

# ── 7. Build-Tools Verzeichnis ─────────────────────────────────────────
if [[ -n "$SDK_PATH" && -d "$SDK_PATH/build-tools" ]]; then
    BT_LATEST="$(ls "$SDK_PATH/build-tools/" 2>/dev/null | sort -V | tail -1)"
    if [[ -n "$BT_LATEST" ]]; then
        step "PASS" "android-build-tools" "build-tools/$BT_LATEST"
    else
        step "WARN" "android-build-tools" "build-tools/ leer"
        next "sdkmanager 'build-tools;34.0.0'"
    fi
else
    step "WARN" "android-build-tools" "build-tools/ Verzeichnis fehlt"
fi

# ── 8. Platform-Tools Verzeichnis ─────────────────────────────────────
if [[ -n "$SDK_PATH" && -d "$SDK_PATH/platform-tools" ]]; then
    step "PASS" "android-platform-tools" "$SDK_PATH/platform-tools"
else
    step "WARN" "android-platform-tools" "platform-tools/ Verzeichnis fehlt"
    next "sdkmanager 'platform-tools'"
fi

# ── 9. Debug-Keystore ─────────────────────────────────────────────────
KS="$HOME/.android/debug.keystore"
if [[ -f "$KS" ]]; then
    step "PASS" "keystore" "$KS"
else
    step "WARN" "keystore" "Debug-Keystore fehlt"
    next "bash tools/setup_android_keystore.sh"
fi

echo "════════════════════════════════════════════════════"
echo "SUMMARY: $PASS_COUNT PASS / $WARN_COUNT WARN / $FAIL_COUNT FAIL"
echo "════════════════════════════════════════════════════"

if [[ $FAIL_COUNT -gt 0 || $WARN_COUNT -gt 0 ]]; then
    echo
    echo "NEXT STEPS (in dieser Reihenfolge):"
    for s in "${NEXT_STEPS[@]}"; do
        echo "  • $s"
    done
    if [[ $FAIL_COUNT -gt 0 ]]; then
        echo
        echo "RESULT: FAIL (kritische Luecken - kein APK-Build moeglich)"
        exit 1
    fi
    echo
    echo "RESULT: WARN (APK-Build aktuell nicht moeglich, Setup-Schritte oben)"
    exit 1
fi

# Alle PASS - echter Export-Versuch
echo
echo "Alle Checks PASS - versuche Android-Debug-Export..."
mkdir -p exports/android
"$GODOT" --headless --import 2>&1 | tail -3
"$GODOT" --headless --export-debug "Android" exports/android/lumo3d.apk 2>&1 | tee /tmp/build_android.log | tail -20

if [[ -f exports/android/lumo3d.apk ]]; then
    echo
    echo "RESULT: PASS - APK erzeugt: exports/android/lumo3d.apk"
    ls -lh exports/android/lumo3d.apk
    exit 0
fi
echo "RESULT: FAIL - Export-Befehl lief, aber APK nicht erzeugt (siehe /tmp/build_android.log)"
exit 1
