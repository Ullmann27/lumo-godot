extends RefCounted
## Saved state of the village defence: lane layout, trained squads, occupied
## buildings, defended waves, the next wave day and the tutorial progress.
## Stored in its own file next to the village save, so every existing
## village save keeps loading byte-for-byte unchanged (no migration needed;
## a missing file means "fresh defence, tutorial not started").

const SIM = preload("res://scripts/creative/build_defense_sim.gd")
const VERSION := 1
const FIRST_WAVE_DAY := 4
const WAVE_INTERVAL := 4
const TUTORIAL_STEPS: Array[Dictionary] = [
	{"id": "build_house", "title": "Baue ein Wohnhaus",
		"text": "Tippe auf einen freien Bauplatz und wähle unten das Wohnhaus."},
	{"id": "gather", "title": "Sammle Ressourcen",
		"text": "Tippe auf „Nächster Tag“. Deine Gebäude liefern Holz, Stein und Essen."},
	{"id": "wall", "title": "Baue eine Mauer",
		"text": "Öffne „Verteidigung“ und baue im Norden eine Mauer. Sie hält die Hasen auf."},
	{"id": "tower", "title": "Baue einen Wachturm",
		"text": "Ein Wachturm schießt Schaumpfeile auf Hasen, die sich nähern."},
	{"id": "train", "title": "Bilde Wachen aus",
		"text": "Bilde zwei Wachen aus. Speer schlägt Reiter, Reiter schlägt Bogen, "
			+ "Bogen schlägt Ritter, Ritter schlägt Speer."},
	{"id": "defend", "title": "Wehre die erste Welle ab",
		"text": "Die frechen Hasen kommen! Halte deine Mauer – dann purzeln sie davon."},
]

var defense: Dictionary = SIM.empty_defense()
var waves_won := 0
var waves_lost := 0
var next_wave_day := FIRST_WAVE_DAY
## building key -> occupying hare squad
var captured: Dictionary = {}
var tutorial_step := 0
var tutorial_skipped := false


func tutorial_active() -> bool:
	return not tutorial_skipped and tutorial_step < TUTORIAL_STEPS.size()


func tutorial_current() -> Dictionary:
	return TUTORIAL_STEPS[tutorial_step] if tutorial_active() else {}


## Advances only when the event matches the current step, in order.
func tutorial_event(id: String) -> bool:
	if not tutorial_active() or TUTORIAL_STEPS[tutorial_step].id != id:
		return false
	tutorial_step += 1
	return true


func skip_tutorial() -> void:
	tutorial_skipped = true


func level(chapter: int) -> int:
	return SIM.level_for(chapter, waves_won)


func days_until_wave(day: int) -> int:
	return maxi(0, next_wave_day - day)


## Lane the hares will come from, as the scouts currently read the defence.
func forecast(chapter: int) -> Dictionary:
	return SIM.plan_wave(level(chapter), defense)


func build(lane: String, kind: String) -> String:
	if not defense.lanes.has(lane):
		return "Diese Seite gibt es nicht."
	var data: Dictionary = defense.lanes[lane]
	match kind:
		"wall":
			if int(data.wall) >= SIM.MAX_WALL:
				return "Diese Mauer ist schon ganz hoch."
			data.wall = int(data.wall) + 1
		"tower":
			if int(data.towers) >= SIM.MAX_TOWERS:
				return "Hier stehen schon drei Wachtürme."
			data.towers = int(data.towers) + 1
		"gate":
			if data.gate:
				return "Hier gibt es schon ein Tor."
			if int(data.wall) == 0:
				return "Ein Tor braucht zuerst eine Mauer."
			data.gate = true
		"watchpost":
			if defense.watchpost:
				return "Der Wachposten steht schon."
			defense.watchpost = true
		_:
			return "Unbekanntes Bauwerk."
	return ""


func train(lane: String, role: String, count: int) -> String:
	if not defense.lanes.has(lane) or role not in SIM.ROLES or count < 1:
		return "Diese Wache gibt es nicht."
	var squad: Dictionary = defense.lanes[lane].squad
	if int(squad[role]) + count > SIM.MAX_SQUAD:
		return "Mehr Wachen passen hier nicht hin."
	squad[role] = int(squad[role]) + count
	return ""


## Move trained guards between lanes (formation / group command).
func move_squad(from_lane: String, to_lane: String, role: String, count: int) -> String:
	if not defense.lanes.has(from_lane) or not defense.lanes.has(to_lane) or role not in SIM.ROLES:
		return "Diese Gruppe gibt es nicht."
	var source: Dictionary = defense.lanes[from_lane].squad
	if count < 1 or int(source[role]) < count:
		return "So viele Wachen stehen dort nicht."
	if int(defense.lanes[to_lane].squad[role]) + count > SIM.MAX_SQUAD:
		return "Mehr Wachen passen dort nicht hin."
	source[role] = int(source[role]) - count
	defense.lanes[to_lane].squad[role] = int(defense.lanes[to_lane].squad[role]) + count
	return ""


## Runs the wave due on `day`. Survivors stay; occupied buildings are listed
## in `captured`. Difficulty steps up only after a defended wave.
func run_wave(day: int, chapter: int, buildings: Dictionary) -> Dictionary:
	var wave := SIM.plan_wave(level(chapter), defense)
	var result := SIM.resolve_wave(defense, wave, buildings)
	for lane in result.lanes:
		defense.lanes[lane].squad = result.lanes[lane].defenders_left.duplicate()
		var wall_hp := float(result.lanes[lane].wall_left)
		if int(defense.lanes[lane].wall) > 0:
			# Walls are repaired by the villagers; a broken gate needs rebuilding.
			if wall_hp <= 0.0:
				defense.lanes[lane].gate = false
	for key in result.captured:
		captured[key] = result.captured[key]
	if result.won:
		waves_won += 1
		tutorial_event("defend")
	else:
		waves_lost += 1
	next_wave_day = day + WAVE_INTERVAL
	result.wave = wave
	return result


## Send guards from a lane to free an occupied building. Nothing is destroyed.
func recapture(key: String, lane: String, chapter: int) -> Dictionary:
	if not captured.has(key) or not defense.lanes.has(lane):
		return {"freed": false, "reason": "Hier sind keine Hasen."}
	var squad: Dictionary = defense.lanes[lane].squad
	var outcome := SIM.recapture(captured[key], squad, level(chapter))
	defense.lanes[lane].squad = outcome.squad_left.duplicate()
	if outcome.freed:
		captured.erase(key)
	return outcome


func is_captured(key: String) -> bool:
	return captured.has(key)


func to_data() -> Dictionary:
	return {
		"version": VERSION,
		"defense": defense.duplicate(true),
		"waves_won": waves_won,
		"waves_lost": waves_lost,
		"next_wave_day": next_wave_day,
		"captured": captured.duplicate(true),
		"tutorial": {"step": tutorial_step, "skipped": tutorial_skipped},
	}


## Returns a restored state or null for anything malformed (the caller then
## keeps the file untouched and starts a fresh defence in memory).
static func restore(raw: Variant):
	if not raw is Dictionary or raw.get("version") != VERSION:
		return null
	if not SIM.valid_defense(raw.get("defense")):
		return null
	for key in ["waves_won", "waves_lost", "next_wave_day"]:
		if not SIM._int_in(raw.get(key), 0, 100000):
			return null
	var tutorial: Variant = raw.get("tutorial")
	if not tutorial is Dictionary or not tutorial.get("skipped") is bool:
		return null
	if not SIM._int_in(tutorial.get("step"), 0, TUTORIAL_STEPS.size()):
		return null
	var occupied: Variant = raw.get("captured")
	if not occupied is Dictionary:
		return null
	for key in occupied:
		if not key is String or not occupied[key] is Dictionary or occupied[key].size() != SIM.ROLES.size():
			return null
		for role in SIM.ROLES:
			if not SIM._int_in(occupied[key].get(role), 0, SIM.MAX_SQUAD):
				return null
	var state = load("res://scripts/creative/build_defense_state.gd").new()
	state.defense = _typed(raw.defense)
	state.waves_won = int(raw.waves_won)
	state.waves_lost = int(raw.waves_lost)
	state.next_wave_day = int(raw.next_wave_day)
	state.tutorial_step = int(tutorial.step)
	state.tutorial_skipped = bool(tutorial.skipped)
	for key in occupied:
		var squad := {}
		for role in SIM.ROLES:
			squad[role] = int(occupied[key][role])
		state.captured[key] = squad
	return state


## JSON turns integers into floats; normalise the layout back to ints.
static func _typed(raw: Dictionary) -> Dictionary:
	var result := SIM.empty_defense()
	result.watchpost = bool(raw.watchpost)
	for lane in SIM.LANES:
		var data: Dictionary = raw.lanes[lane]
		result.lanes[lane].wall = int(data.wall)
		result.lanes[lane].towers = int(data.towers)
		result.lanes[lane].gate = bool(data.gate)
		for role in SIM.ROLES:
			result.lanes[lane].squad[role] = int(data.squad[role])
	return result


static func path_for(village_save_path: String) -> String:
	return village_save_path.get_basename() + "_defense.json"
