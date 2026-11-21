extends RefCounted
## Original Lumo race rules and shared menu data. Unlocks are earned, never charged.
## Kart is a reward game: learning happens in the app, never inside a race.
const EXPANSION = preload("res://scripts/games/kart_expansion_tracks.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const BASE_TRACKS: Array[Dictionary] = [
	{"id": "sonnenhafen", "name": "Sonnenhafen", "tag": "MEER · BRÜCKEN · WEITE KURVEN", "color": Color("64dfeb"), "description": "Über die Hafenbrücke, am Leuchtturm vorbei und direkt ans Meer."},
	{"id": "zauberwald", "name": "Zauberwald", "tag": "WALD · LEUCHTEN · GEHEIMNISSE", "color": Color("87eac1"), "description": "Leuchtende Pilze und große Baumwipfel begleiten deine Fahrt."},
	{"id": "bergwelt", "name": "Himmelsinseln", "tag": "INSELN · WASSERFÄLLE · STERNE", "color": Color("9cc9ff"), "description": "Hoch über den Wolken: schwebende Inseln, Wasserfälle und die Schwebestadt."},
	{"id": "holo_city", "name": "Holo City", "tag": "ZUKUNFT · NEON · NACHT", "color": Color("baabff"), "description": "Zwischen gläsernen Türmen und schimmernden Lichtbändern."}
]
static var TRACKS: Array[Dictionary] = _all_tracks()

static func _all_tracks() -> Array[Dictionary]:
	var result: Array[Dictionary] = BASE_TRACKS.duplicate(true)
	result.append_array(EXPANSION.CATALOG)
	result.append({
		"id": "jungle_emerald_3600", "name": "Dschungelherz",
		"tag": "EXPEDITION SMARAGD · 3,6 KM", "color": Color("9dcb6b"),
		"description": "Zwölf Dschungelwelten: Flusshafen, Wasserfall, Wurzelgrotte und Kronenbrücke."
	})
	result.append({
		"id": "riesengarten_2400", "name": "Riesengarten",
		"tag": "LUMOS SOMMERGARTEN · 2,4 KM", "color": Color("ffcf3a"),
		"description": "Winzig im Riesengarten: Gießkannen-Schanze, Gartenschlauch und Gewächshaus."
	})
	result.make_read_only()
	return result

const MODES: Array[Dictionary] = [
	{"id": "race", "name": "Einzelrennen", "tag": "DEIN SCHNELLER START", "description": "Zwei Runden, fünf Rivalen und deine Lieblingsstrecke."},
	{"id": "cup", "name": "Sternen-Cup", "tag": "ALLE WELTEN · EIN POKAL", "description": "Fahre durch alle Rennwelten. Jeder Platz zählt für die Gesamtwertung."},
	{"id": "time_trial", "name": "Zeitfahren", "tag": "DU GEGEN DEINEN GEIST", "description": "Verbessere deine Bestzeit. Deine beste Fahrt fährt als Geist mit."},
	{"id": "training", "name": "Freies Training", "tag": "ENTDECKEN OHNE DRUCK", "description": "Lerne lenken, bremsen und driften. Du bestimmst, wann du fertig bist."},
	{"id": "arena", "name": "Kristall-Arena", "tag": "90 SEKUNDEN ABENTEUER", "description": "Sammle mehr Kristalle als deine Rivalen. Schild und Impuls helfen dir."},
	# Eigene Szene mit demselben Kart: scripts/games/parcours/ (Weltwahl dort).
	{"id": "parcours", "name": "Abenteuer-Parcours", "tag": "GESCHICKLICHKEIT · EBENEN · ZU FUSS", "description": "Brücken, Aufzüge und Plattformen – und manchmal steigt Lumo aus."}
]
const DRIVERS: Array[Dictionary] = [
	{"id": "fox", "name": "Lumo", "tag": "DEIN MUTIGER FUCHS", "color": Color("76d9ff"), "unlock": 0},
	{"id": "rabbit", "name": "Nova", "tag": "NEUGIERIG UND FLINK", "color": Color("c0abff"), "unlock": 6},
	{"id": "otter", "name": "Milo", "tag": "ENTSPANNT INS ABENTEUER", "color": Color("75e6ce"), "unlock": 12},
	{"id": "frog", "name": "Frosch", "tag": "AUS DEM DSCHUNGEL", "color": Color("64c987"), "unlock": 0}
]
## Die Flotte mit Werten, Preisen und Aussehen steht in kart_fleet.gd.
static var KARTS: Array[Dictionary] = FLEET.KARTS
const DIFFICULTIES: Array[Dictionary] = [
	# Eigentempo ist auf allen Stufen gleich (volles Tempo, wie bisher auf "Extrem");
	# die Stufen unterscheiden sich über die Rivalen und die Lenkhilfe.
	{"id": "gemuetlich", "name": "Entdecken", "tag": "VOLLES TEMPO · LENKHILFE", "description": "Volles Tempo mit sanfter Lenkhilfe am Fahrbahnrand. Die Rivalen lassen dir Platz.", "speed": 1.17, "rival": 0.86},
	{"id": "flott", "name": "Abenteuer", "tag": "FREIE LENKUNG", "description": "Volles Tempo, freie Lenkung und starke Rivalen.", "speed": 1.17, "rival": 0.96},
	{"id": "pro", "name": "Extrem", "tag": "MAXIMALE HERAUSFORDERUNG", "description": "Rivalen nutzen volle Kartleistung, schnelle Kurven, Überholmanöver und verdiente Turbos.", "speed": 1.17, "rival": 1.0}
]
const CUP_POINTS: Array[int] = [12, 9, 7, 5, 3, 1]

static func entry(items: Array[Dictionary], id: String) -> Dictionary:
	for item in items:
		if item.id == id:
			return item
	return items[0]

static func unlocked(item: Dictionary, stars: int, unlocked_ids: Array) -> bool:
	return stars >= int(item.get("unlock", 0)) or unlocked_ids.has(str(item.id))
