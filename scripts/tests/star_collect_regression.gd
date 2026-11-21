extends SceneTree
## Sternenjagd wie ein Kind: echte Tipps (Bildschirmberührung) auf die
## sichtbaren Sterne, drei Wellen, Sternschnuppe, Ergebnis mit Bestzeit,
## „Zur Spielewelt“. Prüft Hoch- und Querformat bei Handy-Dichte 2,625:
## jeder Stern liegt im Bild unterhalb der Kopfleiste, Knöpfe ≥ 48 dp.
##
##   godot --headless --path . --script res://scripts/tests/star_collect_regression.gd

const SCENE := "res://scenes/games/star_collect.tscn"
const MIN_TOUCH_PX: float = 126.0

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("[StarCollectRegression] FAIL " + message)


func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _seconds(value: float) -> void:
	var until: int = Time.get_ticks_msec() + int(value * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _screen(point: Vector2) -> Vector2:
	return root.get_final_transform() * point


func _tap(view_point: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = _screen(view_point)
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await _frames(1)


func _button_px(button: Control) -> Vector2:
	var xform: Transform2D = root.get_final_transform() * button.get_global_transform_with_canvas()
	return (xform * Rect2(Vector2.ZERO, button.size)).size


func _run() -> void:
	var bridge: Node = root.get_node("HostBridge")
	var host_options: Dictionary = bridge.get("_options")
	host_options["displayDensity"] = 2.625
	bridge.set("_options", host_options)
	var router: Node = root.get_node("SceneRouter")
	router.launch_options = {"childKey": "sternenjagd-regression"}
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lumo_sternenjagd.cfg"))
	root.size = Vector2i(1080, 2340)
	var game: Node = load(SCENE).instantiate()
	root.add_child(game)
	await _frames(8)
	var lumo: Node = game.get_node("LumoCharacter")
	_check(lumo.has_method("has_original_lumo") and lumo.has_original_lumo(), "echter Lumo")
	_check(
		game.wave == 0 and game.stars.size() == 5, "Welle 1 mit 5 Sternen (%d)" % game.stars.size()
	)
	_check_visible(game, "Hochformat")
	_check(game.hint.visible, "Tipp-Hinweis über dem ersten Stern sichtbar")
	for button in [game.back_button]:
		var px: Vector2 = _button_px(button)
		_check(minf(px.x, px.y) >= MIN_TOUCH_PX, "Zurück-Knopf ≥ 48 dp (%s)" % str(px))
	_check(game.back_button.text.contains("Spielewelt"), "Zurück-Knopf nennt die Spielewelt")
	# Daneben tippen fängt nichts.
	var corner := Vector2(8, game.get_viewport().get_visible_rect().size.y - 8)
	await _tap(corner)
	_check(game.caught_total == 0, "Tipp ins Leere fängt keinen Stern")
	# Erste Welle durch echte Berührungen.
	var sounds: Array[String] = []
	root.get_node("AudioManager").sfx_played.connect(
		func(sound: String) -> void: sounds.append(sound)
	)
	var caught_signal: Array[int] = []
	game.star_caught.connect(func(total: int) -> void: caught_signal.append(total))
	await _catch_all(game)
	_check(game.caught_total == 5, "5 Sterne per Tipp gefangen (%d)" % game.caught_total)
	_check(caught_signal.size() == 5, "Signal je Stern")
	_check(sounds.count("star_collected") == 5, "Fangton je Stern (%s)" % str(sounds))
	_check(not game.hint.visible, "Hinweis verschwindet nach dem ersten Fang")
	_check(game.find_children("StarBurst", "CPUParticles3D", true, false).size() > 0, "Funkenregen")
	await _seconds(2.0)
	_check(game.wave == 1 and game.stars.size() == 7, "Welle 2 mit 7 Sternen")
	_check(game.counter_label.text == "0 / 7", "Zähler neu (%s)" % game.counter_label.text)
	var first: Node3D = game.stars[0]
	var before: Vector3 = first.position
	await _seconds(0.6)
	_check(first.position.distance_to(before) > 0.05, "Sterne tanzen in Welle 2")
	# Querformat: neue Welle liegt ebenfalls im Bild.
	root.size = Vector2i(2176, 1812)
	await _frames(4)
	await _catch_all(game)
	await _seconds(2.0)
	_check(game.wave == 2 and game.stars.size() == 9, "Welle 3 mit 9 Sternen")
	_check_visible(game, "Querformat")
	var landscape_px: Vector2 = _button_px(game.back_button)
	_check(minf(landscape_px.x, landscape_px.y) >= MIN_TOUCH_PX, "Knopf quer ≥ 48 dp")
	await _seconds(2.6)
	_check(is_instance_valid(game.shooting_star), "Sternschnuppe fliegt in Welle 3")
	if is_instance_valid(game.shooting_star):
		await _seconds(0.8)
		var cam: Camera3D = game.camera
		await _tap(cam.unproject_position(game.shooting_star.global_position))
		_check(game.bonus_caught, "Sternschnuppe per Tipp gefangen")
	await _catch_all(game)
	await _frames(4)
	_check(game.caught_total == 21, "alle 21 Sterne (%d)" % game.caught_total)
	_check(game.result_panel.visible, "Ergebnis erscheint")
	var texts: Array[String] = []
	for node in game.result_box.get_children():
		if node is Label:
			texts.append(node.text)
	var joined := " | ".join(texts)
	_check(joined.contains("21 Sterne in"), "Ergebnis nennt echte Zahl (%s)" % joined)
	_check(joined.contains("Neue Bestzeit"), "erste Runde ist Bestzeit")
	_check(joined.contains("Sternschnuppe"), "Bonus im Ergebnis")
	var saved := ConfigFile.new()
	_check(saved.load("user://lumo_sternenjagd.cfg") == OK, "Bestzeit gespeichert")
	var again: Button = game.result_box.find_child("AgainButton", true, false)
	var back: Button = game.result_box.find_child("ResultBackButton", true, false)
	_check(again != null and back != null, "Nochmal und Zur Spielewelt")
	if again != null:
		var px: Vector2 = _button_px(again)
		_check(minf(px.x, px.y) >= MIN_TOUCH_PX, "Nochmal ≥ 48 dp (%s)" % str(px))
		await _tap(again.get_global_rect().get_center())
		await _frames(3)
		_check(game.wave == 0 and game.caught_total == 0, "Nochmal startet neu")
		_check(not game.result_panel.visible, "Ergebnis geschlossen")
	var scene_events: Array[String] = []
	root.get_node("EventBus").scene_changed.connect(
		func(_from: String, to: String) -> void: scene_events.append(to)
	)
	await _tap(game.back_button.get_global_rect().get_center())
	await _frames(2)
	_check(scene_events.has("games"), "Zurück führt in die Spielewelt (%s)" % str(scene_events))
	game.queue_free()
	await _frames(3)
	if current_scene != null:
		current_scene.queue_free()
	await _frames(3)
	root.get_node("GameSoundscape").release_audio()
	for voice in root.get_node("AudioManager").get("_pool"):
		voice.stop()
		voice.stream = null
	await _seconds(0.4)
	if failures.is_empty():
		print("[StarCollectRegression] PASS: %d checks" % checks)
	else:
		print("[StarCollectRegression] FAIL: %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _check_visible(game: Node, label: String) -> void:
	var view: Vector2 = game.get_viewport().get_visible_rect().size
	var cam: Camera3D = game.camera
	var top_bar: float = game.safe.get_global_rect().position.y + game.counter_pill.size.y
	var inside: int = 0
	for star in game.stars:
		var at: Vector2 = cam.unproject_position(star.global_position)
		if Rect2(Vector2.ZERO, view).has_point(at) and at.y > top_bar:
			inside += 1
	_check(
		inside == game.stars.size(),
		"%s: alle Sterne im Bild (%d/%d)" % [label, inside, game.stars.size()]
	)


func _catch_all(game: Node) -> void:
	var guard: int = 0
	while not game.stars.is_empty() and guard < 30:
		guard += 1
		var star: Node3D = game.stars[0]
		await _tap(game.camera.unproject_position(star.global_position))
		await _frames(2)
