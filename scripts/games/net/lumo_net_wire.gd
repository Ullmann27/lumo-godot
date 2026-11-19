extends RefCounted
## Leitungsformat der LUMO-Netzbasis (Kart, Parcours, später Karten).
##
## Jede Nachricht ist ein kleines JSON-Objekt in reinem ASCII (Nicht-ASCII als \uXXXX).
## Eingehendes wird zuerst auf Größe und Zeichen geprüft, dann geparst und gegen ein festes
## Schema je Nachrichtentyp gefiltert. Unbekanntes oder Kaputtes wird still verworfen
## (kein Laufzeitfehler, keine Fehlerzeile im Protokoll).
##
## Übertragen werden nur Sitzungs-Pseudonyme (z. B. „Flinker Fuchs 7“), Fahrer-/Kart-Kennungen,
## Fahrdaten und Spielereignisse. Kein Vorname, kein Profil, kein Chat, kein freier Text.

const PROTOCOL: int = 2
const MAX_BYTES: int = 1400
const MAX_SEATS: int = 4
const MAX_COORD: float = 5000.0
const ID_PATTERN: String = "^[a-z0-9_]{1,40}$"
const TOKEN_PATTERN: String = "^[0-9a-f]{32}$"
const ZONE_PATTERN: String = "^[0-9]{1,2}:[0-9]{1,2}$"

## Feste Wortliste: Pseudonyme werden nur aus diesen Teilen gebaut und auch nur so angenommen.
const PSEUDO_ADJECTIVES: Array[String] = [
	"Flinker", "Mutiger", "Heller", "Wilder", "Schlauer", "Froher", "Kluger", "Starker"
]
const PSEUDO_ANIMALS: Array[String] = [
	"Fuchs", "Hase", "Igel", "Dachs", "Biber", "Luchs", "Otter", "Falke"
]

## Nachrichtentypen, die ein Gast an die Autorität schicken darf.
const FROM_GUEST: Array[String] = ["join", "pose", "cp", "pick", "use", "ping", "bye"]
## Nachrichtentypen, die nur von der Autorität kommen dürfen.
const FROM_AUTHORITY: Array[String] = [
	"welcome", "reject", "roster", "start", "snap", "ev", "pong", "bye"
]
const EVENT_KINDS: Array[String] = ["cp", "item", "use", "finish", "result", "takeover", "away"]
const REJECT_CODES: Array[String] = ["protocol", "full", "started", "token", "closed", "track"]


## Sitzungs-Pseudonym aus Zufall (wechselt mit jeder Sitzung, hängt an keinem Profil).
static func make_pseudonym(rng: RandomNumberGenerator) -> String:
	return (
		"%s %s %d"
		% [
			PSEUDO_ADJECTIVES[rng.randi_range(0, PSEUDO_ADJECTIVES.size() - 1)],
			PSEUDO_ANIMALS[rng.randi_range(0, PSEUDO_ANIMALS.size() - 1)],
			rng.randi_range(1, 99)
		]
	)


## Nur Pseudonyme aus der Wortliste sind erlaubt; alles andere wird ersetzt.
static func clean_pseudonym(raw: Variant, fallback: String = "Flinker Fuchs 1") -> String:
	var parts: PackedStringArray = str(raw).split(" ")
	if parts.size() != 3 or not parts[2].is_valid_int():
		return fallback
	var number: int = int(parts[2])
	if (
		parts[0] in PSEUDO_ADJECTIVES
		and parts[1] in PSEUDO_ANIMALS
		and number >= 1
		and number <= 99
		and str(number) == parts[2]
	):
		return str(raw)
	return fallback


static func make_token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


static func encode(message: Dictionary) -> PackedByteArray:
	var text: String = JSON.stringify(message)
	var out := ""
	for i in range(text.length()):
		var code: int = text.unicode_at(i)
		out += text[i] if code < 128 else "\\u%04x" % code
	return out.to_ascii_buffer()


## Bytes → Nachricht ({} bei allem, was nicht exakt passt). `from_authority` legt fest,
## welche Typen angenommen werden.
static func decode(data: PackedByteArray, from_authority: bool) -> Dictionary:
	if data.is_empty() or data.size() > MAX_BYTES or data[0] != 123:
		return {}
	for byte in data:
		if byte < 32 or byte > 126:
			return {}
	var json := JSON.new()
	if json.parse(data.get_string_from_ascii()) != OK:
		return {}
	var raw: Variant = json.data
	if not raw is Dictionary:
		return {}
	var kind: String = str((raw as Dictionary).get("t", ""))
	if kind not in (FROM_AUTHORITY if from_authority else FROM_GUEST):
		return {}
	var cleaned: Variant = _clean(kind, raw as Dictionary)
	if not cleaned is Dictionary:
		return {}
	(cleaned as Dictionary)["t"] = kind
	return cleaned


static func _clean(kind: String, m: Dictionary) -> Variant:
	match kind:
		"join":
			var token: String = str(m.get("tok", ""))
			if not token.is_empty() and not _matches(TOKEN_PATTERN, token):
				return null
			if int(num(m.get("v"), -1)) != PROTOCOL:
				return {"bad_protocol": true}
			return {
				"ps": clean_pseudonym(m.get("ps")),
				"drv": clean_id(m.get("drv"), "fox"),
				"kart": clean_id(m.get("kart"), "comet"),
				"tok": token,
				"last": clampi(int(num(m.get("last"), 0)), 0, 100000)
			}
		"pose":
			var pose: Variant = clean_pose(m.get("s"))
			return {"s": pose} if pose is Array else null
		"cp":
			return {
				"lap": clampi(int(num(m.get("lap"), -1)), -1, 99),
				"i": clampi(int(num(m.get("i"), -1)), -1, 99),
				"k": num(m.get("k"), -1.0)
			}
		"pick":
			var zone: String = str(m.get("z", ""))
			return {"z": zone} if _matches(ZONE_PATTERN, zone) else null
		"use":
			return {"e": clampi(int(num(m.get("e"), -1)), -1, 100000)}
		"ping":
			return {"c": num(m.get("c"), 0.0)}
		"pong":
			return {"c": num(m.get("c"), 0.0), "h": num(m.get("h"), 0.0)}
		"bye":
			return {}
		"reject":
			var why: String = str(m.get("why", ""))
			return {"why": why if why in REJECT_CODES else "closed"}
		"welcome":
			var token: String = str(m.get("tok", ""))
			var roster: Variant = clean_roster(m.get("seats"))
			if not _matches(TOKEN_PATTERN, token) or not roster is Array:
				return null
			return {
				"seat": clampi(int(num(m.get("seat"), -1)), -1, MAX_SEATS - 1),
				"tok": token,
				"seats": roster,
				"room": clean_room(m.get("room")),
				"h": num(m.get("h"), 0.0)
			}
		"roster":
			var roster: Variant = clean_roster(m.get("seats"))
			return {"seats": roster} if roster is Array else null
		"start":
			return {"room": clean_room(m.get("room")), "t0": num(m.get("t0"), 0.0)}
		"snap":
			var list: Variant = m.get("s")
			if not list is Array or (list as Array).size() > MAX_SEATS:
				return null
			var poses: Array = []
			for entry in list:
				var pose: Variant = clean_pose(entry)
				if pose is Array:
					poses.append(pose)
			return {"s": poses}
		"ev":
			return clean_event(m)
	return null


## Fahrdaten: [platz, k (Rennzeit), x, y, z, gier, tempo] – nur endliche Zahlen im Rahmen.
static func clean_pose(raw: Variant) -> Variant:
	if not raw is Array or (raw as Array).size() != 7:
		return null
	var out: Array = []
	for value in raw:
		if not (value is float or value is int) or not is_finite(float(value)):
			return null
		out.append(float(value))
	var seat: int = int(out[0])
	if seat < 0 or seat >= MAX_SEATS or float(seat) != out[0]:
		return null
	for i in [2, 3, 4]:
		if absf(out[i]) > MAX_COORD:
			return null
	out[0] = seat
	out[6] = clampf(out[6], -80.0, 80.0)
	return out


static func clean_roster(raw: Variant) -> Variant:
	if not raw is Array or (raw as Array).size() > MAX_SEATS:
		return null
	var out: Array = []
	for entry in raw:
		if not entry is Dictionary:
			return null
		var kind: String = str(entry.get("kind", ""))
		if kind not in ["human", "ai", "open"]:
			return null
		out.append(
			{
				"seat": clampi(int(num(entry.get("seat"), 0)), 0, MAX_SEATS - 1),
				"kind": kind,
				"ps": clean_pseudonym(entry.get("ps")),
				"drv": clean_id(entry.get("drv"), "fox"),
				"kart": clean_id(entry.get("kart"), "comet"),
				"on": entry.get("on", false) == true
			}
		)
	return out


static func clean_room(raw: Variant) -> Dictionary:
	var room: Dictionary = raw if raw is Dictionary else {}
	return {
		"track": clean_id(room.get("track"), ""),
		"laps": clampi(int(num(room.get("laps"), 1)), 1, 9),
		"cps": clampi(int(num(room.get("cps"), 1)), 1, 64),
		"zones": clampi(int(num(room.get("zones"), 0)), 0, 32),
		"nonce": clean_id(room.get("nonce"), "")
	}


static func clean_event(m: Dictionary) -> Variant:
	var kind: String = str(m.get("kind", ""))
	var n: int = int(num(m.get("n"), 0))
	if kind not in EVENT_KINDS or n < 1 or n > 100000:
		return null
	var out := {
		"n": n,
		"kind": kind,
		"eid": clean_id(m.get("eid"), ""),
		"seat": clampi(int(num(m.get("seat"), -1)), -1, MAX_SEATS - 1)
	}
	if str(out.eid).is_empty():
		return null
	for key in ["lap", "i", "e", "place"]:
		if m.has(key):
			out[key] = clampi(int(num(m.get(key), 0)), -1, 100000)
	for key in ["t", "time"]:
		if m.has(key):
			out[key] = num(m.get(key), 0.0)
	if m.has("item"):
		out["item"] = clean_id(m.get("item"), "")
	if m.has("z"):
		var zone: String = str(m.get("z", ""))
		out["z"] = zone if _matches(ZONE_PATTERN, zone) else ""
	if m.has("standings"):
		var standings: Variant = m.get("standings")
		if not standings is Array or (standings as Array).size() > MAX_SEATS:
			return null
		var rows: Array = []
		for row in standings:
			if not row is Dictionary:
				return null
			rows.append(
				{
					"seat": clampi(int(num(row.get("seat"), 0)), 0, MAX_SEATS - 1),
					"place": clampi(int(num(row.get("place"), 0)), 1, MAX_SEATS),
					"time": num(row.get("time"), -1.0),
					"kind": "ai" if str(row.get("kind", "")) == "ai" else "human"
				}
			)
		out["standings"] = rows
	return out


static func clean_id(raw: Variant, fallback: String) -> String:
	var text: String = str(raw) if raw != null else ""
	return text if _matches(ID_PATTERN, text) else fallback


## Nur echte, endliche Zahlen; alles andere ergibt den Ersatzwert.
static func num(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		var number: float = float(value)
		return number if is_finite(number) else fallback
	return fallback


static func _matches(pattern: String, text: String) -> bool:
	return RegEx.create_from_string(pattern).search(text) != null
