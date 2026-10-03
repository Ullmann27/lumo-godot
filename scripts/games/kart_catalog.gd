extends RefCounted
## Original Lumo race rules and shared menu data. Unlocks are earned, never charged.
const TRACKS: Array[Dictionary] = [
	{"id": "sonnenhafen", "name": "Sonnenhafen", "tag": "MEER · BRÜCKEN · WEITE KURVEN", "color": Color("64dfeb"), "description": "Über die Hafenbrücke, am Leuchtturm vorbei und direkt ans Meer."},
	{"id": "zauberwald", "name": "Zauberwald", "tag": "WALD · LEUCHTEN · GEHEIMNISSE", "color": Color("87eac1"), "description": "Leuchtende Pilze und große Baumwipfel begleiten deine Fahrt."},
	{"id": "bergwelt", "name": "Wolkenpass", "tag": "BERGE · HÖHEN · AUSSICHT", "color": Color("a9caff"), "description": "Hoch über dem Tal warten weite Kehren und schwebende Wolken."},
	{"id": "holo_city", "name": "Holo City", "tag": "ZUKUNFT · NEON · NACHT", "color": Color("baabff"), "description": "Zwischen gläsernen Türmen und schimmernden Lichtbändern."}
]
const MODES: Array[Dictionary] = [
	{"id": "race", "name": "Einzelrennen", "tag": "DEIN SCHNELLER START", "description": "Zwei Runden, fünf Rivalen und deine Lieblingsstrecke."},
	{"id": "cup", "name": "Sternen-Cup", "tag": "VIER WELTEN · EIN POKAL", "description": "Fahre alle vier Strecken. Jeder Platz zählt für die Gesamtwertung."},
	{"id": "time_trial", "name": "Zeitfahren", "tag": "DU GEGEN DEINEN GEIST", "description": "Verbessere deine Bestzeit. Deine beste Fahrt fährt als Geist mit."},
	{"id": "training", "name": "Freies Training", "tag": "ENTDECKEN OHNE DRUCK", "description": "Lerne lenken, bremsen und driften. Du bestimmst, wann du fertig bist."},
	{"id": "learn_cup", "name": "Lern-Cup", "tag": "FAHREN · DENKEN · WACHSEN", "description": "Vier Rennen mit einer entspannten Lernpause nach jedem Ziel."},
	{"id": "arena", "name": "Kristall-Arena", "tag": "90 SEKUNDEN ABENTEUER", "description": "Sammle mehr Kristalle als deine Rivalen. Schild und Impuls helfen dir."}
]
const DRIVERS: Array[Dictionary] = [
	{"id": "fox", "name": "Lumo", "tag": "DEIN MUTIGER FUCHS", "color": Color("76d9ff"), "unlock": 0},
	{"id": "rabbit", "name": "Nova", "tag": "NEUGIERIG UND FLINK", "color": Color("c0abff"), "unlock": 6},
	{"id": "otter", "name": "Milo", "tag": "ENTSPANNT INS ABENTEUER", "color": Color("75e6ce"), "unlock": 12}
]
const KARTS: Array[Dictionary] = [
	{"id": "comet", "name": "Comet", "tag": "AUSGEWOGEN", "description": "Tempo ●●●  Lenkung ●●●  Schub ●●●", "speed": 1.0, "turn": 1.0, "accel": 1.0, "unlock": 0},
	{"id": "glider", "name": "Glider", "tag": "LEICHT ZU LENKEN", "description": "Tempo ●●  Lenkung ●●●●  Schub ●●●", "speed": 0.93, "turn": 1.13, "accel": 1.12, "unlock": 8},
	{"id": "turbo", "name": "Aurora GT", "tag": "SCHNELL AUF GERADEN", "description": "Tempo ●●●●  Lenkung ●●  Schub ●●", "speed": 1.1, "turn": 0.94, "accel": 0.88, "unlock": 18}
]
const DIFFICULTIES: Array[Dictionary] = [
	{"id": "gemuetlich", "name": "Entdecken", "tag": "MIT LENKHILFE", "description": "Gemütliches Tempo. Lumo hilft sanft am Fahrbahnrand.", "speed": 0.83, "rival": 0.71},
	{"id": "flott", "name": "Abenteuer", "tag": "DEIN EIGENES TEMPO", "description": "Mehr Tempo, freie Lenkung und ausgeglichene Rivalen.", "speed": 1.0, "rival": 0.87},
	{"id": "pro", "name": "Sternen-Profi", "tag": "DRIFT MACHT DEN UNTERSCHIED", "description": "Volles Tempo. Gewinne mit sauberen Kurven und cleverem Boost.", "speed": 1.17, "rival": 0.99}
]
const CUP_POINTS: Array[int] = [12, 9, 7, 5, 3, 1]

static func entry(items: Array[Dictionary], id: String) -> Dictionary:
	for item in items:
		if item.id == id:
			return item
	return items[0]

static func unlocked(item: Dictionary, stars: int, unlocked_ids: Array) -> bool:
	return stars >= int(item.get("unlock", 0)) or unlocked_ids.has(str(item.id))
