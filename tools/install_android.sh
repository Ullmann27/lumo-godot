#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────
# install_android.sh - APK auf das angeschlossene Android-Geraet
#   installieren via `adb install -r`.
# ────────────────────────────────────────────────────────────────────────
#
# Verhalten:
#   1. Detektiert adb (PATH, ANDROID_HOME/platform-tools, ~/Android/Sdk)
#   2. Listet angeschlossene Geraete:
#      - 0 Geraete:    Hinweis zu USB-Debugging
#      - 1 Geraet:     installiert lumo3d-debug.apk via -r
#      - >1 Geraete:   listet IDs, Anweisung "ADB_SERIAL=<id> bash ..."
#   3. Bei Erfolg: Hinweis zum Logcat-Helper
#
# Optionen:
#   --apk <pfad>   alternative APK-Datei (default: exports/android/lumo3d-debug.apk)
#   --serial <id>  zwingt auf bestimmtes Geraet (alternativ ADB_SERIAL env)
#   --help         diese Hilfe
#
# Exit-Codes:
#   0  Installation erfolgreich
#   1  Fehlende Voraussetzungen / Geraet / APK
# ────────────────────────────────────────────────────────────────────────
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APK="exports/android/lumo3d-debug.apk"
SERIAL="${ADB_SERIAL:-}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --apk) APK="$2"; shift 2 ;;
        --serial) SERIAL="$2"; shift 2 ;;
        --help|-h)
            awk '/^[^#]/ { exit } { print }' "$0" | sed 's/^#\s\{0,1\}//'
            exit 0
            ;;
        *) echo "[install_android] unbekannte Option: $1"; exit 1 ;;
    esac
done

# adb finden
ADB="${ADB:-}"
if [[ -z "$ADB" ]]; then
    if command -v adb >/dev/null 2>&1; then
        ADB="$(command -v adb)"
    else
        for cand in "${ANDROID_HOME:-}/platform-tools/adb" \
                    "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
                    "$HOME/Android/Sdk/platform-tools/adb" \
                    "/opt/android-sdk/platform-tools/adb"; do
            if [[ -x "$cand" ]]; then ADB="$cand"; break; fi
        done
    fi
fi

if [[ -z "$ADB" || ! -x "$ADB" ]]; then
    echo "[install_android] FAIL: adb nicht gefunden"
    echo "  -> Setze \$ANDROID_HOME und stelle sicher dass \$ANDROID_HOME/platform-tools/adb existiert"
    echo "  -> Oder installiere via 'sdkmanager platform-tools'"
    exit 1
fi
echo "[install_android] adb: $ADB"

if [[ ! -f "$APK" ]]; then
    echo "[install_android] FAIL: APK nicht gefunden: $APK"
    echo "  -> Erst 'bash tools/build_android.sh' laufen lassen"
    exit 1
fi
APK_SIZE="$(ls -lh "$APK" | awk '{print $5}')"
echo "[install_android] APK: $APK ($APK_SIZE)"

# Geraeteliste holen
"$ADB" start-server >/dev/null 2>&1 || true
DEVICES_RAW="$("$ADB" devices | tail -n +2 | grep -v '^\s*$' || true)"
DEVICE_COUNT="$(echo "$DEVICES_RAW" | grep -c 'device$' || true)"

if [[ -z "$DEVICES_RAW" || "$DEVICE_COUNT" -eq 0 ]]; then
    echo "[install_android] FAIL: kein Android-Geraet angeschlossen"
    echo
    echo "  Pruefe:"
    echo "  1. USB-Kabel verbunden (KEIN reines Ladekabel)"
    echo "  2. Auf dem Handy: Einstellungen > Ueber das Telefon"
    echo "     -> 7x auf Build-Nummer tippen (Entwickleroptionen freischalten)"
    echo "  3. Einstellungen > Entwickleroptionen > USB-Debugging AN"
    echo "  4. Beim Erstverbinden den USB-Debugging-Dialog auf dem Handy bestaetigen"
    echo "  5. '$ADB devices' nochmal pruefen"
    exit 1
fi

if [[ "$DEVICE_COUNT" -gt 1 && -z "$SERIAL" ]]; then
    echo "[install_android] FAIL: $DEVICE_COUNT Geraete angeschlossen"
    echo "$DEVICES_RAW"
    echo
    echo "  Waehle eines via: ADB_SERIAL=<id> bash tools/install_android.sh"
    echo "  Oder:             bash tools/install_android.sh --serial <id>"
    exit 1
fi

ADB_ARGS=()
if [[ -n "$SERIAL" ]]; then
    ADB_ARGS+=("-s" "$SERIAL")
fi

echo
echo "[install_android] installiere..."
"$ADB" "${ADB_ARGS[@]}" install -r "$APK"
INSTALL_EXIT=$?

if [[ $INSTALL_EXIT -ne 0 ]]; then
    echo "[install_android] FAIL: adb install Exit $INSTALL_EXIT"
    exit 1
fi

echo
echo "[install_android] DONE."
echo "  Starte die App 'Lumo 3D' auf dem Handy."
echo "  Logs ansehen: bash tools/logcat_lumo.sh"
exit 0
