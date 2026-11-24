extends SceneTree
## Measures the joins between road and loop on every track that has a loop:
## gap (height above the asphalt), Versatz (sideways/forward misalignment),
## kink (tangent angle), banking mismatch, deck width, continuous rows and
## that the climbing and the descending track never cross each other.
## Uses the real track build and the actual deck mesh vertices.
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS: Array[String] = ["sonnenhafen", "candy_cloud", "volcano_night", "galaxy_ringway"]
## Allowed tolerances (metres / degrees).
const GAP_TOLERANCE: float = 0.003
const OFFSET_TOLERANCE: float = 0.005
const KINK_LIMIT_DEG: float = 2.5
const BANK_LIMIT_DEG: float = 0.5
const WIDTH_TOLERANCE: float = 0.01
const ROW_STEP_LIMIT: float = 0.8
const CROSSING_CLEARANCE: float = 0.05
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("[LoopSeam] FAIL: ", message)


func _angle_deg(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(a.normalized().angle_to(b.normalized()))


func _deck_vertices(world) -> PackedVector3Array:
	for name in ["StuntLoopDeck", "LoopDeck"]:
		var node: MeshInstance3D = world.get_node_or_null(name)
		if node != null:
			return node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	return PackedVector3Array()


func _nearest(vertices: PackedVector3Array, at: Vector3) -> float:
	var best: float = INF
	for vertex in vertices:
		best = minf(best, vertex.distance_squared_to(at))
	return sqrt(best)


## Gap and Versatz of one road-joined row against the road surface.
func _join(world, row: Dictionary, d: float, lane: float, half: float, label: String) -> Dictionary:
	var basis: Basis = world.frame(d)
	var worst_gap: float = 0.0
	var worst_offset: float = 0.0
	for side in [-1.0, 1.0]:
		var vertex: Vector3 = row.left if side < 0.0 else row.right
		var road: Vector3 = world.position_at(d, lane + side * half)
		var delta: Vector3 = vertex - road
		var gap: float = delta.dot(basis.y) - LOOP.DECK_LIFT
		var offset: float = (delta - basis.y * delta.dot(basis.y)).length()
		worst_gap = maxf(worst_gap, absf(gap))
		worst_offset = maxf(worst_offset, offset)
	var bank: float = _angle_deg(row.right - row.left, basis.x)
	var width: float = row.left.distance_to(row.right)
	_check(worst_gap <= GAP_TOLERANCE, "%s gap %.4f m" % [label, worst_gap])
	_check(worst_offset <= OFFSET_TOLERANCE, "%s Versatz %.4f m" % [label, worst_offset])
	_check(bank <= BANK_LIMIT_DEG, "%s banking mismatch %.3f deg" % [label, bank])
	_check(absf(width - half * 2.0) <= WIDTH_TOLERANCE, "%s width %.3f m" % [label, width])
	return {"gap": worst_gap, "offset": worst_offset, "bank": bank}


func _measure(track: String) -> void:
	var world = WORLD.new()
	root.add_child(world)
	world.build(true, track, true)
	var layout: Dictionary = world.loop_layout
	_check(not layout.is_empty(), "%s has a loop" % track)
	if layout.is_empty():
		world.free()
		return
	var start: float = float(layout.start)
	var half: float = LOOP.half_width_of(layout)
	var entry_lane: float = float(layout.lane)
	var exit_lane: float = LOOP.exit_lane(layout)
	var rows: Array = LOOP.deck_rows(world, layout)
	var vertices: PackedVector3Array = _deck_vertices(world)
	_check(not vertices.is_empty(), "%s deck mesh present" % track)
	# 1) The rendered deck is exactly the measured rows (no extra plinths/steps).
	var mesh_error: float = 0.0
	for index in [0, LOOP.APRON_SEGMENTS, rows.size() - 1 - LOOP.APRON_SEGMENTS, rows.size() - 1]:
		for key in ["left", "right"]:
			mesh_error = maxf(mesh_error, _nearest(vertices, rows[index][key]))
	_check(mesh_error < 0.0005, "%s mesh matches measured rows (%.5f m)" % [track, mesh_error])
	# 2) Joins: apron start, loop entry lip, loop exit lip, apron end.
	var first_ring: int = LOOP.APRON_SEGMENTS
	var last_ring: int = first_ring + LOOP.DECK_SEGMENTS
	var joins: Array = [
		[rows[0], start - LOOP.APRON_M, entry_lane, "apron-in"],
		[rows[first_ring], start, entry_lane, "entry"],
		[rows[last_ring], start + LOOP.advance_of(layout), exit_lane, "exit"],
		[rows[rows.size() - 1], start + LOOP.advance_of(layout) + LOOP.APRON_M, exit_lane, "apron-out"],
	]
	var worst: Dictionary = {"gap": 0.0, "offset": 0.0, "bank": 0.0}
	for join in joins:
		var result: Dictionary = _join(world, join[0], join[1], join[2], half, track + " " + join[3])
		for key in worst:
			worst[key] = maxf(worst[key], result[key])
	# 3) Tangent continuity at both lips: the ring leaves and meets the road flat.
	var entry_dir: Vector3 = (
		(rows[first_ring + 1].left + rows[first_ring + 1].right)
		- (rows[first_ring].left + rows[first_ring].right)
	)
	var exit_dir: Vector3 = (
		(rows[last_ring].left + rows[last_ring].right)
		- (rows[last_ring - 1].left + rows[last_ring - 1].right)
	)
	var entry_kink: float = _angle_deg(entry_dir, world.forward(start))
	var exit_kink: float = _angle_deg(exit_dir, world.forward(start + LOOP.advance_of(layout)))
	_check(entry_kink <= KINK_LIMIT_DEG, "%s entry kink %.2f deg" % [track, entry_kink])
	_check(exit_kink <= KINK_LIMIT_DEG, "%s exit kink %.2f deg" % [track, exit_kink])
	# 4) Continuous surface: no row jumps, constant width through the ring.
	var largest_step: float = 0.0
	var width_error: float = 0.0
	for index in range(rows.size() - 1):
		largest_step = maxf(largest_step, rows[index].left.distance_to(rows[index + 1].left))
		largest_step = maxf(largest_step, rows[index].right.distance_to(rows[index + 1].right))
		width_error = maxf(width_error, absf(rows[index].left.distance_to(rows[index].right) - half * 2.0))
	_check(largest_step <= ROW_STEP_LIMIT, "%s largest row step %.3f m" % [track, largest_step])
	_check(width_error <= WIDTH_TOLERANCE, "%s deck width error %.4f m" % [track, width_error])
	# 5) Climbing and descending tracks never cross: compare every low pair.
	var basis: Basis = world.frame(start)
	var origin: Vector3 = world.position_at(start)
	var crossing: float = INF
	var low_rows: Array = []
	for index in range(first_ring, last_ring + 1):
		var row: Dictionary = rows[index]
		var center: Vector3 = (row.left + row.right) * 0.5 - origin
		var height: float = center.dot(basis.y)
		if height < 3.0:
			var lateral_a: float = (row.left - origin).dot(basis.x)
			var lateral_b: float = (row.right - origin).dot(basis.x)
			low_rows.append(
				{
					"u": row.u, "forward": center.dot(-basis.z), "height": height,
					"low": minf(lateral_a, lateral_b), "high": maxf(lateral_a, lateral_b)
				}
			)
	for a in low_rows:
		if a.u >= 0.5:
			continue
		for b in low_rows:
			if b.u <= 0.5:
				continue
			if absf(a.forward - b.forward) < 0.6 and absf(a.height - b.height) < 1.2:
				var separation: float = maxf(b.low - a.high, a.low - b.high)
				crossing = minf(crossing, separation)
	_check(crossing >= CROSSING_CLEARANCE, "%s climbing/descending clearance %.3f m" % [track, crossing])
	# 6) Both road joins stay on asphalt; the ring itself is on the exterior branch.
	var edge: float = float(world.road_width) * 0.5 - 0.15
	for lane in [entry_lane, exit_lane]:
		_check(absf(lane) + half <= edge, "%s deck at lane %.2f inside road edge" % [track, lane])
	# 7) Walls grow out of the road instead of standing on it as blocks.
	_check(float(rows[0].wall) == 0.0 and float(rows[rows.size() - 1].wall) == 0.0, "%s walls taper" % track)
	print(
		(
			"[LoopSeam] %s: gap %.4f m, Versatz %.4f m, banking %.3f deg, kink in/out %.2f/%.2f deg, row step %.3f m, track clearance %.3f m"
			% [track, worst.gap, worst.offset, worst.bank, entry_kink, exit_kink, largest_step, crossing]
		)
	)
	world.free()


func _run() -> void:
	for track in TRACKS:
		_measure(track)
	if failures > 0:
		printerr("[LoopSeam] %d failures" % failures)
		quit(1)
		return
	print("[LoopSeam] PASS: %d loops join the road seamlessly" % TRACKS.size())
	quit(0)
