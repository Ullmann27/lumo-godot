extends SceneTree
## Puzzle-Atelier am Handy (Dichte 2,625): Das Auswahlmenü zeigt das gewählte
## Bild groß (und wechselt mit „Bild: …“), der Titel passt ins schmale
## Hochformat, das Einrasten eines Teils ist hörbar und das fertige Bild
## zeigt die verdienten Sterne als Sternreihe.

const SCENE := "res://scenes/creative/puzzle_world.tscn"
const SAVE := "user://lumo_puzzle_feedback_regression.json"

var checks: int = 0
var failures: Array[String] = []
var sounds: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("[PuzzleFeedback] FAIL " + message)


func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _run() -> void:
	var bridge: Node = root.get_node("HostBridge")
	bridge._options["displayDensity"] = 2.625
	root.get_node("SceneRouter").launch_options = {"childKey": "puzzle_feedback_regression"}
	DirAccess.remove_absolute(SAVE)
	root.get_node("AudioManager").sfx_played.connect(func(name: String): sounds.append(name))
	root.size = Vector2i(1080, 2340)
	var game: Node = load(SCENE).instantiate()
	root.add_child(game)
	await _frames(10)
	for sample in [Vector2i(1080, 2340), Vector2i(2176, 1812)]:
		root.size = sample
		await _frames(8)
		_check_selection(game, str(sample))
	root.size = Vector2i(1080, 2340)
	await _frames(6)
	_check(game.title_label.text == "PUZZLE-ATELIER", "schmaler Titel im Hochformat")
	var before: int = game.selected_motif
	game._next_motif()
	await _frames(3)
	var picture := game.menu_box.find_child("MotifPicture", true, false) as TextureRect
	_check(
		(
			game.selected_motif != before
			and picture != null
			and picture.texture == game.MOTIFS[game.selected_motif]
		),
		"Vorschau wechselt mit dem Bild"
	)
	game.selected_count = 6
	game.start()
	await _frames(3)
	sounds.clear()
	for id in range(6):
		game._tray()
		await physics_frame
		await physics_frame
		var point: Vector2 = game.camera.unproject_position(
			game.nodes[id].global_position + Vector3.UP * 0.16
		)
		game._pick(point, 0)
		if game.dragging != id:
			_check(false, "Teil %d greifbar" % id)
			continue
		var target: Vector2 = game.model.target(id)
		game._drag(game.camera.unproject_position(Vector3(target.x, 0.35, target.y)))
		game._drop()
		if id == 0:
			_check(sounds.has("puzzle_snap"), "Einrasten ist hörbar (%s)" % str(sounds))
	await _frames(4)
	_check(game.model.complete(), "Runde fertig gelegt")
	var row: HBoxContainer = null
	for child in game.menu_box.get_children():
		if child is HBoxContainer and child.get_child_count() == 3:
			row = child
	_check(row != null, "Sternreihe im Ergebnis")
	if row != null:
		var filled: int = 0
		for icon in row.get_children():
			filled += 1 if bool(icon.get("filled")) else 0
		_check(filled >= 2, "verdiente Sterne gefüllt (%d)" % filled)
	game.queue_free()
	await _frames(3)
	DirAccess.remove_absolute(SAVE)
	bridge._options.erase("displayDensity")
	root.get_node("GameSoundscape").release_audio()
	for voice in root.get_node("AudioManager").get("_pool"):
		voice.stop()
		voice.stream = null
	await create_timer(0.4).timeout
	if failures.is_empty():
		print("[PuzzleFeedback] PASS: %d checks" % checks)
	else:
		print("[PuzzleFeedback] FAIL: %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _check_selection(game: Node, label: String) -> void:
	var preview := game.menu_box.find_child("MotifPreview", false, false) as Control
	_check(preview != null and preview.is_visible_in_tree(), label + ": Bildvorschau sichtbar")
	if preview == null:
		return
	var picture := preview.find_child("MotifPicture", true, false) as TextureRect
	_check(
		picture != null and picture.texture == game.MOTIFS[game.selected_motif],
		label + ": Vorschau zeigt das gewählte Bild"
	)
	_check(preview.size.y >= 96.0, label + ": Vorschau groß genug (%.0f)" % preview.size.y)
	var view := Rect2(Vector2.ZERO, game.get_viewport().get_visible_rect().size)
	_check(
		view.encloses(game.menu.get_global_rect().grow(-1.0)),
		"%s: Menü im Bild (%s)" % [label, str(game.menu.get_global_rect())]
	)
