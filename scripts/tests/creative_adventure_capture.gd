extends SceneTree
const RHYTHM = preload("res://scripts/creative/rhythm_state.gd")
const TREASURE = preload("res://scripts/creative/treasure_state.gd")
var out_dir := "res://exports/creative-build"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rhythm = RHYTHM.new()
	rhythm.setup(0)
	rhythm.time = float(rhythm.notes[0].time)
	assert(not rhythm.press(3), "Wrong lane does not hit a note")
	assert(rhythm.press(0) and rhythm.hits == 1)
	rhythm.release(0)
	var hold: Dictionary = rhythm.notes[4]
	rhythm.time = float(hold.time)
	assert(rhythm.press(int(hold.lane)))
	rhythm.release(int(hold.lane))
	assert(int(hold.state) == 3, "Early hold release misses")
	rhythm.setup(2, 1)
	for note in rhythm.notes:
		rhythm.time = float(note.time)
		assert(rhythm.press(int(note.lane)))
		if note.kind == "hold":
			rhythm.advance(float(note.length))
		elif note.kind == "slide":
			rhythm.time += float(note.length)
			assert(rhythm.press(int(note.target)))
		rhythm.release(int(note.lane))
	assert(rhythm.hits == 40 and rhythm.stars() == 3 and rhythm.accuracy() > 0.99)
	var adventure = TREASURE.new()
	assert(not adventure.answer(0, Vector3.ZERO), "Clues require approaching the actual location")
	for clue in TREASURE.CLUES:
		assert(not adventure.answer((int(clue.correct) + 1) % 3, clue.at))
		assert(adventure.answer(int(clue.correct), clue.at))
	assert(adventure.completed and adventure.inventory.has("Sternenschatz"))
	var recovered = TREASURE.new()
	assert(recovered.restore(adventure.to_data()) and recovered.completed)
	var invalid: Dictionary = adventure.to_data()
	invalid.chapter = 20
	assert(not recovered.restore(invalid) and recovered.completed)
	print(
		"[CreativeAdventure] PASS timing, early release, slide, all charts, clue distance, inventory gates, reload"
	)
	if "--logic-only" in OS.get_cmdline_user_args():
		quit(0)
		return
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/creative/rhythm_world.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await _capture("05_rhythm_song_select")
	game.start()
	game.model.time = 4.2
	game._process(0)
	await _capture("06_rhythm_play")
	var before: float = game.model.time
	game._pause(true)
	for _i in range(12):
		await process_frame
	assert(game.model.time == before, "Pause freezes timing and input")
	game._pause(false)
	game.queue_free()
	await process_frame
	game = load("res://scenes/creative/treasure_world.tscn").instantiate()
	root.add_child(game)
	for _i in range(10):
		await process_frame
	game.model = TREASURE.new()
	game.model.result_id = "creative-treasure-qa"
	game.save_path = "user://lumo_treasure_qa.json"
	game.player.position = Vector3(-9, 0.2, -4)
	game.camera.position = game.player.position + Vector3(10, 14, 19)
	game._update()
	await _capture("07_treasure_exploration")
	game.player.position = TREASURE.CLUES[0].at
	await physics_frame
	game._interact()
	assert(game.paused and game.modal.visible)
	await _capture("08_treasure_first_clue")
	game._answer(0)
	assert(game.model.chapter == 1 and game.model.inventory.has("Blattschlüssel"))
	assert(game._save())
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	assert(saved is Dictionary and recovered.restore(saved) and recovered.chapter == 1)
	game._inventory()
	await _capture("09_treasure_inventory")
	game.queue_free()
	await process_frame
	print(
		"[CreativeAdventure] PASS actual 3D notes, pause, clue, inventory, JSON save, 5 screenshots"
	)
	quit(0)


func _capture(name: String) -> void:
	for _i in range(8):
		await process_frame
	var frame: Image = root.get_texture().get_image()
	assert(frame != null and frame.get_width() == 1280)
	assert(frame.save_png(out_dir + "/" + name + ".png") == OK)
	print("[CreativeAdventure] screenshot: ", name)
