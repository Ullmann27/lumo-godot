extends SceneTree
## Regression: viertes Lied, Combo-Bonus getrennt von accuracy/score,
## bestehende Charts, Saves und Reward-Wallet-Schlüssel.

const STATE = preload("res://scripts/creative/rhythm_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_songs_and_charts()
	_perfect_run_keeps_accuracy()
	_combo_milestones_and_reset()
	_note_types()
	_saves_and_rewards()
	await _world_cycles_four_songs()
	print("[RhythmParty] PASS fourth song, combo cheers, save/reward compatibility")
	quit(0)


func _songs_and_charts() -> void:
	assert(STATE.SONGS.size() == 4, "Fourth song Mondfunkeln is available")
	var ids: Array = []
	for song in STATE.SONGS:
		ids.append(str(song.id))
	assert(ids == ["sternentanz", "wolkenwalzer", "funkelreise", "mondfunkeln"])
	assert(str(STATE.SONGS[3].name) == "Mondfunkeln")
	var original := STATE.new()
	original.setup(0)
	assert(original.song.id == "sternentanz")
	assert(original.notes.size() == 40)
	assert(int(original.notes[0].lane) == 0 and str(original.notes[0].kind) == "tap")
	assert(str(original.notes[4].kind) == "hold")
	assert(str(original.notes[7].kind) == "slide")
	assert(str(original.notes[9].kind) == "star")
	assert(is_equal_approx(original.window, 0.28))
	original.setup(0, 1)
	assert(is_equal_approx(original.window, 0.22))
	original.setup(0, 2)
	assert(is_equal_approx(original.window, 0.17))
	var moon := STATE.new()
	moon.setup(3)
	assert(moon.song.id == "mondfunkeln")
	assert(moon.notes.size() == 40)
	assert(int(moon.song.bpm) == 88)
	assert(not is_equal_approx(float(moon.notes[1].time), float(original.notes[1].time)))
	moon.setup(4)
	assert(moon.song.id == "sternentanz", "Song index wraps over the catalog")


func _play_perfect(model, count: int = -1) -> void:
	var limit: int = model.notes.size() if count < 0 else count
	var done := 0
	for note in model.notes:
		if done >= limit:
			return
		if int(note.state) != 0:
			continue
		model.time = float(note.time)
		assert(model.press(int(note.lane)))
		if note.kind == "hold":
			model.advance(float(note.length))
		elif note.kind == "slide":
			model.time += float(note.length)
			assert(model.press(int(note.target)))
		model.release(int(note.lane))
		done += 1


func _perfect_run_keeps_accuracy() -> void:
	var model := STATE.new()
	model.setup(0)
	_play_perfect(model)
	assert(model.hits == 40 and model.stars() == 3 and model.accuracy() > 0.99)
	assert(model.best_combo == 40)
	assert(is_equal_approx(model.score, model.maximum))
	assert(is_equal_approx(model.combo_bonus, 85.0))
	assert(model.total_score() == int(model.score) + 85)
	assert(model.combo_xp() == 6)
	assert(model.reward_xp() == 12 + 3 * 4 + 6)
	assert(is_equal_approx(model.accuracy(), model.score / model.maximum))
	var later := STATE.new()
	later.setup(2, 1)
	_play_perfect(later)
	assert(later.hits == 40 and later.stars() == 3 and later.accuracy() > 0.99)


func _combo_milestones_and_reset() -> void:
	var model := STATE.new()
	model.setup(0)
	_play_perfect(model, 5)
	assert(model.combo == 5)
	assert(model.last_cheer == 5)
	assert(model.judgement == "Combo 5! Super!")
	assert(is_equal_approx(model.combo_bonus, 10.0))
	assert(model.combo_xp() == 2)
	model.last_cheer = 0
	_play_perfect(model, 5)
	assert(model.combo == 10)
	assert(model.last_cheer == 10)
	assert(model.judgement == "Combo 10! Fantastisch!")
	assert(is_equal_approx(model.combo_bonus, 35.0))
	assert(model.combo_xp() == 4)
	var streak := STATE.new()
	streak.setup(0)
	_play_perfect(streak, 5)
	assert(is_equal_approx(streak.combo_bonus, 10.0))
	var next: Dictionary = streak.notes[5]
	streak.time = float(next.time) + streak.window + 0.05
	streak.advance(0.01)
	assert(streak.combo == 0)
	assert(streak.misses >= 1)
	assert(is_equal_approx(streak.combo_bonus, 10.0), "Combo points stay after a miss")
	assert(streak.best_combo == 5)
	assert(streak.combo_xp() == 2)
	_play_perfect(streak, 5)
	assert(streak.combo == 5)
	assert(streak.last_cheer == 5)
	assert(is_equal_approx(streak.combo_bonus, 20.0), "A new streak can cheer again")
	var empty := STATE.new()
	empty.setup(0)
	assert(empty.stars() == 0)
	assert(empty.combo_xp() == 0)
	assert(empty.reward_xp() == 12)
	assert(empty.total_score() == 0)


func _note_types() -> void:
	var model := STATE.new()
	model.setup(0)
	assert(not model.press(3), "Wrong lane does not hit a note")
	model.time = float(model.notes[0].time)
	assert(model.press(0) and model.hits == 1)
	model.release(0)
	var hold: Dictionary = model.notes[4]
	model.time = float(hold.time)
	assert(model.press(int(hold.lane)))
	model.release(int(hold.lane))
	assert(int(hold.state) == 3, "Early hold release misses")
	var slide_model := STATE.new()
	slide_model.setup(0)
	var slide: Dictionary = slide_model.notes[7]
	slide_model.time = float(slide.time)
	assert(slide_model.press(int(slide.lane)))
	assert(int(slide.state) == 4)
	slide_model.time += float(slide.length)
	assert(slide_model.press(int(slide.target)))
	assert(int(slide.state) == 2)
	var star: Dictionary = slide_model.notes[9]
	slide_model.time = float(star.time)
	var before: float = slide_model.score
	assert(slide_model.press(int(star.lane)))
	assert(slide_model.score >= before + 199.0)


func _saves_and_rewards() -> void:
	var path := "user://lumo_rhythm_party_regression.cfg"
	var config := ConfigFile.new()
	config.set_value("sternentanz", "best", 4400)
	config.set_value("wolkenwalzer", "best", 2100)
	config.save(path)
	config = ConfigFile.new()
	assert(config.load(path) == OK)
	assert(int(config.get_value("sternentanz", "best", 0)) == 4400)
	assert(int(config.get_value("wolkenwalzer", "best", 0)) == 2100)
	config.set_value("mondfunkeln", "best", 100)
	config.save(path)
	config = ConfigFile.new()
	config.load(path)
	assert(int(config.get_value("sternentanz", "best", 0)) == 4400, "Old song bests stay readable")
	assert(int(config.get_value("wolkenwalzer", "best", 0)) == 2100)
	assert(int(config.get_value("mondfunkeln", "best", 0)) == 100)
	DirAccess.remove_absolute(path)


func _world_cycles_four_songs() -> void:
	var game: Node = load("res://scenes/creative/rhythm_world.tscn").instantiate()
	root.get_node("SceneRouter").launch_options = {"childKey": "rhythmregression"}
	root.add_child(game)
	for _i in range(6):
		await process_frame
	assert(game.has_node("RhythmHitRail"), "Concert hit rail is present")
	assert(game.has_node("RhythmBackdrop"), "LED backdrop hides the castle")
	assert(game.song_index == 0)
	game._next_song()
	game._next_song()
	game._next_song()
	assert(game.song_index == 3)
	assert(str(STATE.SONGS[game.song_index].id) == "mondfunkeln")
	assert(str(game.song_button.text).contains("Mondfunkeln"))
	assert(str(game.song_button.text).contains("4/4"))
	game._next_song()
	assert(game.song_index == 0)
	game.song_index = 3
	game.start()
	assert(str(game.model.song.id) == "mondfunkeln")
	assert(game.model.notes.size() == 40)
	var kinds := {}
	for i in game.note_nodes:
		var note: Dictionary = game.model.notes[int(i)]
		kinds[str(note.kind)] = true
		assert(game.note_nodes[i].get_child_count() >= 1)
	assert(kinds.has("tap") and kinds.has("hold") and kinds.has("slide") and kinds.has("star"))
	var seed := ConfigFile.new()
	var save_path := "user://lumo_rhythm_rhythmregression.cfg"
	seed.set_value("sternentanz", "best", 4400)
	seed.set_value("mondfunkeln", "best", 50)
	seed.save(save_path)
	_play_perfect(game.model)
	var seen: Dictionary = {}
	var bridge: Node = root.get_node("HostBridge")
	var on_reward := func(payload: Dictionary) -> void:
		seen.clear()
		for key in payload:
			seen[key] = payload[key]
	bridge.reward_reported.connect(on_reward)
	game._finish()
	if seen.is_empty():
		push_error("[RhythmParty] Reward wallet emitted no payload")
		quit(1)
		return
	assert(seen.get("game", "") == "rhythm")
	assert(seen.get("status", "") == "completed")
	assert(int(seen.get("stars", 0)) == 3)
	assert(seen.has("resultId") and str(seen.get("resultId", "")) != "")
	assert(int(seen.get("xp", 0)) == game.model.reward_xp())
	assert(int(seen.get("xp", 0)) == 12 + 3 * 4 + 6)
	var saved := ConfigFile.new()
	assert(saved.load(save_path) == OK)
	assert(int(saved.get_value("sternentanz", "best", 0)) == 4400, "Other song scores stay intact")
	assert(int(saved.get_value("mondfunkeln", "best", 0)) == game.model.total_score())
	assert(game.model.total_score() > int(game.model.score))
	DirAccess.remove_absolute(save_path)
	if bridge.reward_reported.is_connected(on_reward):
		bridge.reward_reported.disconnect(on_reward)
	game.queue_free()
	await process_frame
