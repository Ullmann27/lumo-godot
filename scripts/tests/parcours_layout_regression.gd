extends SceneTree
## Layout und Touch des Abenteuer-Parcours auf schmalem Hochformat (1080×2340), Querformat
## (2340×1080) und dem offenen Fold (1812×2176): Weltwahl, Fahren, zu Fuß, Pause und
## Ergebnis. Jedes sichtbare Tippziel liegt ganz im Bild, ist mindestens 48 dp groß
## (126 px) und überdeckt kein anderes Tippziel. Mit xvfb und gl_compatibility starten.

const SIZES: Array = [Vector2i(1080, 2340), Vector2i(2340, 1080), Vector2i(1812, 2176)]
const MIN_PX: float = 126.0
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[ParcoursLayout] FAIL: " + text)


## Bildschirmrechteck eines Controls in echten Fensterpixeln.
func _screen_rect(control: Control) -> Rect2:
	var xform: Transform2D = control.get_viewport().get_final_transform() * control.get_global_transform_with_canvas()
	return xform * Rect2(Vector2.ZERO, control.size)


func _targets(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			var c := child as Control
			var tappable: bool = (
				c is Button or c.has_signal("hold_changed") or c.has_signal("axis_changed")
				or (c.has_signal("button_down") and c.has_signal("pressed"))
			)
			if tappable and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				out.append(c)
				continue
		_targets(child, out)


func _audit(label: String, root_control: Control, window: Vector2) -> void:
	var targets: Array = []
	_targets(root_control, targets)
	_check(targets.size() > 0, label + ": Tippziele vorhanden")
	var screen := Rect2(Vector2.ZERO, window).grow(0.5)
	var rects: Array[Rect2] = []
	for control in targets:
		var rect: Rect2 = _screen_rect(control)
		var scroll_parent: bool = control.get_parent() != null and control.find_parent("ChoiceScroll") != null
		if not scroll_parent:
			_check(screen.encloses(rect), "%s: %s liegt im Bild %s" % [label, control.name, rect])
		_check(
			minf(rect.size.x, rect.size.y) >= MIN_PX - 0.5,
			"%s: %s ist %.0f px groß (mindestens 48 dp)" % [label, control.name, minf(rect.size.x, rect.size.y)]
		)
		for other in rects:
			_check(not rect.grow(-1.0).intersects(other.grow(-1.0)), "%s: %s überdeckt kein anderes Ziel" % [label, control.name])
		rects.append(rect)


func _run() -> void:
	for size in SIZES:
		root.get_window().size = size
		root.get_window().content_scale_size = Vector2i(1280, 720)
		await process_frame
		var router = root.get_node("SceneRouter")
		router.launch_options = {"childKey": "parcours_layout"}
		var game: Node = load("res://scenes/games/kart_parcours.tscn").instantiate()
		root.add_child(game)
		root.get_window().size = size
		for i in range(6):
			await process_frame
		game.set_physics_process(false)
		var window := Vector2(size)
		var label := "%dx%d" % [size.x, size.y]
		_audit(label + " Weltwahl", game.hud.root, window)
		var worlds = load("res://scripts/games/parcours/parcours_worlds.gd")
		game.start_world(worlds.playable_ids()[0], "zeitlauf")
		game.countdown = 0.0
		for i in range(6):
			game.step_game(1.0 / 60.0, 0.0, 0.0, true, Vector2.ZERO)
			await process_frame
		_audit(label + " Fahren", game.hud.root, window)
		# Zu Fuß an der ersten Station
		var run = game.run
		if run.course.stations.size() > 0:
			var s: Dictionary = run.course.stations[0]
			run.drive.place(s.kart_pos, run.drive.heading)
			run.station = 0
			run.leave_kart()
			run.walker.place(s.lever, 0.0)
			for i in range(4):
				game.step_game(1.0 / 60.0, 0.0, 0.0, false, Vector2.ZERO)
				await process_frame
			_check(game.hud.jump_button.visible and game.hud.context_button.visible, label + ": zu Fuß SPRINGEN und HEBEL sichtbar")
			_check(not game.hud.gas_button.visible, label + ": zu Fuß kein GAS")
			_audit(label + " Zu Fuß", game.hud.root, window)
		game.pause_game()
		await process_frame
		await process_frame
		var modal_targets: Array = []
		_targets(game.hud.modal, modal_targets)
		_check(modal_targets.size() >= 4, label + ": Pause hat Weiter, Neu, Weltwahl, Kart-Menü")
		_audit(label + " Pause", game.hud.modal, window)
		game.resume_game()
		game.run.finished = true
		game._finish()
		await process_frame
		await process_frame
		_audit(label + " Ergebnis", game.hud.modal, window)
		game.queue_free()
		await process_frame
	await create_timer(0.4).timeout
	if failures == 0:
		print("[ParcoursLayout] PASS: %d Prüfungen" % checks)
	else:
		print("[ParcoursLayout] FAIL: %d von %d Prüfungen" % [failures, checks])
	quit(1 if failures > 0 else 0)
