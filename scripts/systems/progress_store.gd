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
##   ProgressStore.lifetime_stars()       -> alle je verdienten Sterne (steigt nur, auch wenn
##                                           die App Sterne gegen Belohnungen eintauscht)
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
var _lifetime: int = 0
var _legacy_lifetime: int = 0
var _lifetime_by_child: Dictionary = {}
var _lifetime_child_key: String = ""
var _best_streak: int = 0
var _learned: Dictionary = {}  # letter -> true
var _current_streak: int = 0


func _ready() -> void:
	_load()
	synchronize_host_wallet()


func synchronize_host_wallet() -> void:
	if HostBridge.is_embedded():
		# Flutter owns spendable stars; refresh the local snapshot at every launch.
		var options: Dictionary = HostBridge.launch_options()
		_stars = maxi(0, int(options.get("stars", 0)))
		# Ein neuer Kinderschlüssel übernimmt nie den globalen Altbestand eines anderen Kindes.
		var child: Variant = options.get("childKey", "")
		_lifetime_child_key = child if typeof(child) == TYPE_STRING else ""
		var previous: int = maxi(_legacy_lifetime, _lifetime)
		if not _lifetime_child_key.is_empty():
			previous = int(_lifetime_by_child.get(_lifetime_child_key, 0))
		_lifetime = maxi(maxi(previous, _stars), int(options.get("lifetimeStars", 0)))
		_save()
		print("[Progress] host wallet synchronized: %d (lifetime %d)" % [_stars, _lifetime])
	else:
		_lifetime_child_key = ""
		_lifetime = maxi(_legacy_lifetime, _lifetime)


func _load() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(FILE_PATH)
	if err != OK:
		print("[Progress] no save file (first run) - starting fresh")
		return
	_stars = int(cfg.get_value(SECTION, "stars", 0))
	_lifetime = maxi(_stars, int(cfg.get_value(SECTION, "lifetime", 0)))
	_legacy_lifetime = _lifetime
	_lifetime_by_child.clear()
	var saved_lifetimes: Variant = cfg.get_value(SECTION, "lifetime_by_child", {})
	if saved_lifetimes is Dictionary:
		for child in saved_lifetimes:
			var value: Variant = saved_lifetimes[child]
			if (
				typeof(child) == TYPE_STRING
				and not child.is_empty()
				and typeof(value) == TYPE_INT
				and value >= 0
			):
				_lifetime_by_child[child] = value
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
	var lifetime: int = maxi(_lifetime, _stars)
	_legacy_lifetime = maxi(_legacy_lifetime, lifetime)
	if not _lifetime_child_key.is_empty():
		_lifetime_by_child[_lifetime_child_key] = lifetime
	# Ältere Hosts ohne Schlüssel und Standalone behalten ihren bisherigen Höchststand.
	cfg.set_value(SECTION, "lifetime", _legacy_lifetime)
	cfg.set_value(SECTION, "lifetime_by_child", _lifetime_by_child)
	cfg.set_value(SECTION, "best_streak", _best_streak)
	cfg.set_value(SECTION, "learned", _learned.keys())
	cfg.save(FILE_PATH)


func add_stars(n: int) -> void:
	if n <= 0:
		return
	_stars += n
	_lifetime = maxi(_lifetime, _stars - n) + n
	stars_changed.emit(_stars)
	_save()


func total_stars() -> int:
	return _stars


## Alle je verdienten Sterne; sinkt nie, wenn die App Sterne gegen Belohnungen eintauscht.
func lifetime_stars() -> int:
	return maxi(_lifetime, _stars)


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
