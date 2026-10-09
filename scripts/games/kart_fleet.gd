extends RefCounted
## Die Lumo-Flotte: vierzehn eigene Karts, alle in der Engine gebaut (keine fremden Modelle oder Namen).
## Jedes Kart hat fünf Werte von 0 bis 10. Comet steht mit 6/6/6/6/6 genau in der Mitte, alle
## Faktoren sind dort 1,0; die anderen weichen bewusst davon ab. Freigeschaltet wird mit
## Fortschrittssternen (verdient, nie bezahlt). Tuning (kart_tuning.gd) erhöht die Werte bis 12.
## Karosserie: „loft“ = geloftete Aurora-Karosserie (Comet, Glider, Aurora GT und die sechs
## Profil-Designs aus PROFILES), sonst ein Körper aus dem Plattenbaukasten in kart_vehicle.gd.
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
			"look": {"body": "loft", "paint": Color("0f2450"), "trim": Color("dfe9f6"), "accent": Color("f08a2c"), "neon": Color("2fd0ff")},
		},
		{
			"id": "gecko_velo", "name": "Gecko Velo", "role": "Flink", "tag": "FLINK DURCH KURVEN", "unlock": 0,
			"description": "Schmale Nase, flinke Lenkung und schneller Antritt.",
			"stats": {"speed": 7, "accel": 7, "brake": 5, "handling": 8, "turbo": 5},
			"traits": {"offroad": 0.54, "stability": 0.42},
			"look": {"body": "loft", "paint": Color("a9dd37"), "trim": Color("edf9ff"), "accent": Color("f08a2c"), "neon": Color("72e6ff")},
		},
		{
			"id": "boru_rally", "name": "Boru Rally", "role": "Rallye", "tag": "KRAFTVOLLER ANTRITT", "unlock": 4,
			"description": "Rallye-Bügel, breite Schultern und kräftige Beschleunigung.",
			"stats": {"speed": 5, "accel": 9, "brake": 7, "handling": 6, "turbo": 6},
			"traits": {"offroad": 0.70, "stability": 0.52},
			"look": {"body": "loft", "paint": Color("cc7d3f"), "trim": Color("edf9ff"), "accent": Color("b7cddd"), "neon": Color("72e6ff")},
		},
		{
			"id": "glider", "name": "Glider", "role": "Wendig", "tag": "LEICHT ZU LENKEN", "unlock": 8,
			"description": "Leicht und wendig: biegt eng ein und zieht schnell an, ist aber nicht der Schnellste.",
			"stats": {"speed": 5, "accel": 7, "brake": 6, "handling": 9, "turbo": 5},
			"traits": {"offroad": 0.54, "stability": 0.40},
			"look": {"body": "loft", "paint": Color("dff0ff"), "trim": Color("3fd0c0"), "accent": Color("ffffff"), "neon": Color("4fffe6")},
		},
		{
			"id": "nala_comet", "name": "Nala Comet", "role": "Sportlich", "tag": "SPORTLICH UND WENDIG", "unlock": 10,
			"description": "Geschwungene Heckflossen und ein ausgewogener Sprint.",
			"stats": {"speed": 8, "accel": 7, "brake": 5, "handling": 7, "turbo": 6},
			"traits": {"offroad": 0.54, "stability": 0.45},
			"look": {"body": "loft", "paint": Color("ef7968"), "trim": Color("edf9ff"), "accent": Color("ffd36a"), "neon": Color("72e6ff")},
		},
		{
			"id": "noa_tide", "name": "Noa Tide", "role": "Komfort", "tag": "SANFTE WELLENLINIEN", "unlock": 12,
			"description": "Runde Bugform und besonders angenehme Lenkung.",
			"stats": {"speed": 6, "accel": 8, "brake": 6, "handling": 9, "turbo": 5},
			"traits": {"offroad": 0.54, "stability": 0.46},
			"look": {"body": "loft", "paint": Color("478de1"), "trim": Color("edf9ff"), "accent": Color("72e6ff"), "neon": Color("72e6ff")},
		},
		{
			"id": "iva_aurora", "name": "Iva Aurora", "role": "Aero", "tag": "LEICHTER AEROFLÜGEL", "unlock": 16,
			"description": "Federflossen, eine schlanke Nase und Tempo auf Geraden.",
			"stats": {"speed": 9, "accel": 5, "brake": 5, "handling": 7, "turbo": 7},
			"traits": {"offroad": 0.50, "stability": 0.44},
			"look": {"body": "loft", "paint": Color("a0a6e9"), "trim": Color("edf9ff"), "accent": Color("ffd36a"), "neon": Color("c79bff")},
		},
		{
			"id": "turbo", "name": "Aurora GT", "role": "Highspeed", "tag": "SCHNELL AUF GERADEN", "unlock": 18,
			"description": "Flacher Langstreckenrenner: unschlagbar auf Geraden, träger in engen Kurven.",
			"stats": {"speed": 9, "accel": 5, "brake": 5, "handling": 5, "turbo": 8},
			"traits": {"offroad": 0.50, "stability": 0.48},
			"look": {"body": "loft", "paint": Color("3a1f6e"), "trim": Color("ffd36a"), "accent": Color("ffb43a"), "neon": Color("c79bff")},
		},
		{
			"id": "zuri_volt", "name": "Zuri Volt", "role": "Elektro", "tag": "ELEKTRISCHER ANTRITT", "unlock": 20,
			"description": "Wabengrill, Lichtfühler und ein lebhafter Start.",
			"stats": {"speed": 7, "accel": 8, "brake": 6, "handling": 5, "turbo": 8},
			"traits": {"offroad": 0.54, "stability": 0.45},
			"look": {"body": "loft", "paint": Color("efc044"), "trim": Color("101c30"), "accent": Color("72e6ff"), "neon": Color("72e6ff")},
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


# ------------------------------------------------------------------ Profil-Designs
## Die sechs Profil-Designs teilen die geloftete Aurora-Karosserie; PROFILES ändert Breite, Nase,
## Höhe und Flügel, decorate() setzt eigene Anbauteile. Werte und Preise stehen oben in KARTS.
const IDS: Array[String] = [
	"gecko_velo", "boru_rally", "nala_comet", "noa_tide", "iva_aurora", "zuri_volt"
]
const PROFILES: Dictionary = {
	"gecko_velo":
	{"paint": "a9dd37", "width": 0.93, "nose": 0.78, "height": 0.91, "wing": 1.24, "wing_y": 0.95},
	"boru_rally":
	{"paint": "cc7d3f", "width": 1.08, "nose": 1.10, "height": 1.14, "wing": 1.42, "wing_y": 1.03},
	"nala_comet":
	{"paint": "ef7968", "width": 0.98, "nose": 0.94, "height": 1.02, "wing": 1.38, "wing_y": 0.96},
	"noa_tide":
	{"paint": "478de1", "width": 1.02, "nose": 1.08, "height": 0.96, "wing": 1.50, "wing_y": 0.88},
	"iva_aurora":
	{"paint": "a0a6e9", "width": 0.96, "nose": 0.82, "height": 0.93, "wing": 1.60, "wing_y": 1.02},
	"zuri_volt":
	{"paint": "efc044", "width": 1.04, "nose": 1.16, "height": 1.04, "wing": 1.46, "wing_y": 0.98}
}


static func profile(id: String) -> Dictionary:
	return PROFILES.get(id, {}).duplicate()


static func shell(id: String) -> Array[Vector4]:
	var info: Dictionary = profile(id)
	var n: float = float(info.get("nose", 1.0))
	var h: float = float(info.get("height", 1.0))
	return [
		Vector4(-1.16, 0.015, 0.018, 0.50),
		Vector4(-1.07, 0.24 * n, 0.065 * h, 0.51),
		Vector4(-0.81, 0.45 * n, 0.17 * h, 0.52),
		Vector4(-0.48, 0.58, 0.20 * h, 0.50),
		Vector4(0.06, 0.61, 0.14, 0.45),
		Vector4(0.55, 0.61, 0.15, 0.46),
		Vector4(0.91, 0.48, 0.15 * h, 0.49),
		Vector4(1.05, 0.20, 0.065, 0.50),
		Vector4(1.08, 0.01, 0.015, 0.50)
	]


static func decorate(kart, body: Node3D, paint: Color, id: String) -> void:
	if not PROFILES.has(id):
		return
	body.set_meta("fleet_design", id)
	for side in [-1.0, 1.0]:
		match id:
			"gecko_velo":
				_fin(kart, body, Vector3(side * 0.47, 0.61, 0.48), side, paint, 0.38)
				kart._ellipsoid(
					body,
					Vector3(side * 0.29, 0.64, -0.93),
					Vector3(0.10, 0.07, 0.08),
					kart.INK,
					0.2,
					0.35
				)
				kart._ellipsoid(
					body,
					Vector3(side * 0.29, 0.64, -1.00),
					Vector3(0.064, 0.044, 0.023),
					kart.WHITE,
					0.18,
					0.27
				)
			"boru_rally":
				var lamp: MeshInstance3D = kart._ring(
					body, Vector3(side * 0.28, 0.67, -0.90), 0.070, 0.095, kart.CHROME, 0.75
				)
				lamp.rotation.x = PI / 2.0
				kart._ellipsoid(
					body,
					Vector3(side * 0.28, 0.67, -0.925),
					Vector3(0.071, 0.071, 0.024),
					kart.WHITE,
					0.18,
					0.27
				)
				_ribbon(
					kart,
					body,
					[
						Vector3(side * 0.52, 0.52, -1.08),
						Vector3(side * 0.57, 0.60, -1.13),
						Vector3(0, 0.60, -1.13)
					],
					0.036,
					kart.CHROME,
					0.75
				)
			"nala_comet":
				_fin(kart, body, Vector3(side * 0.49, 0.62, 0.48), side, paint, 0.32)
				for stripe in range(3):
					kart._box(
						body,
						Vector3(
							side * (0.537 + stripe * 0.011),
							0.693 + stripe * 0.059,
							0.50 + stripe * 0.024
						),
						Vector3(0.034, 0.025, 0.15 - stripe * 0.02),
						kart.WHITE,
						0.18
					)
			"noa_tide":
				_ribbon(
					kart,
					body,
					[
						Vector3(side * 0.20, 0.65, -0.94),
						Vector3(side * 0.33, 0.68, -0.78),
						Vector3(side * 0.40, 0.69, -0.55)
					],
					0.036,
					kart.WHITE,
					0.18
				)
				_ribbon(
					kart,
					body,
					[
						Vector3(side * 0.63, 0.60, -0.20),
						Vector3(side * 0.66, 0.67, 0.10),
						Vector3(side * 0.60, 0.61, 0.48)
					],
					0.022,
					kart.ICE,
					0.15,
					0.9
				)
			"iva_aurora":
				for feather in range(3):
					_fin(
						kart,
						body,
						Vector3(side * (0.48 + feather * 0.055), 0.55, 0.16 + feather * 0.10),
						side,
						kart.WHITE,
						0.19 - feather * 0.03
					)
				_ribbon(
					kart,
					body,
					[
						Vector3(side * 0.12, 0.752, -0.75),
						Vector3(side * 0.27, 0.77, -0.65),
						Vector3(side * 0.38, 0.70, -0.53)
					],
					0.019,
					paint,
					0.42
				)
			"zuri_volt":
				kart._rod(
					body,
					Vector3(side * 0.34, 0.90, 0.38),
					Vector3(side * 0.42, 1.21, 0.46),
					0.017,
					kart.INK,
					0.2
				)
				kart._ellipsoid(
					body,
					Vector3(side * 0.42, 1.22, 0.46),
					Vector3(0.047, 0.047, 0.047),
					kart.ICE,
					0.15,
					0.5
				)
	if id == "boru_rally":
		_ribbon(
			kart,
			body,
			[
				Vector3(-0.40, 0.66, 0.49),
				Vector3(-0.40, 1.25, 0.49),
				Vector3(-0.26, 1.40, 0.49),
				Vector3(0.26, 1.40, 0.49),
				Vector3(0.40, 1.25, 0.49),
				Vector3(0.40, 0.66, 0.49)
			],
			0.041,
			kart.CHROME,
			0.75
		)
	if id == "zuri_volt":
		# The grille is mounted in a real fascia instead of hanging ahead of the narrow nose.
		kart._box(body, Vector3(0, 0.57, -1.012), Vector3(0.55, 0.205, 0.13), kart.INK, 0.35)
		for cell in range(7):
			var x: float = (float(cell % 4) - 1.5) * 0.12
			var y: float = 0.51 + floorf(float(cell) / 4.0) * 0.10
			var points: Array[Vector3] = []
			for corner in range(7):
				var a: float = float(corner) * TAU / 6.0
				points.append(Vector3(x + cos(a) * 0.055, y + sin(a) * 0.055, -1.078))
			_ribbon(kart, body, points, 0.009, kart.CHROME, 0.75)


static func _fin(kart, body: Node3D, at: Vector3, side: float, paint: Color, height: float) -> void:
	var rings: Array[Vector4] = [
		Vector4(0, 0.025, 0.16, 0),
		Vector4(height * 0.38, 0.035, 0.13, 0.03),
		Vector4(height * 0.85, 0.024, 0.065, 0.09),
		Vector4(height, 0.003, 0.008, 0.12)
	]
	var fin: MeshInstance3D = kart._mesh(
		body, kart._loft(rings, true, 16, 3), at, paint, 0.42, 0.24
	)
	fin.rotation.z = -side * 0.18


static func _ribbon(
	kart,
	body: Node3D,
	points: Array[Vector3],
	width: float,
	color: Color,
	metal: float = 0.0,
	glow: float = 0.0
) -> void:
	kart._ribbon(body, points, width, color, metal, glow)
