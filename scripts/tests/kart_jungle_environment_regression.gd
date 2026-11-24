extends SceneTree
## Dschungelherz scenery is part of the track package: it builds on full and
## low detail, adds a forest, water, landmarks and living effects, and reacts
## to the race (advance / celebrate_finish) without touching road collision.
const WORLD = preload("res://scripts/games/kart_world.gd")
const COURSE = preload("res://scripts/games/kart_jungle_course.gd")
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for lightweight in [false, true]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(lightweight, COURSE.ID, false)
		await physics_frame
		var environment: Node3D = world.get_node_or_null("DschungelherzEnvironment")
		assert(environment != null, "Dschungelherz environment is part of the track package")
		var props: int = int(world.get_meta("jungle_environment_props", 0))
		assert(props >= (1500 if lightweight else 3000), "dense jungle on %s detail: %d props" % [
			"low" if lightweight else "full", props])
		assert(world.get_meta("jungle_road_collision_sections") == 12, "road collision unchanged")
		assert(environment.get_node_or_null("JungleFloor") != null, "jungle floor exists")
		# The course owns its daylight; the project's sunset default once
		# drowned the whole race in orange haze.
		var skies: Array[Node] = world.find_children("*", "WorldEnvironment", false, false)
		assert(skies.size() == 1, "Dschungelherz needs exactly one own WorldEnvironment")
		var daylight: Environment = (skies[0] as WorldEnvironment).environment
		assert(daylight.background_mode == Environment.BG_SKY and daylight.fog_density <= 0.002,
			"bright rainforest sky with thin haze")
		assert(world.find_children("*", "DirectionalLight3D", false, false).size() >= 1, "sun exists")
		assert(environment.get_node_or_null("Glühwürmchen") != null, "fireflies exist")
		var player: Vector3 = world.position_at(10.0 * COURSE.SECTION_LENGTH + 50.0)
		for frame in 10:
			environment.advance(1.0 / 60.0, player, true, false)
		assert(environment.get_node("Tropenregen").emitting, "rain falls in the Regenkessel")
		environment.advance(1.0 / 60.0, player, true, true)
		assert(not environment.get_node("Tropenregen").emitting, "reduced motion stops rain")
		environment.celebrate_finish()
		assert(environment.get_node("Blütenregen").emitting, "finish celebration starts")
		checks += 1
		world.queue_free()
		await process_frame
	print("[JungleEnvironment] PASS: %d checks" % checks)
	quit(0)
