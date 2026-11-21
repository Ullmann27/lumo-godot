extends SceneTree
## Wolkeninseln: Pause-, Kurs- und Lernfenster am Handy (Dichte 2,625) im
## schmalen Hochformat und im offenen Fold quer. Das Fenster bleibt mittig im
## Bild, kein Knopf ragt hinaus, die Höhe folgt dem Inhalt (kein leerer
## Kasten über dem Stick), Überschriften und Lernfragen wachsen mit der Dichte.

const SCENE := "res://scenes/games/jump_islands.tscn"
const DENSITY: float = 2.625

var checks: int = 0
var failures: Array[String] = []
var game


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("[JumpModalLayout] FAIL " + message)


func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _run() -> void:
	DirAccess.remove_absolute("user://jump_session.cfg")
	var bridge: Node = root.get_node("HostBridge")
	bridge._options["displayDensity"] = DENSITY
	root.size = Vector2i(1080, 2340)
	game = load(SCENE).instantiate()
	root.add_child(game)
	await _frames(8)
	for sample in [Vector2i(1080, 2340), Vector2i(2176, 1812)]:
		root.size = sample
		game._layout_ui()
		await _frames(4)
		game._pause()
		await _frames(6)
		_check_modal("Pause " + str(sample))
		var title: Label = game.modal_column.get_child(0)
		var unit: float = game._ui_unit()
		_check(
			title.get_theme_font_size("font_size") >= roundi(28 * unit),
			"Pause-Überschrift wächst mit der Dichte %s" % str(sample)
		)
		if sample.x > sample.y:
			var stick: Rect2 = game.movement_stick.get_global_rect()
			_check(
				not game.modal.get_global_rect().intersects(stick),
				"Pausefenster lässt den Stick frei (quer)"
			)
		game._show_courses()
		await _frames(6)
		_check_modal("Kurse " + str(sample))
		game._resume()
		await _frames(3)
		_check(not game.modal.visible, "Weiterspielen schließt das Fenster")
	root.size = Vector2i(1080, 2340)
	game._layout_ui()
	await _frames(3)
	game._open_question()
	await _frames(6)
	_check_modal("Lernfrage")
	var prompt: Label = game.modal_column.get_child(1)
	_check(
		prompt.get_theme_font_size("font_size") >= roundi(27 * game._ui_unit()),
		"Lernfrage groß genug (%d)" % prompt.get_theme_font_size("font_size")
	)
	# Wiederaufnahme: die Wartemeldung verschwindet nach „Weiterspielen“.
	game.question_open = false
	game.modal.hide()
	game._set_controls_enabled(true)
	game.message.text = game.RESTORED_TEXT
	game._pause()
	game._resume()
	_check(game.message.text != game.RESTORED_TEXT, "Wartemeldung nach dem Weiterspielen ersetzt")
	bridge._options.erase("displayDensity")
	game.abandoned = true
	game.queue_free()
	await _frames(3)
	DirAccess.remove_absolute("user://jump_session.cfg")
	root.get_node("GameSoundscape").release_audio()
	for voice in root.get_node("AudioManager").get("_pool"):
		voice.stop()
		voice.stream = null
	await _frames(20)
	if failures.is_empty():
		print("[JumpModalLayout] PASS: %d checks" % checks)
	else:
		print("[JumpModalLayout] FAIL: %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _check_modal(label: String) -> void:
	var view := Rect2(Vector2.ZERO, game.get_viewport().get_visible_rect().size)
	var rect: Rect2 = game.modal.get_global_rect()
	_check(view.encloses(rect), "%s: Fenster im Bild (%s in %s)" % [label, rect, view])
	_check(
		absf(rect.get_center().x - view.get_center().x) < 2.0,
		"%s: Fenster mittig (%.1f)" % [label, rect.get_center().x - view.get_center().x]
	)
	for item in game.modal_column.get_children():
		if item is Button:
			var button_rect: Rect2 = item.get_global_rect()
			_check(
				button_rect.size.x <= rect.size.x + 0.5,
				"%s: Knopf passt ins Fenster (%s)" % [label, item.text]
			)
	var content: float = game.modal_column.get_combined_minimum_size().y
	_check(
		rect.size.y <= maxf(content + 120.0, 0.0) or rect.size.y >= view.size.y * 0.8,
		"%s: Höhe folgt dem Inhalt (%.0f für %.0f)" % [label, rect.size.y, content]
	)
