#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────
# logcat_lumo.sh - gefiltertes adb logcat fuer Lumo 3D + Mitschrift.
# ────────────────────────────────────────────────────────────────────────
#
# Verhalten:
#   1. Detektiert adb
#   2. Setzt logcat auf einen Filter der Godot/Lumo/Crash-relevante Tags
#      und Texte einfaengt
#   3. Schreibt parallel in exports/android/logcat_lumo_YYYYMMDD_HHMMSS.txt
#   4. Strg+C beendet sauber, Datei bleibt
#
# Optionen:
#   --serial <id>  Zielgeraet (alternativ ADB_SERIAL env)
#   --clear        adb logcat -c vor Start (alten Buffer leeren)
#   --help         diese Hilfe
#
# Filter (case-insensitive grep):
#   Godot, Lumo, ERROR, FATAL, ANR, Vulkan, OpenGL, Audio, Input,
#   AndroidRuntime
# ────────────────────────────────────────────────────────────────────────
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SERIAL="${ADB_SERIAL:-}"
CLEAR_BUFFER="false"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --serial) SERIAL="$2"; shift 2 ;;
        --clear) CLEAR_BUFFER="true"; shift ;;
        --help|-h)
            awk '/^[^#]/ { exit } { print }' "$0" | sed 's/^#\s\{0,1\}//'
            exit 0
            ;;
        *) echo "[logcat_lumo] unbekannte Option: $1"; exit 1 ;;
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
                    "$HOME/Android/Sdk/platform-tools/adb"; do
            if [[ -x "$cand" ]]; then ADB="$cand"; break; fi
        done
    fi
fi

if [[ -z "$ADB" || ! -x "$ADB" ]]; then
    echo "[logcat_lumo] FAIL: adb nicht gefunden"
    echo "  -> ANDROID_HOME setzen + platform-tools installieren"
    exit 1
fi

ADB_ARGS=()
if [[ -n "$SERIAL" ]]; then
    ADB_ARGS+=("-s" "$SERIAL")
fi

# Geraet vorhanden?
DEVICE_COUNT="$("$ADB" "${ADB_ARGS[@]}" devices 2>/dev/null | tail -n +2 | grep -c 'device$' || true)"
if [[ "$DEVICE_COUNT" -eq 0 ]]; then
    echo "[logcat_lumo] FAIL: kein Android-Geraet"
    echo "  -> USB-Kabel + USB-Debugging pruefen"
    exit 1
fi

mkdir -p exports/android
TS="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="exports/android/logcat_lumo_${TS}.txt"

if [[ "$CLEAR_BUFFER" == "true" ]]; then
    echo "[logcat_lumo] adb logcat -c (Buffer leeren)..."
    "$ADB" "${ADB_ARGS[@]}" logcat -c
fi

FILTER='Godot|Lumo|ERROR|FATAL|ANR|Vulkan|OpenGL|Audio|Input|AndroidRuntime'

echo "[logcat_lumo] start - Filter: $FILTER"
echo "[logcat_lumo] log -> $LOG_FILE"
echo "[logcat_lumo] Strg+C zum Beenden"
echo

# logcat -v threadtime fuer Zeitstempel + TID. Pipe durch grep -E -i
# fuer den Filter und durch tee in die Logdatei.
"$ADB" "${ADB_ARGS[@]}" logcat -v threadtime 2>&1 \
    | grep -iE --line-buffered "$FILTER" \
    | tee "$LOG_FILE"
