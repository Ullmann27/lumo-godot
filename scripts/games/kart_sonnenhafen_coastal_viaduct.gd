extends RefCounted
## Sonnenhafen sea-facing pedestrian viaducts. Entirely original geometry.
## Deliberately outside the 10.8 m racing surface: no collision, AI, laps,
## item balance, scoring, animations or persistent game state are modified.
## All parts enter the existing spatial MultiMesh batches via world._prop().
const SITES: Array[float] = [0.66, 0.79]
const SITE_SIDE: Array[float] = [1.0, -1.0]
const HALF_RUN: float = 25.0
const SUPPORT_OFFSET: float = 18.0
const PIER_CLEARANCE: float = 9.2

const LIMESTONE := Color("e4c7a3")
const STEEL := Color("244e67")
const DEEP_STEEL := Color("183a51")
const GLASS := Color("5ecbd7")
const SKY := Color("9cecf0")
const SUN := Color("ffce80")


static func build(world) -> void:
	if world.track_id != "sonnenhafen":
		return
	var before: int = world.decoration_count
	var sites: Array[Dictionary] = []
	for index in range(SITES.size()):
		var center_d: float = world.length * SITES[index]
		var side: float = SITE_SIDE[index]
		var anchors: Array[Vector3] = []
		var feet: Array[Vector3] = []
		var invalid: bool = false
		for step in range(7):
			var distance: float = center_d - HALF_RUN + float(step) * HALF_RUN / 3.0
			var road_centre: Vector3 = world.position_at(distance)
			var rail_side: Vector3 = world.position_at(distance, side * SUPPORT_OFFSET)
			var ground_y: float = world._ground_height(rail_side.x, rail_side.z)
			var foot := Vector3(rail_side.x, ground_y, rail_side.z)
			if world._near_road(foot, PIER_CLEARANCE):
				invalid = true
				break
			feet.append(foot)
			anchors.append(Vector3(foot.x, maxf(road_centre.y + 6.2, ground_y + 7.3), foot.z))
		if invalid:
			continue
		_structure(world, anchors, feet, index)
		sites.append({
			"fraction": SITES[index], "side": side,
			"anchors": anchors, "feet": feet
		})
	world.set_meta("sonnenhafen_viaduct_sites", sites)
	world.set_meta("sonnenhafen_viaduct_parts", world.decoration_count - before)


static func _structure(
	world, anchors: Array[Vector3], feet: Array[Vector3], site_index: int
) -> void:
	for i in range(anchors.size()):
		var crown: Vector3 = anchors[i]
		var foot: Vector3 = feet[i]
		var height: float = crown.y - foot.y
		# Tapered maritime piers, capstones and projecting outriggers.
		world._prop("cylinder", (foot + crown) * 0.5,
			Vector3(0.85, height, 0.85), LIMESTONE)
		world._prop("cylinder", foot + Vector3.UP * 0.36,
			Vector3(1.18, 0.72, 1.18), DEEP_STEEL)
		world._prop("cylinder", crown - Vector3.UP * 0.26,
			Vector3(1.25, 0.36, 1.25), STEEL)
		if not world.low_detail:
			world._prop("cylinder", foot + Vector3.UP * height * 0.45,
				Vector3(0.93, 0.24, 0.93), STEEL)
			world._prop("cylinder", foot + Vector3.UP * height * 0.75,
				Vector3(0.91, 0.18, 0.91), STEEL)
		if i == anchors.size() - 1:
			continue
		var next_crown: Vector3 = anchors[i + 1]
		var travel: Vector3 = next_crown - crown
		var basis: Basis = Basis.looking_at(travel.normalized(), Vector3.UP)
		var centre: Vector3 = (crown + next_crown) * 0.5
		var span: float = travel.length()
		# Broad continuous promenade, original trussed silhouette, no nav mesh.
		world._prop("box", centre, Vector3(3.1, 0.42, span + 0.12), LIMESTONE, basis)
		world._prop("box", centre + Vector3.UP * 0.23,
			Vector3(2.95, 0.06, span + 0.08), STEEL, basis)
		for side in [-1.0, 1.0]:
			var side_basis: Vector3 = basis.x * side
			var start: Vector3 = crown + side_basis * 1.45
			var end: Vector3 = next_crown + side_basis * 1.45
			world._beam(start + Vector3.UP * 1.05, end + Vector3.UP * 1.05, 0.105, GLASS)
			world._beam(start - Vector3.UP * 0.15, end - Vector3.UP * 0.15, 0.19, STEEL)
			if not world.low_detail:
				for rung in range(3):
					var u: float = (float(rung) + 0.5) / 3.0
					var post: Vector3 = start.lerp(end, u)
					world._prop("cylinder", post + Vector3.UP * 0.52,
						Vector3(0.075, 1.07, 0.075), STEEL)
				# Oblique steel members make silhouette legible from chase cam.
				world._beam(start - Vector3.UP * 0.19,
					(start + end) * 0.5 + Vector3.UP * 1.04, 0.065, DEEP_STEEL)
		if i % 2 == 0:
			world._prop("cylinder", centre + Vector3.UP * 2.2,
				Vector3(0.10, 3.8, 0.10), STEEL)
			world._prop("ball", centre + Vector3.UP * 4.15,
				Vector3(0.50, 0.50, 0.50), SUN, Basis.IDENTITY, true)
	# A recognisable sunrise-crown at the middle, not a reused harbor crane.
	var p: Vector3 = anchors[3] + Vector3.UP * 1.8
	world._prop("torus", p + Vector3.UP * 1.0,
		Vector3(4.5, 0.26, 4.5), SKY, Basis(Vector3.RIGHT, PI * 0.5), true)
	world._prop("ball", p + Vector3.UP * 1.0,
		Vector3(1.2, 1.2, 1.2), SUN, Basis.IDENTITY, true)
	if not world.low_detail:
		for ray in range(8):
			var a: float = float(ray) * TAU / 8.0
			var ray_start: Vector3 = p + Vector3.UP * 1.0 + Vector3(cos(a), sin(a), 0.0) * 2.5
			var ray_end: Vector3 = p + Vector3.UP * 1.0 + Vector3(cos(a), sin(a), 0.0) * 3.6
			world._beam(ray_start, ray_end, 0.08, SUN, true)
