extends RefCounted
## Kristallflut – Gelände und Bauwerke (aus flut_environment.gd aufgerufen): Küste mit Klippen
## und Meeresgrund, Schiffsanleger mit Schiff, Leuchtturm, Wasserfall über dem Sprungbecken,
## gläserner Unterwassertunnel mit Rippen, Fischen, Korallen und Ruinen, Ruineninsel mit
## Säulengang, Kristallgrotte mit Lichtbecken, Klippenweg, Wasserfall-Vorhang, Starttor.
## Maße aus flut_course.gd, Modelle aus tools/lumo_signature_art/build_kristallflut.py.
const DIR: String = "res://assets/kart/signature/kristallflut/"
const WATERFALL = preload("res://assets/shaders/signature/signature_waterfall.gdshader")
const FISH = preload("res://assets/shaders/signature/signature_fish.gdshader")
const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const ISLAND_CENTRE: Vector2 = Vector2(300.0, -230.0)
const FISH_COUNT: Dictionary = {"low": 40, "medium": 90, "high": 150}


static func build(env) -> void:
	terrain(env)
	env.skirts(Color("6b6a60"), func(d: float) -> bool: return _open(env, d))
	harbour(env)
	waterfall_jump(env)
	underwater_tunnel(env)
	ruins(env)
	grotto(env)
	cliff_path(env)
	curtain(env)
	start_gate(env)


static func _open(env, d: float) -> bool:
	for tunnel in env.course.TUNNELS:
		if d > float(tunnel.start) - 1.0 and d < float(tunnel.end) + 1.0:
			return false
	return true


# ------------------------------------------------------------------ Gelände


## Natürliches Gelände: Klippenland im Inneren (bis 26 m), Strände, Meeresgrund (−16 m).
## Südlich der Startgeraden liegt der Hafen (Meer), längs des Unterwassertunnels eine
## Meerenge (strait: Stützpunkte der Tunnelmitte).
static func natural(x: float, z: float, strait: PackedVector2Array) -> float:
	var r: float = Vector2((x - ISLAND_CENTRE.x) / 1.35, z - ISLAND_CENTRE.y).length()
	var wobble: float = sin(x * 0.013) * 26.0 + cos(z * 0.011 + x * 0.006) * 20.0
	var land: float = smoothstep(420.0 + wobble, 300.0 + wobble, r)
	# Hafenbecken südlich der Startgeraden (westlich der Klippenstraße).
	land *= 1.0 - smoothstep(6.0, 20.0, z) * (1.0 - smoothstep(170.0, 250.0, x))
	var near: float = INF
	for point in strait:
		near = minf(near, point.distance_squared_to(Vector2(x, z)))
	land *= smoothstep(55.0, 110.0, sqrt(near))
	var hills: float = (
		10.0 + sin(x * 0.021) * 5.0 + cos(z * 0.017) * 6.0 + smoothstep(260.0, 80.0, r) * 12.0
	)
	return lerpf(-16.0 + sin(x * 0.03) * 1.5, hills, land)


static func ground(env, x: float, z: float) -> float:
	var h: float = natural(x, z, env.parts.get("strait", PackedVector2Array()))
	var hit: Vector2 = env.road_hit(x, z)
	if hit.x < 60.0:
		var road_y: float = env.world._road_samples[int(hit.y)].y
		var d: float = float(env.world._road_distances[int(hit.y)])
		var half: float = env.world.road_width_at(d) * 0.5
		var tilt: float = half * 0.14
		if env.world.bank_weight(d) > 0.0:
			tilt = absf(env.world.frame(d).x.y) * half
		var target: float = road_y - 0.7 - tilt
		var tunnel = env._tunnel_at(d)
		var glass: Vector2 = env.parts.get("glass", Vector2.ZERO)
		if d > glass.x and d < glass.y:
			# Die Glasröhre liegt auf dem Meeresgrund: darüber nur Wasser.
			target = minf(h, road_y - 1.2)
		elif tunnel != null:
			# Felsröhren liegen in einem Einschnitt: unter dem Gewölbe tief, daneben Fels bis
			# über die Decke. So schneidet das Gelände nie durch den Innenraum.
			if hit.x < half + 4.0:
				return road_y - 1.2
			var cover: float = maxf(h, road_y + float(tunnel.ceiling) + 6.0)
			return lerpf(road_y - 1.2, cover, smoothstep(half + 4.0, half + 12.0, hit.x))
		if d > 284.0 and d < 322.0:
			target = minf(h, road_y - 6.0)
		if d < 136.0 or d > 2690.0:
			# Anleger auf Pfählen: darunter liegt Hafenwasser.
			target = minf(h, -3.0)
		h = lerpf(target, h, smoothstep(half + 5.0, half + 30.0, hit.x))
	return h


static func colour(x: float, z: float, h: float) -> Color:
	var sand := Color("e3d3a6")
	var grass := Color("6ea24a")
	var rock := Color("8a8f86")
	var seabed := Color("2f8a8c")
	var c: Color = grass.lerp(
		rock, smoothstep(14.0, 24.0, h) * 0.7 + 0.15 * sin(x * 0.04 + z * 0.03)
	)
	c = c.lerp(sand, 1.0 - smoothstep(0.6, 3.0, h))
	c = c.lerp(seabed, 1.0 - smoothstep(-6.0, -0.5, h))
	return c


## Glasstrecke des Unterwassertunnels: dort, wo die Röhrenkuppe 0,8 m unter dem Meer liegt.
## Davor und dahinter führt eine Felsröhre hinab bzw. hinauf (Vector2(von, bis) in Metern).
static func glass_span(env) -> Vector2:
	var tunnel: Dictionary = env.course.TUNNELS[0]
	var limit: float = float(env.course.SEA_LEVEL) - float(tunnel.ceiling) - 0.8
	var span := Vector2(INF, -INF)
	var d: float = float(tunnel.start)
	while d <= float(tunnel.end):
		if env.world.position_at(d).y < limit:
			span = Vector2(minf(span.x, d), maxf(span.y, d))
		d += 2.0
	return span


static func terrain(env) -> void:
	var glass: Vector2 = glass_span(env)
	env.parts["glass"] = glass
	var strait := PackedVector2Array()
	var along: float = glass.x + 10.0
	while along < glass.y - 10.0:
		var p: Vector3 = env.world.position_at(along)
		strait.append(Vector2(p.x, p.z))
		along += 20.0
	env.parts["strait"] = strait
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for sample in env.world._road_samples:
		min_p = Vector2(minf(min_p.x, sample.x), minf(min_p.y, sample.z))
		max_p = Vector2(maxf(max_p.x, sample.x), maxf(max_p.y, sample.z))
	var centre: Vector2 = (min_p + max_p) * 0.5
	var size: float = maxf(max_p.x - min_p.x, max_p.y - min_p.y) + 420.0
	var cells: int = 140 if env.low() else (190 if env.tier == "medium" else 220)
	env.terrain("Kuestenland", centre, size, cells, func(x, z): return ground(env, x, z), colour)


# ------------------------------------------------------------------ Hafen


static func harbour(env) -> void:
	var world = env.world
	# Anleger: Holzpfähle unter den Planken, Poller, das Schiff am Kai (Meerseite rechts).
	for d in range(0, 132, 6):
		var basis: Basis = world.frame(d)
		for side in [-1.0, 1.0]:
			var p: Vector3 = world.position_at(d, side * (world.road_width_at(d) * 0.5 + 0.2))
			world._beam(p - Vector3.UP * 6.0, p + basis.y * 0.9, 0.5, Color("6d4c33"))
		if d % 18 == 0:
			var post: Vector3 = world.position_at(d, world.road_width_at(d) * 0.5 + 0.6)
			world._prop(
				"cylinder", post + Vector3.UP * 0.4, Vector3(0.5, 0.8, 0.5), Color("2f3a44")
			)
	env.place(DIR + "ship.glb", 70.0, 28.0, 1.2, 180.0, float(env.course.SEA_LEVEL) - 0.6, 2.0)
	for d in [2720.0, 2790.0]:
		var basis: Basis = world.frame(d)
		for side in [-1.0, 1.0]:
			var p: Vector3 = world.position_at(d, side * (world.road_width_at(d) * 0.5 + 0.2))
			world._beam(p - Vector3.UP * 6.0, p + basis.y * 0.9, 0.5, Color("6d4c33"))
	# Leuchtturm auf der Landzunge: das Leuchtfeuer dreht sich (Licht als Kegel).
	var light_at: Vector3 = world.position_at(480.0, 46.0)
	var lighthouse: Node3D = env.module(DIR + "lighthouse.glb", 4.0)
	var rock_y: float = ground(env, light_at.x, light_at.z)
	if rock_y < 2.0:
		# Leuchtturm-Felsen im Meer.
		world._prop(
			"rock",
			Vector3(light_at.x, -4.0, light_at.z),
			Vector3(16.0, 14.0, 16.0),
			Color("7d817a")
		)
		rock_y = 2.5
	lighthouse.position = Vector3(light_at.x, rock_y - 0.5, light_at.z)
	lighthouse.scale = Vector3.ONE * 1.4
	env.add_child(lighthouse)
	var beam := Node3D.new()
	beam.name = "Leuchtfeuer"
	beam.position = lighthouse.position + Vector3.UP * 29.0
	env.add_child(beam)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.6
	cone.bottom_radius = 7.0
	cone.height = 60.0
	cone.radial_segments = 12
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(1.0, 0.95, 0.7, 0.18)
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ray := MeshInstance3D.new()
	ray.mesh = cone
	ray.material_override = glow
	ray.rotation_degrees = Vector3(0, 0, 90)
	ray.position = Vector3(30.0, 0, 0)
	ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.add_child(ray)
	env.beam = beam


# ------------------------------------------------------------------ Wasserfall-Sprung


static func waterfall_jump(env) -> void:
	var world = env.world
	var crossing: float = float(env.course.FALL_STREAM)
	var basis: Basis = world.frame(crossing)
	var road: Vector3 = world.position_at(crossing)
	# Fall von einer 28 m hohen Klippe links der Fahrbahn in das Becken unter der Brücke.
	var cliff: Vector3 = world.position_at(crossing, -40.0)
	world._prop(
		"rock", Vector3(cliff.x, road.y + 6.0, cliff.z), Vector3(30.0, 44.0, 26.0), Color("8d958a")
	)
	world._prop(
		"rock",
		Vector3(cliff.x, road.y + 2.0, cliff.z) + basis.z * 18.0,
		Vector3(22.0, 30.0, 20.0),
		Color("7f877c")
	)
	world._prop(
		"rock",
		Vector3(cliff.x, road.y + 2.0, cliff.z) - basis.z * 18.0,
		Vector3(22.0, 28.0, 20.0),
		Color("858c80")
	)
	var top: Vector3 = world.position_at(crossing, -17.0)
	var top_y: float = road.y + 26.0
	var bottom_y: float = road.y - 6.5
	# Der Vorhang steht quer zur Fahrtrichtung: der Fahrer sieht ihn von vorn.
	var fall := _sheet(Vector3(top.x, top_y, top.z), basis.x, 12.0, top_y - bottom_y)
	env.mesh_node(
		"Wasserfall",
		fall,
		env.shader_material(WATERFALL, {"speed": 12.0, "half_width": 6.0, "opacity": 0.95}),
		0.0,
		false
	)
	# Der Fluss läuft unter der Brücke hindurch bergab ins Meer.
	var sea_y: float = float(env.course.SEA_LEVEL) + 0.2
	var path: Array = []
	for lateral in [-17.0, -8.0, 0.0, 24.0, 60.0, 90.0]:
		var p: Vector3 = world.position_at(crossing, lateral)
		var t: float = inverse_lerp(-17.0, 90.0, lateral)
		path.append(Vector3(p.x, lerpf(bottom_y, sea_y, t), p.z))
	var flow: ShaderMaterial = env.shader_material(
		WATERFALL, {"speed": 5.0, "half_width": 5.0, "opacity": 0.9}
	)
	env.mesh_node("Fluss", env.path_ribbon(path, 5.0), flow, 0.0, false)
	env.puffs(
		"Gischt",
		[Vector4(top.x, bottom_y + 1.0, top.z, 6.0)],
		30,
		Color(0.95, 0.98, 1.0, 0.55),
		6.0,
		12.0,
		0.25,
		false,
		Vector3(1.0, 0, 0.5)
	)
	# Steinbrücke: Pfeiler und Brüstung tragen die Fahrbahn über den Fluss.
	for d in range(286, 322, 4):
		var b: Basis = world.frame(d)
		for side in [-1.0, 1.0]:
			var p: Vector3 = world.position_at(d, side * (world.road_width_at(d) * 0.5 + 0.3))
			world._prop("box", p + b.y * 0.5, Vector3(0.7, 1.0, 4.1), Color("b9b4a2"), b)
	for side in [-1.0, 1.0]:
		var pier: Vector3 = world.position_at(crossing + side * 9.0)
		world._prop("box", pier - Vector3.UP * 4.0, Vector3(14.0, 8.0, 3.0), Color("a9a597"), basis)
	# Regenbogen in der Gischt (Sonne im Rücken des Fahrers).
	var arc := TorusMesh.new()
	arc.inner_radius = 17.0
	arc.outer_radius = 19.0
	arc.rings = 32
	arc.ring_segments = 6
	var rainbow := StandardMaterial3D.new()
	rainbow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rainbow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rainbow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rainbow.albedo_color = Color(1.0, 0.7, 0.9, 0.22)
	var bow: MeshInstance3D = env.mesh_node("Regenbogen", arc, rainbow, 0.0, false)
	bow.position = Vector3(top.x, bottom_y, top.z) + basis.z * 6.0
	bow.rotation = Vector3(PI * 0.5, atan2(-basis.z.x, -basis.z.z), 0)


## Senkrechtes Wasserband: oben bei top, Breite quer zu along, Höhe nach unten.
static func _sheet(top: Vector3, along: Vector3, width: float, height: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side: Vector3 = along.normalized() * width * 0.5
	var rows: int = 6
	for i in range(rows + 1):
		var y: float = float(i) / float(rows) * height
		for k in range(2):
			var lateral: float = -1.0 if k == 0 else 1.0
			surface.set_uv(Vector2(lateral * width * 0.5, y))
			surface.set_normal(along.cross(Vector3.UP).normalized())
			surface.add_vertex(
				(
					top
					+ side * lateral
					- Vector3.UP * y
					+ along.cross(Vector3.UP).normalized() * y * 0.06
				)
			)
		if i > 0:
			var n: int = i * 2
			for index in [n - 2, n, n - 1, n - 1, n, n + 1]:
				surface.add_index(index)
	return surface.commit()


# ------------------------------------------------------------------ Unterwassertunnel


static func underwater_tunnel(env) -> void:
	var world = env.world
	var tunnel: Dictionary = env.course.TUNNELS[0]
	var glass_part: Vector2 = env.parts.glass
	# Felsröhren hinab und hinauf; dort spart die Meeresoberfläche die Röhre aus.
	var holes: Array = []
	for span in [
		Vector2(float(tunnel.start), glass_part.x), Vector2(glass_part.y, float(tunnel.end))
	]:
		env.vault(span.x, span.y, float(tunnel.ceiling), 0.8, 0.5, Color("5f6a66"))
		var d: float = span.x
		while d <= span.y:
			var p: Vector3 = world.position_at(d)
			if (
				p.y + float(tunnel.ceiling) > float(env.course.SEA_LEVEL) - 3.0
				and p.y < float(env.course.SEA_LEVEL) + 3.0
			):
				holes.append(Vector4(p.x, p.z, world.road_width_at(d) * 0.5 + 4.5, 0.0))
			d += 9.0
	holes.resize(mini(holes.size(), 24))
	var water: ShaderMaterial = env.sea.material_override
	water.set_shader_parameter("holes", holes)
	water.set_shader_parameter("hole_count", holes.size())
	env.parts["sea_holes"] = holes.size()
	var a: float = glass_part.x
	var b: float = glass_part.y
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.6, 0.95, 1.0, 0.14)
	glass.roughness = 0.02
	glass.metallic = 0.4
	glass.rim_enabled = true
	glass.rim = 0.7
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tube: MeshInstance3D = env.mesh_node(
		"Unterwasserroehre", env.tube(a, b, float(tunnel.ceiling), 0.5), glass, 0.0, false
	)
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var d: float = a
	while d <= b:
		env.place(DIR + "tunnel_ring.glb", d, 0.0, 1.0, 0.0, world.position_at(d).y + 0.6, 1.0)
		d += 14.0
	# Meeresgrund rund um die Röhre: Korallen, versunkene Säulen, Fischschwärme.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2800
	for i in range(18):
		var at_d: float = lerpf(a + 20.0, b - 20.0, rng.randf())
		var side: float = 1.0 if rng.randf() > 0.5 else -1.0
		var lateral: float = side * rng.randf_range(14.0, 34.0)
		var foot: Vector3 = world.position_at(at_d, lateral)
		var ground_y: float = ground(env, foot.x, foot.z) - 0.3
		if i % 3 == 0:
			env.place(
				DIR + "ruin_column.glb",
				at_d,
				lateral,
				rng.randf_range(1.0, 1.6),
				at_d,
				ground_y,
				1.0
			)
		else:
			env.place(
				DIR + "coral.glb", at_d, lateral, rng.randf_range(1.0, 2.2), at_d, ground_y, 1.0
			)
	_fish(env, a, b)
	# Lichtsäulen: Sonne bricht durch die Wellen (additiv, wandern mit der Zeit nicht nötig).
	var shaft_material := StandardMaterial3D.new()
	shaft_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shaft_material.albedo_color = Color(0.6, 0.95, 1.0, 0.08)
	shaft_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shaft_material.disable_fog = true
	var shaft := QuadMesh.new()
	shaft.size = Vector2(5.0, 22.0)
	for i in range(8):
		var at_d: float = lerpf(a + 30.0, b - 30.0, float(i) / 7.0)
		var p: Vector3 = world.position_at(at_d, (-1.0 if i % 2 == 0 else 1.0) * 12.0)
		var node: MeshInstance3D = env.mesh_node(
			"Lichtsaeule%d" % i, shaft, shaft_material, 0.0, false
		)
		node.position = Vector3(p.x, float(env.course.SEA_LEVEL) - 10.0, p.z)
		node.rotation = Vector3(0, float(i), 0.25)


static func _fish(env, a: float, b: float) -> void:
	var world = env.world
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Körper (Raute) und Schwanzflosse, Kopf zeigt nach −z.
	var points: Array = [
		Vector3(0, 0, -0.6),
		Vector3(0.22, 0, 0),
		Vector3(0, 0.25, 0),
		Vector3(-0.22, 0, 0),
		Vector3(0, -0.2, 0),
		Vector3(0, 0, 0.5),
		Vector3(0, 0.3, 0.85),
		Vector3(0, -0.3, 0.85),
	]
	for p in points:
		surface.add_vertex(p)
	for index in [0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 1, 5, 2, 1, 5, 3, 2, 5, 4, 3, 5, 1, 4, 5, 6, 7]:
		surface.add_index(index)
	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()
	var count: int = int(FISH_COUNT.get(env.tier, 90))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var palette: Array[Color] = [
		Color("ffb347"), Color("ffe066"), Color("7ff5ff"), Color("ff7f8a"), Color("b48cff")
	]
	for i in range(count):
		var school: int = i / 15
		var at_d: float = lerpf(a + 25.0, b - 25.0, float(school % 8) / 7.0)
		var side: float = 1.0 if school % 2 == 0 else -1.0
		var centre: Vector3 = world.position_at(at_d, side * rng.randf_range(16.0, 24.0))
		centre.y = world.position_at(at_d).y + rng.randf_range(2.0, 7.0)
		multimesh.set_instance_transform(
			i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), centre)
		)
		multimesh.set_instance_color(i, palette[school % palette.size()])
		multimesh.set_instance_custom_data(
			i,
			Color(
				rng.randf(),
				rng.randf_range(0.04, 0.09),
				rng.randf_range(4.0, 9.0),
				rng.randf_range(0.3, 1.2)
			)
		)
	var node := MultiMeshInstance3D.new()
	node.name = "Fischschwaerme"
	node.multimesh = multimesh
	node.material_override = env.shader_material(FISH)
	node.custom_aabb = AABB(Vector3(-3000, -100, -3000), Vector3(6000, 300, 6000))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env.add_child(node)
	env.parts["fish"] = count


# ------------------------------------------------------------------ Ruinen, Grotte, Klippen


static func ruins(env) -> void:
	var world = env.world
	var split: Dictionary = env.course.SPLITS[0]
	var narrow: float = (float(split.lateral) - world.road_width_at(1300.0) * 0.5) * 0.5
	var d: float = float(split.start) + 4.0
	while d < float(split.end):
		env.place(DIR + "ruin_arch.glb", d, narrow, 0.95, 0.0, NAN, 1.0)
		d += 20.0
	d = float(split.start) + 2.0
	while d < float(split.end):
		env.place(DIR + "ruin_column.glb", d, float(split.lateral), 0.75, d * 3.0, NAN, 0.8)
		d += 8.0
	for at in [1180.0, 1215.0, 1380.0, 1420.0]:
		for side in [-1.0, 1.0]:
			var lateral: float = side * (world.road_width_at(at) * 0.5 + 9.0 + fposmod(at, 11.0))
			var foot: Vector3 = world.position_at(at, lateral)
			env.place(
				DIR + "ruin_column.glb",
				at,
				lateral,
				1.3,
				at,
				ground(env, foot.x, foot.z) - 1.0,
				1.2
			)


static func grotto(env) -> void:
	var world = env.world
	var tunnel: Dictionary = env.course.TUNNELS[1]
	var a: float = float(tunnel.start)
	var b: float = float(tunnel.end)
	env.vault(a, b, float(tunnel.ceiling), 2.4, 0.8, Color("50606a"))
	for at in [a, b]:
		var mouth: Vector3 = world.position_at(at)
		world._prop("rock", mouth + Vector3.UP * 14.0, Vector3(34.0, 12.0, 10.0), Color("6c726c"))
	var d: float = a + 8.0
	var flip: float = 1.0
	while d < b - 6.0:
		var lateral: float = flip * (world.road_width_at(d) * 0.5 + 1.2)
		env.place(
			DIR + "crystal_spire.glb",
			d,
			lateral,
			0.55 + fposmod(d * 0.07, 0.3),
			d * 5.0,
			world.position_at(d).y - 0.6,
			0.8
		)
		d += 13.0
		flip = -flip
	# Leuchtende Becken neben der Fahrbahn (spiegeln das Kristalllicht).
	for k in range(3):
		var at: float = lerpf(a + 25.0, b - 25.0, float(k) / 2.0)
		var side: float = -1.0 if k % 2 == 0 else 1.0
		var pool: ArrayMesh = env.ribbon(at - 10.0, at + 10.0, side * 7.0, side * 8.8, -0.35, 2.0)
		var water := StandardMaterial3D.new()
		water.albedo_color = Color("1fb7c4")
		water.emission_enabled = true
		water.emission = Color("2ee6e0")
		water.emission_energy_multiplier = 1.2
		water.roughness = 0.04
		water.metallic = 0.3
		env.mesh_node("Lichtbecken%d" % k, pool, water, 0.0, false)
	var light := OmniLight3D.new()
	light.name = "Kristalllicht"
	light.light_color = Color("7ff5ff")
	light.light_energy = 2.4
	light.omni_range = 60.0
	light.position = world.position_at((a + b) * 0.5) + Vector3.UP * 8.0
	env.add_child(light)
	env.parts["crystal_light"] = light


static func cliff_path(env) -> void:
	var world = env.world
	var split: Dictionary = env.course.SPLITS[1]
	var d: float = float(split.start) + 3.0
	while d < float(split.end) - 2.0:
		env.place(DIR + "crystal_spire.glb", d, float(split.lateral), 0.32, d * 9.0, NAN, 0.8)
		d += 9.0
	for at in [2060.0, 2120.0, 2190.0, 2260.0, 2320.0]:
		var lateral: float = -(world.road_width_at(at) * 0.5 + 12.0)
		var foot: Vector3 = world.position_at(at, lateral)
		env.place(
			DIR + "crystal_spire.glb", at, lateral, 1.4, at, ground(env, foot.x, foot.z) - 0.5, 1.4
		)


## Wasserfall-Vorhang: das Wasser fällt vor dem Felsdach quer über die Einfahrt.
static func curtain(env) -> void:
	var world = env.world
	var tunnel: Dictionary = env.course.TUNNELS[2]
	var a: float = float(tunnel.start)
	var b: float = float(tunnel.end)
	env.vault(a, b, float(tunnel.ceiling), 1.6, 0.6, Color("7a7f76"))
	var sheet_material: ShaderMaterial = env.shader_material(
		WATERFALL, {"speed": 10.0, "half_width": 9.0, "opacity": 0.45}
	)
	for at in [a + 1.0, b - 1.0]:
		var basis: Basis = world.frame(at)
		var top: Vector3 = world.position_at(at) + basis.y * (float(tunnel.ceiling) + 0.4)
		env.mesh_node(
			"Vorhang_%d" % roundi(at),
			_sheet(top, basis.x, 18.0, float(tunnel.ceiling) + 1.0),
			sheet_material,
			0.0,
			false
		)
	var mist: Vector3 = world.position_at(a)
	env.puffs(
		"Vorhanggischt",
		[Vector4(mist.x, mist.y + 0.5, mist.z, 7.0)],
		24,
		Color(0.95, 0.98, 1.0, 0.4),
		4.0,
		6.0,
		0.4,
		false,
		Vector3(0.5, 0, 0)
	)


static func start_gate(env) -> void:
	var gate: Node3D = env.place(
		DIR + "pier_gate.glb", -6.0, 0.0, 1.0, 0.0, env.world.position_at(-6.0).y
	)
	gate.name = "Starttor"
	var title := Label3D.new()
	title.name = "Streckenname"
	title.font = FONT
	title.font_size = 96
	title.pixel_size = 0.013
	title.text = "KRISTALLFLUT"
	title.modulate = Color("e9fffb")
	title.outline_size = 14
	title.outline_modulate = Color("0f4a5a")
	title.position = Vector3(0.0, 11.0, 0.6)
	title.visibility_range_end = 220.0
	gate.add_child(title)
