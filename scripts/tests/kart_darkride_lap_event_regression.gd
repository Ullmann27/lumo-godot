extends SceneTree
## Actual scene-graph test for lap-aware tunnel visuals (without physics mutation).
const WORLD = preload("res://scripts/games/kart_world.gd")
const DIRECTOR = preload("res://scripts/games/kart_darkride_event_director.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: LumoRaceWorld = WORLD.new()
	root.add_child(world)
	world.build(true, "sonnenhafen", false)
	var director = DIRECTOR.new()
	director.bind_world(world)
	var ride: Node3D = world.get_node("SonnenhafenBioluminescentDarkride")
	var surface: MeshInstance3D = ride.get_node("DarkrideIlluminatedRoad")
	var material: ShaderMaterial = surface.material_override
	var checkpoints: PackedVector3Array = world.checkpoint_positions.duplicate()
	var race_length: float = world.length
	assert(director.phase == DIRECTOR.Phase.OUTSIDE)
	assert(is_equal_approx(float(material.get_shader_parameter("light_intensity")),
		DIRECTOR.BASE_SHADER_ENERGY))
	director.tick(race_length * 0.72, race_length, 0.1, false)
	assert(director.phase == DIRECTOR.Phase.CRUISING)
	director.tick(race_length * 1.73, race_length, 0.1, false)
	assert(director.phase == DIRECTOR.Phase.WARNING, "Lap 2 needs a pre-event warning")
	director.tick(race_length * 1.74, race_length, 0.35, false)
	assert(director.phase == DIRECTOR.Phase.SURGE)
\tvar vfx: Node3D = world.get_node(
		"SonnenhafenBioluminescentDarkride/LumoArcadeCrystalShockwave")
	assert(vfx != null and vfx.visible, "Arcade shockwave was not activated")
	assert(vfx.get_child_count() == 2, "Low detail shockwave must use only two rings")
	assert(int(vfx.burst_count) == 1, "A single lap crossing must produce one burst")
	var full_intensity: float = float(material.get_shader_parameter("light_intensity"))
	assert(full_intensity > DIRECTOR.BASE_SHADER_ENERGY + 0.25,
		"Second-lap tunnel energy surge not visible")
	for i in range(35):
		director.tick(race_length * 1.75, race_length, 0.1, false)
	assert(director._triggered_lap == 1, "Visual event must occur once per lap only")
	assert(director._active_surge_seconds < 0.0, "Visual surge never settled")
	assert(not vfx.visible and int(vfx.burst_count) == 1, "VFX must expire, without retriggering")
	assert(world.length == race_length and world.checkpoint_positions == checkpoints,
		"Neon-only event must not change road physics or checkpoint positions")
	assert(world.get_node("SonnenhafenBioluminescentDarkride").get_child_count() == 5)
	director.bind_world(null)
	await process_frame
	var calm_director = DIRECTOR.new()
	calm_director.bind_world(world)
	calm_director.tick(race_length * 1.74, race_length, 0.35, true)
	var low_motion_intensity: float = float(material.get_shader_parameter("light_intensity"))
	assert(low_motion_intensity < full_intensity,
		"Reduced motion must reduce the visual event amplitude")
	calm_director.bind_world(null)
	calm_director.tick(race_length * 1.74, race_length, 0.1, false)
	print("[DarkrideEvent] PASS: lap-two neon + cartoon burst, reduced motion, no physics changes")
	quit(0)
