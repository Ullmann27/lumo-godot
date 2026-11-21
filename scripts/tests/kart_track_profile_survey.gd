extends SceneTree
## Messwerkzeug (kein Regressionstest): Streckenprofil je Strecke, zwei Runden
## Mittellinien-Fahrt durch die echte Rennphysik (Eigentempo der Stufe „flott“).
## Aufruf: godot --headless --path . --script res://scripts/tests/kart_track_profile_survey.gd
##         -- [out.json] [track_id ...]
const PROFILE = preload("res://scripts/tests/helpers/kart_track_profile.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tracks_script: Script = load("res://scripts/games/kart_tracks.gd")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = ""
	var ids: Array = []
	for arg in args:
		if str(arg).ends_with(".json"):
			out = str(arg)
		else:
			ids.append(str(arg))
	if ids.is_empty():
		ids = tracks_script.IDS.duplicate()
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	var report: Dictionary = {}
	for track in ids:
		game.race_seed = 20261118
		game._start_selected_race(
			{
				"mode": "race",
				"driver": "fox",
				"kart": "comet",
				"track": track,
				"difficulty": "flott"
			}
		)
		await process_frame
		game.countdown = 0
		game.racing = true
		var shape: Dictionary = PROFILE.geometry(game.world)
		var ride: Dictionary = await PROFILE.drive(self, game)
		shape.merge(ride)
		report[track] = shape
		print(
			(
				(
					"[Profile] %-19s L=%5.0f h=%4.1f..%4.1f climb=%4.0f crests=%d corners=%d S=%d"
					+ " straights=%d air=%.1fs/%d quiet=%.1fs@%.0f hlgap=%.1fs@%.0f hl=%d"
					+ " dec=%d cv=%.2f lap2=%.1f resets=%d"
				)
				% [
					track,
					shape.length,
					shape.height_min,
					shape.height_max,
					shape.climb,
					shape.crests.size(),
					shape.corners.size(),
					shape.direction_changes,
					shape.straights.size(),
					shape.air_s,
					shape.takeoffs,
					shape.longest_quiet_s,
					shape.longest_quiet_at,
					shape.highlight_gap_s,
					shape.highlight_gap_at,
					shape.highlights,
					shape.decisions,
					shape.speed_cv,
					shape.lap2_time,
					shape.resets
				]
			)
		)
	if not out.is_empty():
		var file := FileAccess.open(out, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	game.abandoned = true
	await TEARDOWN.release_scene(self, game, "[Profile]")
	quit(0)
