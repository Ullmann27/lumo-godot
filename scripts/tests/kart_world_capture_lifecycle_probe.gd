extends "res://scripts/tests/kart_world_expansion_capture.gd"
## Headless lifecycle diagnostic only. Produces no images or capture manifest.
## The production capture keeps its mandatory real-renderer check.


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
	if await super._capture_views():
		await _finish(0)
	# Stop the inherited runner before its image-manifest writing stage.
	return false


func _capture(_name: String, _camera_source: String) -> bool:
	await _frames(4)
	return true
