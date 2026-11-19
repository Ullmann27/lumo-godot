extends RefCounted
## Spielstand eines privaten Raums – läuft NUR bei der Autorität (im WLAN: Gastgeber-Gerät,
## später ein Server). Rein: keine Netzwerk-, Knoten- oder Wanduhr-Abhängigkeit; die Uhr
## (`now`, Sekunden der Autorität) wird bei jedem Aufruf übergeben.
##
## Die Autorität entscheidet allein über: Platzvergabe (2–4 Plätze, KI füllt freie),
## Checkpoints (nur der nächste, mit Mindestabstand, Zeitstempel in engem Fenster um die eigene
## Uhr), Item-Ziehung (genau einmal je Platz/Runde/Zone, über einen übergebenen Zieher –
## im Kart: `kart_item_catalog.roll`), Item-Einsatz (nur das gehaltene Item), Zieleinlauf,
## Ergebnis. Jedes Ereignis bekommt eine fortlaufende Nummer n und eine raumweit eindeutige
## Kennung eid („<raum>_<n>“), über die Geräte Belohnungen genau einmal buchen.

const WIRE = preload("res://scripts/games/net/lumo_net_wire.gd")

## Fahrer-Kennungen aus kart_catalog.DRIVERS (die KI nimmt die echten Mitspieler-Figuren).
const AI_DRIVERS: Array[String] = ["rabbit", "otter", "frog", "fox"]

var config: Dictionary = {
	"track": "sonnenhafen",
	"laps": 2,
	"cps": 8,
	"zones": 4,
	"seats": 4,
	## Kürzeste mögliche Zeit zwischen zwei Checkpoints (aus der Strecke abgeleitet).
	"min_gap": 1.0,
	## Wie weit eine gemeldete Checkpoint-Zeit hinter der Uhr der Autorität liegen darf.
	"max_lag": 0.5,
	## So lange wartet ein Platz nach Verbindungsabbruch auf seinen Fahrer, dann fährt die KI.
	"grace": 20.0,
	"countdown": 3.0,
	"ai_fill": true,
	## KI-Plätze melden ihre Checkpoints selbst (Tests, Parcours ohne eigene KI). Im Kart
	## melden die vorhandenen Rivalen ihre Durchfahrten über claim_checkpoint.
	"ai_auto": true,
	"ai_cp_seconds": [3.0, 3.1, 3.2, 3.3]
}
var nonce: String = ""
var phase: String = "lobby"  # lobby | racing | done
var t0: float = 0.0
var seats: Array = []
var events: Array = []
var rejects: Dictionary = {}
## Callable(seat: int, place: int, progress: float) -> String (Item-Kennung, "" = nichts).
var drawer: Callable
var rng := RandomNumberGenerator.new()
var _sent: int = 0


func _init(overrides: Dictionary = {}, seed_value: int = -1) -> void:
	config.merge(overrides, true)
	config.seats = clampi(int(config.seats), 2, WIRE.MAX_SEATS)
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	nonce = "r%08x" % rng.randi()
	for i in range(int(config.seats)):
		seats.append(_open_seat(i))


static func _open_seat(i: int) -> Dictionary:
	return {
		"seat": i,
		"kind": "open",
		"ps": "",
		"drv": "",
		"kart": "",
		"tok": "",
		"on": false,
		"lap": 0,
		"next_cp": 0,
		"last_t": 0.0,
		"finish": -1.0,
		"place": 0,
		"item": "",
		"item_n": 0,
		"picked": {},
		"away_since": -1.0,
		## Nach einem Abbruch: frühestens annehmbare Checkpoint-Zeit (Zeitpunkt des letzten
		## Lebenszeichens − max_lag), damit unterwegs gesammelte Durchfahrten nachgereicht werden
		## können – aber nie früher als vor dem Abbruch.
		"lag_floor": -1.0
	}


func room() -> Dictionary:
	return {
		"track": config.track,
		"laps": config.laps,
		"cps": config.cps,
		"zones": config.zones,
		"nonce": nonce
	}


## Neuer Fahrer oder Wiederkehrer (mit Platzkarte `token`). Ergebnis:
## {ok, seat, tok, resumed} oder {ok: false, why}.
func join(info: Dictionary, token: String, _now: float) -> Dictionary:
	if not token.is_empty():
		for s in seats:
			if s.kind == "human" and s.tok == token:
				s.on = true
				s.away_since = -1.0
				return {"ok": true, "seat": s.seat, "tok": token, "resumed": true}
		return {"ok": false, "why": "token"}
	if phase != "lobby":
		return {"ok": false, "why": "started"}
	for s in seats:
		if s.kind == "open":
			s.kind = "human"
			s.ps = WIRE.clean_pseudonym(info.get("ps"))
			s.drv = WIRE.clean_id(info.get("drv"), "fox")
			s.kart = WIRE.clean_id(info.get("kart"), "comet")
			s.tok = WIRE.make_token()
			s.on = true
			return {"ok": true, "seat": s.seat, "tok": s.tok, "resumed": false}
	return {"ok": false, "why": "full"}


## Verbindung weg: Platz bleibt reserviert (Zeit `grace`), danach übernimmt die KI.
## `last_heard` = Uhr der Autorität beim letzten Paket dieses Platzes (−1 = jetzt).
func disconnect_seat(seat: int, now: float, last_heard: float = -1.0) -> void:
	if not _valid(seat):
		return
	var s: Dictionary = seats[seat]
	if s.kind != "human" or not s.on:
		return
	if phase == "done":
		s.on = false  # nach dem Ergebnis ist Gehen kein Spielereignis mehr
		return
	s.on = false
	s.away_since = now
	s.lag_floor = race_time(last_heard if last_heard >= 0.0 else now) - float(config.max_lag)
	if phase == "lobby":
		seats[seat] = _open_seat(seat)  # vor dem Start einfach frei machen
	else:
		_event({"kind": "away", "seat": seat, "t": race_time(now)})


func human_count() -> int:
	var count: int = 0
	for s in seats:
		if s.kind == "human":
			count += 1
	return count


func start(now: float) -> bool:
	if phase != "lobby" or human_count() < 1:
		return false
	var ai_index: int = 0
	for s in seats:
		if s.kind == "open" and bool(config.ai_fill):
			s.kind = "ai"
			s.ps = "Lumo KI %d" % (ai_index + 1)
			s.drv = AI_DRIVERS[ai_index % AI_DRIVERS.size()]
			s.kart = "comet"
			s.on = true
			ai_index += 1
	t0 = now + float(config.countdown)
	phase = "racing"
	return true


func race_time(now: float) -> float:
	return now - t0


## Checkpoint-Meldung eines Platzes. `claimed` = Rennzeit laut Fahrer (wird nur in einem engen
## Fenster um die eigene Uhr angenommen). Gibt das Ereignis zurück oder {} (Grund in rejects).
func claim_checkpoint(seat: int, lap: int, index: int, claimed: float, now: float) -> Dictionary:
	if not _valid(seat) or phase != "racing":
		return _reject("phase")
	var s: Dictionary = seats[seat]
	if s.kind == "open" or float(s.finish) >= 0.0:
		return _reject("seat")
	if lap != int(s.lap) or index != int(s.next_cp):
		return _reject("order")
	var now_t: float = race_time(now)
	var lower: float = now_t - float(config.max_lag)
	if float(s.lag_floor) >= 0.0:
		lower = minf(lower, float(s.lag_floor))
	var t: float = clampf(claimed, lower, now_t)
	if t < 0.0:
		return _reject("early")
	if t - float(s.last_t) < float(config.min_gap):
		return _reject("too_fast")
	s.last_t = t
	if t >= now_t - float(config.max_lag):
		s.lag_floor = -1.0  # wieder auf Stand
	var ev: Dictionary = _event({"kind": "cp", "seat": seat, "lap": lap, "i": index, "t": t})
	s.next_cp = index + 1
	if int(s.next_cp) >= int(config.cps):
		s.next_cp = 0
		s.lap = lap + 1
		if int(s.lap) >= int(config.laps):
			_finish(seat, t)
	return ev


## Item-Prisma eingesammelt (Zone „runde:nummer“). Genau eine Ziehung je Platz/Runde/Zone,
## nur mit freiem Item-Feld; die Ziehung macht die Autorität.
func pick_item(seat: int, zone: String, now: float) -> Dictionary:
	var why: String = _pick_refusal(seat, zone, now)
	if not why.is_empty():
		return _reject(why)
	var s: Dictionary = seats[seat]
	s.picked[zone] = true
	var item: String = ""
	if drawer.is_valid():
		item = str(drawer.call(seat, place_of(seat), progress_of(seat)))
	else:
		item = ["boost", "shield", "star_rocket"][rng.randi_range(0, 2)]
	item = WIRE.clean_id(item, "")
	if item.is_empty():
		return _reject("empty")
	var ev: Dictionary = _event({"kind": "item", "seat": seat, "z": zone, "item": item})
	s.item = item
	s.item_n = int(ev.n)
	return ev


func _pick_refusal(seat: int, zone: String, now: float) -> String:
	if not _valid(seat) or phase != "racing" or race_time(now) < 0.0:
		return "phase"
	var s: Dictionary = seats[seat]
	var parts: PackedStringArray = zone.split(":")
	if s.kind == "open" or float(s.finish) >= 0.0 or parts.size() != 2:
		return "seat"
	if int(parts[0]) != int(s.lap) or int(parts[1]) >= int(config.zones):
		return "zone"
	if (s.picked as Dictionary).has(zone):
		return "twice"
	if not str(s.item).is_empty():
		return "full"
	return ""


## Einsatz: nur das gehaltene Item (über die Nummer seines Zieh-Ereignisses).
func use_item(seat: int, item_event: int, now: float) -> Dictionary:
	if not _valid(seat) or phase != "racing":
		return _reject("phase")
	var s: Dictionary = seats[seat]
	if str(s.item).is_empty() or int(s.item_n) != item_event:
		return _reject("not_held")
	var ev: Dictionary = _event(
		{"kind": "use", "seat": seat, "e": item_event, "item": s.item, "t": race_time(now)}
	)
	s.item = ""
	s.item_n = 0
	return ev


## Zeitschritt der Autorität: KI-Fortschritt, KI-Übernahme verwaister Plätze, Rennende.
func tick(now: float) -> void:
	if phase != "racing":
		return
	var now_t: float = race_time(now)
	for s in seats:
		if s.kind == "human" and not s.on and float(s.away_since) >= 0.0:
			if now - float(s.away_since) > float(config.grace) and float(s.finish) < 0.0:
				s.kind = "ai"
				s.tok = ""
				_event({"kind": "takeover", "seat": s.seat, "t": now_t})
		if s.kind == "ai" and bool(config.ai_auto) and float(s.finish) < 0.0:
			var step: float = _ai_seconds(int(s.seat))
			while float(s.finish) < 0.0 and now_t >= float(s.last_t) + step:
				var ev: Dictionary = claim_checkpoint(
					int(s.seat), int(s.lap), int(s.next_cp), float(s.last_t) + step, now
				)
				if ev.is_empty():
					break
	_maybe_result(now_t)


func _ai_seconds(seat: int) -> float:
	var list: Array = config.ai_cp_seconds
	return maxf(float(config.min_gap), float(list[seat % list.size()]))


func progress_of(seat: int) -> float:
	var s: Dictionary = seats[seat]
	return (
		float(int(s.lap) * int(config.cps) + int(s.next_cp))
		/ float(int(config.cps) * int(config.laps))
	)


## Aktueller Platz (1 = vorn): Ziel-Reihenfolge, sonst Fortschritt, bei Gleichstand früher dort.
func place_of(seat: int) -> int:
	var order: Array = standings()
	for row in order:
		if int(row.seat) == seat:
			return int(row.place)
	return seats.size()


func standings() -> Array:
	var rows: Array = []
	for s in seats:
		if s.kind == "open":
			continue
		rows.append(s)
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var af: bool = float(a.finish) >= 0.0
			var bf: bool = float(b.finish) >= 0.0
			if af != bf:
				return af
			if af:
				return float(a.finish) < float(b.finish)
			var ap: float = progress_of(int(a.seat))
			var bp: float = progress_of(int(b.seat))
			if ap != bp:
				return ap > bp
			return float(a.last_t) < float(b.last_t)
	)
	var out: Array = []
	for i in range(rows.size()):
		out.append(
			{
				"seat": rows[i].seat,
				"place": i + 1,
				"time": rows[i].finish,
				"kind": "ai" if rows[i].kind == "ai" else "human"
			}
		)
	return out


## Neue Ereignisse seit dem letzten Aufruf (zum Versenden).
func take_new() -> Array:
	var out: Array = events.slice(_sent)
	_sent = events.size()
	return out


## Ereignisse ab Nummer `after` + 1 (Nachholen nach Wiederverbinden).
func events_after(after: int) -> Array:
	return events.slice(clampi(after, 0, events.size()))


func roster() -> Array:
	var out: Array = []
	for s in seats:
		out.append(
			{
				"seat": s.seat,
				"kind": s.kind,
				"ps": s.ps if not str(s.ps).is_empty() else "Flinker Fuchs 1",
				"drv": s.drv if not str(s.drv).is_empty() else "fox",
				"kart": s.kart if not str(s.kart).is_empty() else "comet",
				"on": s.on
			}
		)
	return out


func _finish(seat: int, t: float) -> void:
	var s: Dictionary = seats[seat]
	var done: int = 0
	for other in seats:
		if float(other.finish) >= 0.0:
			done += 1
	s.finish = t
	s.place = done + 1
	_event({"kind": "finish", "seat": seat, "time": t, "place": s.place})


func _maybe_result(_now_t: float) -> void:
	for s in seats:
		if s.kind != "open" and float(s.finish) < 0.0:
			return
	phase = "done"
	_event({"kind": "result", "seat": -1, "standings": standings()})


func _event(data: Dictionary) -> Dictionary:
	var n: int = events.size() + 1
	data["n"] = n
	data["eid"] = "%s_%d" % [nonce, n]
	events.append(data)
	return data


func _reject(reason: String) -> Dictionary:
	rejects[reason] = int(rejects.get(reason, 0)) + 1
	return {}


func _valid(seat: int) -> bool:
	return seat >= 0 and seat < seats.size()
