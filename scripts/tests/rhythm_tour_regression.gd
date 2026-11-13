extends SceneTree
const STATE = preload("res://scripts/creative/rhythm_state.gd")
const TOUR = preload("res://scripts/creative/rhythm_tour.gd")
var checks := 0
var failures: Array[String] = []


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_warning("[RhythmTour] " + message)


func _initialize() -> void:
	call_deferred("_run")


func _play(model, miss_count := 0, good_only := false) -> void:
	for index in range(model.notes.size()):
		var note: Dictionary = model.notes[index]
		if index < miss_count:
			model.advance(maxf(0, float(note.time) + model.window + 0.01 - model.time))
			continue
		var error: float = model.window * 0.6 if good_only else 0.0
		model.advance(maxf(0, float(note.time) + error - model.time))
		_check(model.press(int(note.lane)), "Chart onset can be played")
		if note.kind == "hold":
			model.advance(maxf(0, float(note.time) + float(note.length) + 0.01 - model.time))
		elif note.kind == "slide":
			model.advance(maxf(0, float(note.time) + float(note.length) + error - model.time))
			_check(model.press(int(note.target)), "Slide can reach adjacent lane before next note")
			model.release(int(note.target))
		model.release(int(note.lane))
	model.advance(maxf(0, model.duration - model.time))


func _run() -> void:
	var fingerprints: Array[String] = []
	for song in range(4):
		var previous_duration := INF
		for difficulty in range(3):
			var model = STATE.new()
			model.setup(song, difficulty)
			_check(model.notes.size() == 40 and model.maximum == 4400, "Each chart keeps equal reward potential")
			_check(model.duration < previous_duration, "Higher difficulty adds denser musical spacing")
			previous_duration = model.duration
			var copy = STATE.new()
			copy.setup(song, difficulty)
			_check(copy.notes == model.notes, "Charts are deterministic")
			var beat: float = 60.0 / model.song.bpm
			var fingerprint := PackedStringArray()
			for index in range(model.notes.size()):
				var note: Dictionary = model.notes[index]
				_check(is_equal_approx(note.time / beat * 2, roundf(note.time / beat * 2)), "Note lies on audible half-beat grid")
				_check(int(note.lane) in [0, 1, 2, 3] and abs(int(note.target) - int(note.lane)) == 1, "Slides use adjacent touch targets")
				if note.kind in ["hold", "slide"] and index + 1 < model.notes.size():
					_check(float(note.time) + float(note.length) + model.window < float(model.notes[index + 1].time), "Hold and slide have a fair completion window")
				fingerprint.append("%d:%s:%.2f" % [int(note.lane), note.kind, float(note.time) / beat])
			if difficulty == 0:
				fingerprints.append("|".join(fingerprint))
			_play(model)
			_check(model.hits == 40 and model.misses == 0 and model.accuracy() > 0.999, "Every song and difficulty can be completed fairly")
	for a in range(fingerprints.size()):
		for b in range(a + 1, fingerprints.size()):
			_check(fingerprints[a] != fingerprints[b], "Songs have different playable patterns")
	var validation = STATE.new()
	validation.setup(0)
	_check(not validation.press(-1) and not validation.press(4) and validation.held.is_empty(), "Invalid lanes cannot create phantom input")
	validation.time = validation.notes[4].time
	validation.press(validation.notes[4].lane)
	validation.release(validation.notes[4].lane)
	_check(validation.notes[4].state == 3 and validation.misses == 1, "Early hold release remains a miss")
	var late = STATE.new()
	late.setup(1)
	late.advance(late.notes[0].time + late.window + 0.01 - late.time)
	_check(late.notes[0].state == 3 and not late.press(late.notes[0].lane), "Late presses cannot resurrect missed notes")

	var tour = TOUR.new()
	var old := ConfigFile.new()
	old.set_value("sternentanz", "best", 4485)
	old.set_value("other_setting", "parent", "retained")
	_check(tour.read_from(old), "Original score format loads without migration")
	var untouched = STATE.new()
	untouched.setup(0)
	_check(not tour.record(0, 0, untouched.notes, "unfinished").accepted, "Unfinished round cannot unlock a stage")
	_play(untouched, 10, true)
	_check(not tour.record(2, 0, untouched.notes, "locked").accepted, "Locked stage cannot skip progression")
	for difficulty in range(3):
		for index in range(4):
			var model = STATE.new()
			model.setup(index, difficulty)
			_play(model, 10, true)
			var id := "round_%d_%d" % [difficulty, index]
			var result: Dictionary = tour.record(index, difficulty, model.notes, id)
			_check(model.misses == 10 and model.accuracy() < 0.60, "Tour fixture deliberately includes misses and only good timing")
			_check(result.accepted and result.passed and result.newly_completed, "Tour goal accepts attainable non-perfect play")
			var attempts: Dictionary = tour.attempts.duplicate()
			_check(not tour.record(index, difficulty, model.notes, id).accepted and tour.attempts == attempts, "Duplicate round cannot increase attempts or progression")
		_check(tour.cleared[difficulty] == 4, "Each difficulty has an independent complete four-stage tour")
	tour.write_to(old)
	_check(old.get_value("sternentanz", "best") == 4485 and old.get_value("other_setting", "parent") == "retained", "Tour writes preserve legacy and unknown settings")
	var path := "user://rhythm_tour_model_regression.cfg"
	_check(old.save(path) == OK, "Additive campaign saves through actual ConfigFile")
	var reloaded := ConfigFile.new()
	_check(reloaded.load(path) == OK, "Campaign reads from disk")
	var restored = TOUR.new()
	_check(restored.read_from(reloaded) and restored.cleared == tour.cleared and restored.best_hits == tour.best_hits and restored.attempts == tour.attempts, "All difficulties and best attempts survive disk reload")
	var sibling = TOUR.new()
	_check(sibling.read_from(ConfigFile.new()) and sibling.cleared == [0, 0, 0], "Another child begins with independent progress")
	old.set_value(TOUR.SECTION, "version", 2)
	_check(not sibling.read_from(old), "Unknown tour version cannot be overwritten as version one")
	DirAccess.remove_absolute(path)
	if failures.is_empty():
		print("[RhythmTour] PASS checks=", checks, ": distinct fair charts, three difficulties, non-perfect campaign and additive saves")
		quit(0)
	else:
		print("[RhythmTour] FAIL ", failures)
		quit(1)
