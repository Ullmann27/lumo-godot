extends RefCounted
## Instanced actual 3D landmarks; videos guide composition rather than replacing geometry.
const TRACKS = preload("res://scripts/games/kart_expansion_tracks.gd")
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const SKY = preload("res://scripts/games/kart_sky_islands.gd")


static func prepare(world) -> void:
	if world.track_id in ["candy_cloud", "volcano_night", "galaxy_ringway"]:
		world.loop_layout = {"start": world.length * 0.72, "lane": 2.9}
	if (
		world.track_id
		in ["crystal_canyon", "candy_cloud", "volcano_night", "winter_sprint", "galaxy_ringway"]
	):
		var start: float = world.length * (0.42 if world.track_id != "volcano_night" else 0.48)
		world.jump = {
			"ramp_start": start,
			"take_off": start + SKY.RAMP_LENGTH,
			"gap_end": start + SKY.RAMP_LENGTH + SKY.GAP_LENGTH,
			"height": SKY.RAMP_HEIGHT,
			"angle": atan2(SKY.RAMP_HEIGHT, SKY.RAMP_LENGTH)
		}


static func environment(world) -> void:
	var floating: bool = world.track_id in ["candy_cloud", "galaxy_ringway"]
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.position.y = -12 if floating else -2
	if world.track_id == "volcano_night":
		var lava := ShaderMaterial.new()
		lava.shader = preload("res://assets/shaders/kart_lava.gdshader")
		ground.material_override = lava
	elif world.track_id == "candy_cloud":
		var clouds := ShaderMaterial.new()
		clouds.shader = preload("res://assets/shaders/kart_cloud_sea.gdshader")
		ground.material_override = clouds
	else:
		ground.material_override = world._material(world.definition.ground)
	world.add_child(ground)
	for child in world.get_children():
		if child is WorldEnvironment:
			child.environment.fog_density = 0.0005
			child.environment.ambient_light_energy = (
				0.48 if world.track_id == "candy_cloud" else 0.32
			)
			child.environment.tonemap_exposure = 1.15
			if world.track_id == "galaxy_ringway":
				child.environment.fog_enabled = false
			if world.track_id in ["volcano_night", "galaxy_ringway"]:
				child.environment.fog_light_color = Color("14214d")
				child.environment.fog_light_energy = 0.25
				var night := ShaderMaterial.new()
				night.shader = preload("res://assets/shaders/kart_night_sky.gdshader")
				night.set_shader_parameter("zenith", Color("040b24"))
				night.set_shader_parameter("horizon", Color("14214d"))
				night.set_shader_parameter("glow", Color("283d69"))
				night.set_shader_parameter("below", Color("0c1838"))
				child.environment.sky.sky_material = night
				child.environment.ambient_light_energy = 0.25
	if world.track_id in ["volcano_night", "galaxy_ringway", "winter_sprint", "crystal_canyon"]:
		world._prop(
			"ball", Vector3(20, 92, -185), Vector3.ONE * 11, Color("cbdcff"), Basis.IDENTITY, true
		)


static func build(world) -> void:
	if not world.loop_layout.is_empty():
		LOOP.build(world, world.loop_layout, Color("ffc56f"))
	if not world.jump.is_empty():
		SKY.jump_dressing(world)
	var rng := RandomNumberGenerator.new()
	rng.seed = world.definition.seed
	# The landmarks repeat around the whole course, with a clear navigable roadway.
	var count: int = 32 if world.low_detail else 56
	for i in range(count):
		var d: float = (float(i) + 0.25) * world.length / count
		var basis: Basis = world.frame(d)
		var side: float = -1 if i % 2 == 0 else 1
		var at: Vector3 = world.position_at(d, side * rng.randf_range(15, 29))
		var angle := Basis(Vector3.UP, rng.randf_range(-PI, PI))
		match world.track_id:
			"crystal_canyon":
				world._prop("rock", at - Vector3.UP * 7, Vector3(8, 14, 10), Color("4f496e"), angle)
				for j in range(3):
					world._prop(
						"crystal",
						at + basis.x * (j - 1) * 2.4,
						Vector3(2.5, rng.randf_range(5, 10), 2.5),
						Color("b8a0ff") if j % 2 else Color("65d8f5"),
						angle,
						true
					)
			"jungle_temple":
				_palm(world, at, 6 + i % 4, basis)
				if i % 5 == 0:
					_temple(world, at + basis.x * side * 5, basis, Color("adb49b"))
				world._prop("crown", at + Vector3(4, 0, 2), Vector3(5, 1.7, 4), Color("3d8262"))
			"candy_cloud":
				world._prop("crown", at - Vector3.UP * 6, Vector3(12, 7, 9), Color("f0cbef"))
				if i % 3 == 0:
					_candy_castle(world, at, basis, Color("f4b9db") if i % 2 else Color("b5d8f8"))
				else:
					world._prop(
						"cylinder", at + Vector3.UP * 3.5, Vector3(0.28, 7, 0.28), Color("fbecdf")
					)
					world._prop(
						"torus",
						at + Vector3.UP * 8,
						Vector3.ONE * 6.5,
						Color("ecba78"),
						basis.rotated(basis.x, PI * 0.5)
					)
					world._prop(
						"torus",
						at + Vector3.UP * 8.1,
						Vector3(6.3, 0.78, 6.3),
						Color("f5a4d5"),
						basis.rotated(basis.x, PI * 0.5)
					)
					for j in range(5):
						world._prop(
							"ball",
							at + Vector3(sin(j) * 2.2, 8 + cos(j) * 2.2, 0),
							Vector3.ONE * 0.32,
							[Color("69d9f3"), Color("ffe085"), Color("d195fa")][j % 3]
						)
				if i % 4 == 0:
					_candy_cane(world, at + basis.x * 7, basis)
			"volcano_night":
				world._prop(
					"rock", at - Vector3.UP * 6, Vector3(10, 13, 12), Color("363546"), angle
				)
				world._prop(
					"rock",
					at + basis.x * side * 3,
					Vector3(3, 12 + i % 6, 3.2),
					Color("292c40"),
					angle
				)
				world._prop(
					"crystal",
					at + Vector3.UP * 2.5,
					Vector3(1.2, 3.0, 1.2),
					Color("ff7e3b"),
					angle,
					true
				)
			"winter_sprint":
				world._prop(
					"mountain", at - Vector3.UP * 7, Vector3(10, 15, 12), Color("d7eaf3"), angle
				)
				world._prop("fir", at + Vector3.UP * 2.5, Vector3(4, 8, 4), Color("8cadc4"))
				world._prop("fir", at + Vector3.UP * 3.5, Vector3(3.2, 6.5, 3.2), Color("eef5ff"))
				if i % 3 == 0:
					world._prop(
						"crystal",
						at + basis.x * 4,
						Vector3(1.7, 5, 1.7),
						Color("9bdffa"),
						angle,
						true
					)
			"galaxy_ringway":
				world._prop(
					"star",
					at + Vector3.UP * rng.randf_range(4, 22),
					Vector3.ONE * rng.randf_range(0.5, 1.8),
					Color("ffe6a1"),
					angle,
					true
				)
				if i % 5 == 0:
					var planet: Vector3 = at + Vector3.UP * 16
					world._prop(
						"ball",
						planet,
						Vector3.ONE * 8,
						Color("b598dd") if i % 2 else Color("62a3d4")
					)
					world._prop(
						"torus",
						planet,
						Vector3(24, 2, 24),
						Color("edbd91"),
						Basis(Vector3.FORWARD, 0.4),
						true
					)
			"desert_drift":
				world._prop(
					"mountain", at - Vector3.UP * 5, Vector3(18, 13, 14), Color("d6b27a"), angle
				)
				if i % 4 == 0:
					_palm(world, at, 7, basis)
				if i % 7 == 0:
					_temple(world, at + basis.x * side * 4, basis, Color("e7c88f"))
			"learning_lab":
				world._prop(
					"glass_tower", at - Vector3.UP * 3, Vector3(9, 20 + i % 9, 9), Color("508da3")
				)
				world._prop(
					"ball",
					at + Vector3.UP * 9,
					Vector3.ONE * 2.5,
					Color("83e8e3"),
					Basis.IDENTITY,
					true
				)
				for j in range(3):
					var end: Vector3 = (
						at + Vector3(sin(j * TAU / 3) * 4, 9 + cos(j * TAU / 3) * 4, 1)
					)
					world._beam(at + Vector3.UP * 9, end, 0.25, Color("d7f9ff"))
					world._prop(
						"ball",
						end,
						Vector3.ONE,
						[Color("84d2ff"), Color("bb9cf7"), Color("ffd190")][j]
					)
	for i in range(12):
		var d: float = (float(i) + 0.5) * world.length / 12
		var basis: Basis = world.frame(d)
		var color: Color = (
			Color("ffae52") if world.track_id == "volcano_night" else world.definition.accent
		)
		if world.track_id in ["volcano_night", "galaxy_ringway", "learning_lab"]:
			for side in [-1.0, 1.0]:
				var at: Vector3 = world.position_at(d, side * 2.5) + basis.y * 0.055
				world._prop(
					"box",
					at,
					Vector3(2.2, 0.04, 0.42),
					color,
					basis * Basis(Vector3.UP, side * 0.48),
					true
				)
	if world.track_id == "volcano_night":
		_volcano(world)
	if world.track_id == "crystal_canyon":
		world._snow_tunnel(
			world.length * 0.24,
			{
				"inner": Color("463957"),
				"outer": Color("776886"),
				"stripes": [Color("a594bc"), Color("71639a")],
				"boulder": Color("5b496b"),
				"lamp": Color("b9a0ff")
			}
		)
	if world.track_id in ["jungle_temple", "desert_drift"]:
		world._suspension_bridge(world.length * 0.30, 45)


static func _palm(world, at: Vector3, height: float, basis: Basis) -> void:
	world._prop(
		"cylinder",
		at + Vector3.UP * height * 0.4,
		Vector3(0.33, height, 0.33),
		Color("98755b"),
		basis
	)
	for j in range(6):
		var angle: float = j * TAU / 6
		var leaf_basis := Basis(Vector3.UP, angle).rotated(Vector3.FORWARD, 0.3)
		world._prop(
			"crown",
			at + Vector3(sin(angle) * 2, height * 0.94, cos(angle) * 2),
			Vector3(1.3, 0.55, 4.5),
			Color("57a776"),
			leaf_basis
		)


static func _temple(world, at: Vector3, basis: Basis, color: Color) -> void:
	for j in range(4):
		world._prop(
			"box",
			at + Vector3.UP * j * 1.2,
			Vector3(13 - j * 2, 1.2, 13 - j * 2),
			color.darkened(j * 0.06),
			basis
		)
	for side in [-1.0, 1.0]:
		world._prop(
			"cylinder",
			at + basis.x * side * 2.6 + Vector3.UP * 6,
			Vector3(0.6, 6, 0.6),
			color,
			basis
		)
	world._prop("box", at + Vector3.UP * 9, Vector3(7, 0.8, 4), color, basis)


static func _candy_castle(world, at: Vector3, basis: Basis, color: Color) -> void:
	world._prop("box", at + Vector3.UP * 3, Vector3(9, 6, 5), color, basis)
	for side in [-1.0, 1.0]:
		var foot: Vector3 = at + basis.x * side * 5
		world._prop("cylinder", foot + Vector3.UP * 4.5, Vector3(1.8, 9, 1.8), color, basis)
		world._prop("cone", foot + Vector3.UP * 10.5, Vector3(2.5, 4, 2.5), Color("f58fbe"), basis)
		world._prop(
			"ball",
			foot + Vector3.UP * 12.8,
			Vector3.ONE * 0.55,
			Color("ffdfad"),
			Basis.IDENTITY,
			true
		)
		world._prop(
			"box",
			foot + Vector3.UP * 5 + basis.z * 1.8,
			Vector3(0.5, 1.2, 0.05),
			Color("fff0c1"),
			basis,
			true
		)
	world._prop("roof", at + Vector3.UP * 7, Vector3(10, 3, 6), Color("c28be3"), basis)


static func _candy_cane(world, at: Vector3, basis: Basis) -> void:
	for j in range(10):
		world._prop(
			"cylinder",
			at + Vector3.UP * (j + 0.5),
			Vector3(0.35, 1, 0.35),
			Color("fa94be") if j % 2 else Color("fff0e0")
		)
	for j in range(9):
		var angle: float = j * PI / 8
		world._prop(
			"ball",
			at + basis.x * (1.5 + cos(angle) * 1.5) + Vector3.UP * (10 + sin(angle) * 1.5),
			Vector3.ONE * 0.36,
			Color("fa94be") if j % 2 else Color("fff0e0")
		)


static func _volcano(world) -> void:
	var at := Vector3(0, -8, -175)
	world._prop("volcano_mountain", at, Vector3(68, 90, 68), Color.WHITE)
	world._prop(
		"cone", at + Vector3.UP * 83, Vector3(12, 12, 12), Color("ff8a3e"), Basis.IDENTITY, true
	)
	world._prop(
		"torus", at + Vector3.UP * 87, Vector3(26, 3, 26), Color("ffbd57"), Basis.IDENTITY, true
	)
	for i in range(7):
		var angle: float = i * TAU / 7
		var heights := [0.0, 0.15, 0.34, 0.56, 0.77, 0.94, 1.0]
		var radii := [1.0, 0.93, 0.76, 0.56, 0.35, 0.20, 0.18]
		var previous := Vector3.ZERO
		for j in range(heights.size()):
			# Follow the actual basalt surface; a straight cone line sinks inside ridges.
			var ridge: float = 1.0 + sin(angle * 7 + 0.4) * 0.065 + sin(angle * 13 + j * 0.7) * 0.028
			var radius: float = radii[j] * ridge * 68.0 + 2.0
			var height: float = (heights[j] + (sin(angle * 7) * 0.012 if j > 0 else 0)) * 90.0
			var point := at + Vector3(sin(angle) * radius, height, cos(angle) * radius)
			if j > 0:
				world._beam(previous, point, 1.7 + float(6 - j) * 0.16, Color("ff792f"), true)
			previous = point
		world._prop(
			"ball",
			at + Vector3(sin(angle) * 15, 105 + i * 4, cos(angle) * 12),
			Vector3(12, 7, 9),
			Color("756278")
		)
	for i in range(9):
		var d: float = world.length * (0.10 + i * 0.09)
		var basis: Basis = world.frame(d)
		var top: Vector3 = world.position_at(d, 16) + Vector3.UP * 14
		world._beam(top, top - Vector3.UP * 24, 2, Color("ff8837"), true)
