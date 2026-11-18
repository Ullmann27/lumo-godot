extends RefCounted
## Untere Leiste der Dorfwelt in vier Bereichen (reine Regeln, keine Knoten):
##   „Bauen“ – Wege und Gebäude, „Versorgen“ – Felder, Wasser, Vorräte,
##   „Nachbarn“ – Karte, Handel, Bündnisse, „Schützen“ – Wachen, Verteidigung.
## „Nächster Tag“ ist keine Bereichsaktion, sondern bleibt fest daneben.
## Am Anfang gibt es nur Haus und Hof. Weitere Werkzeuge und Bereiche öffnen
## sich an einem passenden Spielmoment und bleiben dann offen (gespeichert).
const VERSION := 1
const ORDER := ["bauen", "versorgen", "nachbarn", "schuetzen"]
const TITLES := {"bauen": "Bauen", "versorgen": "Versorgen", "nachbarn": "Nachbarn", "schuetzen": "Schützen"}
const CARDS := {
	"bauen": ["house", "road", "lumber", "quarry", "market", "school", "clinic"],
	"versorgen": ["farm", "well", "grain", "bakery"],
}
## Was ein Anfänger sieht: genau die Werkzeuge für Haus und Hof.
const STARTER_CARDS := ["house", "farm"]
const NEIGHBORS_DAY := 3
const DEFENSE_DAY := 5
## Kurzer Satz, wenn ein Bereich neu aufgeht.
const OPENED := {
	"tools": "Neu beim Bauen und Versorgen: mehr Gebäude!",
	"nachbarn": "Neu: „Nachbarn“. Dort sind Karte, Handel und Freunde.",
	"schuetzen": "Neu: „Schützen“. Dort planst du Wachen und Mauern.",
}

var current := "bauen"
var open: Dictionary = {"bauen": true, "versorgen": true, "nachbarn": false, "schuetzen": false}
var full_tools := false


static func section_of_kind(kind: String) -> String:
	for section in CARDS:
		if kind in (CARDS[section] as Array):
			return section
	return "bauen"


func card_visible(kind: String) -> bool:
	return full_tools or kind in STARTER_CARDS


func is_open(section: String) -> bool:
	return bool(open.get(section, false))


func select(section: String) -> bool:
	if not is_open(section):
		return false
	current = section
	return true


func unlock_all() -> void:
	full_tools = true
	for section in ORDER:
		open[section] = true


## Prüft nach einem Spielmoment, was neu aufgeht. Gibt die Schlüssel zurück
## ("tools", "nachbarn", "schuetzen"), die gerade frei wurden.
func update(model, tutorial_done: bool, raid_pending: bool) -> Array[String]:
	var opened: Array[String] = []
	var town: Dictionary = model._player
	var day := int(model.day)
	if not full_tools and tutorial_done:
		full_tools = true
		opened.append("tools")
	if not is_open("nachbarn") and tutorial_done and day >= NEIGHBORS_DAY:
		open["nachbarn"] = true
		opened.append("nachbarn")
	var farm_ready := int(model._count(town, "farm")) > 0
	if not is_open("schuetzen") and ((tutorial_done and day >= DEFENSE_DAY and farm_ready) or raid_pending):
		open["schuetzen"] = true
		opened.append("schuetzen")
	return opened


func snapshot() -> Dictionary:
	return {"version": VERSION, "current": current, "open": open.duplicate(), "full": full_tools}


## Alte Dörfer (ohne Leistendaten) behalten alle Werkzeuge, die sie kannten.
static func restore(raw: Variant, model = null):
	var result = load("res://scripts/creative/build_village_dock.gd").new()
	if raw is Dictionary and raw.get("version") == VERSION:
		result.full_tools = bool(raw.get("full", false))
		var flags: Variant = raw.get("open", {})
		if flags is Dictionary:
			for section in ORDER:
				result.open[section] = bool(flags.get(section, result.open[section]))
		result.open["bauen"] = true
		result.open["versorgen"] = true
		result.current = str(raw.get("current", "bauen"))
		if not result.is_open(result.current):
			result.current = "bauen"
		return result
	if model != null and (model._player.buildings.size() > 0 or int(model.day) > 1):
		result.unlock_all()
	return result
