extends SceneTree
## Actual-world regression for the shoreline shader and waterfall renderer contract.
## Geometry-only builds still author water, cliffs and all coastal set pieces.

const WORLD = preload("res://scripts/games/kart_world.gd")


func _foam_value(material: ShaderMaterial) -> float:
	var raw: Variant = material.get_shader_parameter("coastal_foam")
	# An unset shader uniform returns null on some renderers. This test requires
	# the runtime to set the exact value, not silently rely on a shader default.
	assert(raw is float, "Coastal foam must be explicitly initialized on every track")
	if not raw is float:
		return -1.0
	return raw


func _initialize() -> void:
	call_deferred("_run")


func _check_sonnenhafen(low_detail: bool) -> void:
	var world = WORLD.new()
	root.add_child(world)
	world.build(low_detail, "sonnenhafen", true)
	assert(world.has_node("AnimatedCoastalWater"), "Sea mesh must exist")
	var water: MeshInstance3D = world.get_node("AnimatedCoastalWater")
	assert(water.material_override is ShaderMaterial, "Coastal water must use a shader")
	var material: ShaderMaterial = water.material_override
	assert(material.shader != null and material.shader.code.contains("coastal_foam"))
	var foam: float = _foam_value(material)
	assert(is_equal_approx(foam, 0.0 if low_detail else 0.78), "Full/low water profile")
	assert(is_equal_approx(water.position.y, -2.35), "Harbor and ocean sea level")
	assert(world.has_node("LumoCoastalWaterfall"), "Waterfall is part of the actual world")
	var waterfall: MeshInstance3D = world.get_node("LumoCoastalWaterfall")
	assert(waterfall.mesh is QuadMesh, "Waterfall keeps original lightweight geometry")
	assert(waterfall.material_override is ShaderMaterial)
	var fall_shader: Shader = (waterfall.material_override as ShaderMaterial).shader
	assert(fall_shader != null and fall_shader.code.contains("filament_wave"))
	assert(not fall_shader.code.contains("smoothstep(1.0, 0.88"), "No undefined reversed edge")
	assert(world.has_meta("harbor_water_height"), "Harbor stays integrated")
	assert(is_equal_approx(float(world.get_meta("harbor_water_height")), -2.35))
	world.queue_free()


func _run() -> void:
	_check_sonnenhafen(false)
	await process_frame
	_check_sonnenhafen(true)
	await process_frame
	var forest = WORLD.new()
	root.add_child(forest)
	forest.build(true, "zauberwald", true)
	var sea: MeshInstance3D = forest.get_node("AnimatedCoastalWater")
	var mat: ShaderMaterial = sea.material_override
	assert(is_equal_approx(_foam_value(mat), 0.0))
	forest.queue_free()
	await process_frame
	print("[SonnenhafenWater] PASS: full/low foam, other-track isolation, real waterfall, shared sea height")
	quit(0)
