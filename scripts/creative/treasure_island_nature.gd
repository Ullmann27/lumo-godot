class_name TreasureIslandNature
extends RefCounted

## Natur und Bauten der Schatzinsel aus den Blender-Modellen (AdventureKit):
## Gelände mit Gras/Sand/Pfad/Fels-Mischung, Wald, Palmenstrand, Gräser, Farne,
## Felsen, Ruinen, Schloss, Höhle, Leuchtturm, Lager, Wasserfälle, Bach, Meer
## mit Brandung. Nur Optik: Kollision, Hinweise, Fundorte und Regeln bleiben in
## treasure_world.gd / treasure_state.gd unverändert.

const KIT = preload("res://scripts/creative/adventure_kit.gd")
const STATE = preload("res://scripts/creative/treasure_state.gd")
const SEA_LEVEL := -1.65
## Feste Orte der Requisiten (auch für Abstandsregeln beim Streuen).
const CAMP := Vector3(-6.8, 0.0, -2.2)
const LIGHTHOUSE := Vector3(29.5, 0.0, -13.0)
const CAVE := Vector3(-23.0, 0.0, -70.5)
const START_FALLS := Vector3(-12.4, 0.0, 1.4)
const CLUE_FALLS := Vector3(16.6, 0.0, -23.6)
## Bachlauf vom Wasserfall-Teich nach Osten ins Meer.
const STREAM := [
	Vector3(16.0, 0.0, -20.8), Vector3(20.0, 0.0, -19.2), Vector3(24.0, 0.0, -20.6),
	Vector3(28.0, 0.0, -19.4), Vector3(32.0, 0.0, -20.4), Vector3(37.5, 0.0, -20.0)
]

## Bodenprojektion des Kameraversatzes aus treasure_world.gd (CAMERA_OFFSET x/z).
const CAMERA_GROUND := Vector2(3.9, 8.6)

static var _noise: FastNoiseLite


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var t: float = clampf((p - a).dot(b - a) / maxf(0.0001, (b - a).length_squared()), 0.0, 1.0)
	return p.distance_to(a.lerp(b, t))


static func _n() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 71882
		_noise.frequency = 0.045
		_noise.fractal_octaves = 3
	return _noise


## Randmaß wie das bisherige Gelände: 0 im Inneren, 1 an der Wasserkante.
static func rim(x: float, z: float) -> float:
	var nx: float = absf(x) / 37.0
	var nz: float = absf(z + 29.0) / (44.0 if z <= -29.0 else 58.0)
	var radial: float = pow(nx * nx * nx * nx + nz * nz * nz * nz, 0.25)
	return clampf((radial - 0.78) / 0.28, 0.0, 1.0)


static func path_weight(x: float, z: float) -> float:
	var w: float = 1.0 - clampf((absf(x) - 1.9) / 1.4, 0.0, 1.0)
	w *= 1.0 - smoothstep(-66.0, -69.0, z)
	w *= 1.0 - smoothstep(9.0, 12.0, z)
	# Abzweige zu Kristallen und Mondgarten.
	for route in [[Vector2(-2, -33), Vector2(-15, -39)], [Vector2(2, -33), Vector2(16, -48)]]:
		var a: Vector2 = route[0]
		var b: Vector2 = route[1]
		var p := Vector2(x, z)
		var t: float = clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		var d: float = p.distance_to(a.lerp(b, t))
		w = maxf(w, 1.0 - clampf((d - 1.2) / 1.2, 0.0, 1.0))
	# Pfad zum Lager.
	var camp_d: float = Vector2(x, z).distance_to(Vector2(CAMP.x, CAMP.z))
	w = maxf(w, (1.0 - clampf((camp_d - 2.6) / 1.4, 0.0, 1.0)) * 0.8)
	return w


## Bodenhöhe der sichtbaren Oberfläche (die Kollision bleibt die flache Box).
static func height(x: float, z: float) -> float:
	var r := rim(x, z)
	var path := path_weight(x, z)
	var walk := (1.0 - path) * (1.0 - r)
	var wave: float = _n().get_noise_2d(x, z) * 0.26 * walk
	var mound: float = absf(_n().get_noise_2d(x * 0.37, z * 0.37)) * 0.2 * walk
	var y: float = wave + mound - r * r * 2.35
	# Nördlicher Felsrücken hinter dem Schloss (außerhalb des begehbaren Bereichs).
	var ridge: float = smoothstep(-70.5, -75.0, z) * (1.0 - smoothstep(-77.5, -80.0, z))
	var ridge_h: float = 5.5 + _n().get_noise_2d(x * 0.6, 3.0) * 3.0 + (1.0 - absf(x) / 42.0) * 2.0
	y = lerpf(y, ridge_h, ridge)
	# Bachbett leicht vertieft.
	var sd := stream_distance(x, z)
	y -= (1.0 - clampf(sd / 1.8, 0.0, 1.0)) * 0.32
	return y


static func stream_distance(x: float, z: float) -> float:
	var best := 999.0
	var p := Vector2(x, z)
	for i in range(STREAM.size() - 1):
		var a := Vector2(STREAM[i].x, STREAM[i].z)
		var b := Vector2(STREAM[i + 1].x, STREAM[i + 1].z)
		var t: float = clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a.lerp(b, t)))
	return best


static func terrain_mesh() -> ArrayMesh:
	var cols := 84
	var rows := 124
	var origin := Vector3(-44.0, 0.0, -80.0)
	var step := Vector2(88.0 / float(cols - 1), 126.0 / float(rows - 1))
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(cols * rows)
	colors.resize(cols * rows)
	for row in range(rows):
		for col in range(cols):
			var x: float = origin.x + float(col) * step.x
			var z: float = origin.z + float(row) * step.y
			var y := height(x, z)
			var r := rim(x, z)
			var ridge: float = smoothstep(-70.0, -74.0, z) * (1.0 - smoothstep(-77.0, -79.5, z))
			var sand: float = clampf((r - 0.18) * 2.4, 0.0, 1.0) * (1.0 - ridge)
			var path := path_weight(x, z) * (1.0 - sand)
			var rock: float = clampf((r - 0.86) * 5.0, 0.0, 1.0) * 0.0 + ridge * 0.85
			rock = maxf(rock, clampf(1.0 - stream_distance(x, z) / 1.2, 0.0, 1.0) * 0.7)
			var idx: int = row * cols + col
			verts[idx] = Vector3(x, y, z)
			colors[idx] = Color(sand, path, rock, 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows - 1):
		for col in range(cols - 1):
			var a: int = row * cols + col
			var b: int = a + 1
			var c: int = a + cols
			var d: int = c + 1
			for idx in [a, b, c, b, d, c]:
				st.set_color(colors[idx])
				st.set_uv(Vector2(verts[idx].x, verts[idx].z) * 0.1)
				st.add_vertex(verts[idx])
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func terrain_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = KIT.shader("island_terrain")
	for key in ["grass", "sand", "path", "rock"]:
		m.set_shader_parameter(key + "_albedo", KIT.texture(key + "_albedo.jpg"))
		m.set_shader_parameter(key + "_normal", KIT.texture(key + "_normal.jpg"))
	m.set_shader_parameter("water_level", SEA_LEVEL)
	return m


## Freie Stelle? Abstand zu Pfad, Hinweisen, Fundorten und Requisiten.
static func _free(at: Vector3, keep: float, avoid_path := true) -> bool:
	if avoid_path and path_weight(at.x, at.z) > 0.02:
		return false
	var p := Vector2(at.x, at.z)
	for clue in STATE.CLUES:
		var c := Vector2(clue.at.x, clue.at.z)
		if p.distance_to(c) < keep:
			return false
		# Blickachse der Folgekamera frei halten (Kamera steht hinten rechts).
		if _seg_dist(p, c, c + CAMERA_GROUND) < keep * 0.75:
			return false
	for spot in STATE.DISCOVERIES:
		var d := Vector2(spot.at.x, spot.at.z)
		if p.distance_to(d) < keep * 0.7 or _seg_dist(p, d, d + CAMERA_GROUND) < keep * 0.5:
			return false
	for blocked in [CAMP, LIGHTHOUSE, START_FALLS, CLUE_FALLS, Vector3(0, 0, -60), Vector3(0, 0, -31), Vector3(0, 0, 1.35)]:
		var radius := 7.5 if blocked in [Vector3(0, 0, -60), LIGHTHOUSE] else 4.5
		if Vector2(at.x, at.z).distance_to(Vector2(blocked.x, blocked.z)) < radius:
			return false
	if stream_distance(at.x, at.z) < 2.2:
		return false
	return true


static func _on_ground(x: float, z: float, yaw: float, scale: float, sink: float = 0.1) -> Transform3D:
	return KIT.xf(Vector3(x, height(x, z) - sink, z), yaw, scale)


static func apply(root: Node3D) -> void:
	var budget: Dictionary = LumoQuality.budget()
	var density: float = clampf(float(budget.get("decor_density", 1.0)), 0.35, 1.0)
	var tier := LumoQuality.tier()
	var nature := Node3D.new()
	nature.name = "TreasureNature"
	root.add_child(nature)
	_forest(nature, density)
	_beach(nature, density)
	_ground_cover(nature, density, tier)
	_rocks(nature, density)
	_ruins(nature, density)
	_landmarks(nature, density)
	_water(nature, density)


static func _forest(root: Node3D, density: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90211
	var oaks: Dictionary = {"tree_oak_a": [] as Array[Transform3D], "tree_oak_b": [] as Array[Transform3D], "tree_oak_c": [] as Array[Transform3D]}
	var bushes: Dictionary = {"bush_a": [] as Array[Transform3D], "bush_b": [] as Array[Transform3D]}
	var target := int(round(78.0 * density))
	var tries := 0
	var placed := 0
	while placed < target and tries < 2400:
		tries += 1
		var x := rng.randf_range(-33.0, 33.0)
		var z := rng.randf_range(-70.0, 10.0)
		if rim(x, z) > 0.32 or absf(x) < 6.2:
			continue
		# Waldsaum: links dichter, rechts lichter (Blick auf Wasserfall und Strand).
		if x > 0 and rng.randf() < 0.35:
			continue
		if not _free(Vector3(x, 0, z), 4.2):
			continue
		var key: String = ["tree_oak_a", "tree_oak_b", "tree_oak_c"][rng.randi() % 3 if rng.randf() > 0.25 else 2]
		oaks[key].append(_on_ground(x, z, rng.randf() * TAU, rng.randf_range(0.85, 1.25), 0.15))
		placed += 1
		if rng.randf() < 0.7:
			var bkey: String = "bush_a" if rng.randf() < 0.65 else "bush_b"
			var off := Vector3(rng.randf_range(-2.4, 2.4), 0, rng.randf_range(-2.4, 2.4))
			if _free(Vector3(x, 0, z) + off, 3.0):
				bushes[bkey].append(_on_ground(x + off.x, z + off.z, rng.randf() * TAU, rng.randf_range(0.9, 1.6), 0.05))
	# Der alte Sternenbaum am ersten Hinweis: groß, unverwechselbar.
	var star_at: Vector3 = STATE.CLUES[0].at + Vector3(-1.6, 0, -1.8)
	oaks["tree_oak_b"].append(_on_ground(star_at.x, star_at.z, 0.6, 1.55, 0.2))
	for key in oaks:
		var list: Array[Transform3D] = oaks[key]
		KIT.scatter(root, "Forest_" + key, "flora", key, list, true)
	# Büsche säumen den Weg (nah an der Kamera = viel Detail).
	for i in range(int(round(36.0 * density))):
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := 8.0 - float(i) * 2.1 + rng.randf_range(-0.6, 0.6)
		var x := side * rng.randf_range(4.6, 7.0)
		if _free(Vector3(x, 0, z), 3.2):
			var bkey: String = "bush_a" if rng.randf() < 0.7 else "bush_b"
			bushes[bkey].append(_on_ground(x, z, rng.randf() * TAU, rng.randf_range(0.8, 1.3), 0.05))
	for key in bushes:
		var list: Array[Transform3D] = bushes[key]
		KIT.scatter(root, "Forest_" + key, "flora", key, list, true)


static func _beach(root: Node3D, density: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 44120
	var palms := {"palm_a": [] as Array[Transform3D], "palm_b": [] as Array[Transform3D]}
	var count := int(round(30.0 * density))
	var placed := 0
	var tries := 0
	while placed < count and tries < 1600:
		tries += 1
		var x := rng.randf_range(-36.0, 36.0)
		var z := rng.randf_range(-62.0, 16.0)
		var r := rim(x, z)
		if r < 0.22 or r > 0.58 or absf(x) < 6.0:
			continue
		if not _free(Vector3(x, 0, z), 3.0):
			continue
		var key: String = "palm_a" if placed % 2 == 0 else "palm_b"
		# Palmen neigen sich zum Meer.
		var yaw := atan2(x, z + 29.0) + rng.randf_range(-0.6, 0.6)
		palms[key].append(_on_ground(x, z, yaw, rng.randf_range(0.85, 1.15), 0.2))
		placed += 1
	for key in palms:
		var list: Array[Transform3D] = palms[key]
		KIT.scatter(root, "Beach_" + key, "flora", key, list, true)


static func _ground_cover(root: Node3D, density: float, tier: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5521
	var grass: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	var grass_count: int = {"low": 700, "medium": 2600, "high": 5200}.get(tier, 2600)
	var tries := 0
	while grass.size() + flowers.size() < grass_count and tries < grass_count * 4:
		tries += 1
		var x := rng.randf_range(-36.0, 36.0)
		var z := rng.randf_range(-70.0, 15.0)
		var r := rim(x, z)
		if r > 0.25 or z < -70.0:
			continue
		var pw := path_weight(x, z)
		if pw > 0.55 or stream_distance(x, z) < 1.0:
			continue
		# Dichte Büschel in Wegnähe und vorne, lichter am Strand.
		if pw < 0.05 and r > 0.12 and rng.randf() < 0.6:
			continue
		var s := rng.randf_range(0.7, 1.35) * (1.0 - pw * 0.6)
		var t := _on_ground(x, z, rng.randf() * TAU, s, 0.04)
		if rng.randf() < 0.14:
			flowers.append(t)
		else:
			grass.append(t)
	# Mondgarten: goldene Blumenwiese.
	for i in range(int(round(60.0 * density))):
		var at: Vector3 = STATE.CLUES[4].at + Vector3(rng.randf_range(-4.5, 4.5), 0, rng.randf_range(-4.5, 4.5))
		flowers.append(_on_ground(at.x, at.z, rng.randf() * TAU, rng.randf_range(0.8, 1.2), 0.04))
	var fern_count := int(round(110.0 * density))
	tries = 0
	while ferns.size() < fern_count and tries < 3000:
		tries += 1
		var x := rng.randf_range(-34.0, 34.0)
		var z := rng.randf_range(-70.0, 14.0)
		if rim(x, z) > 0.2 or path_weight(x, z) > 0.0 or absf(x) < 3.6:
			continue
		if not _free(Vector3(x, 0, z), 2.0):
			continue
		ferns.append(_on_ground(x, z, rng.randf() * TAU, rng.randf_range(0.9, 1.8), 0.05))
	var reach := 48.0 if tier == "low" else 70.0
	KIT.scatter(root, "GroundGrass", "flora", "grass_tuft", grass, false, reach)
	KIT.scatter(root, "GroundFlowers", "flora", "grass_flowers", flowers, false, reach)
	KIT.scatter(root, "GroundFerns", "flora", "fern", ferns, tier == "high", reach + 10.0)


static func _rocks(root: Node3D, density: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6612
	var sets := {"rock_a": [] as Array[Transform3D], "rock_b": [] as Array[Transform3D], "rock_c": [] as Array[Transform3D]}
	var keys := ["rock_a", "rock_b", "rock_c"]
	var count := int(round(70.0 * density))
	var tries := 0
	var placed := 0
	while placed < count and tries < 3000:
		tries += 1
		var x := rng.randf_range(-38.0, 38.0)
		var z := rng.randf_range(-72.0, 17.0)
		var r := rim(x, z)
		# Felsen sammeln sich am Ufer (Brandungsfelsen) und verstreut im Wald.
		if r < 0.45 and rng.randf() < 0.7:
			continue
		if r > 0.98:
			continue
		if not _free(Vector3(x, 0, z), 3.0):
			continue
		var s := rng.randf_range(0.5, 1.6) * (1.4 if r > 0.6 else 1.0)
		sets[keys[placed % 3]].append(_on_ground(x, z, rng.randf() * TAU, s, 0.25 * s))
		placed += 1
	# Steine entlang des Hauptwegs als Wegkante.
	for i in range(int(round(52.0 * density))):
		var side := -1.0 if i % 2 else 1.0
		var z := 9.0 - float(i) * 1.45 + rng.randf_range(-0.3, 0.3)
		if z < -64.0:
			break
		var x := side * rng.randf_range(2.6, 3.3)
		if absf(z + 31.0) < 2.5 or absf(z - 1.35) < 1.8:
			continue
		sets[keys[i % 3]].append(_on_ground(x, z, rng.randf() * TAU, rng.randf_range(0.18, 0.34), 0.05))
	for key in sets:
		var list: Array[Transform3D] = sets[key]
		KIT.scatter(root, "Rocks_" + key, "ruins", key, list, true)
	# Felsrücken im Norden und Klippen am Meer.
	var cliffs: Array[Transform3D] = []
	for i in range(11):
		var x := -40.0 + float(i) * 8.0 + rng.randf_range(-1.5, 1.5)
		cliffs.append(KIT.xf(Vector3(x, height(x, -76.0) - 2.0, -76.0 + rng.randf_range(-2, 2)), rng.randf() * TAU, rng.randf_range(1.4, 2.2)))
	for at in [Vector3(-36, 0, -40), Vector3(37, 0, -50), Vector3(-34, 0, 10), Vector3(36, 0, 6), Vector3(-38, 0, -18)]:
		cliffs.append(KIT.xf(Vector3(at.x, SEA_LEVEL - 1.2, at.z), rng.randf() * TAU, rng.randf_range(0.9, 1.3)))
	KIT.scatter(root, "Cliffs", "ruins", "boulder_cliff", cliffs, true)


static func _ruins(root: Node3D, density: float) -> void:
	var cols: Array[Transform3D] = []
	var broken: Array[Transform3D] = []
	var fallen: Array[Transform3D] = []
	var walls: Array[Transform3D] = []
	var arches: Array[Transform3D] = []
	# Säulengang vor dem Schloss (begleitet den Weg, kein Hindernis auf dem Pfad).
	for i in range(5):
		var z := -42.0 - float(i) * 3.6
		for side in [-1.0, 1.0]:
			var x: float = side * 5.2
			if (i + int(side)) % 3 == 0:
				broken.append(_on_ground(x, z, float(i) * 0.7, 1.0, 0.05))
			else:
				cols.append(_on_ground(x, z, float(i) * 0.4, 1.0, 0.05))
	fallen.append(_on_ground(8.6, -45.6, 0.4, 1.0, 0.25))
	fallen.append(_on_ground(-8.4, -53.0, 2.1, 1.0, 0.25))
	fallen.append(_on_ground(-6.0, -33.6, 1.3, 0.8, 0.25))
	walls.append(_on_ground(-11.0, -55.0, 0.35, 1.0, 0.05))
	walls.append(_on_ground(11.5, -57.5, -0.4, 0.9, 0.05))
	walls.append(_on_ground(-20.5, -46.0, 1.4, 0.85, 0.05))
	walls.append(_on_ground(22.0, -30.0, -1.2, 0.8, 0.05))
	arches.append(_on_ground(-9.4, -24.5, 0.9, 0.9, 0.05))
	arches.append(_on_ground(9.5, -64.5, -0.3, 1.0, 0.05))
	# Schatzkammer: Säulen um die Truhe.
	for at in [Vector3(-3.6, 0, -66.8), Vector3(3.6, 0, -66.8), Vector3(-3.6, 0, -63.4), Vector3(3.6, 0, -63.4)]:
		cols.append(_on_ground(at.x, at.z, 0.0, 0.8, 0.02))
	walls.append(_on_ground(0.0, -69.6, 0.0, 1.05, 0.05))
	KIT.scatter(root, "RuinColumns", "ruins", "ruin_column", cols, true)
	KIT.scatter(root, "RuinColumnsBroken", "ruins", "ruin_column_broken", broken, true)
	KIT.scatter(root, "RuinColumnsFallen", "ruins", "ruin_column_fallen", fallen, true)
	KIT.scatter(root, "RuinWalls", "ruins", "ruin_wall", walls, true)
	KIT.scatter(root, "RuinArches", "ruins", "ruin_arch", arches, true)


static func _landmarks(root: Node3D, density: float) -> void:
	# Schloss (Front zeigt zum Spieler, +Z).
	KIT.place(root, "StarCastle", "ruins", "star_castle", KIT.xf(Vector3(0, -0.05, -60.5), PI, 1.0))
	KIT.place(root, "Lighthouse", "props", "lighthouse", KIT.xf(Vector3(LIGHTHOUSE.x, height(LIGHTHOUSE.x, LIGHTHOUSE.z) - 0.2, LIGHTHOUSE.z), 0.4, 0.95))
	var beacon := OmniLight3D.new()
	beacon.name = "LighthouseGlow"
	beacon.position = LIGHTHOUSE + Vector3(0, 15.6, 0)
	beacon.light_color = Color("ffd890")
	beacon.light_energy = 1.4
	beacon.omni_range = 9.0
	root.add_child(beacon)
	var rocks_lh: Array[Transform3D] = []
	for i in range(6):
		var a := float(i) / 6.0 * TAU
		rocks_lh.append(KIT.xf(LIGHTHOUSE + Vector3(cos(a) * 4.2, -0.6, sin(a) * 4.2), a, 0.9 + 0.2 * float(i % 3)))
	KIT.scatter(root, "LighthouseRocks", "ruins", "rock_c", rocks_lh, true)
	# Höhle im nördlichen Felsrücken.
	KIT.place(root, "TreasureCave", "ruins", "cave_entrance", KIT.xf(Vector3(CAVE.x, -0.1, CAVE.z), PI + 0.25, 1.0))
	# Lager: Zelt, Feuer, Kisten, Fässer.
	KIT.place(root, "CampTent", "props", "tent", KIT.xf(CAMP + Vector3(-3.2, 0.0, -1.8), 0.9, 1.15))
	KIT.place(root, "CampFire", "props", "campfire", KIT.xf(CAMP + Vector3(0.2, 0.02, 0.4), 0.3, 1.0))
	var fire := OmniLight3D.new()
	fire.name = "CampFireLight"
	fire.position = CAMP + Vector3(0.2, 1.1, 0.4)
	fire.light_color = Color("ff9a48")
	fire.light_energy = 2.2
	fire.omni_range = 6.5
	root.add_child(fire)
	var crates: Array[Transform3D] = [
		KIT.xf(CAMP + Vector3(-1.6, 0, -3.6), 0.3, 0.9), KIT.xf(CAMP + Vector3(-0.7, 0, -3.9), 1.0, 0.7),
		KIT.xf(CAMP + Vector3(-1.2, 0.9, -3.7), 0.6, 0.6)
	]
	KIT.scatter(root, "CampCrates", "props", "crate", crates, true)
	var barrels: Array[Transform3D] = [KIT.xf(CAMP + Vector3(2.6, 0, -2.8), 0.0, 1.0), KIT.xf(CAMP + Vector3(3.3, 0, -2.1), 0.6, 0.9)]
	KIT.scatter(root, "CampBarrels", "props", "barrel", barrels, true)
	# Wegweiser an Kreuzungen.
	var posts: Array[Transform3D] = [
		KIT.xf(Vector3(3.6, 0, 3.2), -0.4, 1.0), KIT.xf(Vector3(-3.6, 0, -17.5), 2.6, 1.0), KIT.xf(Vector3(4.0, 0, -45.5), -0.2, 1.0)
	]
	KIT.scatter(root, "Signposts", "props", "signpost", posts, true)


static func _ribbon(points: Array, widths: Array, rise: Array = []) -> ArrayMesh:
	## Band entlang Punkten; UV.x quer, UV.y entlang (in Metern).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_v := 0.0
	for i in range(points.size()):
		var p: Vector3 = points[i]
		var d: Vector3 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)])
		d.y = 0.0
		var side := Vector3(-d.z, 0.0, d.x).normalized() * float(widths[i]) * 0.5
		if i > 0:
			along += p.distance_to(points[i - 1])
		var l := p - side
		var r := p + side
		if i > 0:
			for v in [[prev_l, 0.0, prev_v], [prev_r, 1.0, prev_v], [r, 1.0, along], [prev_l, 0.0, prev_v], [r, 1.0, along], [l, 0.0, along]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v[1], v[2]))
				st.add_vertex(v[0])
		prev_l = l
		prev_r = r
		prev_v = along
	st.generate_tangents()
	return st.commit()


static func _fall_mesh(top: Vector3, bottom: Vector3, width: float, bulge: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 10
	var dir := Vector3(bottom.x - top.x, 0, bottom.z - top.z).normalized()
	var side := Vector3(-dir.z, 0, dir.x) * width * 0.5
	var pts: Array[Vector3] = []
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := top.lerp(bottom, t)
		p += dir * bulge * sin(t * PI * 0.9)
		pts.append(p)
	var along := 0.0
	for i in range(steps):
		var a := pts[i]
		var b := pts[i + 1]
		var va := along
		along += a.distance_to(b)
		var n := (dir + Vector3.UP * 0.2).normalized()
		for v in [[a - side, 0.0, va], [a + side, 1.0, va], [b + side * 1.12, 1.0, along], [a - side, 0.0, va], [b + side * 1.12, 1.0, along], [b - side * 1.12, 0.0, along]]:
			st.set_normal(n)
			st.set_uv(Vector2(v[1], v[2] / maxf(0.01, top.distance_to(bottom))))
			st.add_vertex(v[0])
	st.generate_tangents()
	return st.commit()


static func _water_material(speed: float, stretch: float, foam: float, color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = KIT.shader("flowing_water")
	m.set_shader_parameter("streak_tex", KIT.texture("water_normal.jpg"))
	m.set_shader_parameter("wave_normal", KIT.texture("water_normal.jpg"))
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("stretch", stretch)
	m.set_shader_parameter("foam_bottom", foam)
	m.set_shader_parameter("water_color", color)
	return m


static func _water(root: Node3D, density: float) -> void:
	# Meer mit Wellen-Normalen und Fresnel.
	var sea := MeshInstance3D.new()
	sea.name = "TreasureSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(320, 320)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	sea.mesh = plane
	sea.position = Vector3(0.0, SEA_LEVEL, -22.0)
	var sm := ShaderMaterial.new()
	sm.shader = KIT.shader("sea")
	sm.set_shader_parameter("wave_normal", KIT.texture("water_normal.jpg"))
	sea.material_override = sm
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sea)
	# Brandungsband entlang der Küstenlinie (dort, wo das Gelände das Meer schneidet).
	var shore := MeshInstance3D.new()
	shore.name = "TreasureSurf"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 160
	var ring_in: Array[Vector3] = []
	var ring_out: Array[Vector3] = []
	for i in range(steps + 1):
		var a := float(i) / float(steps) * TAU
		var dir := Vector2(cos(a), sin(a))
		# Schnittpunkt Gelände/Meeresspiegel entlang des Strahls suchen.
		var lo := 20.0
		var hi := 70.0
		for _k in range(18):
			var mid := (lo + hi) * 0.5
			var px := dir.x * mid
			var pz := -29.0 + dir.y * mid
			if height(px, pz) > SEA_LEVEL:
				lo = mid
			else:
				hi = mid
		var edge := Vector3(dir.x * lo, SEA_LEVEL + 0.06, -29.0 + dir.y * lo)
		ring_in.append(edge + Vector3(dir.x, 0, dir.y) * -0.8 + Vector3.UP * 0.04)
		ring_out.append(edge + Vector3(dir.x, 0, dir.y) * 3.4)
	for i in range(steps):
		var u0 := float(i) / float(steps) * 12.0
		var u1 := float(i + 1) / float(steps) * 12.0
		for v in [[ring_out[i], u0, 0.0], [ring_out[i + 1], u1, 0.0], [ring_in[i + 1], u1, 1.0], [ring_out[i], u0, 0.0], [ring_in[i + 1], u1, 1.0], [ring_in[i], u0, 1.0]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v[1], v[2]))
			st.add_vertex(v[0])
	shore.mesh = st.commit()
	var fm := ShaderMaterial.new()
	fm.shader = KIT.shader("foam")
	fm.set_shader_parameter("noise_tex", KIT.texture("water_normal.jpg"))
	shore.material_override = fm
	shore.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shore)
	# Wasserfälle: Felsklippe + fallendes Band + Teich + Gischt.
	_falls(root, START_FALLS, 4.8, 2.6, Vector3(0, 0, 1), density, "Start")
	_falls(root, CLUE_FALLS, 6.4, 3.2, Vector3(-0.35, 0, 1).normalized(), density, "Clue")
	# Bach zum Meer.
	var pts: Array = []
	var widths: Array = []
	for i in range(STREAM.size()):
		var p: Vector3 = STREAM[i]
		pts.append(Vector3(p.x, height(p.x, p.z) + 0.12 if i < STREAM.size() - 1 else SEA_LEVEL + 0.05, p.z))
		widths.append(1.9 + 0.3 * float(i % 2))
	var stream := MeshInstance3D.new()
	stream.name = "TreasureStream"
	stream.mesh = _ribbon(pts, widths)
	stream.material_override = _water_material(0.9, 3.0, 0.0, Color(0.32, 0.6, 0.72, 0.82))
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(stream)
	var stream_stones: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in range(int(round(26.0 * density))):
		var t := rng.randf()
		var seg := mini(int(t * float(STREAM.size() - 1)), STREAM.size() - 2)
		var p: Vector3 = STREAM[seg].lerp(STREAM[seg + 1], fmod(t * float(STREAM.size() - 1), 1.0))
		var off := rng.randf_range(1.0, 1.6) * (-1.0 if i % 2 else 1.0)
		stream_stones.append(_on_ground(p.x + rng.randf_range(-0.5, 0.5), p.z + off, rng.randf() * TAU, rng.randf_range(0.2, 0.42), 0.08))
	KIT.scatter(root, "StreamStones", "ruins", "rock_b", stream_stones, true)


static func _falls(root: Node3D, at: Vector3, drop: float, width: float, facing: Vector3, density: float, tag: String) -> void:
	var cliff: Array[Transform3D] = []
	var back := -facing
	var side := Vector3(-facing.z, 0, facing.x)
	cliff.append(KIT.xf(at + back * 2.6 + Vector3.UP * (drop * 0.25), atan2(facing.x, facing.z), drop / 5.0))
	cliff.append(KIT.xf(at + back * 2.0 + side * 3.4 + Vector3.UP * (drop * 0.1), atan2(facing.x, facing.z) + 1.1, drop / 6.5))
	cliff.append(KIT.xf(at + back * 2.2 - side * 3.6 + Vector3.UP * (drop * 0.08), atan2(facing.x, facing.z) - 0.9, drop / 6.8))
	KIT.scatter(root, "FallsCliff" + tag, "ruins", "boulder_cliff", cliff, true)
	var top := at + back * 0.6 + Vector3.UP * (drop + 0.2)
	var bottom := at + facing * 0.9 + Vector3.UP * 0.05
	var fall := MeshInstance3D.new()
	fall.name = "Waterfall" + tag
	fall.mesh = _fall_mesh(top, bottom, width, 0.9)
	fall.material_override = _water_material(1.8, 1.0, 1.0, Color(0.6, 0.84, 0.94, 0.84))
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fall)
	var pool := MeshInstance3D.new()
	pool.name = "FallsPool" + tag
	var disc := CylinderMesh.new()
	disc.top_radius = width * 1.25
	disc.bottom_radius = width * 1.25
	disc.height = 0.05
	disc.radial_segments = 28
	pool.mesh = disc
	pool.position = at + facing * 1.6 + Vector3.UP * 0.06
	pool.scale = Vector3(1.0, 1.0, 0.8)
	pool.material_override = _water_material(0.25, 6.0, 0.0, Color(0.24, 0.5, 0.62, 0.86))
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pool)
	if density > 0.5:
		var spray := KIT.sparkle_particles("FallsSpray" + tag, int(round(36.0 * density)), Color(0.9, 0.96, 1.0, 0.55), width * 0.5, 1.6)
		spray.position = bottom + Vector3.UP * 0.4
		var proc: ParticleProcessMaterial = spray.process_material
		proc.initial_velocity_min = 0.6
		proc.initial_velocity_max = 1.6
		proc.gravity = Vector3(0, -1.2, 0)
		proc.scale_min = 2.0
		proc.scale_max = 4.5
		root.add_child(spray)
