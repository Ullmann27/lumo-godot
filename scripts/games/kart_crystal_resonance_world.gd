extends RefCounted
## An authored approach, broad geological gateway, and open crystal-gorge reveal.
## The existing physical road and jump remain the only drivable route.

const GROUND = preload("res://scripts/games/track_themes/track_ground_profile.gd")
const BASALT := Color("49485f")
const ROCK := Color("776783")
const STRATA := Color("ad91ac")
const VIOLET := Color("a67bd0")
const BLUE := Color("67b9d1")
const DEEP_BLUE := Color("3b718b")
const GOLD := Color("efc175")
const SECTION := 0.61


static func build(world) -> void:
	if world.track_id != "crystal_canyon":
		return
	var first: int = world.decoration_count
	var distance: float = world.length * SECTION
	var center: Vector3 = world.position_at(distance)
	var direction: Vector3 = world.forward(distance)
	direction.y = 0.0
	var basis := Basis.looking_at(direction.normalized())
	var wall_count := _cliff_approach(world, distance)
	_gateway(world, center, basis)
	var overlook_count := _overlook(world, distance + 59.0)
	var marker := Node3D.new()
	marker.name = "CrystalResonanceLandmark"
	marker.set_meta("first_piece", first)
	marker.set_meta("piece_count", world.decoration_count - first)
	marker.set_meta("wall_count", wall_count)
	marker.set_meta("overlook_count", overlook_count)
	marker.set_meta("gateway_position", center)
	marker.set_meta("section_distance", distance)
	world.add_child(marker)


static func _cliff_approach(world, center: float) -> int:
	var accepted := 0
	var count := 5 if world.low_detail else 7
	for index in range(count):
		var fraction := float(index) / float(count - 1)
		var distance: float = center - 47.0 + fraction * 80.0
		var direction: Vector3 = world.forward(distance)
		direction.y = 0.0
		var basis := Basis.looking_at(direction.normalized())
		for side in [-1.0, 1.0]:
			var at: Vector3 = world.position_at(distance) + basis.x * side * 27.0
			if world._near_road(at, 22.0):
				continue
			at.y = GROUND.surface_height("crystal_canyon")
			accepted += 1
			var height := 13.0 + float((index * 7) % 9)
			world._prop(
				"rock", at + Vector3.UP * height * 0.5, Vector3(6.0, height, 8.0), BASALT, basis
			)
			world._prop(
				"rock",
				at + Vector3.UP * (height * 0.88),
				Vector3(6.3, height * 0.36, 8.2),
				ROCK,
				basis
			)
			world._prop(
				"rock", at + Vector3.UP * (height * 0.64), Vector3(6.1, 0.85, 8.0), STRATA, basis
			)
			for shard in range(2 if world.low_detail else 3):
				var local := Vector3(float(shard - 1) * 2.0, 0.0, -5.0 + float(shard) * 3.9)
				var crystal: Vector3 = at + basis * local + Vector3.UP * (height * 0.92)
				world._prop(
					"crystal",
					crystal,
					Vector3(1.05, 4.8 + shard, 1.05),
					BLUE if shard % 2 else VIOLET,
					basis
				)
			var foot: Vector3 = at - basis.x * side * 4.5 + Vector3.UP * 0.9
			world._prop("crystal", foot, Vector3(0.65, 2.0, 0.65), GOLD, basis, true)
	return accepted


static func _gateway(world, center: Vector3, basis: Basis) -> void:
	world._prop("arch", center + Vector3.UP * 1.8, Vector3(16.5, 17.0, 7.2), BASALT, basis)
	world._prop(
		"arch",
		center + Vector3.UP * 1.9 - basis.z * 3.45,
		Vector3(16.65, 17.15, 0.35),
		STRATA,
		basis
	)
	# Thin mineral seams articulate the opening without an opaque portal plane.
	world._prop(
		"arch",
		center + Vector3.UP * 2.05 - basis.z * 3.68,
		Vector3(16.45, 17.0, 0.12),
		DEEP_BLUE,
		basis
	)
	for side in [-1.0, 1.0]:
		var at: Vector3 = center + basis.x * side * 19.8
		var floor_y: float = GROUND.surface_height("crystal_canyon")
		var pedestal_height: float = maxf(center.y + 2.4 - floor_y, 1.0)
		world._prop(
			"box",
			Vector3(at.x, floor_y + pedestal_height * 0.5, at.z),
			Vector3(3.6, pedestal_height, 9.0),
			ROCK,
			basis
		)
		world._prop("rock", at + Vector3.UP * 4.2, Vector3(3.2, 9.0, 5.4), ROCK, basis)
		world._prop(
			"crystal",
			at + basis.z * 4.8 + Vector3.UP * 0.7,
			Vector3(1.6, 10.7, 1.6),
			BLUE if side > 0 else VIOLET,
			basis * Basis(Vector3.FORWARD, -side * 0.10)
		)
		world._prop(
			"crystal",
			at - basis.z * 4.5 + Vector3.UP * 1.0,
			Vector3(1.1, 7.3, 1.1),
			VIOLET if side > 0 else BLUE,
			basis
		)
		world._prop("crystal", at + Vector3.UP * 8.1, Vector3(0.48, 2.9, 0.48), GOLD, basis, true)
	# The large suspended geode hangs well above the six-metre driving envelope.
	var crest := center + Vector3.UP * 20.6
	world._prop("rock", crest, Vector3(5.6, 4.3, 4.6), ROCK, basis)
	world._prop(
		"crystal", crest - basis.z * 4.1 - Vector3.UP * 2.1, Vector3(1.25, 3.9, 1.25), BLUE, basis
	)
	for side in [-1.0, 1.0]:
		world._prop(
			"crystal",
			crest + basis.x * side * 3.2 - basis.z * 2.5,
			Vector3(0.8, 2.9, 0.8),
			VIOLET,
			basis
		)


static func _overlook(world, distance: float) -> int:
	var accepted := 0
	var center: Vector3 = world.position_at(distance)
	var ahead: Vector3 = world.forward(distance)
	ahead.y = 0.0
	var basis := Basis.looking_at(ahead.normalized())
	for side in [-1.0, 1.0]:
		for index in range(3):
			var at: Vector3 = (
				center + basis.x * side * (39.0 + index * 15.0) + basis.z * (index * 18.0)
			)
			if world._near_road(at, 26.0):
				continue
			at.y = GROUND.surface_height("crystal_canyon")
			accepted += 1
			world._prop("mountain", at, Vector3(15.0, 26.0 + index * 6.0, 13.0), ROCK, basis)
			world._prop(
				"crystal",
				at + Vector3.UP * 15.0,
				Vector3(3.0, 12.0 + index * 3.0, 3.0),
				VIOLET if index % 2 else BLUE,
				basis
			)
			if not world.low_detail:
				world._prop(
					"crystal",
					at + basis.x * 7.0 + Vector3.UP * 2.0,
					Vector3(1.8, 9.0, 1.8),
					DEEP_BLUE,
					basis
				)
	return accepted
