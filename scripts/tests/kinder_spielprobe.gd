extends SceneTree
## Kinderprobe: ein Spiel so öffnen, wie ein Kind es bekommt – über den echten
## Einstieg `boot.tscn` mit `--scene=<id>` –, die Ladezeit messen, dann mit
## echten Eingaben (Tippen auf die Bildschirmmitte von Knöpfen, Ziehen,
## gehaltene Tasten) eine Weile spielen und Bilder als JPG aufnehmen.
## Zusätzlich: Größe aller sichtbaren Knöpfe in echten Bildpunkten (48 dp am
## Fold ≈ 126 px) und ob Knöpfe außerhalb des Bildes liegen.
##
##   xvfb-run -a -s '-screen 0 2560x2560x24' godot --path . --rendering-method gl_compatibility \
##     --audio-driver Dummy --script res://scripts/tests/kinder_spielprobe.gd -- \
##     --scene=puzzle --size=1080x2340 --shots=<ordner> --tag=vorher
##
## Spiele ohne eigenen Boot-Eintrag (Sternenjagd) werden über die Spielewelt
## geöffnet: Boot → Spielewelt → echter Tipp auf die Kachel.
## Die Probe ist keine Abnahme: sie bricht nur ab, wenn das Spiel gar nicht
## öffnet. Alles andere steht im Protokoll ([Kinderprobe] …).

const MIN_TOUCH_PX: float = 126.0
const HUB_TILES: Array[String] = ["stars"]
## Ziele, die `app_boot.gd` direkt öffnet. Alles andere (z. B. die Lese-Welt)
## erreicht die Probe nur per Direktsprung des SceneRouters – im eingebetteten
## APK-Betrieb führt „Lernen" stattdessen zurück in die App.
const BOOT_TARGETS: Array[String] = [
	"kart",
	"jump",
	"run",
	"puzzle",
	"build",
	"settlement",
	"rhythm",
	"treasure",
	"learning",
	"cards",
	"connect_four",
	"memory",
	"chess",
	"quiz",
	"home",
	"games"
]

var options: Dictionary = {}
var shots_dir: String = ""
var tag: String = "probe"
var scene_id: String = ""
var shot_index: int = 0
var notes: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[pair[0]] = pair[1]
	scene_id = str(options.get("scene", "games"))
	tag = str(options.get("tag", "probe"))
	shots_dir = str(options.get("shots", ""))
	if not shots_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(shots_dir)
	var size_text: String = str(options.get("size", "1080x2340"))
	var parts: PackedStringArray = size_text.split("x")
	if DisplayServer.get_name() != "headless" and parts.size() == 2:
		root.size = Vector2i(int(parts[0]), int(parts[1]))
	# Das Handy meldet seine Bildschirmdichte über den Host (Fold7 ≈ 2,625);
	# ohne sie zeichnen die Spiele ihre Bedienung für Dichte 1 (zu klein).
	var bridge: Node = root.get_node("HostBridge")
	var host_options: Dictionary = bridge.get("_options")
	host_options["displayDensity"] = float(options.get("density", "2.625"))
	bridge.set("_options", host_options)
	var router: Node = root.get_node("SceneRouter")
	var wanted_id: String = scene_id
	var boot_id: String = scene_id
	var via_hub: bool = scene_id in HUB_TILES or str(options.get("via", "")) == "hub"
	if via_hub or scene_id not in BOOT_TARGETS:
		boot_id = "games"
	# Die Boot-Szene liest ihre Optionen aus den Kommandozeilen-Argumenten;
	# für Kacheln der Spielewelt startet sie in der Spielewelt.
	if boot_id != scene_id:
		options["scene"] = boot_id
	print(
		(
			"[Kinderprobe] scene=%s window=%s renderer=%s"
			% [scene_id, str(root.size), RenderingServer.get_current_rendering_method()]
		)
	)
	var started: int = Time.get_ticks_msec()
	change_scene_to_file("res://scenes/app/boot.tscn")
	var game: Node = await _wait_for_scene(router, boot_id, 90000)
	if game == null:
		print(
			(
				"[Kinderprobe] FAIL: %s nicht geöffnet nach %d ms"
				% [boot_id, Time.get_ticks_msec() - started]
			)
		)
		quit(1)
		return
	print(
		(
			"[Kinderprobe] ladezeit %s: %d ms (Container, Software-Renderer)"
			% [boot_id, Time.get_ticks_msec() - started]
		)
	)
	if boot_id != wanted_id and not via_hub:
		print("[Kinderprobe] Direktsprung %s (kein Boot-Ziel)" % wanted_id)
		router.goto(wanted_id)
		game = await _wait_for_scene(router, wanted_id, 90000)
		if game == null:
			print("[Kinderprobe] FAIL: %s öffnet nicht" % wanted_id)
			quit(1)
			return
	elif boot_id != wanted_id:
		await _seconds(1.5)
		await _shot("hub")
		var tile: Control = _find_route_tile(game, wanted_id)
		if tile == null:
			print("[Kinderprobe] FAIL: Kachel %s nicht gefunden" % wanted_id)
			quit(1)
			return
		var tile_started: int = Time.get_ticks_msec()
		await _tap(_screen_center(tile))
		game = await _wait_for_scene(router, wanted_id, 90000)
		if game == null:
			print("[Kinderprobe] FAIL: Kachel %s öffnet nichts" % wanted_id)
			quit(1)
			return
		print(
			(
				"[Kinderprobe] ladezeit kachel->%s: %d ms"
				% [wanted_id, Time.get_ticks_msec() - tile_started]
			)
		)
	await _seconds(float(options.get("settle", "2.0")))
	await _shot("start")
	_audit_buttons(game, "start")
	await _play(game)
	_audit_buttons(current_scene, "ende")
	for note in notes:
		print("[Kinderprobe] notiz: " + note)
	print(
		(
			"[Kinderprobe] ENDE %s: %d Bilder, Szene jetzt %s"
			% [scene_id, shot_index, str(router.get("current_scene_id"))]
		)
	)
	var sound: Node = root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	await _seconds(0.4)
	quit(0)


func _wait_for_scene(router: Node, wanted: String, timeout_ms: int) -> Node:
	var path: String = str(router.SCENES.get(wanted, ""))
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var scene: Node = current_scene
		if scene != null and scene.scene_file_path == path:
			return scene
	return null


func _seconds(value: float) -> void:
	var until: int = Time.get_ticks_msec() + int(value * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	if shots_dir.is_empty():
		return
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		notes.append("Bild %s leer" % label)
		return
	shot_index += 1
	var path: String = shots_dir.path_join(
		(
			"%s_%s_%dx%d_%02d_%s.jpg"
			% [tag, scene_id, image.get_width(), image.get_height(), shot_index, label]
		)
	)
	image.save_jpg(path, 0.86)
	print("[Kinderprobe] bild " + path)


## Echte Bildpunkte eines Steuerelements (Stretch der Projektbasis eingerechnet).
func _screen_rect(control: Control) -> Rect2:
	var xform: Transform2D = root.get_final_transform() * control.get_global_transform_with_canvas()
	return xform * Rect2(Vector2.ZERO, control.size)


func _screen_center(control: Control) -> Vector2:
	return _screen_rect(control).get_center()


func _tap(screen_pos: Vector2, hold: float = 0.08) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = screen_pos
	down.pressed = true
	Input.parse_input_event(down)
	await _seconds(hold)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = screen_pos
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _drag(from: Vector2, to: Vector2, seconds: float) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = from
	down.pressed = true
	Input.parse_input_event(down)
	var steps: int = maxi(4, int(seconds * 30.0))
	var last: Vector2 = from
	for step in range(1, steps + 1):
		var point: Vector2 = from.lerp(to, float(step) / float(steps))
		var move := InputEventScreenDrag.new()
		move.index = 0
		move.position = point
		move.relative = point - last
		move.velocity = (point - last) * 30.0
		Input.parse_input_event(move)
		last = point
		await _seconds(seconds / float(steps))
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = to
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _visible_buttons(scene: Node) -> Array[BaseButton]:
	var found: Array[BaseButton] = []
	if scene == null:
		return found
	var window_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	for node in scene.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if not button.is_visible_in_tree() or button.disabled:
			continue
		var rect: Rect2 = _screen_rect(button)
		if not rect.has_area() or not window_rect.intersects(rect):
			continue
		found.append(button)
	found.sort_custom(
		func(a: BaseButton, b: BaseButton) -> bool:
			var ra: Rect2 = _screen_rect(a)
			var rb: Rect2 = _screen_rect(b)
			if absf(ra.position.y - rb.position.y) > 12.0:
				return ra.position.y < rb.position.y
			return ra.position.x < rb.position.x
	)
	return found


func _button_label(button: BaseButton) -> String:
	var text: String = ""
	if button is Button:
		text = (button as Button).text.replace("\n", " ")
	if text.strip_edges().is_empty():
		text = str(button.name)
	if button.tooltip_text != "" and text == str(button.name):
		text += " (" + button.tooltip_text + ")"
	return text.substr(0, 40)


func _audit_buttons(scene: Node, label: String) -> void:
	var buttons: Array[BaseButton] = _visible_buttons(scene)
	var small: Array[String] = []
	var outside: Array[String] = []
	var window_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	for button in buttons:
		var rect: Rect2 = _screen_rect(button)
		if minf(rect.size.x, rect.size.y) < MIN_TOUCH_PX:
			small.append("%s %dx%d" % [_button_label(button), int(rect.size.x), int(rect.size.y)])
		if not window_rect.encloses(rect.grow(-2.0)):
			outside.append(_button_label(button))
	print(
		(
			"[Kinderprobe] knöpfe %s: %d sichtbar, %d unter 48 dp, %d angeschnitten"
			% [label, buttons.size(), small.size(), outside.size()]
		)
	)
	for entry in small.slice(0, 14):
		print("[Kinderprobe]   klein: " + entry)
	for entry in outside.slice(0, 8):
		print("[Kinderprobe]   angeschnitten: " + entry)


func _find_route_tile(scene: Node, destination: String) -> Control:
	for node in scene.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		if control.has_meta("destination") and str(control.get_meta("destination")) == destination:
			return control
		if control is BaseButton and str(control.name).to_lower().contains(destination):
			return control
	return null


func _find_button(scene: Node, words: Array) -> BaseButton:
	for button in _visible_buttons(scene):
		var label: String = _button_label(button).to_lower()
		for word in words:
			if label.contains(str(word).to_lower()):
				return button
	return null


func _is_exit(button: BaseButton) -> bool:
	var label: String = _button_label(button).to_lower()
	for word in [
		"‹",
		"zurück",
		"zuruck",
		"spielewelt",
		"spieleauswahl",
		"beenden",
		"verlassen",
		"home",
		"back",
		"zur ",
		"eltern",
		"×",
		"schließen"
	]:
		if label.contains(word):
			return true
	for word in str(options.get("avoid", "")).split(",", false):
		if label.contains(word.to_lower()) or str(button.name).to_lower().contains(word.to_lower()):
			return true
	return false


## Wie ein Kind: auf alles tippen, was nach Knopf aussieht (ohne „Zurück“),
## dazwischen schauen, was passiert.
func _poke_buttons(rounds: int, pause: float, shots_every: int) -> void:
	var tapped: Dictionary = {}
	for i in range(rounds):
		var scene: Node = current_scene
		var candidates: Array[BaseButton] = []
		for button in _visible_buttons(scene):
			if not _is_exit(button) and not tapped.has(_button_label(button)):
				candidates.append(button)
		if candidates.is_empty():
			break
		var button: BaseButton = candidates[0]
		# Wunschknöpfe zuerst (z. B. „Los“), sonst von oben nach unten.
		for word in str(options.get("first", "")).split(",", false):
			for candidate in candidates:
				if _button_label(candidate).to_lower().contains(word.to_lower()):
					button = candidate
					break
			if button != candidates[0]:
				break
		tapped[_button_label(button)] = true
		print("[Kinderprobe] tippe: " + _button_label(button))
		await _tap(_screen_center(button))
		await _seconds(pause)
		if shots_every > 0 and (i + 1) % shots_every == 0:
			await _shot("tipp%d" % (i + 1))


func _hold_action(action: String, seconds: float) -> void:
	if not InputMap.has_action(action):
		return
	Input.action_press(action)
	await _seconds(seconds)
	Input.action_release(action)


func _find_by_script(scene: Node, script_file: String) -> Control:
	if scene == null:
		return null
	for node in scene.find_children("*", "Control", true, false):
		var script: Script = node.get_script() as Script
		if (
			script != null
			and script.resource_path.ends_with(script_file)
			and node.is_visible_in_tree()
		):
			return node as Control
	return null


## Finger auf den Stick, in eine Richtung schieben, halten, loslassen.
func _stick_hold(stick: Control, direction: Vector2, seconds: float, jump: Control) -> void:
	var rect: Rect2 = _screen_rect(stick)
	var center: Vector2 = rect.get_center()
	var reach: Vector2 = direction.normalized() * minf(rect.size.x, rect.size.y) * 0.42
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = center
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(2)
	var move := InputEventScreenDrag.new()
	move.index = 0
	move.position = center + reach
	move.relative = reach
	Input.parse_input_event(move)
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	var jumped: bool = false
	while Time.get_ticks_msec() < until:
		await process_frame
		if jump != null and not jumped and Time.get_ticks_msec() > until - int(seconds * 500.0):
			jumped = true
			var press := InputEventScreenTouch.new()
			press.index = 1
			press.position = _screen_center(jump)
			press.pressed = true
			Input.parse_input_event(press)
			await _seconds(0.25)
			var release := InputEventScreenTouch.new()
			release.index = 1
			release.position = press.position
			release.pressed = false
			Input.parse_input_event(release)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = center + reach
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


## Leuchtende 3D-Ziele (Area3D mit Tipp-Erkennung) antippen.
func _tap_pickables(limit: int) -> int:
	var scene: Node = current_scene
	var camera: Camera3D = root.get_camera_3d()
	if scene == null or camera == null:
		return 0
	var tapped: int = 0
	var window_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	for node in scene.find_children("*", "Area3D", true, false):
		if tapped >= limit or not is_instance_valid(node) or current_scene != scene:
			break
		var area := node as Area3D
		if (
			not is_instance_valid(area)
			or not area.input_ray_pickable
			or not area.is_visible_in_tree()
		):
			continue
		if camera.is_position_behind(area.global_position):
			continue
		var point: Vector2 = camera.unproject_position(area.global_position)
		var screen: Vector2 = root.get_final_transform() * point
		if not window_rect.has_point(screen):
			continue
		print(
			"[Kinderprobe] tippe 3D: %s bei %s" % [str(area.get_parent().name), str(screen.round())]
		)
		await _tap(screen)
		await _seconds(0.7)
		tapped += 1
	return tapped


func _play(game: Node) -> void:
	var mode: String = str(options.get("play", "auto"))
	if mode == "none":
		return
	await _poke_buttons(int(options.get("taps", "5")), float(options.get("pause", "1.2")), 2)
	await _seconds(1.0)
	await _shot("getippt")
	var scene: Node = current_scene
	var stick: Control = _find_by_script(scene, "kart_joystick.gd")
	if stick != null and str(options.get("stick", "1")) != "0":
		var jump: Control = _find_by_script(scene, "jump_touch_button.gd")
		for direction in [Vector2.UP, Vector2(1, -0.4), Vector2.UP, Vector2(-1, -0.3), Vector2.UP]:
			await _stick_hold(stick, direction, 1.6, jump)
		await _shot("gelaufen")
	match str(options.get("hook", "")):
		"puzzle":
			await _hook_puzzle(current_scene)
		"rhythm":
			await _hook_rhythm(current_scene)
		"world":
			await _hook_world_taps()
	var picked: int = await _tap_pickables(int(options.get("picks", "6")))
	if picked > 0:
		await _seconds(1.5)
		await _shot("angetippt")
	if game != null and not is_instance_valid(game):
		notes.append("Spielszene wurde während des Spielens verlassen")


## Puzzle: drei Teile mit dem Finger auf ihren Platz ziehen (ein Kind, das
## die Stelle gefunden hat), dazwischen einmal daneben.
func _hook_puzzle(game: Node) -> void:
	if game == null or not ("model" in game) or game.get("paused"):
		notes.append("Puzzle nicht gestartet – kein Ziehen möglich")
		return
	var camera: Camera3D = game.get("camera")
	var moved: int = 0
	for id in range(game.model.pieces.size()):
		if moved >= 3:
			break
		if game.model.pieces[id].locked:
			continue
		var piece: Node3D = game.nodes[id]
		var target: Vector2 = game.model.target(id)
		var from: Vector2 = camera.unproject_position(piece.global_position)
		var to: Vector2 = camera.unproject_position(Vector3(target.x, 0.35, target.y))
		var xform: Transform2D = root.get_final_transform()
		if moved == 1:
			await _drag(xform * from, xform * (from.lerp(to, 0.5)), 0.6)
			await _seconds(0.6)
			await _shot("puzzle_daneben")
			from = camera.unproject_position(piece.global_position)
		await _drag(xform * from, xform * to, 0.8)
		await _seconds(0.5)
		moved += 1
	await _seconds(0.6)
	await _shot("puzzle_gelegt")
	print("[Kinderprobe] puzzle: %d Teile gezogen, fertig=%s" % [moved, str(game.model.complete())])


## Rhythmus: auf die Spur tippen, wenn eine Note an der Linie ist (mit
## kindlicher Ungenauigkeit durch die Bildrate des Containers).
func _hook_rhythm(game: Node) -> void:
	if game == null or not ("model" in game) or not game.get("running"):
		notes.append("Rhythmus-Lied läuft nicht")
		return
	var lanes: Array = game.get("lane_buttons")
	var until: int = Time.get_ticks_msec() + int(float(options.get("song", "14")) * 1000.0)
	var shot_at: int = Time.get_ticks_msec() + 6000
	var taps: int = 0
	while Time.get_ticks_msec() < until and is_instance_valid(game) and game.get("running"):
		await process_frame
		for note in game.model.notes:
			if int(note.state) != 0 or absf(float(note.time) - game.model.time) > 0.1:
				continue
			var button: Control = lanes[int(note.lane)]
			var at: Vector2 = _screen_center(button)
			var down := InputEventScreenTouch.new()
			down.index = 2
			down.position = at
			down.pressed = true
			Input.parse_input_event(down)
			await _seconds(maxf(0.08, float(note.length)))
			var up := InputEventScreenTouch.new()
			up.index = 2
			up.position = at
			up.pressed = false
			Input.parse_input_event(up)
			taps += 1
			break
		if Time.get_ticks_msec() > shot_at:
			shot_at = until + 1
			await _shot("rhythmus")
	print(
		(
			"[Kinderprobe] rhythmus: %d Tipps, Treffer %d, daneben %d"
			% [taps, int(game.model.hits), int(game.model.misses)]
		)
	)


## Bauwelt/Dorf: in die Welt tippen (Bauen/Auswählen) an mehreren Stellen.
func _hook_world_taps() -> void:
	var size := Vector2(root.size)
	for point in [Vector2(0.5, 0.55), Vector2(0.42, 0.6), Vector2(0.58, 0.5), Vector2(0.5, 0.45)]:
		await _tap(size * point)
		await _seconds(0.8)
	await _shot("welt_getippt")
