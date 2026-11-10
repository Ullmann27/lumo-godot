extends RefCounted
## Visible generation leap for Sonnenhafen: a second Mediterranean town
## terrace, a promenade arcade, Ferris gondolas on the existing celestial
## wheel, palms, flowering planters and bay sails, plus a race-camera
## Ferris wheel + lighthouse composition, harbour-front aquarium and
## boats with water reflections, start lights and finish-line fireworks.
##
## Static pieces use the world's spatial `_prop` batches. The harbor wheel
## uses two additional animated MultiMeshes; existing particles stay bounded.
## The race spline,
## checkpoints, physics and other tracks stay untouched.
## LOW builds the same world with fewer repeated pieces.

const SHOPFRONT = preload("res://scripts/games/kart_sonnenhafen_shopfront.gd")
const ATTRACTION = preload("res://scripts/games/kart_sonnenhafen_attraction.gd")

const FACADES: Array[Color] = [
	Color("f4c7a8"),
	Color("f7ecd0"),
	Color("7fb8b0"),
	Color("e89b8c"),
	Color("f0d48a"),
	Color("d9c4e0"),
	Color("f2b7c4"),
]
const ROOFS: Array[Color] = [
	Color("c14b32"),
	Color("b33b28"),
	Color("d4723c"),
	Color("a34a38"),
]
const CREAM := Color("f6edd8")
const TEAL := Color("3aa8a6")
const WOOD := Color("b9926b")
const PALM := Color("3f8f58")
const TRUNK := Color("8a6240")
const WHITE := Color("f4f1ea")
const NAVY := Color("1d3d58")
const GLASS := Color("5ec8d4")
const FLOWER_A := Color("e28bb8")
const FLOWER_B := Color("f0d56a")
const ROAD_CLEAR: float = 7.0
const TOWN_RADIUS: float = 6.8
# Stage for the race-camera Ferris wheel + lighthouse composition.
# Capture camera 03 uses the same numbers so before/after share a framing.
const WOW_DISTANCE: float = 95.0
const WOW_LATERAL: float = 42.0


static func build(world) -> void:
	if world.track_id != "sonnenhafen":
		return
	var before: int = world.decoration_count
	var heroes: Array = world.get_meta("sonnenhafen_hero_landmarks", [])
	var placed: Array[Dictionary] = []
	placed.append_array(_town_terraces(world, heroes))
	placed.append_array(_start_quarter(world, heroes))
	placed.append_array(_promenade_arcade(world, heroes))
	placed.append_array(_palms_and_flowers(world, heroes))
	_ferris_gondolas(world, heroes)
	placed.append_array(_bay_sails(world))
	placed.append_array(_wow_composition(world, heroes))
	placed.append_array(_harbor_front(world, heroes))
	_start_lights(world)
	_finish_fireworks(world)
	if not world.low_detail:
		_ambient_sparkles(world)
	world.set_meta("sonnenhafen_generation_sites", placed)
	world.set_meta("sonnenhafen_generation_parts", world.decoration_count - before)


static func _blocked(world, at: Vector3, radius: float, heroes: Array) -> bool:
	if world._near_road(at, radius + ROAD_CLEAR):
		return true
	if world._ground_height(at.x, at.z) < -0.35:
		return true
	for site in heroes:
		var centre: Vector3 = site["position"]
		if at.distance_to(centre) < float(site["radius"]) + radius + 2.0:
			return true
	return false


static func _start_quarter(world, heroes: Array) -> Array[Dictionary]:
	## Denser first 150 m so the opening race camera actually sees the town.
	var placed: Array[Dictionary] = []
	var count: int = 5 if world.low_detail else 8
	for i in range(count):
		var fraction: float = 0.006 + float(i) * 0.010
		var distance: float = world.length * fraction
		for side in [-1.0, 1.0]:
			var anchor := Vector3.INF
			for lateral in [18.5, 22.5]:
				var proposed: Vector3 = world.position_at(distance, side * lateral)
				var at := Vector3(
					proposed.x, world._ground_height(proposed.x, proposed.z), proposed.z
				)
				if not _blocked(world, at, TOWN_RADIUS, heroes):
					anchor = at
					break
			if not anchor.is_finite():
				continue
			var basis: Basis = world.frame(distance)
			var facade: Color = FACADES[(i + (0 if side < 0.0 else 3)) % FACADES.size()]
			var roof: Color = ROOFS[(i + (0 if side < 0.0 else 1)) % ROOFS.size()]
			_villa(world, anchor, basis, facade, roof, i + 3)
			if i < 3:
				SHOPFRONT.build(world, anchor, basis, 7.4 + float((i + 3) % 2) * 1.6, 5.6)
			placed.append({"kind": "villa", "position": anchor, "fraction": fraction})
	return placed


static func _town_terraces(world, heroes: Array) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	var count: int = 10 if world.low_detail else 16
	for i in range(count):
		var fraction: float = 0.07 + float(i) * (0.82 / float(count))
		var distance: float = world.length * fraction
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var anchor := Vector3.INF
		for lateral in [19.0, 24.0, 30.0, 36.0]:
			var proposed: Vector3 = world.position_at(distance, side * lateral)
			var at := Vector3(proposed.x, world._ground_height(proposed.x, proposed.z), proposed.z)
			if not _blocked(world, at, TOWN_RADIUS, heroes):
				anchor = at
				break
		if not anchor.is_finite():
			continue
		var basis: Basis = world.frame(distance)
		var facade: Color = FACADES[i % FACADES.size()]
		var roof: Color = ROOFS[i % ROOFS.size()]
		_villa(world, anchor, basis, facade, roof, i)
		placed.append({"kind": "villa", "position": anchor, "fraction": fraction})
	return placed


static func _villa(
	world, at: Vector3, basis: Basis, facade: Color, roof: Color, index: int
) -> void:
	var floors: int = 2 + (index % 3)
	var height: float = 3.4 * float(floors)
	var width: float = 7.4 + float(index % 2) * 1.6
	var depth: float = 5.6
	world._prop(
		"box", at + Vector3.UP * (height * 0.5), Vector3(width, height, depth), facade, basis
	)
	world._prop(
		"box",
		at + Vector3.UP * 0.22,
		Vector3(width + 0.35, 0.44, depth + 0.28),
		Color("cbb89a"),
		basis
	)
	world._prop(
		"roof",
		at + Vector3.UP * (height + 1.15),
		Vector3(width + 1.1, 2.5, depth + 1.0),
		roof,
		basis
	)
	world._prop(
		"box",
		at + Vector3.UP * (height + 0.08),
		Vector3(width + 0.55, 0.18, depth + 0.45),
		CREAM,
		basis
	)
	for floor_index in range(floors):
		for column in range(3):
			var local := Vector3(
				(float(column) - 1.0) * 2.05, 1.55 + float(floor_index) * 3.15, depth * 0.5 + 0.06
			)
			var window: Vector3 = at + basis * local
			world._prop("box", window, Vector3(1.15, 1.45, 0.16), CREAM, basis)
			world._prop(
				"box", window + basis.z * 0.08, Vector3(0.92, 1.18, 0.06), Color("3d6f88"), basis
			)
	# Street balcony with flowering boxes, readable at racing speed.
	var balcony: Vector3 = at + basis * Vector3(0.0, 3.35, depth * 0.5 + 0.55)
	world._prop("box", balcony, Vector3(width * 0.82, 0.16, 1.15), CREAM, basis)
	for rail in range(7 if not world.low_detail else 4):
		var x: float = (float(rail) / float(6 if not world.low_detail else 3) - 0.5) * width * 0.75
		world._prop(
			"box", balcony + basis * Vector3(x, 0.45, 0.48), Vector3(0.07, 0.85, 0.07), NAVY, basis
		)
	for blossom in range(5 if not world.low_detail else 3):
		var x: float = (float(blossom) - 2.0) * 0.85
		world._prop(
			"crown",
			balcony + basis * Vector3(x, 0.28, 0.15),
			Vector3(0.38, 0.26, 0.34),
			FLOWER_A if blossom % 2 == 0 else FLOWER_B
		)
	if index % 4 == 0:
		var tower: Vector3 = at + basis * Vector3(width * 0.28, 0.0, -depth * 0.12)
		world._prop(
			"cylinder",
			tower + Vector3.UP * (height + 3.4),
			Vector3(1.55, height + 6.8, 1.55),
			facade.lightened(0.06)
		)
		world._prop("cone", tower + Vector3.UP * (height + 7.6), Vector3(2.4, 2.8, 2.4), roof)
		world._prop(
			"box", tower + Vector3.UP * (height + 5.6), Vector3(1.1, 1.2, 0.12), GLASS, basis, true
		)


static func _promenade_arcade(world, heroes: Array) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	var bays: int = 6 if world.low_detail else 10
	for i in range(bays):
		var fraction: float = 0.035 + float(i) * 0.016
		var distance: float = world.length * fraction
		var proposed: Vector3 = world.position_at(distance, -17.5)
		var at := Vector3(proposed.x, world._ground_height(proposed.x, proposed.z), proposed.z)
		if _blocked(world, at, 3.2, heroes):
			proposed = world.position_at(distance, 17.5)
			at = Vector3(proposed.x, world._ground_height(proposed.x, proposed.z), proposed.z)
			if _blocked(world, at, 3.2, heroes):
				continue
		var basis: Basis = world.frame(distance)
		world._prop("cylinder", at + Vector3.UP * 2.15, Vector3(0.42, 4.3, 0.42), CREAM)
		world._prop(
			"cylinder", at + basis * Vector3(3.4, 2.15, 0.0), Vector3(0.42, 4.3, 0.42), CREAM
		)
		world._prop(
			"box",
			at + basis * Vector3(1.7, 4.45, 0.0),
			Vector3(4.2, 0.38, 1.55),
			Color("d4723c"),
			basis
		)
		world._prop(
			"box", at + basis * Vector3(1.7, 3.85, 0.0), Vector3(3.4, 0.22, 0.22), TEAL, basis
		)
		if not world.low_detail:
			world._prop(
				"box", at + basis * Vector3(1.7, 2.4, 0.65), Vector3(2.6, 0.16, 0.85), WOOD, basis
			)
		placed.append({"kind": "arcade", "position": at, "fraction": fraction})
	return placed


static func _palms_and_flowers(world, heroes: Array) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	var count: int = 8 if world.low_detail else 14
	for i in range(count):
		var fraction: float = 0.05 + float(i) * (0.78 / float(count))
		var distance: float = world.length * fraction
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var proposed: Vector3 = world.position_at(distance, side * 15.6)
		var at := Vector3(proposed.x, world._ground_height(proposed.x, proposed.z), proposed.z)
		if _blocked(world, at, 2.4, heroes):
			continue
		_palm(world, at, 1.0 + float(i % 3) * 0.18)
		if not world.low_detail:
			world._flower_patch(
				at + Vector3(1.6, 0.0, 0.8), FLOWER_A if i % 2 == 0 else FLOWER_B, 5
			)
		placed.append({"kind": "palm", "position": at, "fraction": fraction})
	return placed


static func _palm(world, at: Vector3, scale: float) -> void:
	world._prop(
		"cylinder", at + Vector3.UP * (3.4 * scale), Vector3(0.28, 6.8, 0.28) * scale, TRUNK
	)
	for i in range(5 if not world.low_detail else 4):
		var yaw: float = float(i) * TAU / 5.0
		var leaf_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.72)
		world._prop(
			"crown",
			at + Vector3.UP * (6.5 * scale) + leaf_basis.y * (1.15 * scale),
			Vector3(1.55, 0.28, 0.85) * scale,
			PALM if i % 2 == 0 else PALM.lightened(0.08),
			leaf_basis
		)
	world._prop(
		"ball", at + Vector3.UP * (6.7 * scale), Vector3(0.55, 0.45, 0.55) * scale, Color("6b3d24")
	)


static func _ferris_gondolas(world, heroes: Array) -> void:
	var site: Dictionary = {}
	for item in heroes:
		if str(item["kind"]) == "celestial_wheel":
			site = item
			break
	if site.is_empty():
		return
	var at: Vector3 = site["position"]
	var basis: Basis = world.frame(world.length * float(site["fraction"]))
	var centre: Vector3 = at + Vector3.UP * 23.0
	var count: int = 6 if world.low_detail else 8
	for i in range(count):
		var phi: float = TAU * float(i) / float(count)
		var point: Vector3 = centre + basis.x * (cos(phi) * 11.2) + Vector3.UP * (sin(phi) * 11.2)
		var cabin: Color = FACADES[i % FACADES.size()]
		world._beam(point, point + Vector3.DOWN * 0.55, 0.08, Color("5d8796"))
		world._prop("box", point + Vector3.DOWN * 1.45, Vector3(1.85, 1.9, 1.55), cabin, basis)
		world._prop(
			"box",
			point + Vector3.DOWN * 1.35 + basis.z * 0.72,
			Vector3(1.35, 1.05, 0.08),
			GLASS,
			basis
		)
		world._prop(
			"box",
			point + Vector3.DOWN * 2.35,
			Vector3(1.95, 0.16, 1.65),
			ROOFS[i % ROOFS.size()],
			basis
		)


static func _bay_sails(world) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	var candidates: Array[Vector3] = [
		Vector3(148.0, 0.0, 36.0),
		Vector3(162.0, 0.0, -28.0),
		Vector3(132.0, 0.0, -86.0),
		Vector3(-150.0, 0.0, 42.0),
		Vector3(78.0, 0.0, 168.0),
		Vector3(-92.0, 0.0, -172.0),
	]
	if world.low_detail:
		candidates = candidates.slice(0, 3)
	for i in range(candidates.size()):
		var raw: Vector3 = candidates[i]
		var at := Vector3(raw.x, -2.17, raw.z)
		if world._ground_height(at.x, at.z) > -1.6:
			continue
		if world._near_road(at, 16.0):
			continue
		var sailing: bool = i % 2 == 0
		var accent: Color = TEAL if sailing else WHITE
		var yaw: float = float(i) * 0.7
		var basis := Basis(Vector3.UP, yaw)
		world._prop("hull", at, Vector3(1.25, 0.9, 1.25), NAVY, basis)
		world._prop(
			"box", at + basis * Vector3(0.0, 0.42, 0.4), Vector3(1.7, 0.16, 2.9), WOOD, basis
		)
		if sailing:
			world._prop(
				"cylinder",
				at + basis * Vector3(0.0, 3.2, -0.45),
				Vector3(0.07, 5.9, 0.07),
				WHITE,
				basis
			)
			world._prop("sail", at + basis * Vector3(0.0, 0.85, -0.45), Vector3.ONE, WHITE, basis)
			world._prop(
				"sail",
				at + basis * Vector3(0.04, 0.95, -0.62),
				Vector3(1.0, 0.78, -0.62),
				accent,
				basis
			)
		else:
			world._prop(
				"box", at + basis * Vector3(0.0, 1.15, 0.25), Vector3(1.55, 1.2, 1.65), CREAM, basis
			)
			world._prop(
				"box", at + basis * Vector3(0.0, 1.85, 0.25), Vector3(1.9, 0.16, 2.0), accent, basis
			)
		placed.append({"kind": "bay_sail", "position": at, "fraction": -1.0})
	return placed


static func _ambient_sparkles(world) -> void:
	var dust := GPUParticles3D.new()
	dust.name = "SonnenhafenSeaSparkle"
	dust.amount = 48
	dust.lifetime = 4.0
	dust.preprocess = 2.0
	dust.visibility_aabb = AABB(Vector3(-220, -12, -220), Vector3(440, 90, 440))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(170, 10, 170)
	process.gravity = Vector3(0.0, 0.12, 0.0)
	process.initial_velocity_min = 0.08
	process.initial_velocity_max = 0.35
	process.scale_min = 0.07
	process.scale_max = 0.20
	process.color = Color("fff1c2")
	dust.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.22
	mesh.radial_segments = 8
	mesh.rings = 4
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.emission_enabled = true
	draw.emission = Color("ffe7a0")
	draw.emission_energy_multiplier = 2.0
	draw.albedo_color = Color("fff6d0")
	mesh.material = draw
	dust.draw_pass_1 = mesh
	world.add_child(dust)


static func _wow_composition(world, heroes: Array) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	var proposed: Vector3 = world.position_at(WOW_DISTANCE, WOW_LATERAL)
	var at := Vector3(proposed.x, world._ground_height(proposed.x, proposed.z), proposed.z)
	if _blocked(world, at, 12.0, heroes):
		var found := false
		for lateral in [38.0, 46.0, 50.0, 34.0]:
			for extra in [0.0, -10.0, 12.0]:
				proposed = world.position_at(WOW_DISTANCE + extra, lateral)
				at = Vector3(proposed.x, world._ground_height(proposed.x, proposed.z), proposed.z)
				if not _blocked(world, at, 12.0, heroes):
					found = true
					break
			if found:
				break
		if not found:
			return placed
	var basis: Basis = world.frame(WOW_DISTANCE)
	var water_dir: Vector3 = (
		world.position_at(WOW_DISTANCE, WOW_LATERAL + 12.0)
		- world.position_at(WOW_DISTANCE, WOW_LATERAL)
	)
	water_dir.y = 0.0
	if water_dir.length() > 0.001:
		water_dir = water_dir.normalized()
	else:
		water_dir = basis.x
	# Boardwalk and pier so the wheel and lighthouse sit as one harbour landmark.
	world._prop("box", at + Vector3.UP * 0.85, Vector3(20.0, 1.1, 14.0), Color("c4a074"), basis)
	world._prop(
		"box",
		at + water_dir * 9.0 + Vector3.UP * 0.55,
		Vector3(10.0, 0.7, 7.4),
		Color("8d6a48"),
		basis
	)
	if not world.low_detail:
		for i in range(4):
			var post: Vector3 = at + water_dir * (4.0 + float(i) * 2.4) + basis.z * 2.8
			world._prop(
				"cylinder", post + Vector3.UP * 1.1, Vector3(0.16, 2.2, 0.16), Color("5b4030")
			)
	var radius: float = 16.0
	var centre: Vector3 = at + Vector3.UP * (radius + 6.0)
	var upright: Basis = basis * Basis(Vector3.RIGHT, PI * 0.5)
	# Build the wheel rim from slender emissive beam segments. A heavily scaled
	# glowing torus reads as a solid yellow disc in the mobile/GL renderer.
	var rim_segments: int = 20 if world.low_detail else 32
	var previous_rim: Vector3 = centre + basis.x * radius
	for i in range(1, rim_segments + 1):
		var phi: float = TAU * float(i) / float(rim_segments)
		var rim_point: Vector3 = (
			centre + basis.x * (cos(phi) * radius) + Vector3.UP * (sin(phi) * radius)
		)
		world._beam(previous_rim, rim_point, 0.24, Color("f2d36b"), true)
		previous_rim = rim_point
	world._prop("ball", centre, Vector3(3.4, 3.4, 3.4), Color("60dce2"), Basis.IDENTITY, true)
	world._prop("cylinder", centre, Vector3(1.1, 3.8, 1.1), Color("5d8796"), upright)
	var attraction = ATTRACTION.new()
	world.add_child(attraction)
	attraction.configure(world, centre, basis, radius)
	for side in [-1.0, 1.0]:
		var foot: Vector3 = at + basis.x * side * 7.2 + Vector3.UP * 1.4
		world._beam(foot, centre, 0.55, Color("5d8796"))
		world._prop("cylinder", foot, Vector3(1.6, 1.1, 1.6), Color("263f56"))
	world._beam(at + Vector3.UP * 1.6 - water_dir * 4.0, centre, 0.48, Color("5d8796"))
	placed.append({"kind": "wow_wheel", "position": at, "fraction": WOW_DISTANCE / world.length})
	world.set_meta("sonnenhafen_wow_landmark", at)

	var light_at: Vector3 = at + water_dir * 15.0 + basis.z * 3.5
	light_at.y = world._ground_height(light_at.x, light_at.z)
	if _blocked(world, light_at, 4.5, heroes) and light_at.y >= -0.35:
		light_at = at + water_dir * 12.0
		light_at.y = world._ground_height(light_at.x, light_at.z)
	if light_at.y < 0.4:
		var floor_y: float = light_at.y
		world._prop(
			"cylinder",
			Vector3(light_at.x, (floor_y + 1.2) * 0.5, light_at.z),
			Vector3(6.2, max(1.6, 1.2 - floor_y), 6.2),
			Color("8a7355")
		)
		light_at.y = 1.2
	_wow_lighthouse(world, light_at)
	placed.append(
		{"kind": "wow_lighthouse", "position": light_at, "fraction": WOW_DISTANCE / world.length}
	)
	return placed


static func _wow_lighthouse(world, at: Vector3) -> void:
	world._prop("cylinder", at + Vector3.UP * 0.45, Vector3(5.1, 0.9, 5.1), Color("b7c4b3"))
	var bands: int = 6 if world.low_detail else 8
	for i in range(bands):
		var y: float = 1.3 + float(i) * 2.15
		var stripe: Color = Color("f4efe4") if i % 2 == 0 else Color("d14b3a")
		var width: float = 3.15 - float(i) * 0.08
		world._prop("cylinder", at + Vector3.UP * y, Vector3(width, 2.15, width), stripe)
	var lantern: Vector3 = at + Vector3.UP * (1.3 + float(bands) * 2.15 + 0.2)
	world._prop("cylinder", lantern + Vector3.UP * 0.2, Vector3(3.0, 0.4, 3.0), Color("36576c"))
	world._prop(
		"cylinder",
		lantern + Vector3.UP * 1.45,
		Vector3(2.15, 2.1, 2.15),
		Color("ffe7a0"),
		Basis.IDENTITY,
		true
	)
	world._prop("torus", lantern + Vector3.UP * 0.55, Vector3(5.0, 0.14, 5.0), Color("60dce2"))
	var posts: int = 6 if world.low_detail else 8
	for i in range(posts):
		var angle: float = float(i) * TAU / float(posts)
		world._prop(
			"cylinder",
			lantern + Vector3(cos(angle) * 1.35, 1.35, sin(angle) * 1.35),
			Vector3(0.12, 2.0, 0.12),
			Color("36576c")
		)
	world._prop("roof", lantern + Vector3.UP * 2.85, Vector3(4.4, 1.8, 4.4), Color("466c89"))
	world._prop(
		"ball",
		lantern + Vector3.UP * 4.05,
		Vector3(1.15, 1.15, 1.15),
		Color("fff4b0"),
		Basis.IDENTITY,
		true
	)


static func _harbor_front(world, heroes: Array) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	# Glass aquarium pavilion on the water side, closer to the race camera.
	var proposed: Vector3 = world.position_at(58.0, 36.0)
	var at := Vector3(proposed.x, world._ground_height(proposed.x, proposed.z), proposed.z)
	if not _blocked(world, at, 7.0, heroes):
		var basis: Basis = world.frame(58.0)
		world._prop("cylinder", at + Vector3.UP * 1.1, Vector3(11.4, 2.2, 11.4), Color("d9c4a0"))
		world._prop("cylinder", at + Vector3.UP * 2.35, Vector3(10.2, 0.35, 10.2), TEAL)
		world._prop(
			"ball",
			at + Vector3.UP * 6.4,
			Vector3(10.5, 8.4, 10.5),
			Color("7fe0ea"),
			Basis.IDENTITY,
			true
		)
		if not world.low_detail:
			world._prop(
				"torus",
				at + Vector3.UP * 3.4,
				Vector3(14.0, 0.22, 14.0),
				Color("60dce2"),
				Basis.IDENTITY,
				true
			)
			world._prop(
				"box",
				at + basis * Vector3(0.0, 2.6, 5.6),
				Vector3(4.2, 3.4, 0.18),
				GLASS,
				basis,
				true
			)
		world._prop(
			"box",
			at + basis * Vector3(0.0, 1.6, 6.2),
			Vector3(4.8, 3.1, 1.4),
			Color("f4efe4"),
			basis
		)
		placed.append({"kind": "harbor_aquarium", "position": at, "fraction": 58.0 / world.length})
	var slips: Array[Vector2] = [
		Vector2(70.0, 58.0),
		Vector2(88.0, 64.0),
		Vector2(108.0, 56.0),
		Vector2(52.0, 54.0),
		Vector2(124.0, 66.0),
		Vector2(96.0, 72.0),
	]
	if world.low_detail:
		slips = slips.slice(0, 3)
	for i in range(slips.size()):
		var slip: Vector2 = slips[i]
		var raw: Vector3 = world.position_at(slip.x, slip.y)
		var deck := Vector3(raw.x, -2.17, raw.z)
		if world._ground_height(deck.x, deck.z) > -1.6:
			continue
		if world._near_road(deck, 16.0):
			continue
		var yaw: float = float(i) * 0.55 + 0.4
		var basis := Basis(Vector3.UP, yaw)
		_harbor_boat(world, deck, basis, i % 2 == 0, FACADES[i % FACADES.size()])
		placed.append({"kind": "harbor_boat", "position": deck, "fraction": slip.x / world.length})
	return placed


static func _harbor_boat(world, at: Vector3, basis: Basis, sailing: bool, accent: Color) -> void:
	world._prop("hull", at, Vector3(1.35, 0.95, 1.35), NAVY, basis)
	world._prop(
		"box", at + basis * Vector3(0.0, 0.46, 0.35), Vector3(1.85, 0.18, 3.15), WOOD, basis
	)
	if sailing:
		world._prop(
			"cylinder", at + basis * Vector3(0.0, 3.4, -0.4), Vector3(0.08, 6.2, 0.08), WHITE, basis
		)
		world._prop("sail", at + basis * Vector3(0.0, 0.9, -0.4), Vector3.ONE, WHITE, basis)
		world._prop(
			"sail", at + basis * Vector3(0.05, 1.0, -0.58), Vector3(1.0, 0.8, -0.6), accent, basis
		)
	else:
		world._prop(
			"box", at + basis * Vector3(0.0, 1.2, 0.2), Vector3(1.65, 1.25, 1.75), CREAM, basis
		)
		world._prop(
			"box", at + basis * Vector3(0.0, 1.9, 0.2), Vector3(2.0, 0.16, 2.15), accent, basis
		)
	# Mirrored stand-ins so the water reads as reflective under llvmpipe.
	var water_y: float = -2.35
	var reflected := Vector3(at.x, 2.0 * water_y - at.y, at.z)
	var shade: Color = NAVY.darkened(0.22)
	world._prop("hull", reflected, Vector3(1.3, 0.85, 1.3), shade, basis)
	world._prop(
		"box",
		reflected + basis * Vector3(0.0, -0.4, 0.35),
		Vector3(1.75, 0.14, 3.0),
		WOOD.darkened(0.3),
		basis
	)


static func _start_lights(world) -> void:
	# Keep the start gantry above the kart sightline instead of dominating the
	# race camera. The crossbar sits just over four metres above the road.
	var distance: float = 27.0
	var basis: Basis = world.frame(distance)
	var mid: Vector3 = world.position_at(distance, 0.0)
	mid.y = world._ground_height(mid.x, mid.z)
	for side in [-1.0, 1.0]:
		var foot: Vector3 = world.position_at(distance, side * 7.3)
		foot.y = world._ground_height(foot.x, foot.z)
		world._prop("cylinder", foot + Vector3.UP * 2.1, Vector3(0.30, 4.2, 0.30), Color("2b2d38"))
		world._prop("cylinder", foot + Vector3.UP * 0.3, Vector3(0.72, 0.6, 0.72), Color("1a1c24"))
	world._prop("box", mid + Vector3.UP * 4.25, Vector3(15.4, 0.34, 0.52), Color("2b2d38"), basis)
	world._prop("box", mid + Vector3.UP * 4.65, Vector3(8.8, 0.72, 0.46), Color("1a1c24"), basis)
	var count: int = 3 if world.low_detail else 5
	for i in range(count):
		var x: float = (float(i) - float(count - 1) * 0.5) * 1.35
		var lamp: Vector3 = mid + basis.x * x + Vector3.UP * 4.55
		world._prop("cylinder", lamp, Vector3(0.48, 0.58, 0.48), Color("3a1216"), basis)
		world._prop(
			"ball",
			lamp + Vector3.DOWN * 0.10,
			Vector3(0.54, 0.54, 0.54),
			Color("ff3b3b"),
			Basis.IDENTITY,
			true
		)


static func _finish_fireworks(world) -> void:
	var at: Vector3 = world.position_at(0.0, 0.0) + Vector3.UP * 7.5
	_firework_emitter(
		world, at, "SonnenhafenFinishFireworks", Color("ffd27a"), 28 if world.low_detail else 64
	)
	if not world.low_detail:
		_firework_emitter(
			world,
			at + Vector3(3.5, 1.0, -2.0),
			"SonnenhafenFinishFireworksMagenta",
			Color("ff7ad8"),
			40
		)


static func _firework_emitter(
	world, at: Vector3, node_name: String, color: Color, amount: int
) -> void:
	var dust := GPUParticles3D.new()
	dust.name = node_name
	dust.position = at
	dust.amount = amount
	dust.lifetime = 2.2
	dust.preprocess = 1.4
	dust.explosiveness = 0.88
	dust.randomness = 0.35
	dust.visibility_aabb = AABB(Vector3(-70, -8, -70), Vector3(140, 110, 140))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 2.4
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 58.0
	process.initial_velocity_min = 9.0
	process.initial_velocity_max = 20.0
	process.gravity = Vector3(0.0, -8.5, 0.0)
	process.scale_min = 0.14
	process.scale_max = 0.42
	process.color = color
	dust.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	mesh.radial_segments = 8
	mesh.rings = 4
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.emission_enabled = true
	draw.emission = color
	draw.emission_energy_multiplier = 3.2
	draw.albedo_color = color
	mesh.material = draw
	dust.draw_pass_1 = mesh
	world.add_child(dust)
