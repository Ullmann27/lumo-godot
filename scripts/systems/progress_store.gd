## ProgressStore (Autoload "ProgressStore") - persistenter Lernfortschritt.
##
## Speichert Sterne, Streak-Bestleistung und welche Buchstaben das Kind
## schon erfolgreich abgefragt hat. Persistenz via user://progress.cfg.
##
## API:
##   ProgressStore.add_stars(n)           -> total_stars wachsen
##   ProgressStore.mark_letter_learned(c) -> Buchstabe in Set aufnehmen
##   ProgressStore.report_streak(n)       -> evtl. best_streak updaten
##   ProgressStore.total_stars()
##   ProgressStore.best_streak()
##   ProgressStore.learned_letters()      -> Array[String]
##   ProgressStore.is_letter_learned(c)
##
## Signals:
##   stars_changed(total)
##   streak_changed(best, current_in_session)
##   letters_changed(count)
extends Node

signal stars_changed(total: int)
signal streak_changed(best: int, current: int)
signal letters_changed(learned_count: int)

const FILE_PATH: String = "user://progress.cfg"
const SECTION: String = "progress"

var _stars: int = 0
var _best_streak: int = 0
var _learned: Dictionary = {}  # letter -> true
var _current_streak: int = 0


func _ready() -> void:
	_load()


func _load() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(FILE_PATH)
	if err != OK:
		print("[Progress] no save file (first run) - starting fresh")
		return
	_stars = int(cfg.get_value(SECTION, "stars", 0))
	_best_streak = int(cfg.get_value(SECTION, "best_streak", 0))
	var arr: Array = cfg.get_value(SECTION, "learned", [])
	for x in arr:
		_learned[String(x)] = true
	print(
		"[Progress] loaded stars:%d streak:%d letters:%d" % [_stars, _best_streak, _learned.size()]
	)


func _save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(SECTION, "stars", _stars)
	cfg.set_value(SECTION, "best_streak", _best_streak)
	cfg.set_value(SECTION, "learned", _learned.keys())
	cfg.save(FILE_PATH)


func add_stars(n: int) -> void:
	if n <= 0:
		return
	_stars += n
	stars_changed.emit(_stars)
	_save()


func total_stars() -> int:
	return _stars


func best_streak() -> int:
	return _best_streak


func current_streak() -> int:
	return _current_streak


## In einer laufenden Spielrunde aufrufen wenn eine Antwort richtig war.
## Erhoeht _current_streak und ggf. _best_streak.
func streak_hit() -> void:
	_current_streak += 1
	if _current_streak > _best_streak:
		_best_streak = _current_streak
		_save()
	streak_changed.emit(_best_streak, _current_streak)


## Bei falscher Antwort: Streak resettet.
func streak_break() -> void:
	if _current_streak == 0:
		return
	_current_streak = 0
	streak_changed.emit(_best_streak, _current_streak)


## Beim Game-Start: aktuelle Session-Streak zuruecksetzen.
func streak_reset() -> void:
	_current_streak = 0
	streak_changed.emit(_best_streak, _current_streak)


func mark_letter_learned(letter: String) -> void:
	var key: String = letter.to_lower()
	if _learned.has(key):
		return
	_learned[key] = true
	letters_changed.emit(_learned.size())
	_save()


func is_letter_learned(letter: String) -> bool:
	return _learned.has(letter.to_lower())


func learned_letters() -> Array:
	return _learned.keys()


## Komplett-Reset (nur fuer Tests / Parent-Bereich).
func reset_all() -> void:
	_stars = 0
	_best_streak = 0
	_learned.clear()
	_current_streak = 0
	_save()
	stars_changed.emit(_stars)
	streak_changed.emit(_best_streak, _current_streak)
	letters_changed.emit(0)
