extends SceneTree
## Rhythm Party am Handy (Dichte 2,625): Das Start-, Ergebnis- und
## Pausenmenü ist so hoch wie sein Inhalt (kein leerer Kasten über der Bühne),
## liegt mittig im Bild und lässt die vier Spurknöpfe frei.

const SCENE := "res://scenes/creative/rhythm_world.tscn"

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("[RhythmMenuFit] FAIL " + message)


func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _run() -> void:
	var bridge: Node = root.get_node("HostBridge")
	bridge._options["displayDensity"] = 2.625
	root.get_node("SceneRouter").launch_options = {"childKey": "rhythm-menu-fit"}
	root.size = Vector2i(1080, 2340)
	var game: Node = load(SCENE).instantiate()
	root.add_child(game)
	await _frames(10)
	for sample in [Vector2i(1080, 2340), Vector2i(2176, 1812)]:
		root.size = sample
		await _frames(8)
		_check_menu(game, "Start " + str(sample))
	game.start()
	await _frames(4)
	game._pause(true)
	await _frames(8)
	_check_menu(game, "Pause")
	game._pause(false)
	await _frames(2)
	game.queue_free()
	bridge._options.erase("displayDensity")
	await _frames(4)
	root.get_node("GameSoundscape").release_audio()
	await create_timer(0.4).timeout
	if failures.is_empty():
		print("[RhythmMenuFit] PASS: %d checks" % checks)
	else:
		print("[RhythmMenuFit] FAIL: %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _check_menu(game: Node, label: String) -> void:
	var menu: Control = game.menu
	_check(menu.visible, label + ": Menü sichtbar")
	var view := Rect2(Vector2.ZERO, game.get_viewport().get_visible_rect().size)
	var rect: Rect2 = menu.get_global_rect()
	_check(view.encloses(rect), "%s: Menü im Bild (%s)" % [label, rect])
	var content: float = game.menu_box.get_combined_minimum_size().y
	var chrome: float = menu.get_theme_stylebox("panel").get_minimum_size().y
	_check(
		rect.size.y <= maxf(180.0, content + chrome) + 2.0,
		"%s: Höhe folgt dem Inhalt (%.0f für %.0f)" % [label, rect.size.y, content + chrome]
	)
	for lane in game.lane_buttons:
		_check(
			not rect.intersects((lane as Control).get_global_rect()), "%s: Spurknopf frei" % label
		)
