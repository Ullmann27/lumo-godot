extends RefCounted
## Strecken 2.0: Spannungsstellen, die ein Kind später beschreiben kann („die Strecke, wo ich
## rechts über die Lava gesprungen bin“). Eigene LUMO-Bausteine, alle auf der FERTIG
## geglätteten Fahrbahn geplant (lokale Rundendistanz, Meter):
##
##   crest  Kuppensprung über die ganze Breite. Wird als Schanze in world.action.kickers
##          eingetragen, damit Spieler, Rivalen (kart_rival_flight) und Rücksetzer dieselbe
##          Flugrechnung nutzen. Kein Spalt dahinter: jedes Tempo ist sicher.
##   leap   Spalt-Schanze mit sicherer Umfahrung: auf einer Fahrbahnhälfte (mutige Linie)
##          eine Rampe und dahinter ein Spalt (Lava, Wasser, Gletscherspalte …); die andere
##          Hälfte (sichere Linie) bleibt durchgehend Straße. Wer zu langsam abspringt oder
##          neben die Rampe fährt, fällt und wird von der Lumo-Wolke hinter den Spalt getragen.
##   bank   Steilkurve: die vorhandene Kurve wird stärker überhöht (Rollwinkel bis BANK_LIMIT).
##   turbo  Tempo-Passage: drei Turbo-Felder hintereinander unter leuchtenden Bögen.
##
## Rechnung (Container, Schwerkraft im Flug 30 m/s², Hub = v·sin(Winkel) + Bonus, gedeckelt):
##   leap: Rampe 10 m / 1,5 m (8,5°), Bonus 2,0, Deckel 6,0, Spalt 10 m.
##     Nötige Flugweite = Spalt 10 m + halbe Kartlänge 1,24 m + 1,0 m Reserve = 12,24 m.
##     t(v) = (vz + √(vz² + 2·30·1,5)) / 30, Weite = v·cos(8,5°)·t.
##     v = 24 m/s: vz = 5,55 → t = 0,55 s → 13,1 m (reicht); v = 20 m/s → 10,3 m (zu kurz).
##     Mindesttempo daher ≈ 23 m/s (83 km/h), min_clear_speed() rechnet es je Stelle genau.
##     Volles Tempo (Kind 48 m/s, Eigentempo 1,17 → ~55 m/s): vz = 6,0 (Deckel), t = 0,58 s,
##     Weite ≈ 31 m. Langsamstes Kart (boru_rally) Spitze 46,5 m/s → ≈ 26 m.
##     Reserve bei normaler Fahrt: Faktor ≥ 2 über der nötigen Weite.
##   crest: Anlauf 16 m, 1,3 m hoch, quadratisch (Lippe 9,2°), Bonus 2,2, Deckel 6,0:
##     ab ~25 m/s fliegt jedes Kart ≈ 0,56 s (Landungsturbo ab 0,35 s Flug).
##   hero crest (Fernblick): Schwerkraft 20, Deckel 7,5 → ≈ 0,85 s Flug, ≈ 40 m bei 48 m/s;
##     die Landebahn wird beim Planen auf 55 m Geradeauslauf geprüft.

const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const META: String = "thrill_plan"
const OFF_META: String = "thrills_off"
const ROAD_HALF: float = 5.4
const LEAP_INNER: float = 1.3
const LEAP_OUTER: float = 5.45
const LEAP_RAMP_LENGTH: float = 10.0
const LEAP_RAMP_HEIGHT: float = 1.5
const LEAP_GAP_LENGTH: float = 10.0
## Frühester Absprung einer Spalt-Schanze (Streckenmeter ab Start).
const LEAP_MIN_START: float = 350.0
## Abstand des Rettungspunkts zum nächsten Checkpoint-Tor (Meter).
const LEAP_SECTION_MARGIN: float = 4.0
const LEAP_LIFT_BONUS: float = 2.0
const LEAP_MAX_LIFT: float = 6.0
const FLIGHT_GRAVITY: float = 30.0
const FALL_MARGIN: float = 0.2
const KART_HALF_LENGTH: float = 1.24
const LANDING_RESERVE_M: float = 1.0
const CREST_LENGTH: float = 16.0
const CREST_HEIGHT: float = 1.3
const CREST_BACK: float = 9.0
const BANK_GAIN: float = 13.0
const BANK_LIMIT: float = PI / 5.0
const BANK_STEP: float = 2.0
const SIGN_LEAD_M: float = 120.0
const TURBO_SPACING: float = 22.0

## Thema der Spalt-Schanze: Farbe der Tiefe und des Leuchtens, Name.
const THEMES: Dictionary = {
	"lava": {"deep": Color("ff5a12"), "glow": Color("ffb347"), "wall": Color("2a1a1a")},
	"water": {"deep": Color("1f9fd0"), "glow": Color("7ff0ff"), "wall": Color("2f4a3a")},
	"ice": {"deep": Color("5fc8ff"), "glow": Color("d8f6ff"), "wall": Color("8fb4cc")},
	"chasm": {"deep": Color("3a2a1c"), "glow": Color("ffd27a"), "wall": Color("b98b52")},
	"crystal": {"deep": Color("8f5cff"), "glow": Color("e2c9ff"), "wall": Color("3b2d6b")},
	"candy": {"deep": Color("7a3b1c"), "glow": Color("ff9ad8"), "wall": Color("f6d2e8")},
	"void": {"deep": Color("2a1a8e"), "glow": Color("b8a4ff"), "wall": Color("141038")},
	"plasma": {"deep": Color("18c9a8"), "glow": Color("9cfff0"), "wall": Color("1d3d4a")},
	"neon": {"deep": Color("2a5cff"), "glow": Color("6ee4f4"), "wall": Color("17203a")},
	"fairy": {"deep": Color("2fb7a0"), "glow": Color("b8ffe6"), "wall": Color("2d4a3a")},
	"cloud": {"deep": Color("8fa6ff"), "glow": Color("e6ecff"), "wall": Color("3a4c98")},
}

## Je Strecke: Wunschlage (m, negativ = vor dem Ziel) – die Planung rückt jede Stelle auf den
## nächsten freien, ausreichend geraden Abschnitt. Fehlt eine Strecke, bleibt sie unverändert.
const SPECS: Dictionary = {
	"sonnenhafen":
	[
		{"kind": "bank", "id": "werftkurve", "name": "Werftkurve", "at": 900.0, "length": 86.0, "window": 650.0},
	],
	"jungle_emerald_3600":
	[
		{"kind": "crest", "id": "startwurzel", "at": 180.0, "name": "Start-Wurzel"},
		{"kind": "crest", "id": "flussbuckel", "at": 720.0, "name": "Fluss-Buckel"},
		{"kind": "crest", "id": "wurzelkuppe", "at": 1300.0, "name": "Wurzelkuppe"},
		{
			"kind": "crest",
			"id": "lianenkuppe",
			"at": 1620.0,
			"name": "Lianen-Kuppe",
			"hero": true,
			"height": 1.6
		},
		{"kind": "crest", "id": "tempelkuppe", "at": 2010.0, "name": "Tempel-Kuppe"},
		{"kind": "crest", "id": "ruinenbuckel", "at": 2420.0, "name": "Ruinen-Buckel"},
		{
			"kind": "crest",
			"id": "kronenflug",
			"at": 2900.0,
			"name": "Kronen-Flug",
			"hero": true,
			"height": 1.6
		},
		{"kind": "turbo", "id": "lianenbahn", "at": 3150.0, "name": "Lianen-Turbo"},
		{"kind": "crest", "id": "zielwurzel", "at": 3400.0, "name": "Ziel-Wurzel"},
		{"kind": "bank", "id": "kapokkurve", "name": "Kapokkurve", "at": 1040.0, "length": 88.0, "window": 600.0},
	],
	"zauberwald":
	[
		{"kind": "crest", "id": "startkuppe", "at": 260.0, "name": "Moos-Kuppe"},
		{
			"kind": "leap",
			"id": "feenbach",
			"at": 480.0,
			"side": 1.0,
			"theme": "fairy",
			"name": "Feenbach-Sprung"
		},
		{"kind": "crest", "id": "wurzelkuppe", "at": 680.0, "name": "Wurzelkuppe"},
		{"kind": "turbo", "id": "wurzeltunnel", "at": 1110.0, "name": "Wurzeltunnel-Turbo"},
		{
			"kind": "crest",
			"id": "gluehwuermchen",
			"at": 1500.0,
			"name": "Glühwürmchen-Kuppe",
			"hero": true,
			"height": 1.6
		},
		{
			"kind": "bank",
			"id": "feenkurve",
			"at": 1735.0,
			"length": 90.0,
			"window": 40.0,
			"name": "Feenkurve"
		},
		{"kind": "crest", "id": "zielkuppe", "at": -150.0, "name": "Zielkuppe"},
	],
	"bergwelt":
	[
		{"kind": "crest", "id": "startwolke", "at": 160.0, "name": "Startwolke"},
		{"kind": "crest", "id": "wolkenbuckel", "at": 480.0, "name": "Wolkenbuckel"},
		{
			"kind": "leap",
			"id": "wolkenspalt",
			"at": 740.0,
			"side": -1.0,
			"theme": "cloud",
			"name": "Wolkenspalt-Sprung"
		},
		{"kind": "turbo", "id": "sternenhoehle", "at": 1250.0, "name": "Höhlen-Turbo"},
		{
			"kind": "crest",
			"id": "inselflug",
			"at": 1520.0,
			"name": "Insel-Flug",
			"hero": true,
			"height": 1.6
		},
		{
			"kind": "bank",
			"id": "sternkurve",
			"at": 1740.0,
			"length": 90.0,
			"window": 30.0,
			"name": "Sternkurve"
		},
		{"kind": "crest", "id": "zielwolke", "at": 1885.0, "name": "Zielwolke"},
	],
	"holo_city":
	[
		{"kind": "turbo", "id": "aurora", "at": 380.0, "name": "Aurora-Turbo"},
		{"kind": "crest", "id": "neonbuckel", "at": 640.0, "name": "Neon-Buckel"},
		{
			"kind": "leap",
			"id": "datenkluft",
			"at": 900.0,
			"side": -1.0,
			"theme": "neon",
			"name": "Datenkluft-Sprung"
		},
		{"kind": "crest", "id": "datenwelle", "at": 1120.0, "name": "Datenwelle"},
		{
			"kind": "crest",
			"id": "skyline",
			"at": 1440.0,
			"name": "Skyline-Flug",
			"hero": true,
			"height": 1.6
		},
		{
			"kind": "bank",
			"id": "neonkurve",
			"at": 1720.0,
			"length": 90.0,
			"window": 30.0,
			"name": "Neonkurve"
		},
		{"kind": "crest", "id": "zielrampe", "at": 1885.0, "name": "Ziel-Buckel"},
	],
	"crystal_canyon":
	[
		{"kind": "turbo", "id": "grotte", "at": 120.0, "name": "Grotten-Turbo"},
		{"kind": "crest", "id": "geode", "at": 690.0, "name": "Geoden-Kuppe"},
		{
			"kind": "crest",
			"id": "amethystflug",
			"at": 1000.0,
			"name": "Amethyst-Flug",
			"hero": true,
			"height": 1.6
		},
		{
			"kind": "leap",
			"id": "kristallschlucht",
			"at": 1430.0,
			"side": 1.0,
			"theme": "crystal",
			"name": "Kristallschlucht-Sprung"
		},
		{
			"kind": "bank",
			"id": "kristallkurve",
			"at": 1560.0,
			"length": 90.0,
			"window": 30.0,
			"name": "Kristallkurve"
		},
		{"kind": "crest", "id": "zielkristall", "at": 1860.0, "name": "Ziel-Kuppe"},
	],
	"jungle_temple":
	[
		{"kind": "crest", "id": "wurzelbuckel", "at": 200.0, "name": "Wurzelbuckel"},
		{
			"kind": "leap",
			"id": "tempelfluss",
			"at": 564.0,
			"side": -1.0,
			"theme": "water",
			"name": "Tempelfluss-Sprung"
		},
		{"kind": "crest", "id": "ruinenkuppe", "at": 740.0, "name": "Ruinen-Kuppe"},
		{"kind": "turbo", "id": "tempelgang", "at": 900.0, "name": "Tempelgang-Turbo"},
		{
			"kind": "bank",
			"id": "lianenkurve",
			"at": 1400.0,
			"length": 90.0,
			"window": 30.0,
			"name": "Lianenkurve"
		},
		{"kind": "crest", "id": "schlangenbuckel", "at": 1540.0, "name": "Schlangenbuckel"},
		{
			"kind": "crest",
			"id": "tempelfinale",
			"at": 1760.0,
			"name": "Tempel-Finale",
			"hero": true,
			"height": 1.6
		},
	],
	"candy_cloud":
	[
		{"kind": "crest", "id": "zuckerkuppe", "at": 235.0, "name": "Zuckerkuppe"},
		{
			"kind": "leap",
			"id": "schokofluss",
			"at": 560.0,
			"side": 1.0,
			"theme": "candy",
			"name": "Schokofluss-Sprung"
		},
		{
			"kind": "bank",
			"id": "bonbonkurve",
			"at": 710.0,
			"length": 90.0,
			"window": 30.0,
			"name": "Bonbonkurve"
		},
		{"kind": "turbo", "id": "bonbon", "at": 1100.0, "name": "Bonbon-Turbo"},
		{
			"kind": "crest",
			"id": "regenbogen",
			"at": 1750.0,
			"name": "Regenbogen-Flug",
			"hero": true,
			"height": 1.6
		},
	],
	"volcano_night":
	[
		{"kind": "turbo", "id": "glutstollen", "at": 300.0, "name": "Glutstollen-Turbo"},
		{"kind": "crest", "id": "basaltbuckel", "at": 680.0, "name": "Basaltbuckel"},
		{
			"kind": "bank",
			"id": "feuerkurve",
			"at": 840.0,
			"length": 80.0,
			"window": 25.0,
			"name": "Feuerkurve"
		},
		{
			"kind": "crest",
			"id": "vulkanflug",
			"at": 1130.0,
			"name": "Vulkan-Flug",
			"hero": true,
			"height": 1.6
		},
		{
			"kind": "leap",
			"id": "lavastrom",
			"at": 1278.0,
			"side": 1.0,
			"theme": "lava",
			"name": "Lavastrom-Sprung"
		},
		{
			"kind": "leap",
			"id": "glutspalt",
			"at": 1800.0,
			"side": -1.0,
			"theme": "lava",
			"name": "Glutspalt-Finale"
		},
	],
	"winter_sprint":
	[
		{"kind": "turbo", "id": "kristallhoehle", "at": 300.0, "name": "Kristallhöhlen-Turbo"},
		{"kind": "crest", "id": "schneebuckel", "at": 480.0, "name": "Schneebuckel"},
		{
			"kind": "crest",
			"id": "lawinenkuppe",
			"at": 1060.0,
			"name": "Lawinen-Kuppe",
			"hero": true,
			"height": 1.6
		},
		{
			"kind": "leap",
			"id": "gletscherspalte",
			"at": 1470.0,
			"side": -1.0,
			"theme": "ice",
			"name": "Gletscherspalten-Sprung"
		},
		{
			"kind": "bank",
			"id": "eiskurve",
			"at": 1580.0,
			"length": 80.0,
			"window": 30.0,
			"name": "Eiskurve"
		},
		{"kind": "crest", "id": "schneewechte", "at": 1760.0, "name": "Ziel-Schneewechte"},
	],
	"galaxy_ringway":
	[
		{"kind": "crest", "id": "kometenbuckel", "at": 200.0, "name": "Kometenbuckel"},
		{
			"kind": "bank",
			"id": "saturnkurve",
			"at": 420.0,
			"length": 90.0,
			"window": 30.0,
			"name": "Saturnkurve"
		},
		{"kind": "turbo", "id": "warp", "at": 1050.0, "name": "Warp-Turbo"},
		{"kind": "turbo", "id": "mondbahn", "at": 1350.0, "name": "Mondbahn-Turbo"},
		{
			"kind": "leap",
			"id": "sternenloch",
			"at": 1760.0,
			"side": 1.0,
			"theme": "void",
			"name": "Sternenloch-Sprung"
		},
		{
			"kind": "crest",
			"id": "zielkomet",
			"at": 1885.0,
			"name": "Ziel-Komet",
			"hero": true,
			"height": 1.6
		},
	],
	"desert_drift":
	[
		{"kind": "crest", "id": "startduene", "at": 190.0, "name": "Startdüne"},
		{
			"kind": "leap",
			"id": "treibsand",
			"at": 540.0,
			"side": -1.0,
			"theme": "chasm",
			"name": "Treibsand-Schlucht"
		},
		{"kind": "crest", "id": "duenenkuppe", "at": 740.0, "name": "Dünenkuppe"},
		{"kind": "turbo", "id": "katakomben", "at": 1000.0, "name": "Katakomben-Turbo"},
		{
			"kind": "bank",
			"id": "sandkurve",
			"at": 1420.0,
			"length": 80.0,
			"window": 30.0,
			"name": "Sandkurve"
		},
		{
			"kind": "crest",
			"id": "duenenflug",
			"at": 1530.0,
			"name": "Dünen-Flug",
			"hero": true,
			"height": 1.6
		},
		{"kind": "crest", "id": "oasenfinale", "at": 1880.0, "name": "Oasen-Finale"},
	],
	"windwerk_3000":
	[
		{
			"kind": "bank",
			"id": "viaduktkurve",
			"at": 1356.0,
			"length": 90.0,
			"window": 20.0,
			"name": "Viadukt-Steilkurve"
		},
	],
	"learning_lab":
	[
		{"kind": "crest", "id": "laborbuckel", "at": 200.0, "name": "Laborbuckel"},
		{"kind": "crest", "id": "molekuel", "at": 530.0, "name": "Molekül-Kuppe"},
		{"kind": "turbo", "id": "teilchen", "at": 950.0, "name": "Teilchen-Turbo"},
		{
			"kind": "leap",
			"id": "plasmarinne",
			"at": 1460.0,
			"side": 1.0,
			"theme": "plasma",
			"name": "Plasma-Rinne"
		},
		{
			"kind": "bank",
			"id": "magnetkurve",
			"at": 1270.0,
			"length": 90.0,
			"window": 40.0,
			"name": "Magnetkurve"
		},
		{
			"kind": "crest",
			"id": "raketenkuppe",
			"at": 1740.0,
			"name": "Raketen-Kuppe",
			"hero": true,
			"height": 1.6
		},
	],
}


static func specs_for(track_id: String) -> Array:
	return SPECS.get(track_id, [])


static func has(track_id: String) -> bool:
	return not specs_for(track_id).is_empty()


static func of(world) -> Array:
	return world.get_meta(META, []) if world.has_meta(META) else []


# ------------------------------------------------------------------ Planung


static func _base_blocked(world, kind: String = "") -> Array:
	var length: float = float(world.length)
	var blocked: Array = [Vector2(-INF, 70.0), Vector2(length - 45.0, INF)]
	var tunnel: Dictionary = world.get_meta("adventure_tunnel_plan", {})
	# Turbo fields lie flat on the road: a tunnel with turbo fields is a tempo passage.
	if not tunnel.is_empty() and kind != "turbo":
		blocked.append(Vector2(float(tunnel.start) - 40.0, float(tunnel.end) + 30.0))
	if not world.jump.is_empty():
		blocked.append(
			Vector2(float(world.jump.ramp_start) - 40.0, float(world.jump.gap_end) + 50.0)
		)
	if not world.loop_layout.is_empty():
		blocked.append(
			Vector2(float(world.loop_layout.start) - 40.0, float(world.loop_layout.start) + 100.0)
		)
	for entry in PASSAGES.of(world):
		if entry.has("zone_start"):
			blocked.append(Vector2(float(entry.zone_start) - 40.0, float(entry.zone_end) + 25.0))
	return blocked


static func _free(span: Vector2, blocked: Array) -> bool:
	for zone in blocked:
		var area: Vector2 = zone
		if span.x < area.y and span.y > area.x:
			return false
	return true


static func _straight(world, a: float, b: float, minimum_dot: float) -> bool:
	var ahead: Vector3 = world.forward(a)
	var d: float = a
	while d <= b:
		if ahead.dot(world.forward(d)) < minimum_dot:
			return false
		d += 5.0
	return true


static func _turn_rate(world, d: float) -> float:
	var a: Vector3 = world.forward(d - 10.0)
	var b: Vector3 = world.forward(d + 10.0)
	return absf(angle_difference(atan2(a.x, a.z), atan2(b.x, b.z))) / 20.0


## Span the element occupies (incl. approach) for a start distance.
static func _span(spec: Dictionary, start: float) -> Vector2:
	match str(spec.kind):
		"crest":
			var landing: float = 60.0 if bool(spec.get("hero", false)) else 40.0
			return Vector2(start - 50.0, start + CREST_LENGTH + landing)
		"leap":
			return Vector2(start - 70.0, start + LEAP_RAMP_LENGTH + LEAP_GAP_LENGTH + 40.0)
		"turbo":
			return Vector2(start - 10.0, start + TURBO_SPACING * 2.0 + 20.0)
		"bank":
			return Vector2(start, start + float(spec.get("length", 120.0)))
	return Vector2(start, start)


static func _fits(world, spec: Dictionary, start: float) -> bool:
	match str(spec.kind):
		"crest":
			var take_off: float = start + CREST_LENGTH
			var landing: float = 60.0 if bool(spec.get("hero", false)) else 40.0
			return (
				_straight(world, start - 20.0, take_off, 0.985)
				and _straight(world, take_off, take_off + landing, 0.965)
			)
		"leap":
			var take_off: float = start + LEAP_RAMP_LENGTH
			return (
				leap_rules_ok(float(world.length), start)
				and _straight(world, start - 60.0, take_off, 0.97)
				and _straight(world, take_off, take_off + 40.0, 0.965)
			)
	return true


## Regeln seit dem Gerätefund vom 19.11.: keine Sturz-Stelle in den ersten LEAP_MIN_START m
## (das Feld ist dort noch dicht), und Sturzbereich samt Rettungspunkt der Lumo-Wolke
## (gap_exit: Spaltende + 3 m) liegen im selben Checkpoint-Abschnitt (Streckenlänge / 8) –
## sonst überspränge die Rettung ein Tor, und die Runde zählte nicht.
static func leap_rules_ok(length: float, start: float) -> bool:
	var take_off: float = start + LEAP_RAMP_LENGTH
	if take_off - 0.5 < LEAP_MIN_START:
		return false
	var section: float = length / 8.0
	var first: int = floori((take_off - 0.5) / section)
	var last: int = floori((take_off + LEAP_GAP_LENGTH + 3.0 + LEAP_SECTION_MARGIN) / section)
	return first == last


static func plan(world) -> Array:
	var result: Array = []
	var length: float = float(world.length)
	var placed: Array = []
	# Authoring tests (kart_track_pieces_regression) may ask for the classic layout.
	var specs: Array = (
		[] if bool(world.get_meta(OFF_META, false)) else specs_for(str(world.track_id))
	)
	for source in specs:
		var spec: Dictionary = source.duplicate(true)
		var blocked: Array = _base_blocked(world, str(spec.kind)) + placed
		var wish: float = float(spec.at)
		if wish < 0.0:
			wish += length
		var chosen: float = -1.0
		if str(spec.kind) == "bank":
			chosen = _bank_start(world, spec, wish, blocked)
		else:
			for step in range(81):
				var offset: float = (
					floorf(float(step + 1) / 2.0) * 6.0 * (1.0 if step % 2 == 0 else -1.0)
				)
				var start: float = wish + offset
				var span: Vector2 = _span(spec, start)
				if span.x < 0.0 or span.y > length:
					continue
				if _free(span, blocked) and _fits(world, spec, start):
					chosen = start
					break
		if chosen < 0.0:
			push_warning("[Thrills] %s/%s found no free stretch" % [world.track_id, spec.id])
			continue
		var entry: Dictionary = _resolve(spec, chosen)
		placed.append(_span(spec, chosen))
		result.append(entry)
	result.sort_custom(func(a, b): return float(a.start) < float(b.start))
	world.set_meta(META, result)
	_bake_bank(world, result)
	return result


static func _bank_start(world, spec: Dictionary, wish: float, blocked: Array) -> float:
	var span_length: float = float(spec.get("length", 120.0))
	var best: float = -1.0
	var best_rate: float = 0.0
	var window: float = float(spec.get("window", 180.0))
	var d: float = wish - window
	while d <= wish + window:
		var start: float = d - span_length * 0.5
		if start > 0.0 and start + span_length < float(world.length):
			if _free(Vector2(start, start + span_length), blocked):
				var rate: float = _turn_rate(world, d)
				if rate > best_rate:
					best_rate = rate
					best = start
		d += 4.0
	return best


static func _resolve(spec: Dictionary, start: float) -> Dictionary:
	var entry: Dictionary = spec.duplicate(true)
	entry["start"] = start
	match str(spec.kind):
		"crest":
			var hero: bool = bool(spec.get("hero", false))
			var height: float = float(spec.get("height", CREST_HEIGHT))
			entry["take_off"] = start + CREST_LENGTH
			entry["height"] = height
			entry["angle"] = atan2(2.0 * height, CREST_LENGTH)
			entry["flight_gravity"] = 20.0 if hero else FLIGHT_GRAVITY
			entry["lift_bonus"] = 2.6 if hero else 2.2
			entry["max_lift"] = 7.5 if hero else 6.0
			entry["end"] = start + CREST_LENGTH + (60.0 if hero else 40.0)
		"leap":
			var side: float = float(spec.get("side", 1.0))
			entry["side"] = side
			entry["take_off"] = start + LEAP_RAMP_LENGTH
			entry["gap_end"] = start + LEAP_RAMP_LENGTH + LEAP_GAP_LENGTH
			entry["height"] = LEAP_RAMP_HEIGHT
			entry["angle"] = atan2(LEAP_RAMP_HEIGHT, LEAP_RAMP_LENGTH)
			entry["flight_gravity"] = FLIGHT_GRAVITY
			entry["lift_bonus"] = LEAP_LIFT_BONUS
			entry["max_lift"] = LEAP_MAX_LIFT
			entry["inner"] = LEAP_INNER
			entry["outer"] = LEAP_OUTER
			entry["end"] = float(entry.gap_end) + 4.0
			entry["decision"] = true
			entry["min_speed"] = min_clear_speed(entry)
		"turbo":
			entry["end"] = start + TURBO_SPACING * 2.0 + 6.0
		"bank":
			entry["end"] = start + float(spec.get("length", 120.0))
	entry["sign_at"] = maxf(10.0, start - SIGN_LEAD_M)
	return entry


## Smallest take-off speed whose flight clears the gap plus half a kart and reserve.
static func min_clear_speed(entry: Dictionary) -> float:
	var need: float = (
		float(entry.gap_end) - float(entry.take_off) + KART_HALF_LENGTH + LANDING_RESERVE_M
	)
	var v: float = 4.0
	while v < 80.0:
		if flight_distance(entry, v) >= need:
			return v
		v += 0.25
	return INF


static func flight_time(entry: Dictionary, speed: float) -> float:
	var vz: float = minf(
		speed * sin(float(entry.angle)) + float(entry.lift_bonus), float(entry.max_lift)
	)
	var g: float = float(entry.flight_gravity)
	return (vz + sqrt(vz * vz + 2.0 * g * float(entry.height))) / g


static func flight_distance(entry: Dictionary, speed: float) -> float:
	return speed * cos(float(entry.angle)) * flight_time(entry, speed)


## Crest kickers and turbo pads join the ordinary action course (same physics everywhere).
static func extend_action(world) -> void:
	if not world.action.has("kickers"):
		return
	for entry in of(world):
		match str(entry.kind):
			"crest":
				(
					world
					. action
					. kickers
					. append(
						{
							"start": float(entry.start),
							"take_off": float(entry.take_off),
							"length": CREST_LENGTH,
							"height": float(entry.height),
							"angle": float(entry.angle),
							"flight_gravity": float(entry.flight_gravity),
							"lift_bonus": float(entry.lift_bonus),
							"max_lift": float(entry.max_lift),
							"profile": "ease_in",
							"thrill": str(entry.id),
							"hero_flight": bool(entry.get("hero", false)),
						}
					)
				)
			"turbo":
				for k in range(3):
					var at: float = float(entry.start) + TURBO_SPACING * float(k)
					world.action.pads.append(
						{"start": at, "end": at + 6.0, "lateral": 0.0, "thrill": str(entry.id)}
					)


## Ranges no other race element (slalom, pads, rocks, rings) may be placed in.
static func blocked_ranges(world) -> Array:
	var blocked: Array = []
	for entry in of(world):
		var span: Vector2 = _span(entry, float(entry.start))
		if str(entry.kind) == "bank":
			# Keine Pylonen und Felsen in der Steilkurve: Rivalen fahren dort ihre Außenlinie
			# und kamen vor einem Pylon nicht mehr herum (Vulkan-Nacht, Entdecken, 19.11.).
			blocked.append(span)
			continue
		# Leaps keep their whole run-up free (rival lane change, rocks, slalom pylons).
		# Crest landings get 60 m more: rivals land with any lateral offset and must not
		# meet slalom pylons or rocks before they have settled on their line.
		var trim: float = 0.0 if str(entry.kind) == "leap" else 20.0
		var settle: float = 60.0 if str(entry.kind) == "crest" else 0.0
		blocked.append(Vector2(span.x + trim, span.y + settle))
	return blocked


## Fraction-placed boxes/rings/pads must not sit on a ramp, a gap or a crest landing.
static func clear_distance(world, distance: float) -> float:
	var d: float = fposmod(distance, float(world.length))
	for entry in of(world):
		if str(entry.kind) in ["bank", "turbo"]:
			continue
		if d > float(entry.start) - 30.0 and d < float(entry.end) + 8.0:
			return distance - d + float(entry.end) + 12.0
	return distance


# ------------------------------------------------------------------ Fahrphysik


static func _leap_at(world, d: float) -> Dictionary:
	for entry in of(world):
		if str(entry.kind) == "leap" and d >= float(entry.start) - 1.0 and d < float(entry.end):
			return entry
	return {}


static func on_brave_line(entry: Dictionary, lateral: float) -> bool:
	return lateral * float(entry.side) >= float(entry.inner) - 0.05


## Height of the leap ramp under this lateral position (0 on the safe line).
static func lane_height(world, distance: float, lateral: float) -> float:
	var d: float = fposmod(distance, float(world.length))
	var entry: Dictionary = _leap_at(world, d)
	if entry.is_empty() or d < float(entry.start) or d >= float(entry.take_off):
		return 0.0
	if not on_brave_line(entry, lateral):
		return 0.0
	return (d - float(entry.start)) / LEAP_RAMP_LENGTH * float(entry.height)


static func lane_pitch(world, distance: float, lateral: float) -> float:
	return (
		float(_leap_at(world, fposmod(distance, float(world.length))).get("angle", 0.0))
		if lane_height(world, distance, lateral) > 0.0
		else 0.0
	)


## No road under this point: the brave half between lip and far edge.
static func lane_gap(world, distance: float, lateral: float) -> bool:
	var d: float = fposmod(distance, float(world.length))
	var entry: Dictionary = _leap_at(world, d)
	if entry.is_empty() or d < float(entry.take_off) or d >= float(entry.gap_end):
		return false
	return lateral * float(entry.side) > float(entry.inner) + FALL_MARGIN


## Just past a leap gap on the brave half: a kart arriving below the road here hit the wall.
static func far_edge(world, distance: float, lateral: float) -> bool:
	var d: float = fposmod(distance, float(world.length))
	var entry: Dictionary = _leap_at(world, d)
	if entry.is_empty() or d < float(entry.gap_end) or d >= float(entry.gap_end) + 4.0:
		return false
	return lateral * float(entry.side) > float(entry.inner) + FALL_MARGIN


## Lateral interval of the road surface that is missing at this distance (for meshes).
static func cut_span(world, distance: float) -> Vector2:
	var d: float = fposmod(distance, float(world.length))
	var entry: Dictionary = _leap_at(world, d)
	if entry.is_empty() or d < float(entry.take_off) or d >= float(entry.gap_end):
		return Vector2(INF, INF)
	var side: float = float(entry.side)
	var a: float = float(entry.inner) * side
	var b: float = 9.0 * side
	return Vector2(minf(a, b), maxf(a, b))


static func cuts_side(world, distance: float, side: float) -> bool:
	var span: Vector2 = cut_span(world, distance)
	return span.x < INF and side * 5.5 >= span.x and side * 5.5 <= span.y


## The leap whose lip was crossed on the brave line between two physics steps.
static func leap_crossed(world, previous: float, current: float, lateral: float) -> Dictionary:
	var length: float = float(world.length)
	var a: float = fposmod(previous, length)
	var b: float = fposmod(current, length)
	if b <= a or b - a > 14.0:
		return {}
	for entry in of(world):
		if str(entry.kind) != "leap":
			continue
		var lip: float = float(entry.take_off)
		if a >= float(entry.start) and a < lip and b >= lip and on_brave_line(entry, lateral):
			return entry
	return {}


## Where the cloud sets a kart down that fell into a leap gap (-1: not in a leap).
static func gap_exit(world, distance: float) -> float:
	var d: float = fposmod(distance, float(world.length))
	for entry in of(world):
		if str(entry.kind) != "leap":
			continue
		if d >= float(entry.take_off) - 0.5 and d < float(entry.gap_end) + 6.0:
			return distance - d + float(entry.gap_end) + 3.0
	return -1.0


## Respawn distance (cumulative race distance) for a candidate inside a leap: just after
## the gap on solid road; -1 when the candidate is not inside a leap.
static func safe_respawn(world, candidate: float) -> float:
	var d: float = fposmod(candidate, float(world.length))
	for entry in of(world):
		if str(entry.kind) != "leap":
			continue
		if d >= float(entry.start) - 2.0 and d < float(entry.gap_end) + 3.0:
			return candidate - d + float(entry.gap_end) + 3.0
	return -1.0


## Rival line: brave rivals (even index) jump when fast enough, everyone else keeps safe.
static func rival_lane(world, distance: float, speed: float, index: int) -> float:
	var d: float = fposmod(distance, float(world.length))
	for entry in of(world):
		if str(entry.kind) != "leap":
			continue
		if d < float(entry.start) - 60.0 or d >= float(entry.gap_end) + 4.0:
			continue
		var side: float = float(entry.side)
		var brave: bool = index % 2 == 0 and speed >= float(entry.min_speed) + 8.0
		if brave and d < float(entry.take_off):
			return side * (float(entry.inner) + float(entry.outer)) * 0.5
		return -side * 1.9
	return INF


## After traffic avoidance: a rival that is not lined up on the ramp never steers over the
## gap edge (it stays 0.8 m inside the safe half from the lip to the far edge).
static func rival_gap_guard(world, distance: float, lane: float, index: int) -> float:
	var d: float = fposmod(distance, float(world.length))
	var entry: Dictionary = _leap_at(world, d)
	if entry.is_empty() or d < float(entry.start) - 12.0 or d >= float(entry.gap_end) + 1.0:
		return lane
	var side: float = float(entry.side)
	var edge: float = float(entry.inner) - 0.8
	if index % 2 == 0 and d < float(entry.take_off) and lane * side >= float(entry.inner) + 0.6:
		return lane  # lined up on the ramp: keep it
	if lane * side > edge:
		return side * edge
	return lane


## Lane the test/capture driver aims for: the brave line through every leap.
static func bot_lane(world, distance: float) -> float:
	if not is_instance_valid(world) or not world.has_meta(META):
		return 0.0
	var d: float = fposmod(distance, float(world.length))
	for entry in of(world):
		if str(entry.kind) != "leap":
			continue
		if d >= float(entry.start) - 60.0 and d < float(entry.gap_end) + 6.0:
			return float(entry.side) * (float(entry.inner) + float(entry.outer)) * 0.5
	return 0.0


# ------------------------------------------------------------------ Steilkurve


static func _bake_bank(world, entries: Array) -> void:
	var length: float = float(world.length)
	var count: int = ceili(length / BANK_STEP)
	var profile := PackedFloat32Array()
	var any: bool = false
	profile.resize(count)
	for entry in entries:
		if str(entry.kind) != "bank":
			continue
		any = true
		var a: float = float(entry.start)
		var b: float = float(entry.end)
		var ease: float = 30.0
		for i in range(count):
			var d: float = float(i) * BANK_STEP
			var w: float = 0.0
			if d >= a and d <= b:
				w = minf(1.0, minf(d - a, b - d) / ease)
				w = w * w * (3.0 - 2.0 * w)
			profile[i] = maxf(profile[i], w)
	world.thrill_bank = profile if any else PackedFloat32Array()


# ------------------------------------------------------------------ Fahrer-Hinweise


## The next element ahead that gets a spoken/written hint (leaps, turbo lanes, hero crests);
## small crests and banked curves explain themselves through their signs and arrows.
static func next_announced(world, local: float) -> Dictionary:
	for entry in of(world):
		if float(entry.start) <= local:
			continue
		var kind: String = str(entry.kind)
		if kind in ["leap", "turbo"] or (kind == "crest" and bool(entry.get("hero", false))):
			return entry
	return {}


static func approach_text(entry: Dictionary) -> String:
	var custom: String = str(entry.get("text", ""))
	if not custom.is_empty():
		return custom
	match str(entry.kind):
		"leap":
			var brave: String = "rechts" if float(entry.side) > 0.0 else "links"
			var safe: String = "links" if float(entry.side) > 0.0 else "rechts"
			return (
				"%s: %s mit Schwung springen – %s sicher vorbei."
				% [str(entry.get("name", "Sprung")), brave.capitalize(), safe]
			)
		"crest":
			return "%s – Gas halten und fliegen!" % str(entry.get("name", "Kuppe"))
		"bank":
			return "%s – ganz außen bleibt der Schwung!" % str(entry.get("name", "Steilkurve"))
		"turbo":
			return "%s – drei Turbo-Felder in der Mitte!" % str(entry.get("name", "Turbo-Bahn"))
	return ""
