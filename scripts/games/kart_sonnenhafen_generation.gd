extends RefCounted
## Visible generation leap for Sonnenhafen: a second Mediterranean town
## terrace, a promenade arcade, Ferris gondolas on the existing celestial
## wheel, palms, flowering planters and bay sails.
##
## Everything goes through the world's MultiMesh `_prop` batches except one
## HIGH-only GPUParticles3D node (no per-frame allocations). The race spline,
## checkpoints, physics and other tracks stay untouched.
## LOW builds the same world with fewer repeated pieces.

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
			var at := Vector3(
				proposed.x, world._ground_height(proposed.x, proposed.z), proposed.z
			)
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


static func _villa(world, at: Vector3, basis: Basis, facade: Color, roof: Color, index: int) -> void:
	var floors: int = 2 + (index % 3)
	var height: float = 3.4 * float(floors)
	var width: float = 7.4 + float(index % 2) * 1.6
	var depth: float = 5.6
	world._prop("box", at + Vector3.UP * (height * 0.5), Vector3(width, height, depth), facade, basis)
	world._prop("box", at + Vector3.UP * 0.22, Vector3(width + 0.35, 0.44, depth + 0.28), Color("cbb89a"), basis)
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
			var local := Vector3((float(column) - 1.0) * 2.05, 1.55 + float(floor_index) * 3.15, depth * 0.5 + 0.06)
			var window: Vector3 = at + basis * local
			world._prop("box", window, Vector3(1.15, 1.45, 0.16), CREAM, basis)
			world._prop("box", window + basis.z * 0.08, Vector3(0.92, 1.18, 0.06), Color("3d6f88"), basis)
	# Street balcony with flowering boxes, readable at racing speed.
	var balcony: Vector3 = at + basis * Vector3(0.0, 3.35, depth * 0.5 + 0.55)
	world._prop("box", balcony, Vector3(width * 0.82, 0.16, 1.15), CREAM, basis)
	for rail in range(7 if not world.low_detail else 4):
		var x: float = (float(rail) / float(6 if not world.low_detail else 3) - 0.5) * width * 0.75
		world._prop("box", balcony + basis * Vector3(x, 0.45, 0.48), Vector3(0.07, 0.85, 0.07), NAVY, basis)
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
		world._prop(
			"cone",
			tower + Vector3.UP * (height + 7.6),
			Vector3(2.4, 2.8, 2.4),
			roof
		)
		world._prop(
			"box",
			tower + Vector3.UP * (height + 5.6),
			Vector3(1.1, 1.2, 0.12),
			GLASS,
			basis,
			true
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
		world._prop("cylinder", at + basis * Vector3(3.4, 2.15, 0.0), Vector3(0.42, 4.3, 0.42), CREAM)
		world._prop(
			"box",
			at + basis * Vector3(1.7, 4.45, 0.0),
			Vector3(4.2, 0.38, 1.55),
			Color("d4723c"),
			basis
		)
		world._prop(
			"box",
			at + basis * Vector3(1.7, 3.85, 0.0),
			Vector3(3.4, 0.22, 0.22),
			TEAL,
			basis
		)
		if not world.low_detail:
			world._prop(
				"box",
				at + basis * Vector3(1.7, 2.4, 0.65),
				Vector3(2.6, 0.16, 0.85),
				WOOD,
				basis
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
			world._flower_patch(at + Vector3(1.6, 0.0, 0.8), FLOWER_A if i % 2 == 0 else FLOWER_B, 5)
		placed.append({"kind": "palm", "position": at, "fraction": fraction})
	return placed


static func _palm(world, at: Vector3, scale: float) -> void:
	world._prop("cylinder", at + Vector3.UP * (3.4 * scale), Vector3(0.28, 6.8, 0.28) * scale, TRUNK)
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
	world._prop("ball", at + Vector3.UP * (6.7 * scale), Vector3(0.55, 0.45, 0.55) * scale, Color("6b3d24"))


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
		world._prop("box", point + Vector3.DOWN * 2.35, Vector3(1.95, 0.16, 1.65), ROOFS[i % ROOFS.size()], basis)


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
		world._prop("box", at + basis * Vector3(0.0, 0.42, 0.4), Vector3(1.7, 0.16, 2.9), WOOD, basis)
		if sailing:
			world._prop("cylinder", at + basis * Vector3(0.0, 3.2, -0.45), Vector3(0.07, 5.9, 0.07), WHITE, basis)
			world._prop("sail", at + basis * Vector3(0.0, 0.85, -0.45), Vector3.ONE, WHITE, basis)
			world._prop("sail", at + basis * Vector3(0.04, 0.95, -0.62), Vector3(1.0, 0.78, -0.62), accent, basis)
		else:
			world._prop("box", at + basis * Vector3(0.0, 1.15, 0.25), Vector3(1.55, 1.2, 1.65), CREAM, basis)
			world._prop("box", at + basis * Vector3(0.0, 1.85, 0.25), Vector3(1.9, 0.16, 2.0), accent, basis)
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
