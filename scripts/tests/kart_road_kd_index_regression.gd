extends SceneTree
## B4: deterministic exact equivalence to the historical brute-force road
## lookup, across every primary world and the actual 1.851 km Sonnenhafen.
## Benchmark figures are diagnostic only: no fabricated 60-FPS claim.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const IDS: Array[String] = ["sonnenhafen", "zauberwald", "bergwelt", "holo_city"]

func _initialize() -> void:
	call_deferred("_run")

func _original_brute(world, p: Vector3) -> Vector2:
	var smallest: float = INF
	var index: int = 0
	for i in range(world._road_samples.size()):
		var delta := Vector2(
			world._road_samples[i].x - p.x,
			world._road_samples[i].z - p.z
		)
		var cost: float = delta.length_squared()
		if cost < smallest:
			smallest = cost
			index = i
	return Vector2(sqrt(smallest), float(index))

func _run() -> void:
	var total: int = 0
	var kd_micros: int = 0
	var brute_micros: int = 0
	for id in IDS:
		var world = WORLD.new()
		world.track_id = id
		world.definition = TRACKS.definition(id)
		world._make_curve()
		assert(world._road_kd_count == world._road_samples.size())
		assert(world._road_kd_nodes.size() == world._road_samples.size(),
			"KD-tree must index every original baked sample once")
		assert(world._road_kd_root >= 0)
		var probes: Array[Vector3] = []
		for n in range(320):
			var distance: float = float(n) * world.length / 320.0
			for lateral in [-120.0, -35.0, 0.0, 23.0, 95.0]:
				var centre: Vector3 = world.position_at(distance)
				var frame: Basis = world.frame(distance)
				probes.append(centre + frame.x * lateral
					+ Vector3.UP * float(n % 11))
		# Also cover sparse terrain outside shoreline and far from any road.
		for xi in range(-8, 9):
			for zi in range(-8, 9):
				probes.append(Vector3(float(xi) * 37.7,
					float(xi % 5) * 13.0, float(zi) * 35.8))
		var legacy: Array[Vector2] = []
		var start_brute: int = Time.get_ticks_usec()
		for p in probes:
			legacy.append(_original_brute(world, p))
		brute_micros += Time.get_ticks_usec() - start_brute
		var start_kd: int = Time.get_ticks_usec()
		for i in range(probes.size()):
			var actual: Vector2 = world._nearest_horizontal(probes[i])
			var expected: Vector2 = legacy[i]
			assert(int(actual.y) == int(expected.y),
				"Nearest baked-sample INDEX changed; terrain road clearance is not exact")
			assert(absf(actual.x - expected.x) < 0.0002,
				"Nearest baked-sample DISTANCE changed")
			total += 1
		kd_micros += Time.get_ticks_usec() - start_kd
		# Synthetic runtime fixtures that clear/replace samples must not read
		# stale KD nodes (legacy linear compatibility remains operational).
		world._road_samples.clear()
		world._road_samples.append(Vector3(10.0, 2.0, 10.0))
		world._road_samples.append(Vector3(20.0, 2.0, 20.0))
		var fallback: Vector2 = world._nearest_horizontal(Vector3(19.0, 3.0, 19.0))
		assert(int(fallback.y) == 1 and fallback.x < 1.5)
		world.free()
	assert(total >= 7000)
	print("[RoadKD] probes=%d, brute_us=%d, kd_us=%d" % [
		total, brute_micros, kd_micros
	])
	print("[RoadKD] PASS: exact old-world terrain distance and nearest-sample identity, all primary tracks")
	quit(0)
