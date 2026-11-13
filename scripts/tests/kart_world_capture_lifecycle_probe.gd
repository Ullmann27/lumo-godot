extends "res://scripts/tests/kart_world_expansion_capture.gd"
## Headless lifecycle diagnostic only. Produces no images or capture manifest.
## The production capture keeps its mandatory real-renderer check.

const WINTER_VISIBILITY = preload("res://scripts/tests/kart_winter_visibility_geometry.gd")
var visibility


func _prepare_output() -> String:
	if DisplayServer.get_name() != "headless":
		return "Use the real capture for renderer evidence; this is a headless lifecycle probe"
	var isolated := OS.get_environment("XDG_DATA_HOME")
	var user_path := ProjectSettings.globalize_path("user://")
	if isolated.is_empty() or not user_path.begins_with(isolated.trim_suffix("/") + "/"):
		return "Set an isolated XDG_DATA_HOME for the lifecycle probe"
	print("[KartWorldCaptureLifecycle] HEADLESS diagnostic; no pixels or image manifest")
	return ""


func _capture_views() -> bool:
	if selected == "winter_sprint":
		visibility = WINTER_VISIBILITY.new()
		visibility.prepare(game.world)
		for fraction in [0.0, 0.025, 0.05]:
			_place_player(game.world.length * fraction)
			game._update_camera(1.0, true)
			var problem: String = visibility.check_race_camera(game.camera, fraction)
			if not problem.is_empty():
				visibility = null
				await _finish(1, "[KartWinterVisibility] " + problem)
				return false
	if await super._capture_views():
		if visibility != null:
			print(
				(
					"[KartWinterVisibility] PASS checks=%d; geometry only, no pixels"
					% visibility.checks
				)
			)
			visibility = null
		await _finish(0)
	# Stop the inherited runner before its image-manifest writing stage.
	return false


func _capture(view_name: String, _camera_source: String) -> bool:
	await _frames(4)
	if visibility != null and view_name == "02_world_landmark":
		var problem: String = visibility.check_landmark(game.camera, game.world)
		if not problem.is_empty():
			visibility = null
			await _finish(1, "[KartWinterVisibility] " + problem)
			return false
	return true
