extends RefCounted
## B2 east tidal-channel racing viaduct support system.
## Real instanced pylons below the *existing* driveable road, no replacement
## of kart physics, collision rail, checkpoint locations or saved-progress IDs.
const NAVY := Color("244c60")
const STONE := Color("d1bfa7")
const SEAM := Color("517d8a")
const GOLD := Color("fff0ba")
const ROAD_OFFSET: float = 9.0

static func build(world) -> void:
	if world.track_id != "sonnenhafen" or world.world_extent.x < 160.0:
		return
	var before: int = world.decoration_count
	var supports: Array[Dictionary] = []
	var spacing: float = 29.0 if world.low_detail else 16.0
	var count: int = ceili(world.length / spacing)
	for i in range(count):
		var d: float = (float(i) + 0.5) * world.length / float(count)
		var centre: Vector3 = world.position_at(d)
		if centre.x < 250.0 or absf(centre.z) > 85.0:
			continue
		var bed: float = world._ground_height(centre.x, centre.z)
		if bed > -3.0 or centre.y - bed < 10.0:
			continue
		var basis: Basis = world.frame(d)
		var piers: Array[Vector3] = []
		for side in [-1.0, 1.0]:
			var edge: Vector3 = world.position_at(d, side * ROAD_OFFSET)
			var foot_y: float = minf(bed, world._ground_height(edge.x, edge.z))
			var bottom: Vector3 = Vector3(edge.x, foot_y, edge.z)
			var top: Vector3 = Vector3(edge.x, centre.y - 0.48, edge.z)
			var height: float = top.y - bottom.y
			if height < 5.0:
				continue
			world._prop("cylinder", (top + bottom) * 0.5,
				Vector3(0.72, height, 0.72), STONE)
			world._prop("cylinder", bottom + Vector3.UP * 0.30,
				Vector3(1.0, 0.60, 1.0), NAVY)
			world._prop("cylinder", top - Vector3.UP * 0.22,
				Vector3(1.12, 0.40, 1.12), SEAM)
			if not world.low_detail:
				world._beam(top - basis.x * side * 0.2 - Vector3.UP * 2.8,
					centre - Vector3.UP * 0.64, 0.13, NAVY)
				for y_fraction in [0.35, 0.65]:
					world._prop("cylinder",
						bottom.lerp(top, y_fraction),
						Vector3(0.79, 0.20, 0.79), SEAM)
			piers.append(bottom)
		if piers.size() != 2:
			continue
		var cross: Vector3 = centre - Vector3.UP * 0.56
		world._prop("box", cross,
			Vector3(ROAD_OFFSET * 2.1, 0.28, 1.1), NAVY, basis)
		if not world.low_detail:
			world._prop("box", cross - Vector3.UP * 0.20,
				Vector3(ROAD_OFFSET * 2.05, 0.14, 1.5), STONE, basis)
		supports.append({"distance": d, "feet": piers, "road_height": centre.y})
	world.set_meta("sonnenhafen_long_bridge_supports", supports)
	world.set_meta("sonnenhafen_long_bridge_parts", world.decoration_count - before)
