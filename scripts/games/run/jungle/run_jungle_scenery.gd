extends Node3D
## The look of the Dschungelherz adventure path: sky and light, the path decks
## (earth, planks, rope bridges, treetop decks, flagstones, cave floor, rails),
## terrain on both sides, a dense jungle of trees, ferns and big leaves close
## to the path and over head, lianas, ruins, the cave, waterfalls, mist, light
## shafts, torches and animals. Purely visual; nothing here is collided with.
##
## Everything repeated is batched into MultiMeshes per kind and 80 m stretch, so
## the whole jungle costs a few dozen draw calls from the running camera.

const MESHES = preload("res://scripts/games/run/jungle/run_jungle_meshes.gd")
const SHADERS = preload("res://scripts/games/run/jungle/run_jungle_shaders.gd")
const CHUNK: float = 160.0
## Variants that share one mesh (and so one draw call per stretch).
const ALIAS: Dictionary = {
	"fern2": "fern0", "fern3": "fern1", "leaf2": "leaf0", "leaf3": "leaf1", "tree3": "tree0", "tree4": "tree1",
	"tree5": "tree2", "grass1": "grass0", "rock1": "rock0", "crystal1": "crystal0", "liana2": "liana1",
	"palm1": "palm0", "pillar0": "pillar1", "flower1": "flower0", "flower2": "flower0", "flower3": "flower0",
	"flower4": "flower0",
}
const LEAF_GREENS: Array[Color] = [
	Color("2f8f3e"), Color("3a9e48"), Color("26773a"), Color("4caf50"), Color("1f6b3a"), Color("5bb34a")
]
const BLOSSOMS: Array[Color] = [Color("ff6fa8"), Color("ffd24a"), Color("ff8a3d"), Color("b46cff"), Color("5fd7ff")]
const DECK: Dictionary = {
	"dirt": [0, Color("c19a68"), Color("86b24a")],
	"roots": [0, Color("b08a5c"), Color("7aa844")],
	"station": [1, Color("c8955c"), Color("a07a4c")],
	"plank": [1, Color("d9a86a"), Color("b8884f")],
	"bridge": [1, Color("deb070"), Color("b8884f")],
	"canopy": [1, Color("d0a064"), Color("86b24a")],
	"stone": [2, Color("e0c89c"), Color("b2c080")],
	"cave": [0, Color("8a877c"), Color("5f8576")],
	"rail": [0, Color("857a6c"), Color("6c6458")],
	"gold": [2, Color("f0c862"), Color("d9a63a")],
}

var path
var level
var low: bool = false
var placed: int = 0
var _rng := RandomNumberGenerator.new()
var _kinds: Dictionary = {}
var _buckets: Dictionary = {}
var _materials: Dictionary = {}
var _deck_materials: Dictionary = {}
var _pollen: CPUParticles3D
## Where the path comes back near itself, scenery of one part must not cover
## another: path samples in a coarse grid, and the stretches where this matters.
var _grid: Dictionary = {}
var _grid_s := PackedFloat32Array()
var _grid_points := PackedVector3Array()
var _grid_half := PackedFloat32Array()
var _crowded := PackedByteArray()
const GRID_CELL: float = 12.0
const GRID_STEP: float = 3.0
## Kinds that may stand on the ground near another part of the path.
const SOLID_KINDS: Array[String] = [
	"tree0", "tree1", "tree2", "giant", "palm0", "rock0", "pillar1", "bush", "leaf0", "leaf1", "fern0", "fern1",
	"grass0", "flower0", "statue", "block", "post", "torch", "flame", "bulb", "crystal0", "canopy", "liana0", "liana1",
]


func build(world, layout, lightweight: bool) -> void:
	path = world
	level = layout
	low = lightweight
	_rng.seed = 20261118
	_make_materials()
	_make_kinds()
	_index_path()
	_environment()
	_decks()
	_terrain()
	_cave()
	_bonus_hall()
	_vegetation()
	_structures()
	_decor()
	_fauna()
	_background()
	_flush()
	_ambient_particles()


func follow(camera_position: Vector3, _player_s: float, _delta: float) -> void:
	if is_instance_valid(_pollen):
		_pollen.global_position = camera_position + Vector3(0, 1.0, 0)


# ------------------------------------------------------------------ materials and kinds

func _make_materials() -> void:
	_materials["foliage"] = SHADERS.material(SHADERS.FOLIAGE, {"brightness": 1.25})
	_materials["trunk"] = SHADERS.material(SHADERS.FOLIAGE, {"sway": 0.6, "brightness": 1.15})
	_materials["solid"] = SHADERS.material(SHADERS.SOLID)
	_materials["glow"] = SHADERS.material(SHADERS.GLOW, {"pulse": 0.35, "strength": 1.6})
	_materials["flame"] = SHADERS.material(SHADERS.FLAME)
	_materials["fauna"] = SHADERS.material(SHADERS.FAUNA)
	_materials["shaft"] = SHADERS.material(SHADERS.SHAFT)
	_materials["mist"] = SHADERS.material(SHADERS.MIST)
	_materials["water"] = SHADERS.material(SHADERS.WATER, {"flow": 0.35, "stretch": 0.4})
	_materials["fall"] = SHADERS.material(SHADERS.WATER, {"flow": 1.2, "stretch": 1.6})
	for kind in DECK:
		var entry: Array = DECK[kind]
		if not _deck_materials.has(int(entry[0])):
			_deck_materials[int(entry[0])] = SHADERS.material(SHADERS.GROUND, {"pattern": int(entry[0])})
	_materials["terrain"] = SHADERS.material(SHADERS.GROUND, {"pattern": 0})


func _kind(name: String, mesh: Mesh, material: String, range_end: float = 140.0, shadow: bool = false) -> void:
	_kinds[name] = {"mesh": mesh, "material": material, "range": range_end, "shadow": shadow}


func _make_kinds() -> void:
	var trees: int = 3
	for index in range(trees):
		var bark: Color = [Color("6b4a31"), Color("5a3d28"), Color("7a5a3c")][index % 3]
		_kind("tree%d" % index, MESHES.tree(100 + index, 18.0, 4 + index % 3, bark, LEAF_GREENS[index % LEAF_GREENS.size()]), "trunk", 190.0, not low)
	_kind("giant", MESHES.tree(77, 30.0, 6, Color("5e4330"), Color("2c8a47")), "trunk", 260.0, not low)
	for index in range(4):
		_kind("fern%d" % index, MESHES.fern(200 + index, 6 + index, 1.3 + 0.2 * index, LEAF_GREENS[(index + 2) % LEAF_GREENS.size()]), "foliage", 70.0)
		_kind("leaf%d" % index, MESHES.broadleaf(300 + index, 4 + index, 1.2 + 0.25 * index, LEAF_GREENS[(index + 1) % LEAF_GREENS.size()]), "foliage", 90.0)
	for index in range(2):
		_kind("grass%d" % index, MESHES.grass(400 + index, 10, 0.7, Color("6fb43f") if index == 0 else Color("4f9a3c")), "foliage", 60.0)
		_kind("palm%d" % index, MESHES.palm(500 + index, 11.0 + 3.0 * index), "trunk", 220.0, not low)
		_kind("rock%d" % index, MESHES.rock(600 + index, Vector3(1.4, 0.9, 1.2), Color("7f8574") if index == 0 else Color("8e836c")), "solid", 160.0, not low)
		_kind("pillar%d" % index, MESHES.pillar(700 + index, 4.5 + 2.0 * index, index == 0), "solid", 200.0, not low)
		_kind("crystal%d" % index, MESHES.crystal(800 + index, Color("62e6ff") if index == 0 else Color("b48cff")), "glow", 120.0)
	_kind("flower0", MESHES.flower(900, Color("ffffff")), "foliage", 60.0)
	var bulb := MESHES.Kit.new()
	MESHES.blob(bulb, Vector3.ZERO, Vector3.ONE * 0.2, Color("ffe08a"), RandomNumberGenerator.new(), 0.0, 3, 6)
	_kind("bulb", bulb.mesh(), "glow", 140.0)
	for index in range(3):
		_kind("liana%d" % index, MESHES.liana(1000 + index, 5.0 + 2.0 * float(index)), "foliage", 120.0)
	var crown := MESHES.Kit.new()
	var crown_rng := RandomNumberGenerator.new()
	crown_rng.seed = 1100
	for lobe in range(5):
		var at := Vector3(crown_rng.randf_range(-1.6, 1.6), crown_rng.randf_range(-0.4, 0.4), crown_rng.randf_range(-1.6, 1.6))
		MESHES.blob(crown, at, Vector3(1.8, 0.9, 1.8), LEAF_GREENS[lobe % LEAF_GREENS.size()], crown_rng, 0.25, 4, 9, 0.4)
	_kind("canopy", crown.mesh(), "foliage", 130.0)
	var bush := MESHES.Kit.new()
	MESHES.blob(bush, Vector3(0, 0.5, 0), Vector3(1.1, 0.8, 1.1), Color("2f8f3e"), crown_rng, 0.25, 4, 8, 0.3)
	MESHES.blob(bush, Vector3(0.7, 0.4, 0.3), Vector3(0.7, 0.6, 0.7), Color("3a9e48"), crown_rng, 0.25, 3, 7, 0.3)
	_kind("bush", bush.mesh(), "foliage", 120.0)
	_kind("statue", MESHES.statue(1200), "solid", 220.0, not low)
	_kind("arch", MESHES.arch(5.6, 4.8), "solid", 260.0, not low)
	_kind("torch", MESHES.torch(), "solid", 120.0)
	_kind("flame", MESHES.flame(), "flame", 160.0)
	_kind("block", MESHES.box(Vector3(0.5, 0.5, 0.5), Color("bfa77f")), "solid", 160.0)
	_kind("templeblock", MESHES.box(Vector3(0.5, 0.5, 0.5), Color("c2a878")), "solid", 0.0)
	_kind("plankbox", MESHES.box(Vector3(0.5, 0.5, 0.5), Color("a77b4a")), "solid", 130.0)
	_kind("rope", MESHES.box(Vector3(0.5, 0.5, 0.5), Color("d9c08a")), "solid", 90.0)
	_kind("iron", MESHES.box(Vector3(0.5, 0.5, 0.5), Color("8d96a3")), "solid", 120.0)
	var post := CylinderMesh.new()
	post.top_radius = 0.5
	post.bottom_radius = 0.5
	post.height = 1.0
	post.radial_segments = 6 if low else 8
	post.rings = 1
	_kind("post", post, "solid", 150.0)
	_kind("butterfly", MESHES.butterfly(), "fauna", 70.0)
	_kind("bird", MESHES.bird(), "fauna", 260.0)
	_kind("leafcard", MESHES.leaf_card(), "fauna", 60.0)
	var dot := MESHES.Kit.new()
	MESHES.blob(dot, Vector3.ZERO, Vector3.ONE * 0.06, Color(1, 1, 1), crown_rng, 0.0, 2, 4)
	_kind("firefly", dot.mesh(), "fauna", 70.0)
	var gold := MESHES.Kit.new()
	for coin in range(9):
		MESHES.blob(gold, Vector3(crown_rng.randf_range(-0.8, 0.8), 0.1 + crown_rng.randf() * 0.5, crown_rng.randf_range(-0.8, 0.8)), Vector3(0.5, 0.25, 0.5), Color("ffd24a"), crown_rng, 0.1, 3, 7)
	_kind("treasure", gold.mesh(), "glow", 120.0)
	var mountain := MESHES.Kit.new()
	MESHES.blob(mountain, Vector3.ZERO, Vector3(1.0, 1.0, 1.0), Color("3f6f5a"), crown_rng, 0.18, 6, 12, 0.0, true)
	_kind("mountain", mountain.mesh(), "solid", 0.0)
	var cliff := MESHES.Kit.new()
	MESHES.blob(cliff, Vector3.ZERO, Vector3(1.0, 1.0, 1.0), Color("6c6a5c"), crown_rng, 0.28, 6, 10, 0.0, true)
	_kind("cliff", cliff.mesh(), "solid", 220.0)


## Queues one instance. `at_s` decides the batch, so instances near each other share it.
func _put(kind: String, at_s: float, transform: Transform3D, colour: Color = Color.WHITE, custom: Color = Color(0, 0, 0, 0)) -> void:
	if kind.begins_with("flower") and colour == Color.WHITE:
		colour = BLOSSOMS[int(kind.substr(6)) % BLOSSOMS.size()]
	if kind.begins_with("crystal1"):
		colour = Color("c9a8ff")
	kind = ALIAS.get(kind, kind)
	if not _kinds.has(kind):
		return
	if at_s >= 0.0 and _is_crowded(at_s) and SOLID_KINDS.has(kind):
		var margin: float = 1.6 if kind in ["tree0", "tree1", "tree2", "giant", "palm0"] else 0.5
		if _path_in_the_way(transform.origin, at_s, margin):
			return
	var key: String = "%s|%d" % [kind, floori(at_s / CHUNK) if _kinds[kind].range > 0.0 else 0]
	if not _buckets.has(key):
		_buckets[key] = {"kind": kind, "xforms": [], "colours": [], "custom": []}
	_buckets[key].xforms.append(transform)
	_buckets[key].colours.append(colour)
	_buckets[key].custom.append(custom)
	placed += 1


func _flush() -> void:
	for key in _buckets:
		var bucket: Dictionary = _buckets[key]
		var kind: Dictionary = _kinds[bucket.kind]
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_colors = true
		instances.use_custom_data = true
		instances.mesh = kind.mesh
		instances.instance_count = bucket.xforms.size()
		for index in range(instances.instance_count):
			instances.set_instance_transform(index, bucket.xforms[index])
			instances.set_instance_color(index, bucket.colours[index])
			instances.set_instance_custom_data(index, bucket.custom[index])
		var node := MultiMeshInstance3D.new()
		node.name = "Jungle_" + str(key).replace("|", "_")
		node.multimesh = instances
		node.material_override = _materials[kind.material]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if float(kind.range) > 0.0:
			node.visibility_range_end = float(kind.range) * (0.75 if low else 1.0)
			node.visibility_range_end_margin = 10.0
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		add_child(node)
	_buckets.clear()


# ------------------------------------------------------------------ helpers in road space

func _point(at: float, lat: float, h: float = 0.0) -> Vector3:
	return path.position_at(at, lat) + Vector3.UP * h


## A transform at a road position, turned by `yaw` around the vertical and scaled.
func _xf(at: float, lat: float, h: float, scale: Vector3, yaw: float = 0.0) -> Transform3D:
	var heading: float = atan2(-path.forward(at).x, -path.forward(at).z)
	return Transform3D(Basis(Vector3.UP, heading + yaw).scaled_local(scale), _point(at, lat, h))


func _floor(at: float) -> float:
	return minf(0.0, path.ground_offset_at(at))


func _surface_of(at: float) -> String:
	return path.surface_at(at)


func _main_samples(step: float) -> PackedFloat32Array:
	var list := PackedFloat32Array()
	var at: float = 0.0
	while at < path.length:
		list.append(at)
		at += step
	return list


# ------------------------------------------------------------------ where the path meets itself

func _cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / GRID_CELL), floori(point.z / GRID_CELL))


func _index_path() -> void:
	var at: float = 0.0
	while at < path.length:
		var point: Vector3 = path.position_at(at, 0.0)
		var key: Vector2i = _cell(point)
		if not _grid.has(key):
			_grid[key] = PackedInt32Array()
		_grid[key].append(_grid_s.size())
		_grid_s.append(at)
		_grid_points.append(point)
		_grid_half.append(path.half_width_at(at) if not path.in_gap(at) else path.half_width_at(at) + 0.5)
		at += GRID_STEP
	# A stretch is crowded when a part at least 40 m further along passes within 60 m.
	_crowded.resize(_grid_s.size())
	_crowded.fill(0)
	for index in range(_grid_s.size()):
		var centre: Vector2i = _cell(_grid_points[index])
		for dx in range(-5, 6):
			for dz in range(-5, 6):
				var key := Vector2i(centre.x + dx, centre.y + dz)
				if not _grid.has(key):
					continue
				for other in _grid[key]:
					if absf(_grid_s[other] - _grid_s[index]) < 40.0:
						continue
					var flat := Vector2(_grid_points[other].x - _grid_points[index].x, _grid_points[other].z - _grid_points[index].z)
					if flat.length() < 60.0:
						_crowded[index] = 1
						break


func _is_crowded(at: float) -> bool:
	var index: int = clampi(roundi(at / GRID_STEP), 0, _crowded.size() - 1)
	return _crowded[index] != 0


## True when `point` (something standing near the path at `own`) would stand on,
## or hang over, another part of the path.
func _path_in_the_way(point: Vector3, own: float, margin: float) -> bool:
	var centre: Vector2i = _cell(point)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := Vector2i(centre.x + dx, centre.y + dz)
			if not _grid.has(key):
				continue
			for other in _grid[key]:
				if absf(_grid_s[other] - own) < 25.0:
					continue
				var sample: Vector3 = _grid_points[other]
				var flat: float = Vector2(sample.x - point.x, sample.z - point.z).length()
				if flat < _grid_half[other] + margin and point.y > sample.y - 14.0 and point.y < sample.y + 4.5:
					return true
	return false


## Terrain height at `point`, lowered where it would cover another part of the path.
func _below_other_path(point: Vector3, own: float) -> float:
	var height: float = point.y
	var centre: Vector2i = _cell(point)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := Vector2i(centre.x + dx, centre.y + dz)
			if not _grid.has(key):
				continue
			for other in _grid[key]:
				if absf(_grid_s[other] - own) < 25.0 or path.ceiling_at(_grid_s[other]) < 100.0:
					continue
				var sample: Vector3 = _grid_points[other]
				var flat: float = Vector2(sample.x - point.x, sample.z - point.z).length()
				var reach: float = _grid_half[other] + 6.0
				if flat < reach and height > sample.y - 0.7 and height < sample.y + 40.0:
					height = minf(height, sample.y - 0.7 - maxf(0.0, flat - _grid_half[other]) * 0.6)
	return height


# ------------------------------------------------------------------ sky, sun and fog

func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("2f7fd8")
	sky_material.sky_horizon_color = Color("ffe2b0")
	sky_material.sky_curve = 0.12
	sky_material.ground_bottom_color = Color("1d3b2c")
	sky_material.ground_horizon_color = Color("9fc7a0")
	sky_material.sun_angle_max = 18.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color("b8d8a8")
	environment.ambient_light_energy = 1.05
	environment.ambient_light_sky_contribution = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.15
	environment.tonemap_white = 6.0
	environment.fog_enabled = true
	# Depth fog with a clear near range: the exponential fog of the compatibility
	# renderer washed out even the path right in front of the camera.
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color("a9d0d6")
	environment.fog_density = 0.85
	environment.fog_depth_begin = 45.0
	environment.fog_depth_end = 320.0
	environment.fog_depth_curve = 1.6
	environment.fog_sky_affect = 0.15
	environment.glow_enabled = not low
	environment.glow_intensity = 0.7
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 0.95
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.06
	environment.adjustment_contrast = 1.05
	var holder := WorldEnvironment.new()
	holder.name = "JungleSky"
	holder.environment = environment
	add_child(holder)
	var sun := DirectionalLight3D.new()
	sun.name = "JungleSun"
	sun.light_color = Color("ffd9a0")
	sun.light_energy = 1.7
	sun.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(35.0), 0.0)
	sun.shadow_enabled = not low
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_blur = 1.5
	add_child(sun)


# ------------------------------------------------------------------ path decks

## The walkable surfaces as ribbons (one mesh per surface stretch, cut at 60 m).
func _decks() -> void:
	for surface in level.surfaces:
		var kind: String = str(surface.kind)
		if kind == "gap" or not DECK.has(kind):
			continue
		var from: float = float(surface.s0)
		var to: float = float(surface.s1)
		while from < to - 0.01:
			var until: float = minf(to, from + 60.0)
			_deck(from, until, kind, float(surface.half))
			from = until


func _deck(from: float, to: float, kind: String, half: float) -> void:
	var entry: Array = DECK[kind]
	var middle: Color = entry[1]
	var edge: Color = entry[2]
	var raised: bool = path.ground_offset_at((from + to) * 0.5) < -1.5 or kind in ["plank", "bridge", "canopy", "station"]
	var columns: Array = [
		[-half - 0.45, -0.35 if raised else -0.25, edge.darkened(0.25)],
		[-half - 0.3, 0.06, edge],
		[-half + 0.35, 0.02, middle.lerp(edge, 0.4)],
		[0.0, 0.0, middle],
		[half - 0.35, 0.02, middle.lerp(edge, 0.4)],
		[half + 0.3, 0.06, edge],
		[half + 0.45, -0.35 if raised else -0.25, edge.darkened(0.25)],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = maxi(1, ceili((to - from) / 1.0))
	for row in range(rows + 1):
		var at: float = lerpf(from, to, float(row) / float(rows))
		var basis: Basis = path.frame(at)
		for column in columns:
			var tint: Color = column[2]
			tint = tint.lightened(_rng.randf_range(-0.04, 0.06))
			st.set_color(tint)
			st.set_uv(Vector2(float(column[0]) / (half * 2.0) + 0.5, at))
			st.add_vertex(path.position_at(at, float(column[0])) + basis.y * float(column[1]))
		# Skirt down from the edges (earth bank or the side board of a deck).
	var width: int = columns.size()
	for row in range(rows):
		for column in range(width - 1):
			var a: int = row * width + column
			var b: int = a + 1
			var c: int = a + width
			var d: int = c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_skirts(mesh, from, to, half, raised, edge.darkened(0.35))
	var node := MeshInstance3D.new()
	node.name = "Deck_%s_%d" % [kind, int(from)]
	node.mesh = mesh
	node.material_override = _deck_materials[int(entry[0])]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 260.0
	add_child(node)


## Adds the side faces under the deck edge as a second surface of the same mesh.
func _skirts(mesh: ArrayMesh, from: float, to: float, half: float, raised: bool, colour: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var depth: float = 0.55 if raised else 1.6
	var rows: int = maxi(1, ceili((to - from) / 1.5))
	for side in [-1.0, 1.0]:
		for row in range(rows):
			var a_s: float = lerpf(from, to, float(row) / float(rows))
			var b_s: float = lerpf(from, to, float(row + 1) / float(rows))
			var out: float = side * (half + 0.45)
			var low_out: float = side * (half + (0.5 if raised else 1.6))
			var a_top: Vector3 = path.position_at(a_s, out) + path.frame(a_s).y * -0.3
			var b_top: Vector3 = path.position_at(b_s, out) + path.frame(b_s).y * -0.3
			var a_low: Vector3 = path.position_at(a_s, low_out) + Vector3.DOWN * depth
			var b_low: Vector3 = path.position_at(b_s, low_out) + Vector3.DOWN * depth
			var normal: Vector3 = path.frame(a_s).x * side
			for vertex in [a_top, b_top, b_low, a_top, b_low, a_low]:
				st.set_normal(normal)
				st.set_color(colour)
				st.set_uv(Vector2(0.0, a_s))
				st.add_vertex(vertex)
	st.commit(mesh)


# ------------------------------------------------------------------ terrain on both sides

const OFFSETS: Array[float] = [0.0, 0.7, 1.8, 3.6, 6.5, 11.0, 18.0, 28.0, 42.0]


func _terrain_height(at: float, offset: float) -> float:
	var ground: float = _floor(at)
	var kind: String = _surface_of(at)
	if kind == "cave":
		return 6.9 + offset * 0.9
	var rise: float = pow(maxf(0.0, offset - 2.6), 1.22) * 0.34
	var wobble: float = sin(at * 0.11 + offset * 0.7) * 0.8 + sin(at * 0.037 - offset * 0.3) * 1.6
	var base: float = ground - (0.32 if offset < 1.0 else 0.5)
	if ground < -1.5:
		base = ground
	return base + rise + wobble * clampf((offset - 2.0) / 8.0, 0.0, 1.0)


func _terrain() -> void:
	var step: float = 3.0 if low else 2.0
	var samples: PackedFloat32Array = _main_samples(step)
	var stretch: int = int(60.0 / step)
	var start: int = 0
	while start < samples.size() - 1:
		var stop: int = mini(samples.size() - 1, start + stretch)
		for side in [-1.0, 1.0]:
			_terrain_strip(samples, start, stop, side)
		start = stop


func _terrain_strip(samples: PackedFloat32Array, start: int, stop: int, side: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width: int = OFFSETS.size()
	for index in range(start, stop + 1):
		var at: float = samples[index]
		var half: float = path.half_width_at(at) + 0.4
		var origin: Vector3 = path.position_at(at, 0.0)
		for offset in OFFSETS:
			var lateral: float = side * (half + offset)
			var point: Vector3 = path.position_at(at, lateral)
			point.y = origin.y + _terrain_height(at, offset)
			if _is_crowded(at):
				point.y = _below_other_path(point, at)
			var green: Color = Color("5c8f3a").lerp(Color("2f6b33"), clampf(offset / 20.0, 0.0, 1.0))
			if offset < 1.0 and _floor(at) > -1.5:
				green = Color("7a6a46").lerp(green, offset)
			if _surface_of(at) == "cave":
				green = Color("53614f")
			st.set_color(green.lightened(_rng.randf_range(-0.06, 0.06)))
			st.set_uv(Vector2(offset, at))
			st.add_vertex(point)
	for row in range(stop - start):
		for column in range(width - 1):
			var a: int = row * width + column
			var b: int = a + 1
			var c: int = a + width
			var d: int = c + 1
			if side < 0.0:
				st.add_index(a)
				st.add_index(b)
				st.add_index(c)
				st.add_index(b)
				st.add_index(d)
				st.add_index(c)
			else:
				st.add_index(a)
				st.add_index(c)
				st.add_index(b)
				st.add_index(b)
				st.add_index(c)
				st.add_index(d)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "Terrain_%d_%d" % [start, int(side)]
	node.mesh = st.commit()
	node.material_override = _materials["terrain"]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 320.0
	add_child(node)


# ------------------------------------------------------------------ the cave

func _cave() -> void:
	for roof in level.ceilings:
		var from: float = roof.x
		while from < roof.y - 0.01:
			var to: float = minf(roof.y, from + 50.0)
			_cave_piece(from, to, roof.z)
			from = to
		# Glowing crystals in the walls, a few torches and dripping light.
		var at: float = roof.x + 3.0
		while at < roof.y:
			var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
			var half: float = path.half_width_at(at)
			var crystal: String = "crystal%d" % (_rng.randi() % 2)
			_put(crystal, at, _xf(at, side * (half + 0.9), _rng.randf_range(0.0, 2.5), Vector3.ONE * _rng.randf_range(0.6, 1.3), _rng.randf() * TAU), Color.WHITE)
			if _rng.randf() < 0.3:
				_put(crystal, at, _xf(at, side * _rng.randf_range(0.5, half), roof.z - 0.3, Vector3(1, -1, 1) * _rng.randf_range(0.5, 0.9), _rng.randf() * TAU))
			at += _rng.randf_range(2.5, 4.5) * (1.5 if low else 1.0)


func _cave_piece(from: float, to: float, height: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = maxi(1, ceili((to - from) / 1.5))
	var ring: int = 13
	for row in range(rows + 1):
		var at: float = lerpf(from, to, float(row) / float(rows))
		var half: float = path.half_width_at(at) + 0.5
		var basis: Basis = path.frame(at)
		var centre: Vector3 = path.position_at(at, 0.0)
		for k in range(ring):
			var u: float = float(k) / float(ring - 1)
			var angle: float = PI * u
			var wobble: float = 1.0 + 0.18 * sin(at * 0.7 + float(k) * 1.9) + 0.1 * sin(at * 0.23 + float(k))
			var lateral: float = -cos(angle) * (half + 0.9) * wobble
			var up: float = sin(angle) * height * (0.92 + 0.12 * sin(at * 0.5 + float(k) * 2.3))
			if k == 0 or k == ring - 1:
				up = -0.4
			var colour: Color = Color("4a4d48").lerp(Color("3c5f55"), clampf(up / height, 0.0, 1.0))
			if (k + row) % 5 == 0:
				colour = colour.lightened(0.08)
			st.set_color(colour)
			st.set_uv(Vector2(u, at))
			st.add_vertex(centre + basis.x * lateral + basis.y * up)
	for row in range(rows):
		for k in range(ring - 1):
			var a: int = row * ring + k
			var b: int = a + 1
			var c: int = a + ring
			var d: int = c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "Cave_%d" % int(from)
	node.mesh = st.commit()
	if not _materials.has("cave"):
		_materials["cave"] = SHADERS.material(
			SHADERS.SOLID.replace("render_mode specular_schlick_ggx;", "render_mode specular_schlick_ggx, cull_disabled;"),
			{"brightness": 1.5}
		)
	node.material_override = _materials["cave"]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if not low else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 200.0
	add_child(node)


# ------------------------------------------------------------------ the bonus hall

func _bonus_hall() -> void:
	var from: float = float(level.bonus.s0)
	var to: float = float(level.bonus.s1)
	_cave_piece(from - 2.0, to + 2.0, 7.5)
	var at: float = from + 2.0
	while at < to:
		for side in [-1.0, 1.0]:
			_put("pillar1", at, _xf(at, side * 4.1, 0.0, Vector3.ONE))
			_put("treasure", at, _xf(at + 2.5, side * 3.4, 0.0, Vector3.ONE * _rng.randf_range(0.8, 1.4), _rng.randf() * TAU))
			_put("crystal%d" % (_rng.randi() % 2), at, _xf(at + 4.0, side * 3.6, 0.3, Vector3.ONE * 1.2, _rng.randf() * TAU))
			_put("torch", at, _xf(at + 1.0, side * 3.4, 0.0, Vector3.ONE))
			_put("flame", at, _xf(at + 1.0, side * 3.4, 2.05, Vector3.ONE))
		at += 8.0
	for k in range(3):
		var light := OmniLight3D.new()
		light.light_color = Color("ffd27a")
		light.light_energy = 2.4
		light.omni_range = 26.0
		light.position = path.position_at(lerpf(from + 10.0, to - 10.0, float(k) / 2.0), 0.0) + Vector3.UP * 5.5
		add_child(light)


# ------------------------------------------------------------------ the jungle

func _vegetation() -> void:
	var density: float = 0.55 if low else 1.0
	var at: float = 0.0
	while at < path.length:
		var kind: String = _surface_of(at)
		var half: float = path.half_width_at(at)
		var ground: float = _floor(at)
		var raised: bool = ground < -1.5
		var covered: bool = kind == "cave"
		for side in [-1.0, 1.0]:
			if _niche_here(at, side):
				_fern_curtain(at, side, half)
				continue
			if covered:
				if _rng.randf() < 0.35 * density:
					_put("fern%d" % (_rng.randi() % 4), at, _xf(at, side * (half + _rng.randf_range(0.3, 0.9)), 0.0, Vector3.ONE * _rng.randf_range(0.6, 1.0), _rng.randf() * TAU), Color("9fd8b0"))
				continue
			# Foreground: ferns and big leaves right at the path edge.
			if _rng.randf() < 0.85 * density:
				var offset: float = _rng.randf_range(0.25, 1.9)
				var h: float = 0.0 if not raised else -0.25
				var pick: float = _rng.randf()
				var scale: float = _rng.randf_range(0.7, 1.4)
				if raised:
					_put("bush", at, _xf(at, side * (half + 0.55), -0.75, Vector3(0.75, 0.55, 0.75) * scale, _rng.randf() * TAU))
				elif pick < 0.5:
					_put("fern%d" % (_rng.randi() % 4), at, _xf(at, side * (half + offset), h + _terrain_lift(at, offset), Vector3.ONE * scale, _rng.randf() * TAU))
				elif pick < 0.82:
					_put("leaf%d" % (_rng.randi() % 4), at, _xf(at, side * (half + offset + 0.3), h + _terrain_lift(at, offset), Vector3.ONE * scale, _rng.randf() * TAU))
				else:
					_put("grass%d" % (_rng.randi() % 2), at, _xf(at, side * (half + offset * 0.5), h, Vector3.ONE * scale, _rng.randf() * TAU))
			if not raised and _rng.randf() < 0.22 * density:
				var offset: float = _rng.randf_range(0.4, 2.4)
				_put("flower%d" % (_rng.randi() % 5), at, _xf(at, side * (half + offset), _terrain_lift(at, offset), Vector3.ONE * _rng.randf_range(0.8, 1.3), _rng.randf() * TAU))
			# Middle band: big leaves, bushes and rocks.
			if _rng.randf() < 0.45 * density:
				var offset: float = _rng.randf_range(2.5, 8.0)
				var h: float = _terrain_lift(at, offset) + (ground if raised else 0.0)
				var roll: float = _rng.randf()
				if roll < 0.45:
					_put("leaf%d" % (_rng.randi() % 4), at, _xf(at, side * (half + offset), h, Vector3.ONE * _rng.randf_range(1.5, 2.6), _rng.randf() * TAU))
				elif roll < 0.75:
					_put("bush", at, _xf(at, side * (half + offset), h, Vector3.ONE * _rng.randf_range(1.0, 2.0), _rng.randf() * TAU))
				else:
					_put("rock%d" % (_rng.randi() % 2), at, _xf(at, side * (half + offset), h - 0.3, Vector3.ONE * _rng.randf_range(0.7, 1.8), _rng.randf() * TAU))
		at += 1.15
	_trees()
	_overhead()


func _terrain_lift(at: float, offset: float) -> float:
	var base: float = _terrain_height(at, offset) - _terrain_height(at, 0.0)
	return maxf(0.0, base) * 0.9


func _niche_here(at: float, side: float) -> bool:
	for item in level.decor:
		if str(item.kind) == "niche" and signf(float(item.lat)) == side and absf(at - float(item.s)) < float(item.get("length", 12.0)) * 0.5:
			return true
	return false


## Ferns between the main lane and a hidden niche: you can run through them.
func _fern_curtain(at: float, side: float, half: float) -> void:
	_put("leaf%d" % (_rng.randi() % 4), at, _xf(at, side * (half - 2.2), 0.0, Vector3.ONE * _rng.randf_range(1.1, 1.5), _rng.randf() * TAU))
	_put("fern%d" % (_rng.randi() % 4), at, _xf(at, side * (half + 0.6), 0.0, Vector3.ONE * 1.3, _rng.randf() * TAU))


func _trees() -> void:
	var trees: int = 3
	var at: float = 0.0
	while at < path.length:
		var kind: String = _surface_of(at)
		var half: float = path.half_width_at(at)
		var ground: float = _floor(at)
		for side in [-1.0, 1.0]:
			if kind == "cave":
				continue
			var offset: float = _rng.randf_range(3.2, 11.0)
			var floor_h: float = _terrain_height(at, offset)
			var scale: float = _rng.randf_range(0.65, 1.25)
			if kind in ["stone", "dirt"] and _rng.randf() < 0.18:
				_put("palm%d" % (_rng.randi() % 2), at, _xf(at, side * (half + offset), floor_h, Vector3.ONE * scale, _rng.randf() * TAU))
			else:
				_put("tree%d" % (_rng.randi() % trees), at, _xf(at, side * (half + offset), floor_h - 0.3, Vector3.ONE * scale * (1.4 if ground < -1.5 else 1.0), _rng.randf() * TAU))
			if _rng.randf() < 0.6:
				var far: float = _rng.randf_range(13.0, 34.0)
				_put("tree%d" % (_rng.randi() % trees), at, _xf(at, side * (half + far), _terrain_height(at, far) - 0.5, Vector3.ONE * _rng.randf_range(1.0, 1.7), _rng.randf() * TAU))
		at += _rng.randf_range(3.6, 5.6) * (1.5 if low else 1.0)
	# Giant trunks carry the treetop walks.
	at = 0.0
	while at < path.length:
		if _floor(at) < -10.0 and _surface_of(at) in ["canopy", "plank", "bridge", "gap"]:
			var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
			var deck_up: float = -_floor(at)
			_put("giant", at, _xf(at, side * (path.half_width_at(at) + _rng.randf_range(2.6, 4.5)), _floor(at), Vector3.ONE * clampf((deck_up + 12.0) / 30.0, 0.8, 1.4), _rng.randf() * TAU))
		at += _rng.randf_range(14.0, 20.0)


## Leaves and lianas over head: the path runs under a roof of jungle.
func _overhead() -> void:
	var at: float = 2.0
	while at < path.length:
		var kind: String = _surface_of(at)
		if kind != "cave":
			var half: float = path.half_width_at(at)
			for side in [-1.0, 1.0]:
				if _rng.randf() < (0.22 if _floor(at) < -1.5 else 0.45):
					var lat: float = side * _rng.randf_range(half * 0.4, half + 6.0)
					_put("canopy", at, _xf(at, lat, _rng.randf_range(8.5, 12.5), Vector3(1.0, 0.8, 1.0) * _rng.randf_range(1.0, 1.8), _rng.randf() * TAU))
				if _rng.randf() < 0.55:
					var lat: float = side * _rng.randf_range(half + 0.3, half + 3.0)
					var which: int = _rng.randi() % 3
					_put("liana%d" % which, at, _xf(at, lat, _rng.randf_range(9.5, 12.0), Vector3.ONE, _rng.randf() * TAU))
			if _rng.randf() < 0.18:
				# One liana right over the path, well above Lumo's head.
				_put("liana0", at, _xf(at, _rng.randf_range(-1.0, 1.0), 10.0, Vector3.ONE, _rng.randf() * TAU))
		at += _rng.randf_range(4.0, 6.5) * (1.5 if low else 1.0)


# ------------------------------------------------------------------ built things along the path

func _structures() -> void:
	for surface in level.surfaces:
		var kind: String = str(surface.kind)
		var from: float = float(surface.s0)
		var to: float = float(surface.s1)
		var half: float = float(surface.half)
		match kind:
			"plank", "canopy", "station":
				var at: float = from + 1.0
				while at < to:
					var ground: float = _floor(at)
					if ground < -1.0:
						for side in [-1.0, 1.0]:
							var depth: float = -ground + 0.3
							_put("post", at, _xf(at, side * (half - 0.1), -depth * 0.5 - 0.2, Vector3(0.32, depth, 0.32)), Color("6b4a31"))
					if kind == "canopy":
						_put("post", at, Transform3D(path.frame(at) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.6, 3.8, 1.2)), _point(at, 0.0, -1.0)), Color("6b4a31"))
					at += 3.6
				if kind != "station":
					_railing(from, to, half, kind == "canopy")
			"bridge":
				_railing(from, to, half, true)
				var at: float = from
				while at <= to:
					for side in [-1.0, 1.0]:
						_put("post", at, _xf(at, side * (half + 0.1), 0.6, Vector3(0.14, 1.4, 0.14)), Color("8a6a45"))
					at += (to - from) / 6.0
			"stone":
				var at: float = from + 1.0
				while at < to:
					for side in [-1.0, 1.0]:
						if _rng.randf() < 0.7:
							_put("block", at, _xf(at, side * (half + 0.55), 0.25, Vector3(0.7, _rng.randf_range(0.5, 1.0), 1.1), _rng.randf_range(-0.1, 0.1)), Color.WHITE.darkened(_rng.randf() * 0.15))
						if _rng.randf() < 0.18:
							_put("pillar%d" % (_rng.randi() % 2), at, _xf(at, side * (half + _rng.randf_range(1.6, 3.5)), 0.0, Vector3.ONE, _rng.randf() * TAU))
					at += 2.4
			"rail":
				var at: float = from
				while at < to:
					_put("plankbox", at, _xf(at, 0.0, 0.06, Vector3(2.0, 0.12, 0.28)))
					at += 0.9
				at = from
				while at < to:
					for side in [-0.55, 0.55]:
						_put("iron", at, Transform3D(path.frame(at + 0.6).scaled_local(Vector3(0.1, 0.12, 1.25)), _point(at + 0.6, side, 0.17)))
					at += 1.2
				at = from + 3.0
				while at < to:
					if _rng.randf() < 0.5:
						for side in [-1.0, 1.0]:
							_put("post", at, _xf(at, side * (half + 0.7), 1.8, Vector3(0.28, 3.6, 0.28)), Color("7a5a3c"))
						_put("plankbox", at, _xf(at, 0.0, 3.6, Vector3(half * 2.0 + 1.8, 0.3, 0.3)))
					at += 9.0
	# Water under the stream and the cave pools.
	for gap in level.gaps:
		var from: float = gap.x
		var to: float = gap.y
		var middle: float = (from + to) * 0.5
		var kind: String = _surface_of(from - 1.0)
		if kind in ["dirt", "cave", "roots"]:
			_water_plane(from - 1.0, to + 1.0, path.half_width_at(middle) + 2.5, -1.9)
		elif kind in ["canopy", "plank", "stone", "rail"]:
			# A misty drop: haze below the hole tells that it is deep.
			var mist := MeshInstance3D.new()
			mist.mesh = MESHES.card(to - from + 6.0, 5.0)
			mist.material_override = _materials["mist"]
			mist.transform = Transform3D(path.frame(middle) * Basis(Vector3.UP, PI * 0.5), _point(middle, 0.0, -5.0))
			add_child(mist)


func _railing(from: float, to: float, half: float, ropes: bool) -> void:
	var at: float = from
	var step: float = 2.5
	while at < to - 0.1:
		var next: float = minf(to, at + step)
		for side in [-1.0, 1.0]:
			var lat: float = side * (half + 0.12)
			_put("post", at, _xf(at, lat, 0.55, Vector3(0.12, 1.1, 0.12)), Color("7a5a3c"))
			var a: Vector3 = _point(at, lat, 1.05)
			var b: Vector3 = _point(next, lat, 1.05)
			var mid: Vector3 = (a + b) * 0.5 + Vector3.DOWN * (0.12 if ropes else 0.0)
			var along: Vector3 = b - a
			var basis := Basis.looking_at(along.normalized(), Vector3.UP).scaled_local(Vector3(0.06, 0.06, along.length()))
			_put("rope" if ropes else "plankbox", at, Transform3D(basis, mid))
		at = next


func _water_plane(from: float, to: float, half: float, depth: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = maxi(1, ceili((to - from) / 1.5))
	for row in range(rows + 1):
		var at: float = lerpf(from, to, float(row) / float(rows))
		for column in range(2):
			var lat: float = -half if column == 0 else half
			st.set_uv(Vector2(float(column), float(row) / float(rows)))
			st.add_vertex(path.position_at(at, lat) + Vector3.UP * depth)
	for row in range(rows):
		var a: int = row * 2
		st.add_index(a)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 3)
		st.add_index(a + 2)
	var node := MeshInstance3D.new()
	node.name = "Water_%d" % int(from)
	node.mesh = st.commit()
	node.material_override = _materials["water"]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


# ------------------------------------------------------------------ landmarks from the level

func _decor() -> void:
	# A small lantern marks every rescue point.
	for point in level.respawns:
		var at: float = float(point.s)
		if at < 0.0:
			continue
		var side: float = path.half_width_at(at) + 0.5
		var lat: float = side if float(point.lat) <= 0.0 else -side
		_put("torch", at, _xf(at, lat, 0.0, Vector3.ONE * 0.55))
		_put("bulb", at, _xf(at, lat, 1.18, Vector3.ONE))
	for item in level.decor:
		var at: float = float(item.s)
		var lat: float = float(item.lat)
		match str(item.kind):
			"torch":
				_put("torch", at, _xf(at, lat, 0.0, Vector3.ONE))
				_put("flame", at, _xf(at, lat, 2.05, Vector3.ONE))
				if not low:
					var light := OmniLight3D.new()
					light.light_color = Color("ffb35c")
					light.light_energy = 1.6
					light.omni_range = 7.0
					light.distance_fade_enabled = true
					light.distance_fade_begin = 40.0
					light.distance_fade_length = 15.0
					light.position = _point(at, lat, 2.4)
					add_child(light)
			"statue":
				_put("statue", at, _xf(at, lat, 0.0, Vector3.ONE * 1.3, PI * 0.5 * signf(lat)))
			"arch", "puzzle_gate", "cave_mouth":
				var width: float = path.half_width_at(at) * 2.0 + 0.8
				_put("arch", at, _xf(at, 0.0, -0.1, Vector3(width / 5.6, 1.0, 1.0)))
				if str(item.kind) == "arch":
					for side in [-1.0, 1.0]:
						_put("torch", at, _xf(at, side * (width * 0.5 + 0.8), 0.0, Vector3.ONE))
						_put("flame", at, _xf(at, side * (width * 0.5 + 0.8), 2.05, Vector3.ONE))
			"waterfall":
				_waterfall(at, lat, float(item.get("height", 8.0)), float(item.get("width", 6.0)), bool(item.get("curtain", false)))
			"finish_temple":
				for side in [-1.0, 1.0]:
					_put("pillar1", at, _xf(at, side * 4.5, 0.0, Vector3.ONE * 1.4))
					_put("statue", at, _xf(at - 3.0, side * 6.5, 0.0, Vector3.ONE * 1.6, -PI * 0.5 * side))
				_put("arch", at, _xf(at + 4.0, 0.0, 0.0, Vector3(1.6, 1.6, 1.6)))
			"sign":
				_put("post", at, _xf(at, lat, 0.7, Vector3(0.14, 1.4, 0.14)), Color("7a5a3c"))
				_put("plankbox", at, _xf(at, lat, 1.4, Vector3(1.1, 0.6, 0.1), -0.3))
			"cart_stop":
				_put("plankbox", at, _xf(at - 25.0, 1.6, 0.5, Vector3(0.9, 1.0, 1.4)))


func _waterfall(at: float, lat: float, height: float, width: float, curtain: bool) -> void:
	var fall := MeshInstance3D.new()
	fall.name = "Waterfall_%d" % int(at)
	fall.mesh = MESHES.card(width, height, 4)
	fall.material_override = _materials["fall"]
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var frame: Basis = path.frame(at)
	var bottom: float = -2.4 if not curtain else 0.0
	if curtain:
		# A curtain across the cave path: Lumo runs straight through it.
		fall.transform = Transform3D(frame, _point(at, 0.0, bottom))
	else:
		fall.transform = Transform3D(frame * Basis(Vector3.UP, PI * 0.5 * signf(lat)), _point(at, lat, bottom))
	add_child(fall)
	var mist := MeshInstance3D.new()
	mist.mesh = MESHES.card(width * 1.6, 3.0)
	mist.material_override = _materials["mist"]
	mist.transform = Transform3D(fall.transform.basis, fall.transform.origin + Vector3.UP * -0.4)
	add_child(mist)
	if not curtain:
		_put("rock0", at, _xf(at, lat - signf(lat) * 1.0, bottom - 0.5, Vector3(2.4, 1.2, 2.0)))
		_put("cliff", at, _xf(at, lat + signf(lat) * 2.2, bottom - 2.0, Vector3(width * 0.8, height + 2.0, 3.0)))


# ------------------------------------------------------------------ animals, light and mist

func _fauna() -> void:
	var at: float = 5.0
	var count: float = 0.5 if low else 1.0
	while at < path.length:
		var kind: String = _surface_of(at)
		var half: float = path.half_width_at(at)
		var lat: float = (half + _rng.randf_range(0.5, 3.0)) * (-1.0 if _rng.randf() < 0.5 else 1.0)
		if kind == "cave" or kind == "stone":
			for _f in range(int(4 * count)):
				var spot: float = at + _rng.randf_range(-4.0, 4.0)
				_put("firefly", at, _xf(spot, _rng.randf_range(-half - 2.0, half + 2.0), _rng.randf_range(0.6, 4.0), Vector3.ONE * 1.4), Color("e8ff7a"), Color(_rng.randf(), 0.08, 0.15, 2.0 / 4.0))
		else:
			if _rng.randf() < 0.7 * count:
				var wing: Color = [Color("4fc3ff"), Color("ffcf33"), Color("ff7ab0"), Color("b48cff")][_rng.randi() % 4]
				_put("butterfly", at, _xf(at, lat, _rng.randf_range(0.9, 2.2), Vector3.ONE * 1.4), wing, Color(_rng.randf(), 0.06, 0.35, 0.0))
			if _rng.randf() < 0.5 * count:
				_put("leafcard", at, _xf(at, _rng.randf_range(-half - 2.0, half + 2.0), 4.0, Vector3.ONE * 1.6), Color("8ccf4a"), Color(_rng.randf(), 0.0, 0.2, 3.0 / 4.0))
			# Sun shafts through gaps in the canopy.
			if _rng.randf() < 0.32 * count:
				var shaft := MeshInstance3D.new()
				shaft.mesh = MESHES.card(_rng.randf_range(2.0, 3.6), 16.0)
				shaft.material_override = _materials["shaft"]
				shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				shaft.visibility_range_end = 120.0
				var tilt := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, -0.45)
				var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
				shaft.transform = Transform3D(tilt, _point(at, side * _rng.randf_range(half + 1.5, half + 6.0), -1.5))
				add_child(shaft)
		if _floor(at) < -8.0 and _rng.randf() < 0.3:
			var haze := MeshInstance3D.new()
			haze.mesh = MESHES.card(16.0, 6.0)
			haze.material_override = _materials["mist"]
			haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			haze.visibility_range_end = 160.0
			haze.transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), _point(at, lat * 2.0, _floor(at) + 2.0))
			add_child(haze)
		at += _rng.randf_range(7.0, 11.0)
	# Parrots circling above the treetops.
	for index in range(14 if not low else 6):
		var spot: float = path.length * (float(index) + 0.5) / 14.0
		var colour: Color = [Color("ff4b3a"), Color("2fb7ff"), Color("ffd23a"), Color("37d67a")][index % 4]
		_put("bird", spot, _xf(spot, _rng.randf_range(-12.0, 12.0), _rng.randf_range(16.0, 24.0), Vector3.ONE * 1.8), colour, Color(_rng.randf(), _rng.randf_range(0.4, 0.9), 0.12, 1.0 / 4.0))


func _ambient_particles() -> void:
	if low:
		return
	_pollen = CPUParticles3D.new()
	_pollen.name = "Pollen"
	_pollen.amount = 24
	_pollen.lifetime = 6.0
	_pollen.preprocess = 6.0
	_pollen.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_pollen.emission_box_extents = Vector3(10, 4, 10)
	_pollen.direction = Vector3(0.3, 0.2, 0)
	_pollen.spread = 180.0
	_pollen.gravity = Vector3(0, -0.05, 0)
	_pollen.initial_velocity_min = 0.1
	_pollen.initial_velocity_max = 0.4
	_pollen.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025, 0.025)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(1.0, 0.95, 0.7)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.9, 0.6)
	quad.material = material
	_pollen.mesh = quad
	add_child(_pollen)


# ------------------------------------------------------------------ the far distance

func _background() -> void:
	var low_corner := Vector3(INF, INF, INF)
	var high_corner := Vector3(-INF, -INF, -INF)
	for at in _main_samples(20.0):
		var point: Vector3 = path.position_at(at, 0.0)
		low_corner = low_corner.min(point)
		high_corner = high_corner.max(point)
	var centre: Vector3 = (low_corner + high_corner) * 0.5
	var radius: float = maxf(high_corner.x - low_corner.x, high_corner.z - low_corner.z) * 0.5 + 180.0
	for index in range(18):
		var angle: float = TAU * float(index) / 18.0 + _rng.randf_range(-0.1, 0.1)
		var distance: float = radius + _rng.randf_range(0.0, 140.0)
		var at: Vector3 = centre + Vector3(cos(angle), 0.0, sin(angle)) * distance
		at.y = low_corner.y - 30.0
		var size := Vector3(_rng.randf_range(90.0, 160.0), _rng.randf_range(90.0, 190.0), _rng.randf_range(90.0, 160.0))
		_put("mountain", 0.0, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(size), at), Color.WHITE.darkened(_rng.randf() * 0.2))
		if index % 3 == 0:
			# A tall waterfall pours down the nearer mountains.
			var fall := MeshInstance3D.new()
			fall.mesh = MESHES.card(18.0, size.y * 0.9, 6)
			fall.material_override = _materials["fall"]
			fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var facing: Vector3 = (centre - at)
			facing.y = 0.0
			fall.transform = Transform3D(Basis.looking_at(-facing.normalized(), Vector3.UP), at + facing.normalized() * size.x * 0.82 + Vector3.UP * size.y * 0.15)
			add_child(fall)
	# The heart of the jungle: a stepped temple behind the finish, seen from afar.
	var finish: float = float(level.finish_s)
	var base: Vector3 = path.position_at(finish + 30.0, 0.0)
	for step in range(6):
		var width: float = 34.0 - float(step) * 5.0
		_put("templeblock", 0.0, Transform3D(Basis.from_scale(Vector3(width, 4.0, width)), base + Vector3.UP * (2.0 + float(step) * 4.0)), Color.WHITE.darkened(0.05 * float(step % 2)))
	_put("statue", finish, Transform3D(Basis.from_scale(Vector3.ONE * 3.0), base + Vector3.UP * 24.0))
	# A wide forest floor far below everything, so no gap ever shows the sky.
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(radius * 3.0, radius * 3.0)
	var floor_node := MeshInstance3D.new()
	floor_node.name = "ForestFloor"
	floor_node.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("24502e")
	floor_material.roughness = 1.0
	floor_node.material_override = floor_material
	floor_node.position = Vector3(centre.x, low_corner.y - 22.0, centre.z)
	floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_node)
