extends RefCounted
## Kristallflut – versunkene Abenteuerwelt (Team B1, 26.11.2026). Fahrautorität der Strecke:
## Mittellinie, Höhen, Breiten, Beläge, zwei Abkürzungen, Unterwassertunnel, Kristallgrotte,
## Schanzen, Turbofelder, Sperrbereiche. Meeresspiegel 0 m (Runde 2: Flut +1,4 m).
## Bild, Klang, Licht und Ereignisse: flut_environment.gd und flut_landmarks.gd.
##
## Ablauf einer Runde (≈ 48 m/s, eine Stelle etwa alle 3–7 s):
##   0 s Schiffsanleger · 5 s Wasserfall-Sprung (früher Höhepunkt über das Becken) ·
##   8 s Klippenkurve über dem Meer · 13 s hinab zum Ufer · 16 s Unterwassertunnel (Glas, Fische,
##   versunkene Ruinen, Licht von oben) · 24 s Ruineninsel mit Säulengang-Abkürzung · 30 s
##   Muschel-Steilkurve · 33 s Kristallgrotte mit Lichtbecken · 39 s Fontänenplatz (angekündigt,
##   eine Seite immer frei) · 44 s Klippen-Abkürzung · 50 s unter dem Wasserfall-Vorhang hindurch
##   · 54 s Hafenkurve und Zielgerade über den Anleger.
const ID: String = "kristallflut_2800"
const NAME: String = "Kristallflut"
const CATALOG_ENTRY: Dictionary = {
	"id": ID,
	"name": NAME,
	"tag": "VERSUNKENE WELT · 2,8 KM",
	"color": Color("3fd8d0"),
	"description":
	"Durch den Unterwassertunnel, an Wasserfällen vorbei und hinein in die Kristallgrotte.",
}
## Gemessene Rundenlänge (Curve3D.get_baked_length, Test prüft ±0,5 m).
const LENGTH: float = 2823.1
const BASE_WIDTH: float = 13.0
const START_HEIGHT: float = 4.0
const SEA_LEVEL: float = 0.0
const TIDE_RISE: float = 1.4
const ENVIRONMENT: String = "res://scripts/games/kristallflut/flut_environment.gd"
const AUDIO_DIR: String = "kristallflut"
const SEGMENTS: Array = [
	{"s": 130.0, "h": 4.0},
	{"turn": -30.0, "r": 120.0, "ramp": 25.0, "h": 8.0},
	{"s": 150.0, "h": 14.0},
	{"turn": 70.0, "r": 70.0, "ramp": 20.0, "h": 18.0},
	{"turn": -40.0, "r": 90.0, "ramp": 20.0, "h": 18.0},
	{"s": 90.0, "h": 12.0},
	{"turn": 55.0, "r": 100.0, "ramp": 20.0, "h": 4.0},
	{"s": 150.0, "h": -12.5},
	{"turn": 45.0, "r": 120.0, "ramp": 25.0, "h": -12.5},
	{"s": 110.0, "h": 2.0},
	{"turn": 50.0, "r": 80.0, "ramp": 20.0, "h": 6.0},
	{"s": 130.0, "h": 7.0},
	{"turn": -40.0, "r": 80.0, "ramp": 20.0, "h": 8.0},
	{"turn": 90.0, "r": 65.0, "ramp": 20.0, "h": 10.0},
	{"s": 210.0, "h": 9.0},
	{"turn": 40.0, "r": 100.0, "ramp": 20.0, "h": 11.0},
	{"s": 130.0, "h": 12.0},
	{"turn": -60.0, "r": 80.0, "ramp": 20.0, "h": 14.0},
	{"s": 200.0, "h": 16.0},
	{"turn": 80.0, "r": 70.0, "ramp": 20.0, "h": 12.0},
	{"free": true},
	{"turn": 100.0, "r": 75.0, "ramp": 25.0, "h": 6.0},
	{"free": true, "h": 4.0},
]
const SECTIONS: Array[Dictionary] = [
	{"id": "anleger", "name": "Schiffsanleger", "start": 0.0, "end": 220.0},
	{"id": "wasserfall", "name": "Wasserfall-Sprung", "start": 220.0, "end": 370.0},
	{"id": "klippen", "name": "Klippenkurven", "start": 370.0, "end": 764.0},
	{"id": "tunnel", "name": "Unterwassertunnel", "start": 764.0, "end": 1144.0},
	{"id": "ruinen", "name": "Ruineninsel", "start": 1144.0, "end": 1440.0},
	{"id": "muschel", "name": "Muschel-Steilkurve", "start": 1440.0, "end": 1562.0},
	{"id": "grotte", "name": "Kristallgrotte", "start": 1562.0, "end": 1772.0},
	{"id": "fontaenen", "name": "Fontänenplatz", "start": 1772.0, "end": 2095.0},
	{"id": "klippenweg", "name": "Klippen-Abkürzung", "start": 2095.0, "end": 2414.0},
	{"id": "vorhang", "name": "Wasserfall-Vorhang", "start": 2414.0, "end": 2528.0},
	{"id": "hafen", "name": "Hafenkurve und Ziel", "start": 2528.0, "end": LENGTH},
]
const WIDTH_KEYS: Array = [
	[0.0, 16.0],
	[100.0, 16.0],
	[160.0, 13.0],
	[1200.0, 13.0],
	[1236.0, 24.0],
	[1352.0, 24.0],
	[1380.0, 13.0],
	[1860.0, 13.0],
	[1885.0, 15.0],
	[1950.0, 15.0],
	[1975.0, 13.0],
	[2062.0, 13.0],
	[2098.0, 24.0],
	[2272.0, 24.0],
	[2300.0, 13.0],
	[2700.0, 13.0],
	[2760.0, 16.0],
	[2824.0, 16.0],
]
## Beläge: 2 Planken (Anleger), 6 Küstenstein, 1 Steinbrücke, 7 Glastunnel, 3 Kristall.
const SURFACES: Array = [
	[0.0, 2],
	[128.0, 6],
	[300.0, 1],
	[330.0, 6],
	[784.0, 7],
	[1130.0, 6],
	[1580.0, 3],
	[1762.0, 6],
	[2700.0, 2],
]
const ROAD_LOOK: Dictionary = {
	"asphalt": Color("3a4048"),
	"kerb_a": Color("2fc7d8"),
	"kerb_b": Color("f4f1e6"),
	"accent": Color("7ff5ff"),
	"accent_glow": 1.4,
}
const SPLITS: Array = [
	{
		"id": "saeulengang",
		"start": 1262.0,
		"end": 1344.0,
		"lateral": -3.5,
		"half": 1.0,
		"wedge": 8.0
	},
	{"id": "klippenweg", "start": 2122.0, "end": 2264.0, "lateral": 3.5, "half": 1.2, "wedge": 9.0},
]
const TUNNELS: Array = [
	# Felsabstieg, Glasröhre unter dem Meer (wo die Röhrenkuppe unter Wasser liegt), Felsaufstieg.
	{"id": "unterwasser", "start": 786.0, "end": 1128.0, "ceiling": 9.0},
	{"id": "grotte", "start": 1580.0, "end": 1758.0, "ceiling": 13.0},
	{"id": "vorhang", "start": 2440.0, "end": 2486.0, "ceiling": 10.0},
]
const FALL_KICKER: Vector2 = Vector2(238.0, 250.0)
const FALL_STREAM: float = 302.0
const TIDE_CALL: float = 120.0
## Bildstellen für Rennbilder (kart_signature_race_regression --shots).
const SHOT_MARKS: Array = [260.0, 420.0, 900.0, 1300.0, 1660.0, 1930.0, 2200.0, 2450.0]
const THRILL_SPECS: Array = [
	{"kind": "turbo", "id": "tunnelturbo", "at": 860.0, "name": "Tiefsee-Turbo"},
	{
		"kind": "bank",
		"id": "muschelkurve",
		"at": 1500.0,
		"length": 90.0,
		"window": 10.0,
		"name": "Muschel-Steilkurve",
	},
	{"kind": "crest", "id": "hafenbuckel", "at": 2712.0, "name": "Hafenbuckel"},
]
const AMBIENCE: Array = [
	{"kind": "harbour", "metres": 40.0, "side": 24.0, "radius": 160.0, "db": -25.0},
	{"kind": "waterfall", "metres": 302.0, "side": -30.0, "radius": 170.0, "db": -20.0},
	{"kind": "surf", "metres": 450.0, "side": 40.0, "radius": 190.0, "db": -24.0},
	{"kind": "underwater", "metres": 880.0, "side": 0.0, "radius": 150.0, "db": -22.0},
	{"kind": "underwater", "metres": 1060.0, "side": 0.0, "radius": 130.0, "db": -22.0},
	{"kind": "surf", "metres": 1300.0, "side": 30.0, "radius": 170.0, "db": -25.0},
	{"kind": "grotto", "metres": 1670.0, "side": 0.0, "radius": 120.0, "db": -21.0},
	{"kind": "fountain", "metres": 1930.0, "side": 0.0, "radius": 110.0, "db": -22.0},
	{"kind": "waterfall", "metres": 2462.0, "side": 0.0, "radius": 140.0, "db": -19.0},
	{"kind": "harbour", "metres": 2760.0, "side": 24.0, "radius": 150.0, "db": -25.0},
]


static func definition() -> Dictionary:
	var names: Array[String] = []
	for section in SECTIONS:
		names.append(str(section.name))
	return {
		"id": ID,
		"name": NAME,
		"subtitle": "Versunkene Abenteuerwelt · 2,8 Kilometer",
		"accent": Color("3fd8d0"),
		"asphalt": Color("3a4048"),
		"sky": Color("4aa6e0"),
		"horizon": Color("d9f3ef"),
		"fog": Color("bfe6e4"),
		"sun": Color("fff1d6"),
		"ground": Color("8fb26e"),
		"seed": 28002611,
		"points": PackedVector3Array(),
		"length_m": LENGTH,
		"road_width_m": BASE_WIDTH,
		"section_names": names,
	}


static func action_plan(_world: Node3D) -> Dictionary:
	var result: Dictionary = {"pads": [], "gates": [], "kickers": [], "dives": [], "edges": []}
	# Wasserfall-Sprung: über das Becken, darunter trägt eine Steinbrücke die Fahrbahn weiter.
	(
		result
		. kickers
		. append(
			{
				"start": FALL_KICKER.x,
				"take_off": FALL_KICKER.y,
				"length": FALL_KICKER.y - FALL_KICKER.x,
				"height": 2.2,
				"angle": atan2(2.2, FALL_KICKER.y - FALL_KICKER.x),
				"flight_gravity": 14.0,
				"lift_bonus": 5.0,
				"max_lift": 11.0,
				"hero_flight": true,
				"landing_road_end": 368.0,
				"signature": "wasserfall",
			}
		)
	)
	for pad in [[345.0, 2.6], [560.0, -2.6], [620.0, 2.6]]:
		result.pads.append({"start": pad[0], "end": pad[0] + 6.0, "lateral": pad[1]})
	# Säulengang (enge linke Linie der Ruineninsel) und Klippenweg (enge rechte Linie).
	for start in [1276.0, 1300.0, 1324.0]:
		result.pads.append({"start": start, "end": start + 6.0, "lateral": -8.0})
	for start in [2140.0, 2172.0, 2204.0, 2236.0]:
		result.pads.append({"start": start, "end": start + 6.0, "lateral": 8.0})
	# Grotte und Zielgerade.
	for pad in [[1640.0, -2.4], [1700.0, 2.4], [2600.0, -2.4]]:
		result.pads.append({"start": pad[0], "end": pad[0] + 6.0, "lateral": pad[1]})
	return result


static func item_hazards() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{"start": FALL_KICKER.x - 50.0, "end": 372.0, "kind": "flut_wasserfall"},
	]
	for split in SPLITS:
		result.append(
			{
				"start": float(split.start) - 40.0,
				"end": float(split.end) + 20.0,
				"kind": "flut_" + str(split.id)
			}
		)
	for tunnel in TUNNELS:
		result.append(
			{
				"start": float(tunnel.start) - 20.0,
				"end": float(tunnel.end) + 10.0,
				"kind": "flut_" + str(tunnel.id)
			}
		)
	result.append({"start": 1880.0, "end": 1950.0, "kind": "flut_fontaenen"})
	return result
