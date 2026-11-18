extends SceneTree
## Nahaufnahmen der Kulisse ohne Rennen (kein Gate): Leuchte und Baum je Strecke.
## LUMO_KART_REVIEW_DIR=/abs/dir godot --path . --rendering-method gl_compatibility \
##   --script res://scripts/tests/kart_scenery_showcase_capture.gd -- [strecke ...]
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const TREES: Array[String] = [
	"laubbaum", "laubbaum_b", "nadelbaum", "palme", "zauberbaum", "dschungelbaum", "winterbaum"
]


func _initialize() -> void:
	call_deferred("_run")


func _shot(path: String) -> void:
	for i in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("[KartShowcase] " + path)


func _find_tree(node: Node) -> Vector3:
	for child in node.get_children():
		if child is MultiMeshInstance3D and str(child.get_meta("scenery_species", "")) in TREES:
			if int(child.get_meta("scenery_lod", -1)) == 0 and child.multimesh.instance_count > 0:
				return child.position + child.multimesh.get_instance_transform(0).origin
	return Vector3.INF


func _run() -> void:
	var destination: String = OS.get_environment("LUMO_KART_REVIEW_DIR")
	root.size = Vector2i(1280, 720)
	var performance: Node = root.get_node_or_null("PerformanceManager")
	if performance != null:
		performance.call("set_profile", 2, false)
	var selected: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument in TRACKS.IDS:
			selected.append(argument)
	for track in selected:
		var world = WORLD.new()
		root.add_child(world)
		world.build(false, track)
		var camera := Camera3D.new()
		camera.fov = 60.0
		camera.far = 500.0
		root.add_child(camera)
		camera.make_current()
		var heads: PackedVector3Array = world.get_meta("scenery_lamp_heads", PackedVector3Array())
		if heads.size() > 3:
			var head: Vector3 = heads[3]
			var road: Dictionary = world.sample_road(head)
			var d: float = float(road.get("distance", 0.0))
			var eye: Vector3 = world.position_at(d - 9.0, 0.0) + Vector3.UP * 2.2
			camera.look_at_from_position(eye, head - Vector3.UP * 1.6)
			await _shot(destination.path_join("%s_lamp.png" % track))
		var tree: Vector3 = _find_tree(world.get_node("KartScenery"))
		if tree != Vector3.INF:
			var eye2: Vector3 = tree + Vector3(9.0, 3.5, 9.0)
			camera.look_at_from_position(eye2, tree + Vector3.UP * 4.0)
			await _shot(destination.path_join("%s_tree.png" % track))
		camera.queue_free()
		world.queue_free()
		await process_frame
	quit()
