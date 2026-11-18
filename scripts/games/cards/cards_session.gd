extends RefCounted
## Spielstand des Kartentischs: laufende Partien, Einstellungen, gebuchte
## Ergebnisse. Eine Datei pro Kind unter user://, wie bei Puzzle und Bauwelt.
##
## Jede Partie trägt ihre Ergebnis-ID vom ersten Austeilen an. `settle()`
## bucht eine beendete Partie genau einmal – auch nach Fortsetzen, erneutem
## Öffnen oder doppeltem Aufruf.

const DECK = preload("res://scripts/games/cards/rules/star_deck.gd")
const AI = preload("res://scripts/games/cards/rules/cards_ai.gd")
const RULES := {
	"stich": preload("res://scripts/games/cards/rules/sternenstich_rules.gd"),
	"leiter": preload("res://scripts/games/cards/rules/sternenleiter_rules.gd"),
	"quartett": preload("res://scripts/games/cards/rules/quartett_rules.gd"),
}
const GAMES: Array[String] = ["stich", "leiter", "quartett"]
const VERSION := 1
const BOOKED_LIMIT := 300
const PLACE_STARS := [3, 2, 1, 1]

var path := ""
var data: Dictionary = {}
var last_error := ""


static func path_for(child_key: String) -> String:
	var owner := child_key.strip_edges()
	if owner.is_empty():
		return "user://lumo_cards_standalone.json"
	return "user://lumo_cards_%s.json" % owner.sha256_text().substr(0, 24)


static func create_rules(game: String) -> RefCounted:
	return RULES[game].new() if RULES.has(game) else null


func _init(file_path: String = "") -> void:
	path = file_path
	data = _blank()


func _blank() -> Dictionary:
	return {
		"v": VERSION,
		"matches": {},
		"booked": [],
		"prefs": {"players": 4, "difficulty": 1, "rounds": 3},
		"intro_seen": {},
		"stats": {},
	}


## Lädt die Datei. Fehlende oder beschädigte Dateien ergeben einen leeren Stand.
func load_file() -> bool:
	data = _blank()
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("v", 0)) != VERSION:
		last_error = "Spielstand unlesbar"
		return false
	var clean: Dictionary = DECK.normalized(parsed)
	for key: String in ["matches", "prefs", "intro_seen", "stats"]:
		if clean.get(key) is Dictionary:
			data[key] = clean[key]
	if clean.get("booked") is Array:
		data.booked = clean.booked
	var prefs: Dictionary = data.prefs
	prefs["players"] = clampi(int(prefs.get("players", 4)), 2, 4)
	prefs["difficulty"] = clampi(int(prefs.get("difficulty", 1)), 0, 2)
	prefs["rounds"] = clampi(int(prefs.get("rounds", 3)), 1, 5)
	return true


## Schreibt erst in eine Nebendatei und tauscht dann aus.
func save_file() -> bool:
	if path.is_empty():
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Spielstand nicht schreibbar"
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		last_error = "Spielstand nicht gespeichert (%d)" % error
	return error == OK


func prefs() -> Dictionary:
	return data.prefs.duplicate()


func set_prefs(players: int, difficulty: int, rounds: int) -> void:
	data.prefs = {
		"players": clampi(players, 2, 4),
		"difficulty": clampi(difficulty, 0, 2),
		"rounds": clampi(rounds, 1, 5),
	}
	save_file()


func intro_seen(game: String) -> bool:
	return bool(data.intro_seen.get(game, false))


func mark_intro_seen(game: String) -> void:
	data.intro_seen[game] = true
	save_file()


func has_match(game: String) -> bool:
	return data.matches.get(game) is Dictionary


## Kurzinfo für den Auswahlbildschirm, ohne die Partie zu laden.
func match_summary(game: String) -> Dictionary:
	if not has_match(game):
		return {}
	var saved: Dictionary = data.matches[game]
	return {
		"round": int(saved.get("round", 0)) + 1,
		"rounds_total": int(saved.get("rounds_total", 1)),
		"players": int(saved.get("players", 2)),
		"difficulty": int(saved.get("difficulty", 1)),
	}


func new_match(game: String, config: Dictionary) -> RefCounted:
	var rules := create_rules(game)
	if rules == null:
		return null
	rules.setup(config)
	store(rules)
	return rules


## Setzt eine gespeicherte Partie fort. Beschädigte Stände werden verworfen.
func resume(game: String) -> RefCounted:
	if not has_match(game):
		return null
	var rules := create_rules(game)
	if rules == null or not rules.restore(data.matches[game]):
		data.matches.erase(game)
		save_file()
		return null
	return rules


func store(rules: RefCounted) -> bool:
	data.matches[rules.game_id()] = rules.snapshot()
	return save_file()


func discard(game: String) -> void:
	if data.matches.has(game):
		data.matches.erase(game)
		save_file()


func is_booked(result_id: String) -> bool:
	return data.booked.has(result_id)


static func stars_for(place: int, difficulty: int, rounds: int) -> int:
	var stars := int(PLACE_STARS[clampi(place, 1, 4) - 1])
	if place == 1 and difficulty >= 2:
		stars += 1
	if rounds <= 1:
		stars = mini(stars, 2)
	return stars


## Bucht eine beendete Partie. Gibt die Ergebnis-Daten für Sterne und
## Host-Meldung zurück – oder {} wenn nichts (mehr) zu buchen ist.
func settle(rules: RefCounted, session_id: String = "") -> Dictionary:
	if rules == null or rules.phase() != "match_over":
		return {}
	var result_id := str(rules.s.result_id)
	if result_id.is_empty() or is_booked(result_id):
		# Schon gebucht: nur die erledigte Partie aufräumen.
		if has_match(rules.game_id()) and str(data.matches[rules.game_id()].get("result_id", "")) == result_id:
			discard(rules.game_id())
		return {}
	var place := int(rules.places()[0])
	var stars := stars_for(place, int(rules.s.difficulty), rules.rounds_total())
	data.booked.append(result_id)
	while data.booked.size() > BOOKED_LIMIT:
		data.booked.pop_front()
	data.matches.erase(rules.game_id())
	var stats: Dictionary = data.stats.get(rules.game_id(), {"played": 0, "won": 0})
	stats["played"] = int(stats.get("played", 0)) + 1
	if place == 1:
		stats["won"] = int(stats.get("won", 0)) + 1
	data.stats[rules.game_id()] = stats
	save_file()
	return {
		"resultId": result_id,
		"game": "cards",
		"variant": rules.game_id(),
		"sessionId": session_id,
		"status": "completed",
		"stars": stars,
		# Die App verbucht nur Ergebnisse mit Erfahrungspunkten: zehn je Stern.
		"xp": stars * 10,
		"place": place,
		"players": rules.players(),
		"difficulty": int(rules.s.difficulty),
		"rounds": rules.rounds_total(),
		"points": int(rules.s.scores[0]),
	}


## Lässt einen KI-Mitspieler ziehen. Der Zufallszustand bleibt Teil der Partie.
static func ai_move(rules: RefCounted, player: int, level: int = -1) -> Dictionary:
	var strength := int(rules.s.difficulty) if level < 0 else level
	var choice: Dictionary = AI.choose(rules.view(player), rules.legal_moves(player), strength, int(rules.s.ai_rng))
	rules.s.ai_rng = int(choice.rng)
	return choice.move
