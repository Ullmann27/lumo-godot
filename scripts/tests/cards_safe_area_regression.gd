extends SceneTree
## Der Kartentisch mit Systemrändern (Statusleiste, Kamera-Aussparung,
## Gestenleiste): alles Bedienbare bleibt im sicheren Bereich und reagiert auf
## echte Berührungen. Die Ränder sind eine erklärte Vorgabe, keine Gerätemessung.

const TABLE := "res://scenes/games/cards_table.tscn"
const FIXTURE := "res://scripts/tests/fixtures/cards_safe_area_table.gd"
const DRIVER = preload("res://scripts/tests/helpers/cards_table_driver.gd")
const SESSION = preload("res://scripts/games/cards/cards_session.gd")
const SAFE_AREA = preload("res://scripts/app/android_safe_area.gd")
const SCENE_TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const CHILD := "cards-safe-area"
## Name, Fenster, Dichte, Ränder (links, oben, rechts, unten in Bildpunkten).
const PROFILES := [
	["android35_portrait", Vector2i(1080, 2400), 2.625, Rect2(0, 136, 0, 63)],
	["android35_portrait_earlier_inset", Vector2i(1080, 2400), 2.625, Rect2(0, 145, 0, 63)],
	["landscape_cutout_fixture", Vector2i(2400, 1080), 2.625, Rect2(136, 63, 0, 63)],
	["short_landscape_fixture", Vector2i(640, 360), 1.0, Rect2(0, 32, 0, 24)],
	["desktop_without_insets", Vector2i(1280, 720), 1.0, Rect2()],
	["phone_portrait_720", Vector2i(720, 1280), 1.75, Rect2(0, 58, 0, 42)],
	["phone_landscape_720", Vector2i(1280, 720), 1.75, Rect2(84, 0, 0, 36)],
	["fold_portrait", Vector2i(1768, 2208), 2.4, Rect2(0, 84, 0, 58)],
	["fold_landscape", Vector2i(2208, 1768), 2.4, Rect2(0, 84, 0, 58)],
]
const CAPTURES := {"android35_portrait": ["playing", "paused"], "landscape_cutout_fixture": ["playing"]}

var table: Node
var density := 1.0
var safe_pixels := Rect2()
var profile_name := ""
var checks := 0
var failures: Array[String] = []
var targets: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var images: Array[Dictionary] = []
var capture := false
var output := "res://exports/cards-safe-area"
var layout_sequence := 0


func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not OS.get_environment("LUMO_CAPTURE_DIR").is_empty():
		output = OS.get_environment("LUMO_CAPTURE_DIR")
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(profile_name + ": " + label)
		push_error("[CardsSafeArea] " + profile_name + ": " + label)


func _rect(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	return Rect2(transform * Vector2.ZERO, control.size)


func _array(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _target(control: Control, label: String) -> void:
	var pixels := _rect(control)
	var dp := pixels.size / density
	_check(minf(dp.x, dp.y) >= 47.99, "%s is a %s dp touch target" % [label, dp])
	_check(safe_pixels.grow(0.51).encloses(pixels), "%s stays clear of the system edges: %s in %s" % [label, pixels, safe_pixels])
	targets.append({"profile": profile_name, "label": label, "rect_px": _array(pixels), "dp": [dp.x, dp.y],
		"safe_rect_px": _array(safe_pixels)})


func _all_targets(stage: String) -> void:
	var seen := 0
	for button: Button in table.hud.visible_buttons():
		if button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			# Namensschilder sind nur Ziel, wenn gefragt werden darf; sichtbar im sicheren Bereich bleiben sie immer.
			_check(safe_pixels.grow(0.51).encloses(_rect(button)), "%s %s stays inside the safe area" % [stage, button.name])
			continue
		seen += 1
		_target(button, stage + " " + button.name)
	_check(seen > 0, stage + " offers touch targets")


func _tap(id: String, label: String, edge: bool = false) -> void:
	var button: Button = table.hud.find_button(id)
	_check(button != null and not button.disabled, label + " is available")
	if button == null:
		return
	_target(button, label)
	var point := _rect(button).get_center()
	if edge:
		# 22 dp neben der Mitte: auch der Rand des Knopfs muss reagieren.
		point.y += 22.0 * density
	inputs.append({"profile": profile_name, "label": label, "screen_touch_px": [point.x, point.y], "edge_22_dp": edge})
	await DRIVER.touch(self, point)
	await DRIVER.settle(self, 3)


func _quad_rect(quad: Array) -> Rect2:
	var box := Rect2(Vector2(quad[0][0], quad[0][1]), Vector2.ZERO)
	for corner: Array in quad:
		box = box.expand(Vector2(corner[0], corner[1]))
	return box


func _hand_checks(stage: String) -> Array:
	var hand: Array = []
	var controls: Array[Rect2] = []
	for control: Control in [table.hud.hint_panel, table.hud.me_plate, table.hud.action_button, table.hud.top_bar]:
		if control.is_visible_in_tree():
			controls.append(_rect(control))
	for card: int in table.hand_cards():
		var quad: Array = table.card_quad(card)
		var box := _quad_rect(quad)
		hand.append({"id": str(card), "quad": quad})
		_check(safe_pixels.grow(1.0).encloses(box), "%s hand card %d stays inside the safe area: %s" % [stage, card, box])
		if not table._selected.has(card):
			for control: Rect2 in controls:
				_check(not box.intersects(control), "%s hand card %d does not cover a control" % [stage, card])
		var point: Vector2 = DRIVER.hand_point(table, card)
		_check(table._hand_card_at(point) == card, "%s hand card %d is hit at its visible corner" % [stage, card])
	_check(hand.size() >= 1, stage + " shows the hand")
	return hand


func _capture(name: String, hand: Array) -> void:
	if not capture:
		return
	root.disable_3d = false
	await DRIVER.settle(self, 5)
	await RenderingServer.frame_post_draw
	var rendered := root.get_texture().get_image()
	_check(not rendered.is_empty() and rendered.get_size() == root.size, "capture is the full-size viewport")
	var path := output.path_join(name + ".png")
	_check(rendered.save_png(path) == OK, "viewport PNG was saved")
	var focus := {}
	for card: int in table.cards:
		if table.cards[card].zone == "trump":
			focus = {"id": str(card), "quad": table.card_quad(card)}
	layout_sequence += 1
	var layout := {
		"schema": 2, "layout_sequence": layout_sequence, "settled": table.is_idle(), "ui_visible": table.hud.is_visible_in_tree(),
		"observation_source": "fixture", "pending": 0, "paused": table._paused, "game": table.game,
		"density": density, "window_px": [root.size.x, root.size.y], "safe_rect_px": _array(safe_pixels),
		"hand": hand, "table": focus,
	}
	var file := FileAccess.open(output.path_join(name + ".layout.json"), FileAccess.WRITE)
	_check(file != null, "layout sidecar opens")
	if file != null:
		file.store_string(JSON.stringify(layout))
		file.close()
	images.append({"path": path, "profile": profile_name, "size": [root.size.x, root.size.y], "safe_rect_px": _array(safe_pixels)})
	root.disable_3d = true


func _exercise() -> void:
	_check(table.inset_reads > 0, "the layout reads the platform safe-area boundary")
	# Auswahl.
	_all_targets("selection")
	_check(safe_pixels.grow(0.51).encloses(_rect(table.hud.safe)), "the whole interface is inset")
	await _tap("Tile_stich", "Sternenstich tile", true)
	_check(table.hud.overlay_kind == "setup", "a real touch on the tile opens the settings")
	_all_targets("setup")
	_check(safe_pixels.grow(0.51).encloses(_rect(table.hud.overlay.get_node("Panel"))), "the settings panel is inside the safe area")
	await _tap("Pick_rounds_1", "one round")
	await _tap("Pick_players_4", "three fellow players")
	await _tap("Pick_difficulty_0", "easy")
	await _tap("start", "start", true)
	_check(await DRIVER.idle(self, table, 60.0), "the deal settles")
	_check(table.screen == "play" and table.rules != null, "the match runs")
	# Spiel: warten, bis das Kind dran ist.
	var guard := 0
	while not table._can_act() and guard < 20:
		guard += 1
		await DRIVER.idle(self, table, 60.0)
		await DRIVER.settle(self, 2)
	_check(table._can_act(), "the child gets a turn")
	_all_targets("play")
	for plate: Button in table.hud.plates:
		_check(safe_pixels.grow(0.51).encloses(_rect(plate)), "name plate %s is inside the safe area" % plate.name)
	_check(safe_pixels.grow(0.51).encloses(_rect(table.hud.top_bar)), "the header clears the status bar")
	var hand := _hand_checks("play")
	if profile_name in CAPTURES:
		await _capture(profile_name + "-playing", hand)
	# Erste Berührung hebt die Karte, der Knopf „Legen“ erscheint im sicheren Bereich.
	var legal: int = table._legal_cards.keys()[0]
	var point: Vector2 = DRIVER.hand_point(table, legal)
	inputs.append({"profile": profile_name, "label": "hand card", "screen_touch_px": [point.x, point.y], "edge_22_dp": false})
	await DRIVER.touch(self, point)
	await DRIVER.idle(self, table, 10.0)
	_check(table._selected == [legal], "a real touch lifts the playable card")
	_check(safe_pixels.grow(1.0).encloses(_quad_rect(table.card_quad(legal))), "the lifted card stays inside the safe area")
	var moves: int = int(table.rules.s.moves)
	await _tap("Action", "Legen", true)
	await DRIVER.idle(self, table, 60.0)
	_check(int(table.rules.s.moves) > moves, "Legen plays the lifted card")
	# Pause.
	guard = 0
	while not table._can_act() and table.rules.phase() == "playing" and guard < 20:
		guard += 1
		await DRIVER.idle(self, table, 60.0)
	var before: Dictionary = table.rules.snapshot()
	await _tap("Pause", "pause", true)
	_check(table.hud.overlay_kind == "pause" and table._paused, "a real touch opens the pause menu")
	_all_targets("pause")
	_check(safe_pixels.grow(0.51).encloses(_rect(table.hud.overlay.get_node("Panel"))), "the pause panel is inside the safe area")
	if profile_name in CAPTURES and "paused" in CAPTURES[profile_name]:
		await _capture(profile_name + "-paused", _hand_checks("paused"))
	await _tap("rules", "rules")
	_all_targets("rules")
	_check(safe_pixels.grow(0.51).encloses(_rect(table.hud.overlay.get_node("Panel"))), "the rules panel is inside the safe area")
	await _tap("rules_done", "back from rules")
	await _tap("continue", "continue", true)
	_check(table.hud.overlay_kind.is_empty() and not table._paused and table.rules.snapshot() == before, "the pause changes nothing in the match")
	# Zu Ende spielen: Rundenwertung und Endstand im sicheren Bereich.
	guard = 0
	while table.screen == "play" and guard < 400:
		guard += 1
		if not await DRIVER.idle(self, table, 60.0):
			break
		if not table.hud.overlay_kind.is_empty():
			break
		if table._can_act():
			if not await DRIVER.play(self, table, DRIVER.suggestion(table)):
				_check(false, "a touch move fails while finishing the round")
				break
	await DRIVER.idle(self, table, 60.0)
	_check(table.hud.overlay_kind == "final", "the one-round match ends with the standings")
	_all_targets("final")
	_check(safe_pixels.grow(0.51).encloses(_rect(table.hud.overlay.get_node("Panel"))), "the standings are inside the safe area")
	await _tap("menu", "another game")
	_check(table.screen == "select", "the selection returns")
	# Einführung: Sprechblase im sicheren Bereich.
	await _tap("Tile_quartett", "Lumo-Quartett tile")
	await DRIVER.idle(self, table, 60.0)
	_check(is_instance_valid(table.hud.bubble), "the first visit shows Lumo's speech bubble")
	if is_instance_valid(table.hud.bubble):
		_check(safe_pixels.grow(0.51).encloses(_rect(table.hud.bubble)), "the speech bubble is inside the safe area")
		_all_targets("introduction")
		await _tap("intro_skip", "skip the introduction")
	_check(table.hud.overlay_kind == "setup", "skipping leads to the settings")
	await _tap("back", "back to the selection")
	await _tap("leave", "Zurück", true)
	_check(table.return_calls == 1, "a real touch on Zurück reaches the return to the app")


func _run() -> void:
	if capture and DisplayServer.get_name() == "headless":
		push_error("Cards safe-area capture requires an actual renderer")
		quit(2)
		return
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(output)
	_check(Input.emulate_mouse_from_touch, "touch events reach the buttons")
	# Unabhängige Geometriefälle der Android-Umrechnung (unverändert gültig).
	var decor := Vector2(1080, 2400)
	var bars := Rect2(0, 136, 0, 63)
	_check(SAFE_AREA.insets_inside_view(decor, Rect2(Vector2.ZERO, decor), bars) == bars, "edge-to-edge view keeps both system insets")
	_check(SAFE_AREA.insets_inside_view(decor, Rect2(0, 136, 1080, 2201), bars) == Rect2(), "a padded view is not inset twice")
	_check(SAFE_AREA.insets_inside_view(decor, Rect2(0, 63, 1080, 2337), bars) == Rect2(0, 73, 0, 63), "a partly padded view gets the remaining overlap")
	_check(SAFE_AREA.insets_inside_view(Vector2(2400, 1080), Rect2(80, 20, 2320, 1060), Rect2(136, 63, 0, 63)) == Rect2(56, 43, 0, 63),
		"landscape cutout and view offset stay separate edges")
	var bridge := root.get_node("HostBridge")
	var original: Dictionary = bridge._options.duplicate(true)
	var save_path := SESSION.path_for(CHILD)
	root.disable_3d = capture
	for profile: Array in PROFILES:
		profile_name = profile[0]
		root.size = profile[1]
		density = profile[2]
		var insets: Rect2 = profile[3]
		safe_pixels = Rect2(insets.position, Vector2(root.size) - insets.position - insets.size)
		bridge._options = {"displayDensity": density, "childKey": CHILD, "soundEnabled": false}
		DirAccess.remove_absolute(save_path)
		await DRIVER.settle(self, 3)
		table = load(TABLE).instantiate()
		table.set_script(load(FIXTURE))
		table.display_insets = insets
		root.add_child(table)
		table.time_scale = 60.0
		await DRIVER.settle(self, 6)
		# Solange Android noch keine Ränder gemeldet hat, bleibt die Oberfläche verborgen.
		table._android_safe_area_enabled = true
		table._resize()
		_check(not table.hud.visible, "no control is shown before the system edges are known")
		table.observation = {"view_size": Vector2(root.size), "decor_size": Vector2(root.size),
			"render_rect": Rect2(Vector2.ZERO, Vector2(root.size)), "system_insets": insets, "insets": insets, "window_size": root.size}
		table._resize()
		_check(table.hud.visible, "the interface appears with the measured edges")
		table.session.mark_intro_seen("stich")
		await DRIVER.settle(self, 4)
		await _exercise()
		_check(await SCENE_TEARDOWN.release_scene(self, table, "[CardsSafeArea] " + profile_name), "the scene is released")
		table = null
		await DRIVER.settle(self, 3)
	root.disable_3d = false
	bridge._options = original
	DirAccess.remove_absolute(save_path)
	var report := FileAccess.open(output.path_join("cards-safe-area.json"), FileAccess.WRITE)
	_check(report != null, "evidence report opens")
	if report != null:
		report.store_string(JSON.stringify({"checks": checks, "failures": failures, "renderer": DisplayServer.get_name(),
			"android_device_measurement": false,
			"fixture_scope": "declared insets: API35 log-observed portrait bars, synthetic cutout, phone, fold and desktop cases",
			"profiles": PROFILES.size(), "targets": targets, "input_events": inputs, "images": images}, "  "))
		report.close()
	print("CARDS_SAFE_AREA_%s checks=%d failures=%d profiles=%d images=%d" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size(), PROFILES.size(), images.size()])
	quit(0 if failures.is_empty() else 1)
