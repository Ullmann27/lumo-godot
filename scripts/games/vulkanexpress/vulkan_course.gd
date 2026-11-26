extends RefCounted
## Vulkanexpress – Feuerinsel (Team B1, 26.11.2026). Fahrautorität der Strecke:
## Mittellinie, Höhen, Breiten, Beläge, Abzweige, Tunnel, Rampen, Turbofelder und
## Sperrbereiche. Bild, Licht, Klang und Ereignisse stehen in vulkan_environment.gd und
## folgen genau diesen Zahlen. Rechnung der Mittellinie: kart_signature_geometry.gd.
##
## Ablauf einer Runde (≈ 40 m/s, eine Stelle etwa alle 4–8 s, nie mehr als 10 s ohne):
##   0 s Bahnhof Feuerinsel, der Vulkanexpress fährt mit los · 7 s Lavastrom-Schanze
##   (früher Höhepunkt, Flug über den Lavafluss) · 12 s Basaltschlucht mit Lavarinnen ·
##   17 s Felsentunnel-Turbo · 22 s Hängebrücke über den Glutcanyon · 28 s Kristallgarten
##   (Abzweig: enger Kristallpfad mit Turbo oder breite Außenbahn) · 31 s der Vulkan grummelt
##   (Ansage), 36 s Ausbruch über der Kraterrand-Steilkurve · 39 s Kraterblick-Sprung ·
##   48 s Vulkanhöhle (Abzweig Lavafall-Galerie / Kristallnischen) · 55 s Dampfgeysire
##   (angekündigt, eine Hälfte immer frei) · 60 s Aschehang-Serpentine · 63 s Aschebuckel ·
##   70 s Strandkehre · 76 s Wettfahrt mit dem Express und Strandbuckel ins Ziel.
const ID: String = "vulkanexpress_3100"
const NAME: String = "Vulkanexpress"
## Eintrag im Strecken-Katalog (Menü, Cup, Zeitfahren).
const CATALOG_ENTRY: Dictionary = {
	"id": ID,
	"name": NAME,
	"tag": "FEUERINSEL · 3,1 KM",
	"color": Color("ff7a2f"),
	"description": "Lavaströme, Felsentunnel, Hängebrücke und ein Vulkan, der Feuerwerk spuckt.",
}
## Gemessene Rundenlänge (Curve3D.get_baked_length, Test prüft ±0,5 m).
const LENGTH: float = 3151.4
const BASE_WIDTH: float = 13.0
const START_HEIGHT: float = 3.0
const ENVIRONMENT: String = "res://scripts/games/vulkanexpress/vulkan_environment.gd"
const AUDIO_DIR: String = "vulkanexpress"
const SEGMENTS: Array = [
	{"s": 150.0, "h": 3.0},
	{"turn": 35.0, "r": 120.0, "ramp": 25.0, "h": 6.0},
	{"s": 210.0, "h": 10.0},
	{"turn": -40.0, "r": 90.0, "ramp": 20.0, "h": 12.0},
	{"turn": 70.0, "r": 70.0, "ramp": 20.0, "h": 15.0},
	{"s": 140.0, "h": 18.0},
	{"turn": -30.0, "r": 100.0, "ramp": 20.0, "h": 20.0},
	{"s": 120.0, "h": 22.0},
	{"turn": 80.0, "r": 60.0, "ramp": 25.0, "h": 24.0},
	{"s": 40.0},
	{"s": 160.0, "h": 26.0},
	{"turn": 45.0, "r": 110.0, "ramp": 25.0, "h": 30.0},
	{"turn": 100.0, "r": 55.0, "ramp": 25.0, "h": 38.0},
	{"s": 120.0, "h": 40.0},
	{"turn": -60.0, "r": 80.0, "ramp": 25.0, "h": 36.0},
	{"turn": 50.0, "r": 90.0, "ramp": 25.0, "h": 30.0},
	{"s": 60.0},
	{"s": 180.0, "h": 22.0},
	{"turn": -45.0, "r": 100.0, "ramp": 20.0, "h": 18.0},
	{"s": 60.0, "h": 15.0},
	{"turn": -45.0, "r": 120.0, "ramp": 20.0, "h": 13.0},
	{"turn": 40.0, "r": 60.0, "ramp": 20.0, "h": 10.0},
	{"turn": -40.0, "r": 60.0, "ramp": 20.0, "h": 8.0},
	{"s": 120.0, "h": 5.0},
	{"s": 20.0},
	{"turn": 110.0, "r": 60.0, "ramp": 25.0, "h": 3.0},
	{"free": true},
	{"turn": 90.0, "r": 80.0, "ramp": 25.0},
	{"free": true, "h": 3.0},
]
const SECTIONS: Array[Dictionary] = [
	{"id": "bahnhof", "name": "Bahnhof Feuerinsel", "start": 0.0, "end": 250.0},
	{"id": "lavastrom", "name": "Lavastrom-Schanze", "start": 250.0, "end": 460.0},
	{"id": "schlucht", "name": "Basaltschlucht", "start": 460.0, "end": 648.0},
	{"id": "tunnel", "name": "Felsentunnel", "start": 648.0, "end": 860.0},
	{"id": "bruecke", "name": "Hängebrücke", "start": 860.0, "end": 1090.0},
	{"id": "kristall", "name": "Kristallgarten", "start": 1090.0, "end": 1400.0},
	{"id": "krater", "name": "Kraterrand", "start": 1400.0, "end": 1854.0},
	{"id": "hoehle", "name": "Vulkanhöhle", "start": 1854.0, "end": 2194.0},
	{"id": "geysire", "name": "Dampfgeysire", "start": 2194.0, "end": 2368.0},
	{"id": "aschehang", "name": "Aschehang", "start": 2368.0, "end": 2632.0},
	{"id": "strand", "name": "Strandkehre", "start": 2632.0, "end": 2987.0},
	{"id": "ziel", "name": "Wettfahrt zum Ziel", "start": 2987.0, "end": LENGTH},
]
## Fahrbahnbreite [Meter, Breite]: Startaufstellung, Brücke, zwei Abzweige, Geysirfeld.
const WIDTH_KEYS: Array = [
	[0.0, 16.0],
	[110.0, 16.0],
	[170.0, 13.0],
	[840.0, 13.0],
	[862.0, 12.0],
	[978.0, 12.0],
	[1000.0, 13.0],
	[1100.0, 13.0],
	[1138.0, 24.0],
	[1282.0, 24.0],
	[1318.0, 13.0],
	[1880.0, 13.0],
	[1918.0, 22.0],
	[2084.0, 22.0],
	[2118.0, 13.0],
	[2170.0, 13.0],
	[2192.0, 15.0],
	[2262.0, 15.0],
	[2290.0, 13.0],
	[2950.0, 13.0],
	[3010.0, 16.0],
	[3152.0, 16.0],
]
## Beläge (kart_signature_road.gdshader): 0 Basalt, 1 Steinbrücke, 2 Planken, 3 Obsidian.
const SURFACES: Array = [
	[0.0, 0],
	[318.0, 1],
	[362.0, 0],
	[658.0, 3],
	[782.0, 0],
	[858.0, 2],
	[982.0, 0],
	[1140.0, 3],
	[1280.0, 0],
	[1916.0, 3],
	[2092.0, 0],
]
const ROAD_LOOK: Dictionary = {
	"asphalt": Color("2a2629"),
	"kerb_a": Color("e8512b"),
	"kerb_b": Color("f3ece0"),
	"accent": Color("ff9a3c"),
	"accent_glow": 1.3,
}
## Abzweige: Trennwand (Querlage, halbe Dicke) zwischen enger Turbo-Linie und breiter Bahn.
const SPLITS: Array = [
	{
		"id": "kristallgarten",
		"start": 1150.0,
		"end": 1268.0,
		"lateral": 3.5,
		"half": 1.2,
		"wedge": 9.0
	},
	{"id": "hoehle", "start": 1944.0, "end": 2062.0, "lateral": -3.0, "half": 1.0, "wedge": 8.0},
]
## Tunnel und Höhle: die Kamera bleibt unter der Decke (Meter über der Fahrbahn).
const TUNNELS: Array = [
	{"id": "felsentunnel", "start": 662.0, "end": 778.0, "ceiling": 9.0},
	{"id": "vulkanhoehle", "start": 1922.0, "end": 2086.0, "ceiling": 15.0},
]
## Lavastrom-Schanze: früher Höhepunkt, Flug über den Lavafluss (Steinbogen darunter).
const LAVA_KICKER: Vector2 = Vector2(290.0, 302.0)
const LAVA_RIVER: float = 345.0
const BRIDGE: Vector2 = Vector2(862.0, 978.0)
## Ausbruch: Ansage bei ERUPTION_CALL, Ausbruch ab ERUPTION_START (Runde 1 und 2).
const ERUPTION_CALL: float = 1240.0
const ERUPTION_START: float = 1420.0
## Bildstellen für Rennbilder (kart_signature_race_regression --shots).
const SHOT_MARKS: Array = [300.0, 920.0, 1200.0, 1500.0, 2000.0, 2236.0, 3000.0]
## Spannungsstellen (kart_track_thrills.gd liest sie): eine Steilkurve am Kraterrand,
## Kuppensprünge mit durchgehender Fahrbahn darunter und der Turbo im Felsentunnel.
const THRILL_SPECS: Array = [
	{"kind": "turbo", "id": "felsentunnel", "at": 676.0, "name": "Felsentunnel-Turbo"},
	{
		"kind": "bank",
		"id": "kraterkurve",
		"at": 1462.0,
		"length": 90.0,
		"window": 10.0,
		"name": "Kraterrand-Steilkurve",
	},
	{
		"kind": "crest",
		"id": "kraterblick",
		"at": 1556.0,
		"name": "Kraterblick-Sprung",
		"hero": true,
		"height": 1.6
	},
	{"kind": "crest", "id": "aschebuckel", "at": 2512.0, "name": "Aschebuckel"},
	{"kind": "crest", "id": "strandbuckel", "at": 3036.0, "name": "Strandbuckel"},
]
## Klanginseln (assets/audio/kart/signature/vulkanexpress/*.ogg).
const AMBIENCE: Array = [
	{"kind": "surf", "metres": 60.0, "side": -40.0, "radius": 170.0, "db": -24.0},
	{"kind": "lava", "metres": 345.0, "side": 0.0, "radius": 150.0, "db": -22.0},
	{"kind": "lava", "metres": 560.0, "side": 14.0, "radius": 120.0, "db": -26.0},
	{"kind": "cave", "metres": 720.0, "side": 0.0, "radius": 90.0, "db": -24.0},
	{"kind": "lava", "metres": 920.0, "side": 0.0, "radius": 140.0, "db": -22.0},
	{"kind": "lava", "metres": 1460.0, "side": 40.0, "radius": 160.0, "db": -24.0},
	{"kind": "cave", "metres": 2000.0, "side": 0.0, "radius": 120.0, "db": -22.0},
	{"kind": "steam", "metres": 2236.0, "side": -6.0, "radius": 110.0, "db": -23.0},
	{"kind": "surf", "metres": 2800.0, "side": -30.0, "radius": 190.0, "db": -23.0},
]


static func definition() -> Dictionary:
	var names: Array[String] = []
	for section in SECTIONS:
		names.append(str(section.name))
	return {
		"id": ID,
		"name": NAME,
		"subtitle": "Feuerinsel · 3,1 Kilometer",
		"accent": Color("ff7a2f"),
		"asphalt": Color("2a2629"),
		"sky": Color("3d5f93"),
		"horizon": Color("f5a66b"),
		"fog": Color("8c6a62"),
		"sun": Color("ffd2a1"),
		"ground": Color("3a3234"),
		"seed": 31002611,
		"points": PackedVector3Array(),
		"length_m": LENGTH,
		"road_width_m": BASE_WIDTH,
		"section_names": names,
	}


## Turbofelder und Schanzen im Format von kart_action_course (Spannungsstellen ergänzt
## kart_track_thrills: Steilkurve, Kuppen, Tunnel-Turbo).
static func action_plan(_world: Node3D) -> Dictionary:
	var result: Dictionary = {"pads": [], "gates": [], "kickers": [], "dives": [], "edges": []}
	(
		result
		. kickers
		. append(
			{
				"start": LAVA_KICKER.x,
				"take_off": LAVA_KICKER.y,
				"length": LAVA_KICKER.y - LAVA_KICKER.x,
				"height": 2.2,
				"angle": atan2(2.2, LAVA_KICKER.y - LAVA_KICKER.x),
				"flight_gravity": 14.0,
				"lift_bonus": 5.0,
				"max_lift": 11.0,
				"hero_flight": true,
				"landing_road_end": 440.0,
				"signature": "lavastrom",
			}
		)
	)
	# Landung: zwei versetzte Felder belohnen die gerade Landung.
	for pad in [[412.0, -2.6], [436.0, 2.6]]:
		result.pads.append({"start": pad[0], "end": pad[0] + 6.0, "lateral": pad[1]})
	# Basaltschlucht: Innenlinie der Kurven.
	for pad in [[515.0, 2.8], [600.0, -2.8]]:
		result.pads.append({"start": pad[0], "end": pad[0] + 6.0, "lateral": pad[1]})
	# Kristallpfad (enge rechte Linie des Kristallgartens): drei Felder hintereinander.
	for start in [1178.0, 1206.0, 1234.0]:
		result.pads.append({"start": start, "end": start + 6.0, "lateral": 8.0})
	# Lavafall-Galerie (enge linke Linie der Höhle).
	for start in [1972.0, 2000.0, 2028.0]:
		result.pads.append({"start": start, "end": start + 6.0, "lateral": -7.0})
	# Strandkehre und Zielgerade.
	for pad in [[2700.0, 2.5], [2900.0, 2.5], [3002.0, -2.4]]:
		result.pads.append({"start": pad[0], "end": pad[0] + 6.0, "lateral": pad[1]})
	return result


## Sperrbereiche für die Sammelzonen: Schanze samt Flug, Brücke, Abzweige, Höhle, Geysire.
static func item_hazards() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{"start": LAVA_KICKER.x - 50.0, "end": 445.0, "kind": "vulkan_lavastrom"},
		{"start": BRIDGE.x - 20.0, "end": BRIDGE.y + 10.0, "kind": "vulkan_bruecke"},
	]
	for split in SPLITS:
		result.append(
			{
				"start": float(split.start) - 40.0,
				"end": float(split.end) + 20.0,
				"kind": "vulkan_" + str(split.id)
			}
		)
	for tunnel in TUNNELS:
		result.append(
			{
				"start": float(tunnel.start) - 20.0,
				"end": float(tunnel.end) + 10.0,
				"kind": "vulkan_" + str(tunnel.id)
			}
		)
	result.append({"start": 2170.0, "end": 2250.0, "kind": "vulkan_geysire"})
	return result


static func section_at(distance: float) -> int:
	var d: float = fposmod(distance, LENGTH)
	for i in range(SECTIONS.size()):
		if d < float(SECTIONS[i].end):
			return i
	return SECTIONS.size() - 1
