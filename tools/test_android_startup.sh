#!/usr/bin/env bash
# Install the universal APK on an already booted emulator and verify real startup.
# Usage: ADB_SERIAL=emulator-5554 bash tools/test_android_startup.sh path/to/app.apk
set -Eeuo pipefail

lumo_apk=${1:-exports/android/lumo3d-debug.apk}
if [[ "$lumo_apk" != /* ]]; then lumo_apk="$PWD/$lumo_apk"; fi
lumo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$lumo_root"
lumo_package=dev.ullmann.lumo3d
lumo_log="$lumo_root/exports/android/android-startup.log"
mkdir -p "$(dirname "$lumo_log")"
: > "$lumo_log"
lumo_capture=$(mktemp "${lumo_log}.logcat.XXXXXX")

finish() {
    local status=$?
    if [[ -s "$lumo_capture" ]]; then
        printf '\n[AndroidStartup] Captured logcat\n' >> "$lumo_log"
        cat "$lumo_capture" >> "$lumo_log"
    fi
    rm -f "$lumo_capture"
    if (( status != 0 )); then
        printf '[AndroidStartup] Diagnostics: %s\n' "$lumo_log" >&2
        cat "$lumo_log" >&2
    fi
}
trap finish EXIT

fail() {
    printf '[AndroidStartup] FAIL: %s\n' "$*" | tee -a "$lumo_log" >&2
    exit 1
}

lumo_adb=${ADB:-}
if [[ -z "$lumo_adb" ]]; then
    lumo_adb=$(command -v adb || true)
fi
if [[ -z "$lumo_adb" ]]; then
    for candidate in "${ANDROID_HOME:-}/platform-tools/adb" "${ANDROID_SDK_ROOT:-}/platform-tools/adb"; do
        if [[ -x "$candidate" ]]; then lumo_adb=$candidate; break; fi
    done
fi
[[ -n "$lumo_adb" && -x "$lumo_adb" ]] || fail "adb not found"
[[ -f "$lumo_apk" ]] || fail "APK not found: $lumo_apk"
lumo_adb_args=()
lumo_serial=${ADB_SERIAL:-${ANDROID_SERIAL:-}}
if [[ -n "$lumo_serial" ]]; then lumo_adb_args=(-s "$lumo_serial"); fi
adb_cmd() { timeout 15s "$lumo_adb" "${lumo_adb_args[@]}" "$@"; }

printf '[AndroidStartup] APK: %s\n' "$lumo_apk" | tee -a "$lumo_log"
adb_cmd get-state >> "$lumo_log" 2>&1 || fail "Android device is unavailable or ambiguous"
{
    printf '[AndroidStartup] APK bytes: %s\n' "$(wc -c < "$lumo_apk")"
    for property in ro.build.version.sdk ro.product.cpu.abilist ro.product.cpu.abi; do
        printf '[AndroidStartup] %s: ' "$property"
        adb_cmd shell getprop "$property" || true
    done
    printf '[AndroidStartup] Android /data free space:\n'
    adb_cmd shell df -h /data || true
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$lumo_apk" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    abis = sorted({name.split('/')[1] for name in archive.namelist()
                   if name.startswith('lib/') and name.endswith('.so')})
    print('[AndroidStartup] Packaged native ABIs: ' + (', '.join(abis) or '(none)'))
PY
    fi
    lumo_aapt=${AAPT:-$(command -v aapt || true)}
    if [[ -z "$lumo_aapt" ]]; then
        for candidate in "${ANDROID_HOME:-}"/build-tools/*/aapt "${ANDROID_SDK_ROOT:-}"/build-tools/*/aapt; do
            if [[ -x "$candidate" ]]; then lumo_aapt=$candidate; fi
        done
    fi
    if [[ -n "$lumo_aapt" && -x "$lumo_aapt" ]]; then
        "$lumo_aapt" dump badging "$lumo_apk" 2>&1 | \
            grep -E '^(package:|sdkVersion:|targetSdkVersion:|native-code:)' || true
    fi
} 2>&1 | tee -a "$lumo_log"
if ! timeout 60s "$lumo_adb" "${lumo_adb_args[@]}" install --no-incremental -r "$lumo_apk" 2>&1 | tee -a "$lumo_log"; then
    fail "adb install failed; see install output in the log"
fi
adb_cmd shell am force-stop "$lumo_package" >> "$lumo_log" 2>&1 || fail "Could not stop previous app instance"
adb_cmd logcat -c >> "$lumo_log" 2>&1 || fail "Could not clear logcat"
lumo_resolved=$(adb_cmd shell cmd package resolve-activity --brief \
    -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$lumo_package" 2>&1) \
    || fail "Launcher activity resolution failed"
printf '%s\n' "$lumo_resolved" >> "$lumo_log"
lumo_activity=$(printf '%s\n' "$lumo_resolved" | tr -d '\r' | \
    awk '/^dev\.ullmann\.lumo3d\/[^[:space:]]+$/ { component=$0 } END { print component }')
[[ -n "$lumo_activity" ]] || fail "No MAIN/LAUNCHER activity found for $lumo_package"
printf '[AndroidStartup] Launcher: %s\n' "$lumo_activity" | tee -a "$lumo_log"
if ! adb_cmd shell am start -W -a android.intent.action.MAIN \
    -c android.intent.category.LAUNCHER -n "$lumo_activity" >> "$lumo_log" 2>&1; then
    fail "Android rejected activity launch"
fi
if grep -Eiq 'Error:|Permission Denial|SecurityException|unable to resolve|does not exist|Status: (error|timeout)' "$lumo_log"; then
    fail "Activity launch was denied or failed"
fi

capture_logcat() {
    adb_cmd logcat -d -v threadtime > "$lumo_capture" 2>&1 || fail "Could not capture logcat"
    local error_pattern="Couldn.t load project|Could not load.*(project|main pack)|Failed.*(main pack|project\.binary|\.pck)|FATAL EXCEPTION|Fatal signal|SIGSEGV|SIGABRT|SCRIPT ERROR|Parse Error|godot[[:space:]]*:.*ERROR:"
    if grep -Eiq "$error_pattern" "$lumo_capture"; then
        grep -Ein "$error_pattern" "$lumo_capture" | head -12 >&2 || true
        fail "Project loading, script, Java or native crash detected"
    fi
}

lumo_deadline=$((SECONDS + 60))
lumo_started=0
while (( SECONDS < lumo_deadline )); do
    capture_logcat
    if grep -Fq '[Boot] starting' "$lumo_capture" \
        && grep -Eq '\[Router\] goto:(games|home|kart|jump)[[:space:]]' "$lumo_capture" \
        && grep -Eq '\[Lumo\] (character|companion)_ready' "$lumo_capture"; then
        adb_cmd shell pidof "$lumo_package" >> "$lumo_log" 2>&1 || fail "App exited after boot markers"
        lumo_started=1
        break
    fi
    sleep 2
done
(( lumo_started == 1 )) || fail "Boot, route and loaded-character markers were not all observed within 60 seconds"
sleep 2
capture_logcat
lumo_pid=$(adb_cmd shell pidof "$lumo_package" | tr -d '\r') || fail "App crashed or exited after startup"
[[ "$lumo_pid" =~ ^[0-9]+([[:space:]][0-9]+)*$ ]] || fail "No live app process after startup"
printf '[AndroidStartup] PASS: Boot + scene route + Lumo ready; process %s remains alive. Log: %s\n' \
    "$lumo_pid" "$lumo_log" | tee -a "$lumo_log"

# Exercise the actual game route and its portrait-to-landscape startup, too.
cat "$lumo_capture" >> "$lumo_log"
adb_cmd shell am force-stop "$lumo_package" >> "$lumo_log" 2>&1 || fail "Could not stop menu instance"
adb_cmd logcat -c >> "$lumo_log" 2>&1 || fail "Could not clear route logcat"
printf '[AndroidStartup] Launch direct kart route\n' | tee -a "$lumo_log"
adb_cmd shell am start -W -a android.intent.action.VIEW -p "$lumo_package" \
    -d 'lumo3d://kart?grade=2' >> "$lumo_log" 2>&1 || fail "Android rejected kart route"
lumo_deadline=$((SECONDS + 60))
lumo_started=0
while (( SECONDS < lumo_deadline )); do
    capture_logcat
    if grep -Fq '[Kart] ready: Sonnenhafen' "$lumo_capture" \
        && grep -Eq '\[Router\] goto:kart[[:space:]]' "$lumo_capture"; then
        lumo_started=1
        break
    fi
    sleep 2
done
(( lumo_started == 1 )) || fail "Direct kart route did not initialize within 60 seconds"
lumo_deadline=$((SECONDS + 40))
lumo_frame_ready=0
while (( SECONDS < lumo_deadline )); do
    capture_logcat
    adb_cmd shell pidof "$lumo_package" >> "$lumo_log" 2>&1 || fail "Kart exited after orientation change"
    adb_cmd exec-out screencap -p > "$lumo_root/exports/android/sonnenhafen-android-start.png" \
        || fail "Could not capture running Android race"
    if python3 tools/check_android_frame.py "$lumo_root/exports/android/sonnenhafen-android-start.png" >> "$lumo_log" 2>&1; then
        lumo_frame_ready=1
        break
    fi
    sleep 2
done
(( lumo_frame_ready == 1 )) || fail "Android race remained black or clipped after landscape transition"
printf '[AndroidStartup] PASS: direct kart route initialized and remained alive after orientation change\n' \
    | tee -a "$lumo_log"
