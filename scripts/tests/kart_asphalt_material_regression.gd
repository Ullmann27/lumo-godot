extends SceneTree
## End-to-end surface profile regression using the real assembled road mesh.
## This does not alter racing, physics or material assets.

const WORLD = preload("res://scripts/games/kart_world.gd")


func _initialize() -> void:
	call_deferred("_run")


func _check(track_id: String, low_detail: bool) -> void:
	var world = WORLD.new()
	root.add_child(world)
	world.build(low_detail, track_id, true)
	assert(world.road is MeshInstance3D, "Race world must create a real road mesh")
	var road: MeshInstance3D = world.road
	assert(road.material_override is ShaderMaterial)
	var material: ShaderMaterial = road.material_override
	assert(material.shader != null)
	if track_id == "candy_cloud":
		assert(material.shader.code.contains("shader_type spatial"), "Candy keeps its own shader")
		assert(not material.shader.code.contains("uniform float surface_grit"), "Do not replace the candy road")
	else:
		assert(material.shader.code.contains("surface_grit"))
		assert(material.shader.code.contains("pebble_lod"), "Detail must fade at distance")
		var raw: Variant = material.get_shader_parameter("surface_grit")
		assert(raw is float, "Every standard road must explicitly set surface grit")
		if raw is float:
			assert(is_equal_approx(raw, 0.0 if low_detail else 0.86))
	world.queue_free()


func _run() -> void:
	for track_id in ["sonnenhafen", "zauberwald", "holo_city", "candy_cloud"]:
		for low in [false, true]:
			_check(track_id, low)
			await process_frame
	print("[KartAsphalt] PASS: real road materials in four tracks, full/low LOD, candy shader preserved")
	quit(0)
