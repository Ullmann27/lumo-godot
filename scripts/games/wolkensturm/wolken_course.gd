extends RefCounted
## Wolkensturm – Himmelsmetropole (Team B1, 26.11.2026). Fahrautorität der Strecke:
## Mittellinie, Höhen, Breiten, Beläge, Abzweig, Glastunnel, Schanzen, Turbofelder,
## Sperrbereiche. Die Stadt schwebt auf Inseln über einem Wolkenmeer (Wolkendecke 82 m);
## die Fahrbahn liegt zwischen 86 und 118 m. Bild, Klang und Ereignisse: wolken_environment.gd.
##
## Ablauf einer Runde (≈ 50 m/s, eine Stelle etwa alle 3–7 s):
##   0 s Wolkenhafen zwischen Hochhäusern · 7 s Wolkensprung (früher Höhepunkt: Flug über die
##   Kante, Landung auf der Holo-Rampe hinab in die Wolkendecke) · 13 s Glastunnel durch den
##   Atrium-Turm mit Turbo · 18 s Holobrücke zwischen schwebenden Plattformen · 22 s Windkanal
##   (Aufwind-Schanze, Rückenwind-Turbos) · 28 s Sternenturm-Spirale (zwei Ebenen übereinander)
##   · 38 s Skyline-Sprung · 43 s Sturm-Steilkurve · 46 s Skyway-Gabel (Lobby-Abkürzung mit
##   Turbo oder breite Außenbahn) · 52 s Wolkentauchgang in Schlangenlinien · 58 s Lufttaxi-
##   Kreuzung (angekündigt, eine Seite immer frei) · 64 s Zielkurve. Gewitter in der Ferne:
##   Blitz zuerst, Donner um Entfernung/343 m/s später; in Runde 2 zieht die Front vorbei.
const ID: String = "wolkensturm_3300"
const NAME: String = "Wolkensturm"
const CATALOG_ENTRY: Dictionary = {
	"id": ID,
	"name": NAME,
	"tag": "HIMMELSMETROPOLE · 3,3 KM",
	"color": Color("5ff0ff"),
	"description": "Glastunnel, Holobrücken, Turmspirale und Blitze überm Wolkenmeer.",
}
## Gemessene Rundenlänge (Curve3D.get_baked_length, Test prüft ±0,5 m).
const LENGTH: float = 3323.4
const BASE_WIDTH: float = 13.0
const START_HEIGHT: float = 100.0
const CLOUD_DECK: float = 82.0
const ENVIRONMENT: String = "res://scripts/games/wolkensturm/wolken_environment.gd"
const AUDIO_DIR: String = "wolkensturm"
const SEGMENTS: Array = [
	{"s": 140.0, "h": 100.0},
	{"turn": 30.0, "r": 150.0, "ramp": 25.0, "h": 102.0},
	{"s": 120.0, "h": 105.0},
	{"s": 170.0, "h": 87.0},
	{"turn": 60.0, "r": 80.0, "ramp": 20.0, "h": 86.0},
	{"s": 130.0, "h": 90.0},
	{"turn": 40.0, "r": 120.0, "ramp": 20.0, "h": 94.0},
	{"s": 120.0, "h": 96.0},
	{"turn": -40.0, "r": 90.0, "ramp": 20.0, "h": 97.0},
	{"s": 160.0, "h": 98.0},
	{"turn": 90.0, "r": 70.0, "ramp": 20.0, "h": 98.0},
	{"s": 40.0, "h": 98.0},
	{"turn": 360.0, "r": 52.0, "ramp": 25.0, "h": 116.0},
	{"s": 80.0, "h": 118.0},
	{"turn": -30.0, "r": 100.0, "ramp": 20.0, "h": 118.0},
	{"s": 130.0, "h": 116.0},
	{"turn": 30.0, "r": 100.0, "ramp": 20.0, "h": 114.0},
	{"turn": 90.0, "r": 60.0, "ramp": 20.0, "h": 112.0},
	{"s": 60.0, "h": 110.0},
	{"s": 160.0, "h": 108.0},
	{"turn": -30.0, "r": 90.0, "ramp": 20.0, "h": 105.0},
	{"s": 90.0, "h": 103.0},
	{"turn": 30.0, "r": 90.0, "ramp": 20.0, "h": 100.0},
	{"turn": 35.0, "r": 85.0, "ramp": 20.0, "h": 94.0},
	{"turn": -35.0, "r": 85.0, "ramp": 20.0, "h": 92.0},
	{"free": true},
	{"turn": 90.0, "r": 80.0, "ramp": 25.0, "h": 97.0},
	{"free": true, "h": 100.0},
]
const SECTIONS: Array[Dictionary] = [
	{"id": "hafen", "name": "Wolkenhafen", "start": 0.0, "end": 244.0},
	{"id": "sprung", "name": "Wolkensprung", "start": 244.0, "end": 535.0},
	{"id": "glastunnel", "name": "Glastunnel", "start": 535.0, "end": 769.0},
	{"id": "holo", "name": "Holobrücke", "start": 769.0, "end": 1077.0},
	{"id": "wind", "name": "Windkanal", "start": 1077.0, "end": 1407.0},
	{"id": "spirale", "name": "Sternenturm-Spirale", "start": 1407.0, "end": 1759.0},
	{"id": "skyline", "name": "Skyline", "start": 1759.0, "end": 2113.0},
	{"id": "steilkurve", "name": "Sturm-Steilkurve", "start": 2113.0, "end": 2265.0},
	{"id": "gabel", "name": "Skyway-Gabel", "start": 2265.0, "end": 2515.0},
	{"id": "wolken", "name": "Wolkentauchgang", "start": 2515.0, "end": 2816.0},
	{"id": "taxi", "name": "Lufttaxi-Kreuzung", "start": 2816.0, "end": 3084.0},
	{"id": "ziel", "name": "Zielkurve", "start": 3084.0, "end": LENGTH},
]
const WIDTH_KEYS: Array = [
	[0.0, 16.0],
	[110.0, 16.0],
	[170.0, 13.0],
	[2262.0, 13.0],
	[2292.0, 24.0],
	[2440.0, 24.0],
	[2470.0, 13.0],
	[2940.0, 13.0],
	[2962.0, 15.0],
	[3030.0, 15.0],
	[3050.0, 13.0],
	[3250.0, 13.0],
	[3300.0, 16.0],
	[3324.0, 16.0],
]
## Beläge: 5 Skyway-Metall, 4 Holo-Glas, 7 Glastunnel, 8 Wolkenstraße, 0 Asphalt.
const SURFACES: Array = [
	[0.0, 0],
	[244.0, 5],
	[364.0, 4],
	[500.0, 5],
	[645.0, 7],
	[762.0, 5],
	[873.0, 4],
	[993.0, 5],
	[1407.0, 0],
	[1759.0, 5],
	[2515.0, 8],
	[2816.0, 5],
	[3084.0, 0],
]
const ROAD_LOOK: Dictionary = {
	"asphalt": Color("2a3046"),
	"kerb_a": Color("ff4fd8"),
	"kerb_b": Color("f2f6ff"),
	"accent": Color("5ff0ff"),
	"accent_glow": 1.6,
}
const SPLITS: Array = [
	{"id": "gabel", "start": 2302.0, "end": 2430.0, "lateral": -3.5, "half": 1.0, "wedge": 9.0},
]
const TUNNELS: Array = [
	{"id": "glastunnel", "start": 646.0, "end": 762.0, "ceiling": 9.5},
]
const JUMP_KICKER: Vector2 = Vector2(330.0, 342.0)
const WIND_KICKER: Vector2 = Vector2(1090.0, 1102.0)
const HELIX: Vector2 = Vector2(1407.0, 1759.0)
const HOLO_BRIDGE: Vector2 = Vector2(873.0, 993.0)
const STORM_CALL: float = 2100.0
## Bildstellen für Rennbilder (kart_signature_race_regression --shots).
const SHOT_MARKS: Array = [350.0, 700.0, 930.0, 1150.0, 1600.0, 2360.0, 2650.0, 3000.0]
const THRILL_SPECS: Array = [
	{"kind": "turbo", "id": "glastunnel", "at": 660.0, "name": "Glastunnel-Turbo"},
	{
		"kind": "crest",
		"id": "skyline",
		"at": 1925.0,
		"name": "Skyline-Sprung",
		"hero": true,
		"height": 1.6
	},
	{
		"kind": "bank",
		"id": "sturmkurve",
		"at": 2170.0,
		"length": 90.0,
		"window": 10.0,
		"name": "Sturm-Steilkurve",
	},
	{"kind": "crest", "id": "wolkenkante", "at": 2836.0, "name": "Wolkenkante"},
]
const AMBIENCE: Array = [
	{"kind": "city", "metres": 60.0, "side": -30.0, "radius": 170.0, "db": -26.0},
	{"kind": "wind", "metres": 420.0, "side": 0.0, "radius": 170.0, "db": -24.0},
	{"kind": "city", "metres": 700.0, "side": 0.0, "radius": 120.0, "db": -24.0},
	{"kind": "hum", "metres": 930.0, "side": 0.0, "radius": 120.0, "db": -26.0},
	{"kind": "wind", "metres": 1160.0, "side": 0.0, "radius": 160.0, "db": -21.0},
	{"kind": "city", "metres": 1580.0, "side": -52.0, "radius": 180.0, "db": -25.0},
	{"kind": "wind", "metres": 2170.0, "side": 30.0, "radius": 160.0, "db": -23.0},
	{"kind": "hum", "metres": 2360.0, "side": -6.0, "radius": 110.0, "db": -26.0},
	{"kind": "wind", "metres": 2680.0, "side": 0.0, "radius": 190.0, "db": -22.0},
	{"kind": "city", "metres": 3010.0, "side": 20.0, "radius": 160.0, "db": -26.0},
]


static func definition() -> Dictionary:
	var names: Array[String] = []
	for section in SECTIONS:
		names.append(str(section.name))
	return {
		"id": ID,
		"name": NAME,
		"subtitle": "Himmelsmetropole · 3,3 Kilometer",
		"accent": Color("5ff0ff"),
		"asphalt": Color("2a3046"),
		"sky": Color("3e86d8"),
		"horizon": Color("d8ecff"),
		"fog": Color("c9dcf2"),
		"sun": Color("fff3dc"),
		"ground": Color("e9f1fb"),
		"seed": 33002611,
		"points": PackedVector3Array(),
		"length_m": LENGTH,
		"road_width_m": BASE_WIDTH,
		"section_names": names,
	}


static func _kicker(
	at: Vector2, height: float, gravity: float, bonus: float, cap: float, land: float, tag: String
) -> Dictionary:
	return {
		"start": at.x,
		"take_off": at.y,
		"length": at.y - at.x,
		"height": height,
		"angle": atan2(height, at.y - at.x),
		"flight_gravity": gravity,
		"lift_bonus": bonus,
		"max_lift": cap,
		"hero_flight": true,
		"landing_road_end": land,
		"signature": tag,
	}


static func action_plan(_world: Node3D) -> Dictionary:
	var result: Dictionary = {"pads": [], "gates": [], "kickers": [], "dives": [], "edges": []}
	# Wolkensprung: über die Inselkante, die Fahrbahn fällt danach in die Wolken ab.
	result.kickers.append(_kicker(JUMP_KICKER, 2.2, 14.0, 5.0, 11.0, 520.0, "wolkensprung"))
	# Aufwind-Schanze: der Windkanal trägt das Kart länger (geringere Fallbeschleunigung).
	result.kickers.append(_kicker(WIND_KICKER, 2.0, 12.0, 4.0, 8.0, 1225.0, "aufwind"))
	# Rückenwind: drei versetzte Felder nach der Landung im Windkanal.
	for pad in [[1188.0, -2.4], [1204.0, 2.4], [1220.0, -2.4]]:
		result.pads.append({"start": pad[0], "end": pad[0] + 6.0, "lateral": pad[1]})
	# Holobrücke: Mittelfeld, danach ein Feld auf der Außenlinie.
	for pad in [[905.0, 0.0], [955.0, 2.6]]:
		result.pads.append({"start": pad[0], "end": pad[0] + 6.0, "lateral": pad[1]})
	# Spirale: Außenlinie belohnt (Turbo außen in der oberen Windung).
	for pad in [[1610.0, 3.0], [1660.0, 3.0]]:
		result.pads.append({"start": pad[0], "end": pad[0] + 6.0, "lateral": pad[1]})
	# Lobby-Abkürzung (enge linke Linie der Skyway-Gabel).
	for start in [2328.0, 2356.0, 2384.0]:
		result.pads.append({"start": start, "end": start + 6.0, "lateral": -8.0})
	# Wolkentauchgang und Zielkurve.
	for pad in [[2560.0, 2.4], [2780.0, -2.4], [3150.0, 2.6]]:
		result.pads.append({"start": pad[0], "end": pad[0] + 6.0, "lateral": pad[1]})
	return result


static func item_hazards() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{"start": JUMP_KICKER.x - 50.0, "end": 530.0, "kind": "wolken_sprung"},
		{"start": WIND_KICKER.x - 40.0, "end": 1235.0, "kind": "wolken_aufwind"},
		{"start": HELIX.x - 10.0, "end": HELIX.y + 10.0, "kind": "wolken_spirale"},
		{"start": HOLO_BRIDGE.x - 10.0, "end": HOLO_BRIDGE.y + 10.0, "kind": "wolken_holobruecke"},
	]
	for split in SPLITS:
		result.append(
			{
				"start": float(split.start) - 40.0,
				"end": float(split.end) + 20.0,
				"kind": "wolken_" + str(split.id)
			}
		)
	for tunnel in TUNNELS:
		result.append(
			{
				"start": float(tunnel.start) - 20.0,
				"end": float(tunnel.end) + 10.0,
				"kind": "wolken_" + str(tunnel.id)
			}
		)
	result.append({"start": 2950.0, "end": 3020.0, "kind": "wolken_taxi"})
	return result
