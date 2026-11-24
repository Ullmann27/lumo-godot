extends SceneTree
## Every action of the finished-race panel is reachable without scrolling on a
## landscape phone, the small QA emulator and both Fold displays, both at one
## pixel per dp and at the densities those devices report. The dialog
## previously kept its fixed pause height, so "Zur Spieleauswahl" and
## "Zum Lernen" sat below the visible part of the scroll area.
## The panel is docked right in landscape and at the bottom otherwise, shows
## the place badge and the result lines without scrolling and never dims the race.
const SCENE_TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
## Window in pixels and the display density the host reports for it.
const WINDOWS: Array = [
	[Vector2i(1280, 720), 1.0], [Vector2i(2400, 1080), 1.0], [Vector2i(800, 480), 1.0],
	[Vector2i(1812, 2176), 1.0], [Vector2i(904, 2316), 1.0],
	[Vector2i(1600, 720), 2.0], [Vector2i(2400, 1080), 2.625], [Vector2i(1812, 2176), 2.625],
	[Vector2i(904, 2316), 2.625], [Vector2i(2316, 904), 2.625], [Vector2i(2176, 1812), 2.625]
]
## Primary and secondary first ("Noch einmal", "Zur Streckenwahl"), then the smaller second row.
const ACTIONS: Array[String] = [
	"Noch einmal", "Zur Streckenwahl", "Zur Spieleauswahl", "Zum Lernen"
]
var game
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, text: String) -> void:
	if not condition:
		failures += 1
		push_error("[KartResultReach] FAIL: " + text)


## "Ruhige Bewegung": nothing pops, fades, twinkles or keeps animating.
func _reduced_motion_case() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	game.preferred_reduced_motion = true
	game.reduced_motion = true
	game._start_selected_race(
		{"mode": "race", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "flott"}
	)
	game._end_preview()
	game.countdown = 0
	game.racing = true
	await process_frame
	_check(game.reduced_motion, "reduced motion stays set for the race")
	game.elapsed = 98.4
	game.checkpoint_index = 16
	game._finish(false)
	for frame in range(3):
		var badge: Control = game.modal_column.get_node("ResultTitle")
		_check(
			badge.reduced_motion and badge.appear == 1.0 and badge.modulate.a == 1.0 and not badge.is_processing(),
			"reduced motion: badge stands still (frame %d)" % frame
		)
		for row in game.modal_column.get_children():
			_check(row.modulate.a == 1.0, "reduced motion: '%s' is shown at once" % row.name)
		for row in game.modal_column.get_node("ResultStats").get_children():
			_check(row.modulate.a == 1.0, "reduced motion: row '%s' is shown at once" % row.label.text)
		await process_frame
	game.abandoned = true
	if not (await SCENE_TEARDOWN.release_scene(self, game, "[KartResultReach]")):
		failures += 1


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	# Saved Kart settings (e.g. "Ruhige Bewegung" left on by another run) must not
	# decide this test, and its own reduced-motion case must not outlive it.
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	var bridge: Node = root.get_node("HostBridge")
	for entry in WINDOWS:
		var window: Vector2i = entry[0]
		var density: float = entry[1]
		var label: String = "%s@%.3f" % [window, density]
		root.size = window
		bridge._options["displayDensity"] = density
		game = load("res://scenes/games/kart_island.tscn").instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		game.lightweight = true
		await process_frame
		game._start_selected_race(
			{"mode": "race", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "flott"}
		)
		game._end_preview()
		game.countdown = 0
		game.racing = true
		await process_frame
		game.elapsed = 98.4
		game.checkpoint_index = 16
		game._finish(false)
		# Without "Ruhige Bewegung" the badge pops in and the rows fade in.
		_check(
			game.modal_column.get_node("ResultTitle").appear < 1.0
			and game.modal_column.get_node("ResultStats").get_child(0).modulate.a < 1.0,
			"%s result entrance is animated by default" % label
		)
		for frame in range(4):
			await process_frame
		var clip: Rect2 = game.modal_scroll.get_global_rect()
		var screen: Rect2 = root.get_visible_rect()
		var dialog: Rect2 = game.modal.get_global_rect()
		var safe: Rect2 = game.safe_ui.get_global_rect()
		# Viewport units per dp, as the game derives them.
		var dp: float = maxf(
			screen.size.x / (float(window.x) / density), screen.size.y / (float(window.y) / density)
		)
		_check(screen.encloses(dialog), "%s dialog stays on screen" % label)
		_check(safe.grow(0.5).encloses(dialog), "%s dialog stays inside the safe area" % label)
		_check(not game.modal_backdrop.visible, "%s result does not dim the race" % label)
		_check(game.modal_scroll.get_v_scroll_bar().max_value <= clip.size.y + 1.0,
			"%s result content needs no scrolling" % label)
		if float(window.x) >= float(window.y) * 1.3:
			var share: float = dialog.size.x / safe.size.x
			_check(share >= 0.42 and share <= 0.48, "%s panel takes %.3f of the safe width" % [label, share])
			_check(dialog.position.x > safe.get_center().x, "%s panel is docked right" % label)
		else:
			_check(dialog.get_center().y > safe.get_center().y, "%s panel sits in the lower part" % label)
			_check(dialog.position.y - safe.position.y >= safe.size.y * 0.3,
				"%s kart area above the panel stays free" % label)
		var found: Array[String] = []
		var rects: Array[Rect2] = []
		for child in game.modal.find_children("*", "Button", true, false):
			if not child.is_visible_in_tree():
				continue
			found.append(child.text)
			var box: Rect2 = child.get_global_rect()
			_check(
				clip.grow(0.5).encloses(box) and screen.encloses(box),
				"%s '%s' is inside the visible dialog area" % [label, child.text]
			)
			_check(
				child.size.y + 0.5 >= child.custom_minimum_size.y and child.custom_minimum_size.y > 0.0,
				"%s '%s' keeps its touch height" % [label, child.text]
			)
			_check(
				box.size.y + 0.5 >= 48.0 * dp and box.size.x + 0.5 >= 48.0 * dp,
				"%s '%s' is at least 48 dp (%.1f x %.1f dp)" % [label, child.text, box.size.x / dp, box.size.y / dp]
			)
			var font: Font = child.get_theme_font("font")
			var text_width: float = font.get_string_size(
				child.text, HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")
			).x
			_check(
				text_width <= box.size.x - child.get_theme_stylebox("normal").get_minimum_size().x + 0.5,
				"%s '%s' shows its whole caption" % [label, child.text]
			)
			for other in rects:
				_check(not other.grow(-0.5).intersects(box), "%s '%s' overlaps another action" % [label, child.text])
			rects.append(box)
		_check(found == ACTIONS, "%s offers %s, found %s" % [label, ACTIONS, found])
		if found.size() >= 2 and rects.size() >= 2 and float(window.x) / density >= 600.0:
			_check(absf(rects[0].position.y - rects[1].position.y) < 1.0 and rects[0].end.x <= rects[1].position.x,
				"%s primary and secondary action sit side by side" % label)
		var title: Control = game.modal_column.get_node("ResultTitle")
		var stats: Control = game.modal_column.get_node("ResultStats")
		_check(
			title.is_visible_in_tree() and clip.grow(0.5).encloses(title.get_global_rect()),
			"%s place title visible" % label
		)
		_check(title.text == "1. PLATZ von 6", "%s badge names the place, shows '%s'" % [label, title.text])
		_check(
			stats.is_visible_in_tree() and clip.grow(0.5).encloses(stats.get_global_rect()),
			"%s result times visible" % label
		)
		_check(stats.text == game._result_stats_text(), "%s result lines equal the race values" % label)
		var rows: Array[String] = []
		for row in stats.get_children():
			rows.append(row.label.text)
			_check(row.is_visible_in_tree() and clip.grow(0.5).encloses(row.get_global_rect()),
				"%s row '%s' visible" % [label, row.label.text])
		_check(rows == ["Gesamtzeit", "Sterne gesammelt", "Belohnung"] or rows == ["Gesamtzeit", "Beste Runde", "Sterne gesammelt", "Belohnung"],
			"%s result rows %s" % [label, rows])
		var reward: Control = stats.get_child(stats.get_child_count() - 1)
		_check(
			reward.value.text == "+%d" % int(game.result_payload.stars)
			and reward.star_count == int(game.result_payload.stars),
			"%s reward row shows the earned stars" % label
		)
		print("[KartResultReach] %s dialog %s at %s content %.0f" % [
			label, dialog.size, dialog.position, game.modal_column.size.y
		])
		game.abandoned = true
		if not (await SCENE_TEARDOWN.release_scene(self, game, "[KartResultReach]")):
			failures += 1
	bridge._options.erase("displayDensity")
	await _reduced_motion_case()
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	if failures > 0:
		print("[KartResultReach] FAIL: %d checks" % failures)
		quit(1)
		return
	print("[KartResultReach] PASS: all result actions reachable on %d display sizes" % WINDOWS.size())
	quit(0)
