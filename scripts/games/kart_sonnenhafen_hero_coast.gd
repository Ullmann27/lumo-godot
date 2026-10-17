extends RefCounted
## B3: five original, high-silhouette 3D coastal hero landmarks along the
## actually driveable 1,851 m Sonnenhafen circuit. Decorative only.
## This module intentionally uses the established GPU MultiMesh batching and
## does not mutate checkpoints, kart physics, savegames or the Flutter bridge.
const FRACTIONS: Array[float] = [0.10, 0.28, 0.46, 0.65, 0.84]
const SIDES: Array[float] = [1.0, -1.0, 1.0, -1.0, 1.0]
const KINDS: Array[String] = [
	"sun_observatory", "cliff_amphitheater", "harbor_sails",
	"celestial_wheel", "wind_garden"
]
const FOOTPRINT_RADIUS: float = 15.0
const CLEARANCE: float = 7.5
const SAND := Color("e5c69b")
const CORAL := Color("d79062")
const ROCK := Color("a87556")
const DARK := Color("263f56")
const STEEL := Color("5d8796")
const GLASS := Color("60dce2")
const JADE := Color("70b886")
const SUN := Color("ffd17b")
const CREAM := Color("f4ead3")

static func build(world) -> void:
	if world.track_id != "sonnenhafen" or world.length < 1500.0:
		return
	var before: int = world.decoration_count
	var built: Array[Dictionary] = []
	for i in range(FRACTIONS.size()):
		var distance: float = world.length * FRACTIONS[i]
		var basis: Basis = world.frame(distance)
		var anchor := Vector3.INF
		# Check the FULL footprint, not just its centre, against the complete
		# closed racing spline (including nonadjacent curve segments).
		for lateral in [35.0, 43.0, 51.0, 59.0]:
			var proposed: Vector3 = world.position_at(distance, SIDES[i] * lateral)
			var p := Vector3(
				proposed.x, world._ground_height(proposed.x, proposed.z), proposed.z
			)
			if not world._near_road(p, FOOTPRINT_RADIUS + CLEARANCE):
				anchor = p
				break
		if not anchor.is_finite():
			continue
		var before_site: int = world.decoration_count
		_foundation(world, anchor, basis)
		match i:
			0: _sun_observatory(world, anchor, basis)
			1: _cliff_amphitheater(world, anchor, basis)
			2: _harbor_sails(world, anchor, basis)
			3: _celestial_wheel(world, anchor, basis)
			4: _wind_garden(world, anchor, basis)
		built.append({
			"fraction": FRACTIONS[i], "kind": KINDS[i], "position": anchor,
			"radius": FOOTPRINT_RADIUS, "parts": world.decoration_count - before_site
		})
	world.set_meta("sonnenhafen_hero_landmarks", built)
	world.set_meta("sonnenhafen_hero_parts", world.decoration_count - before)

static func _foundation(world, at: Vector3, basis: Basis) -> void:
	# Cliff strata sit under every signature building, including maritime
	# islands where the authored coastal terrain lies below sea level.
	world._prop("rock", at + Vector3.UP * 2.3,
		Vector3(12.8, 5.4, 13.2), ROCK, basis)
	world._prop("rock", at + Vector3.UP * 4.3,
		Vector3(10.3, 2.6, 10.0), CORAL, basis)
	world._prop("cylinder", at + Vector3.UP * 5.8,
		Vector3(10.4, 0.28, 10.4), SAND)

static func _sun_observatory(world, at: Vector3, basis: Basis) -> void:
	var top: Vector3 = at + Vector3.UP * 6.0
	# An original coastal sunspire with recognisable circular glass terraces.
	world._prop("cylinder", top + Vector3.UP * 14.0,
		Vector3(2.8, 28.0, 2.8), CREAM)
	for height in [8.0, 17.0, 27.0]:
		world._prop("cylinder", top + Vector3.UP * height,
			Vector3(5.1, 0.55, 5.1), DARK)
		world._prop("cylinder", top + Vector3.UP * (height + 0.38),
			Vector3(4.65, 0.36, 4.65), GLASS)
		if not world.low_detail:
			world._prop("torus", top + Vector3.UP * (height + 0.38),
				Vector3(10.0, 0.24, 10.0), GLASS, Basis.IDENTITY, true)
	world._prop("cone", top + Vector3.UP * 30.0,
		Vector3(4.2, 3.8, 4.2), CORAL)
	world._prop("ball", top + Vector3.UP * 33.2,
		Vector3(2.2, 2.2, 2.2), SUN, Basis.IDENTITY, true)
	for i in range(8 if not world.low_detail else 4):
		var a: float = float(i) * TAU / (8.0 if not world.low_detail else 4.0)
		var radial := Vector3(cos(a), 0.0, sin(a))
		var pillar: Vector3 = top + radial * 7.0
		world._prop("cylinder", pillar + Vector3.UP * 4.3,
			Vector3(0.48, 8.6, 0.48), STEEL)
		world._beam(pillar + Vector3.UP * 8.8,
			top + Vector3.UP * 14.0, 0.20, CREAM)

static func _cliff_amphitheater(world, at: Vector3, basis: Basis) -> void:
	var crown: Vector3 = at + Vector3.UP * 6.0
	# Real stepped coastal terraces: a large, layered profile readable at
	# speed, rather than microboxes that shimmer on Android.
	for tier in range(5):
		var y: float = float(tier) * 2.6
		var radius: float = 10.4 - float(tier) * 1.0
		world._prop("rock", crown + Vector3.UP * (y + 1.0),
			Vector3(radius, 3.6, radius * 1.12),
			ROCK if tier % 2 == 0 else CORAL, basis)
		world._prop("cylinder", crown + Vector3.UP * (y + 2.1),
			Vector3(radius * 0.89, 0.36, radius * 0.89), SAND)
		if not world.low_detail:
			world._prop("torus", crown + Vector3.UP * (y + 2.25),
				Vector3(radius * 1.6, 0.12, radius * 1.6), CREAM)
	# Four large sculpted buttresses remain present on Mobile Low:
	# structural silhouettes, not high-frequency decorative fragments.
	for side in [-1.0, 1.0]:
		for depth in [-1.0, 1.0]:
			var buttress: Vector3 = crown + basis * Vector3(
				side * 6.1, 6.0, depth * 6.1
			)
			world._prop("rock", buttress,
				Vector3(2.0, 11.8, 2.3), CORAL, basis)
	var monument: Vector3 = crown + Vector3.UP * 17.0
	world._prop("crystal", monument, Vector3(4.0, 8.4, 4.0),
		GLASS, basis, true)
	if not world.low_detail:
		for i in range(10):
			var theta: float = TAU * float(i) / 10.0
			var outer: Vector3 = crown + basis * Vector3(
				cos(theta) * 9.0, 13.6, sin(theta) * 9.0
			)
			world._prop("crown", outer,
				Vector3(2.2, 1.5, 1.9), JADE)

static func _harbor_sails(world, at: Vector3, basis: Basis) -> void:
	var deck: Vector3 = at + Vector3.UP * 6.3
	world._prop("cylinder", deck, Vector3(12.5, 0.65, 12.5), DARK)
	# Layered tensile sails form a dramatic original skyline sculpture;
	# all spars are true solid beams, with no alpha overdraw.
	for index in range(3):
		var side: float = float(index - 1)
		var root: Vector3 = deck + basis.x * side * 5.1
		var mast_height: float = 24.0 + float(index % 2) * 6.5
		world._prop("cylinder", root + Vector3.UP * mast_height * 0.5,
			Vector3(0.35, mast_height, 0.35), CREAM)
		var peak: Vector3 = root + Vector3.UP * mast_height
		for rung in range(8 if not world.low_detail else 4):
			var u: float = float(rung) / (7.0 if not world.low_detail else 3.0)
			var billow: Vector3 = root + basis.z * (9.0 * (1.0 - u))
			billow += basis.x * (side * (2.0 + u) + 3.0 * sin(u * PI))
			billow += Vector3.UP * (u * mast_height)
			world._beam(peak.lerp(root, u), billow,
				0.22 if world.low_detail else 0.13,
				GLASS if index == 1 else CREAM)
		world._beam(peak, root + basis.z * 10.0, 0.21, STEEL)
	world._prop("ball", deck + Vector3.UP * 35.0,
		Vector3(1.6, 1.6, 1.6), SUN, Basis.IDENTITY, true)

static func _celestial_wheel(world, at: Vector3, basis: Basis) -> void:
	var centre: Vector3 = at + Vector3.UP * 23.0
	var upright: Basis = basis * Basis(Vector3.RIGHT, PI * 0.5)
	# 22m vertical solar wheel and a genuinely triangulated support tripod.
	world._prop("torus", centre, Vector3(43.0, 0.65, 43.0),
		SUN, upright, true)
	world._prop("ball", centre, Vector3(3.0, 3.0, 3.0),
		GLASS, Basis.IDENTITY, true)
	for spoke in range(16 if not world.low_detail else 8):
		var phi: float = TAU * float(spoke) / (16.0 if not world.low_detail else 8.0)
		var rim: Vector3 = centre + basis.x * (cos(phi) * 10.8)
		rim += Vector3.UP * (sin(phi) * 10.8)
		world._beam(centre, rim, 0.14, CREAM, true)
	for side in [-1.0, 1.0]:
		var foot: Vector3 = at + basis.x * side * 7.0 + Vector3.UP * 6.0
		world._beam(foot, centre, 0.50, STEEL)
		world._prop("cylinder", foot + Vector3.UP * 0.40,
			Vector3(1.3, 0.80, 1.3), DARK)
	world._beam(at + Vector3.UP * 6.5, centre, 0.62, STEEL)
	if not world.low_detail:
		for i in range(8):
			var a: float = TAU * float(i) / 8.0
			var point: Vector3 = centre + basis.x * (cos(a) * 13.5)
			point += Vector3.UP * (sin(a) * 13.5)
			world._prop("star", point, Vector3.ONE * 0.5,
				GLASS, basis, true)

static func _wind_garden(world, at: Vector3, basis: Basis) -> void:
	# Three original coastal wind sculptures with fully 3D blades. Static
	# ornamental windmills avoid runtime node/tween/draw-call overhead.
	for index in range(3):
		var shift: Vector3 = basis * Vector3(
			float(index - 1) * 6.2, 0.0, -2.7 * float(index % 2)
		)
		var foot: Vector3 = at + shift + Vector3.UP * 6.0
		var height: float = 20.0 + float(index % 2) * 5.0
		world._prop("cone", foot + Vector3.UP * height * 0.5,
			Vector3(1.5, height, 1.5), CREAM)
		var hub: Vector3 = foot + Vector3.UP * height
		world._prop("ball", hub, Vector3(1.7, 1.7, 1.7), SUN,
			Basis.IDENTITY, true)
		for i in range(3):
			var a: float = TAU * float(i) / 3.0 + float(index) * 0.25
			var radial: Vector3 = basis.x * cos(a) + Vector3.UP * sin(a)
			var tip: Vector3 = hub + radial * 9.0
			world._beam(hub, tip, 0.24, GLASS)
			world._prop("crystal", tip, Vector3(0.90, 2.1, 1.0),
				SUN, basis)
		if not world.low_detail:
			world._prop("torus", foot + Vector3.UP * 1.6,
				Vector3(3.3, 0.17, 3.3), JADE, Basis.IDENTITY)
