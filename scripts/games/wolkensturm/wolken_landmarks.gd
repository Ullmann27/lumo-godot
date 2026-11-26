extends RefCounted
## Wolkensturm – Bauwerke entlang der Fahrbahn (aus wolken_environment.gd aufgerufen):
## schwebende Inseln, Skyway-Deck mit Glasgeländer und Stützen, Hochhäuser zwischen den
## Wolken, Sternenturm in der Spirale, Glastunnel durch den Atrium-Turm, Holobrücke mit
## schwebenden Plattformen, Windkanal mit Windrädern und sichtbarem Wind, Skyway-Gabel mit
## Lobby-Halle und Starttor. Maße aus wolken_course.gd, Modelle aus tools/lumo_signature_art/.
const DIR: String = "res://assets/kart/signature/wolkensturm/"
const WINDOWS = preload("res://assets/shaders/signature/signature_windows.gdshader")
const STREAKS = preload("res://assets/shaders/signature/signature_streaks.gdshader")
const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
## Inseln unter der Fahrbahn: [Streckenmeter, Querlage, Größe].
const ISLANDS: Array = [[60.0, 4.0, 1.25], [2366.0, -2.0, 1.0], [3170.0, 10.0, 1.1]]
const TOWER_COUNT: Dictionary = {"low": 26, "medium": 46, "high": 66}


static func build(env) -> void:
	islands(env)
	skyway(env)
	towers(env)
	star_tower(env)
	glass_tunnel(env)
	holo_bridge(env)
	windkanal(env)
	gabel(env)
	start_gate(env)


static func _island_at(env, d: float) -> bool:
	for island in ISLANDS:
		if (
			absf(
				(
					fposmod(d - float(island[0]) + env.world.length * 0.5, env.world.length)
					- env.world.length * 0.5
				)
			)
			< 42.0 * float(island[2])
		):
			return true
	return absf(d - (float(env.course.HELIX.x) + float(env.course.HELIX.y)) * 0.5) < 190.0


static func islands(env) -> void:
	for island in ISLANDS:
		var d: float = float(island[0])
		var size: float = float(island[2])
		# Grasdecke des Felsens (lokal bis 1,4 m) bleibt 1 m unter der Fahrbahn.
		var top: float = env.world.position_at(d).y - 1.0 - 1.4 * size
		env.place(DIR + "island_rock.glb", d, float(island[1]), size, d, top, 2.0)
	# Ferne Inseln im Wolkenmeer.
	for i in range(7):
		var d: float = float(i) * env.world.length / 7.0 + 230.0
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var at: Vector3 = env.world.position_at(d, side * (150.0 + float(i % 3) * 40.0))
		var rock: Node3D = env.module(DIR + "island_rock.glb", 3.0)
		rock.position = Vector3(
			at.x, float(env.course.CLOUD_DECK) + 10.0 + float(i % 4) * 9.0, at.z
		)
		rock.scale = Vector3.ONE * (0.6 + float(i % 3) * 0.25)
		env.add_child(rock)


## Deck unter der Fahrbahn, Glasgeländer mit Leuchtkante, Stützen hinab in die Wolken.
static func skyway(env) -> void:
	var world = env.world
	var holo: Vector2 = env.course.HOLO_BRIDGE
	var tunnel: Dictionary = env.course.TUNNELS[0]
	var steel: StandardMaterial3D = env.material(Color("3b465e"), 0.45, 0.6)
	var segments: Array = [Vector2(0.0, holo.x), Vector2(holo.y, world.length)]
	for span in segments:
		env.mesh_node("SkywayDeck_%d" % int(span.x), _deck(env, span.x, span.y), steel, 0.0, false)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.62, 0.88, 1.0, 0.22)
	glass.roughness = 0.05
	glass.metallic = 0.3
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1.0, 1.0]:
		var rail: ArrayMesh = _rail(env, side, float(tunnel.start), float(tunnel.end))
		var node: MeshInstance3D = env.mesh_node(
			"Glasgelaender%d" % int(side), rail, glass, 0.0, false
		)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var d: float = 0.0
	while d < world.length:
		var inside: bool = d > float(tunnel.start) and d < float(tunnel.end)
		var basis: Basis = world.frame(d)
		for side in [-1.0, 1.0]:
			var top: Vector3 = world.position_at(d, side * (world.road_width_at(d) * 0.5 + 0.1))
			if not inside:
				var neon: Color = Color("5ff0ff") if side > 0.0 else Color("ff4fd8")
				world._prop(
					"box", top + basis.y * 1.25, Vector3(0.14, 0.12, 4.2), neon, basis, true
				)
		d += 4.0
	# Stützen aus Stahl mit Leuchtring, wo keine Insel trägt.
	d = 30.0
	while d < world.length:
		if not _island_at(env, d) and (d < holo.x - 10.0 or d > holo.y + 10.0):
			var basis: Basis = world.frame(d)
			var under: Vector3 = world.position_at(d) - basis.y * 0.6
			var foot := Vector3(under.x, float(env.course.CLOUD_DECK) - 12.0, under.z)
			world._beam(foot, under, 2.0, Color("4a5672"))
			world._prop(
				"cylinder",
				(foot + under) * 0.5 + Vector3.UP * 4.0,
				Vector3(2.8, 0.6, 2.8),
				Color("5ff0ff"),
				Basis.IDENTITY,
				true
			)
		d += 85.0


static func _deck(env, from: float, to: float) -> ArrayMesh:
	var world = env.world
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = 0
	var d: float = from
	while d <= to:
		var basis: Basis = world.frame(d)
		var half: float = world.road_width_at(d) * 0.5
		var corners: Array = [
			world.position_at(d, -half) - basis.y * 0.02,
			world.position_at(d, -half + 1.0) - basis.y * 1.4,
			world.position_at(d, half - 1.0) - basis.y * 1.4,
			world.position_at(d, half) - basis.y * 0.02,
		]
		for p in corners:
			surface.set_normal(-basis.y)
			surface.add_vertex(p)
		if rows > 0:
			for k in range(3):
				var a: int = (rows - 1) * 4 + k
				for index in [a, a + 4, a + 1, a + 1, a + 4, a + 5]:
					surface.add_index(index)
		rows += 1
		d += 3.0
	return surface.commit()


static func _rail(env, side: float, gap_from: float, gap_to: float) -> ArrayMesh:
	var world = env.world
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = 0
	var d: float = 0.0
	while d <= world.length:
		var basis: Basis = world.frame(d)
		var edge: Vector3 = world.position_at(d, side * (world.road_width_at(d) * 0.5 + 0.1))
		var height: float = 0.0 if d > gap_from and d < gap_to else 1.2
		surface.set_normal(basis.x * side)
		surface.add_vertex(edge)
		surface.set_normal(basis.x * side)
		surface.add_vertex(edge + basis.y * height)
		if rows > 0:
			var n: int = rows * 2
			for index in [n - 2, n, n - 1, n - 1, n, n + 1]:
				surface.add_index(index)
		rows += 1
		d += 3.0
	return surface.commit()


## Hochhäuser aus einem MultiMesh (ein Zeichenaufruf), Fassaden aus dem Fenster-Shader.
static func towers(env) -> void:
	var world = env.world
	var rng := RandomNumberGenerator.new()
	rng.seed = 3300
	var count: int = int(TOWER_COUNT.get(env.tier, 46))
	var transforms: Array[Transform3D] = []
	var tries: int = 0
	while transforms.size() < count and tries < count * 12:
		tries += 1
		var d: float = rng.randf() * world.length
		var side: float = 1.0 if rng.randf() > 0.5 else -1.0
		var size := Vector3(
			rng.randf_range(14, 26), rng.randf_range(90, 170), rng.randf_range(14, 26)
		)
		var lateral: float = (
			side * (world.road_width_at(d) * 0.5 + size.x * 0.7 + rng.randf_range(16, 70))
		)
		var at: Vector3 = world.position_at(d, lateral)
		var hit: Vector2 = world._nearest_horizontal(Vector3(at.x, 0.0, at.z))
		if hit.x < size.length() * 0.45 + 12.0:
			continue
		var base_y: float = float(env.course.CLOUD_DECK) - 30.0
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(size)
		transforms.append(Transform3D(basis, Vector3(at.x, base_y + size.y * 0.5, at.z)))
	var box := BoxMesh.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = "Hochhaeuser"
	node.multimesh = multimesh
	node.material_override = env.shader_material(WINDOWS)
	if env.low():
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env.add_child(node)
	env.parts["towers"] = transforms.size()
	# Wahrzeichen-Türme mit Leuchtkronen an markanten Stellen.
	for spot in [
		[150.0, 34.0, "sky_tower_b"],
		[560.0, -40.0, "sky_tower"],
		[1040.0, 42.0, "sky_tower_b"],
		[1880.0, -36.0, "sky_tower"],
		[2260.0, 40.0, "sky_tower_b"],
		[2700.0, -46.0, "sky_tower"],
		[3060.0, 44.0, "sky_tower"]
	]:
		var at: Vector3 = world.position_at(float(spot[0]), float(spot[1]))
		var tower: Node3D = env.module(DIR + str(spot[2]) + ".glb", 4.0)
		tower.position = Vector3(at.x, float(env.course.CLOUD_DECK) - 12.0, at.z)
		tower.scale = Vector3.ONE * 1.7
		tower.rotation.y = float(spot[0])
		env.add_child(tower)


static func helix_centre(env) -> Vector3:
	var helix: Vector2 = env.course.HELIX
	var total := Vector3.ZERO
	var samples: int = 36
	for i in range(samples):
		total += env.world.position_at(
			lerpf(helix.x + 40.0, helix.y - 40.0, float(i) / float(samples))
		)
	return total / float(samples)


static func star_tower(env) -> void:
	var centre: Vector3 = helix_centre(env)
	var tower: Node3D = env.module(DIR + "star_tower.glb", 4.0)
	tower.name = "Sternenturm"
	tower.position = Vector3(centre.x, float(env.course.CLOUD_DECK) - 30.0, centre.z)
	tower.scale = Vector3.ONE * 1.1
	env.add_child(tower)
	var beacon := OmniLight3D.new()
	beacon.light_color = Color("ffe08a")
	beacon.light_energy = 2.0
	beacon.omni_range = 60.0
	beacon.position = tower.position + Vector3.UP * 150.0
	env.add_child(beacon)
	var island: Node3D = env.module(DIR + "island_rock.glb", 3.0)
	island.position = Vector3(centre.x, float(env.course.CLOUD_DECK) + 6.0, centre.z)
	island.scale = Vector3.ONE * 1.6
	env.add_child(island)


static func glass_tunnel(env) -> void:
	var world = env.world
	var tunnel: Dictionary = env.course.TUNNELS[0]
	var a: float = float(tunnel.start)
	var b: float = float(tunnel.end)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.55, 0.85, 1.0, 0.16)
	glass.roughness = 0.03
	glass.metallic = 0.4
	glass.rim_enabled = true
	glass.rim = 0.6
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tube: MeshInstance3D = env.mesh_node(
		"Glastunnel", env.tube(a, b, float(tunnel.ceiling), 0.5), glass, 0.0, false
	)
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Leuchtringe alle 8 m, abwechselnd Cyan und Pink.
	var d: float = a + 2.0
	var k: int = 0
	while d < b:
		var basis: Basis = world.frame(d)
		var half: float = world.road_width_at(d) * 0.5 + 0.5
		var steps: int = 10
		for i in range(steps):
			var u0: float = PI * float(i) / float(steps)
			var u1: float = PI * float(i + 1) / float(steps)
			var p: Vector3 = (
				world.position_at(d, -cos(u0) * half) + basis.y * (sin(u0) * float(tunnel.ceiling))
			)
			var q: Vector3 = (
				world.position_at(d, -cos(u1) * half) + basis.y * (sin(u1) * float(tunnel.ceiling))
			)
			world._beam(p, q, 0.22, Color("5ff0ff") if k % 2 == 0 else Color("ff4fd8"), true)
		d += 8.0
		k += 1
	for at in [a, b]:
		env.place(DIR + "sky_portal.glb", at, 0.0, 1.0, 0.0, world.position_at(at).y + 0.2)
	# Atrium-Turm: zwei Hälften links und rechts, darüber eine Glasbrücke.
	var mid: float = (a + b) * 0.5
	for side in [-1.0, 1.0]:
		var at: Vector3 = world.position_at(mid, side * 26.0)
		var half_tower: Node3D = env.module(DIR + "sky_tower.glb", 3.0)
		half_tower.position = Vector3(at.x, float(env.course.CLOUD_DECK) - 20.0, at.z)
		half_tower.scale = Vector3(1.4, 2.2, 3.0)
		half_tower.rotation.y = atan2(-world.forward(mid).x, -world.forward(mid).z)
		env.add_child(half_tower)


static func holo_bridge(env) -> void:
	var world = env.world
	var bridge: Vector2 = env.course.HOLO_BRIDGE
	var streak: ShaderMaterial = env.shader_material(
		STREAKS, {"tint": Color("5ff0ff"), "speed": 8.0, "density": 0.8, "intensity": 0.9}
	)
	for side in [-1.0, 1.0]:
		var half: float = world.road_width_at(bridge.x) * 0.5
		var edge: ArrayMesh = env.ribbon(
			bridge.x, bridge.y, side * half - 0.3, side * half + 0.3, 0.05, 2.0
		)
		env.mesh_node("Holokante%d" % int(side), edge, streak, 0.0, false)
	var under: ShaderMaterial = env.shader_material(
		STREAKS, {"tint": Color("6f8cff"), "speed": 3.0, "density": 0.6, "intensity": 0.5}
	)
	env.mesh_node(
		"Holounterseite", env.ribbon(bridge.x, bridge.y, -6.5, 6.5, -0.6, 3.0), under, 0.0, false
	)
	for i in range(4):
		var d: float = lerpf(bridge.x + 10.0, bridge.y - 10.0, float(i) / 3.0)
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var at: Vector3 = world.position_at(d, side * 30.0)
		var platform: Node3D = env.module(DIR + "floating_platform.glb", 2.0)
		platform.position = at + Vector3.DOWN * 3.0
		platform.rotation.y = d
		env.add_child(platform)
		env.platforms.append(platform)
		env.platform_rest.append(platform.position)


static func windkanal(env) -> void:
	var world = env.world
	var kicker: Vector2 = env.course.WIND_KICKER
	var from: float = kicker.x - 40.0
	var to: float = 1230.0
	var wind: ShaderMaterial = env.shader_material(
		STREAKS, {"tint": Color("dff6ff"), "speed": 30.0, "density": 0.3, "intensity": 0.45}
	)
	# Sichtbarer Wind über den Karts (nicht in Kamerahöhe, damit die Fahrbahn klar bleibt).
	var sheet: ArrayMesh = env.ribbon(from, to, -6.0, 6.0, 6.5, 3.0)
	env.mesh_node("Wind", sheet, wind, 0.0, false)
	for i in range(4):
		var d: float = lerpf(from, to, float(i) / 3.0)
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var at: Vector3 = world.position_at(d, side * (world.road_width_at(d) * 0.5 + 6.0))
		var rotor: Node3D = env.module(DIR + "wind_rotor.glb", 2.0)
		rotor.position = at - Vector3.UP * 1.0
		env.add_child(rotor)
		env.rotors.append(rotor)
	# Aufwind-Ring über der Schanze: hier trägt der Wind.
	var lip: float = kicker.y + 14.0
	var basis: Basis = world.frame(lip)
	world._prop(
		"torus",
		world.position_at(lip) + basis.y * 7.5,
		Vector3(18, 18, 18),
		Color("8ff7ff"),
		basis.rotated(basis.x, PI * 0.5),
		true
	)


static func gabel(env) -> void:
	var world = env.world
	var split: Dictionary = env.course.SPLITS[0]
	var d: float = float(split.start) + 3.0
	while d < float(split.end) - 2.0:
		env.place(DIR + "holo_pylon.glb", d, float(split.lateral), 1.0, d, NAN, 1.0)
		d += 7.0
	var mid: float = (float(split.start) + float(split.end)) * 0.5
	var narrow: float = (float(split.lateral) - (world.road_width_at(mid) * 0.5)) * 0.5
	for offset in [-34.0, 0.0, 34.0]:
		env.place(DIR + "lobby_hall.glb", mid + offset, narrow, 1.0, 0.0, NAN, 1.2)


static func start_gate(env) -> void:
	var gate: Node3D = env.place(
		DIR + "sky_portal.glb", -8.0, 0.0, 1.0, 0.0, env.world.position_at(-8.0).y + 0.2
	)
	gate.name = "Starttor"
	var title := Label3D.new()
	title.name = "Streckenname"
	title.font = FONT
	title.font_size = 96
	title.pixel_size = 0.013
	title.text = "WOLKENSTURM"
	title.modulate = Color("e8fbff")
	title.outline_size = 14
	title.outline_modulate = Color("1d2a6a")
	title.position = Vector3(0.0, 11.4, 0.8)
	title.visibility_range_end = 220.0
	gate.add_child(title)
