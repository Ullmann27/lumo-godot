#!/usr/bin/env bash
# Zwei Godot-Prozesse fahren über localhost (UDP 47630) ein „Zusammen fahren“-Rennen.
# 1) normales Rennen bis ins Ziel, 2) Gast bricht ab → Gastgeber fährt allein weiter.
# Zwei echte Geräte im WLAN prüft das nicht.
set -u
GODOT="${GODOT_BIN:-/home/user/tools/godot}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
cd "$(dirname "$0")/../.."
run() {
  timeout 240 "$GODOT" --headless --path . --script res://scripts/tests/kart_lan_two_process_test.gd -- "$@"
}
status=0
logs="$(mktemp -d)"
trap 'rm -rf "$logs"' EXIT
for pair in "host:client" "host drop:client_drop"; do
  host_args="${pair%%:*}"; client_args="${pair##*:}"
  run $host_args > "$logs/host.log" 2>&1 &
  host_pid=$!
  # Erst starten, wenn der Raum offen ist (unter Last braucht der Start viele Sekunden).
  for _ in $(seq 1 180); do
    grep -q 'Raumcode' "$logs/host.log" 2>/dev/null && break
    sleep 0.5
  done
  run $client_args > "$logs/client.log" 2>&1
  client_status=$?
  wait $host_pid
  host_status=$?
  grep -h '\[KartLan' "$logs/host.log" "$logs/client.log"
  grep -h 'ERROR' "$logs/host.log" "$logs/client.log" && status=1
  [[ $host_status -eq 0 && $client_status -eq 0 ]] || status=1
done
[[ $status -eq 0 ]] && echo "[KartLan] PASS: zwei Prozesse, Rennen + Abbruch" || echo "[KartLan] FAIL"
exit $status
