extends SceneTree
const WORLD = preload("res://scripts/games/kart_world.gd")
func _initialize() -> void:
	call_deferred("_run")
func _check(track: String, low: bool, cinema: bool) -> void:
	var w = WORLD.new()
	w.track_id = track
	w.low_detail = low
	root.add_child(w)
	w._prop("rock", Vector3(1,2,1), Vector3.ONE * 3.0, Color("b8b6a0"))
	w._prop("rock", Vector3(90,2,1), Vector3.ONE * 3.0, Color("94b4ce"))
	w._flush_instances()
	var found: int = 0
	var material: Material = null
	for child in w.get_children():
		if not child is MultiMeshInstance3D:
			continue
		assert(child.multimesh.use_colors)
		if cinema:
			assert(child.material_override is ShaderMaterial)
			assert(child.material_override.shader.code.contains("COLOR.rgb"))
			if material != null:
				assert(material == child.material_override)
			material = child.material_override
		else:
			assert(child.material_override is StandardMaterial3D)
			assert(child.material_override.vertex_color_use_as_albedo)
		found += 1
	assert(found == 2)
	w.queue_free()
func _run() -> void:
	_check("sonnenhafen", false, true)
	_check("sonnenhafen", true, false)
	_check("zauberwald", false, false)
	for i in range(6):
		await process_frame
	print("[KartCinemaRock] PASS: one shared shader, low mobile and non-harbor unchanged")
	quit(0)
