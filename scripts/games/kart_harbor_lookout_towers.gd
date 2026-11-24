extends RefCounted
## Three original Sonnenhafen observation towers, no external AI assets.
## Real 3D meshes are instanced through the existing spatial GPU batches.
## Every element sits outside the driveable corridor: visuals never affect
## lap timing, collision, steering, checkpoints, or camera.
const STATIONS: Array[float] = [0.17, 0.53, 0.87]
const RACE_CLEARANCE: float = 12.0
const NAVY := Color("142E4B")
const STEEL := Color("A8C9D8")
const SKY_GLASS := Color("3283A9")
const CYAN := Color("53ECFF")
const GOLD := Color("FFC87D")

static func build(world) -> void:
	if world.track_id != "sonnenhafen":
		return
	var before: int = world.decoration_count
	var placements: Array[Vector3] = []
	for i in range(STATIONS.size()):
		var distance: float = world.length * STATIONS[i]
		if world.in_gap(distance) or world.ramp_height(distance) > 0.2:
			continue
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var road_side: Vector3 = world.position_at(distance, side * 21.0)
		var foundation := Vector3(
			road_side.x,
			world._ground_height(road_side.x, road_side.z),
			road_side.z
		)
		# Checking the whole observation footprint, not just the mast.
		if world._near_road(foundation, RACE_CLEARANCE):
			continue
		_build_tower(world, foundation, i)
		placements.append(foundation)
	world.set_meta("sonnenhafen_lookouts", placements)
	world.set_meta("sonnenhafen_lookout_parts", world.decoration_count - before)

static func _build_tower(world, base: Vector3, index: int) -> void:
	var height: float = 16.5 + 1.4 * float(index)
	var roof: Vector3 = base + Vector3.UP * height
	var orient: Basis = Basis(Vector3.UP, PI * float(index) / 5.0)
	# Four broad structural legs. Supports terminate at actual terrain height.
	for i in range(4):
		var angle: float = PI * 0.25 + float(i) * TAU / 4.0
		var local := Vector3(cos(angle) * 1.3, 0, sin(angle) * 1.3)
		var foot: Vector3 = base + orient * local * 1.5
		var crown: Vector3 = roof + orient * local
		world._beam(foot, crown, 0.21, STEEL)
		world._beam(base + Vector3.UP * 5.0 + orient * local, crown, 0.08, NAVY)
	# Main steel mast and an observation floor use instanced true 3D.
	world._prop("cylinder", base + Vector3.UP * height * 0.5,
		Vector3(1.30, height, 1.30), NAVY)
	world._prop("cylinder", roof, Vector3(5.9, 0.65, 5.9), STEEL)
	world._prop("cylinder", roof + Vector3.UP * 0.53,
		Vector3(4.8, 0.75, 4.8), SKY_GLASS)
	world._prop("cone", roof + Vector3.UP * 2.15,
		Vector3(5.7, 2.0, 5.7), NAVY)
	# Discontinuous cyan light bands remain identifiable at racing speed.
	for light_y in [height - 0.65, height + 0.30, height + 1.30]:
		world._prop("torus", base + Vector3.UP * light_y,
			Vector3(6.0, 0.25, 6.0), CYAN, Basis.IDENTITY, true)
	# Scenic platforms are well outside the road so none require collisions.
	for j in range(8):
		var theta: float = TAU * float(j) / 8.0
		var radial := Vector3(cos(theta), 0, sin(theta))
		var p: Vector3 = roof + radial * 2.8
		world._prop("cylinder", p + Vector3.UP * 0.95,
			Vector3(0.085, 1.7, 0.085), STEEL)
		if not world.low_detail:
			var next_theta: float = TAU * float(j + 1) / 8.0
			var end: Vector3 = roof + Vector3(cos(next_theta), 0, sin(next_theta)) * 2.8
			world._beam(p + Vector3.UP * 1.45, end + Vector3.UP * 1.45, 0.075, CYAN)
	# A luminous beacon with a metallic housing; reduced detail keeps its
	# silhouette but eliminates tiny accents on slower Android GPUs.
	world._prop("cylinder", roof + Vector3.UP * 3.35,
		Vector3(0.24, 1.3, 0.24), STEEL)
	world._prop("ball", roof + Vector3.UP * 4.15,
		Vector3(0.68, 0.68, 0.68), GOLD, Basis.IDENTITY, true)
	if not world.low_detail:
		for rung in range(5):
			world._prop("box", base + Vector3.UP * (2.0 + float(rung) * 2.6),
				Vector3(1.8, 0.11, 0.22), CYAN, orient, true)
