extends Node3D
## Lumos Sternwarten-Spielzimmer im Baumhaus: runder Eichentisch mit Filz,
## Hängelampe mit warmem Lichtkegel und Staub im Licht, Bücherregale, Wanduhr,
## die wirklich läuft, Kreidetafel mit dem echten Spielstand, Rundbogenfenster
## mit Abendhimmel und ziehenden Wolken, Teppich, Pflanzen, Kakao und Kekse.
## Reine Kulisse – keine Regeln, keine Karten.
##
## Möbel kommen aus Blender (assets/table_room/models, siehe
## tools/lumo_table_art/build_room_props.py), Texturen sind selbst erzeugt.
## Gleiche Kisten und Kugeln werden zu MultiMeshes zusammengefasst. Was
## gebaut wird, hängt vom Qualitätsprofil ab (LOW/MEDIUM/HIGH).

const KIT = preload("res://scripts/games/table_room/table_room_kit.gd")
const TABLE_Y := 0.98
const TABLE_RADIUS := 1.25
const SEAT_RADIUS := 1.56
const STOOL_HEIGHT := 0.72
## Lumo sitzt näher an der Kante und etwas höher (dickes Kissen): so liegen
## seine Hände aus der Sitzhaltung auf der Tischplatte.
const LUMO_RADIUS := 1.38
const LUMO_LIFT := 0.05
const WALL_RADIUS := 4.7
const WALL_HEIGHT := 4.1
## Vorn bleibt die Wand offen – dort steht die Kamera.
const OPEN_FRONT := 64.0
## Halber Winkel der Fensteröffnung hinten (bei 180°).
const WINDOW_HALF := 16.5
const WINDOW_BASE := 0.35
const WINDOW_WIDTH := 2.4
const WINDOW_HEIGHT := 2.6
## Höhe der Glühbirne: hoch genug, dass der Schirm keine Köpfe verdeckt.
const LAMP_Y := 3.4
const SKY_SHADER := "res://assets/cards_table/shaders/night_sky.gdshader"
const TABLE_GLOW := "res://assets/cards_table/table/table_glow.webp"

var camera: Camera3D
var key_light: SpotLight3D
var environment: Environment
var table_glow_material: StandardMaterial3D
var batches: Array[MultiMeshInstance3D] = []
var batched_instances := 0
var quality := "medium"
## Uhrzeit für die Wanduhr; Tests dürfen sie festlegen (Sekunden seit Mitternacht, −1 = echte Zeit).
var clock_override := -1.0
var _materials: Dictionary = {}
var _boxes: Dictionary = {}
var _spheres: Dictionary = {}
var _stools: Array[Node3D] = []
var _time := 0.0
var _lamp_materials: Array[StandardMaterial3D] = []
var _sky: MeshInstance3D
var _hour_hand: Node3D
var _minute_hand: Node3D
var _pendulum: Node3D
var _lamp: Node3D
var _flame: Node3D
var _cone_material: StandardMaterial3D
var _board_label: Label3D
var _board_title: Label3D
var _scoreboard: Node3D


func _ready() -> void:
	quality = KIT.tier()
	_build_sky()
	_build_shell()
	_build_table()
	_build_furniture()
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
	_update_clock()
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	# Lampen, Sternenkreis und Kerze atmen ganz leicht.
	var breath := 0.5 + 0.5 * sin(_time * 1.3)
	if table_glow_material != null:
		table_glow_material.emission_energy_multiplier = 1.05 + 0.45 * breath
	for index in range(_lamp_materials.size()):
		_lamp_materials[index].emission_energy_multiplier = 2.3 + 0.35 * sin(_time * 2.1 + index * 1.7)
	if is_instance_valid(_lamp):
		# Die Lampe pendelt kaum merklich an ihrer Kette.
		_lamp.rotation.z = 0.012 * sin(_time * 0.7)
		_lamp.rotation.x = 0.008 * sin(_time * 0.53 + 1.0)
	if is_instance_valid(_flame):
		var flicker := 1.0 + 0.12 * sin(_time * 13.0) + 0.08 * sin(_time * 21.7 + 0.6)
		_flame.scale = Vector3(1.0, flicker, 1.0)
	if _cone_material != null:
		_cone_material.albedo_color.a = 0.075 + 0.012 * sin(_time * 0.9)
	_update_clock()


func _update_clock() -> void:
	if not is_instance_valid(_minute_hand):
		return
	var seconds := clock_override
	if seconds < 0.0:
		var now := Time.get_time_dict_from_system()
		seconds = float(now.hour) * 3600.0 + float(now.minute) * 60.0 + float(now.second)
	var minute := fmod(seconds / 60.0, 60.0)
	var hour := fmod(seconds / 3600.0, 12.0)
	# Zeiger drehen um die Blickachse der Uhr (lokal +Z), im Uhrzeigersinn.
	_minute_hand.rotation.z = -TAU * minute / 60.0
	_hour_hand.rotation.z = -TAU * hour / 12.0
	if is_instance_valid(_pendulum):
		_pendulum.rotation.z = 0.16 * sin(_time * PI)


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


## Stellt ein Möbelstück an die Wand bzw. in den Raum; +Z des Möbels schaut zur Mitte.
func place(name: String, angle_degrees: float, radius: float, height: float = 0.0, scale_by: float = 1.0) -> Node3D:
	var node := KIT.prop(name)
	if node == null:
		return null
	node.position = polar(angle_degrees, radius, height)
	node.rotation.y = deg_to_rad(angle_degrees) + PI
	node.scale = Vector3.ONE * scale_by
	add_child(node)
	return node


# --------------------------------------------------------------------- Himmel


func _build_sky() -> void:
	# Der Himmel hängt an der Kamera und füllt immer das ganze Bild; sichtbar
	# bleibt er nur durch das Rundbogenfenster.
	_sky = MeshInstance3D.new()
	_sky.name = "NightSky"
	var quad := QuadMesh.new()
	quad.size = Vector2(160, 160)
	_sky.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = load(SKY_SHADER)
	material.set_shader_parameter("cloud_amount", 0.0 if quality == "low" else 1.0)
	_sky.material_override = material
	_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sky.extra_cull_margin = 1000.0
	# Ferne Baumkronen als dunkle Schattenrisse, dazwischen Laternenlichter.
	var far_tree := mat("far_tree", Color("142a3a"), 1.0)
	far_tree.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var near_tree := mat("near_tree", Color("0d222c"), 1.0)
	near_tree.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in range(18):
		var x := -9.0 + index * 1.05 + sin(index * 2.4) * 0.4
		var size := 2.0 + 1.1 * absf(sin(index * 1.7))
		ball(Vector3(x, 0.4 + size * 0.3, -12.5 - absf(sin(index * 0.9)) * 1.5), size, far_tree, Vector3(1.0, 1.25, 0.6))
	for index in range(10):
		var x := -6.5 + index * 1.4 + cos(index * 1.9) * 0.5
		var size := 1.4 + 0.8 * absf(cos(index * 2.3))
		ball(Vector3(x, -0.2 + size * 0.3, -8.6 - absf(cos(index * 1.3))), size, near_tree, Vector3(1.0, 1.3, 0.6))
	var warm := glowing("far_lantern_warm", Color("ffc66b"), 3.2)
	var cool := glowing("far_lantern_cool", Color("7fe3ff"), 2.6)
	for index in range(14):
		var x := -5.5 + index * 0.85 + sin(index * 3.1) * 0.3
		var y := 1.4 + 1.4 * absf(sin(index * 1.37))
		ball(Vector3(x, y, -7.8 - absf(sin(index * 2.2)) * 2.5), 0.07 + 0.025 * (index % 3), warm if index % 3 != 0 else cool)


# -------------------------------------------------------------- Baumhaus-Hülle


## Gebogene Wand aus Bretterstreifen. Im Fenster bleibt der Bogen offen.
func _wall_mesh(radius: float, height: float, from_deg: float, to_deg: float, cut_window: bool) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 1.0 if cut_window else 3.0
	var angle := from_deg
	while angle < to_deg - 0.001:
		var next := minf(angle + step, to_deg)
		var spans: Array = [[0.0, height]]
		var middle := (angle + next) * 0.5
		var off := absf(180.0 - middle)
		if cut_window and off < WINDOW_HALF:
			var x := WALL_RADIUS * sin(deg_to_rad(off))
			var half := WINDOW_WIDTH * 0.5 + 0.02
			var spring := WINDOW_BASE + WINDOW_HEIGHT - half
			var top := WINDOW_BASE + 0.4
			if x < half:
				top = spring + sqrt(maxf(0.0, half * half - x * x))
			spans = [[0.0, WINDOW_BASE + 0.4], [top, height]]
		for span: Array in spans:
			var y0: float = span[0]
			var y1: float = span[1]
			var a := polar(angle, radius)
			var b := polar(next, radius)
			var na := -a.normalized()
			var nb := -b.normalized()
			var quad := [[a, y0, na], [b, y0, nb], [b, y1, nb], [a, y0, na], [b, y1, nb], [a, y1, na]]
			for corner: Array in quad:
				var p: Vector3 = corner[0]
				tool.set_normal(corner[2])
				tool.add_vertex(Vector3(p.x, corner[1], p.z))
		angle = next
	return tool.commit()


func _build_shell() -> void:
	var wall := KIT.material("wall")
	var walnut := KIT.material("walnut")
	var oak := KIT.material("oak")
	# Boden: Dielen mit Fugen, Maserung und Normal-Map.
	var ground := MeshInstance3D.new()
	ground.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 24)
	ground.mesh = plane
	var floor_material: StandardMaterial3D = KIT.material("floor")
	floor_material.uv1_scale = Vector3(8, 8, 1)
	ground.material_override = floor_material
	add_child(ground)
	# Bretterwand im Rund, hinten mit Rundbogenfenster.
	var wall_node := MeshInstance3D.new()
	wall_node.name = "Wall"
	wall_node.mesh = _wall_mesh(WALL_RADIUS, WALL_HEIGHT, OPEN_FRONT, 360.0 - OPEN_FRONT, true)
	wall_node.material_override = wall
	add_child(wall_node)
	# Sockelleiste und Ringbalken.
	var skirting := MeshInstance3D.new()
	skirting.name = "Skirting"
	skirting.mesh = _wall_mesh(WALL_RADIUS - 0.04, 0.14, OPEN_FRONT, 360.0 - OPEN_FRONT, false)
	skirting.material_override = walnut
	add_child(skirting)
	var angle := OPEN_FRONT + 3.0
	while angle <= 360.0 - OPEN_FRONT - 3.0:
		box(polar(angle, WALL_RADIUS - 0.12, WALL_HEIGHT - 0.12), Vector3(0.52, 0.24, 0.26), oak, Vector3(0, deg_to_rad(angle), 0))
		angle += 6.0
	# Senkrechte Pfosten gliedern die Wand.
	for post_angle: float in [OPEN_FRONT + 1.0, 100.0, 140.0, 220.0, 260.0, 359.0 - OPEN_FRONT]:
		box(polar(post_angle, WALL_RADIUS - 0.1, WALL_HEIGHT * 0.5), Vector3(0.22, WALL_HEIGHT, 0.2), walnut, Vector3(0, deg_to_rad(post_angle), 0))
	# Dach: flacher Kegel aus Brettern, Sparren laufen zur Lampe.
	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.4
	cone.bottom_radius = WALL_RADIUS + 0.3
	cone.height = 1.5
	cone.radial_segments = 40
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	roof.mesh = cone
	var roof_material := wall.duplicate() as StandardMaterial3D
	roof_material.albedo_color = Color(0.62, 0.52, 0.48)
	# Nur die Innenseite zeichnen: die Kamera schaut von vorn über den
	# Dachrand hinein, die nahe Dachhälfte darf das Bild nicht verdecken.
	roof_material.cull_mode = BaseMaterial3D.CULL_FRONT
	roof.material_override = roof_material
	roof.position.y = WALL_HEIGHT + 0.7
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(roof)
	for index in range(8):
		var a := 22.5 + index * 45.0
		var middle := polar(a, WALL_RADIUS * 0.5, WALL_HEIGHT + 0.68)
		box(middle, Vector3(0.14, 0.18, WALL_RADIUS * 1.04), walnut, Vector3(deg_to_rad(-17.0), deg_to_rad(a), 0))


# ----------------------------------------------------------------------- Tisch


func _build_table() -> void:
	var table := KIT.prop("table")
	if table != null:
		table.name = "Table"
		add_child(table)
		table_glow_material = KIT.material("felt").duplicate()
		for instance: Node in table.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := instance as MeshInstance3D
			for surface in range(mesh_node.mesh.get_surface_count()):
				if mesh_node.get_surface_override_material(surface) == KIT.material("felt"):
					mesh_node.set_surface_override_material(surface, table_glow_material)
	else:
		# Ohne Modell: schlichte Scheibe, damit der Tisch spielbar bleibt.
		var top := cylinder(Vector3(0, TABLE_Y - 0.03, 0), TABLE_RADIUS, TABLE_RADIUS, 0.06, KIT.material("felt"), 48)
		top.name = "TableTop"
		table_glow_material = KIT.material("felt")
	# Teppich unter dem Tisch.
	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	var quad := QuadMesh.new()
	quad.size = Vector2(5.8, 5.8)
	quad.orientation = PlaneMesh.FACE_Y
	rug.mesh = quad
	rug.material_override = KIT.material("rug")
	rug.position.y = 0.006
	rug.rotation.y = 0.3
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rug)


## Sitzplatz für eine Figur; `tint` ist die Kissenfarbe. Mit `backrest`
## ein Stuhl, sonst ein runder Hocker (Lumo vorn, damit nichts ihn verdeckt).
func add_stool(angle_degrees: float, tint: Color, radius: float = SEAT_RADIUS, backrest: bool = true, lift: float = 0.0) -> Node3D:
	var seat: Node3D = KIT.prop("chair") if backrest else null
	var cushion_color := tint.lerp(Color("23306a"), 0.3)
	if seat == null:
		seat = Node3D.new()
		var log_mesh := MeshInstance3D.new()
		var body := CylinderMesh.new()
		body.top_radius = 0.3
		body.bottom_radius = 0.34
		body.height = STOOL_HEIGHT - 0.1
		body.radial_segments = 20
		log_mesh.mesh = body
		log_mesh.material_override = KIT.material("oak")
		log_mesh.position.y = (STOOL_HEIGHT - 0.1) * 0.5
		seat.add_child(log_mesh)
		var cushion := MeshInstance3D.new()
		var pad := CylinderMesh.new()
		pad.top_radius = 0.27
		pad.bottom_radius = 0.31
		pad.height = 0.1 + lift
		pad.radial_segments = 20
		cushion.mesh = pad
		cushion.material_override = _cushion(cushion_color)
		cushion.position.y = STOOL_HEIGHT - 0.05 + lift * 0.5
		seat.add_child(cushion)
	else:
		for instance: Node in seat.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := instance as MeshInstance3D
			for surface in range(mesh_node.mesh.get_surface_count()):
				if mesh_node.get_surface_override_material(surface) == KIT.material("cushion"):
					mesh_node.set_surface_override_material(surface, _cushion(cushion_color))
	seat.name = "Stool"
	seat.position = polar(angle_degrees, radius + 0.04)
	seat.rotation.y = deg_to_rad(angle_degrees)
	add_child(seat)
	_stools.append(seat)
	return seat


func _cushion(color: Color) -> StandardMaterial3D:
	var key := "cushion_" + color.to_html(false)
	if _materials.has(key):
		return _materials[key]
	var material := (KIT.material("cushion") as StandardMaterial3D).duplicate() as StandardMaterial3D
	material.resource_name = key
	material.albedo_color = color
	_materials[key] = material
	return material


func clear_stools() -> void:
	for stool: Node3D in _stools:
		stool.queue_free()
	_stools.clear()


# ---------------------------------------------------------------------- Möbel


func _build_furniture() -> void:
	place("shelf", -100.0, WALL_RADIUS - 0.32)
	place("shelf", 100.0, WALL_RADIUS - 0.32)
	var window := place("window", 180.0, WALL_RADIUS * cos(deg_to_rad(WINDOW_HALF)) - 0.02, WINDOW_BASE)
	if window != null:
		_flame = window.find_child("Flame", true, false) as Node3D
	var clock := place("clock", -136.0, WALL_RADIUS - 0.1, 2.75)
	if clock != null:
		_hour_hand = clock.find_child("HourHand", true, false) as Node3D
		_minute_hand = clock.find_child("MinuteHand", true, false) as Node3D
		_pendulum = clock.find_child("Pendulum", true, false) as Node3D
	_scoreboard = place("scoreboard", 136.0, WALL_RADIUS - 0.08, 1.55)
	if _scoreboard != null:
		_build_board_text()
	if quality != "low":
		place("plant", -70.0, WALL_RADIUS - 0.75, 0.0, 1.2)
		place("plant", 72.0, WALL_RADIUS - 0.8, 0.0, 1.0)
		place("plant", 160.0, WALL_RADIUS - 0.9, 0.0, 0.8)
	_lamp = KIT.prop("lamp")
	if _lamp != null:
		_lamp.position = Vector3(0, LAMP_Y, 0.15)
		_lamp.scale = Vector3.ONE * 0.85
		add_child(_lamp)
		# Kette bis zum Dachfirst.
		var chain_length := WALL_HEIGHT + 1.4 - LAMP_Y - 0.8
		var chain := cylinder(Vector3(0, 0.95 + chain_length * 0.5, 0), 0.01, 0.01, chain_length, KIT.material("brass"), 6)
		remove_child(chain)
		_lamp.add_child(chain)
	_build_snacks()


## Kakao, Kekse und Saft am Tischrand – dort, wo keine Karten liegen.
func _build_snacks() -> void:
	var snacks := KIT.prop("snacks")
	if snacks == null:
		return
	for entry: Array in [["Mug", -54.0, 1.07, 0.4], ["CookiePlate", 90.0, 1.02, 0.0], ["JuiceGlass", -38.0, 1.1, 0.0]]:
		var part := snacks.find_child(str(entry[0]), true, false) as Node3D
		if part == null:
			continue
		var holder := Node3D.new()
		holder.name = str(entry[0])
		holder.position = polar(entry[1], entry[2], TABLE_Y - 0.004)
		holder.rotation.y = float(entry[3]) + deg_to_rad(entry[1])
		add_child(holder)
		part.owner = null
		part.get_parent().remove_child(part)
		part.transform = Transform3D.IDENTITY
		holder.add_child(part)
	snacks.queue_free()


func _build_board_text() -> void:
	_board_title = Label3D.new()
	_board_title.name = "BoardTitle"
	_board_title.text = "Sternenrunde"
	_board_title.font_size = 64
	_board_title.pixel_size = 0.0016
	_board_title.modulate = Color(1.0, 0.93, 0.7, 0.92)
	_board_title.outline_size = 0
	_board_title.shaded = false
	_board_title.position = Vector3(0, 0.66, 0.012)
	_scoreboard.add_child(_board_title)
	_board_label = Label3D.new()
	_board_label.name = "BoardScores"
	_board_label.font_size = 52
	_board_label.pixel_size = 0.0016
	_board_label.modulate = Color(0.95, 0.96, 0.92, 0.88)
	_board_label.outline_size = 0
	_board_label.line_spacing = 6.0
	_board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_board_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_board_label.width = 600.0
	_board_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_board_label.shaded = false
	_board_label.position = Vector3(0.0, 0.56, 0.012)
	_scoreboard.add_child(_board_label)
	set_scoreboard("", [])


## Kreidetafel: Spieltitel und echte Zeilen („Name ····· Wert“).
func set_scoreboard(title: String, rows: Array) -> void:
	if _board_label == null:
		return
	_board_title.text = title if not title.is_empty() else "Lumos Spielabend"
	var lines: PackedStringArray = []
	for row: Array in rows:
		var name := str(row[0])
		var value := str(row[1])
		lines.append("%s %s %s" % [name, ".".repeat(maxi(2, 16 - name.length() - value.length())), value])
	_board_label.text = "\n".join(lines) if not lines.is_empty() else "Wer mag mitspielen?"


# --------------------------------------------------------------------- Details


func _build_details() -> void:
	var trim := KIT.material("oak")
	# Lichterketten in weiten Bögen unter dem Ringbalken.
	var bulbs := [glowing("bulb_warm", Color("ffcf7a"), 2.6), glowing("bulb_cyan", Color("7fe3ff"), 2.2), glowing("bulb_rose", Color("ff9fc0"), 2.0)]
	for chain in range(5):
		var a0 := 66.0 + chain * 45.6
		var a1 := a0 + 45.6
		for index in range(13):
			var t := float(index) / 12.0
			var a := lerpf(a0, a1, t)
			var sag := 0.45 * sin(t * PI)
			ball(polar(a, WALL_RADIUS - 0.3, WALL_HEIGHT - 0.3 - sag), 0.04, bulbs[(index + chain) % 3])
	for bulb: StandardMaterial3D in bulbs:
		_register_lamp(bulb)
	# Wimpelkette über dem Fenster.
	var flags := [mat("flag_gold", Color("ffc94a"), 0.9), mat("flag_cyan", Color("53ddfd"), 0.9), mat("flag_rose", Color("ff7fae"), 0.9), mat("flag_violet", Color("9c7bff"), 0.9)]
	for index in range(11):
		var a := 150.0 + index * 6.0
		var drop := 0.2 * sin(float(index) / 10.0 * PI)
		box(polar(a, WALL_RADIUS - 0.35, WINDOW_BASE + WINDOW_HEIGHT + 0.45 - drop), Vector3(0.2, 0.26, 0.02), flags[index % 4], Vector3(0, deg_to_rad(a), deg_to_rad(45.0)))
	# Kleiner Wandschrank mit Spielkisten vorn rechts – dort sitzt niemand.
	var chest_at := polar(60.0, 3.2)
	box(chest_at + Vector3(0, 0.26, 0), Vector3(0.9, 0.52, 0.6), trim, Vector3(0, deg_to_rad(-30.0), 0))
	box(chest_at + Vector3(0, 0.55, 0), Vector3(0.96, 0.08, 0.66), KIT.material("walnut"), Vector3(0, deg_to_rad(-30.0), 0))
	box(chest_at + Vector3(0, 0.32, 0), Vector3(0.14, 0.18, 0.64), KIT.material("brass"), Vector3(0, deg_to_rad(-30.0), 0))
	# Kissenstapel auf dem Boden neben dem linken Regal.
	ball(polar(-74.0, 3.7, 0.12), 0.34, _cushion(Color("7d5bb5")), Vector3(1.0, 0.36, 1.0))
	ball(polar(-76.0, 3.65, 0.3), 0.28, _cushion(Color("ffc94a")), Vector3(1.0, 0.4, 1.0))
	# Ein verlorener Kartenstapel und ein Würfel unter dem Regal – Kleinkram zum Entdecken.
	var die := mat("die", Color("f4efe4"), 0.4)
	box(polar(108.0, 3.9, 0.05), Vector3(0.1, 0.1, 0.1), die, Vector3(0.0, 0.5, 0.0))
	var pip := mat("pip", Color("27304f"), 0.6)
	ball(polar(108.0, 3.9, 0.101), 0.012, pip)


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
	environment.ambient_light_color = Color("7c6fb8")
	environment.ambient_light_energy = 0.42
	# Der PerformanceManager schaltet Nebel je Profil; hier ist er nur ein Hauch.
	environment.fog_enabled = true
	environment.fog_light_color = Color("2a1f3e")
	environment.fog_density = 0.008
	environment.fog_sky_affect = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.08
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.1
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.1
	environment.adjustment_contrast = 1.06
	if quality == "high":
		environment.ssao_enabled = true
		environment.ssao_radius = 0.6
		environment.ssao_intensity = 1.4
	world.environment = environment
	add_child(world)
	# Hängelampe über dem Tisch: die warme Hauptlichtquelle mit Schatten.
	key_light = SpotLight3D.new()
	key_light.name = "LampLight"
	key_light.position = Vector3(0, LAMP_Y - 0.04, 0.15)
	key_light.rotation_degrees = Vector3(-90, 0, 0)
	key_light.light_color = Color("ffd9a0")
	key_light.light_energy = 3.2
	key_light.spot_range = 7.5
	key_light.spot_angle = 58.0
	key_light.spot_angle_attenuation = 1.2
	key_light.spot_attenuation = 0.7
	key_light.shadow_enabled = quality != "low"
	key_light.shadow_bias = 0.03
	key_light.shadow_normal_bias = 1.2
	key_light.shadow_blur = 2.0 if quality == "high" else 1.2
	add_child(key_light)
	# Mondlicht durchs Fenster als kühle Kante auf Köpfen und Tischrand.
	var moon := DirectionalLight3D.new()
	moon.name = "MoonLight"
	moon.rotation_degrees = Vector3(-24, 180, 0)
	moon.light_color = Color("8fb6ff")
	moon.light_energy = 0.5
	moon.shadow_enabled = false
	add_child(moon)
	# Weiches Fülllicht von vorn, damit Gesichter nicht zulaufen.
	var fill := OmniLight3D.new()
	fill.name = "FrontFill"
	fill.position = Vector3(0.0, 2.4, 3.6)
	fill.light_color = Color("ffcfa8")
	fill.light_energy = 0.7
	fill.omni_range = 7.5
	fill.omni_attenuation = 0.9
	fill.shadow_enabled = false
	add_child(fill)
	if quality != "low":
		_build_light_cone()
		_build_dust()
		_build_fireflies()


## Sichtbarer Lichtkegel unter der Lampe: additiver, weich auslaufender Mantel.
func _build_light_cone() -> void:
	var node := MeshInstance3D.new()
	node.name = "LightCone"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.26
	mesh.bottom_radius = 1.5
	mesh.height = LAMP_Y - TABLE_Y
	mesh.radial_segments = 32
	mesh.rings = 4
	mesh.cap_top = false
	mesh.cap_bottom = false
	node.mesh = mesh
	_cone_material = StandardMaterial3D.new()
	_cone_material.resource_name = "light_cone"
	_cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_cone_material.albedo_color = Color(1.0, 0.8, 0.5, 0.08)
	# Nach unten ausblenden: Abstandsblende zur Kamera hilft, dass der Mantel
	# nah vor der Linse nicht als Fläche erscheint.
	_cone_material.proximity_fade_enabled = false
	_cone_material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	_cone_material.distance_fade_min_distance = 1.2
	_cone_material.distance_fade_max_distance = 3.2
	node.material_override = _cone_material
	node.position = Vector3(0, (LAMP_Y + TABLE_Y) * 0.5, 0.15)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


## Staubteilchen schweben im Lampenlicht.
func _build_dust() -> void:
	var dust := CPUParticles3D.new()
	dust.name = "LampDust"
	dust.amount = 70 if quality == "high" else 32
	dust.lifetime = 12.0
	dust.preprocess = 12.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 0.9
	dust.position = Vector3(0, 2.25, 0.15)
	dust.scale = Vector3(1.0, 0.85, 1.0)
	dust.direction = Vector3(0, -1, 0)
	dust.spread = 180.0
	dust.gravity = Vector3(0, -0.004, 0)
	dust.initial_velocity_min = 0.005
	dust.initial_velocity_max = 0.03
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 1.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.9, 0.7, 0.0))
	gradient.add_point(0.25, Color(1, 0.9, 0.7, 1.0))
	gradient.add_point(0.75, Color(1, 0.9, 0.7, 1.0))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 0.9, 0.7, 0.0))
	dust.color_ramp = gradient
	var mote := QuadMesh.new()
	mote.size = Vector2(0.012, 0.012)
	dust.mesh = mote
	var material := StandardMaterial3D.new()
	material.resource_name = "lamp_dust"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.6, 1.4, 1.0, 0.8)
	dust.material_override = material
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)


## Glühwürmchen ziehen langsam am Fenster vorbei.
func _build_fireflies() -> void:
	var motes := CPUParticles3D.new()
	motes.name = "Fireflies"
	motes.amount = 24 if quality == "high" else 12
	motes.lifetime = 9.0
	motes.preprocess = 9.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(3.2, 1.0, 1.2)
	motes.position = Vector3(0, 2.6, -2.8)
	motes.direction = Vector3(0, 1, 0)
	motes.spread = 180.0
	motes.gravity = Vector3.ZERO
	motes.initial_velocity_min = 0.03
	motes.initial_velocity_max = 0.12
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.2
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.016
	mote_mesh.height = 0.032
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
