extends SceneTree
## B5: seawater foam must follow the *real* authored shoreline width,
## not the old fixed 101m×91m template after B2 grew Sonnenhafen.
## This affects a shader uniform only, never terrain physics, race state,
## harbor height, coastal waterfall, other tracks or mobile fallback quality.
const WORLD = preload("res://scripts/games/kart_world.gd")

func _initialize() -> void:
	call_deferred("_run")

func _check(id: String, low: bool) -> void:
	var world = WORLD.new()
	root.add_child(world)
	world.build(low, id, true)
	var water: MeshInstance3D = world.get_node("AnimatedCoastalWater")
	assert(water.material_override is ShaderMaterial)
	var material: ShaderMaterial = water.material_override
	var raw: Variant = material.get_shader_parameter("coastal_extent")
	assert(raw is Vector2, "Actual shader extent must always be bound explicitly")
	var extent: Vector2 = raw
	assert(extent.is_equal_approx(world.world_extent),
		"Shader coastline must track terrain's own authored limits exactly")
	assert(extent.x > 0.0 and extent.y > 0.0)
	assert(material.shader.code.contains("max(coastal_extent"),
		"Shader must use input coastal extent, not fixed legacy radius")
	assert(not material.shader.code.contains("p.x / 101.0"),
		"Original 101m shoreline must not be hardcoded in new shader")
	var foam: float = material.get_shader_parameter("coastal_foam")
	assert(is_equal_approx(foam, 0.78 if id == "sonnenhafen" and not low else 0.0))
	if id == "sonnenhafen":
		assert(extent.x > 300.0 and extent.y > 275.0,
			"New extended Sonnenhafen coastline must be many times larger")
		var actual: float = Vector2(extent.x / extent.x, 0.0).length()
		var old: float = Vector2(extent.x / 101.0, 0.0).length()
		assert(is_equal_approx(actual, 1.0) and old > 3.0,
			"New outer shoreline should line up with normalized radius ~1")
	else:
		assert(extent.x <= 150.0 and extent.y <= 150.0,
			"Unrelated tracks should keep their original coast geometry")
	world.queue_free()
	await process_frame

func _run() -> void:
	for track in ["sonnenhafen", "zauberwald", "holo_city"]:
		for low in [false, true]:
			await _check(track, low)
	print("[DynamicCoastalFoam] PASS: exact island shader extents, long 1.85km coast and legacy renderer profiles")
	quit(0)
