extends RefCounted
## Streckenkulisse von Lumo Kart: strukturierte Baeume und Pflanzen (Blender-Modelle,
## 3 LOD-Stufen, MultiMesh je Zelle), Strassenleuchten mit Lichtkegel und Lichtfleck,
## Reflektoren an den Leitplanken, Umgebungspartikel und Himmelsstimmung.
## Nur Aussehen: Streckenverlauf, Kollision, Tore und Spruenge bleiben unberuehrt.
## Aufruf: kart_world.gd nach dem Bau jeder Strecke (nicht im geometry_only-Modus).
## Profile: low (sicher spielbar), medium (ausgewogen), high, ultra (manuell,
## PerformanceManager.set_ultra(true)).

const LUMO_QUALITY = preload("res://scripts/systems/render/lumo_quality.gd")
const GROUND_PROFILE = preload("res://scripts/games/track_themes/track_ground_profile.gd")
const ADVENTURE_TUNNELS = preload("res://scripts/games/kart_adventure_tunnels.gd")
const TRACK_DETAIL = preload("res://scripts/games/kart_track_detail.gd")
const FOLIAGE_SHADER = preload("res://assets/shaders/kart_scenery_foliage.gdshader")
const GLOW_SHADER = preload("res://assets/shaders/kart_scenery_lamp_glow.gdshader")
const REFLECTOR_SHADER = preload("res://assets/shaders/kart_scenery_reflector.gdshader")
const PARTICLE_MIX_SHADER = preload("res://assets/shaders/kart_scenery_particles_mix.gdshader")
const PARTICLE_ADD_SHADER = preload("res://assets/shaders/kart_scenery_particles_add.gdshader")
const SKY_SHADER = preload("res://assets/shaders/kart_scenery_sky.gdshader")
const LIGHT_POOL = preload("res://scripts/games/visual/kart_scenery_light_pool.gd")
const MODEL_DIR := "res://assets/kart/scenery/models/"
const TEX_DIR := "res://assets/kart/scenery/textures/"

## LOD-Stufen [stufe, ab, bis] in Metern; Zellgroesse der MultiMesh-Gruppen.
const BUDGETS: Dictionary = {
	"low":
	{
		"lods": [[1, 0.0, 55.0], [2, 55.0, 185.0]],
		"cell": 80.0,
		"density": 0.55,
		"verge_range": 0.0,
		"verge_density": 0.0,
		"particles": 0.0,
		"lights": 0,
		"lamp_spacing": 64.0,
		"lamp_range": 150.0,
		"shadow_lods": [],
		"detail": 0.0,
		"reflectors": false,
		"extra_trees": 0.5,
	},
	"medium":
	{
		"lods": [[0, 0.0, 32.0], [1, 32.0, 88.0], [2, 88.0, 225.0]],
		"cell": 56.0,
		"density": 0.8,
		"verge_range": 40.0,
		"verge_density": 0.5,
		"particles": 0.45,
		"lights": 2,
		"lamp_spacing": 42.0,
		"lamp_range": 200.0,
		"shadow_lods": [],
		"detail": 1.0,
		"reflectors": true,
		"extra_trees": 0.8,
	},
	"high":
	{
		"lods": [[0, 0.0, 50.0], [1, 50.0, 125.0], [2, 125.0, 300.0]],
		"cell": 48.0,
		"density": 1.0,
		"verge_range": 60.0,
		"verge_density": 1.0,
		"particles": 1.0,
		"lights": 4,
		"lamp_spacing": 30.0,
		"lamp_range": 260.0,
		"shadow_lods": [0],
		"detail": 1.0,
		"reflectors": true,
		"extra_trees": 1.0,
	},
	"ultra":
	{
		"lods": [[0, 0.0, 78.0], [1, 78.0, 170.0], [2, 170.0, 420.0]],
		"cell": 48.0,
		"density": 1.25,
		"verge_range": 90.0,
		"verge_density": 1.6,
		"particles": 1.7,
		"lights": 8,
		"lamp_spacing": 24.0,
		"lamp_range": 360.0,
		"shadow_lods": [0, 1],
		"detail": 1.0,
		"reflectors": true,
		"extra_trees": 1.4,
	},
}

## Je Strecke: Baumarten (fuer world._tree), Strassenrand-Bewuchs, Leuchten,
## Partikel und Licht. "night": 0 Tag .. 1 Nacht (Lichtkegel, dynamische Lichter).
const THEMES: Dictionary = {
	"sonnenhafen":
	{
		"trees": ["laubbaum", "laubbaum_b", "nadelbaum", "laubbaum", "palme"],
		"verge": ["wiese"],
		"bushes": ["busch_bluehend", "busch"],
		"rocks": ["fels_flach"],
		"lamp": "leuchte_hafen",
		"lamp_colors": [Color("ffd59a")],
		"night": 0.0,
		"particles": ["pollen", "gischt"],
		"wind": 0.55,
		"sky": "mittelmeer",
	},
	"zauberwald":
	{
		"trees": ["zauberbaum", "zauberbaum", "laubbaum_b"],
		"verge": ["zauberflur", "farnflur"],
		"bushes": ["busch", "busch_bluehend"],
		"rocks": ["fels"],
		"lamp": "leuchte_wald",
		"lamp_colors": [Color("ffcf7a"), Color("9fffe0")],
		"night": 0.55,
		"particles": ["laub", "gluehwuermchen"],
		"wind": 0.45,
		"leaf_glow": 0.35,
		"sky": "zauberwald",
	},
	"bergwelt":
	{
		"trees": ["laubbaum", "nadelbaum", "laubbaum_b"],
		"particles": ["pollen"],
		"wind": 0.7,
	},
	"holo_city":
	{
		"trees": ["laubbaum_b"],
		"lamp": "leuchte_neon",
		"lamp_colors": [Color("5ef2ff"), Color("ff5ed8"), Color("a98bff")],
		"night": 1.0,
		"particles": ["neon"],
		"wind": 0.3,
	},
	"jungle_temple":
	{
		"trees": ["palme", "dschungelbaum"],
		"verge": ["farnflur", "wiese"],
		"bushes": ["busch", "busch_bluehend"],
		"rocks": ["fels"],
		"extra_trees": ["dschungelbaum", "palme"],
		"lamp": "leuchte_fackel",
		"lamp_colors": [Color("ffb05a")],
		"night": 0.15,
		"particles": ["pollen"],
		"wind": 0.5,
		"sky": "tropen",
	},
	"candy_cloud":
	{
		"lamp": "leuchte_kette",
		"lamp_colors": [Color("ffd6f0"), Color("fff1a8"), Color("b8e8ff")],
		"night": 0.2,
		"particles": ["funkeln"],
		"wind": 0.4,
	},
	"volcano_night":
	{
		"rocks": ["fels", "fels_flach"],
		"lamp": "leuchte_fackel",
		"lamp_colors": [Color("ff8a3a")],
		"night": 1.0,
		"particles": ["glut"],
		"wind": 0.3,
		"rock_tint": Color(0.36, 0.33, 0.36),
	},
	"winter_sprint":
	{
		"trees": ["winterbaum", "nadelbaum"],
		"verge": ["schneegras"],
		"bushes": [],
		"rocks": ["fels"],
		"extra_trees": ["winterbaum", "winterbaum", "nadelbaum"],
		"lamp": "leuchte_hafen",
		"lamp_colors": [Color("ffd08a")],
		"night": 0.25,
		"particles": ["schnee"],
		"wind": 0.6,
		"snow": 0.65,
		"rock_tint": Color(0.55, 0.57, 0.62),
		"sky": "winter",
	},
	"galaxy_ringway":
	{
		"lamp": "leuchte_neon",
		"lamp_colors": [Color("9a7bff"), Color("6fe7ff")],
		"night": 1.0,
		"particles": ["sterne"],
		"wind": 0.0,
	},
	"desert_drift":
	{
		"verge": ["trockengras"],
		"rocks": ["fels", "fels_flach"],
		"extra_trees": ["palme"],
		"lamp": "leuchte_fackel",
		"lamp_colors": [Color("ffc070")],
		"night": 0.0,
		"particles": ["sand"],
		"wind": 0.8,
		"rock_tint": Color(0.62, 0.5, 0.38),
		"sky": "wueste",
	},
	"learning_lab":
	{
		"lamp": "leuchte_neon",
		"lamp_colors": [Color("5fd8ff"), Color("ffffff")],
		"night": 0.3,
		"particles": ["neon"],
		"wind": 0.0,
	},
	"crystal_canyon":
	{
		"rocks": ["fels", "fels_flach"],
		"lamp": "leuchte_neon",
		"lamp_colors": [Color("c7a6ff"), Color("7fe3ff")],
		"night": 0.6,
		"particles": ["kristall"],
		"wind": 0.2,
		"rock_tint": Color(0.5, 0.45, 0.62),
	},
	"jungle_emerald_3600":
	{
		"trees": ["dschungelbaum", "palme"],
		"lamp": "leuchte_fackel",
		"lamp_colors": [Color("ffb867")],
		"night": 0.1,
		"particles": ["pollen", "gluehwuermchen"],
		"wind": 0.45,
	},
}

## Umgebungspartikel: Atlaszelle (3,3) enthaelt 8 Blaetter (0-7) und 8 runde Sprites (8-15).
const PARTICLES: Dictionary = {
	"laub":
	{
		"add": false, "count": 140, "sprite": [0, 8], "size": 0.16, "box": Vector3(56, 16, 56),
		"velocity": Vector3(0.9, -0.55, 0.3), "sway": 1.2, "tumble": 1.0, "color": Color(1, 1, 1, 1)
	},
	"gluehwuermchen":
	{
		"add": true, "count": 90, "sprite": [11, 1], "size": 0.13, "box": Vector3(50, 6, 50),
		"velocity": Vector3(0.05, 0.08, 0.05), "sway": 0.8, "tumble": 0.0, "color": Color(1.0, 0.95, 0.5, 1.0)
	},
	"pollen":
	{
		"add": false, "count": 120, "sprite": [15, 1], "size": 0.06, "box": Vector3(46, 12, 46),
		"velocity": Vector3(0.35, 0.06, 0.15), "sway": 0.6, "tumble": 0.0, "color": Color(1.0, 0.97, 0.8, 0.8)
	},
	"gischt":
	{
		"add": false, "count": 70, "sprite": [8, 1], "size": 0.22, "box": Vector3(60, 10, 60),
		"velocity": Vector3(0.6, 0.25, 0.2), "sway": 0.4, "tumble": 0.0, "color": Color(1, 1, 1, 0.45)
	},
	"neon":
	{
		"add": true, "count": 140, "sprite": [14, 2], "size": 0.09, "box": Vector3(50, 18, 50),
		"velocity": Vector3(0.0, 0.35, 0.0), "sway": 0.5, "tumble": 0.0, "color": Color(0.6, 0.95, 1.0, 1.0)
	},
	"funkeln":
	{
		"add": true, "count": 110, "sprite": [11, 1], "size": 0.11, "box": Vector3(50, 16, 50),
		"velocity": Vector3(0.0, 0.2, 0.0), "sway": 0.6, "tumble": 0.0, "color": Color(1.0, 0.85, 0.95, 1.0)
	},
	"glut":
	{
		"add": true, "count": 170, "sprite": [9, 2], "size": 0.08, "box": Vector3(50, 18, 50),
		"velocity": Vector3(0.25, 1.1, 0.1), "sway": 0.9, "tumble": 0.0, "color": Color(1.0, 0.55, 0.18, 1.0)
	},
	"schnee":
	{
		"add": false, "count": 260, "sprite": [8, 1], "size": 0.075, "box": Vector3(44, 18, 44),
		"velocity": Vector3(0.35, -1.0, 0.1), "sway": 0.9, "tumble": 0.0, "color": Color(1, 1, 1, 0.95)
	},
	"sterne":
	{
		"add": true, "count": 120, "sprite": [14, 2], "size": 0.08, "box": Vector3(60, 24, 60),
		"velocity": Vector3(0.0, 0.05, 0.0), "sway": 0.3, "tumble": 0.0, "color": Color(0.85, 0.8, 1.0, 1.0)
	},
	"sand":
	{
		"add": false, "count": 200, "sprite": [12, 2], "size": 0.07, "box": Vector3(50, 5, 50),
		"velocity": Vector3(2.6, 0.05, 0.6), "sway": 0.5, "tumble": 0.0, "color": Color(0.95, 0.82, 0.6, 0.55)
	},
	"kristall":
	{
		"add": true, "count": 110, "sprite": [14, 2], "size": 0.07, "box": Vector3(50, 16, 50),
		"velocity": Vector3(0.0, 0.2, 0.0), "sway": 0.5, "tumble": 0.0, "color": Color(0.85, 0.75, 1.0, 1.0)
	},
}

static var _meshes: Dictionary = {}
static var _textures: Dictionary = {}


## Aktives Kulissenprofil: low | medium | high | ultra.
static func quality_name(world) -> String:
	if world.low_detail:
		return "low"
	var tier: String = LUMO_QUALITY.tier()
	if tier == "high":
		var loop := Engine.get_main_loop() as SceneTree
		var performance: Node = null
		if loop != null and loop.root != null:
			performance = loop.root.get_node_or_null("PerformanceManager")
		if performance != null and performance.has_method("is_ultra") and performance.call("is_ultra"):
			return "ultra"
	if tier == "low":
		return "medium"  # world.low_detail ist die verbindliche Leicht-Wahl des Rennens
	return tier


static func theme(track_id: String) -> Dictionary:
	return THEMES.get(track_id, {})


## Baumart fuer world._tree(): deterministisch aus der Position, ohne Zufallsstrom.
static func tree_species(track_id: String, at: Vector3) -> String:
	var trees: Array = theme(track_id).get("trees", ["laubbaum", "laubbaum_b", "nadelbaum"])
	var h: int = absi(int(floor(at.x * 7.13) * 73856093) ^ int(floor(at.z * 5.31) * 19349663))
	return str(trees[h % trees.size()])


static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(TEX_DIR + name + ".png")
	return _textures[name]


## Mesh einer Art und LOD-Stufe aus dem Blender-Export (gecacht).
static func mesh(species: String, lod: int) -> Mesh:
	var key := "%s_lod%d" % [species, lod]
	if _meshes.has(key):
		return _meshes[key]
	var scene: PackedScene = load(MODEL_DIR + species + ".glb")
	var found: Mesh = null
	if scene != null:
		var instance: Node = scene.instantiate()
		var node: Node = instance.find_child(key, true, false)
		if node is MeshInstance3D:
			found = (node as MeshInstance3D).mesh
		instance.free()
	_meshes[key] = found
	return found


static func build(world) -> void:
	var tier: String = quality_name(world)
	var budget: Dictionary = BUDGETS[tier]
	var look: Dictionary = theme(world.track_id)
	var root := Node3D.new()
	root.name = "KartScenery"
	world.add_child(root)
	var stats := {"quality": tier, "species": {}, "lamps": 0, "reflectors": 0, "particles": 0}
	_roadside_flora(world, look, budget)
	var material: ShaderMaterial = foliage_material(world, look, budget)
	_instance_plants(world, root, material, budget, stats)
	stats.lamps = _lamps(world, root, look, budget)
	stats.reflectors = _reflectors(world, root, budget)
	stats.particles = _particles(world, root, look, budget)
	_sky(world, look)
	world.set_meta("scenery_stats", stats)


# ------------------------------------------------------------------ Pflanzen


static func foliage_material(world, look: Dictionary, budget: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FOLIAGE_SHADER
	material.set_shader_parameter("foliage_albedo", texture("foliage_albedo"))
	material.set_shader_parameter("foliage_normal", texture("foliage_normal"))
	material.set_shader_parameter("bark_albedo", texture("bark_albedo"))
	material.set_shader_parameter("bark_normal", texture("bark_normal"))
	material.set_shader_parameter("rock_albedo", texture("rock_albedo"))
	material.set_shader_parameter("rock_normal", texture("rock_normal"))
	material.set_shader_parameter("detail", float(budget.detail))
	material.set_shader_parameter("wind_strength", float(look.get("wind", 0.5)))
	material.set_shader_parameter("snow_cover", float(look.get("snow", 0.0)))
	material.set_shader_parameter("leaf_glow", float(look.get("leaf_glow", 0.0)))
	var environment: Environment = _environment(world)
	if environment != null:
		material.set_shader_parameter("fill_color", environment.ambient_light_color)
		material.set_shader_parameter("fill", float(look.get("fill", 0.16)))
	var sun: DirectionalLight3D = _sun(world)
	if sun != null:
		material.set_shader_parameter("sun_direction", -sun.transform.basis.z)
		material.set_shader_parameter("sun_color", sun.light_color)
		material.set_shader_parameter("translucency", clampf(sun.light_energy * 0.75, 0.2, 0.9))
	return material


static func _environment(world) -> Environment:
	for child in world.get_children():
		if child is WorldEnvironment:
			return (child as WorldEnvironment).environment
	return null


static func _sun(world) -> DirectionalLight3D:
	for child in world.get_children():
		if child is DirectionalLight3D and (child as DirectionalLight3D).shadow_enabled:
			return child
	for child in world.get_children():
		if child is DirectionalLight3D:
			return child
	return null


static func _hash01(a: float, b: float, salt: int) -> float:
	var h: int = int(floor(a * 13.7)) * 73856093 ^ int(floor(b * 11.3)) * 19349663 ^ salt * 83492791
	return float(absi(h) % 10007) / 10007.0


## Bodenhoehe neben der Fahrbahn; NAN wenn dort nichts stehen kann.
static func ground_at(world, at: Vector3, road_y: float) -> float:
	if world.track_id in ["sonnenhafen", "zauberwald", "holo_city"]:
		var g: float = world._ground_height(at.x, at.z)
		if g < -1.6 or absf(road_y - g) > 2.2:
			return NAN
		return g
	if world.track_id in ["bergwelt", "candy_cloud", "galaxy_ringway"]:
		return NAN
	if world.track_id == "jungle_emerald_3600":
		return road_y - 0.08
	var plane: float = GROUND_PROFILE.surface_height(world.track_id)
	if road_y - plane < 3.2 and road_y - plane > -1.0:
		return road_y - 0.05
	return NAN


static func _free_spot(world, d: float, at: Vector3, clearance: float) -> bool:
	if world.in_gap(d) or world._is_bridge(d) or ADVENTURE_TUNNELS.contains(world, d, 14.0):
		return false
	if world.ramp_height(d) > 0.02:
		return false
	if world.has_meta("production_tunnel") and world.production_tunnels != null:
		if world.production_tunnels.has_method("contains_distance"):
			if world.production_tunnels.call("contains_distance", d):
				return false
	return not world._near_road(at, clearance)


## Strassenrand: Gras-/Blumenflecken, Bueschel, Felsen und (wo die Strecke kahl ist)
## zusaetzliche Baeume. Eigener Zufallsstrom, aendert keine bestehende Kulisse.
static func _roadside_flora(world, look: Dictionary, budget: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world.definition.get("seed", 1)) + 99173
	var verges: Array = look.get("verge", [])
	var bushes: Array = look.get("bushes", [])
	var rocks: Array = look.get("rocks", [])
	var extra: Array = look.get("extra_trees", [])
	var reserved: Array[Dictionary] = TRACK_DETAIL.accepted_sites(world)
	var verge_density: float = float(budget.verge_density)
	var step: float = 6.5
	var count: int = floori(world.length / step)
	for i in range(count):
		var d: float = (float(i) + 0.5) * step
		for side in [-1.0, 1.0]:
			if not verges.is_empty() and verge_density > 0.0 and rng.randf() < 0.75 * verge_density:
				var lateral: float = rng.randf_range(6.9, 10.5)
				var at: Vector3 = world.position_at(d + rng.randf_range(-2.0, 2.0), side * lateral)
				var g: float = ground_at(world, at, at.y)
				if not is_nan(g) and _free_spot(world, d, at, 6.6):
					at.y = g
					_plant(world, str(verges[rng.randi() % verges.size()]), at,
						rng.randf_range(0.75, 1.25), rng.randf() * TAU, rng)
			if not bushes.is_empty() and rng.randf() < 0.22:
				var lateral_b: float = rng.randf_range(8.0, 13.0)
				var at_b: Vector3 = world.position_at(d, side * lateral_b)
				var gb: float = ground_at(world, at_b, at_b.y)
				if not is_nan(gb) and _free_spot(world, d, at_b, 7.4):
					at_b.y = gb
					_plant(world, str(bushes[rng.randi() % bushes.size()]), at_b,
						rng.randf_range(0.8, 1.5), rng.randf() * TAU, rng)
			if not rocks.is_empty() and rng.randf() < 0.07:
				var lateral_r: float = rng.randf_range(8.5, 16.0)
				var at_r: Vector3 = world.position_at(d, side * lateral_r)
				var gr: float = ground_at(world, at_r, at_r.y)
				if not is_nan(gr) and _free_spot(world, d, at_r, 8.0):
					at_r.y = gr - 0.15
					var tint: Color = look.get("rock_tint", Color(0.5, 0.5, 0.48))
					_plant(world, str(rocks[rng.randi() % rocks.size()]), at_r,
						rng.randf_range(0.6, 1.8), rng.randf() * TAU, rng, tint)
			if not extra.is_empty() and rng.randf() < 0.18 * float(budget.extra_trees):
				var lateral_t: float = rng.randf_range(11.0, 19.0)
				var at_t: Vector3 = world.position_at(d, side * lateral_t)
				var gt: float = ground_at(world, at_t, at_t.y)
				if is_nan(gt) or not _free_spot(world, d, at_t, 9.5):
					continue
				var on_plot := false
				for site: Dictionary in reserved:
					var plot: Vector3 = site.position
					if Vector2(at_t.x - plot.x, at_t.z - plot.z).length() < float(site.radius) + 3.0:
						on_plot = true
						break
				if on_plot:
					continue
				at_t.y = gt
				_plant(world, str(extra[rng.randi() % extra.size()]), at_t,
					rng.randf_range(0.85, 1.25), rng.randf() * TAU, rng)


static func _plant(world, species: String, at: Vector3, scale: float, yaw: float,
		rng: RandomNumberGenerator, tint: Color = Color(-1, 0, 0)) -> void:
	var color := tint
	if color.r < 0.0:
		color = Color(
			0.5 + rng.randf_range(-0.05, 0.05), 0.5 + rng.randf_range(-0.06, 0.05),
			0.5 + rng.randf_range(-0.06, 0.04)
		)
	world.plant_scenery(species, at, scale, yaw, color, rng.randf())


static func _instance_plants(world, root: Node3D, material: ShaderMaterial,
		budget: Dictionary, stats: Dictionary) -> void:
	var cell_size: float = float(budget.cell)
	var density: float = float(budget.density)
	for species in world.scenery_plants:
		var entry: Dictionary = world.scenery_plants[species]
		var is_verge: bool = species in ["wiese", "trockengras", "schneegras", "farnflur", "zauberflur"]
		var is_small: bool = is_verge or species.begins_with("busch")
		var cells: Dictionary = {}
		var kept := 0
		for i in range(entry.transforms.size()):
			var t: Transform3D = entry.transforms[i]
			var keep: float = density if not is_verge else 1.0
			if keep < 1.0 and _hash01(t.origin.x, t.origin.z, 5) > keep:
				continue
			var key := Vector2i(floori(t.origin.x / cell_size), floori(t.origin.z / cell_size))
			if not cells.has(key):
				cells[key] = {"t": [], "c": []}
			cells[key].t.append(t)
			cells[key].c.append(entry.custom[i])
			kept += 1
		stats.species[species] = kept
		for key in cells:
			var group: Dictionary = cells[key]
			var center := Vector3((key.x + 0.5) * cell_size, 0.0, (key.y + 0.5) * cell_size)
			var height_sum := 0.0
			for t: Transform3D in group.t:
				height_sum += t.origin.y
			center.y = height_sum / group.t.size()
			for lod_entry: Array in budget.lods:
				var lod: int = lod_entry[0]
				var begin: float = lod_entry[1]
				var end: float = lod_entry[2]
				if is_verge:
					if lod != int(budget.lods[0][0]) or float(budget.verge_range) <= 0.0:
						continue
					begin = 0.0
					end = float(budget.verge_range)
				elif is_small:
					end = minf(end, 140.0)
					if begin >= end:
						continue
				var lod_mesh: Mesh = mesh(species, lod)
				if lod_mesh == null:
					continue
				var multimesh := MultiMesh.new()
				multimesh.transform_format = MultiMesh.TRANSFORM_3D
				multimesh.use_custom_data = true
				multimesh.mesh = lod_mesh
				multimesh.instance_count = group.t.size()
				for i in range(group.t.size()):
					var t: Transform3D = group.t[i]
					t.origin -= center
					multimesh.set_instance_transform(i, t)
					multimesh.set_instance_custom_data(i, group.c[i])
				var node := MultiMeshInstance3D.new()
				node.name = "Flora_%s_%d_%d_lod%d" % [species, key.x, key.y, lod]
				node.multimesh = multimesh
				node.position = center
				node.material_override = material
				node.visibility_range_begin = begin
				node.visibility_range_end = end
				node.visibility_range_begin_margin = 4.0 if begin > 0.0 else 0.0
				node.visibility_range_end_margin = 4.0
				var casts: bool = lod in budget.shadow_lods and not is_verge
				node.cast_shadow = (
					GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					if casts
					else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				)
				node.set_meta("scenery_species", species)
				node.set_meta("scenery_lod", lod)
				root.add_child(node)


# ------------------------------------------------------------------ Leuchten


static func _lamp_spot_ok(world, d: float, at: Vector3) -> bool:
	if world.in_gap(d) or ADVENTURE_TUNNELS.contains(world, d, 18.0) or world.ramp_height(d) > 0.02:
		return false
	if not world.loop_layout.is_empty():
		var start: float = float(world.loop_layout.get("start", -1000.0))
		if d > start - 30.0 and d < start + 90.0:
			return false
	if world._near_road(at, 6.4):
		return false
	if world.track_id in ["sonnenhafen", "zauberwald"]:
		var g: float = world._ground_height(at.x, at.z)
		if absf(at.y - g) > 1.4:
			return false
	elif world.track_id == "holo_city":
		pass  # Hochstrasse: Stelen stehen auf dem Fahrbahnsockel
	return true


static func _lamps(world, root: Node3D, look: Dictionary, budget: Dictionary) -> int:
	var kind: String = look.get("lamp", "")
	if kind.is_empty():
		return 0
	var colors: Array = look.get("lamp_colors", [Color("ffd59a")])
	var night: float = float(look.get("night", 0.0))
	var spacing: float = float(budget.lamp_spacing)
	if kind == "leuchte_kette":
		spacing = 14.0 * ceilf(spacing / 14.0)
	var lateral: float = world.RAIL_LATERAL + 1.3
	var count: int = floori(world.length / spacing)
	var transforms: Array[Transform3D] = []
	var customs: Array[Color] = []
	var heads := PackedVector3Array()
	var head_colors: Array[Color] = []
	var head_local: Vector3 = {
		"leuchte_hafen": Vector3(-1.25, 4.3, 0.0),
		"leuchte_wald": Vector3(-0.95, 2.9, 0.0),
		"leuchte_neon": Vector3(-0.2, 5.2, 0.0),
		"leuchte_fackel": Vector3(0.0, 3.1, 0.0),
		"leuchte_kette": Vector3(0.0, 3.4, 7.0),
	}.get(kind, Vector3(0, 4, 0))
	for i in range(count):
		var d: float = (float(i) + 0.25) * spacing
		var side: float = -1.0 if i % 2 == 0 else 1.0
		if kind == "leuchte_kette":
			side = 1.0 if (i / 6) % 2 == 0 else -1.0
		var basis: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d, side * lateral)
		if not _lamp_spot_ok(world, d, at):
			continue
		var right: Vector3 = basis.x * side
		right.y = 0.0
		right = right.normalized()
		var lamp_basis := Basis(right, Vector3.UP, right.cross(Vector3.UP))
		var lamp := Transform3D(lamp_basis, at - Vector3.UP * 0.02)
		transforms.append(lamp)
		var color: Color = colors[i % colors.size()]
		customs.append(Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 1.0))
		heads.append(lamp * head_local)
		head_colors.append(color)
	if transforms.is_empty():
		return 0
	var body := StandardMaterial3D.new()
	body.albedo_texture = texture("lamp_albedo")
	body.metallic = 0.55
	body.roughness = 0.42
	body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var glow := ShaderMaterial.new()
	glow.shader = GLOW_SHADER
	glow.set_shader_parameter("night", night)
	glow.set_shader_parameter("intensity", 1.0 if night > 0.4 else 0.75)
	var meshes: Array[Mesh] = []
	for lod in range(3):
		var source: Mesh = mesh(kind, lod)
		if source == null:
			return 0
		var copy: ArrayMesh = source.duplicate()
		# Reihenfolge aus Blender: 0 Koerper (lamp_body), 1 Licht (lamp_glow).
		for s in range(copy.get_surface_count()):
			copy.surface_set_material(s, glow if s == 1 else body)
		meshes.append(copy)
	var cell_size: float = maxf(float(budget.cell), 64.0)
	var cells: Dictionary = {}
	for i in range(transforms.size()):
		var key := Vector2i(
			floori(transforms[i].origin.x / cell_size), floori(transforms[i].origin.z / cell_size)
		)
		if not cells.has(key):
			cells[key] = []
		cells[key].append(i)
	var lamp_range: float = float(budget.lamp_range)
	var ranges: Array = [[0, 0.0, 48.0], [1, 48.0, 130.0], [2, 130.0, lamp_range]]
	if world.low_detail:
		ranges = [[1, 0.0, 70.0], [2, 70.0, lamp_range]]
	for key in cells:
		var ids: Array = cells[key]
		var center := Vector3.ZERO
		for i in ids:
			center += transforms[i].origin
		center /= float(ids.size())
		for entry: Array in ranges:
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_custom_data = true
			multimesh.mesh = meshes[int(entry[0])]
			multimesh.instance_count = ids.size()
			for j in range(ids.size()):
				var t: Transform3D = transforms[ids[j]]
				t.origin -= center
				multimesh.set_instance_transform(j, t)
				multimesh.set_instance_custom_data(j, customs[ids[j]])
			var node := MultiMeshInstance3D.new()
			node.name = "Lamps_%s_%d_%d_lod%d" % [kind, key.x, key.y, int(entry[0])]
			node.multimesh = multimesh
			node.position = center
			node.visibility_range_begin = float(entry[1])
			node.visibility_range_end = float(entry[2])
			node.visibility_range_begin_margin = 4.0 if float(entry[1]) > 0.0 else 0.0
			node.visibility_range_end_margin = 4.0
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.set_meta("scenery_lamp", kind)
			root.add_child(node)
	var light_count: int = int(budget.lights)
	if night < 0.3:
		light_count = mini(light_count, 1) if light_count > 0 else 0
	if light_count > 0:
		var pool: Node3D = LIGHT_POOL.new()
		pool.name = "LampLightPool"
		pool.setup(heads, head_colors, light_count, 0.6 + night * 1.2, 10.0 + night * 3.0)
		root.add_child(pool)
	world.set_meta("scenery_lamp_heads", heads)
	return transforms.size()


# ------------------------------------------------------------------ Reflektoren


static func _reflectors(world, root: Node3D, budget: Dictionary) -> int:
	if not bool(budget.reflectors) or world.track_id == "bergwelt":
		return 0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.15)
	var material := ShaderMaterial.new()
	material.shader = REFLECTOR_SHADER
	var spacing := 8.0
	var count: int = floori(world.length / spacing)
	var cells: Dictionary = {}
	var placed := 0
	for i in range(count):
		var d: float = (float(i) + 0.5) * spacing
		if world.in_gap(d) or world.ramp_height(d) > 0.02:
			continue
		var basis: Basis = world.frame(d)
		var open_side: float = world.ACTION.open_side(world.action, d)
		for side in [-1.0, 1.0]:
			if side == open_side:
				continue
			var at: Vector3 = world.position_at(d, side * (world.RAIL_LATERAL - 0.15)) + basis.y * 0.76
			var key := Vector2i(floori(at.x / 96.0), floori(at.z / 96.0))
			if not cells.has(key):
				cells[key] = []
			var tint := Color(1.0, 0.62, 0.18, 1.0) if side > 0.0 else Color(0.95, 0.97, 1.0, 1.0)
			cells[key].append([Transform3D(basis, at), tint])
			placed += 1
	for key in cells:
		var items: Array = cells[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = quad
		multimesh.instance_count = items.size()
		var center: Vector3 = items[0][0].origin
		for j in range(items.size()):
			var t: Transform3D = items[j][0]
			t.origin -= center
			multimesh.set_instance_transform(j, t)
			multimesh.set_instance_custom_data(j, items[j][1])
		var node := MultiMeshInstance3D.new()
		node.name = "Reflectors_%d_%d" % [key.x, key.y]
		node.multimesh = multimesh
		node.position = center
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 160.0
		root.add_child(node)
	return placed


# ------------------------------------------------------------------ Partikel


static func _particles(world, root: Node3D, look: Dictionary, budget: Dictionary) -> int:
	var factor: float = float(budget.particles)
	if factor <= 0.0:
		return 0
	var total := 0
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for kind in look.get("particles", []):
		var spec: Dictionary = PARTICLES.get(kind, {})
		if spec.is_empty():
			continue
		var count: int = maxi(8, roundi(float(spec.count) * factor))
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = quad
		multimesh.instance_count = count
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(world.track_id) + str(kind))
		for i in range(count):
			multimesh.set_instance_transform(i, Transform3D.IDENTITY)
			multimesh.set_instance_custom_data(
				i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf())
			)
		var material := ShaderMaterial.new()
		material.shader = PARTICLE_ADD_SHADER if bool(spec.add) else PARTICLE_MIX_SHADER
		material.set_shader_parameter("atlas", texture("foliage_albedo"))
		material.set_shader_parameter("sprite_first", int(spec.sprite[0]))
		material.set_shader_parameter("sprite_count", int(spec.sprite[1]))
		material.set_shader_parameter("box_size", spec.box)
		material.set_shader_parameter("velocity", spec.velocity)
		material.set_shader_parameter("sway", float(spec.sway))
		material.set_shader_parameter("tumble", float(spec.tumble))
		material.set_shader_parameter("particle_size", float(spec.size))
		material.set_shader_parameter("tint", spec.color)
		var node := MultiMeshInstance3D.new()
		node.name = "AmbientParticles_" + str(kind)
		node.multimesh = multimesh
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Die Teilchen werden im Shader um die Kamera gewickelt: nie wegschneiden.
		node.custom_aabb = AABB(Vector3(-5000, -500, -5000), Vector3(10000, 1000, 10000))
		root.add_child(node)
		total += count
	return total


# ------------------------------------------------------------------ Himmel

const SKIES: Dictionary = {
	"mittelmeer":
	{
		"zenith": Color("2f6fc4"), "horizon": Color("a9cdea"), "haze": Color("f1d9b8"),
		"ground": Color("8fa3a8"), "clouds": 0.42, "cloud_color": Color("fffaf2"),
		"cloud_shadow": Color("aab8cc"), "sun_size": 0.03, "stars": 0.0, "aurora": 0.0, "energy": 1.0,
	},
	"zauberwald":
	{
		"zenith": Color("2a4f7a"), "horizon": Color("8fc9c2"), "haze": Color("d6c6e8"),
		"ground": Color("2f4a44"), "clouds": 0.35, "cloud_color": Color("f3e9ff"),
		"cloud_shadow": Color("8b8fb8"), "sun_size": 0.025, "stars": 0.25, "aurora": 0.0, "energy": 0.95,
	},
	"tropen":
	{
		"zenith": Color("2e78c9"), "horizon": Color("a6dde0"), "haze": Color("e8efd0"),
		"ground": Color("5c7a5a"), "clouds": 0.5, "cloud_color": Color("ffffff"),
		"cloud_shadow": Color("a8bfcf"), "sun_size": 0.03, "stars": 0.0, "aurora": 0.0, "energy": 1.0,
	},
	"winter":
	{
		"zenith": Color("355d9e"), "horizon": Color("b8cbe6"), "haze": Color("f2d9cf"),
		"ground": Color("b9c7d6"), "clouds": 0.3, "cloud_color": Color("fbfbff"),
		"cloud_shadow": Color("9eaecb"), "sun_size": 0.028, "stars": 0.0, "aurora": 0.35, "energy": 0.95,
	},
	"wueste":
	{
		"zenith": Color("3b78c2"), "horizon": Color("e6cfa2"), "haze": Color("f4d6a6"),
		"ground": Color("b08a5c"), "clouds": 0.15, "cloud_color": Color("fff6e8"),
		"cloud_shadow": Color("c9b49a"), "sun_size": 0.035, "stars": 0.0, "aurora": 0.0, "energy": 1.05,
	},
}


static func _sky(world, look: Dictionary) -> void:
	var preset: Dictionary = SKIES.get(look.get("sky", ""), {})
	if preset.is_empty():
		return
	for child in world.get_children():
		if not (child is WorldEnvironment):
			continue
		var environment: Environment = (child as WorldEnvironment).environment
		if environment == null or environment.sky == null:
			return
		if not (environment.sky.sky_material is ProceduralSkyMaterial):
			return
		var sky_material := ShaderMaterial.new()
		sky_material.shader = SKY_SHADER
		for key in preset:
			sky_material.set_shader_parameter(key, preset[key])
		var sky := Sky.new()
		sky.sky_material = sky_material
		sky.process_mode = Sky.PROCESS_MODE_QUALITY
		sky.radiance_size = Sky.RADIANCE_SIZE_128
		environment.sky = sky
		# Der Tiefennebel faerbte den ganzen Himmel fast weiss; nur noch ein Hauch.
		environment.fog_sky_affect = 0.12
		world.set_meta("scenery_sky", look.get("sky", ""))
		return
