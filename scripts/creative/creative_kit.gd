extends RefCounted
## Shared real geometry, material cache and glass UI for the three new 3D games.
const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")
var materials: Dictionary = {}
const STONE = preload("res://assets/creative/sandstone.webp")
const GRASS = preload("res://assets/generated/lumo3d_assets/textures/albedo/grass_deep_albedo.png")
const WOOD = preload(
	"res://assets/generated/lumo3d_assets/textures/albedo/wood_warm_soft_albedo.png"
)


func material(color: Color, glow: bool = false, glass: bool = false) -> StandardMaterial3D:
	var key: String = color.to_html() + str(glow) + str(glass)
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.62
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.3
	if glass:
		mat.roughness = 0.18
		mat.metallic = 0.28
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.55
	materials[key] = mat
	return mat


func textured(kind: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := "texture-" + kind + tint.to_html()
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = {"stone": STONE, "grass": GRASS, "wood": WOOD}[kind]
	mat.albedo_color = tint
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * (0.65 if kind == "stone" else 0.45)
	mat.roughness = 0.83
	materials[key] = mat
	return mat


func castle(root: Node3D, at: Vector3, scale_factor: float = 1.0) -> void:
	var castle_root := Node3D.new()
	root.add_child(castle_root)
	castle_root.position = at
	castle_root.scale = Vector3.ONE * scale_factor
	for x in [-4.0, 4.0]:
		var tower := cylinder(castle_root, Vector3(x, 2.9, 0), 1.25, 5.8, Color("91a9cf"))
		tower.material_override = textured("stone", Color("98b0d5"))
		cylinder(castle_root, Vector3(x, 7.25, 0), 1.8, 3.0, Color("3e78b7"), 0)
		for y in [2.0, 4.0]:
			box(castle_root, Vector3(x, y, 1.23), Vector3(0.38, 0.7, 0.06), Color("ffdca0"), true)
		box(castle_root, Vector3(x, 8.7, 0), Vector3(0.06, 1.8, 0.06), Color("ded7b7"))
		box(castle_root, Vector3(x + 0.48, 9.3, 0), Vector3(0.9, 0.55, 0.08), Color("5bc7e8"))
	var hall := box(castle_root, Vector3(0, 1.9, 0), Vector3(6.8, 3.8, 2.8), Color.WHITE)
	hall.material_override = textured("stone", Color("b2c7db"))
	var roof := PrismMesh.new()
	roof.size = Vector3(7.4, 2.0, 3.4)
	mesh(castle_root, roof, Vector3(0, 4.8, 0), Color("4077b2"))
	box(castle_root, Vector3(0, 1.15, 1.42), Vector3(1.3, 2.3, 0.1), Color("354777"))
	for x in [-2.0, 2.0]:
		box(castle_root, Vector3(x, 2.2, 1.42), Vector3(0.65, 1.05, 0.06), Color("ffdca0"), true)


func mesh(
	root: Node3D, shape: Mesh, at: Vector3, color: Color, glow: bool = false, glass: bool = false
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material(color, glow, glass)
	node.position = at
	root.add_child(node)
	return node


func box(
	root: Node3D, at: Vector3, size: Vector3, color: Color, glow: bool = false
) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(root, shape, at, color, glow)


func sphere(
	root: Node3D, at: Vector3, size: Vector3, color: Color, glow: bool = false
) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 16
	shape.rings = 8
	var node: MeshInstance3D = mesh(root, shape, at, color, glow)
	node.scale = size
	return node


func cylinder(
	root: Node3D, at: Vector3, radius: float, height: float, color: Color, top: float = -1.0
) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius if top < 0.0 else top
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 16
	return mesh(root, shape, at, color)


func collision(root: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	node.shape = shape
	node.position = at
	root.add_child(node)


func part_node(item: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.set_meta("part", item.id)
	var size: Vector3 = item.size
	var color: Color = item.color
	var glow: bool = bool(item.get("glow", false))
	var mid := Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5)
	match str(item.shape):
		"door":
			box(body, mid, size * 0.98, color)
			box(body, Vector3(0.5, 0.9, 0.995), Vector3(0.64, 1.72, 0.05), Color("655276"))
			box(body, Vector3(0.5, 1.42, 1.035), Vector3(0.32, 0.36, 0.03), Color("ffd896"), true)
			sphere(body, Vector3(0.73, 0.8, 1.05), Vector3.ONE * 0.10, Color("eac785"))
			collision(body, mid, size * 0.98)
		"arch":
			for x in [0.4, 2.6]:
				box(body, Vector3(x, 1.1, 0.5), Vector3(0.8, 2.2, 0.92), color)
				collision(body, Vector3(x, 1.1, 0.5), Vector3(0.8, 2.2, 0.92))
			box(body, Vector3(1.5, 2.6, 0.5), Vector3(3, 0.8, 0.98), color)
			collision(body, Vector3(1.5, 2.6, 0.5), Vector3(3, 0.8, 0.98))
		"roof":
			var shape := PrismMesh.new()
			shape.size = size * Vector3(0.98, 0.98, 0.98)
			mesh(body, shape, mid, color)
			collision(body, mid, size * 0.98)
		"cone":
			cylinder(body, mid, 1.48, size.y, color, 0)
			collision(body, mid, size * 0.96)
		"pillar":
			cylinder(body, mid, 0.35, size.y - 0.25, color)
			box(body, Vector3(0.5, 0.12, 0.5), Vector3(0.9, 0.24, 0.9), color)
			box(body, Vector3(0.5, size.y - 0.12, 0.5), Vector3(0.9, 0.24, 0.9), color)
			collision(body, mid, size * 0.96)
		"stairs":
			for i in range(3):
				var height: float = (i + 1) * 2.0 / 3.0
				var at := Vector3(0.5, height * 0.5, float(i) + 0.5)
				box(body, at, Vector3(0.96, height, 0.96), color)
				collision(body, at, Vector3(0.96, height, 0.96))
		"tree":
			cylinder(body, Vector3(1, 1.1, 1), 0.20, 2.2, Color("886647"))
			for at in [Vector3(1, 2.7, 1), Vector3(0.5, 2.4, 0.8), Vector3(1.5, 2.9, 1.2)]:
				sphere(body, at, Vector3(1.2, 1.3, 1.2), color)
			collision(body, Vector3(1, 1, 1), Vector3(0.4, 2, 0.4))
		"lantern":
			cylinder(body, Vector3(0.5, 0.75, 0.5), 0.06, 1.5, Color("40577b"))
			box(body, Vector3(0.5, 1.7, 0.5), Vector3(0.42, 0.5, 0.42), color, true)
			cylinder(body, Vector3(0.5, 1.99, 0.5), 0.35, 0.16, Color("5e6784"), 0.08)
			collision(body, mid, Vector3(0.5, 2, 0.5))
		"crystal", "star":
			var node: MeshInstance3D = mesh(
				body, SHAPES.star() if item.shape == "star" else SHAPES.crystal(), mid, color, true
			)
			node.scale = size * 0.75
			collision(body, mid, size * 0.7)
		"flag":
			cylinder(body, Vector3(0.18, 1.5, 0.5), 0.045, 3, Color("d4def4"))
			box(body, Vector3(0.63, 2.6, 0.5), Vector3(0.72, 0.65, 0.06), color)
			collision(body, Vector3(0.18, 1.5, 0.5), Vector3(0.12, 3, 0.12))
		"flowers":
			for i in range(5):
				var at := Vector3(0.15 + 0.17 * i, 0.4 + 0.08 * (i % 2), 0.35 + 0.2 * (i % 2))
				cylinder(body, at * Vector3(1, 0.5, 1), 0.025, at.y, Color("59a766"))
				sphere(body, at, Vector3.ONE * 0.2, color)
		"bush":
			sphere(body, mid, Vector3(0.94, 0.94, 0.94), color)
			collision(body, mid, size * 0.75)
		"bench":
			box(body, Vector3(1, 0.45, 0.5), Vector3(1.95, 0.2, 0.85), color)
			box(body, Vector3(1, 0.8, 0.1), Vector3(1.95, 0.4, 0.15), color)
			for x in [0.3, 1.7]:
				box(body, Vector3(x, 0.2, 0.5), Vector3(0.15, 0.4, 0.7), Color("4a5d76"))
			collision(body, mid, size * 0.95)
		"bridge":
			box(body, Vector3(1.5, 0.55, 0.5), Vector3(2.98, 0.3, 0.98), color)
			for z in [0.07, 0.93]:
				box(body, Vector3(1.5, 0.86, z), Vector3(2.98, 0.18, 0.12), color.darkened(0.15))
			collision(body, Vector3(1.5, 0.55, 0.5), Vector3(2.98, 0.3, 0.98))
		"waterfall":
			var water: MeshInstance3D = box(body, mid, Vector3(0.85, 2.95, 0.3), color)
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://assets/shaders/kart_waterfall.gdshader")
			water.material_override = mat
		"grass":
			box(body, Vector3(0.5, 0.4, 0.5), Vector3(0.98, 0.8, 0.98), Color("8c7359"))
			box(body, Vector3(0.5, 0.9, 0.5), Vector3(0.99, 0.2, 0.99), color)
			collision(body, mid, size * 0.98)
		_:
			var shape := BoxMesh.new()
			shape.size = size * 0.98
			mesh(body, shape, mid, color, glow, item.shape == "glass")
			collision(body, mid, size * 0.98)
	if item.id in ["stone", "sand"] or item.shape in ["wall", "arch", "pillar", "stairs"]:
		for child in body.get_children():
			if child is MeshInstance3D:
				child.material_override = textured("stone", color.lightened(0.45))
	if item.id == "wood" or item.shape in ["bridge", "bench"]:
		for child in body.get_children():
			if child is MeshInstance3D:
				child.material_override = textured("wood", color.lightened(0.5))
	if item.shape == "wall":
		box(body, Vector3(0.5, 1.18, 1.005), Vector3(0.55, 0.72, 0.025), Color("476c9d"))
		box(body, Vector3(0.5, 1.18, 1.022), Vector3(0.40, 0.55, 0.015), Color("ffe4aa"), true)
		box(body, Vector3(0.5, 1.18, 1.035), Vector3(0.035, 0.56, 0.02), Color("7587a8"))
	if item.shape in ["wall", "stone", "sand"]:
		for y in range(int(size.y) * 3):
			box(
				body,
				Vector3(size.x * 0.5, (y + 1) / 3.0, 0.006),
				Vector3(size.x * 0.95, 0.013, 0.012),
				color.darkened(0.22)
			)
	return body


func environment(root: Node3D) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("081537")
	sky_mat.sky_horizon_color = Color("1a3264")
	sky_mat.ground_horizon_color = Color("1a3264")
	sky_mat.ground_bottom_color = Color("07152d")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a8c7fa")
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.04
	world.environment = env
	root.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -30, 0)
	light.light_color = Color("d9e8ff")
	light.light_energy = 0.80
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 70.0
	root.add_child(light)
	sphere(root, Vector3(-35, 36, -48), Vector3.ONE * 5.5, Color("c1d9ff"), true)
	var stars := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = SHAPES.star()
	multi.instance_count = 90
	var rng := RandomNumberGenerator.new()
	rng.seed = 75199
	for i in range(90):
		var at := Vector3(
			rng.randf_range(-65, 65), rng.randf_range(20, 55), rng.randf_range(-65, -25)
		)
		multi.set_instance_transform(
			i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.12, 0.3)), at)
		)
	stars.multimesh = multi
	stars.material_override = material(Color("b5d9ff"), true)
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(stars)


static func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.07, 0.18, 0.94)
	style.border_color = Color("56bcf3")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)
	return style


static func button(text: String, callback: Callable, min_width: float = 82) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = Vector2(min_width, 48)
	control.add_theme_stylebox_override("normal", panel())
	var hover: StyleBoxFlat = panel()
	hover.bg_color = Color("205083")
	control.add_theme_stylebox_override("hover", hover)
	control.add_theme_stylebox_override("pressed", hover)
	control.add_theme_font_size_override("font_size", 16)
	control.pressed.connect(callback)
	return control


static func label(text: String, size: int = 18) -> Label:
	var control := Label.new()
	control.text = text
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", Color("e4f5ff"))
	return control
