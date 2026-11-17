extends RefCounted
## A connected alpine backdrop and cableway beside Winter-Sprint's existing road.
## Static pieces share the production world's spatial MultiMesh batches.

const GROUND = preload("res://scripts/games/track_themes/track_ground_profile.gd")
const CABLE_CARS = preload("res://scripts/games/kart_winter_cable_cars.gd")
const ROCK := Color("657993")
const ROCK_DARK := Color("455b79")
const ROCK_FAR := Color("8296b1")
const SNOW := Color("e2eff6")
const SNOW_SHADE := Color("afc9dc")
const TIMBER := Color("704b3c")
const FRAME := Color("293d51")
const CREAM := Color("e9d8ba")
const GLASS := Color("6399bc")
const LIGHT := Color("ffd18b")
const RED := Color("c95c55")


static func layout(world) -> Dictionary:
	var east := Vector3(-INF, 0, 0)
	var north := INF
	var south := -INF
	for point: Vector3 in world.curve.get_baked_points():
		if point.x > east.x:
			east = point
		north = minf(north, point.z)
		south = maxf(south, point.z)
	var ground_y: float = GROUND.surface_height("winter_sprint")
	# The older roadside snowbanks reach east of the road. Keep the complete
	# station and cabin corridor between them and the distant alpine ridge.
	var base := Vector3(east.x + 43.0, ground_y + 16.0, east.z + 55.0)
	var summit := base + Vector3(3.0, 8.0, -156.0)
	return {"east": east, "north": north, "south": south, "base": base, "summit": summit}


static func build(world) -> void:
	if world.track_id != "winter_sprint":
		return
	var arrangement := layout(world)
	var before: int = world.decoration_count
	var peaks := _ridgeline(world, arrangement)
	var gallery_count := _ice_gallery(world)
	var base: Vector3 = arrangement.base
	var summit: Vector3 = arrangement.summit
	var structures_begin: int = world.decoration_count
	# Both stations and every cable segment remain east of the entire road envelope.
	_station(world, base, false)
	_station(world, summit, true)
	var cable_low := base + Vector3(2.7, 7.9, -3.8)
	var cable_high := summit + Vector3(2.7, 7.9, -3.8)
	_cableway(world, cable_low, cable_high)
	var landmark := Node3D.new()
	landmark.name = "WinterAlpineLandmark"
	landmark.set_meta("base_station", base)
	landmark.set_meta("summit_station", summit)
	landmark.set_meta("cable_low", cable_low)
	landmark.set_meta("cable_high", cable_high)
	landmark.set_meta("peak_count", peaks)
	landmark.set_meta("gallery_count", gallery_count)
	landmark.set_meta("first_piece", before)
	landmark.set_meta("piece_count", world.decoration_count - before)
	landmark.set_meta("first_structure", structures_begin)
	landmark.set_meta("structure_count", world.decoration_count - structures_begin)
	world.add_child(landmark)
	var cars := CABLE_CARS.new()
	cars.configure(cable_low, cable_high, world)
	landmark.add_child(cars)


static func _ridgeline(world, arrangement: Dictionary) -> int:
	var count := 6 if world.low_detail else 9
	var ground_y: float = GROUND.surface_height("winter_sprint")
	for index in range(count):
		var t := float(index) / float(count - 1)
		var height := 47.0 + float((index * 13) % 31)
		var width := 33.0 + float((index * 7) % 13)
		var at := Vector3(
			float(arrangement.east.x) + 91.0 + float(index % 3) * 13.0,
			ground_y,
			lerpf(float(arrangement.north) - 49.0, float(arrangement.south) + 44.0, t)
		)
		var facing := Basis(Vector3.UP, float(index) * 0.57)
		world._prop("mountain", at, Vector3(width, height, 39), ROCK_DARK, facing)
		world._prop(
			"mountain",
			at + Vector3(0, height * 0.56, 0),
			Vector3(width * 0.42, height * 0.445, 16.4),
			SNOW,
			facing
		)
		if not world.low_detail:
			world._prop(
				"mountain",
				at + Vector3(33, 0, -18),
				Vector3(34, height * 0.79, 31),
				ROCK_FAR,
				facing
			)
			world._prop(
				"mountain",
				at + Vector3(33, height * 0.47, -18),
				Vector3(12, height * 0.325, 11),
				SNOW_SHADE,
				facing
			)
	return count


static func _ice_gallery(world) -> int:
	var accepted := 0
	for index in range(4):
		var distance: float = world.length * 0.315 + float(index - 1) * 11.0
		var center: Vector3 = world.position_at(distance)
		var ahead: Vector3 = world.forward(distance)
		ahead.y = 0.0
		var basis := Basis.looking_at(ahead.normalized())
		var clear := true
		for side in [-1.0, 1.0]:
			if world._near_road(center + basis.x * side * 18.0, 14.0):
				clear = false
		if not clear or world.in_gap(distance) or world.ramp_height(distance) > 0.0:
			continue
		accepted += 1
		world._prop("arch", center + Vector3.UP * 3.0, Vector3(14.0, 8.0, 3.4), SNOW_SHADE, basis)
		world._prop("arch", center + Vector3.UP * 3.05, Vector3(14.25, 8.15, 0.22), SNOW, basis)
		for side in [-1.0, 1.0]:
			var at: Vector3 = center + basis.x * side * 18.0
			world._prop("rock", at + Vector3.UP * 1.2, Vector3(4.0, 7.0, 6.0), ROCK, basis)
			world._prop("rock", at + Vector3.UP * 4.0, Vector3(4.1, 3.0, 6.1), SNOW, basis)
			world._prop(
				"crystal",
				at - basis.x * side * 1.4 + Vector3.UP * 2.0,
				Vector3(1.0, 3.0, 1.0),
				GLASS,
				basis
			)
			world._prop(
				"box",
				center + basis.x * side * 14.1 + Vector3.UP * 2.0,
				Vector3(0.22, 3.6, 0.30),
				LIGHT,
				basis,
				true
			)
	return accepted


static func _station(world, at: Vector3, high: bool) -> void:
	var basis := Basis(Vector3.UP, -PI * 0.5)
	if high or at.y > GROUND.surface_height("winter_sprint"):
		# Both platforms stand on ground-connected piers. The lower station
		# sits beside the raised road, above its older roadside snowbanks.
		var floor_y: float = GROUND.surface_height("winter_sprint")
		var pier_height: float = at.y - floor_y
		for x in [-5.7, 5.7]:
			for z in [-3.6, 3.6]:
				_put(
					world,
					"box",
					at,
					basis,
					Vector3(x, -pier_height * 0.5, z),
					Vector3(1.15, pier_height, 1.15),
					ROCK
				)
		for level in [0.25, 0.68]:
			_put(
				world,
				"box",
				at,
				basis,
				Vector3(0, -pier_height * level, 0),
				Vector3(12.6, 0.6, 8.3),
				ROCK_DARK
			)
	_put(world, "box", at, basis, Vector3(0, 0.4, 0), Vector3(16, 0.8, 11), ROCK)
	_put(world, "box", at, basis, Vector3(0, 0.88, 0), Vector3(16.2, 0.16, 11.2), SNOW)
	_put(world, "box", at, basis, Vector3(0, 3.6, 0), Vector3(12.8, 5.4, 8), CREAM)
	_put(world, "box", at, basis, Vector3(0, 1.4, 0), Vector3(13.0, 1, 8.2), TIMBER)
	_put(world, "roof", at, basis, Vector3(0, 7.0, 0), Vector3(15, 2.3, 10), FRAME)
	_put(world, "roof", at, basis, Vector3(0, 7.23, 0), Vector3(15.2, 2.3, 10.2), SNOW)
	for x in [-5.5, -1.85, 1.85, 5.5]:
		_put(world, "box", at, basis, Vector3(x, 3.5, 4.1), Vector3(0.22, 5.1, 0.24), TIMBER)
	for x in [-3.7, 0.0, 3.7]:
		_put(world, "box", at, basis, Vector3(x, 4.15, 4.13), Vector3(2.85, 2.4, 0.13), FRAME)
		_put(world, "box", at, basis, Vector3(x, 4.15, 4.22), Vector3(2.53, 2.08, 0.08), GLASS)
		_put(world, "box", at, basis, Vector3(x, 4.15, 4.28), Vector3(0.08, 2.17, 0.06), CREAM)
		_put(world, "box", at, basis, Vector3(x, 3.95, 4.28), Vector3(2.60, 0.08, 0.06), CREAM)
	_put(world, "box", at, basis, Vector3(0, 2.0, 4.22), Vector3(1.8, 2.1, 0.22), FRAME)
	_put(world, "box", at, basis, Vector3(0, 2.25, 4.35), Vector3(1.43, 1.4, 0.05), LIGHT, true)
	for side in [-1.0, 1.0]:
		_put(
			world, "box", at, basis, Vector3(side * 6.9, 2.6, 4.8), Vector3(0.18, 3.3, 0.18), FRAME
		)
	_put(world, "box", at, basis, Vector3(0, 4.25, 4.8), Vector3(14.2, 0.27, 1.7), RED)
	_put(world, "box", at, basis, Vector3(0, 4.45, 4.8), Vector3(14.3, 0.12, 1.8), SNOW)
	for x in [-6.4, 6.4]:
		_put(world, "cylinder", at, basis, Vector3(x, 2.2, 4.6), Vector3(0.07, 2.6, 0.07), FRAME)
		_put(
			world, "ball", at, basis, Vector3(x, 3.55, 4.6), Vector3(0.24, 0.29, 0.24), LIGHT, true
		)
	for step in range(3):
		_put(
			world,
			"box",
			at,
			basis,
			Vector3(0, 0.15 + step * 0.25, 6.3 - step * 0.45),
			Vector3(3.5, 0.3, 0.7),
			SNOW_SHADE
		)
	# The star is geometry; it stays readable without an emissive screen or text.
	_put(world, "star", at, basis, Vector3(0, 6.35, 4.42), Vector3(0.55, 0.55, 0.18), LIGHT)
	if not world.low_detail:
		for side in [-1.0, 1.0]:
			for index in range(6):
				_put(
					world,
					"box",
					at,
					basis,
					Vector3(side * (2.9 + index * 0.85), 1.75, 5.2),
					Vector3(0.09, 1.5, 0.09),
					TIMBER
				)
			_put(
				world,
				"box",
				at,
				basis,
				Vector3(side * 5.1, 2.52, 5.2),
				Vector3(4.7, 0.14, 0.16),
				TIMBER
			)


static func _cableway(world, low: Vector3, high: Vector3) -> void:
	var direction := (high - low).normalized()
	var cross := direction.cross(Vector3.UP).normalized()
	var span := 16 if world.low_detail else 24
	for side in [-1.0, 1.0]:
		var offset: Vector3 = cross * side * 1.9
		for index in range(span):
			var a: Vector3 = _cable_point(low, high, float(index) / span) + offset
			var b: Vector3 = _cable_point(low, high, float(index + 1) / span) + offset
			world._beam(a, b, 0.07, FRAME)
	for fraction in [0.14, 0.60, 0.89]:
		var cable := _cable_point(low, high, fraction)
		var foot := Vector3(cable.x, GROUND.surface_height("winter_sprint"), cable.z)
		world._beam(foot, cable + Vector3.UP * 0.3, 0.44, ROCK_DARK)
		world._beam(cable - cross * 2.6, cable + cross * 2.6, 0.25, FRAME)
		for side in [-1.0, 1.0]:
			world._prop(
				"box", foot + cross * side * 0.8 + Vector3.UP * 0.22, Vector3(1.2, 0.44, 1.2), ROCK
			)


static func _cable_point(low: Vector3, high: Vector3, t: float) -> Vector3:
	return low.lerp(high, t) - Vector3.UP * sin(t * PI) * 2.2


static func _put(
	world,
	kind: String,
	at: Vector3,
	basis: Basis,
	local: Vector3,
	size: Vector3,
	color: Color,
	glow: bool = false
) -> void:
	world._prop(kind, at + basis * local, size, color, basis, glow)
