extends "res://scripts/games/kart_signature/kart_signature_environment.gd"
## Vulkanexpress – Feuerinsel: Insel, Vulkan, Lavaflüsse, Wahrzeichen, Vulkanexpress und
## der kinderfreundliche Ausbruch. Fahrbahn und Kollision kommen aus kart_signature_world.gd;
## hier steht nur, was man sieht und hört, und was im Rennen passiert (_race_tick).
## Physik der Effekte: Lava fließt bergab zum Meer und dampft dort; Rauch steigt auf und
## treibt mit dem Westwind; Lavabomben fliegen auf Wurfparabeln (g = 9,81 m/s²) und landen
## nur im Krater oder auf der Bergflanke, nie auf der Fahrbahn.
const DIR: String = "res://assets/kart/signature/vulkanexpress/"
const LAVA_SHADER = preload("res://assets/shaders/signature/signature_lava_flow.gdshader")
const WATER_SHADER = preload("res://assets/shaders/signature/signature_water.gdshader")
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const LANDMARKS = preload("res://scripts/games/vulkanexpress/vulkan_landmarks.gd")
const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const VOLCANO_CENTRE: Vector2 = Vector2(492.0, -405.0)
const VOLCANO_HEIGHT: float = 130.0
const VOLCANO_RADIUS: float = 300.0
const CRATER_RADIUS: float = 34.0
const SEA_LEVEL: float = -1.2
## Westwind in m/s (unten schwächer als über dem Gipfel).
const WIND: Vector3 = Vector3(3.2, 0.0, 1.1)
const HIGH_WIND: Vector3 = Vector3(6.5, 0.0, 2.2)
## Ausbruch: Dauer, Wurfweite der Bomben, Höhe der Fontäne.
const ERUPTION_SECONDS: float = 14.0
const BOMB_COUNT: int = 7
const LOOK: Dictionary = {
	"zenith": Color("2f4f86"),
	"horizon": Color("f4a56e"),
	"ground": Color("3a2c2a"),
	"ground_horizon": Color("c98a62"),
	"sun_color": Color("ffd09a"),
	"sun_energy": 1.05,
	"sun_rotation": Vector3(-24, -62, 0),
	"ambient": Color("cdb6aa"),
	"ambient_energy": 0.34,
	"fog": Color("8e7268"),
	"fog_density": 0.00042,
	"exposure": 0.95,
	"glow": 0.7,
	"glow_threshold": 0.95,
	"saturation": 1.15,
	"aerial": 0.12,
	"fog_energy": 0.38,
	"fog_sky": 0.4,
	"fill_color": Color("8fb0ff"),
	"fill_energy": 0.22,
}
## Lavaflüsse [x, Lavaoberfläche y, z]: vom Vulkan bergab ins Meer, unter den Brücken durch.
const LAVASTROM: Array = [
	Vector3(445, 34, -300),
	Vector3(392, 15, -196),
	Vector3(352, 6.5, -128),
	Vector3(323, 2.3, -86),
	Vector3(305, 0.8, -10),
	Vector3(300, -0.2, 70),
	Vector3(296, -1.0, 170),
]
const GLUTCANYON: Array = [
	Vector3(640, 24, -560),
	Vector3(683, 9, -498),
	Vector3(730, 3.0, -437),
	Vector3(775, 1.6, -372),
	Vector3(830, 0.2, -295),
	Vector3(880, -1.0, -230),
]

var lava_material: ShaderMaterial
var flank_material: ShaderMaterial
var crater_light: OmniLight3D
var fountain: MultiMeshInstance3D
var smoke: MultiMeshInstance3D
var ash: MultiMeshInstance3D
var bombs: Array[MeshInstance3D] = []
var bomb_paths: Array[Dictionary] = []
var geyser_steam: Array[MultiMeshInstance3D] = []
var train_cars: Array[Node3D] = []
var eruption_time: float = -1.0
var eruption_count: int = 0
## Der Express steht am Bahnsteig (Lok bei 70 m) und fährt beim Start mit los.
var train_s: float = 70.0
var train_speed: float = 0.0
var train_running: bool = false
var train_shown: bool = true
var train_started: bool = false
var _summit: Vector3
var _river_boxes: Array[Rect2] = []


func _scene() -> void:
	_lighting(LOOK)
	_summit = Vector3(VOLCANO_CENTRE.x, rim_height() - 8.0, VOLCANO_CENTRE.y)
	lava_material = shader_material(LAVA_SHADER, {"half_width": 4.5, "speed": 1.1})
	var steps: Array[Callable] = [
		_sea,
		_island,
		_lava_rivers,
		_volcano_top,
		_side_crater,
		_station_and_train,
		LANDMARKS.build.bind(self),
		_geysers
	]
	var timing: Array[int] = []
	for step in steps:
		var started: int = Time.get_ticks_usec()
		step.call()
		timing.append((Time.get_ticks_usec() - started) / 1000)
	parts["timing_ms"] = timing
	parts["eruptions"] = 0


# ------------------------------------------------------------------ Meer und Insel


func _sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4200, 4200)
	plane.subdivide_width = 48 if low() else 96
	plane.subdivide_depth = plane.subdivide_width
	var sea := mesh_node(
		"Meer",
		plane,
		shader_material(
			WATER_SHADER, {"deep": Color("0d3550"), "shallow": Color("2a8c94"), "wave_height": 0.45}
		),
		0.0,
		false
	)
	sea.position = Vector3(300, SEA_LEVEL, -400)


func _segment_distance(p: Vector2, a: Vector3, b: Vector3) -> Vector2:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var t: float = clampf((p - a2).dot(b2 - a2) / maxf((b2 - a2).length_squared(), 0.01), 0.0, 1.0)
	return Vector2(p.distance_to(a2.lerp(b2, t)), lerpf(a.y, b.y, t))


## Abstand zum Fluss und Lavahöhe dort: Vector2(Abstand, Höhe).
func _river(p: Vector2, path: Array) -> Vector2:
	var best := Vector2(INF, 0.0)
	for i in range(path.size() - 1):
		var hit: Vector2 = _segment_distance(p, path[i], path[i + 1])
		if hit.x < best.x:
			best = hit
	return best


func _volcano(x: float, z: float) -> float:
	var r: float = Vector2(x, z).distance_to(VOLCANO_CENTRE)
	if r >= VOLCANO_RADIUS:
		return 0.0
	var ridges: float = (
		sin(atan2(z - VOLCANO_CENTRE.y, x - VOLCANO_CENTRE.x) * 7.0) * 2.5 * (r / VOLCANO_RADIUS)
	)
	if r < CRATER_RADIUS:
		# Kraterschüssel: vom Rand 18 m hinab bis zum Lavasee.
		return rim_height() + 2.0 - 18.0 * smoothstep(CRATER_RADIUS, CRATER_RADIUS * 0.55, r)
	return (
		VOLCANO_HEIGHT * pow(1.0 - r / VOLCANO_RADIUS, 2.2)
		+ ridges
		+ 2.0 * smoothstep(CRATER_RADIUS + 10.0, CRATER_RADIUS, r)
	)


## Höhe des Kraterrands (Kegel bei CRATER_RADIUS).
func rim_height() -> float:
	return VOLCANO_HEIGHT * pow(1.0 - CRATER_RADIUS / VOLCANO_RADIUS, 2.2)


## Natürliches Gelände: Inselrand, Vulkan, Hügel über den Tunneln, Nebenkrater.
func _natural(x: float, z: float) -> float:
	var island: float = Vector2((x - 270.0) / 1.25, z + 400.0).length()
	var wobble: float = sin(x * 0.011) * 22.0 + cos(z * 0.013 + x * 0.004) * 18.0
	var coast: float = smoothstep(560.0 + wobble, 470.0 + wobble, island)
	var h: float = lerpf(-9.0, 2.5 + sin(x * 0.031) * 1.2 + cos(z * 0.027) * 1.4, coast)
	h += _volcano(x, z)
	for hill in parts.get("hills", []):
		var c: Vector3 = hill
		h += c.y * exp(-Vector2(x - c.x, z - c.z).length_squared() / 2600.0)
	return h


func _ground(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h: float = _natural(x, z)
	var hit: Vector2 = road_hit(x, z)
	if hit.x < 60.0:
		var road_y: float = world._road_samples[int(hit.y)].y
		var d: float = float(world._road_distances[int(hit.y)])
		var half: float = world.road_width_at(d) * 0.5
		# Querneigung: normale Kurven höchstens 0,14 rad, die Steilkurve genau gerechnet.
		var tilt: float = half * 0.14
		if world.bank_weight(d) > 0.0:
			tilt = absf(world.frame(d).x.y) * half
		var target: float = road_y - 0.7 - tilt
		if _tunnel_at(d) != null:
			target = maxf(h, road_y + 16.0)
		if (d > 312.0 and d < 368.0) or (d > 856.0 and d < 984.0):
			target = minf(h, road_y - 3.0)
		h = lerpf(target, h, smoothstep(half + 6.0, half + 34.0, hit.x))
	# Flussbetten: Lava liegt 0,6 m unter den Ufern, die Ufer fallen weich ab.
	for k in range(2):
		var path: Array = LAVASTROM if k == 0 else GLUTCANYON
		var bank: float = 8.0 if k == 0 else 14.0
		var box: Rect2 = _river_boxes[k]
		if not box.has_point(p):
			continue
		var river: Vector2 = _river(p, path)
		var bed: float = river.y - 0.6
		if river.x < bank + 26.0 and h > bed:
			h = lerpf(bed, h, smoothstep(bank * 0.55, bank + 26.0, river.x))
	return h


## Grober Rahmen um jeden Lavafluss (Uferbreite eingerechnet): spart die Abstandsrechnung.
func _river_box(path: Array, margin: float) -> Rect2:
	var box := Rect2(Vector2(path[0].x, path[0].z), Vector2.ZERO)
	for point in path:
		box = box.expand(Vector2(point.x, point.z))
	return box.grow(margin)


func _island() -> void:
	# Hügel über Felsentunnel und Vulkanhöhle: die Fahrbahn fährt wirklich in den Berg.
	parts["hills"] = [
		Vector3(world.position_at(720).x, 24.0, world.position_at(720).z),
		Vector3(world.position_at(2004).x, 30.0, world.position_at(2004).z),
	]
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for sample in world._road_samples:
		min_p = Vector2(minf(min_p.x, sample.x), minf(min_p.y, sample.z))
		max_p = Vector2(maxf(max_p.x, sample.x), maxf(max_p.y, sample.z))
	var centre: Vector2 = (min_p + max_p) * 0.5
	var size: float = maxf(max_p.x - min_p.x, max_p.y - min_p.y) + 440.0
	_river_boxes = [_river_box(LAVASTROM, 40.0), _river_box(GLUTCANYON, 46.0)]
	var cells: int = 140 if low() else (190 if tier == "medium" else 220)
	terrain("Feuerinsel", centre, size, cells, _ground, _ground_colour)


func _ground_colour(x: float, z: float, h: float) -> Color:
	var r: float = Vector2(x, z).distance_to(VOLCANO_CENTRE)
	var basalt := Color("231d1e")
	var ash_tone := Color("473d3a")
	var green := Color("4b6a36")
	var sand := Color("1c1819")
	var colour: Color = basalt.lerp(ash_tone, 0.5 + 0.5 * sin(x * 0.05 + z * 0.03))
	colour = colour.lerp(
		green,
		(
			smoothstep(220.0, 330.0, r)
			* smoothstep(1.0, 6.0, h)
			* (1.0 - smoothstep(14.0, 30.0, h))
			* 0.8
		)
	)
	colour = colour.lerp(sand, 1.0 - smoothstep(-0.5, 2.6, h))
	colour = colour.lerp(Color("3a1a16"), smoothstep(60.0, 95.0, h) * 0.7)
	return colour


# ------------------------------------------------------------------ Lava


func _lava_rivers() -> void:
	mesh_node("Lavastrom", path_ribbon(LAVASTROM, 4.5), lava_material, 0.0, false)
	mesh_node("Glutcanyon", path_ribbon(GLUTCANYON, 5.0), lava_material, 0.0, false)
	# Wo die Lava ins Meer fließt, verdampft Wasser: dichte weiße Säulen.
	var mouths: Array = []
	for path in [LAVASTROM, GLUTCANYON]:
		var end: Vector3 = path[path.size() - 1]
		mouths.append(Vector4(end.x, SEA_LEVEL + 0.5, end.z, 4.0))
	puffs("MeeresDampf", mouths, 26, Color(0.95, 0.95, 0.97, 0.5), 9.0, 34.0, 0.11, false, WIND)
	# Lavaströme auf der Bergflanke (abseits der Fahrbahn), nach dem Ausbruch heller.
	flank_material = shader_material(LAVA_SHADER, {"half_width": 2.0, "speed": 0.6, "glow": 1.4})
	for angle in [0.35, 1.25, -0.55, 2.4]:
		var path: Array = []
		for k in range(16):
			var r: float = CRATER_RADIUS + 6.0 + float(k) * 7.5
			var a: float = angle + sin(float(k) * 0.7 + angle) * 0.06
			var x: float = VOLCANO_CENTRE.x + cos(a) * r
			var z: float = VOLCANO_CENTRE.y + sin(a) * r
			path.append(Vector3(x, _natural(x, z) + 0.35, z))
		mesh_node("Flankenlava", path_ribbon(path, 2.0), flank_material, 0.0, false)


func _volcano_top() -> void:
	var lake := CylinderMesh.new()
	lake.top_radius = CRATER_RADIUS - 6.0
	lake.bottom_radius = CRATER_RADIUS - 6.0
	lake.height = 0.4
	lake.radial_segments = 32
	var crater := mesh_node(
		"Kratersee",
		lake,
		shader_material(LAVA_SHADER, {"half_width": 30.0, "speed": 0.3}),
		0.0,
		false
	)
	crater.position = Vector3(VOLCANO_CENTRE.x, rim_height() - 15.6, VOLCANO_CENTRE.y)
	crater_light = OmniLight3D.new()
	crater_light.name = "Kraterglut"
	crater_light.light_color = Color("ff8a3a")
	crater_light.light_energy = 3.0
	crater_light.omni_range = 120.0
	crater_light.shadow_enabled = false
	crater_light.position = _summit + Vector3(0, 8, 0)
	add_child(crater_light)
	var top := Vector4(_summit.x, _summit.y, _summit.z, 10.0)
	smoke = puffs(
		"Rauchsaeule", [top], 70, Color(0.34, 0.31, 0.32, 0.6), 26.0, 150.0, 0.045, false, HIGH_WIND
	)
	ash = puffs(
		"Aschewolke",
		[top + Vector4(0, 30, 0, 24)],
		44,
		Color(0.24, 0.21, 0.22, 0.75),
		38.0,
		110.0,
		0.06,
		false,
		HIGH_WIND * 1.4
	)
	ash.material_override.set_shader_parameter("intensity", 0.0)
	# Lavafontäne: ballistisch mit 46 m/s, Gipfelhöhe rund 100 m, fällt in den Krater zurück.
	fountain = puffs(
		"Lavafontaene",
		[Vector4(top.x, top.y, top.z, 16.0)],
		130,
		Color(1.0, 0.52, 0.14, 1.0),
		5.5,
		46.0,
		0.13,
		true,
		Vector3.ZERO,
		9.81
	)
	fountain.material_override.set_shader_parameter("intensity", 0.0)
	var glow := puffs(
		"Kraterfunken",
		[top],
		26,
		Color(1.0, 0.6, 0.25, 1.0),
		2.2,
		15.0,
		0.45,
		true,
		Vector3.ZERO,
		9.81
	)
	glow.material_override.set_shader_parameter("intensity", 0.7)
	_glow_halo(top)
	var sphere := SphereMesh.new()
	sphere.radius = 3.4
	sphere.height = 6.8
	sphere.radial_segments = 12
	sphere.rings = 6
	var hot := material(Color("ff8a2a"), 0.4, 0.0, 5.0)
	for i in range(BOMB_COUNT):
		var bomb := mesh_node("Lavabombe%d" % i, sphere, hot, 0.0, false)
		bomb.visible = false
		bombs.append(bomb)
		# Landestelle: Bergflanke oder Krater, mindestens 70 m von der Fahrbahn entfernt.
		var angle: float = float(i) / float(BOMB_COUNT) * TAU + 0.4
		var reach: float = 46.0 + float(i % 3) * 22.0
		var land := Vector2(
			VOLCANO_CENTRE.x + cos(angle) * reach, VOLCANO_CENTRE.y + sin(angle) * reach
		)
		var flight: float = 3.4 + float(i % 2) * 0.8
		var drop: float = _natural(land.x, land.y) - _summit.y
		# Wurfparabel: v_y so, dass die Bombe nach "flight" Sekunden auf der Flanke ankommt.
		var vy: float = (drop + 0.5 * 9.81 * flight * flight) / flight
		(
			bomb_paths
			. append(
				{
					"start": _summit,
					"velocity":
					Vector3((land.x - _summit.x) / flight, vy, (land.y - _summit.z) / flight),
					"flight": flight,
					"delay": float(i) * 0.9,
				}
			)
		)
	parts["bomb_paths"] = bomb_paths


## Glutschein über dem Krater: ein großes additives Leuchtbild, beim Ausbruch heller.
func _glow_halo(top: Vector4) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.62, 0.3, 1.0))
	gradient.set_color(1, Color(1.0, 0.35, 0.1, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var halo_material := StandardMaterial3D.new()
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_material.disable_fog = true
	halo_material.albedo_texture = texture
	halo_material.albedo_color = Color(1, 1, 1, 0.35)
	var quad := QuadMesh.new()
	quad.size = Vector2(90, 90)
	var halo := mesh_node("Glutschein", quad, halo_material, 0.0, false)
	halo.position = Vector3(top.x, top.y + 12.0, top.z)
	parts["halo"] = halo_material


func _side_crater() -> void:
	# Nebenkrater innen an der Kraterrand-Steilkurve: Lavasee 6 m unter der Fahrbahn.
	var at: Vector3 = world.position_at(1462.0, -40.0)
	var rim := CylinderMesh.new()
	rim.top_radius = 22.0
	rim.bottom_radius = 34.0
	rim.height = 10.0
	rim.radial_segments = 28
	var ring := mesh_node("Nebenkrater", rim, material(Color("3d3132"), 0.95), 0.0)
	ring.position = Vector3(at.x, at.y - 9.0, at.z)
	var lake := CylinderMesh.new()
	lake.top_radius = 19.0
	lake.bottom_radius = 19.0
	lake.height = 0.3
	lake.radial_segments = 28
	var pool := mesh_node(
		"Nebenkrater_Lava",
		lake,
		shader_material(LAVA_SHADER, {"half_width": 19.0, "speed": 0.4}),
		0.0,
		false
	)
	pool.position = Vector3(at.x, at.y - 3.8, at.z)
	puffs(
		"Nebenkrater_Dampf",
		[Vector4(at.x, at.y - 3.5, at.z, 10.0)],
		16,
		Color(0.85, 0.8, 0.78, 0.35),
		10.0,
		36.0,
		0.08,
		false,
		WIND
	)
	parts["side_crater"] = at


# ------------------------------------------------------------------ Bahnhof und Express


func _rail_point(s: float) -> Transform3D:
	var at: Vector3 = world.position_at(s, 19.0)
	var ground: float = maxf(_ground(at.x, at.z), SEA_LEVEL + 0.6)
	var ahead: Vector3 = world.forward(s)
	return Transform3D(
		Basis(Vector3.UP, atan2(-ahead.x, -ahead.z)), Vector3(at.x, ground + 0.35, at.z)
	)


func _station_and_train() -> void:
	var station: Node3D = place(DIR + "station.glb", 48.0, 24.5, 1.0, 0.0, 3.0 - 1.2)
	var sign := Label3D.new()
	sign.name = "Bahnhofsschild"
	sign.font = FONT
	sign.font_size = 72
	sign.pixel_size = 0.012
	sign.text = "BAHNHOF FEUERINSEL"
	sign.modulate = Color("ffe1a8")
	sign.outline_size = 10
	sign.outline_modulate = Color("5a1e16")
	sign.position = Vector3(-0.2, 6.4, 0.0)
	sign.rotation_degrees = Vector3(0, -90, 0)
	sign.visibility_range_end = 160.0
	station.add_child(sign)
	# Gleis: zwei Schienen und Schwellen auf dem Strand, von Portal zu Portal.
	var s: float = 2930.0
	while s < float(world.length) + 255.0:
		var t: Transform3D = _rail_point(s)
		world._prop(
			"box", t.origin + Vector3.UP * 0.05, Vector3(2.6, 0.18, 0.5), Color("5b4030"), t.basis
		)
		if int(s) % 6 == 0:
			for side in [-0.72, 0.72]:
				var a: Transform3D = _rail_point(s)
				var b: Transform3D = _rail_point(s + 6.0)
				var off: Vector3 = a.basis.x * side
				world._beam(
					a.origin + off + Vector3.UP * 0.2,
					b.origin + b.basis.x * side + Vector3.UP * 0.2,
					0.12,
					Color("8d97a2")
				)
		s += 1.5
	for portal_s in [2928.0, 252.0]:
		var t: Transform3D = _rail_point(portal_s)
		var portal: Node3D = module(DIR + "tunnel_portal.glb")
		portal.name = "Bahnportal_%d" % roundi(portal_s)
		portal.transform = Transform3D(
			t.basis.scaled(Vector3.ONE * 0.42), t.origin - Vector3.UP * 0.3
		)
		add_child(portal)
		world._prop(
			"rock",
			t.origin + t.basis.z * (-4.0 if portal_s < 1000 else 4.0) + Vector3.UP * 3.0,
			Vector3(14, 10, 10),
			Color("3b3234")
		)
	for i in range(4):
		var car: Node3D = module(DIR + ("locomotive.glb" if i == 0 else "wagon.glb"), 1.4)
		car.name = "Express%d" % i
		add_child(car)
		train_cars.append(car)
	puffs(
		"ExpressDampf",
		[Vector4(0, 0, 0, 0.3)],
		18,
		Color(0.95, 0.95, 0.95, 0.6),
		2.4,
		9.0,
		0.5,
		false,
		Vector3(0, 0, 3)
	)
	parts["train_steam"] = get_node("ExpressDampf")
	_set_train(train_s)


## Gleis: von 2925 m (Portal am Strand) über die Ziellinie bis 250 m (Portal am Kliff).
func _on_line(s: float) -> bool:
	var w: float = fposmod(s, float(world.length))
	return w > 2925.0 or w < 250.0


func _set_train(s: float) -> void:
	for i in range(train_cars.size()):
		var car_s: float = s - 9.4 * float(i)
		var car: Node3D = train_cars[i]
		car.visible = train_shown and _on_line(car_s)
		if car.visible:
			car.transform = _rail_point(fposmod(car_s, float(world.length)))
	var steam: MultiMeshInstance3D = parts.get("train_steam")
	if steam != null:
		steam.visible = train_cars[0].visible
		var chimney: Transform3D = _rail_point(fposmod(s, float(world.length)))
		steam.global_position = chimney.origin + chimney.basis * Vector3(0, 4.6, -3.3)


# ------------------------------------------------------------------ Geysire


func _geysers() -> void:
	var gate: Dictionary = {}
	for entry in world.get_meta("passage_plan", []):
		if str(entry.id) == "dampfgeysire":
			gate = entry
	if gate.is_empty():
		return
	parts["geyser_gate"] = gate
	var plane: float = float(gate.plane)
	var band := Vector2(float(gate.lat_min), float(gate.lat_max))
	for k in range(2):
		var lateral: float = (band.x + band.y) * 0.5 * (1.0 if k == 0 else -1.0)
		var outer: float = (world.road_width_at(plane) * 0.5 + 2.6) * signf(lateral)
		place(
			DIR + "geyser_vent.glb", plane, outer, 0.8, 0.0, world.position_at(plane, outer).y - 0.6
		)
		var basis: Basis = world.frame(plane)
		var at: Vector3 = world.position_at(plane, lateral) + basis.y * 0.3
		var column := puffs(
			"Geysir%d" % k,
			[Vector4(at.x, at.y, at.z, 2.4)],
			40,
			Color(0.97, 0.97, 1.0, 0.7),
			3.6,
			11.0,
			0.9,
			false,
			Vector3(0.6, 0, 0.2)
		)
		column.material_override.set_shader_parameter("intensity", 0.08)
		geyser_steam.append(column)
	for offset in [-60.0, -30.0, 30.0, 60.0]:
		var at: float = plane + offset
		var side: float = 1.0 if int(offset) % 60 == 0 else -1.0
		var lateral: float = side * (world.road_width_at(at) * 0.5 + 7.0)
		var foot: Vector3 = world.position_at(at, lateral)
		place(DIR + "geyser_vent.glb", at, lateral, 0.6, offset, _ground(foot.x, foot.z) - 0.3)
		puffs(
			"Fumarole_%d" % roundi(at),
			[Vector4(foot.x, _ground(foot.x, foot.z) + 1.0, foot.z, 1.2)],
			12,
			Color(0.92, 0.9, 0.88, 0.45),
			2.6,
			12.0,
			0.25,
			false,
			WIND
		)


# ------------------------------------------------------------------ Rennen


func _race_tick(game: Node, delta: float) -> void:
	var local: float = fposmod(float(game.get("distance")), float(world.length))
	var running: bool = bool(game.get("racing")) and not bool(game.get("finished"))
	_advance_train(game, local, delta, running)
	_advance_eruption(game, local, delta)
	_advance_geysers(float(game.get("elapsed")))


func _advance_train(game: Node, local: float, delta: float, running: bool) -> void:
	if running and not train_started:
		train_started = true
		train_running = true
		if audio != null:
			audio.cue("whistle", -2.0)
	if running and not train_running and local > 2640.0 and local < 2700.0:
		train_running = true
		train_shown = true
		train_s = 2930.0
		train_speed = 18.0
		_announce(
			game, "express", "Der Vulkanexpress kommt! Wer ist zuerst im Ziel?", "whistle", -2.0
		)
	if not train_running:
		return
	train_speed = move_toward(train_speed, 27.0, 4.0 * delta)
	train_s += train_speed * delta
	if train_s > float(world.length):
		train_s -= float(world.length)
	if train_s > 290.0 and train_s < 2900.0:
		train_running = false
		train_shown = false
	_set_train(train_s)


func _advance_eruption(game: Node, local: float, delta: float) -> void:
	if local > float(course.ERUPTION_CALL) and local < float(course.ERUPTION_START):
		_announce(
			game, "grollen", "Der Vulkan grummelt … gleich zeigt er sein Feuerwerk!", "rumble"
		)
	if local > float(course.ERUPTION_START) and local < float(course.ERUPTION_START) + 300.0:
		if _announce(
			game, "ausbruch", "Ausbruch! Ganz weit oben – die Fahrbahn bleibt sicher.", "eruption"
		):
			eruption_time = 0.0
			eruption_count += 1
			parts["eruptions"] = eruption_count
	if eruption_time >= 0.0:
		eruption_time += delta
		_show_eruption(eruption_time)
		if eruption_time > ERUPTION_SECONDS + 4.0:
			eruption_time = -1.0
			_show_eruption(-1.0)


## Ausbruch zur Zeit t (s, -1 = Ruhe): Fontäne, Bomben, Licht, Aschewolke, Flankenlava.
func _show_eruption(t: float) -> void:
	var amount: float = 0.0
	if t >= 0.0:
		amount = (
			smoothstep(0.0, 1.5, t)
			* (1.0 - smoothstep(ERUPTION_SECONDS - 3.0, ERUPTION_SECONDS + 3.0, t))
		)
	fountain.material_override.set_shader_parameter("intensity", amount)
	ash.material_override.set_shader_parameter("intensity", amount * 0.8)
	smoke.material_override.set_shader_parameter("intensity", 1.0 + amount * 0.6)
	crater_light.light_energy = 3.0 + amount * (9.0 + 3.0 * sin(t * 13.0))
	var halo: StandardMaterial3D = parts.get("halo")
	if halo != null:
		halo.albedo_color.a = 0.35 + amount * (0.55 + 0.1 * sin(t * 9.0))
	crater_light.omni_range = 120.0 + amount * 140.0
	flank_material.set_shader_parameter(
		"glow", 1.4 + minf(float(eruption_count), 2.0) * 0.6 + amount * 1.5
	)
	environment.ambient_light_color = Color(LOOK.ambient).lerp(Color("ffb27a"), amount * 0.35)
	for i in range(bombs.size()):
		var path: Dictionary = bomb_paths[i]
		var local: float = t - float(path.delay)
		var flying: bool = t >= 0.0 and local >= 0.0 and local <= float(path.flight)
		bombs[i].visible = flying
		if flying:
			var v: Vector3 = path.velocity
			bombs[i].position = path.start + v * local + Vector3.DOWN * 0.5 * 9.81 * local * local


func _advance_geysers(elapsed: float) -> void:
	if not parts.has("geyser_gate") or geyser_steam.is_empty():
		return
	var gate: Dictionary = parts.geyser_gate
	var state: Dictionary = PASSAGES.swing_state(gate, elapsed)
	var active: Vector2 = PASSAGES.gate_band(gate, state)
	for k in range(geyser_steam.size()):
		var mine: bool = (k == 0) == (active.x < 0.0)
		var level: float = 0.08
		if mine and str(state.phase) == "warn":
			level = 0.25 + 0.2 * float(state.progress)
		elif mine and str(state.phase) == "swing":
			level = 1.0
		geyser_steam[k].material_override.set_shader_parameter("intensity", level)


func celebrate_finish() -> void:
	if eruption_time < 0.0:
		eruption_time = 0.0
		eruption_count += 1
		parts["eruptions"] = eruption_count
