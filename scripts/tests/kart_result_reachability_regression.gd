extends SceneTree
## Every action of the finished-race dialog is reachable without scrolling on a
## landscape phone, the small QA emulator and both Fold displays. The dialog
## previously kept its fixed pause height, so "Zur Spieleauswahl" and
## "Zum Lernen" sat below the visible part of the scroll area.
const SCENE_TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const WINDOWS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(2400, 1080), Vector2i(800, 480), Vector2i(1812, 2176),
	Vector2i(904, 2316)
]
const ACTIONS: Array[String] = [
	"Noch einmal fahren", "Neue Fahrt auswählen", "Zur Spieleauswahl", "Zum Lernen"
]
var game
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, text: String) -> void:
	if not condition:
		failures += 1
		push_error("[KartResultReach] FAIL: " + text)


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	for window in WINDOWS:
		root.size = window
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
		for frame in range(4):
			await process_frame
		var clip: Rect2 = game.modal_scroll.get_global_rect()
		var screen: Rect2 = root.get_visible_rect()
		_check(screen.encloses(game.modal.get_global_rect()), "%s dialog stays on screen" % window)
		var found: Array[String] = []
		for child in game.modal_column.get_children():
			if child is Button and child.is_visible_in_tree():
				found.append(child.text)
				_check(
					clip.grow(0.5).encloses(child.get_global_rect()),
					"%s '%s' is inside the visible dialog area" % [window, child.text]
				)
				var density: float = child.custom_minimum_size.y / 48.0
				_check(
					child.size.y + 0.5 >= child.custom_minimum_size.y and density > 0.0,
					"%s '%s' keeps its touch height" % [window, child.text]
				)
		_check(found == ACTIONS, "%s offers %s, found %s" % [window, ACTIONS, found])
		var title: Label = game.modal_column.get_node("ResultTitle")
		var stats: Label = game.modal_column.get_node("ResultStats")
		_check(
			title.is_visible_in_tree() and clip.grow(0.5).encloses(title.get_global_rect()),
			"%s place title visible" % window
		)
		_check(
			stats.is_visible_in_tree() and clip.grow(0.5).encloses(stats.get_global_rect()),
			"%s result times visible" % window
		)
		print("[KartResultReach] %s dialog %s content %.0f" % [
			window, game.modal.get_global_rect().size, game.modal_column.size.y
		])
		game.abandoned = true
		if not (await SCENE_TEARDOWN.release_scene(self, game, "[KartResultReach]")):
			failures += 1
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	if failures > 0:
		print("[KartResultReach] FAIL: %d checks" % failures)
		quit(1)
		return
	print("[KartResultReach] PASS: all result actions reachable on %d display sizes" % WINDOWS.size())
	quit(0)
