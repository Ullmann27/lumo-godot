#!/usr/bin/env bash
# Netzbasis mit echten Godot-Prozessen über ENet auf 127.0.0.1:
#   Autorität (host) + Gast a + Gast b (+ KI auf Platz 4). Gast b endet nach 5 s hart
#   (Prozess weg, keine Abmeldung); ein NEUER Prozess kommt mit der Platzkarte zurück.
# Geprüft: alle sehen dieselben Ereignisse, jedes Gerät bucht genau einmal, gleicher Platz.
# Das ist „PASS LOKAL (mehrere Prozesse, Loopback)“ – NICHT zwei Geräte im WLAN.
set -u
GODOT="${GODOT_BIN:-/home/user/tools/godot}"
cd "$(dirname "$0")/../.."
work="${LUMO_NET_WORK:-$(mktemp -d)}"
mkdir -p "$work"
port="$(python3 -c 'import socket;s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.bind(("127.0.0.1",0));print(s.getsockname()[1])')"
run() {  # name, args...
  local name="$1"; shift
  mkdir -p "$work/xdg_$name"
  XDG_DATA_HOME="$work/xdg_$name" timeout 300 "$GODOT" --headless --path . \
    --script res://scripts/tests/lumo_net_multi_process_test.gd -- "$@" > "$work/$name.log" 2>&1
}
run host host "$port" "$work" & host_pid=$!
for _ in $(seq 1 240); do grep -q 'Raum offen auf Port' "$work/host.log" 2>/dev/null && break; sleep 0.5; done
run a guest "$port" "$work" a & a_pid=$!
run b drop "$port" "$work" b; drop_status=$?
run b2 resume "$port" "$work" b & b2_pid=$!
wait $a_pid; a_status=$?
wait $b2_pid; b2_status=$?
wait $host_pid; host_status=$?
grep -h '\[LumoNetMP' "$work/host.log" "$work/a.log" "$work/b.log" "$work/b2.log"
status=0
if grep -h 'ERROR\|SCRIPT ERROR' "$work"/*.log; then status=1; fi
for s in $host_status $a_status $drop_status $b2_status; do [[ $s -eq 0 ]] || status=1; done
python3 - "$work" <<'EOF' || status=1
import json, sys, os
w = sys.argv[1]
r = {n: json.load(open(os.path.join(w, n + ".json"))) for n in ("host", "a", "b")}
ok = r["host"]["events"] == r["a"]["events"] == r["b"]["events"]
eids = [e.split(":")[0] for e in r["host"]["events"]]
ok &= len(eids) == len(set(eids))
ok &= all(len(r[n]["booked"]) == 1 for n in r)
ok &= len({r[n]["booked"][0][0] for n in r}) == 1
places = sorted(r[n]["booked"][0][1] for n in r)
ok &= len(set(places)) == 3
print("[LumoNetMP] Vergleich: Ereignisse %d/%d/%d gleich=%s, Buchungen %s, Plätze %s"
      % (len(r["host"]["events"]), len(r["a"]["events"]), len(r["b"]["events"]),
         r["host"]["events"] == r["a"]["events"] == r["b"]["events"],
         [len(r[n]["booked"]) for n in r], places))
sys.exit(0 if ok else 1)
EOF
[[ $status -eq 0 ]] && echo "[LumoNetMP] PASS: vier Prozesse (Autorität, 2 Gäste, Neustart), Loopback" || echo "[LumoNetMP] FAIL (Logs: $work)"
exit $status
