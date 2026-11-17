extends SceneTree
## Exercise time, phase and rebind behavior against the actual generated cave.
const WORLD = preload("res://scripts/games/kart_world.gd")
const DIRECTOR = preload("res://scripts/games/kart_darkride_event_director.gd")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr("[DarkrideLifecycle] FAIL: ", description)


func _run() -> void:
	var world: LumoRaceWorld = WORLD.new()
	root.add_child(world)
	world.build(true, "sonnenhafen", false)
	var director = DIRECTOR.new()
	director.bind_world(world)
	var cave: MeshInstance3D = world.get_node(
		"SonnenhafenBioluminescentDarkride/DarkrideRockAndCanopy"
	)
	var mat: ShaderMaterial = cave.material_override
	var distance: float = world.length
	director.tick(distance * 1.74, distance, 0.35, false)
	director.tick(distance * 1.82, distance, 2.5, false)
	_check(
		director.phase == DIRECTOR.Phase.OUTSIDE,
		"Expired surge must preserve OUTSIDE after leaving the cave"
	)
	director.bind_world(world)
	director.tick(distance * 1.74, distance, 0.35, false)
	director.tick(distance * 1.798, distance, 2.5, false)
	_check(
		director.phase == DIRECTOR.Phase.EXITING,
		"Expired surge must preserve EXITING at the portal"
	)
	var shader_source: String = mat.shader.code
	_check(
		not "TIME" in shader_source,
		"Reduced motion and pause cannot freeze an independent shader TIME clock"
	)
	var time_before: Variant = mat.get_shader_parameter("animation_time")
	director.tick(distance * 1.75, distance, 0.5, true)
	_check(
		mat.get_shader_parameter("animation_time") == time_before,
		"Reduced motion must hold the cave animation clock"
	)
	director.tick(distance * 1.75, distance, 0.0, false)
	_check(
		mat.get_shader_parameter("animation_time") == time_before,
		"Zero delta must not advance visual time"
	)
	director.tick(distance * 1.75, distance, 0.5, false)
	var time_after: Variant = mat.get_shader_parameter("animation_time")
	_check(
		time_before != null and time_after != null and time_before != time_after,
		"Normal driving must advance the controlled cave animation clock"
	)
	director.bind_world(null)
	_check(
		is_equal_approx(
			float(mat.get_shader_parameter("light_intensity")), DIRECTOR.BASE_SHADER_ENERGY
		),
		"Unbinding must restore the old cave material"
	)
	world.queue_free()
	await process_frame
	print("[DarkrideLifecycle] failures=", failures)
	quit(1 if failures else 0)
