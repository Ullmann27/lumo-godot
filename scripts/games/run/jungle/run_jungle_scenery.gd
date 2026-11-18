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
const ART = preload("res://scripts/games/run/jungle/run_jungle_art.gd")
const CHUNK: float = 80.0
## Variants that share one mesh (and so one draw call per stretch).
const ALIAS: Dictionary = {
	"fern2": "fern0", "fern3": "fern1", "leaf2": "leaf0", "leaf3": "leaf1", "tree3": "tree0", "tree4": "tree1",
	"tree5": "tree2", "grass1": "grass0", "liana2": "liana2", "flower1": "flower0", "flower2": "flower0", "flower3": "flower0",
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
	"cave": [3, Color("8a877c"), Color("5f8576")],
	"rail": [0, Color("857a6c"), Color("6c6458")],
	"gold": [2, Color("f0c862"), Color("d9a63a")],
}
## Per quality tier (low, medium, high): how far the detailed tree meshes reach,
## how far plants are drawn, how dense the jungle grows, how far the sun casts shadows.
const TREE_DETAIL: Array[float] = [0.0, 28.0, 62.0]
const PLANT_RANGE: Array[float] = [48.0, 66.0, 90.0]
const DENSITY: Array[float] = [0.55, 1.0, 1.35]
const SHADOW_RANGE: Array[float] = [0.0, 32.0, 60.0]
## The light of each part of the path (blended along the way in follow()).
const MOODS: Array[Dictionary] = [
	# Lichtung: golden morning light.
	{"sun": Color("ffd391"), "energy": 1.8, "ambient": Color("e0eab8"), "fog": Color("cfe0b8"), "top": Color("3f8be0"), "horizon": Color("ffe0a8"), "shaft": Color(1.0, 0.85, 0.5, 0.24)},
	# Wurzelpfad: green and warm under the roof of leaves.
	{"sun": Color("ffe0a8"), "energy": 1.65, "ambient": Color("cfe8b8"), "fog": Color("b5d6b0"), "top": Color("3a86d8"), "horizon": Color("f2e6b0"), "shaft": Color(1.0, 0.9, 0.6, 0.22)},
	# Kronenwege: airy and bright high up.
	{"sun": Color("fff1d6"), "energy": 2.0, "ambient": Color("dcefff"), "fog": Color("cfe6f2"), "top": Color("2e86ea"), "horizon": Color("e8f4ff"), "shaft": Color(1.0, 0.95, 0.8, 0.18)},
	# Tempelruinen: warm stone and torchlight.
	{"sun": Color("ffc27a"), "energy": 1.75, "ambient": Color("f0dcb4"), "fog": Color("e6cfa0"), "top": Color("4a7fd0"), "horizon": Color("ffcf90"), "shaft": Color(1.0, 0.78, 0.45, 0.26)},
	# Wasserfallhöhle: blue-turquoise and glowing crystals.
	{"sun": Color("bfe8ff"), "energy": 1.4, "ambient": Color("b8e4e6"), "fog": Color("8fcfd6"), "top": Color("2f76c8"), "horizon": Color("bfeef0"), "shaft": Color(0.6, 0.95, 1.0, 0.2)},
	# Lorenfahrt: late adventurous sun.
	{"sun": Color("ffb877"), "energy": 1.85, "ambient": Color("ecd9bc"), "fog": Color("e8c9a0"), "top": Color("3b6fc8"), "horizon": Color("ffc488"), "shaft": Color(1.0, 0.75, 0.42, 0.26)},
]

## The order in which the scenery is built (see step()).
const STEPS: Array[String] = [
	"_check_shaders", "_make_materials", "_make_kinds", "_index_path", "_environment", "_decks", "_terrain", "_cave",
	"_bonus_hall", "_vegetation", "_structures", "_decor", "_fauna", "_background", "_flush", "_ambient_particles",
	"_first_mood",
]
const SIMPLE_STEPS: Array[String] = ["_plain_materials", "_environment", "_decks", "_first_mood"]
## Tests: name of a step that fails on purpose ("any" = the first one).
static var force_failure: String = ""

var path
var level
var low: bool = false
## Plain look (fallback): standard materials, no plants or props.
var simple: bool = false
var step_index: int = 0
var failed_step: String = ""
## Milliseconds each build step took (container measurements in the tests).
var step_ms: Dictionary = {}
## 0 = low, 1 = medium, 2 = high (from the saved quality profile).
var tier: int = 1
var placed: int = 0
var _rng := RandomNumberGenerator.new()
var _kinds: Dictionary = {}
var _buckets: Dictionary = {}
var _far_buckets: Dictionary = {}
const FAR_CHUNK: float = 128.0
var _materials: Dictionary = {}
var _deck_materials: Dictionary = {}
var _pollen: CPUParticles3D
var _sun: DirectionalLight3D
var _environment_res: Environment
var _sky_material: ProceduralSkyMaterial
var _mood_index: float = -1.0
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
	"tree0", "tree1", "tree2", "tree0_far", "tree1_far", "tree2_far", "giant", "palm0", "palm1", "rock0", "rock1", "pillar0", "pillar1", "bush", "leaf0", "leaf1",
	"fern0", "fern1", "grass0", "flower0", "statue", "block", "post", "torch", "flame", "bulb", "crystal0", "crystal1",
	"canopy", "liana0", "liana1", "liana2", "wall", "lantern", "crate", "barrelprop", "cover",
]
const TREE_KINDS: Array[String] = ["tree0", "tree1", "tree2", "tree0_far", "tree1_far", "tree2_far", "giant", "palm0", "palm1"]


func build(world, layout, lightweight: bool, plain: bool = false) -> void:
	begin(world, layout, lightweight, plain)
	while not finished():
		step()


## Starts a build that step() then carries out piece by piece (one piece per
## call, so the game can spread the work over several frames).
func begin(world, layout, lightweight: bool, plain: bool = false) -> void:
	path = world
	level = layout
	low = lightweight
	simple = plain
	tier = 0 if low else (2 if _profile() == "high" else 1)
	_rng.seed = 20261118
	step_index = 0
	failed_step = ""


func steps() -> Array[String]:
	return SIMPLE_STEPS if simple else STEPS


func finished() -> bool:
	return step_index >= steps().size() or not failed_step.is_empty()


## Builds the next piece. False when it failed: then the build is over and
## failed_step names the piece (the caller falls back to the plain look).
## Every piece returns true as its last line, so a piece that stopped half-way
## on an error (an aborted call returns null) is noticed here.
func step() -> bool:
	if finished():
		return failed_step.is_empty()
	var name: String = steps()[step_index]
	var done: bool = false
	var started: int = Time.get_ticks_msec()
	if force_failure.is_empty() or simple or (force_failure != name and force_failure != "any"):
		done = call(name) == true
	step_ms[name] = Time.get_ticks_msec() - started
	if not done:
		failed_step = name
		return false
	step_index += 1
	return true


## The jungle shaders must have compiled (on a picky graphics driver a shader
## that does not compile draws nothing or garbage): each one reports its uniforms.
func _check_shaders() -> bool:
	var broken: Array[String] = []
	var sources: Dictionary = {
		"FOLIAGE": SHADERS.FOLIAGE, "SOLID": SHADERS.SOLID, "GROUND": SHADERS.GROUND, "GLOW": SHADERS.GLOW,
		"WATER": SHADERS.WATER, "LEAF": "", "SURFACE": "",
	}
	for key in sources:
		var shader: Shader = ART.shader(key.to_lower()) if str(sources[key]).is_empty() else null
		if shader == null:
			shader = Shader.new()
			shader.code = sources[key]
		if shader.get_shader_uniform_list().is_empty():
			broken.append(key)
	if not broken.is_empty():
		push_warning("[JungleArt] shaders did not compile: " + ", ".join(broken))
		return false
	return true


func _first_mood() -> bool:
	_apply_mood(0.0)
	return true


## The plain look: path decks in vertex colours with standard materials and the
## sky - used when the full jungle could not be built on this device.
func _plain_materials() -> bool:
	for pattern in range(4):
		var made := StandardMaterial3D.new()
		made.vertex_color_use_as_albedo = true
		made.vertex_color_is_srgb = true
		made.roughness = 0.9
		_deck_materials[pattern] = made
	return true


func _profile() -> String:
	var store: Node = get_node_or_null("/root/SettingsStore")
	return str(store.call("get_profile")) if store != null and store.has_method("get_profile") else "medium"


func follow(camera_position: Vector3, player_s: float, _delta: float, focus: Vector3 = Vector3.INF) -> void:
	if focus.is_finite():
		ART.set_focus(focus + Vector3.UP * 0.9)
	if is_instance_valid(_pollen):
		_pollen.global_position = camera_position + Vector3(0, 1.0, 0)
	_apply_mood(player_s)


## Blends sun, sky, fog and ambient light between the moods of the sections.
func _apply_mood(at: float) -> void:
	if level == null or level.sections.is_empty() or _sun == null:
		return
	var position: float = 0.0
	for section in level.sections:
		if at >= float(section.s0):
			var span: float = maxf(1.0, float(section.s1) - float(section.s0))
			var into: float = at - float(section.s0)
			var blend: float = smoothstep(span - 20.0, span + 10.0, into) if into > span - 20.0 else 0.0
			position = float(section.index) + blend
	position = clampf(position, 0.0, float(MOODS.size() - 1))
	if absf(position - _mood_index) < 0.002:
		return
	_mood_index = position
	var a: Dictionary = MOODS[floori(position)]
	var b: Dictionary = MOODS[mini(floori(position) + 1, MOODS.size() - 1)]
	var t: float = position - float(floori(position))
	_sun.light_color = Color(a.sun).lerp(b.sun, t)
	_sun.light_energy = lerpf(float(a.energy), float(b.energy), t)
	_environment_res.ambient_light_color = Color(a.ambient).lerp(b.ambient, t)
	_environment_res.fog_light_color = Color(a.fog).lerp(b.fog, t)
	_sky_material.sky_top_color = Color(a.top).lerp(b.top, t)
	_sky_material.sky_horizon_color = Color(a.horizon).lerp(b.horizon, t)
	if _materials.has("shaft"):
		_materials["shaft"].set_shader_parameter("colour", Color(a.shaft).lerp(b.shaft, t))


# ------------------------------------------------------------------ materials and kinds

func _make_materials() -> bool:
	_materials["foliage"] = SHADERS.material(SHADERS.FOLIAGE, {"brightness": 1.25})
	_materials["trunk"] = SHADERS.material(SHADERS.FOLIAGE, {"sway": 0.6, "brightness": 1.15})
	_materials["solid"] = SHADERS.material(SHADERS.SOLID)
	_materials["glow"] = SHADERS.material(SHADERS.GLOW, {"pulse": 0.35, "strength": 1.6})
	_materials["flame"] = SHADERS.material(SHADERS.FLAME)
	_materials["fauna"] = SHADERS.material(SHADERS.FAUNA)
	_materials["shaft"] = SHADERS.material(SHADERS.SHAFT)
	_materials["mist"] = SHADERS.material(SHADERS.MIST)
	_materials["water"] = SHADERS.material(SHADERS.WATER, {"flow": 0.35, "stretch": 0.4, "lit": 1.0})
	_materials["fall"] = SHADERS.material(SHADERS.WATER, {"flow": 1.2, "stretch": 1.6, "lit": 0.0})
	var maps: Dictionary = {
		"ground_tex": ART.texture("ground_albedo.jpg"), "ground_nrm": ART.texture("ground_normal.jpg"),
		"moss_tex": ART.texture("moss_albedo.jpg"), "moss_nrm": ART.texture("moss_normal.jpg"),
		"flecks": 0.32 if tier == 0 else 0.16,
	}
	var details: Dictionary = {0: "ground", 1: "wood", 2: "sandstone", 3: "stone"}
	for kind in DECK:
		var entry: Array = DECK[kind]
		var pattern: int = int(entry[0])
		if not _deck_materials.has(pattern):
			var params: Dictionary = maps.duplicate()
			params["pattern"] = pattern
			params["detail_tex"] = ART.texture(str(details[pattern]) + "_albedo.jpg")
			params["detail_nrm"] = ART.texture(str(details[pattern]) + "_normal.jpg")
			_deck_materials[pattern] = SHADERS.material(SHADERS.GROUND, params)
	var terrain: Dictionary = maps.duplicate()
	terrain["pattern"] = 0
	terrain["detail_tex"] = maps.ground_tex
	terrain["detail_nrm"] = maps.ground_nrm
	_materials["terrain"] = SHADERS.material(SHADERS.GROUND, terrain)
	var cave: Dictionary = maps.duplicate()
	cave["pattern"] = 3
	cave["detail_tex"] = ART.texture("stone_albedo.jpg")
	cave["detail_nrm"] = ART.texture("stone_normal.jpg")
	_materials["cave_ground"] = SHADERS.material(SHADERS.GROUND, cave)
	return true


func _kind(name: String, mesh: Mesh, material: String, range_end: float = 140.0, shadow: bool = false) -> void:
	_kinds[name] = {"mesh": mesh, "material": material, "range": range_end, "shadow": shadow, "source": "code", "chunk": CHUNK}


## A kind drawn with a Blender model; `lod_model` takes over beyond the tier's
## detail distance. Falls back to `fallback` (code mesh) only if the GLB is missing.
func _art(name: String, model: String, range_end: float, shadow: bool, fallback: Mesh, fallback_material: String,
		options: Dictionary = {}, lod_model: String = "", chunk: float = CHUNK, neutral: bool = false) -> void:
	var near: Dictionary = options.duplicate()
	var far: Dictionary = options.duplicate()
	if not lod_model.is_empty() and tier > 0:
		near["lod_window"] = Vector2(-1.0, TREE_DETAIL[tier])
		far["lod_window"] = Vector2(TREE_DETAIL[tier], 1000000.0)
	var mesh: Mesh = ART.mesh(model, near)
	if mesh == null:
		_kind(name, fallback, fallback_material, range_end, shadow)
		return
	var lod: Mesh = ART.mesh(lod_model, far) if not lod_model.is_empty() else null
	_kinds[name] = {
		"mesh": mesh, "material": "", "range": range_end, "shadow": shadow, "source": "glb:" + model, "lod": lod,
		"chunk": chunk, "neutral": neutral, "proxy": ART.mesh(lod_model, options) if not lod_model.is_empty() else null,
	}


func _make_kinds() -> bool:
	var plants: float = PLANT_RANGE[tier]
	var shadows: bool = tier > 0
	var trees: Array[String] = ["tree_broad", "tree_slender", "tree_fig"]
	for index in range(3):
		_art("tree%d" % index, trees[index], 190.0 if tier > 0 else 150.0, shadows, MESHES.tree(100 + index, 18.0, 4 + index % 3, Color("6b4a31"), LEAF_GREENS[index]), "trunk", {}, trees[index] + "_lod", 28.0)
	# Trees away from the path only ever show their light version (no detailed batch).
	for index in range(3):
		_art("tree%d_far" % index, trees[index] + "_lod", 190.0 if tier > 0 else 150.0, tier == 2, MESHES.tree(100 + index, 18.0, 4, Color("6b4a31"), LEAF_GREENS[index]), "trunk", {}, "", 128.0)
	_art("giant", "tree_kapok", 260.0, shadows, MESHES.tree(77, 30.0, 6, Color("5e4330"), Color("2c8a47")), "trunk", {}, "tree_kapok_lod", 48.0)
	_art("palm0", "palm_a", 220.0, shadows, MESHES.palm(500, 11.0), "trunk", {}, "palm_a_lod", 48.0)
	_art("palm1", "palm_b", 220.0, shadows, MESHES.palm(501, 14.0), "trunk", {}, "palm_b_lod", 48.0)
	for index in range(2):
		_art("fern%d" % index, ["fern_a", "fern_b"][index], plants, tier == 2, MESHES.fern(200 + index, 7, 1.4, LEAF_GREENS[index]), "foliage", {}, "", 64.0)
		_art("leaf%d" % index, ["bigleaf_a", "bigleaf_b"][index], plants + 20.0, tier == 2, MESHES.broadleaf(300 + index, 5, 1.3, LEAF_GREENS[index]), "foliage", {}, "", 64.0)
	_art("cover", "groundcover", plants, false, MESHES.grass(402, 8, 0.4, Color("4f9a3c")), "foliage", {}, "", 64.0)
	_art("grass0", "grass", plants * 0.8, false, MESHES.grass(400, 10, 0.7, Color("6fb43f")), "foliage", {}, "", 64.0)
	_art("rock0", "rock_a", 160.0, tier == 2, MESHES.rock(600, Vector3(1.4, 0.9, 1.2)), "solid")
	_art("rock1", "rock_b", 160.0, tier == 2, MESHES.rock(601, Vector3(1.4, 0.9, 1.2)), "solid")
	_art("pillar0", "pillar_broken", 200.0, shadows, MESHES.pillar(700, 4.5, true), "solid")
	_art("pillar1", "pillar", 200.0, shadows, MESHES.pillar(701, 6.5, false), "solid")
	_art("crystal0", "crystal_a", 120.0, false, MESHES.crystal(800, Color("62e6ff")), "glow")
	_art("crystal1", "crystal_b", 120.0, false, MESHES.crystal(801, Color("b48cff")), "glow")
	_art("flower0", "flower", plants * 0.8, false, MESHES.flower(900, Color("ffffff")), "foliage", {}, "", 64.0)
	var bulb := MESHES.Kit.new()
	MESHES.blob(bulb, Vector3.ZERO, Vector3.ONE * 0.2, Color("ffe08a"), RandomNumberGenerator.new(), 0.0, 3, 6)
	_kind("bulb", bulb.mesh(), "glow", 140.0)
	for index in range(3):
		_art("liana%d" % index, ["liana_a", "liana_b", "liana_c"][index], 120.0, false, MESHES.liana(1000 + index, 5.0 + 2.0 * float(index)), "foliage")
	_art("canopy", "canopy", 130.0, shadows, MESHES.liana(1100, 1.0), "foliage")
	_art("bush", "bush", 120.0, tier == 2, MESHES.grass(1101, 6, 0.6, Color("2f8f3e")), "foliage", {}, "", 64.0)
	_art("statue", "statue", 220.0, shadows, MESHES.statue(1200), "solid")
	_art("arch", "arch", 260.0, shadows, MESHES.arch(5.6, 4.8), "solid")
	_art("wall", "wall", 200.0, shadows, MESHES.box(Vector3(2.0, 1.2, 0.4), Color("bfa77f")), "solid")
	_art("stairs", "stairs", 200.0, shadows, MESHES.box(Vector3(1.5, 0.75, 1.0), Color("bfa77f")), "solid")
	_art("torch", "torch", 120.0, false, MESHES.torch(), "solid")
	_art("lantern", "lantern", 120.0, false, MESHES.torch(), "solid")
	_art("crate", "crate", 120.0, shadows, MESHES.box(Vector3(0.5, 0.5, 0.5), Color("a77b4a")), "solid")
	_art("barrelprop", "barrel", 120.0, shadows, MESHES.barrel(), "solid")
	_kind("flame", MESHES.flame(), "flame", 160.0)
	_art("block", "block", 160.0, false, MESHES.box(Vector3(0.5, 0.5, 0.5), Color("bfa77f")), "solid", {"world": true, "world_scale": 0.45}, "", CHUNK, true)
	_art("templeblock", "block", 0.0, false, MESHES.box(Vector3(0.5, 0.5, 0.5), Color("c2a878")), "solid", {"world": true, "world_scale": 0.12}, "", CHUNK, true)
	_art("plankbox", "plank", 130.0, false, MESHES.box(Vector3(0.5, 0.5, 0.5), Color("a77b4a")), "solid", {"world": true, "world_scale": 0.9}, "", CHUNK, true)
	_art("rope", "rope", 90.0, false, MESHES.box(Vector3(0.5, 0.5, 0.5), Color("d9c08a")), "solid", {}, "", CHUNK, true)
	_art("iron", "rail", 120.0, false, MESHES.box(Vector3(0.5, 0.5, 0.5), Color("8d96a3")), "solid", {"world": true, "world_scale": 1.0}, "", CHUNK, true)
	var post := CylinderMesh.new()
	post.top_radius = 0.5
	post.bottom_radius = 0.5
	post.height = 1.0
	_art("post", "post", 150.0, false, post, "solid", {"world": true, "world_scale": 0.8}, "", CHUNK, true)
	_kind("butterfly", MESHES.butterfly(), "fauna", 70.0)
	_kind("bird", MESHES.bird(), "fauna", 260.0)
	_kind("leafcard", MESHES.leaf_card(), "fauna", 60.0)
	var crown_rng := RandomNumberGenerator.new()
	crown_rng.seed = 1100
	var dot := MESHES.Kit.new()
	MESHES.blob(dot, Vector3.ZERO, Vector3.ONE * 0.06, Color(1, 1, 1), crown_rng, 0.0, 2, 4)
	_kind("firefly", dot.mesh(), "fauna", 70.0)
	_kind("spark", dot.mesh(), "fauna", 60.0)
	var gold := MESHES.Kit.new()
	for coin in range(9):
		MESHES.blob(gold, Vector3(crown_rng.randf_range(-0.8, 0.8), 0.1 + crown_rng.randf() * 0.5, crown_rng.randf_range(-0.8, 0.8)), Vector3(0.5, 0.25, 0.5), Color("ffd24a"), crown_rng, 0.1, 3, 7)
	_art("treasure", "treasure", 120.0, false, gold.mesh(), "glow")
	var mountain := MESHES.Kit.new()
	MESHES.blob(mountain, Vector3.ZERO, Vector3(1.0, 1.0, 1.0), Color("3f6f5a"), crown_rng, 0.18, 6, 12, 0.0, true)
	_kind("mountain", mountain.mesh(), "solid", 0.0)
	_art("cliff", "cliff", 220.0, shadows, mountain.mesh(), "solid", {"moss": 0.45})
	return true


## What the scenery is built from: every kind and whether it comes from a Blender model.
func art_report() -> Dictionary:
	var from_glb: Array[String] = []
	var from_code: Array[String] = []
	for name in _kinds:
		if str(_kinds[name].source).begins_with("glb:"):
			from_glb.append(name)
		else:
			from_code.append(name)
	return {"glb": from_glb, "code": from_code, "missing": ART.missing.duplicate()}


## Queues one instance. `at_s` decides the batch, so instances near each other share it.
func _put(kind: String, at_s: float, transform: Transform3D, colour: Color = Color.WHITE, custom: Color = Color(0, 0, 0, 0)) -> void:
	if kind.begins_with("flower"):
		if custom.a <= 0.0:
			custom = BLOSSOMS[int(kind.substr(6)) % BLOSSOMS.size()]
			custom.a = 1.0
		colour = Color.WHITE
	if kind.begins_with("crystal1"):
		colour = Color("c9a8ff")
	kind = ALIAS.get(kind, kind)
	if not _kinds.has(kind):
		return
	if bool(_kinds[kind].get("neutral", false)):
		# Textured wood and stone keep their own colour; the old flat tints only shade a little.
		colour = Color.WHITE.lerp(colour, 0.18)
	if at_s >= 0.0 and _is_crowded(at_s) and SOLID_KINDS.has(kind):
		var margin: float = 1.6 if kind in TREE_KINDS else 0.5
		if _path_in_the_way(transform.origin, at_s, margin):
			return
	var chunk: float = float(_kinds[kind].chunk)
	var key: String = "%s|%d" % [kind, floori(at_s / chunk) if _kinds[kind].range > 0.0 else 0]
	if not _buckets.has(key):
		_buckets[key] = {"kind": kind, "xforms": [], "colours": [], "custom": [], "ats": []}
	_buckets[key].ats.append(at_s)
	_buckets[key].xforms.append(transform)
	_buckets[key].colours.append(colour)
	_buckets[key].custom.append(custom)
	placed += 1


func _flush() -> bool:
	for key in _buckets:
		var bucket: Dictionary = _buckets[key]
		var kind: Dictionary = _kinds[bucket.kind]
		var lod: Mesh = kind.get("lod")
		var range_end: float = float(kind.range) * (0.75 if low else 1.0)
		if lod == null:
			_batch(str(key), bucket, kind.mesh, kind, 0.0, range_end, bool(kind.shadow))
		elif tier == 0:
			_batch(str(key), bucket, lod, kind, 0.0, range_end, false)
		else:
			var detail: float = TREE_DETAIL[tier]
			_far_parts(str(bucket.kind), bucket)
			# HIGH: the detailed crowns cast the shadows. MEDIUM: a light stand-in casts them.
			var reach: float = detail + float(kind.chunk) * 0.6
			_batch(str(key), bucket, kind.mesh, kind, 0.0, reach, bool(kind.shadow) and tier == 2)
			if bool(kind.shadow) and tier == 1:
				var proxy: MultiMeshInstance3D = _batch(str(key) + "_shadow", bucket, kind.proxy, kind, 0.0, SHADOW_RANGE[1] + float(kind.chunk) * 0.6, true)
				proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	# The light far versions of near trees go in long batches: few draw calls.
	for key in _far_buckets:
		var bucket: Dictionary = _far_buckets[key]
		var kind: Dictionary = _kinds[bucket.kind]
		_batch(str(key) + "_far", bucket, kind.lod, kind, 0.0, float(kind.range), bool(kind.shadow) and tier == 2)
	_buckets.clear()
	_far_buckets.clear()
	return true


func _far_parts(kind: String, bucket: Dictionary) -> void:
	var key: String = "%s|%d" % [kind, floori(float(bucket.ats[0]) / FAR_CHUNK)]
	if not _far_buckets.has(key):
		_far_buckets[key] = {"kind": kind, "xforms": [], "colours": [], "custom": [], "ats": []}
	for field in ["xforms", "colours", "custom", "ats"]:
		_far_buckets[key][field].append_array(bucket[field])


func _batch(key: String, bucket: Dictionary, mesh: Mesh, kind: Dictionary, range_begin: float, range_end: float, shadow: bool) -> MultiMeshInstance3D:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = bucket.xforms.size()
	for index in range(instances.instance_count):
		instances.set_instance_transform(index, bucket.xforms[index])
		instances.set_instance_color(index, bucket.colours[index])
		instances.set_instance_custom_data(index, bucket.custom[index])
	var node := MultiMeshInstance3D.new()
	node.name = "Jungle_" + key.replace("|", "_")
	node.multimesh = instances
	if not str(kind.material).is_empty():
		node.material_override = _materials[kind.material]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if range_end > 0.0:
		node.visibility_range_begin = range_begin
		node.visibility_range_end = range_end
		node.visibility_range_begin_margin = 4.0 if range_begin > 0.0 else 0.0
		node.visibility_range_end_margin = 10.0 if range_begin <= 0.0 or range_end > 100.0 else 4.0
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	if str(kind.source).begins_with("glb:"):
		node.set_meta("jungle_glb", ART.path_of(str(kind.source).substr(4)))
	add_child(node)
	return node


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


func _index_path() -> bool:
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
	return true


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

func _environment() -> bool:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("2f7fd8")
	sky_material.sky_horizon_color = Color("ffe2b0")
	sky_material.sky_curve = 0.12
	sky_material.ground_bottom_color = Color("1d3b2c")
	sky_material.ground_horizon_color = Color("9fc7a0")
	sky_material.sun_angle_max = 18.0
	_sky_material = sky_material
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	_environment_res = environment
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# A fixed bright fill instead of sky light: under the closed canopy the sky
	# contributes almost nothing and trunks and leaves in shadow turned black.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d4ecc4")
	environment.ambient_light_energy = 1.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.25
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
	# Shadows of the sun through the canopy: none on LOW, near on MEDIUM, far and split on HIGH.
	sun.shadow_enabled = tier > 0
	sun.directional_shadow_max_distance = SHADOW_RANGE[tier] if tier > 0 else 40.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if tier == 2 else DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_fade_start = 0.75
	sun.shadow_blur = 1.2
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.4
	add_child(sun)
	_sun = sun
	return true


# ------------------------------------------------------------------ path decks

## The walkable surfaces as ribbons (one mesh per surface stretch, cut at 60 m).
func _decks() -> bool:
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
	return true


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
	var top: ArrayMesh = st.commit()
	var skirt := ArrayMesh.new()
	_skirts(skirt, from, to, half, raised, edge.darkened(0.35))
	# One surface for deck and side skirts: one draw call per deck piece.
	var merged := SurfaceTool.new()
	merged.create_from(top, 0)
	merged.deindex()
	merged.append_from(skirt, 0, Transform3D.IDENTITY)
	var mesh: ArrayMesh = merged.commit()
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


func _terrain() -> bool:
	var step: float = 3.0 if low else 2.0
	var samples: PackedFloat32Array = _main_samples(step)
	var stretch: int = int(120.0 / step)
	var start: int = 0
	while start < samples.size() - 1:
		var stop: int = mini(samples.size() - 1, start + stretch)
		for side in [-1.0, 1.0]:
			_terrain_strip(samples, start, stop, side)
		start = stop
	return true


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

func _cave() -> bool:
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
		# The crystals light the cave walls blue-turquoise (MEDIUM and HIGH).
		if tier > 0:
			var glow_at: float = roof.x + 6.0
			while glow_at < roof.y - 3.0:
				var light := OmniLight3D.new()
				light.light_color = Color("5fe6ff") if int(glow_at) % 2 == 0 else Color("9f8cff")
				light.light_energy = 1.3
				light.omni_range = 8.0
				light.distance_fade_enabled = true
				light.distance_fade_begin = 45.0
				light.distance_fade_length = 15.0
				var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
				light.position = _point(glow_at, side * (path.half_width_at(glow_at) + 0.5), 1.6)
				add_child(light)
				glow_at += 22.0 if tier == 1 else 14.0
	return true


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
		_materials["cave"] = ART.surface_material("stone", {"double": true, "world_scale": 0.3, "moss": 0.22, "tint": Color(0.72, 0.86, 0.95), "floor": 0.1})
	node.material_override = _materials["cave"]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if not low else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 200.0
	add_child(node)


# ------------------------------------------------------------------ the bonus hall

func _bonus_hall() -> bool:
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
	return true


# ------------------------------------------------------------------ the jungle

func _vegetation() -> bool:
	var density: float = DENSITY[tier]
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
			# Low leafy cover hides the bare forest floor between the plants.
			if not raised and _rng.randf() < 0.9 * density:
				var spot: float = _rng.randf_range(1.2, 10.0)
				_put("cover", at, _xf(at, side * (half + spot), _terrain_lift(at, spot) - 0.05, Vector3.ONE * _rng.randf_range(1.0, 2.0), _rng.randf() * TAU))
			# HIGH: a second band of big plants further out.
			if tier == 2 and not raised and _rng.randf() < 0.5:
				var spot: float = _rng.randf_range(7.0, 15.0)
				var big: String = ("leaf%d" % (_rng.randi() % 2)) if _rng.randf() < 0.5 else "fern1"
				_put(big, at, _xf(at, side * (half + spot), _terrain_lift(at, spot), Vector3.ONE * _rng.randf_range(1.6, 2.6), _rng.randf() * TAU))
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
	return true


## A little colour variation per tree: fresher, darker, more olive.
func _tree_tint() -> Color:
	var v: float = _rng.randf_range(0.86, 1.06)
	return Color(v * _rng.randf_range(0.92, 1.04), v, v * _rng.randf_range(0.86, 1.0))


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
				_put("tree%d" % (_rng.randi() % trees), at, _xf(at, side * (half + offset), floor_h - 0.3, Vector3.ONE * scale * (1.4 if ground < -1.5 else 1.0), _rng.randf() * TAU), _tree_tint())
			# A wall of forest on the slopes: far trees only ever show their light version.
			if tier > 0 and kind != "cave" and _rng.randf() < 0.55 * DENSITY[tier]:
				var wall: float = _rng.randf_range(24.0, 44.0)
				_put("tree%d_far" % (_rng.randi() % trees), at, _xf(at, side * (half + wall), _terrain_height(at, wall) - 0.6, Vector3.ONE * _rng.randf_range(1.1, 1.8), _rng.randf() * TAU), _tree_tint())
			if _rng.randf() < 0.6:
				var far: float = _rng.randf_range(13.0, 34.0)
				_put("tree%d_far" % (_rng.randi() % trees), at, _xf(at, side * (half + far), _terrain_height(at, far) - 0.5, Vector3.ONE * _rng.randf_range(1.0, 1.7), _rng.randf() * TAU), _tree_tint())
		at += _rng.randf_range(3.6, 5.6) * [1.5, 1.0, 0.82][tier]
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
		at += _rng.randf_range(4.0, 6.5) * [1.5, 1.0, 0.8][tier]


# ------------------------------------------------------------------ built things along the path

func _structures() -> bool:
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
						# Ruined walls and stairs of the old temple beside the way.
						if _rng.randf() < 0.1 * DENSITY[tier]:
							_put("wall", at, _xf(at, side * (half + _rng.randf_range(3.0, 5.5)), -0.1, Vector3.ONE * _rng.randf_range(0.8, 1.1), PI * 0.5 + _rng.randf_range(-0.15, 0.15)))
						elif tier > 0 and _rng.randf() < 0.04:
							_put("stairs", at, _xf(at, side * (half + _rng.randf_range(5.5, 8.0)), -0.05, Vector3.ONE, -PI * 0.5 * side))
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
				at = from + 5.0
				while at < to:
					# Crates and barrels of the old mine beside the rails.
					if _rng.randf() < 0.35:
						var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
						var spot: float = half + _rng.randf_range(1.2, 2.6)
						if _rng.randf() < 0.6:
							_put("crate", at, _xf(at, side * spot, 0.0, Vector3.ONE * _rng.randf_range(0.8, 1.1), _rng.randf() * TAU))
						else:
							_put("barrelprop", at, _xf(at, side * spot, 0.6, Vector3.ONE * 0.8, _rng.randf() * TAU))
					at += _rng.randf_range(6.0, 11.0)
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
	return true


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

func _decor() -> bool:
	# A small lantern marks every rescue point.
	for point in level.respawns:
		var at: float = float(point.s)
		if at < 0.0:
			continue
		var side: float = path.half_width_at(at) + 0.5
		var lat: float = side if float(point.lat) <= 0.0 else -side
		_put("lantern", at, _xf(at, lat, 0.0, Vector3.ONE * 1.15, PI if lat > 0.0 else 0.0))
	for item in level.decor:
		var at: float = float(item.s)
		var lat: float = float(item.lat)
		match str(item.kind):
			"torch":
				_put("torch", at, _xf(at, lat, 0.0, Vector3.ONE))
				_put("flame", at, _xf(at, lat, 2.05, Vector3.ONE))
				_embers(at, lat, 2.1)
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
						_embers(at, side * (width * 0.5 + 0.8), 2.1)
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
	return true


## Sparks rising from a torch flame (animated on the GPU by the fauna shader).
func _embers(at: float, lat: float, h: float) -> void:
	if tier == 0:
		return
	for k in range(4 * tier):
		_put("spark", at, _xf(at, lat, h, Vector3.ONE * 0.5), Color(1.0, 0.55, 0.15), Color(_rng.randf(), 0.0, _rng.randf_range(0.12, 0.2), 1.0))


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

func _fauna() -> bool:
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
	return true


func _ambient_particles() -> bool:
	if low:
		return true
	_pollen = CPUParticles3D.new()
	_pollen.name = "Pollen"
	_pollen.amount = 24 if tier == 1 else 56
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
	return true


# ------------------------------------------------------------------ the far distance

func _background() -> bool:
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
	return true
