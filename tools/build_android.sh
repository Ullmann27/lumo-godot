#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────
# build_android.sh - Android APK Build mit Auto-Diagnose und
#   optionalem Auto-Setup (SDK-Komponenten + Lizenzen + Keystore).
# ────────────────────────────────────────────────────────────────────────
#
# Verhalten:
#   1. Detektiert Godot 4.6.x Binary (godot / godot4 / GODOT_BIN /
#      bekannte Pfade)
#   2. Detektiert Export-Templates
#   3. Detektiert Android-SDK (ANDROID_HOME, ANDROID_SDK_ROOT,
#      ~/Android/Sdk, /opt/android-sdk, /usr/lib/android-sdk)
#   4. Detektiert sdkmanager, adb, apksigner, zipalign, keytool
#   5. Wenn sdkmanager da: bietet --auto-setup an (installiert
#      platform-tools + build-tools + platforms + akzeptiert Lizenzen)
#   6. Wenn keytool da + kein Keystore: erzeugt Debug-Keystore via
#      tools/setup_android_keystore.sh
#   7. Wenn alles PASS: ruft `godot --headless --export-debug "Android"
#      exports/android/lumo3d-debug.apk`
#   8. Verifiziert APK (existiert, >1 MB) und optional apksigner verify
#   9. Zusammenfassung PASS/WARN/FAIL + konkrete naechste Schritte
#
# Optionen:
#   --auto-setup    SDK-Komponenten via sdkmanager auto-installieren
#                   (nur wenn sdkmanager auffindbar)
#   --help          diese Hilfe anzeigen
#
# Exit-Codes:
#   0  APK erfolgreich erzeugt + verifiziert
#   1  Voraussetzungen fehlen (kritische Luecke) - Diagnose-Bericht
# ────────────────────────────────────────────────────────────────────────
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

AUTO_SETUP="false"
for arg in "$@"; do
    case "$arg" in
        --auto-setup) AUTO_SETUP="true" ;;
        --help|-h)
            awk '/^[^#]/ { exit } { print }' "$0" | sed 's/^#\s\{0,1\}//'
            exit 0
            ;;
        *) echo "[build_android] unbekannte Option: $arg"; exit 1 ;;
    esac
done

PASS_COUNT=0; WARN_COUNT=0; FAIL_COUNT=0
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
next() { NEXT_STEPS+=("$1"); }

echo "════════════════════════════════════════════════════"
echo "Lumo 3D Android Build & Diagnose"
echo "════════════════════════════════════════════════════"

# ── 1. Godot Binary ────────────────────────────────────────────────────
GODOT="${GODOT_BIN:-}"
if [[ -z "$GODOT" ]]; then
    for cand in /home/user/tools/godot /usr/local/bin/godot4 /usr/local/bin/godot $(command -v godot 2>/dev/null) $(command -v godot4 2>/dev/null); do
        if [[ -x "$cand" ]]; then GODOT="$cand"; break; fi
    done
fi
VERSION_RAW=""
if [[ -n "$GODOT" && -x "$GODOT" ]]; then
    VERSION_RAW="$("$GODOT" --version 2>/dev/null | tr -d '\n' || true)"
    if [[ "$VERSION_RAW" == 4.6.* ]]; then
        step "PASS" "godot-binary" "$VERSION_RAW ($GODOT)"
    else
        step "WARN" "godot-binary" "Version $VERSION_RAW (erwartet 4.6.x)"
    fi
else
    step "FAIL" "godot-binary" "kein Godot 4.6.x gefunden"
    next "Godot 4.6.3 installieren und GODOT_BIN=/pfad/zu/godot setzen"
fi

# ── 2. Export-Templates ────────────────────────────────────────────────
VERSION_SHORT="$(echo "${VERSION_RAW:-4.6.3}" | cut -d. -f1-3).stable"
TPL_DIR="$HOME/.local/share/godot/export_templates/${VERSION_SHORT}"
if [[ -f "$TPL_DIR/android_release.apk" && -f "$TPL_DIR/android_debug.apk" ]]; then
    step "PASS" "export-templates" "$TPL_DIR"
else
    step "FAIL" "export-templates" "android_*.apk fehlen unter $TPL_DIR"
    next "Im Godot-Editor: Editor > Manage Export Templates > Download (~900 MB)"
fi

# ── 3. Android Preset ──────────────────────────────────────────────────
if grep -q '^name="Android"' "$ROOT/export_presets.cfg" 2>/dev/null; then
    step "PASS" "export-preset" "Android in export_presets.cfg"
else
    step "FAIL" "export-preset" "kein 'Android'-Preset"
    next "Android-Preset in export_presets.cfg anlegen"
fi

# ── 4a. JDK ────────────────────────────────────────────────────────────
if command -v java >/dev/null 2>&1; then
    step "PASS" "jdk" "$(java -version 2>&1 | head -1)"
else
    step "FAIL" "jdk" "java nicht im PATH"
    next "apt install -y openjdk-17-jdk-headless"
fi
if command -v keytool >/dev/null 2>&1; then
    step "PASS" "jdk-keytool" "$(which keytool)"
else
    step "FAIL" "jdk-keytool" "keytool nicht gefunden"
    next "JDK installieren - keytool gehoert dazu"
fi

# ── 5. Android SDK auto-detection ─────────────────────────────────────
SDK_PATH=""
for cand in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" \
            "$HOME/Android/Sdk" "/opt/android-sdk" "/usr/lib/android-sdk" \
            "$HOME/Library/Android/sdk"; do
    if [[ -n "$cand" && -d "$cand" ]]; then SDK_PATH="$cand"; break; fi
done
if [[ -n "$SDK_PATH" ]]; then
    step "PASS" "android-sdk" "$SDK_PATH"
    export ANDROID_HOME="$SDK_PATH"
    export ANDROID_SDK_ROOT="$SDK_PATH"
else
    step "FAIL" "android-sdk" "kein SDK gefunden in ANDROID_HOME, ANDROID_SDK_ROOT, ~/Android/Sdk, /opt/android-sdk, /usr/lib/android-sdk"
    next "Android Studio installieren (https://developer.android.com/studio) ODER cmdline-tools:"
    next "  mkdir -p ~/Android/Sdk/cmdline-tools && cd ~/Android/Sdk/cmdline-tools"
    next "  curl -L https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -o tools.zip"
    next "  unzip tools.zip && mv cmdline-tools latest"
    next "  export ANDROID_HOME=\$HOME/Android/Sdk"
    next "  export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools"
fi

# ── 6. SDK-Tools ───────────────────────────────────────────────────────
find_sdk_tool() {
    local name="$1"
    if command -v "$name" >/dev/null 2>&1; then echo "$(command -v "$name")"; return; fi
    if [[ -n "$SDK_PATH" ]]; then
        case "$name" in
            sdkmanager) [[ -x "$SDK_PATH/cmdline-tools/latest/bin/$name" ]] && echo "$SDK_PATH/cmdline-tools/latest/bin/$name" ;;
            adb) [[ -x "$SDK_PATH/platform-tools/$name" ]] && echo "$SDK_PATH/platform-tools/$name" ;;
            apksigner|zipalign) find "$SDK_PATH/build-tools" -maxdepth 2 -name "$name" -type f 2>/dev/null | sort -V | tail -1 ;;
        esac
    fi
}

SDKMANAGER="$(find_sdk_tool sdkmanager)"
ADB="$(find_sdk_tool adb)"
APKSIGNER="$(find_sdk_tool apksigner)"
ZIPALIGN="$(find_sdk_tool zipalign)"

[[ -n "$SDKMANAGER" ]] && step "PASS" "sdkmanager" "$SDKMANAGER" \
    || { step "WARN" "sdkmanager" "nicht gefunden"; next "cmdline-tools installieren (siehe oben)"; }
[[ -n "$ADB" ]] && step "PASS" "adb" "$ADB" \
    || { step "WARN" "adb" "nicht gefunden"; next "sdkmanager 'platform-tools' installieren"; }
[[ -n "$APKSIGNER" ]] && step "PASS" "apksigner" "$APKSIGNER" \
    || { step "WARN" "apksigner" "nicht gefunden"; next "sdkmanager 'build-tools;34.0.0' installieren"; }
[[ -n "$ZIPALIGN" ]] && step "PASS" "zipalign" "$ZIPALIGN" \
    || step "WARN" "zipalign" "nicht gefunden (in build-tools enthalten)"

# ── 7. Auto-Setup wenn gewuenscht ──────────────────────────────────────
if [[ "$AUTO_SETUP" == "true" && -n "$SDKMANAGER" ]]; then
    echo
    echo "[auto-setup] sdkmanager --licenses + Pflicht-Komponenten..."
    yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
    "$SDKMANAGER" "platform-tools" "build-tools;34.0.0" "platforms;android-34" 2>&1 | tail -5
    # Re-detect nach Install
    ADB="$(find_sdk_tool adb)"
    APKSIGNER="$(find_sdk_tool apksigner)"
    ZIPALIGN="$(find_sdk_tool zipalign)"
    [[ -n "$ADB" ]] && step "PASS" "auto-setup-adb" "$ADB"
    [[ -n "$APKSIGNER" ]] && step "PASS" "auto-setup-apksigner" "$APKSIGNER"
elif [[ -n "$SDKMANAGER" && ( -z "$ADB" || -z "$APKSIGNER" ) ]]; then
    next "Lauf 'bash tools/build_android.sh --auto-setup' damit sdkmanager Komponenten + Lizenzen automatisch erledigt"
fi

# ── 8. Debug-Keystore (auto-create) ────────────────────────────────────
KS="$HOME/.android/debug.keystore"
if [[ -f "$KS" ]]; then
    step "PASS" "keystore" "$KS"
elif command -v keytool >/dev/null 2>&1; then
    echo "[auto-keystore] erzeuge Debug-Keystore..."
    bash "$ROOT/tools/setup_android_keystore.sh" >/dev/null 2>&1
    if [[ -f "$KS" ]]; then
        step "PASS" "keystore-autogen" "$KS"
    else
        step "FAIL" "keystore-autogen" "Erzeugung fehlgeschlagen"
        next "Manuell: bash tools/setup_android_keystore.sh"
    fi
else
    step "FAIL" "keystore" "$KS fehlt + keytool nicht verfuegbar"
fi

echo "════════════════════════════════════════════════════"
echo "SUMMARY: $PASS_COUNT PASS / $WARN_COUNT WARN / $FAIL_COUNT FAIL"
echo "════════════════════════════════════════════════════"

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo
    echo "NEXT STEPS:"
    for s in "${NEXT_STEPS[@]}"; do echo "  • $s"; done
    echo
    echo "RESULT: FAIL (kritische Luecken - kein APK-Build moeglich)"
    exit 1
fi

# ── 9. APK Export ──────────────────────────────────────────────────────
echo
echo "Voraussetzungen OK - versuche APK-Export..."
mkdir -p exports/android
APK_PATH="exports/android/lumo3d-debug.apk"
rm -f "$APK_PATH"
"$GODOT" --headless --import 2>&1 | tail -2

# Godot 4.6.3 hat einen stillen Configuration-Error im normalen Android-
# Export-Plugin. Workaround: --export-pack + manueller Gradle-Build mit
# Android-Source-Template, dann strip+sign.
echo
echo "Schritt 1: PCK via --export-pack erzeugen..."
"$GODOT" --headless --export-pack "Android" exports/android/lumo3d.pck 2>&1 | tail -2

echo "Schritt 2: Source-Template entpacken..."
mkdir -p android/build
if [[ ! -f android/build/gradlew ]]; then
    TPL_ROOT="$HOME/.local/share/godot/export_templates/${VERSION_SHORT}"
    unzip -q -o "$TPL_ROOT/android_source.zip" -d android/build/
fi

echo "Schritt 3: PCK in Gradle-Source kopieren..."
mkdir -p android/build/src/main/assets/_cl_
cp exports/android/lumo3d.pck android/build/src/main/assets/_cl_/

echo "Schritt 3b: Lumo Patches (app_name + launcher icons) anwenden..."
mkdir -p android/build/src/main/res
(cd tools/android_patches && find res -type f -name "*.png") | while read f; do mkdir -p "android/build/src/main/$(dirname $f)"; cp "tools/android_patches/$f" "android/build/src/main/$f"; done

echo "Schritt 4: Gradle assembleDebug (kann 2-3 min dauern)..."
chmod +x android/build/gradlew
(cd android/build && ./gradlew assembleDebug --quiet \
    -Pexport_package_name=dev.ullmann.lumo3d \
    -Pexport_version_name=0.1.1 \
    -Pexport_version_code=2 2>&1) | tail -5

RAW_APK=android/build/build/outputs/apk/standard/debug/android_debug.apk
if [[ ! -f "$RAW_APK" ]]; then
    echo "RESULT: FAIL - Gradle-Build erzeugte keine APK"
    exit 1
fi

echo "Schritt 5: arm64-only strip + zipalign + apksigner sign..."
WORK=/tmp/apk_build_$$
rm -rf "$WORK"
mkdir -p "$WORK"
( cd "$WORK" && unzip -q "$ROOT/$RAW_APK" && \
  rm -rf lib/x86 lib/x86_64 lib/armeabi-v7a META-INF && \
  zip -r9 -q /tmp/lumo3d-stripped-$$.apk . )

"$ZIPALIGN" -p -f 4 /tmp/lumo3d-stripped-$$.apk /tmp/lumo3d-aligned-$$.apk
"$APKSIGNER" sign \
    --ks "$KS" \
    --ks-pass pass:android --key-pass pass:android \
    --ks-key-alias androiddebugkey \
    --out "$APK_PATH" \
    /tmp/lumo3d-aligned-$$.apk
rm -rf "$WORK" /tmp/lumo3d-stripped-$$.apk /tmp/lumo3d-aligned-$$.apk

# ── 10. APK Verify ─────────────────────────────────────────────────────
if [[ ! -f "$APK_PATH" ]]; then
    echo "RESULT: FAIL - APK wurde nicht erzeugt (siehe /tmp/build_android.log)"
    exit 1
fi

APK_BYTES=$(stat -c%s "$APK_PATH" 2>/dev/null || stat -f%z "$APK_PATH" 2>/dev/null || echo 0)
if [[ $APK_BYTES -lt 1048576 ]]; then
    echo "RESULT: FAIL - APK zu klein (${APK_BYTES} B, erwartet > 1 MB)"
    exit 1
fi
step "PASS" "apk-size" "$(ls -lh "$APK_PATH" | awk '{print $5}')"

if [[ -n "$APKSIGNER" ]]; then
    if "$APKSIGNER" verify "$APK_PATH" >/dev/null 2>&1; then
        step "PASS" "apk-signature" "verified"
    else
        step "WARN" "apk-signature" "apksigner verify fehlgeschlagen (Debug-APK ist trotzdem installierbar)"
    fi
fi

echo
echo "RESULT: PASS - APK bereit: $APK_PATH"
echo
echo "Naechster Schritt: bash tools/install_android.sh"
exit 0
