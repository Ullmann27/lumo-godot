extends RefCounted
## Vulkanexpress – Wahrzeichen und Bauwerke entlang der Fahrbahn (aus vulkan_environment.gd
## aufgerufen): Steinbrücke über den Lavastrom, Hängebrücke über den Glutcanyon, Felsentunnel,
## Vulkanhöhle mit Lavafällen, Kristallgarten, Böschungen, Starttor, Fackeln und Palmen.
## Alle Maße kommen aus vulkan_course.gd; Modelle aus tools/lumo_signature_art/.
const DIR: String = "res://assets/kart/signature/vulkanexpress/"
const LAVA_SHADER = preload("res://assets/shaders/signature/signature_lava_flow.gdshader")
const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const WIND: Vector3 = Vector3(3.2, 0.0, 1.1)


static func build(env) -> void:
	stone_bridge(env)
	suspension_bridge(env)
	felsentunnel(env)
	crystal_garden(env)
	cave(env)
	roadside(env)


# ------------------------------------------------------------------ Brücken


static func stone_bridge(env) -> void:
	var crossing: float = float(env.course.LAVA_RIVER)
	var at: Vector3 = env.world.position_at(crossing)
	var arch: Node3D = env.place(DIR + "stone_arch.glb", crossing, 0.0, 1.0, 90.0, at.y - 0.35)
	arch.scale = Vector3(1.25, 1.0, 1.0)
	for d in range(318, 362, 4):
		var basis: Basis = env.world.frame(d)
		for side in [-1.0, 1.0]:
			var p: Vector3 = env.world.position_at(
				d, side * (env.world.road_width_at(d) * 0.5 + 0.3)
			)
			env.world._prop(
				"box", p + basis.y * 0.55, Vector3(0.7, 1.1, 4.1), Color("8a7b6e"), basis
			)
			if d % 8 == 2:
				env.world._prop(
					"box", p + basis.y * 1.35, Vector3(0.3, 0.5, 0.3), Color("ffc773"), basis, true
				)


static func suspension_bridge(env) -> void:
	var a: float = env.course.BRIDGE.x
	var b: float = env.course.BRIDGE.y
	for at in [a - 2.0, b + 2.0]:
		env.place(DIR + "bridge_tower.glb", at, 0.0, 1.0, 0.0, env.world.position_at(at).y - 0.4)
	# Tragseile hängen als Kettenlinie zwischen den Turmköpfen (12 m über dem Deck).
	for side in [-1.0, 1.0]:
		var previous := Vector3.ZERO
		var steps: int = 24
		for i in range(steps + 1):
			var u: float = float(i) / float(steps)
			var d: float = lerpf(a - 2.0, b + 2.0, u)
			var basis: Basis = env.world.frame(d)
			var sag: float = 12.0 - 10.6 * (1.0 - pow(2.0 * u - 1.0, 2.0))
			var deck: Vector3 = env.world.position_at(d, side * 7.4)
			var cable: Vector3 = deck + basis.y * sag
			if i > 0:
				env.world._beam(previous, cable, 0.22, Color("6b4a33"))
				env.world._beam(deck + basis.y * 0.9, cable, 0.06, Color("c9a56b"))
			previous = cable
		# Handlauf aus Seil und Pfosten.
		for d in range(int(a), int(b), 3):
			var basis: Basis = env.world.frame(d)
			var p: Vector3 = env.world.position_at(d, side * 6.3)
			env.world._prop(
				"box", p + basis.y * 0.6, Vector3(0.16, 1.2, 0.16), Color("8c5a36"), basis
			)
	var under: ArrayMesh = env.ribbon(a, b, -6.4, 6.4, -0.45, 2.0)
	env.mesh_node("Brueckenunterseite", under, env.material(Color("5a3a24"), 0.85), 0.0)
	var glow: MultiMeshInstance3D = env.puffs(
		"Canyonglut",
		[Vector4(730, 3.5, -437, 18.0)],
		30,
		Color(1.0, 0.5, 0.2, 1.0),
		2.2,
		22.0,
		0.25,
		true,
		Vector3(0.4, 0, 0)
	)
	glow.material_override.set_shader_parameter("intensity", 0.8)


# ------------------------------------------------------------------ Tunnel und Höhle


## Gewölbe über der Fahrbahn: Wände bis wall_top, dann Bogen bis ceiling (Innen sichtbar).
static func felsentunnel(env) -> void:
	var tunnel: Dictionary = env.course.TUNNELS[0]
	var a: float = float(tunnel.start)
	var b: float = float(tunnel.end)
	env.vault(a, b, float(tunnel.ceiling), 0.6, 0.35, Color("4a3c3a"))
	for at in [a, b]:
		env.place(
			DIR + "tunnel_portal.glb",
			at,
			0.0,
			1.0,
			0.0 if at == a else 180.0,
			env.world.position_at(at).y - 0.5
		)
	# Glühende Kristalle an den Wänden, abwechselnd links und rechts alle 11 m.
	var d: float = a + 6.0
	var flip: float = 1.0
	while d < b - 4.0:
		var basis: Basis = env.world.frame(d)
		var p: Vector3 = env.world.position_at(d, flip * (env.world.road_width_at(d) * 0.5 + 0.2))
		env.world._prop(
			"crystal",
			p + basis.y * 3.2,
			Vector3(0.9, 2.4, 0.9),
			Color("ff9a4d"),
			basis.rotated(basis.z, flip * 0.5),
			true
		)
		if not env.low() and flip > 0.0:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color("ffa860")
			lamp.light_energy = 1.6
			lamp.omni_range = 16.0
			lamp.position = p + basis.y * 4.0 - basis.x * 1.2
			env.add_child(lamp)
		d += 11.0
		flip = -flip


static func cave(env) -> void:
	var tunnel: Dictionary = env.course.TUNNELS[1]
	var a: float = float(tunnel.start)
	var b: float = float(tunnel.end)
	env.vault(a, b, float(tunnel.ceiling), 2.2, 0.9, Color("3a2e30"))
	for at in [a, b]:
		var portal: Node3D = env.place(
			DIR + "tunnel_portal.glb",
			at,
			0.0,
			1.35,
			0.0 if at == a else 180.0,
			env.world.position_at(at).y - 0.5
		)
		portal.name = "Hoehlenportal_%d" % roundi(at)
	# Trennwand aus Basaltsäulen zwischen Lavafall-Galerie (links) und breitem Weg.
	var split: Dictionary = env.course.SPLITS[1]
	var d: float = float(split.start) + 4.0
	while d < float(split.end) - 3.0:
		env.place(DIR + "basalt_columns.glb", d, float(split.lateral), 0.62, d * 13.0, NAN, 0.8)
		d += 6.0
	# Lavafälle an der linken Höhlenwand, unten eine Lavarinne hinter dem Randstein.
	var gutter: ArrayMesh = env.ribbon(
		a + 8.0,
		b - 8.0,
		-env.world.road_width_at(2000) * 0.5 - 1.6,
		-env.world.road_width_at(2000) * 0.5 - 0.3,
		-0.4,
		3.0
	)
	env.mesh_node("Lavarinne", gutter, env.lava_material, 0.0, false)
	var fall_material: ShaderMaterial = env.shader_material(
		LAVA_SHADER, {"half_width": 2.0, "speed": -2.4, "glow": 3.0}
	)
	for at in [1964.0, 2008.0, 2052.0]:
		var basis: Basis = env.world.frame(at)
		var foot: Vector3 = env.world.position_at(at, -env.world.road_width_at(at) * 0.5 - 1.0)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in range(2):
			for k in range(2):
				var lateral: Vector3 = -basis.z * (float(k) * 4.0 - 2.0)
				surface.set_uv(Vector2(float(k) * 4.0 - 2.0, float(row) * 14.0))
				surface.set_normal(basis.x)
				surface.add_vertex(
					foot + lateral + basis.y * (float(row) * 14.0 - 0.4) - basis.x * 0.4
				)
		for index in [0, 2, 1, 1, 2, 3]:
			surface.add_index(index)
		env.mesh_node("Lavafall_%d" % roundi(at), surface.commit(), fall_material, 0.0, false)
		var light := OmniLight3D.new()
		light.light_color = Color("ff7a2a")
		light.light_energy = 2.4
		light.omni_range = 22.0
		light.position = foot + basis.y * 5.0 + basis.x * 3.0
		env.add_child(light)
	env.puffs(
		"Hoehlenglut",
		[
			Vector4(
				env.world.position_at(2008, -12).x,
				env.world.position_at(2008).y,
				env.world.position_at(2008, -12).z,
				30.0
			)
		],
		20,
		Color(1, 0.55, 0.2, 1),
		0.5,
		10.0,
		0.3,
		true,
		Vector3.ZERO,
		0.0
	)
	for at in [1940.0, 1990.0, 2040.0, 2075.0]:
		env.place(
			DIR + "crystal_cluster.glb",
			at,
			env.world.road_width_at(at) * 0.5 + 1.0,
			0.7,
			at,
			NAN,
			0.8
		)


# ------------------------------------------------------------------ Kristallgarten


static func crystal_garden(env) -> void:
	var split: Dictionary = env.course.SPLITS[0]
	var d: float = float(split.start) + 3.0
	while d < float(split.end) - 2.0:
		env.place(DIR + "crystal_cluster.glb", d, float(split.lateral), 0.58, d * 7.0, NAN, 0.9)
		d += 6.5
	for at in [1120.0, 1150.0, 1185.0, 1225.0, 1262.0, 1295.0]:
		for side in [-1.0, 1.0]:
			var lateral: float = side * (env.world.road_width_at(at) * 0.5 + 6.0 + fposmod(at, 7.0))
			var foot: Vector3 = env.world.position_at(at, lateral)
			env.place(
				DIR + "crystal_cluster.glb",
				at,
				lateral,
				1.4 + fposmod(at * 0.13, 0.8),
				at * 3.0,
				env._ground(foot.x, foot.z) - 0.4
			)


# ------------------------------------------------------------------ Am Straßenrand


## Böschung unter den Fahrbahnkanten (Basalt): die Straße steht nie in der Luft.
static func roadside(env) -> void:
	env.skirts(
		Color("332b2c"),
		func(d: float) -> bool:
			return (
				env._tunnel_at(d) == null
				and not (d > env.course.BRIDGE.x - 1.0 and d < env.course.BRIDGE.y + 1.0)
			)
	)
	# Starttor mit Streckennamen über der Startlinie.
	var gate: Node3D = env.place(
		DIR + "bridge_tower.glb", -8.0, 0.0, 1.2, 0.0, env.world.position_at(-8.0).y - 0.3
	)
	gate.name = "Starttor"
	var title := Label3D.new()
	title.name = "Streckenname"
	title.font = FONT
	title.font_size = 96
	title.pixel_size = 0.013
	title.text = "VULKANEXPRESS"
	title.modulate = Color("ffd59a")
	title.outline_size = 14
	title.outline_modulate = Color("3a1410")
	title.position = Vector3(0.0, 12.4, 0.7)
	title.visibility_range_end = 220.0
	gate.add_child(title)
	# Randsteine aus Basalt mit Glutaugen: Fahrbahnkante überall klar erkennbar.
	var d: float = 2.0
	while d < float(env.world.length):
		var skip: bool = (
			env._tunnel_at(d) != null
			or (d > env.course.BRIDGE.x - 2.0 and d < env.course.BRIDGE.y + 2.0)
			or (d > 316.0 and d < 364.0)
		)
		if not skip:
			var basis: Basis = env.world.frame(d)
			for side in [-1.0, 1.0]:
				var p: Vector3 = env.world.position_at(
					d, side * (env.world.road_width_at(d) * 0.5 + 0.35)
				)
				env.world._prop(
					"box", p + basis.y * 0.32, Vector3(0.7, 0.8, 5.4), Color("2e2729"), basis
				)
				if int(d) % 18 == 2:
					env.world._prop(
						"box",
						p + basis.y * 0.78 - basis.x * side * 0.36,
						Vector3(0.12, 0.18, 0.5),
						Color("ff8a3a"),
						basis,
						true
					)
		d += 6.0
	# Lavabrocken, Fackeln und Dampfritzen entlang der Strecke.
	var vents: Array = []
	for at in range(140, int(env.world.length) - 60, 37):
		var a: float = float(at)
		if env._tunnel_at(a) != null or (a > 840.0 and a < 1000.0):
			continue
		var side: float = 1.0 if (at / 37) % 2 == 0 else -1.0
		var lateral: float = (
			side * (env.world.road_width_at(a) * 0.5 + 5.0 + fposmod(a * 0.37, 9.0))
		)
		var foot: Vector3 = env.world.position_at(a, lateral)
		var ground: float = env._ground(foot.x, foot.z)
		env.world._prop(
			"rock",
			Vector3(foot.x, ground + 0.6, foot.z),
			Vector3(3.0, 2.2, 2.6) * (0.7 + fposmod(a, 1.3)),
			Color("3a3034"),
			Basis(Vector3.UP, a)
		)
		if at % 3 == 0:
			vents.append(Vector4(foot.x + 2.0, ground + 0.3, foot.z, 0.6))
		if at % 2 == 0:
			var torch: Vector3 = env.world.position_at(
				a, -side * (env.world.road_width_at(a) * 0.5 + 1.4)
			)
			env.world._prop(
				"box", torch + Vector3.UP * 1.0, Vector3(0.25, 2.0, 0.25), Color("4a3a30")
			)
			env.world._prop(
				"ball",
				torch + Vector3.UP * 2.2,
				Vector3(0.45, 0.6, 0.45),
				Color("ffb050"),
				Basis.IDENTITY,
				true
			)
	env.puffs("Dampfritzen", vents, 6, Color(0.92, 0.9, 0.88, 0.4), 2.2, 9.0, 0.3, false, WIND)
	# Palmen am schwarzen Strand.
	for at in [2860.0, 2920.0, 3060.0, 3120.0, 40.0, 110.0, 180.0]:
		for k in range(2):
			var lateral: float = -(env.world.road_width_at(at) * 0.5 + 8.0 + float(k) * 9.0)
			var foot: Vector3 = env.world.position_at(at + float(k) * 13.0, lateral)
			palm(env, Vector3(foot.x, env._ground(foot.x, foot.z) - 0.2, foot.z), at + float(k))


static func palm(env, foot: Vector3, seed_value: float) -> void:
	var lean := Vector3(sin(seed_value) * 1.6, 9.0, cos(seed_value) * 1.6)
	env.world._beam(foot, foot + lean * 0.5, 0.55, Color("7b5a3c"))
	env.world._beam(foot + lean * 0.5, foot + lean, 0.45, Color("86643f"))
	for k in range(6):
		var a: float = float(k) / 6.0 * TAU + seed_value
		var tip: Vector3 = foot + lean + Vector3(cos(a) * 4.2, -1.6, sin(a) * 4.2)
		env.world._beam(foot + lean, tip, 0.9, Color("4f8f3e"))
