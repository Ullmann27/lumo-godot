extends SceneTree
## Godot 4.6.3 real desktop-rendered Bauwelt world with ORIGINAL approved
## PREMIUM.build meshes, not a standalone asset gallery or concept montage.
## Only this isolated QA fixture is new; pinned gameplay sources are unchanged.
const SOURCE_GODOT := "3453a43a8bbdcb0495718e1eced2a40837d6e3ab"
const IDS := ["cottage", "windmill", "fountain", "swing", "fox_statue"]
const POS := [
	Vector3i(-12, 0, -12), Vector3i(-6, 0, -12),
	Vector3i(-12, 0, -5), Vector3i(-6, 0, -5),
	Vector3i(-12, 0, 2)
]
var output: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Real rendered frames required")
	output = OS.get_environment("LUMO_BAUWELT_QA_DIR")
	if output.is_empty():
		output = "res://exports/qa-bauwelt-1971"
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280, 720)

	var game = load("res://scenes/creative/build_world.tscn").instantiate()
	root.add_child(game)
	for _i in range(3):
		await process_frame
	# This QA-only save slot never points to a real child's user:// key.
	game.save_path = "user://lumo_qa_bauwelt_premium_1971.json"
	game.model.clear()
	game.goal = "garden"
	game.focus = Vector3(-5.5, 1.5, -4.7)
	game.radius = 29.0
	game._rebuild()
	game._camera_update()
	await _capture("01_original_bauwelt_empty")

	for i in range(IDS.size()):
		var fail_reason: String = game.model.place(IDS[i], POS[i], i % 4)
		assert(fail_reason.is_empty(), "Premium prop " + IDS[i] + ": " + fail_reason)
	game._rebuild()
	game._camera_update()
	await _capture("02_premium_props_placed")

	# Real persistence path uses FileAccess.tmp + flush + rename; explicitly
	# verify disk bytes and reload into the existing live world.
	assert(game.save_world(false), "Save must return confirmed success")
	var saved: String = FileAccess.get_file_as_string(game.save_path)
	assert(saved.length() > 100 and saved.contains("fox_statue"),
		"Premium world must genuinely survive serialized storage")
	game.model.clear()
	assert(game.load_world(false), "Stored game must restore")
	assert(game.model.pieces.size() == IDS.size())
	for id in IDS:
		var found: bool = false
		for item in game.model.pieces:
			if str(item.part) == id:
				found = true
		assert(found, "Premium prop did not survive reload: " + id)
	game._rebuild()
	game._camera_update()
	await _capture("03_premium_props_reloaded")

	var evidence := {
		"provenance": SOURCE_GODOT, "engine": Engine.get_version_info().string,
		"platform": "Godot Desktop software GL compatibility, NOT Android",
		"visuals": ["empty", "premium 5 placed", "saved and restored"],
		"ids": IDS, "saved_count": game.model.pieces.size(),
		"size": "1280x720",
		"note": "Existing production scene with five approved 3D objects, no mocked child data"
	}
	var report := FileAccess.open(output.path_join("evidence.json"), FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify(evidence, "\t"))
	report.flush()
	assert(report.get_error() == OK)
	report.close()

	game.queue_free()
	for _i in range(3):
		await process_frame
	print("[Bauwelt1971] PASS: 5 real premium objects placed and restored, three unaltered 1280x720 GL frames")
	quit(0)


func _capture(label: String) -> void:
	for _i in range(16):
		await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	assert(picture != null and picture.get_size() == Vector2i(1280, 720),
		"No real screenshot for " + label)
	assert(picture.save_png(output.path_join(label + ".png")) == OK,
		"Cannot save screenshot " + label)
