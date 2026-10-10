extends SceneTree
## Isolated renderer/visual-layer smoke, preserving the 1920 driving core.
const WORLD = preload("res://scripts/games/kart_world.gd")
const GLASS = preload("res://scripts/games/visual/kart_premium_glass.gd")
const ENV = preload("res://scripts/games/visual/kart_environment_polish.gd")
const GATES = preload("res://scripts/games/visual/kart_neon_gates.gd")
const TAIL = preload("res://scripts/games/visual/kart_tail_spring_adapter.gd")


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var glass: ColorRect = GLASS.create_overlay(Vector2(320, 98), true)
	assert(glass.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(glass.material is ShaderMaterial)
	assert((glass.material as ShaderMaterial).shader != null)
	var full_glass: ColorRect = GLASS.create_overlay(Vector2(320, 98), false)
	assert((full_glass.material as ShaderMaterial).shader != null)
	var environment := Environment.new()
	var status: Dictionary = ENV.configure(environment, false)
	assert(float(environment.glow_hdr_threshold) > 1.0)
	assert(status.has("renderer"))
	var tail = TAIL.new()
	var pivot := Node3D.new()
	tail.bind_tail(pivot)
	tail.set_steering(0.8)
	assert(tail.joint == pivot)
	tail.reduced_motion = true
	# World is constructed without changing gameplay/saves. Visual-only arch test.
	var world = WORLD.new()
	root.add_child(world)
	world.build(true, "sonnenhafen", true)
	assert(GATES.decorate(world) == 0, "Low graphics profile must not add arches")
	world.build(false, "sonnenhafen", true)
	var count: int = GATES.decorate(world)
	assert(count > 0 and count <= 3)
	assert(world.has_meta("aaa_arch_count"))
	var draw: MultiMeshInstance3D = world.get_node_or_null("LumoNextGenNeonGates")
	assert(is_instance_valid(draw))
	assert(draw.multimesh.instance_count == count * GATES.SEGMENTS)
	for marker in world.get_children():
		if marker is Path3D and marker.name == "LumoNeonArcPath":
			assert(marker.get_child_count() == 1)
			assert(marker.get_child(0) is PathFollow3D)
			assert(marker.get_child(0).get_child(0) is MeshInstance3D)
	world.queue_free()
	await process_frame
	print("[AAA_VISUAL] PASS: real glass shader, fallback, environment, original-world neon arches, no collisions")
	quit(0)
