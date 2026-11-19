extends RefCounted
## Bauteile der Parcours-Welten: Sterne, Checkpoint-Bögen, Ziel, Schilder, Hebel, Tore,
## Aufzugsgerüst, Zahnradscheibe und die Kulissen der drei Welten. Alles prozedural,
## eigene LUMO-Formen; Kulisse als MultiMesh und mit Sichtweite für Mobilgeräte.

const MESHES = preload("res://scripts/games/parcours/parcours_meshes.gd")


static func lit(c: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func glow(c: Color, energy: float = 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func mesh_node(mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	return node


static func box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func cyl_mesh(top: float, bottom: float, height: float, sides: int = 16) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


## Fünfzackiger, gewölbter LUMO-Stern (beidseitig, etwa 1 m groß).
static func star_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer: float = 0.55
	var inner: float = 0.24
	var depth: float = 0.16
	var points: Array[Vector3] = []
	for i in range(10):
		var a: float = PI * 0.5 + TAU * i / 10.0
		var r: float = outer if i % 2 == 0 else inner
		points.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	for side in [1.0, -1.0]:
		var tip := Vector3(0, 0, depth * side)
		for i in range(10):
			var a: Vector3 = points[i]
			var b: Vector3 = points[(i + 1) % 10]
			var n: Vector3 = (b - a).cross(tip - a).normalized() * -side
			var order: Array = [a, b, tip] if side < 0.0 else [a, tip, b]
			for p in order:
				st.set_normal(n if n.length() > 0.1 else Vector3(0, 0, side))
				st.add_vertex(p)
	return st.commit()


static func checkpoint_arch(is_start: bool, accent: Color, edge: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "CheckpointArch"
	var frame := lit(Color("eef3fb"), 0.35, 0.5)
	for side in [-1.0, 1.0]:
		var post := mesh_node(cyl_mesh(0.28, 0.36, 4.6), frame, Vector3(side * 5.4, 2.3, 0))
		root.add_child(post)
		var cap := mesh_node(SphereMesh.new(), glow(edge, 1.4), Vector3(side * 5.4, 4.75, 0))
		cap.scale = Vector3.ONE * 0.55
		cap.name = "Lamp%d" % int(side)
		root.add_child(cap)
	var beam := mesh_node(box_mesh(Vector3(11.4, 0.55, 0.5)), frame, Vector3(0, 4.45, 0))
	root.add_child(beam)
	var band := mesh_node(box_mesh(Vector3(9.6, 0.62, 0.08)), glow(accent, 1.2), Vector3(0, 3.7, 0))
	band.name = "Band"
	root.add_child(band)
	var label := Label3D.new()
	label.text = "START" if is_start else "CHECKPOINT"
	label.font_size = 96
	label.pixel_size = 0.009
	label.outline_size = 18
	label.modulate = Color.WHITE
	label.position = Vector3(0, 3.7, 0.08)
	root.add_child(label)
	var back := label.duplicate() as Label3D
	back.rotation.y = PI
	back.position.z = -0.08
	root.add_child(back)
	return root


static func set_checkpoint_lit(gate: Node3D, lit_up: bool) -> void:
	var band := gate.get_node_or_null("Band") as MeshInstance3D
	if band == null:
		return
	var m := band.material_override as StandardMaterial3D
	var want: Color = Color("5cf08a") if lit_up else m.get_meta("idle", m.albedo_color)
	if not m.has_meta("idle"):
		m.set_meta("idle", m.albedo_color)
	m.albedo_color = want
	m.emission = want


static func finish_arch(accent: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "FinishArch"
	var frame := lit(Color("ffffff"), 0.3, 0.4)
	for side in [-1.0, 1.0]:
		root.add_child(mesh_node(cyl_mesh(0.42, 0.55, 6.4), frame, Vector3(side * 6.6, 3.2, 0)))
		var ball := mesh_node(SphereMesh.new(), glow(Color("ffd84a"), 2.0), Vector3(side * 6.6, 6.7, 0))
		ball.scale = Vector3.ONE * 0.9
		root.add_child(ball)
	# Schachbrettband aus kleinen Quadern.
	var dark := lit(Color("16213a"), 0.5)
	var light := lit(Color("f6f8ff"), 0.5)
	for i in range(18):
		for row in range(2):
			var tile := mesh_node(
				box_mesh(Vector3(0.72, 0.5, 0.3)), dark if (i + row) % 2 == 0 else light,
				Vector3(-6.12 + i * 0.72, 5.75 + row * 0.5, 0)
			)
			root.add_child(tile)
	var label := Label3D.new()
	label.text = "ZIEL"
	label.font_size = 180
	label.pixel_size = 0.01
	label.outline_size = 26
	label.modulate = Color("ffd84a")
	label.position = Vector3(0, 4.5, 0.2)
	root.add_child(label)
	var ring := mesh_node(TorusMesh.new(), glow(accent, 1.5), Vector3(0, 0.08, 0))
	ring.scale = Vector3(7.0, 1.0, 3.0)
	(ring.mesh as TorusMesh).inner_radius = 0.92
	(ring.mesh as TorusMesh).outer_radius = 1.0
	root.add_child(ring)
	return root


## Holo-Schild vor einer Geschicklichkeitsstelle (Ankündigung).
static func skill_sign(text: String, accent: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "SkillSign"
	root.add_child(mesh_node(cyl_mesh(0.09, 0.12, 3.2), lit(Color("d8e2f0"), 0.4, 0.6), Vector3(0, -0.9, 0)))
	var plate := mesh_node(box_mesh(Vector3(3.6, 1.0, 0.12)), lit(Color("0e2240"), 0.3, 0.3), Vector3(0, 0.8, 0))
	root.add_child(plate)
	var rim := mesh_node(box_mesh(Vector3(3.8, 1.18, 0.06)), glow(accent, 1.4), Vector3(0, 0.8, -0.05))
	root.add_child(rim)
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.0075
	label.outline_size = 10
	label.width = 440
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector3(0, 0.8, 0.08)
	root.add_child(label)
	return root


static func station_marker(accent: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "StationMarker"
	var ring := mesh_node(TorusMesh.new(), glow(accent, 1.8), Vector3(0, 0.06, 0))
	(ring.mesh as TorusMesh).inner_radius = 2.6
	(ring.mesh as TorusMesh).outer_radius = 2.9
	root.add_child(ring)
	var label := Label3D.new()
	label.text = "AUSSTEIGEN"
	label.font_size = 72
	label.pixel_size = 0.008
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.6, 0)
	root.add_child(label)
	return root


static func lever(accent: Color) -> Node3D:
	var root := Node3D.new()
	root.add_child(mesh_node(box_mesh(Vector3(1.4, 0.9, 1.0)), lit(Color("39465c"), 0.5, 0.6), Vector3(0, 0.45, 0)))
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = Vector3(0, 0.95, 0)
	arm.rotation.x = -0.7
	root.add_child(arm)
	arm.add_child(mesh_node(cyl_mesh(0.07, 0.07, 1.3), lit(Color("d0d8e6"), 0.3, 0.8), Vector3(0, 0.65, 0)))
	var knob := mesh_node(SphereMesh.new(), glow(accent, 1.6), Vector3(0, 1.35, 0))
	knob.scale = Vector3.ONE * 0.36
	arm.add_child(knob)
	var label := Label3D.new()
	label.text = "HEBEL"
	label.font_size = 64
	label.pixel_size = 0.008
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.9, 0)
	label.name = "Label"
	root.add_child(label)
	return root


static func set_lever(node: Node3D, on: bool) -> void:
	var arm := node.get_node_or_null("Arm") as Node3D
	if arm != null:
		arm.rotation.x = lerpf(arm.rotation.x, 0.7 if on else -0.7, 0.2)
	var label := node.get_node_or_null("Label") as Label3D
	if label != null:
		label.visible = not on


static func blocker_visual(blocker: Dictionary, materials: Dictionary, accent: Color) -> Node3D:
	var size: Vector3 = blocker.size
	match str(blocker.get("style", "")):
		"gate":
			var root := Node3D.new()
			root.name = "Gate"
			for side in [-1.0, 1.0]:
				root.add_child(mesh_node(box_mesh(Vector3(0.4, 2.6, 0.4)), materials.frame, Vector3(side * (size.x * 0.5 + 0.2), 1.3, 0)))
			var bar := Node3D.new()
			bar.name = "Bar"
			root.add_child(bar)
			for i in range(int(size.x / 1.1)):
				var piece := mesh_node(
					box_mesh(Vector3(1.1, 0.42, 0.26)), lit(Color("e8413c") if i % 2 == 0 else Color("f6f6f6"), 0.4),
					Vector3(-size.x * 0.5 + 0.55 + i * 1.1, 1.0, 0)
				)
				bar.add_child(piece)
			for side in [-1.0, 1.0]:
				var lamp := mesh_node(SphereMesh.new(), glow(Color("ff4038"), 2.4), Vector3(side * (size.x * 0.5 + 0.2), 2.85, 0))
				lamp.name = "Lamp" + ("L" if side < 0.0 else "R")
				lamp.scale = Vector3.ONE * 0.5
				root.add_child(lamp)
			return root
		"gear_post":
			var post := Node3D.new()
			post.name = "GearPost"
			post.add_child(mesh_node(cyl_mesh(size.x, size.x, size.y, 14), lit(Color("ffb13b"), 0.35, 0.6), Vector3(0, size.y * 0.5, 0)))
			var crown := mesh_node(TorusMesh.new(), glow(accent, 1.2), Vector3(0, size.y + 0.05, 0))
			(crown.mesh as TorusMesh).inner_radius = size.x * 0.6
			(crown.mesh as TorusMesh).outer_radius = size.x * 1.2
			post.add_child(crown)
			return post
		"pendulum", "hammer":
			var root := Node3D.new()
			root.name = "Hammer"
			root.add_child(mesh_node(box_mesh(size), lit(Color(blocker.get("color", Color("7fd8ff"))), 0.2, 0.2), Vector3(0, size.y * 0.5, 0)))
			return root
		"block":
			var root := Node3D.new()
			root.add_child(mesh_node(box_mesh(size), lit(Color(blocker.get("color", Color("9fe6ff"))), 0.15, 0.1), Vector3(0, size.y * 0.5, 0)))
			return root
		"vine_gate":
			var root := Node3D.new()
			root.name = "VineGate"
			var bar := Node3D.new()
			bar.name = "Bar"
			root.add_child(bar)
			var vine := lit(Color("2f7a35"), 0.8)
			for i in range(int(size.x / 0.7)):
				var strand := mesh_node(cyl_mesh(0.12, 0.16, size.y + 1.0, 6), vine, Vector3(-size.x * 0.5 + 0.35 + i * 0.7, size.y * 0.5 + 0.5, 0))
				bar.add_child(strand)
			return root
	return null


static func set_gate_open(node: Node3D, open: bool) -> void:
	var bar := node.get_node_or_null("Bar") as Node3D
	if bar != null:
		var target: float = 3.6 if open else 0.0
		bar.position.y = lerpf(bar.position.y, target, 0.15)
		bar.visible = bar.position.y < 3.4
	for lamp_name in ["LampL", "LampR"]:
		var lamp := node.get_node_or_null(lamp_name) as MeshInstance3D
		if lamp != null:
			var m := lamp.material_override as StandardMaterial3D
			var c: Color = Color("49f07a") if open else Color("ff4038")
			m.albedo_color = c
			m.emission = c
	if node.name == "Hammer" or node.name == "GearPost":
		node.visible = true


## Zähne am Rand der Drehscheibe (in die Fläche der Scheibe gebaut).
static func disc_teeth(target, slab: Dictionary) -> void:
	var radius: float = float(slab.radius) + float(slab.width) * 0.5
	var y: float = float(slab.y0)
	for i in range(24):
		var a: float = TAU * i / 24.0
		var dir := Vector3(cos(a), 0, sin(a))
		var basis := Basis.looking_at(dir, Vector3.UP)
		target.box("teeth", dir * (radius + 0.35) + Vector3.UP * (y - 0.45), Vector3(1.0, 0.6, 0.7), basis)
	target.cylinder("teeth", Vector3(0, y - 3.5, 0), Vector3(0, y - 0.7, 0), 1.2, 2.2, 16)


## Gelb-schwarze Kante und Schienen am Aufzug (bewegt sich mit).
static func lift_cage(target, slab: Dictionary) -> void:
	var width: float = float(slab.width)
	var length: float = float(slab.length)
	for side in [-1.0, 1.0]:
		target.box("frame", Vector3(side * (width * 0.5 + 0.3), -0.4, -length * 0.5), Vector3(0.3, 0.8, length))


## Feststehendes Aufzugsgerüst: vier Säulen bis zur oberen Ebene.
static func lift_tower(parent: Node3D, course, slab: Dictionary, materials: Dictionary) -> void:
	var motion: Dictionary = slab.motion
	var height: float = float(motion.get("height", 10.0))
	var base: Transform3D = slab.base
	var width: float = float(slab.width)
	var length: float = float(slab.length)
	var target = MESHES.new()
	target.xform = base
	for x in [-1.0, 1.0]:
		for z in [0.0, -1.0]:
			var p := Vector3(x * (width * 0.5 + 0.75), 0.0, z * length)
			target.cylinder("frame", p + Vector3.DOWN * 6.0, p + Vector3.UP * (height + 3.0), 0.32, 0.26, 10)
		target.box("frame", Vector3(x * (width * 0.5 + 0.75), height + 3.0, -length * 0.5), Vector3(0.4, 0.4, length))
	target.box("accent", Vector3(0, height + 3.2, -length * 0.5), Vector3(width + 1.9, 0.5, 0.5))
	var node := MeshInstance3D.new()
	node.name = "LiftTower"
	node.mesh = target.commit(materials)
	parent.add_child(node)


## Kleine Schwebedüsen unter einer Schwebeplattform (leuchten, bewegen sich mit).
static func float_jets(node: Node3D, slab: Dictionary, color: Color) -> void:
	var length: float = float(slab.length)
	var width: float = float(slab.width)
	var jet_material := glow(color, 2.2)
	for x in [-0.32, 0.32]:
		for z in [0.25, 0.75]:
			var jet := mesh_node(cyl_mesh(0.55, 0.2, 0.5, 12), jet_material, Vector3(x * width, -0.95, -z * length))
			jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(jet)


## Kulisse je Welt aus `course.scenery`.
static func scenery(parent: Node3D, course, lightweight: bool) -> void:
	var clouds: Array[Transform3D] = []
	var rocks: Array[Dictionary] = []
	var gears: Array[Dictionary] = []
	for item in course.scenery:
		match str(item.kind):
			"cloud":
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(item.pos)
				var size: float = float(item.size)
				for k in range(5 if not lightweight else 3):
					var offset := Vector3(rng.randf_range(-1, 1) * size, rng.randf_range(-0.2, 0.3) * size * 0.4, rng.randf_range(-1, 1) * size * 0.6)
					var s: float = size * rng.randf_range(0.45, 0.8)
					clouds.append(Transform3D(Basis().scaled(Vector3(s, s * 0.55, s)), (item.pos as Vector3) + offset))
			"island":
				rocks.append(item)
			"gear":
				gears.append(item)
	if not clouds.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var sphere := SphereMesh.new()
		sphere.radial_segments = 16
		sphere.rings = 8
		mm.mesh = sphere
		mm.instance_count = clouds.size()
		for i in range(clouds.size()):
			mm.set_instance_transform(i, clouds[i])
		var node := MultiMeshInstance3D.new()
		node.name = "Clouds"
		node.multimesh = mm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(course.theme.get("cloud", Color.WHITE))
		m.roughness = 1.0
		m.emission_enabled = true
		m.emission = Color(course.theme.get("cloud", Color.WHITE)) * 0.35
		node.material_override = m
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
	for item in rocks:
		var island := Node3D.new()
		island.name = "SkyIsland"
		island.position = item.pos
		var size: float = float(item.size)
		var rock := mesh_node(cyl_mesh(size, size * 0.15, size * 1.4, 9), lit(Color(course.theme.get("rock", Color("8d7a6b"))), 0.9), Vector3(0, -size * 0.7, 0))
		island.add_child(rock)
		var grass := mesh_node(cyl_mesh(size * 1.02, size * 1.02, size * 0.18, 9), lit(Color(course.theme.get("grass", Color("79c66a"))), 0.9), Vector3(0, 0.05, 0))
		island.add_child(grass)
		for k in range(3):
			var tree := mesh_node(SphereMesh.new(), lit(Color(course.theme.get("tree", Color("3f9a52"))), 0.9), Vector3(cos(k * 2.1) * size * 0.5, size * 0.35, sin(k * 2.1) * size * 0.5))
			tree.scale = Vector3.ONE * size * 0.35
			island.add_child(tree)
		for child in island.get_children():
			(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(child as GeometryInstance3D).visibility_range_end = 480.0
		parent.add_child(island)
	for item in gears:
		var gear := Node3D.new()
		gear.name = "SkyGear"
		gear.position = item.pos
		gear.rotation = Vector3(PI * 0.5, randf() * TAU, 0)
		var size: float = float(item.size)
		var ring := mesh_node(TorusMesh.new(), lit(Color(course.theme.get("gear", Color("d9a84a"))), 0.35, 0.8))
		(ring.mesh as TorusMesh).inner_radius = size * 0.7
		(ring.mesh as TorusMesh).outer_radius = size
		gear.add_child(ring)
		for k in range(12):
			var a: float = TAU * k / 12.0
			var tooth := mesh_node(box_mesh(Vector3(size * 0.22, size * 0.22, size * 0.3)), ring.material_override, Vector3(cos(a) * size * 1.05, sin(a) * size * 1.05, 0))
			tooth.rotation.z = a
			gear.add_child(tooth)
		for child in gear.get_children():
			(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(gear)
		parent.animated.append({"kind": "spin", "node": gear, "axis": Vector3(0, 0, 1), "speed": 0.15})
