extends SceneTree
## B3: actual Sonnenhafen World.build() with 5 large authored hero scenes.
## Preserve closed 1.85km race road, 8 checkpoints, collision clearance
## and fully independent low/high instancing tiers and other tracks.
const WORLD = preload("res://scripts/games/kart_world.gd")
const HERO = preload("res://scripts/games/kart_sonnenhafen_hero_coast.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var parts: Array[int] = []
	var first_locations: Array[Vector3] = []
	for low in [true, false]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(low, "sonnenhafen", true)
		assert(world.length > 1800.0 and world.length < 1900.0)
		assert(world.checkpoint_positions.size() == 8)
		assert(world.has_meta("sonnenhafen_hero_landmarks"),
			"Five hero landmarks were not integrated into actual World.build")
		var sites: Array = world.get_meta("sonnenhafen_hero_landmarks")
		assert(sites.size() == HERO.FRACTIONS.size(),
			"All five distinct kilometre-spaced hero scenes must be visible")
		var kind_seen: Dictionary = {}
		var at_positions: Array[Vector3] = []
		for site in sites:
			var position: Vector3 = site["position"]
			var fraction: float = site["fraction"]
			var radius: float = site["radius"]
			var count: int = site["parts"]
			assert(position.is_finite(), "No NaN scenery world coordinates")
			assert(radius >= 15.0 and count >= 16,
				"Every visible landmark needs a real, substantial 3D mesh")
			assert(not world._near_road(position, radius + HERO.CLEARANCE - 0.1),
				"Full hero mesh footprint must remain beyond the entire road")
			assert(not kind_seen.has(site["kind"]),
				"Landmarks must have unique art silhouettes, not repeat a template")
			kind_seen[site["kind"]] = true
			at_positions.append(position)
			for lateral in [-4.0, 0.0, 4.0]:
				var d: float = fraction * world.length
				var point: Vector3 = world.position_at(d, lateral)
				var contact: Dictionary = world.sample_road(point, d)
				assert(contact.on_road)
				assert(absf(float(contact.lateral) - lateral) < 0.12)
				assert(absf(float(contact.height) - point.y) < 0.08)
		var total: int = int(world.get_meta("sonnenhafen_hero_parts"))
		assert(total >= 100 and total <= 450,
			"GPU-batched landmark geometry must stay within the bounded art budget")
		parts.append(total)
		if low:
			first_locations = at_positions
		else:
			for i in range(at_positions.size()):
				assert(at_positions[i].distance_to(first_locations[i]) < 0.001,
					"Changing visual LOD must not change world placement")
		world.queue_free()
		await process_frame
	assert(parts[1] > parts[0] + 20,
		"Full hero LOD must have meaningful extra mesh details")

	for other in ["zauberwald", "holo_city"]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(true, other, true)
		assert(not world.has_meta("sonnenhafen_hero_landmarks"),
			"New original coastal geometry must not bleed into other worlds")
		world.queue_free()
		await process_frame
	print("[SonnenhafenHeroCoast] PASS: 5 unique 3D landmarks, actual low/high LOD, safe road and preserved checkpoints")
	quit(0)
