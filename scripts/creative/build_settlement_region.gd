extends Node3D
## Die große Dorfkarte: Tal mit Hügeln, Fluss, Seen, Küste und Bergen aus der
## Höhenkarte (build_village_terrain.gd). Die Stadt des Kindes wächst in Ringen
## bis 65 × 65 Bauplätze (4.225); der alte 33 × 33 Ortsteil behält alle
## Grundstücks-IDs und Lagen, die ersten 25 Felder liegen exakt wie früher.
## Vegetation, Felsen und Landmarken sind gebündelt (MultiMesh je Gebiet).
const KIT = preload("res://scripts/creative/creative_kit.gd")
const DAY = preload("res://scripts/creative/creative_nextgen_environment.gd")
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const LANDSCAPE = preload("res://scripts/creative/build_village_landscape.gd")
const ART = preload("res://scripts/creative/build_village_art.gd")
const SPACING := 5.3
const TOWN_CENTER := 100.0
const MAX_PLOTS := 4225
## Größter Ring (65 × 65 = Ring 32). Der klassische Wettbau-Ortsteil am
## Ostufer bleibt 33 × 33 (Ring 16).
const MAX_RING := 32
const RIVAL_RING := 16
const HALF_EXTENT := 94.0
## Halbe Kantenlänge der ganzen Stadt des Kindes (Ring 32 + Rand).
const PLAYER_HALF_EXTENT := 176.0
const CHUNK_SIZE := 47.0
const WILD_CHUNK := 160.0
const BRIDGES := [-58.3, 0.0, 58.3]
## Pro Qualitätsstufe: Vegetationsdichte, Sichtweiten, Wiesendetails.
const BUDGETS := {
	"low": {"trees": 0.3, "near": 95.0, "meadow": 0.0, "rocks": 0.5, "shadows_far": false},
	"medium": {"trees": 0.62, "near": 135.0, "meadow": 0.45, "rocks": 0.8, "shadows_far": false},
	"high": {"trees": 1.0, "near": 185.0, "meadow": 1.0, "rocks": 1.0, "shadows_far": true},
}
var _kit := KIT.new()
var _chunks: Array[Node3D] = []
var _wild: Array[Node3D] = []
var _built := false
var _last_focus := Vector3(INF, INF, INF)
var _road_layers: Dictionary = {}
var _garden_groups: Dictionary = {}
var _unlocked_counts: Dictionary = {}
var _built_plots: Dictionary = {false: [], true: []}
var _far_bank_open := false
var landscape: Node3D
var tier := "medium"
var budget: Dictionary = BUDGETS.medium
var animated: Array[Node3D] = []
var bridge_decks: Array[Vector3] = []


static func plot_coordinate(index: int) -> Vector2i:
	if index < 0 or index >= MAX_PLOTS:
		return Vector2i(10000, 10000)
	if index < 9:
		return Vector2i(index % 3 - 1, index / 3 - 1)
	var ring := 2
	while index >= (ring * 2 + 1) * (ring * 2 + 1):
		ring += 1
	var offset := index - (ring * 2 - 1) * (ring * 2 - 1)
	if offset < ring * 2:
		return Vector2i(ring, offset - ring + 1)
	offset -= ring * 2
	if offset < ring * 2 - 1:
		return Vector2i(offset - ring + 1, ring)
	offset -= ring * 2 - 1
	if offset < ring * 2 + 1:
		return Vector2i(-ring, offset - ring)
	offset -= ring * 2 + 1
	return Vector2i(offset - ring + 1, -ring)


## Inverse of plot_coordinate for taps on the terrain itself.
static func plot_index_at(coordinate: Vector2i) -> int:
	var ring := maxi(absi(coordinate.x), absi(coordinate.y))
	if ring > MAX_RING:
		return -1
	if ring <= 1:
		return (coordinate.y + 1) * 3 + coordinate.x + 1
	var base := (ring * 2 - 1) * (ring * 2 - 1)
	if coordinate.x == ring and coordinate.y > -ring:
		return base + coordinate.y + ring - 1
	base += ring * 2
	if coordinate.y == ring and coordinate.x < ring and coordinate.x > -ring:
		return base + coordinate.x + ring - 1
	base += ring * 2 - 1
	if coordinate.x == -ring:
		return base + coordinate.y + ring
	base += ring * 2 + 1
	return base + coordinate.x + ring - 1


static func plot_position(index: int, opponent := false) -> Vector3:
	var coordinate := plot_coordinate(index)
	var x := (TOWN_CENTER if opponent else -TOWN_CENTER) + coordinate.x * SPACING
	var z := coordinate.y * SPACING
	return Vector3(x, TERRAIN.height(x, z) + 0.03, z)


static func ground(x: float, z: float) -> float:
	return TERRAIN.height(x, z)


static func extent_for_plots(count: int) -> float:
	var bounded := clampi(count, 1, MAX_PLOTS)
	var furthest := 1
	for index in range(bounded):
		var coordinate := plot_coordinate(index)
		furthest = maxi(furthest, maxi(absi(coordinate.x), absi(coordinate.y)))
	return (float(furthest) + 0.8) * SPACING


func build_landscape(mode := "settlement") -> void:
	if _built:
		return
	_built = true
	name = "LivingVillageRegion"
	tier = LumoQuality.tier()
	budget = BUDGETS.get(tier, BUDGETS.medium)
	landscape = LANDSCAPE.new()
	add_child(landscape)
	landscape.build(tier)
	for side in [false, true]:
		_build_bank(side)
	_build_river()
	for z in BRIDGES:
		_build_bridge(z)
	_build_waterfront(false)
	_build_waterfront(true)
	_build_wilderness()
	_build_landmarks()
	_title("LUMOS WIESENSTADT", Vector3(-TOWN_CENTER, 0, -91.0), Color("fff3d2"))
	_title(
		"MIRAS NACHBARDORF" if mode == "rival" else "DAS NACHBARDORF",
		Vector3(TOWN_CENTER, 0, -91.0),
		Color("ffd5af")
	)
	set_meta("max_plots_per_town", MAX_PLOTS)
	set_meta("land_dimensions", Vector2(HALF_EXTENT * 2.0, HALF_EXTENT * 2.0))
	set_meta("map_dimensions", TERRAIN.size())
	set_meta("scenery_chunks", _chunks.size())
	set_meta("wilderness_chunks", _wild.size())
	set_meta("blocked_plots_player", TERRAIN.blocked_count(false))
	set_meta("blocked_plots_neighbor", TERRAIN.blocked_count(true))
	update_focus(Vector3(-TOWN_CENTER, 0, 0))


func _build_bank(opponent: bool) -> void:
	var center := TOWN_CENTER if opponent else -TOWN_CENTER
	var bank := StaticBody3D.new()
	bank.name = "NeighborLand" if opponent else "PlayerLand"
	add_child(bank)
	if not opponent and TERRAIN.available():
		bank.add_child(landscape.collision_shape())
	elif not TERRAIN.available():
		var side := _kit.box(
			bank, Vector3(center, -1.4, 0), Vector3(HALF_EXTENT * 2.0, 2.8, HALF_EXTENT * 2.0), Color("c3ad80")
		)
		side.material_override = DAY.bank_material()
		_kit.collision(bank, Vector3(center, -1.4, 0), Vector3(HALF_EXTENT * 2.0, 2.8, HALF_EXTENT * 2.0))
	# Kept as an (empty) presentation layer: streets are painted into the
	# terrain now, so they follow every hill instead of floating above it.
	var road_layer := MultiMeshInstance3D.new()
	road_layer.name = "VillageLanesNeighbor" if opponent else "VillageLanesPlayer"
	add_child(road_layer)
	_road_layers[opponent] = road_layer
	var garden := Node3D.new()
	garden.name = "WildflowerBeltNeighbor" if opponent else "WildflowerBeltPlayer"
	add_child(garden)
	_garden_groups[opponent] = garden
	var hill_lists := {"rock_a": [], "rock_b": [], "rock_c": [], "tree_fir": [], "bush": []}
	var count := ceili(_half(opponent) * 2.0 / CHUNK_SIZE)
	var start := -float(count) * CHUNK_SIZE * 0.5
	for z_index in range(count):
		for x_index in range(count):
			var chunk := Node3D.new()
			chunk.name = "District_%s_%d_%d" % ["neighbor" if opponent else "home", x_index, z_index]
			chunk.position = Vector3(
				center + start + CHUNK_SIZE * (x_index + 0.5), 0, start + CHUNK_SIZE * (z_index + 0.5)
			)
			add_child(chunk)
			_chunks.append(chunk)
			_decorate_chunk(chunk, opponent, hill_lists)
	# One batch per kind and town: rocky hills cost five draw calls in total.
	var hills := Node3D.new()
	hills.name = "DistrictHills" + ("Neighbor" if opponent else "Player")
	add_child(hills)
	for kind in hill_lists:
		ART.batch(hills, "Hill_" + kind, kind, hill_lists[kind], 260.0, kind != "bush")
	set_unlocked_plots(9, opponent)


## Halbe Kantenlänge des ganzen Ortsteils einer Seite (größter Ring + Rand).
static func _half(opponent: bool) -> float:
	return HALF_EXTENT if opponent else PLAYER_HALF_EXTENT


## Erst die Lieferbrücke macht das andere Flussufer zu Bauland.
func set_far_bank_open(open: bool) -> void:
	if open == _far_bank_open:
		return
	_far_bank_open = open
	_paint(false)


## Only the actually unlocked district is drawn. This changes no plot IDs,
## ownership, building capacity, saved data or unlock thresholds.
func set_unlocked_plots(count: int, opponent := false) -> void:
	if not _road_layers.has(opponent):
		return
	var bounded := clampi(count, 1, MAX_PLOTS)
	if int(_unlocked_counts.get(opponent, -1)) == bounded:
		return
	_unlocked_counts[opponent] = bounded
	var ring := _ring(bounded)
	set_meta("road_lines_neighbor" if opponent else "road_lines_player", (ring + 1) * 4)
	_paint(opponent)
	_replant_village_edge(bounded, opponent)


func _ring(count: int) -> int:
	var ring := 1
	for index in range(count):
		var point := plot_coordinate(index)
		ring = maxi(ring, maxi(absi(point.x), absi(point.y)))
	return ring


## Which plots carry a building: dirt yards and lanes are painted around them.
func set_built_plots(plots: Array, opponent := false) -> void:
	var sorted := plots.duplicate()
	sorted.sort()
	if sorted == _built_plots[opponent]:
		return
	_built_plots[opponent] = sorted
	_paint(opponent)


func _paint(opponent: bool) -> void:
	if landscape == null or not _unlocked_counts.has(opponent):
		return
	var count: int = _unlocked_counts[opponent]
	var unlocked: Array = []
	var built: Dictionary = {}
	for index in range(count):
		if TERRAIN.plot_blocked(index, opponent):
			continue
		if not opponent and not _far_bank_open and TERRAIN.plot_far_bank(index):
			continue
		var at := plot_position(index, opponent)
		unlocked.append(Vector2(at.x, at.z))
	for index in _built_plots[opponent]:
		var at := plot_position(int(index), opponent)
		built[Vector2(at.x, at.z)] = true
	landscape.paint_town(TOWN_CENTER if opponent else -TOWN_CENTER, unlocked, built, _ring(count))


func _place(x: float, z: float, scale: float, yaw: float, sink := 0.05) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	return Transform3D(basis, Vector3(x, TERRAIN.height(x, z) - sink, z))


## Batched scenery around the unlocked town. Trees and wildflowers move to
## the NEW meadow border when a region is expanded; no plant is left on a
## building plot and no simulated residents or collision objects are made.
func _replant_village_edge(count: int, opponent: bool) -> void:
	var group: Node3D = _garden_groups[opponent]
	for node in group.get_children():
		group.remove_child(node)
		node.queue_free()
	var distance := extent_for_plots(count) + 5.0
	var center := TOWN_CENTER if opponent else -TOWN_CENTER
	var lists := {"tree_oak": [], "tree_birch": [], "bush": [], "flowers": [], "grass_tuft": [], "rock_c": []}
	for index in range(110):
		var angle := float(index) * 2.3999632 + (0.4 if opponent else 0.0)
		var radius := distance + float(index % 6) * 2.2
		var x := center + sin(angle) * radius
		var z := cos(angle) * radius
		if maxf(absf(x - center), absf(z)) > _half(opponent) - 3.0:
			continue
		if TERRAIN.is_water(x, z) or absf(x - TERRAIN.river_center(z)) < 13.0:
			continue
		var kind := "flowers"
		match index % 5:
			0:
				kind = "tree_oak" if index % 3 else "tree_birch"
			1:
				kind = "bush"
			3:
				kind = "grass_tuft" if index % 2 else "rock_c"
		lists[kind].append(_place(x, z, 0.8 + float(index % 4) * 0.12, angle))
	var total := 0
	for kind in lists:
		ART.batch(group, "Meadow_" + kind, kind, lists[kind], 0.0, kind.begins_with("tree"))
		total += lists[kind].size()
	set_meta("garden_instances_neighbor" if opponent else "garden_instances_player", total)


## Rocky hills and the district's outer meadow: firs, rocks and bushes on the
## cells that are NOT buildable, so the rule is visible in the world.
func _decorate_chunk(chunk: Node3D, opponent: bool, lists: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(chunk.name)
	var half := CHUNK_SIZE * 0.5
	var center := TOWN_CENTER if opponent else -TOWN_CENTER
	for index in range(int(46 * float(budget.rocks))):
		var x := chunk.position.x + rng.randf_range(-half, half)
		var z := chunk.position.z + rng.randf_range(-half, half)
		var coordinate := Vector2i(roundi((x - center) / SPACING), roundi(z / SPACING))
		var plot := plot_index_at(coordinate)
		var ring := RIVAL_RING if opponent else MAX_RING
		var outside := maxf(absf(x - center), absf(z)) > (float(ring) + 0.5) * SPACING
		if not outside and (plot < 0 or not TERRAIN.plot_blocked(plot, opponent)):
			continue
		if TERRAIN.is_water(x, z) or absf(x - TERRAIN.river_center(z)) < 9.0:
			continue
		var steep := TERRAIN.steepness(x, z)
		var kind := "bush"
		if steep > 0.12 or index % 3 == 0:
			kind = ["rock_a", "rock_b", "rock_c"][index % 3]
		elif index % 2 == 0:
			kind = "tree_fir"
		var scale := rng.randf_range(0.7, 1.4) if kind.begins_with("rock") else rng.randf_range(0.8, 1.2)
		lists[kind].append(_place(x, z, scale, rng.randf() * TAU, 0.2 if kind.begins_with("rock") else 0.05))


## Wälder, Felsen und Wiesen außerhalb der Ortsteile, in groben Gebieten
## gebündelt: nahe Fassung mit Blattwerk, ferne Fassung als einfache Krone.
func _build_wilderness() -> void:
	if not TERRAIN.available():
		return
	var origin := TERRAIN.origin()
	var extent := TERRAIN.size()
	var spacing := 7.0 / sqrt(maxf(0.05, float(budget.trees)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var cells: Dictionary = {}
	var z := origin.y + 4.0
	while z < origin.y + extent.y - 4.0:
		var x := origin.x + 4.0
		while x < origin.x + extent.x - 4.0:
			var px := x + rng.randf_range(-0.45, 0.45) * spacing
			var pz := z + rng.randf_range(-0.45, 0.45) * spacing
			x += spacing
			# Kein Wald auf Bauland: weder in der Stadt des Kindes (bis Ring 32)
			# noch im alten Ostufer-Ortsteil noch in den Nachbarstädten.
			if absf(px + TOWN_CENTER) < PLAYER_HALF_EXTENT and absf(pz) < PLAYER_HALF_EXTENT:
				continue
			if absf(px - TOWN_CENTER) < 92.0 and absf(pz) < 92.0:
				continue
			if not TERRAIN.territory_at(px, pz).is_empty():
				continue
			var h := TERRAIN.height(px, pz)
			if h < TERRAIN.WATER_LEVEL + 0.7 or absf(px - TERRAIN.river_center(pz)) < 12.0:
				continue
			var steep := TERRAIN.steepness(px, pz)
			var forest := _forest_noise(px, pz)
			var kind := ""
			if steep > 0.42 or h > 40.0:
				if rng.randf() < 0.18 * float(budget.rocks):
					kind = "rock_b"
			elif forest > 0.42 or (h > 9.0 and forest > 0.3):
				kind = "tree_fir" if (h > 8.0 or rng.randf() < 0.35) else ("tree_oak" if rng.randf() < 0.6 else "tree_birch")
			elif rng.randf() < 0.12:
				kind = ["bush", "rock_b", "tree_oak"][rng.randi() % 3]
			if kind.is_empty():
				continue
			var key := Vector2i(floori((px - origin.x) / WILD_CHUNK), floori((pz - origin.y) / WILD_CHUNK))
			if not cells.has(key):
				cells[key] = {}
			if not cells[key].has(kind):
				cells[key][kind] = []
			var scale := rng.randf_range(0.8, 1.35)
			cells[key][kind].append(_place(px, pz, scale, rng.randf() * TAU, 0.25 if kind.begins_with("rock") else 0.08))
		z += spacing
	var near: float = budget.near
	var far_kind := {"tree_oak": "tree_low", "tree_birch": "tree_low", "tree_fir": "fir_low"}
	var trees := 0
	for key in cells:
		var holder := Node3D.new()
		holder.name = "Wild_%d_%d" % [key.x, key.y]
		holder.position = Vector3.ZERO
		add_child(holder)
		_wild.append(holder)
		var far_lists := {"tree_low": [], "fir_low": []}
		for kind in cells[key]:
			var transforms: Array = cells[key][kind]
			if far_kind.has(kind):
				trees += transforms.size()
				ART.batch(holder, kind, kind, transforms, near, true)
				far_lists[far_kind[kind]].append_array(transforms)
			else:
				ART.batch(holder, kind, kind, transforms, near * 1.6, kind != "bush")
		# Broadleaf trees share one far crown: two far batches per area.
		for far in far_lists:
			ART.batch(holder, far, far, far_lists[far], 0.0, bool(budget.shadows_far), near - 12.0)
	set_meta("wilderness_trees", trees)


static func _forest_noise(x: float, z: float) -> float:
	var value := sin(x * 0.031 + 1.7) * sin(z * 0.027 - 0.4) * 0.5 + 0.5
	value = value * 0.6 + (sin(x * 0.083 + z * 0.061) * 0.5 + 0.5) * 0.4
	return value


func _build_river() -> void:
	if not TERRAIN.available():
		var water := _kit.box(self, Vector3(0, -0.32, 0), Vector3(11.9, 0.10, 230), Color("489bb1"))
		var shader := ShaderMaterial.new()
		shader.shader = preload("res://assets/shaders/kart_water.gdshader")
		water.material_override = shader
		return
	var stones: Array = []
	var reeds: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2210
	var z := -150.0
	while z < 115.0:
		for side in [-1.0, 1.0]:
			var x: float = TERRAIN.river_center(z) + side * rng.randf_range(6.2, 8.0)
			if rng.randf() < 0.55:
				stones.append(_place(x, z, rng.randf_range(0.35, 0.8), rng.randf() * TAU, 0.2))
			elif rng.randf() < 0.8:
				reeds.append(_place(x + side * 0.6, z, rng.randf_range(0.8, 1.2), rng.randf() * TAU, 0.0))
		z += rng.randf_range(2.4, 4.2)
	ART.batch(self, "RiverbankStones", "rock_c", stones, 240.0, false)
	ART.batch(self, "RiverReeds", "reeds", reeds, 160.0, false)


func _build_bridge(z: float) -> void:
	var bridge := StaticBody3D.new()
	bridge.name = "VillageRiverBridge_%d" % int(z)
	add_child(bridge)
	var x := TERRAIN.river_center(z)
	var deck := 0.06
	if TERRAIN.available():
		deck = maxf(TERRAIN.height(x - 11.0, z), TERRAIN.height(x + 11.0, z)) + 0.05
	bridge.position = Vector3(x, deck, z)
	bridge_decks.append(bridge.position)
	if ART.exists("bridge"):
		bridge.add_child(ART.instance("bridge"))
	else:
		_kit.box(bridge, Vector3(0, 0, 0), Vector3(13.5, 0.16, 2.3), Color("d8b785"))
	_kit.collision(bridge, Vector3(0, -0.15, 0), Vector3(22.0, 0.3, 3.0))
	for side in [-1.0, 1.0]:
		_kit.collision(bridge, Vector3(0, 0.5, side * 1.35), Vector3(22.0, 1.0, 0.3))


func _build_waterfront(opponent: bool) -> void:
	var direction := 1.0 if opponent else -1.0
	var z := 9.0
	var x := TERRAIN.river_center(z) + direction * 6.4
	var dock := ART.instance("dock") if ART.exists("dock") else Node3D.new()
	dock.name = "Liefersteg_" + ("Neighbor" if opponent else "Player")
	dock.position = Vector3(x, TERRAIN.WATER_LEVEL + 0.55, z)
	add_child(dock)
	var house := ART.instance("warehouse") if ART.exists("warehouse") else Node3D.new()
	var hx := TERRAIN.river_center(18.0) + direction * 10.6
	house.position = Vector3(hx, TERRAIN.height(hx, 18.0), 18.0)
	house.rotation.y = -direction * PI * 0.5
	add_child(house)
	_title("LIEFERSTEG", Vector3(x, 0, z), Color("f9e6be"), 2.6)


## Bauten, die die Karte erzählen: Wassermühle am Fluss, Wachtürme auf den
## Felshügeln, Werkstatt am Ortsrand. Keine Spielwirkung, keine Grundstücke.
func _build_landmarks() -> void:
	if not TERRAIN.available():
		return
	var mill_z := -30.0
	var mill_x := TERRAIN.river_center(mill_z) - 10.6
	_landmark("watermill", Vector3(mill_x, TERRAIN.height(mill_x - 1.0, mill_z), mill_z), 0.0)
	for spot in [Vector2(-172.0, 50.0), Vector2(168.0, 62.0)]:
		_landmark("watchtower", Vector3(spot.x, TERRAIN.height(spot.x, spot.y) - 0.4, spot.y), 0.6)
	# Vor dem Westrand der ganz ausgebauten Stadt, nie auf einem Bauplatz.
	var shop_x := -TOWN_CENTER - PLAYER_HALF_EXTENT - 8.0
	_landmark("workshop", Vector3(shop_x, TERRAIN.height(shop_x, 6.0), 6.0), PI * 0.5)
	for index in range(6):
		var lz := -34.0 + index * 12.0
		for side in [-1.0, 1.0]:
			var lx: float = TERRAIN.river_center(lz) + side * 12.2
			_landmark("lantern", Vector3(lx, TERRAIN.height(lx, lz), lz), 0.0)


func _landmark(kind: String, at: Vector3, yaw: float) -> void:
	if not ART.exists(kind):
		return
	var node := ART.instance(kind)
	node.position = at
	node.rotation.y = yaw
	add_child(node)
	for child in node.get_children():
		if str(child.name).begins_with("Spin_"):
			animated.append(child)


func _title(caption: String, at: Vector3, color: Color, lift := 3.3) -> void:
	var sign := Label3D.new()
	sign.text = caption
	sign.position = Vector3(at.x, TERRAIN.height(at.x, at.z) + lift, at.z)
	sign.font_size = 48
	sign.pixel_size = 0.014
	sign.modulate = color
	sign.outline_modulate = Color("264b49")
	sign.outline_size = 8
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.visibility_range_end = 95
	add_child(sign)


func update_focus(at: Vector3) -> void:
	if at.distance_squared_to(_last_focus) < 25.0:
		return
	_last_focus = at
	for chunk in _chunks:
		chunk.visible = (
			Vector2(chunk.position.x - at.x, chunk.position.z - at.z).length_squared() < 165.0 * 165.0
		)


func advance(delta: float) -> void:
	for part in animated:
		if is_instance_valid(part):
			part.rotate_object_local(Vector3.RIGHT, delta * (0.9 if str(part.name) == "Spin_Wheel" else 0.6))


static func _box_mesh() -> BoxMesh:
	var shape := BoxMesh.new()
	shape.size = Vector3.ONE
	return shape


static func _sphere_mesh() -> SphereMesh:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1
	shape.radial_segments = 10
	shape.rings = 5
	return shape
