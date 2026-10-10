extends RefCounted
## Developer-only provenance. Excluded from every runtime export preset.


static func source() -> Dictionary:
	var repository := ProjectSettings.globalize_path("res://")
	var head: Array = []
	var differences: Array = []
	var head_result := OS.execute("git", ["-C", repository, "rev-parse", "HEAD"], head)
	var diff_result := OS.execute("git", [
		"-C", repository, "diff", "--name-only", "HEAD", "--",
	], differences)
	var dirty := "".join(differences).strip_edges()
	var sha := "".join(head).strip_edges()
	return {
		"source_commit": sha if head_result == OK and sha.length() == 40 else null,
		"tracked_differences": dirty,
		"clean_tracked_source": head_result == OK and diff_result == OK and dirty.is_empty(),
		"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"physical_android_device": false,
		"visual_acceptance": "Manual reference review required; render success is not art approval",
	}
