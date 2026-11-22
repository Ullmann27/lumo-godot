extends SceneTree
## Rebuild the three selection portraits from the equipped Parcours worlds.
## xvfb-run -a godot --rendering-method gl_compatibility --script res://scripts/tests/parcours_world_card_capture.gd -- --out=/tmp/parcours

const WORLDS = preload("res://scripts/games/parcours/parcours_worlds.gd")
const BUILDER = preload("res://scripts/games/parcours/parcours_builder.gd")
const PEN = preload("res://scripts/games/parcours/parcours_pen.gd")
const VIEWS := {
	"wolkenwerkstatt": ["bruecke", Vector3(11, 9, -16), Vector3(0, 1, 14)],
	"eisturm": ["eisbruecke", Vector3(-16, 12, -21), Vector3(0, 1, 10)],
	"dschungeltempel": ["lianenhalle", Vector3(9, 8, -16), Vector3(0, 2, 15)],
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dest := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			dest = arg.trim_prefix("--out=")
	if dest.is_empty() or DisplayServer.get_name() == "headless" or DirAccess.make_dir_recursive_absolute(dest) != OK:
		printerr("A real renderer and --out=<directory> are required.")
		quit(1)
		return
	root.size = Vector2i(1024, 680)
	root.content_scale_size = root.size
	root.msaa_3d = Viewport.MSAA_4X
	for id in WORLDS.playable_ids():
		var course = WORLDS.build(id)
		var builder := BUILDER.new()
		root.add_child(builder)
		builder.build(course, false, true)
		var view: Array = VIEWS[id]
		var site: Dictionary = course.checkpoints[course.checkpoint_index_of(view[0])]
		var forward: Vector3 = PEN.forward_of(site.heading)
		var across: Vector3 = PEN.right_of(site.heading)
		var frame := Basis(across, Vector3.UP, forward)
		var camera := Camera3D.new()
		builder.add_child(camera)
		camera.fov = 55
		camera.look_at_from_position(site.pos + frame * view[1], site.pos + frame * view[2])
		camera.make_current()
		for i in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		var frame_image := root.get_texture().get_image()
		frame_image.resize(768, 510, Image.INTERPOLATE_LANCZOS)
		if frame_image.save_webp(dest.path_join(id + ".webp"), true, 0.91) != OK:
			quit(1)
			return
		builder.free()
		await process_frame
	print("[ParcoursWorldCards] Three production worlds captured.")
	quit(0)
