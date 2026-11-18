class_name AdventureKit
extends RefCounted

## Gemeinsamer Baukasten der Abenteuerwelten (Schatzinsel, Bühne, Atelier, Spielewelt).
## Lädt die Blender-Modelle aus assets/creative/adventure/models (nur Geometrie +
## Materialnamen) und ordnet jedem Materialnamen einmal abgelegte Texturen und
## Mobile-/gl_compatibility-taugliche Shader zu. Vieles wird als MultiMesh
## gezeichnet: ein Draw-Call je Modell-Oberfläche statt je Objekt.

const BASE := "res://assets/creative/adventure/"
const SETS := {
	"flora": BASE + "models/adventure_flora.glb",
	"ruins": BASE + "models/adventure_ruins.glb",
	"props": BASE + "models/adventure_props.glb",
	"fauna": BASE + "models/adventure_fauna.glb",
	"stage": BASE + "models/adventure_stage.glb",
	"atelier": BASE + "models/adventure_atelier.glb",
	"hub": BASE + "models/adventure_hub.glb",
}

static var _textures: Dictionary = {}
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _shaders: Dictionary = {}


static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var path := BASE + "textures/" + name
		_textures[name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[name]


static func shader(name: String) -> Shader:
	if not _shaders.has(name):
		_shaders[name] = load(BASE + "shaders/" + name + ".gdshader")
	return _shaders[name]


static func _standard(
	albedo: String, normal: String, color: Color = Color.WHITE, rough: float = 0.9, scale: float = 1.0
) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if not albedo.is_empty():
		m.albedo_texture = texture(albedo)
	if not normal.is_empty() and texture(normal) != null:
		m.normal_enabled = true
		m.normal_texture = texture(normal)
		m.normal_scale = 1.0
	m.roughness = rough
	m.uv1_scale = Vector3(scale, scale, scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _plain(color: Color, rough: float = 0.7, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := _plain(color, 0.4)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func _bark(albedo: String, normal: String, tint: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("bark")
	m.set_shader_parameter("albedo_tex", texture(albedo))
	m.set_shader_parameter("normal_tex", texture(normal))
	m.set_shader_parameter("tint", tint)
	return m


## Sichtschutz: Blätter, Stämme und Felsen zwischen Kamera und `focus` werden im
## Raster ausgeblendet. y < -500 schaltet ab (beim Verlassen einer Welt aufrufen).
static func set_focus(focus: Vector3) -> void:
	for key in _materials:
		var m = _materials[key]
		if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
			var name: String = (m as ShaderMaterial).shader.resource_path.get_file()
			if name in ["foliage.gdshader", "moss_stone.gdshader", "bark.gdshader"]:
				(m as ShaderMaterial).set_shader_parameter("focus_world", focus)


static func foliage(tex: String, tint: Color = Color.WHITE, sway: float = 6.0, wind: float = 0.12) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("foliage")
	m.set_shader_parameter("albedo_tex", texture(tex))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("sway_height", sway)
	m.set_shader_parameter("wind", wind)
	m.set_shader_parameter("near_fade", 3.6)
	return m


static func moss_stone(
	albedo: String, normal: String, moss: float, tint: Color = Color.WHITE, scale: float = 1.0
) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("moss_stone")
	m.set_shader_parameter("base_albedo", texture(albedo))
	m.set_shader_parameter("base_normal", texture(normal))
	m.set_shader_parameter("moss_albedo", texture("moss_albedo.jpg"))
	m.set_shader_parameter("moss_amount", moss)
	m.set_shader_parameter("base_tint", tint)
	m.set_shader_parameter("uv_scale", scale)
	return m


static func flap(tex: String, span: float, speed: float, amount: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("wing_flap")
	m.set_shader_parameter("albedo_tex", texture(tex))
	m.set_shader_parameter("span", span)
	m.set_shader_parameter("flap_speed", speed)
	m.set_shader_parameter("flap_amount", amount)
	return m


## Material je Name aus den Blender-Modellen (einmal je Lauf erzeugt).
static func material(name: String) -> Material:
	if _materials.has(name):
		return _materials[name]
	var m: Material
	match name:
		"bark":
			m = _bark("bark_albedo.jpg", "bark_normal.jpg", Color("e8ddd0"))
		"palm_bark":
			m = _bark("palm_bark_albedo.jpg", "palm_bark_normal.jpg", Color.WHITE)
		"leaves_broad":
			m = foliage("leaves_broad.png", Color(0.92, 1.0, 0.88), 9.0, 0.16)
		"leaves_autumn":
			m = foliage("leaves_autumn.png", Color.WHITE, 8.0, 0.16)
		"palm_frond":
			m = foliage("palm_frond.png", Color(1.0, 1.04, 0.92), 10.0, 0.22)
		"fern_frond":
			m = foliage("fern_frond.png", Color(0.95, 1.05, 0.9), 1.2, 0.08)
		"grass_tuft":
			m = foliage("grass_tufts.png", Color(0.93, 0.98, 0.86), 0.8, 0.09)
			m.set_shader_parameter("ground_ao", 0.62)
			m.set_shader_parameter("translucency", 0.22)
		"coconut":
			m = _plain(Color("4a3420"), 0.8)
		"rock", "rock_moss":
			m = moss_stone("rock_albedo.jpg", "rock_normal.jpg", 0.0 if name == "rock" else 0.42, Color("d8d2c6"))
		"ruin_moss":
			m = moss_stone("ruin_albedo.jpg", "ruin_normal.jpg", 0.36, Color.WHITE, 1.0)
		"stone_block":
			m = moss_stone("stone_albedo.jpg", "stone_normal.jpg", 0.22, Color("f0e6d6"), 1.0)
		"cave_dark":
			m = _standard("rock_albedo.jpg", "rock_normal.jpg", Color("2a2622"), 1.0)
		"roof_tiles":
			m = _standard("roof_albedo.jpg", "roof_normal.jpg", Color.WHITE, 0.7)
		"lighthouse_white":
			m = _standard("plaster_albedo.jpg", "plaster_normal.jpg", Color("f4efe6"), 0.85)
		"lighthouse_red":
			m = _standard("plaster_albedo.jpg", "plaster_normal.jpg", Color("c23a2c"), 0.8)
		"metal_dark":
			m = _plain(Color("2a2c32"), 0.45, 0.65)
		"truss_metal":
			m = _plain(Color("b8bcc4"), 0.35, 0.85)
		"brass":
			m = _plain(Color("c89a50"), 0.32, 0.9)
		"lamp_glass":
			m = _glow(Color("ffe2a0"), 2.6)
		"window_glow":
			m = _glow(Color("3a2414"), 0.0)
			(m as StandardMaterial3D).emission_enabled = true
			(m as StandardMaterial3D).emission = Color("ffb04a")
			(m as StandardMaterial3D).emission_energy_multiplier = 0.55
			(m as StandardMaterial3D).roughness = 0.15
		"window_dark":
			m = _plain(Color("1a2430"), 0.2, 0.3)
		"wood":
			m = _standard("wood_albedo.jpg", "wood_normal.jpg", Color.WHITE, 0.85)
		"wood_dark":
			m = _standard("wood_albedo.jpg", "wood_normal.jpg", Color("7a6050"), 0.85)
		"embers":
			m = _glow(Color("ff6a1a"), 2.4)
		"flame":
			var f := ShaderMaterial.new()
			f.shader = shader("flame")
			f.set_shader_parameter("flame_tex", texture("flame.png"))
			m = f
		"fabric":
			m = _standard("fabric_albedo.jpg", "fabric_normal.jpg", Color("e8d8c0"), 0.95)
			(m as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		"shell":
			m = _plain(Color("f2dccb"), 0.45)
		"crab_shell":
			m = _plain(Color("d8522a"), 0.45)
		"crab_claw":
			m = _plain(Color("e8683a"), 0.4)
		"eye_black":
			m = _plain(Color("101010"), 0.2)
		"bird_body":
			m = _plain(Color("f2f2f0"), 0.7)
		"beak":
			m = _plain(Color("f0b030"), 0.5)
		"bird_wing":
			m = flap("wings.png", 1.9, 5.5, 0.55)
		"butterfly_wing":
			m = flap("wings.png", 0.32, 14.0, 1.1)
		"speaker_box":
			m = _standard("speaker_mesh_albedo.jpg", "speaker_mesh_normal.jpg", Color.WHITE, 0.6, 2.0)
		"speaker_cone":
			m = _plain(Color("1c1c22"), 0.55)
		"lamp_shade":
			m = _plain(Color("2f5a4c"), 0.35, 0.5)
		"paper":
			m = _standard("paper_albedo.jpg", "paper_normal.jpg", Color.WHITE, 0.95)
		"paint_red":
			m = _plain(Color("d83a3a"), 0.3)
		"paint_blue":
			m = _plain(Color("3a6ad8"), 0.3)
		"paint_yellow":
			m = _plain(Color("f0c83a"), 0.3)
		"paint_green":
			m = _plain(Color("4abc5a"), 0.3)
		_:
			m = _plain(Color("c0c0c0"))
	_materials[name] = m
	return m


## Alle Meshes eines Sets: Name -> ArrayMesh mit zugeordneten Materialien.
static func meshes(set_name: String) -> Dictionary:
	if _meshes.has(set_name):
		return _meshes[set_name]
	var out := {}
	var path: String = SETS.get(set_name, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("[AdventureKit] Modellset fehlt: " + set_name)
		_meshes[set_name] = out
		return out
	var scene: PackedScene = load(path)
	var root: Node = scene.instantiate()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var source: Mesh = node.mesh
		if source == null:
			continue
		var mesh: ArrayMesh = source.duplicate()
		for i in range(mesh.get_surface_count()):
			var src_mat: Material = mesh.surface_get_material(i)
			var key := src_mat.resource_name if src_mat != null else ""
			mesh.surface_set_material(i, material(key))
		out[str(node.name)] = mesh
	root.free()
	_meshes[set_name] = out
	return out


static func mesh(set_name: String, model: String) -> Mesh:
	return meshes(set_name).get(model, null)


## MultiMesh-Gruppe: ein Knoten je Modell, Schatten optional, Sichtweite optional.
static func scatter(
	parent: Node3D,
	node_name: String,
	set_name: String,
	model: String,
	xforms: Array[Transform3D],
	shadows: bool = true,
	visible_until: float = 0.0,
	custom: bool = false
) -> MultiMeshInstance3D:
	var source := mesh(set_name, model)
	if source == null or xforms.is_empty():
		return null
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = custom
	multi.mesh = source
	multi.instance_count = xforms.size()
	for i in range(xforms.size()):
		multi.set_instance_transform(i, xforms[i])
		if custom:
			multi.set_instance_custom_data(i, Color(fmod(float(i) * 0.618, 1.0), 0, 0, 0))
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multi
	node.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	if visible_until > 0.0:
		node.visibility_range_end = visible_until
		node.visibility_range_end_margin = visible_until * 0.15
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	parent.add_child(node)
	return node


## Einzelnes Modell (z. B. Leuchtturm, Schloss) als MeshInstance3D.
static func place(
	parent: Node3D, node_name: String, set_name: String, model: String, xform: Transform3D, shadows := true
) -> MeshInstance3D:
	var source := mesh(set_name, model)
	if source == null:
		return null
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = source
	node.transform = xform
	node.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	parent.add_child(node)
	return node


static func xf(at: Vector3, yaw: float = 0.0, scale: float = 1.0, tilt := Vector2.ZERO) -> Transform3D:
	var basis := Basis.from_euler(Vector3(tilt.x, yaw, tilt.y)).scaled(Vector3.ONE * scale)
	return Transform3D(basis, at)


## Weicher Glanzpunkt-Partikel (Funken, Glühwürmchen, Fundmoment).
static func sparkle_particles(
	node_name: String, amount: int, color: Color, radius: float, lifetime: float = 2.4
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = node_name
	p.amount = maxi(1, amount)
	p.lifetime = lifetime
	p.visibility_aabb = AABB(Vector3.ONE * -radius * 2.0, Vector3.ONE * radius * 4.0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = radius
	process.direction = Vector3.UP
	process.spread = 40.0
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = 0.5
	process.gravity = Vector3(0, 0.1, 0)
	process.scale_min = 0.6
	process.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 0.0))
	fade.add_point(0.2, color)
	fade.set_color(fade.get_point_count() - 1, Color(color, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	p.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = texture("soft_dot.png")
	quad.material = mat
	p.draw_pass_1 = quad
	return p
