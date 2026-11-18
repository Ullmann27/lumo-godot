extends SceneTree
## Pictures of the village defence: the protected village and the defence plan.
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://scripts/tests/dorf_defense_capture.gd   (DORF_CAPTURE_DIR=<dir>)
const CHILD := "dorf-defense-capture"
const SLOT := 1


func _initialize() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _save(dir: String, name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir.path_join(name + ".png"))


func _run() -> void:
	var dir: String = OS.get_environment("DORF_CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://dorf_defense")
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(1600, 720)
	var world_script = load("res://scripts/creative/build_settlement_world.gd")
	DirAccess.remove_absolute(world_script.project_path(CHILD, SLOT, "village"))
	root.get_node("SceneRouter").launch_options = {"childKey": CHILD, "buildSlot": SLOT, "settlementMode": "settlement", "livingVillage": true}
	var village: Node = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	await _frames(12)
	village.tutorial.skip()
	var model = village.model
	model._player.resources = {"wood": 160, "stone": 160, "food": 50, "coins": 20}
	model._player.crops.carrots = 50
	model._player.population = 8
	model._player.campaign_chapter = 3
	for kind in ["farm", "quarry", "market", "farm", "house", "lumber"]:
		model.try_build(kind, village._next_free_plot())
	model.day = 12
	village.raids.parts = {"wall": 2, "tower": 2, "gate": 1, "ditch": 1, "trap": 3}
	village.raids.guards = 3
	village._rebuild()
	village.raids_view.sync()
	await _frames(30)
	await _save(dir, "dorf_schutz_uebersicht")
	village._defense_dialog()
	await _frames(12)
	await _save(dir, "dorf_schutz_plan")
	print("[DorfDefense] PASS")
	quit(0)
