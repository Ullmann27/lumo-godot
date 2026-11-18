extends Node3D
## Lumos Sternwarten-Stube im Baumhaus: runder Kartentisch, warmes Lampenlicht,
## Blick in die Sternennacht. Reine Kulisse – keine Regeln, keine Karten.
##
## Gebaut aus wenigen geteilten Materialien; gleiche Kisten und Kugeln werden
## zu MultiMeshes zusammengefasst, damit das Handy wenig zeichnen muss.

const TABLE_Y := 0.98
const TABLE_RADIUS := 1.25
const SEAT_RADIUS := 1.56
const STOOL_HEIGHT := 0.72
const WALL_RADIUS := 4.7
## Vorn bleibt die Wand offen – dort steht die Kamera.
const OPEN_FRONT := 64.0
const WOOD_GRAIN := "res://assets/cards_table/table/wood_grain.webp"
const WOOD_PLANKS := "res://assets/cards_table/table/wood_planks.webp"
const TABLE_TOP := "res://assets/cards_table/table/table_top.webp"
const TABLE_GLOW := "res://assets/cards_table/table/table_glow.webp"
const SKY_SHADER := "res://assets/cards_table/shaders/night_sky.gdshader"

var camera: Camera3D
var key_light: SpotLight3D
var environment: Environment
var table_glow_material: StandardMaterial3D
var batches: Array[MultiMeshInstance3D] = []
var batched_instances := 0
var _materials: Dictionary = {}
var _boxes: Dictionary = {}
var _spheres: Dictionary = {}
var _stools: Array[Node3D] = []
var _time := 0.0
var _lamp_materials: Array[StandardMaterial3D] = []
var _sky: MeshInstance3D


func _ready() -> void:
	_build_sky()
	_build_shell()
	_build_table()
	_build_details()
	_build_lights()
	_commit_batches()
	camera = Camera3D.new()
	camera.name = "TableCamera"
	camera.near = 0.08
	camera.far = 60.0
	camera.current = true
	add_child(camera)
	camera.add_child(_sky)
	_sky.position = Vector3(0, 0, -52.0)
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	# Laternen und Sternenkreis atmen ganz leicht.
	var breath := 0.5 + 0.5 * sin(_time * 1.3)
	if table_glow_material != null:
		table_glow_material.emission_energy_multiplier = 1.25 + 0.55 * breath
	for index in range(_lamp_materials.size()):
		_lamp_materials[index].emission_energy_multiplier = 2.3 + 0.35 * sin(_time * 2.1 + index * 1.7)


# ------------------------------------------------------------------ Bausteine


func mat(key: String, color: Color, roughness: float = 0.7, metallic: float = 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.resource_name = key
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_materials[key] = material
	return material


## Holz mit eigener Maserung. Die Textur wird im Weltraum aufgelegt, damit
## gestreckte Kisten im MultiMesh gleichmäßig gemasert bleiben.
func wood(key: String, tint: Color, scale: float = 1.4, planks: bool = false) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := mat(key, tint, 0.74)
	material.albedo_texture = load(WOOD_PLANKS if planks else WOOD_GRAIN)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * scale
	return material


func glowing(key: String, color: Color, energy: float = 2.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := mat(key, color, 0.5)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


## Kiste vormerken; gleiche Materialien werden später ein MultiMesh.
func box(at: Vector3, size: Vector3, material: Material, turn: Vector3 = Vector3.ZERO) -> void:
	var basis := Basis.from_euler(turn) * Basis.from_scale(size)
	if not _boxes.has(material):
		_boxes[material] = []
	_boxes[material].append(Transform3D(basis, at))


func ball(at: Vector3, radius: float, material: Material, squash: Vector3 = Vector3.ONE) -> void:
	if not _spheres.has(material):
		_spheres[material] = []
	_spheres[material].append(Transform3D(Basis.from_scale(squash * radius * 2.0), at))


func cylinder(at: Vector3, top: float, bottom: float, height: float, material: Material, segments: int = 32) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)
	return node


func ring(at: Vector3, radius: float, thickness: float, material: Material, segments: int = 64) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = segments
	mesh.ring_segments = 10
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)
	return node


func _commit_batches() -> void:
	var unit_box := BoxMesh.new()
	unit_box.size = Vector3.ONE
	var unit_ball := SphereMesh.new()
	unit_ball.radius = 0.5
	unit_ball.height = 1.0
	unit_ball.radial_segments = 16
	unit_ball.rings = 8
	for pair: Array in [[_boxes, unit_box, "Boxes"], [_spheres, unit_ball, "Balls"]]:
		var groups: Dictionary = pair[0]
		for material: Material in groups:
			var entries: Array = groups[material]
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = pair[1]
			multimesh.instance_count = entries.size()
			for index in range(entries.size()):
				multimesh.set_instance_transform(index, entries[index])
			var batch := MultiMeshInstance3D.new()
			batch.name = "Room%s_%s" % [pair[2], material.resource_name]
			batch.multimesh = multimesh
			batch.material_override = material
			if material is StandardMaterial3D and (material.emission_enabled or material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED):
				batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(batch)
			batches.append(batch)
			batched_instances += entries.size()
	_boxes.clear()
	_spheres.clear()


static func polar(angle_degrees: float, radius: float, height: float = 0.0) -> Vector3:
	# 0° zeigt zur Kamera (+Z), 90° nach rechts (+X), 180° nach hinten.
	var angle := deg_to_rad(angle_degrees)
	return Vector3(sin(angle) * radius, height, cos(angle) * radius)


## Platz am Tisch: Ursprung am Boden, Blick (−Z) zur Tischmitte.
static func seat_transform(angle_degrees: float, radius: float = SEAT_RADIUS) -> Transform3D:
	var at := polar(angle_degrees, radius)
	return Transform3D(Basis.IDENTITY, at).looking_at(Vector3.ZERO, Vector3.UP)


# --------------------------------------------------------------------- Himmel


func _build_sky() -> void:
	# Der Himmel hängt an der Kamera und füllt immer das ganze Bild; sichtbar
	# bleibt er nur über der Wand und durch das Sternenfenster.
	_sky = MeshInstance3D.new()
	_sky.name = "NightSky"
	var quad := QuadMesh.new()
	quad.size = Vector2(160, 160)
	_sky.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = load(SKY_SHADER)
	_sky.material_override = material
	_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sky.extra_cull_margin = 1000.0
	# Ferne Baumkronen als dunkle Schattenrisse, dazwischen Laternenlichter.
	var far_tree := mat("far_tree", Color("0c2233"), 1.0)
	far_tree.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var near_tree := mat("near_tree", Color("12303a"), 1.0)
	near_tree.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in range(26):
		var x := -19.0 + index * 1.55 + sin(index * 2.4) * 0.5
		var size := 2.2 + 1.1 * absf(sin(index * 1.7))
		ball(Vector3(x, 0.2 + size * 0.35, -13.5 - absf(sin(index * 0.9)) * 1.5), size, far_tree, Vector3(1.0, 1.25, 0.6))
	for index in range(14):
		var x := -13.0 + index * 2.0 + cos(index * 1.9) * 0.6
		var size := 1.5 + 0.8 * absf(cos(index * 2.3))
		ball(Vector3(x, -0.6 + size * 0.3, -9.4 - absf(cos(index * 1.3))), size, near_tree, Vector3(1.0, 1.3, 0.6))
	var warm := glowing("far_lantern_warm", Color("ffc66b"), 3.2)
	var cool := glowing("far_lantern_cool", Color("7fe3ff"), 2.6)
	for index in range(22):
		var x := -12.5 + index * 1.2 + sin(index * 3.1) * 0.4
		var y := 1.4 + 1.6 * absf(sin(index * 1.37))
		ball(Vector3(x, y, -8.6 - absf(sin(index * 2.2)) * 3.0), 0.085 + 0.03 * (index % 3), warm if index % 3 != 0 else cool)


# -------------------------------------------------------------- Baumhaus-Hülle


func _build_shell() -> void:
	var floor_wood := wood("floor_wood", Color("c9a184"), 0.42, true)
	var plank := wood("plank_wood", Color("b98d6d"), 0.8)
	var dark := wood("dark_wood", Color("7d5a45"), 0.9)
	var trim := wood("trim_wood", Color("e0b383"), 1.0)
	# Boden: weite Dielenplattform; vorn offen wie eine Bühne.
	var ground := cylinder(Vector3(0, -0.1, 0), 11.0, 11.0, 0.2, floor_wood, 48)
	ground.name = "Floor"
	# Bretterwand im Rund – hinten bleibt das große Sternenfenster frei.
	var step := 6.0
	var angle := -177.0
	while angle <= 177.0:
		if absf(angle) < OPEN_FRONT:
			angle += step
			continue
		var in_window := absf(angle) > 139.0
		var at := polar(angle, WALL_RADIUS)
		var turn := Vector3(0, deg_to_rad(angle), 0)
		var shade := plank if int(roundf(angle / step)) % 2 == 0 else dark
		if in_window:
			# Brüstung unter dem Fenster.
			box(at + Vector3(0, 0.55, 0), Vector3(0.52, 1.1, 0.14), shade, turn)
		else:
			box(at + Vector3(0, 2.1, 0), Vector3(0.52, 4.2, 0.14), shade, turn)
		angle += step
	# Fensterrahmen: zwei Pfosten, Sims und Bogen aus kurzen Balken.
	for side: float in [-1.0, 1.0]:
		var post := polar(side * 139.0, WALL_RADIUS - 0.08)
		box(post + Vector3(0, 2.1, 0), Vector3(0.26, 4.2, 0.3), trim, Vector3(0, deg_to_rad(side * 139.0), 0))
	# Abschlusspfosten an der offenen Vorderseite.
	for side: float in [-1.0, 1.0]:
		var end_post := polar(side * (OPEN_FRONT + 1.0), WALL_RADIUS - 0.04)
		box(end_post + Vector3(0, 2.1, 0), Vector3(0.3, 4.2, 0.34), trim, Vector3(0, deg_to_rad(side * OPEN_FRONT), 0))
	for index in range(15):
		var a := 141.0 + index * 5.57
		var at := polar(a, WALL_RADIUS - 0.1)
		box(at + Vector3(0, 1.14, 0), Vector3(0.5, 0.1, 0.34), trim, Vector3(0, deg_to_rad(a), 0))
		# Bogen oben: steigt zur Mitte hin an.
		var lift := 3.25 + 0.75 * sin(float(index) / 14.0 * PI)
		box(at + Vector3(0, lift, 0), Vector3(0.52, 0.22, 0.3), trim, Vector3(0, deg_to_rad(a), 0))
		box(at + Vector3(0, lift + 0.55, 0), Vector3(0.52, 0.9, 0.14), dark, Vector3(0, deg_to_rad(a), 0))
	# Ringbalken und Dachsparren zur Lampe in der Mitte.
	var beam_angle := -174.0
	while beam_angle <= 174.0:
		if absf(beam_angle) >= OPEN_FRONT:
			box(polar(beam_angle, WALL_RADIUS - 0.1, 4.25), Vector3(0.52, 0.24, 0.3), trim, Vector3(0, deg_to_rad(beam_angle), 0))
		beam_angle += 6.0
	for index in range(6):
		var a := 75.0 + index * 42.0
		var middle := polar(a, WALL_RADIUS * 0.52, 4.86)
		box(middle, Vector3(0.16, 0.2, WALL_RADIUS * 1.02), dark, Vector3(deg_to_rad(-14.0), deg_to_rad(a), 0))
	cylinder(Vector3(0, 5.5, 0), 0.34, 0.5, 0.3, trim, 16)


# ----------------------------------------------------------------------- Tisch


func _build_table() -> void:
	var rim_wood := wood("table_rim", Color("e3ad78"), 1.5)
	var trunk := wood("table_trunk", Color("a37553"), 0.9)
	# Platte: Filz mit dem leuchtenden Sternenkreis.
	var top := cylinder(Vector3(0, TABLE_Y - 0.03, 0), TABLE_RADIUS - 0.09, TABLE_RADIUS - 0.09, 0.06, null, 64)
	top.name = "TableTop"
	var felt := StandardMaterial3D.new()
	felt.resource_name = "table_felt"
	felt.albedo_texture = load(TABLE_TOP)
	felt.roughness = 0.92
	felt.emission_enabled = true
	felt.emission_texture = load(TABLE_GLOW)
	felt.emission = Color.BLACK
	felt.emission_energy_multiplier = 1.5
	top.material_override = felt
	table_glow_material = felt
	# Die Zylinder-UV der Deckfläche ist bereits ein Kreis-Ausschnitt.
	felt.uv1_scale = Vector3(1, 1, 1)
	_fix_cap_uv(top)
	# Holzrand: außen gerundet, leicht über dem Filz.
	ring(Vector3(0, TABLE_Y - 0.035, 0), TABLE_RADIUS - 0.035, 0.075, rim_wood).name = "TableRim"
	cylinder(Vector3(0, TABLE_Y - 0.1, 0), TABLE_RADIUS - 0.04, TABLE_RADIUS - 0.2, 0.1, rim_wood, 48)
	# Fuß: Baumstumpf mit breitem Wurzelansatz.
	cylinder(Vector3(0, 0.52, 0), 0.34, 0.42, 0.78, trunk, 20)
	cylinder(Vector3(0, 0.1, 0), 0.44, 0.78, 0.2, trunk, 20)
	# Teppich unter dem Tisch.
	var rug := mat("rug", Color("1c2a66"), 1.0)
	cylinder(Vector3(0, 0.012, 0), 2.75, 2.75, 0.02, rug, 48).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring(Vector3(0, 0.03, 0), 2.6, 0.035, mat("rug_gold", Color("d9a94e"), 0.9), 48)
	ring(Vector3(0, 0.03, 0), 2.3, 0.02, mat("rug_cyan", Color("4fb9d8"), 0.9), 48)


## Die Deckfläche eines CylinderMesh nutzt nur einen Teil der Textur. Hier
## bekommt die Platte eine eigene Scheibe mit sauberer 0..1-UV.
func _fix_cap_uv(top: MeshInstance3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius: float = TABLE_RADIUS - 0.09
	var segments := 64
	for index in range(segments):
		var a0 := TAU * index / segments
		var a1 := TAU * (index + 1) / segments
		for corner: Array in [[0.0, 0.0], [1.0, a0], [1.0, a1]]:
			var r: float = corner[0]
			var a: float = corner[1]
			var point := Vector2(cos(a), sin(a)) * r
			tool.set_normal(Vector3.UP)
			tool.set_uv(point * 0.5 + Vector2(0.5, 0.5))
			tool.add_vertex(Vector3(point.x * radius, 0.031, point.y * radius))
	var disc := MeshInstance3D.new()
	disc.name = "TableFelt"
	disc.mesh = tool.commit()
	disc.material_override = top.material_override
	top.add_child(disc)
	top.material_override = mat("table_under", Color("2a1c16"), 0.9)


## Hocker für einen Platz; `tint` ist die Kissenfarbe der Figur.
func add_stool(angle_degrees: float, tint: Color, radius: float = SEAT_RADIUS) -> Node3D:
	var stool := Node3D.new()
	stool.name = "Stool"
	stool.position = polar(angle_degrees, radius + 0.04)
	add_child(stool)
	var log_mesh := MeshInstance3D.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.34
	body.bottom_radius = 0.38
	body.height = STOOL_HEIGHT - 0.1
	body.radial_segments = 16
	log_mesh.mesh = body
	log_mesh.material_override = wood("stool_wood", Color("b8875f"), 1.2)
	log_mesh.position.y = (STOOL_HEIGHT - 0.1) * 0.5
	stool.add_child(log_mesh)
	var cushion := MeshInstance3D.new()
	var pad := CylinderMesh.new()
	pad.top_radius = 0.33
	pad.bottom_radius = 0.37
	pad.height = 0.1
	pad.radial_segments = 16
	cushion.mesh = pad
	cushion.material_override = mat("cushion_" + tint.to_html(false), tint.lerp(Color("23306a"), 0.35), 0.95)
	cushion.position.y = STOOL_HEIGHT - 0.05
	stool.add_child(cushion)
	_stools.append(stool)
	return stool


func clear_stools() -> void:
	for stool: Node3D in _stools:
		stool.queue_free()
	_stools.clear()


# --------------------------------------------------------------------- Details


func _build_details() -> void:
	var dark := wood("dark_wood", Color("7d5a45"), 0.9)
	var trim := wood("trim_wood", Color("e0b383"), 1.0)
	var brass := mat("brass", Color("d9aa55"), 0.35, 0.85)
	# Regale mit Büchern und Leuchtgläsern links und rechts.
	var book_colors := [Color("c2553f"), Color("3d7fa6"), Color("d9a441"), Color("4f9a6a"), Color("7d5bb5")]
	for side: float in [-1.0, 1.0]:
		for shelf in range(3):
			var a := side * (88.0 + shelf * 0.0)
			var height := 1.25 + shelf * 0.82
			var at := polar(a, WALL_RADIUS - 0.36, height)
			var turn := Vector3(0, deg_to_rad(a), 0)
			box(at, Vector3(2.3, 0.07, 0.44), trim, turn)
			for index in range(8):
				var offset := -0.95 + index * 0.25
				var along := Vector3(cos(deg_to_rad(a)), 0, -sin(deg_to_rad(a))) * offset
				if (index + shelf) % 4 == 3:
					var jar := glowing("jar_%d" % ((index + shelf) % 2), Color("ffd27a") if (index + shelf) % 2 == 0 else Color("7fe3ff"), 2.2)
					ball(at + along + Vector3(0, 0.2, 0), 0.11, jar, Vector3(1, 1.25, 1))
					_register_lamp(jar)
				else:
					var tall := 0.34 + 0.07 * ((index * 3 + shelf) % 3)
					var color: Color = book_colors[(index + shelf * 2) % book_colors.size()]
					box(at + along + Vector3(0, 0.035 + tall * 0.5, 0), Vector3(0.11, tall, 0.26),
						mat("book_%d" % ((index + shelf * 2) % book_colors.size()), color, 0.85), turn + Vector3(0, 0, 0.06 * ((index % 3) - 1)))
	# Fernrohr am Sternenfenster.
	var scope_at := polar(158.0, WALL_RADIUS - 1.05)
	for leg in range(3):
		var foot := Vector3(cos(leg * TAU / 3.0), 0, sin(leg * TAU / 3.0)) * 0.34
		box(scope_at + foot * 0.5 + Vector3(0, 0.62, 0), Vector3(0.05, 1.3, 0.05), dark, Vector3(foot.z * 0.52, 0, -foot.x * 0.52))
	var tube := cylinder(scope_at + Vector3(0, 1.55, -0.2), 0.11, 0.16, 1.25, brass, 16)
	tube.rotation = Vector3(deg_to_rad(58.0), deg_to_rad(18.0), 0)
	var lens := cylinder(scope_at + Vector3(0, 1.55, -0.2), 0.17, 0.17, 0.08, mat("lens", Color("2d4f8f"), 0.2, 0.3), 16)
	lens.rotation = tube.rotation
	lens.translate_object_local(Vector3(0, -0.64, 0))
	# Sternkarte an der Wand (rund gerahmt, leuchtet sanft).
	for side: float in [-1.0, 1.0]:
		var a := side * 118.0
		var chart := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.62
		disc.bottom_radius = 0.62
		disc.height = 0.05
		disc.radial_segments = 32
		chart.mesh = disc
		var chart_mat := StandardMaterial3D.new()
		chart_mat.resource_name = "star_chart"
		chart_mat.albedo_color = Color("16306e")
		chart_mat.emission_enabled = true
		chart_mat.emission_texture = load(TABLE_GLOW)
		chart_mat.emission = Color.BLACK
		chart_mat.emission_energy_multiplier = 0.9
		chart_mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
		chart.material_override = _materials.get_or_add("star_chart", chart_mat)
		chart.position = polar(a, WALL_RADIUS - 0.14, 2.75)
		chart.rotation = Vector3(deg_to_rad(90.0), deg_to_rad(a), 0)
		chart.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(chart)
		var frame := ring(chart.position, 0.64, 0.05, trim, 32)
		frame.rotation = chart.rotation
	# Topfpflanzen am Rand.
	var leaf := mat("leaf", Color("3f9d63"), 0.8)
	var leaf_light := mat("leaf_light", Color("6cc47f"), 0.8)
	var pot := mat("pot", Color("b5653f"), 0.9)
	for entry: Array in [[-62.0, 1.0], [62.0, 0.85], [-128.0, 0.7], [128.0, 0.75]]:
		var at := polar(entry[0], WALL_RADIUS - 0.75)
		var s: float = entry[1]
		cylinder(at + Vector3(0, 0.22 * s, 0), 0.3 * s, 0.22 * s, 0.44 * s, pot, 12)
		for index in range(6):
			var spread := Vector3(cos(index * 1.05), 0, sin(index * 1.05)) * 0.2 * s
			ball(at + spread + Vector3(0, (0.62 + 0.14 * (index % 3)) * s, 0), 0.24 * s, leaf if index % 2 == 0 else leaf_light, Vector3(1.0, 1.25, 1.0))
	# Kissenstapel und Truhe vorn rechts – dort sitzt niemand.
	var chest_at := polar(58.0, 2.9)
	box(chest_at + Vector3(0, 0.26, 0), Vector3(0.9, 0.52, 0.6), wood("chest", Color("c98f62"), 1.5), Vector3(0, deg_to_rad(-32.0), 0))
	box(chest_at + Vector3(0, 0.55, 0), Vector3(0.96, 0.08, 0.66), dark, Vector3(0, deg_to_rad(-32.0), 0))
	box(chest_at + Vector3(0, 0.3, 0), Vector3(0.14, 0.2, 0.64), brass, Vector3(0, deg_to_rad(-32.0), 0))
	# Lichterketten in weiten Bögen unter den Sparren.
	var bulbs := [glowing("bulb_warm", Color("ffcf7a"), 2.6), glowing("bulb_cyan", Color("7fe3ff"), 2.2), glowing("bulb_rose", Color("ff9fc0"), 2.0)]
	for chain in range(5):
		var a0 := 66.0 + chain * 45.6
		var a1 := a0 + 45.6
		for index in range(13):
			var t := float(index) / 12.0
			var a := lerpf(a0, a1, t)
			var sag := 0.55 * sin(t * PI)
			ball(polar(a, WALL_RADIUS - 0.45, 3.95 - sag), 0.045, bulbs[(index + chain) % 3])
	for bulb: StandardMaterial3D in bulbs:
		_register_lamp(bulb)
	# Wimpelkette über dem Fenster.
	var flags := [mat("flag_gold", Color("ffc94a"), 0.9), mat("flag_cyan", Color("53ddfd"), 0.9), mat("flag_rose", Color("ff7fae"), 0.9), mat("flag_violet", Color("9c7bff"), 0.9)]
	for index in range(13):
		var a := 143.0 + index * 6.2
		var drop := 0.22 * sin(float(index) / 12.0 * PI)
		box(polar(a, WALL_RADIUS - 0.42, 3.05 - drop), Vector3(0.24, 0.3, 0.02), flags[index % 4], Vector3(0, deg_to_rad(a), deg_to_rad(45.0)))


func _register_lamp(material: StandardMaterial3D) -> void:
	if not _lamp_materials.has(material):
		_lamp_materials.append(material)


# ---------------------------------------------------------------------- Licht


func _build_lights() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("070d24")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6f86d8")
	environment.ambient_light_energy = 0.46
	# Der PerformanceManager schaltet Nebel je Profil; hier ist er nur ein Hauch Nachtblau.
	environment.fog_enabled = true
	environment.fog_light_color = Color("16245e")
	environment.fog_density = 0.006
	environment.fog_sky_affect = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.12
	environment.adjustment_contrast = 1.04
	world.environment = environment
	add_child(world)
	# Hängelampe über dem Tisch: die warme Hauptlichtquelle mit Schatten.
	var lamp_at := Vector3(0, 3.55, 0.25)
	var shade := glowing("lamp_glass", Color("ffd58a"), 2.6)
	ball(lamp_at, 0.3, shade, Vector3(1.0, 0.82, 1.0))
	_register_lamp(shade)
	var brass := mat("brass", Color("d9aa55"), 0.35, 0.85)
	cylinder(lamp_at + Vector3(0, 0.3, 0), 0.06, 0.34, 0.2, brass, 16)
	cylinder(lamp_at + Vector3(0, 1.2, 0), 0.015, 0.015, 1.7, brass, 6)
	ring(lamp_at + Vector3(0, -0.02, 0), 0.31, 0.02, brass, 24)
	key_light = SpotLight3D.new()
	key_light.name = "LampLight"
	key_light.position = lamp_at + Vector3(0, -0.1, 0)
	key_light.rotation_degrees = Vector3(-90, 0, 0)
	key_light.light_color = Color("ffe2b0")
	key_light.light_energy = 2.1
	key_light.spot_range = 7.5
	key_light.spot_angle = 62.0
	key_light.spot_angle_attenuation = 0.7
	key_light.spot_attenuation = 0.9
	key_light.shadow_enabled = true
	key_light.shadow_bias = 0.04
	key_light.shadow_blur = 1.6
	add_child(key_light)
	# Mondlicht von hinten als kühle Kante auf Köpfen und Tischrand.
	var moon := DirectionalLight3D.new()
	moon.name = "MoonLight"
	moon.rotation_degrees = Vector3(-28, 158, 0)
	moon.light_color = Color("9cc4ff")
	moon.light_energy = 0.55
	moon.shadow_enabled = false
	add_child(moon)
	# Weiches Fülllicht von vorn, damit Gesichter nicht zulaufen.
	var fill := OmniLight3D.new()
	fill.name = "FrontFill"
	fill.position = Vector3(0.0, 2.6, 3.4)
	fill.light_color = Color("ffd9b8")
	fill.light_energy = 0.75
	fill.omni_range = 7.5
	fill.omni_attenuation = 0.8
	fill.shadow_enabled = false
	add_child(fill)
	# Glühwürmchen ziehen langsam durch den Raum.
	var motes := CPUParticles3D.new()
	motes.name = "Fireflies"
	motes.amount = 28
	motes.lifetime = 9.0
	motes.preprocess = 9.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(3.6, 1.2, 3.2)
	motes.position = Vector3(0, 2.6, -0.4)
	motes.direction = Vector3(0, 1, 0)
	motes.spread = 180.0
	motes.gravity = Vector3.ZERO
	motes.initial_velocity_min = 0.03
	motes.initial_velocity_max = 0.12
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.2
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.018
	mote_mesh.height = 0.036
	mote_mesh.radial_segments = 6
	mote_mesh.rings = 3
	motes.mesh = mote_mesh
	var mote_material := glowing("firefly", Color("ffe9a0"), 3.0)
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	motes.material_override = mote_material
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)


# ---------------------------------------------------------------------- Kamera


## Stellt die Kamera so, dass Tisch und Runde ins Bild passen.
## `half_width` ist die halbe Breite, die sichtbar sein muss (Welt-Einheiten).
func frame(aspect: float, half_width: float, half_height: float, tilt_degrees: float, shift_down: float) -> void:
	var portrait := aspect < 1.0
	camera.fov = 44.0 if portrait else 36.0
	var half_fov := deg_to_rad(camera.fov * 0.5)
	var by_width := half_width / (tan(half_fov) * aspect)
	var by_height := half_height / tan(half_fov)
	var distance := maxf(by_width, by_height)
	var tilt := deg_to_rad(tilt_degrees)
	var target := Vector3(0, TABLE_Y, 0.0)
	camera.position = target + Vector3(0, sin(tilt), cos(tilt)) * distance
	camera.look_at(target)
	# Bild nach oben schieben: unten braucht die eigene Hand Platz.
	camera.v_offset = -shift_down * distance * tan(half_fov)
