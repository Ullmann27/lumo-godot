extends RefCounted
## The Blender-built models of the Dschungelherz jungle (assets/games/run/jungle/
## models/*.glb, made by tools/lumo_run_art/build_jungle_art.py) prepared for
## the game: each surface gets one of the jungle shaders (leaf cards with wind
## and light shining through, textured bark/stone/wood with moss, glowing
## crystals), fed with the textures the GLB references. Meshes and materials
## are cached, so every tree of a kind shares one mesh and one material set.

const SHADERS = preload("res://scripts/games/run/jungle/run_jungle_shaders.gd")
const DIR: String = "res://assets/games/run/jungle/models/"
const TEXTURES: String = DIR + "textures/"
## How each material of the GLBs is shown: shader and its settings.
const LOOK: Dictionary = {
	"bark": {"shader": "surface", "moss": 0.3, "sway": 1.0, "normal": 1.2},
	"wood": {"shader": "surface", "moss": 0.1},
	"stone": {"shader": "surface", "moss": 0.55, "normal": 1.1},
	"sandstone": {"shader": "surface", "moss": 0.38, "shade": 0.8},
	"moss": {"shader": "surface"},
	"iron": {"shader": "surface", "metal": 0.55, "rough": 0.5},
	"rope": {"shader": "surface"},
	"coconut_husk": {"shader": "surface", "normal": 1.4},
	"grass": {"shader": "plant", "sway": 1.0},
	"stem": {"shader": "plant", "sway": 1.0},
	"leaves": {"shader": "leaf"},
	"petal": {"shader": "petal"},
	"glow_crystal": {"shader": "crystal", "strength": 2.4},
	"glow_lantern": {"shader": "crystal", "pulse": 0.1, "strength": 2.2},
	"paint_ember": {"shader": "surface", "emit": 3.0},
}

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _textures: Dictionary = {}
static var _shaders: Dictionary = {}
## Names of models that could not be loaded (the caller falls back to code meshes).
static var missing: Array[String] = []
static var loaded: Array[String] = []
static var _globals_ready: bool = false


static func path_of(name: String) -> String:
	return DIR + name + ".glb"


## The prepared mesh of a model, or null when its GLB is missing.
## options: world (bool, world-space mapping), world_scale, moss, cap (Color),
## tint (Color multiplies textured wood/stone), leaf (Dictionary of leaf params).
static func mesh(name: String, options: Dictionary = {}) -> Mesh:
	var key: String = name + "|" + str(options)
	if _meshes.has(key):
		return _meshes[key]
	var source: Mesh = _source(name)
	if source == null:
		_meshes[key] = null
		return null
	var result: Mesh = source.duplicate()
	for surface in range(result.get_surface_count()):
		var original: Material = source.surface_get_material(surface)
		result.surface_set_material(surface, material_for(original, options))
	result.resource_name = name
	result.set_meta("jungle_glb", path_of(name))
	_meshes[key] = result
	return result


static func _source(name: String) -> Mesh:
	var cache_key: String = "@" + name
	if _meshes.has(cache_key):
		return _meshes[cache_key]
	var path: String = path_of(name)
	var found: Mesh = null
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		if scene != null:
			var root: Node = scene.instantiate()
			var holder: MeshInstance3D = _first_mesh(root)
			if holder != null:
				found = holder.mesh
			root.free()
	if found == null:
		if not missing.has(name):
			missing.append(name)
		push_warning("[JungleArt] model missing: " + path)
	elif not loaded.has(name):
		loaded.append(name)
	_meshes[cache_key] = found
	return found


static func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found: MeshInstance3D = _first_mesh(child)
		if found != null:
			return found
	return null


static func texture(file: String) -> Texture2D:
	if not _textures.has(file):
		var path: String = TEXTURES + file
		_textures[file] = load(path) if ResourceLoader.exists(path) else null
	return _textures[file]


## The world-space point the leaves keep clear of (Lumo); a global shader value.
static func set_focus(point: Vector3) -> void:
	_ensure_globals()
	RenderingServer.global_shader_parameter_set("jungle_focus", point)


## Adds the global shader value once per process. (Asking the server for its list
## is editor-only and logs an error at runtime, so a flag remembers it instead.)
static func _ensure_globals() -> void:
	if _globals_ready:
		return
	_globals_ready = true
	if not ProjectSettings.has_setting("shader_globals/jungle_focus"):
		RenderingServer.global_shader_parameter_add("jungle_focus", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0, -1000, 0))


static func shader(kind: String) -> Shader:
	_ensure_globals()
	if not _shaders.has(kind):
		var code: String
		match kind:
			"leaf":
				code = SHADERS.LEAF
			"surface":
				code = SHADERS.SURFACE
			"plant":
				code = SHADERS.SURFACE.replace("render_mode specular_schlick_ggx;", "render_mode cull_disabled, specular_schlick_ggx;")
			"crystal":
				code = SHADERS.CRYSTAL
			"petal":
				code = SHADERS.PETAL
		var made := Shader.new()
		made.code = code
		_shaders[kind] = made
	return _shaders[kind]


## One shared ShaderMaterial per (GLB material, options).
static func material_for(original: Material, options: Dictionary = {}) -> Material:
	var name: String = original.resource_name if original != null else "paint"
	var look: Dictionary = LOOK.get(name, {"shader": "surface"})
	var key: String = name + "|" + str(options)
	if _materials.has(key):
		return _materials[key]
	var made := ShaderMaterial.new()
	made.resource_name = name
	made.shader = shader(str(look.shader))
	if options.has("lod_window") and str(look.shader) in ["leaf", "surface", "plant"]:
		made.set_shader_parameter("lod_window", options.lod_window)
	var standard: BaseMaterial3D = original as BaseMaterial3D
	var albedo: Texture2D = standard.albedo_texture if standard != null else null
	var normal: Texture2D = standard.normal_texture if standard != null and standard.normal_enabled else null
	var colour: Color = standard.albedo_color if standard != null else Color.WHITE
	match str(look.shader):
		"leaf":
			made.set_shader_parameter("albedo_tex", albedo if albedo != null else texture("leaves_albedo.png"))
			made.set_shader_parameter("normal_tex", normal if normal != null else texture("leaves_normal.jpg"))
			var leaf: Dictionary = options.get("leaf", {})
			for param in leaf:
				made.set_shader_parameter(param, leaf[param])
		"crystal":
			made.set_shader_parameter("base_color", colour)
			var emit: Color = standard.emission if standard != null and standard.emission_enabled else colour
			made.set_shader_parameter("emission_color", emit)
			made.set_shader_parameter("pulse", float(look.get("pulse", 0.35)))
			made.set_shader_parameter("strength", float(look.get("strength", 1.5)))
		"petal":
			made.set_shader_parameter("sway", 1.0)
		_:
			if name == "paint_cap" and options.has("cap"):
				colour = options.cap
			if options.has("tint") and albedo != null:
				colour = colour * Color(options.tint)
			colour = colour * float(look.get("shade", 1.0))
			colour.a = 1.0
			made.set_shader_parameter("base_color", colour)
			made.set_shader_parameter("use_tex", albedo != null)
			if albedo != null:
				made.set_shader_parameter("albedo_tex", albedo)
				made.set_shader_parameter("normal_tex", normal if normal != null else albedo)
				made.set_shader_parameter("normal_depth", float(look.get("normal", 1.0)) if normal != null else 0.0)
			made.set_shader_parameter("roughness_value", float(look.get("rough", standard.roughness if standard != null else 0.8)))
			made.set_shader_parameter("metallic_value", float(look.get("metal", standard.metallic if standard != null else 0.0)))
			made.set_shader_parameter("moss_amount", float(options.get("moss", look.get("moss", 0.0))))
			made.set_shader_parameter("moss_tex", texture("moss_albedo.jpg"))
			made.set_shader_parameter("sway", float(look.get("sway", 0.0)))
			made.set_shader_parameter("world_mapping", bool(options.get("world", false)))
			made.set_shader_parameter("world_scale", float(options.get("world_scale", 0.5)))
			if look.has("emit"):
				made.set_shader_parameter("emission_color", standard.emission if standard != null else colour)
				made.set_shader_parameter("emission_energy", float(look.emit))
	_materials[key] = made
	return made


## A textured material for code-built geometry (platforms): world-mapped, ignores vertex colour.
static func surface_material(name: String, options: Dictionary = {}) -> Material:
	var key: String = "code|" + name + "|" + str(options)
	if _materials.has(key):
		return _materials[key]
	var albedo_file: String = {"bark": "bark_albedo.jpg", "wood": "wood_albedo.jpg", "stone": "stone_albedo.jpg",
		"sandstone": "sandstone_albedo.jpg", "moss": "moss_albedo.jpg", "ground": "ground_albedo.jpg"}.get(name, "stone_albedo.jpg")
	var made := ShaderMaterial.new()
	made.shader = shader("plant" if bool(options.get("double", false)) else "surface")
	made.set_shader_parameter("floor_light", float(options.get("floor", 0.05)))
	made.set_shader_parameter("use_tex", true)
	made.set_shader_parameter("albedo_tex", texture(albedo_file))
	made.set_shader_parameter("normal_tex", texture(albedo_file.replace("albedo", "normal")))
	made.set_shader_parameter("world_mapping", true)
	made.set_shader_parameter("world_scale", float(options.get("world_scale", 0.5)))
	made.set_shader_parameter("base_color", Color(options.get("tint", Color.WHITE)))
	made.set_shader_parameter("vertex_tint", float(options.get("vertex_tint", 0.0)))
	made.set_shader_parameter("moss_amount", float(options.get("moss", 0.3)))
	made.set_shader_parameter("moss_tex", texture("moss_albedo.jpg"))
	made.set_shader_parameter("roughness_value", 0.85)
	_materials[key] = made
	return made
