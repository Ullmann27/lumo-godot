extends RefCounted
## Die Lumo-Flotte: acht eigene Karts, alle in der Engine gebaut (keine fremden Modelle oder Namen).
## Jedes Kart hat fünf Werte von 0 bis 10. Comet steht mit 6/6/6/6/6 genau in der Mitte, alle
## Faktoren sind dort 1,0; die anderen weichen bewusst davon ab. Freigeschaltet wird mit
## Fortschrittssternen (verdient, nie bezahlt). Tuning (kart_tuning.gd) erhöht die Werte bis 12.
const STATS: Array[String] = ["speed", "accel", "brake", "handling", "turbo"]
const STAT_NAMES: Dictionary = {
	"speed": "Tempo",
	"accel": "Beschleunigung",
	"brake": "Bremsen",
	"handling": "Handling",
	"turbo": "Turbo"
}
const STAT_HINTS: Dictionary = {
	"speed": "Wie schnell das Kart auf der Geraden wird.",
	"accel": "Wie flott es aus Kurven und nach dem Start anzieht.",
	"brake": "Wie kurz der Bremsweg ist.",
	"handling": "Wie genau es lenkt und in Kurven haftet.",
	"turbo": "Wie stark und lange Boost und Drift-Turbo schieben."
}
## Mitte der Skala: Wert 6 entspricht dem Faktor 1,0.
const NEUTRAL: float = 6.0
## Höchster Wert mit Tuning (Grundwert höchstens 10, Tuning bis +2).
const MAX_STAT: float = 12.0

static var KARTS: Array[Dictionary] = _build()


static func _build() -> Array[Dictionary]:
	var rows: Array[Dictionary] = [
		{
			"id": "comet", "name": "Comet", "role": "Allrounder", "tag": "AUSGEWOGEN", "unlock": 0,
			"description": "Lumos Rennkart: gut in allem. Ein sicherer Start auf jeder Strecke.",
			"stats": {"speed": 6, "accel": 6, "brake": 6, "handling": 6, "turbo": 6},
			"traits": {"offroad": 0.54, "stability": 0.45},
			"look": {"body": "aero", "paint": Color("0f2450"), "trim": Color("dfe9f6"), "accent": Color("f08a2c"), "neon": Color("2fd0ff")},
		},
		{
			"id": "glider", "name": "Glider", "role": "Wendig", "tag": "LEICHT ZU LENKEN", "unlock": 8,
			"description": "Leicht und wendig: biegt eng ein und zieht schnell an, ist aber nicht der Schnellste.",
			"stats": {"speed": 5, "accel": 7, "brake": 6, "handling": 9, "turbo": 5},
			"traits": {"offroad": 0.54, "stability": 0.40},
			"look": {"body": "glider", "paint": Color("dff0ff"), "trim": Color("3fd0c0"), "accent": Color("ffffff"), "neon": Color("4fffe6")},
		},
		{
			"id": "turbo", "name": "Aurora GT", "role": "Highspeed", "tag": "SCHNELL AUF GERADEN", "unlock": 18,
			"description": "Flacher Langstreckenrenner: unschlagbar auf Geraden, träger in engen Kurven.",
			"stats": {"speed": 9, "accel": 5, "brake": 5, "handling": 5, "turbo": 8},
			"traits": {"offroad": 0.50, "stability": 0.48},
			"look": {"body": "gt", "paint": Color("3a1f6e"), "trim": Color("ffd36a"), "accent": Color("ffb43a"), "neon": Color("c79bff")},
		},
		{
			"id": "blitz", "name": "Blitz", "role": "Dragster", "tag": "STARTET WIE EIN BLITZ", "unlock": 32,
			"description": "Kleiner Dragster mit riesigem Turbo: explodiert aus jeder Ecke, braucht aber Gefühl beim Bremsen.",
			"stats": {"speed": 6, "accel": 9, "brake": 5, "handling": 6, "turbo": 8},
			"traits": {"offroad": 0.54, "stability": 0.42},
			"look": {"body": "dragster", "paint": Color("ffcf2e"), "trim": Color("1a1c24"), "accent": Color("ff5a2c"), "neon": Color("ffe45c")},
		},
		{
			"id": "terra", "name": "Terra", "role": "Gelände", "tag": "STARK AUCH NEBEN DER STRASSE", "unlock": 48,
			"description": "Robuster Buggy mit dicken Reifen: bremst kräftig, lenkt sicher und bleibt abseits der Fahrbahn schnell.",
			"stats": {"speed": 6, "accel": 6, "brake": 8, "handling": 8, "turbo": 6},
			"traits": {"offroad": 0.82, "stability": 0.56},
			"look": {"body": "buggy", "paint": Color("2f6b4a"), "trim": Color("c9b38a"), "accent": Color("ff9a3c"), "neon": Color("8cff7a")},
		},
		{
			"id": "koloss", "name": "Koloss", "role": "Schwergewicht", "tag": "BREMST UND RAMMT", "unlock": 66,
			"description": "Schwerer Panzerwagen: bremst am kürzesten und lässt sich von Treffern kaum bremsen, wird aber nur langsam schnell.",
			"stats": {"speed": 7, "accel": 4, "brake": 10, "handling": 5, "turbo": 8},
			"traits": {"offroad": 0.62, "stability": 0.66},
			"look": {"body": "heavy", "paint": Color("8c1f2e"), "trim": Color("5a6272"), "accent": Color("ffb43a"), "neon": Color("ff7a6a")},
		},
		{
			"id": "phantom", "name": "Phantom", "role": "Drift-Profi", "tag": "GLEITET DURCH KURVEN", "unlock": 88,
			"description": "Futuristischer Gleiter in Neon: lenkt präzise, driftet sauber und lädt kräftige Turbos.",
			"stats": {"speed": 8, "accel": 7, "brake": 6, "handling": 8, "turbo": 7},
			"traits": {"offroad": 0.54, "stability": 0.44},
			"look": {"body": "phantom", "paint": Color("1b1233"), "trim": Color("ff4fd8"), "accent": Color("7a5cff"), "neon": Color("ff5ce6")},
		},
		{
			"id": "stella", "name": "Stella", "role": "Champion", "tag": "DER STERNENFLITZER", "unlock": 120,
			"description": "Der goldene Sternenflitzer: schnell, wendig und kraftvoll. Nur für Kinder mit vielen Sternen.",
			"stats": {"speed": 9, "accel": 8, "brake": 7, "handling": 8, "turbo": 9},
			"traits": {"offroad": 0.60, "stability": 0.50},
			"look": {"body": "champion", "paint": Color("f2c24a"), "trim": Color("fff4cf"), "accent": Color("1d3e8a"), "neon": Color("ffe9a0")},
		},
	]
	for row in rows:
		var stats: Dictionary = row.stats
		var factors: Dictionary = multipliers(stats, row.traits)
		# Altbestand: speed/turn/accel als Faktoren, damit ältere Aufrufer weiter funktionieren.
		row["speed"] = factors.speed
		row["turn"] = factors.turn
		row["accel"] = factors.accel
	var result: Array[Dictionary] = []
	result.assign(rows)
	return result


static func ids() -> Array[String]:
	var result: Array[String] = []
	for item in KARTS:
		result.append(str(item.id))
	return result


static func has(id: String) -> bool:
	for item in KARTS:
		if str(item.id) == id:
			return true
	return false


static func entry(id: String) -> Dictionary:
	for item in KARTS:
		if str(item.id) == id:
			return item
	return KARTS[0]


static func base_stats(id: String) -> Dictionary:
	var result: Dictionary = {}
	var source: Dictionary = entry(id).stats
	for key in STATS:
		result[key] = float(source.get(key, NEUTRAL))
	return result


## Wandelt Werte (0–12) in Fahrfaktoren um. Wert 6 ergibt überall 1,0.
static func multipliers(stats: Dictionary, traits: Dictionary = {}) -> Dictionary:
	var speed: float = float(stats.get("speed", NEUTRAL)) - NEUTRAL
	var accel: float = float(stats.get("accel", NEUTRAL)) - NEUTRAL
	var brake: float = float(stats.get("brake", NEUTRAL)) - NEUTRAL
	var handling: float = float(stats.get("handling", NEUTRAL)) - NEUTRAL
	var turbo: float = float(stats.get("turbo", NEUTRAL)) - NEUTRAL
	return {
		"speed": 1.0 + speed * 0.030,
		"accel": 1.0 + accel * 0.060,
		"brake": 1.0 + brake * 0.070,
		"turn": 1.0 + handling * 0.045,
		"grip": 1.0 + handling * 0.030,
		"boost_power": 1.0 + turbo * 0.07,
		"boost_time": 1.0 + turbo * 0.05,
		"offroad": float(traits.get("offroad", 0.54)),
		"stability": float(traits.get("stability", 0.45)),
	}


## Balken von 0 bis 1 für die Anzeige (Skala 0–12, damit Tuning sichtbar Platz hat).
static func bar(value: float) -> float:
	return clampf(value / MAX_STAT, 0.0, 1.0)


## Gesamtwert, z. B. für die Reihenfolge in der Auswahl und für Tests.
static func total(stats: Dictionary) -> float:
	var sum: float = 0.0
	for key in STATS:
		sum += float(stats.get(key, NEUTRAL))
	return sum
