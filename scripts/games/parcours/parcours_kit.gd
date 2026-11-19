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


static func sphere_mesh(radius: float = 0.5, segments: int = 12) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(4, segments / 2)
	return mesh


static func torus_mesh(inner: float, outer: float, rings: int = 32, sides: int = 8) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = rings
	mesh.ring_segments = sides
	return mesh


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
	var parts = MESHES.new()
	for side in [-1.0, 1.0]:
		parts.cylinder("frame", Vector3(side * 6.4, -0.2, 0), Vector3(side * 6.4, 6.6, 0), 0.34, 0.26, 12)
		parts.box("frame", Vector3(side * 6.4, 0.15, 0), Vector3(1.1, 0.3, 1.1))
	parts.box("frame", Vector3(0, 6.75, 0), Vector3(13.4, 0.5, 0.55))
	var frame := MeshInstance3D.new()
	frame.mesh = parts.commit({"frame": lit(Color("eef3fb"), 0.35, 0.5)})
	root.add_child(frame)
	var band := mesh_node(box_mesh(Vector3(11.0, 0.7, 0.12)), glow(accent, 1.2), Vector3(0, 6.05, 0))
	band.name = "Band"
	root.add_child(band)
	for side in [-1.0, 1.0]:
		var cap := mesh_node(sphere_mesh(0.32), glow(edge, 1.4), Vector3(side * 6.4, 7.1, 0))
		root.add_child(cap)
	for flip in [0.0, PI]:
		var label := Label3D.new()
		label.text = "START" if is_start else "CHECKPOINT"
		label.font_size = 64
		label.pixel_size = 0.007
		label.outline_size = 12
		label.position = Vector3(0, 6.05, 0.08 if flip == 0.0 else -0.08)
		label.rotation.y = flip
		root.add_child(label)
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
	var parts = MESHES.new()
	for side in [-1.0, 1.0]:
		parts.cylinder("frame", Vector3(side * 7.2, -0.2, 0), Vector3(side * 7.2, 7.4, 0), 0.5, 0.4, 12)
	for i in range(20):
		for row in range(2):
			var key: String = "dark" if (i + row) % 2 == 0 else "light"
			parts.box(key, Vector3(-6.84 + i * 0.72, 6.9 + row * 0.5, 0), Vector3(0.72, 0.5, 0.3))
	var frame := MeshInstance3D.new()
	frame.mesh = parts.commit({
		"frame": lit(Color("ffffff"), 0.3, 0.4), "dark": lit(Color("16213a"), 0.5),
		"light": lit(Color("f6f8ff"), 0.5)
	})
	root.add_child(frame)
	for side in [-1.0, 1.0]:
		root.add_child(mesh_node(sphere_mesh(0.5), glow(Color("ffd84a"), 2.0), Vector3(side * 7.2, 7.8, 0)))
	for flip in [0.0, PI]:
		var label := Label3D.new()
		label.text = "ZIEL"
		label.font_size = 128
		label.pixel_size = 0.009
		label.outline_size = 20
		label.modulate = Color("ffd84a")
		label.position = Vector3(0, 5.6, 0.2 if flip == 0.0 else -0.2)
		label.rotation.y = flip
		root.add_child(label)
	var ring := mesh_node(torus_mesh(0.92, 1.0, 48, 4), glow(accent, 1.5), Vector3(0, 0.08, 0))
	ring.scale = Vector3(7.0, 1.0, 3.0)
	root.add_child(ring)
	return root


## Holo-Schild vor einer Geschicklichkeitsstelle (Ankündigung).
static func skill_sign(text: String, accent: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "SkillSign"
	root.add_child(mesh_node(cyl_mesh(0.09, 0.12, 3.2), lit(Color("d8e2f0"), 0.4, 0.6), Vector3(0, -0.9, 0)))
	var plate := mesh_node(box_mesh(Vector3(4.8, 1.2, 0.12)), lit(Color("0e2240"), 0.3, 0.3), Vector3(0, 0.8, 0))
	root.add_child(plate)
	var rim := mesh_node(box_mesh(Vector3(5.0, 1.38, 0.06)), glow(accent, 1.4), Vector3(0, 0.8, -0.05))
	root.add_child(rim)
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.0075
	label.outline_size = 10
	label.width = 620
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector3(0, 0.8, 0.08)
	root.add_child(label)
	return root


static func station_marker(accent: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "StationMarker"
	var ring := mesh_node(torus_mesh(2.6, 2.9, 40, 4), glow(accent, 1.8), Vector3(0, 0.06, 0))
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
	var knob := mesh_node(sphere_mesh(), glow(accent, 1.6), Vector3(0, 1.35, 0))
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
				var lamp := mesh_node(sphere_mesh(), glow(Color("ff4038"), 2.4), Vector3(side * (size.x * 0.5 + 0.2), 2.85, 0))
				lamp.name = "Lamp" + ("L" if side < 0.0 else "R")
				lamp.scale = Vector3.ONE * 0.5
				root.add_child(lamp)
			# Rätseltor: farbige Lampen zeigen die Reihenfolge der Hebel (links nach rechts).
			var lamps: Array = blocker.get("lamps", [])
			if not lamps.is_empty():
				root.add_child(mesh_node(box_mesh(Vector3(size.x + 0.8, 0.5, 0.4)), materials.frame, Vector3(0, 3.1, 0)))
				for i in range(lamps.size()):
					var x: float = (float(i) - (lamps.size() - 1) * 0.5) * 1.6
					var hint := mesh_node(sphere_mesh(0.42), glow(Color(lamps[i]), 2.6), Vector3(x, 3.6, 0))
					root.add_child(hint)
					var number := Label3D.new()
					number.text = str(i + 1)
					number.font_size = 72
					number.pixel_size = 0.008
					number.outline_size = 14
					number.position = Vector3(x, 4.35, 0)
					number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
					root.add_child(number)
			return root
		"ice_gate":
			var root := Node3D.new()
			root.name = "IceGate"
			var slab_material := StandardMaterial3D.new()
			slab_material.albedo_color = Color(0.7, 0.92, 1.0, 0.72)
			slab_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			slab_material.emission_enabled = true
			slab_material.emission = Color("6fd8ff")
			slab_material.emission_energy_multiplier = 0.6
			slab_material.roughness = 0.05
			root.add_child(mesh_node(box_mesh(size), slab_material, Vector3(0, size.y * 0.5, 0)))
			root.add_child(mesh_node(box_mesh(Vector3(size.x, 0.18, size.z + 0.1)), glow(Color("bff4ff"), 1.8), Vector3(0, 0.09, 0)))
			return root
		"gear_post":
			var post := Node3D.new()
			post.name = "GearPost"
			post.add_child(mesh_node(cyl_mesh(size.x, size.x, size.y, 14), lit(Color(blocker.get("color", Color("ffb13b"))), 0.35, 0.6), Vector3(0, size.y * 0.5, 0)))
			var crown := mesh_node(torus_mesh(size.x * 0.6, size.x * 1.2, 20, 6), glow(accent, 1.2), Vector3(0, size.y + 0.05, 0))
			post.add_child(crown)
			return post
		"pendulum", "hammer":
			var root := Node3D.new()
			root.name = "Hammer"
			root.add_child(mesh_node(box_mesh(size), lit(Color(blocker.get("color", Color("7fd8ff"))), 0.2, 0.2), Vector3(0, size.y * 0.5, 0)))
			return root
		"block":
			var root := Node3D.new()
			root.name = "IceBlock"
			var ice := lit(Color(blocker.get("color", Color("a9e9ff"))), 0.08, 0.0)
			ice.emission_enabled = true
			ice.emission = Color("4fc3ff")
			ice.emission_energy_multiplier = 0.35
			root.add_child(mesh_node(box_mesh(size), ice, Vector3(0, size.y * 0.5, 0)))
			var face := Label3D.new()
			face.text = "◆"
			face.font_size = 96
			face.pixel_size = 0.01
			face.modulate = Color("e9fbff")
			face.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			face.position = Vector3(0, size.y + 0.5, 0)
			root.add_child(face)
			return root
		"log":
			var root := Node3D.new()
			root.name = "StoneRoller"
			var roller := mesh_node(cyl_mesh(size.x * 0.5, size.x * 0.5, size.z, 14), lit(Color("9a8a70"), 0.85), Vector3(0, size.y * 0.5, 0))
			roller.rotation.x = PI * 0.5
			roller.name = "Roller"
			root.add_child(roller)
			for z in [-0.45, 0.45]:
				var band := mesh_node(cyl_mesh(size.x * 0.52, size.x * 0.52, 0.3, 14), lit(Color("c9a050"), 0.4, 0.6), Vector3(0, size.y * 0.5, z * size.z))
				band.rotation.x = PI * 0.5
				root.add_child(band)
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


## Kulisse nie in oder dicht an der Fahrbahn (auch nicht im Blick der Fahrerkamera).
static func clear_of_course(course, p: Vector3, size: float) -> bool:
	var probe := Vector3(p.x, 10000.0, p.z)
	for index in range(course.slabs.size()):
		if not course._near_bounds(course.slabs[index], p):
			var c: Vector3 = course.slabs[index].reach_center
			var r: float = float(course.slabs[index].reach_radius) + size + 8.0
			if Vector2(p.x - c.x, p.z - c.z).length() > r:
				continue
		if not course._slab_ground(index, probe, 0.0, course.mechanisms, size * 0.7 + 5.0).is_empty():
			return false
	return true


## Kulisse je Welt aus `course.scenery`.
static func scenery(parent: Node3D, course, lightweight: bool) -> void:
	var clouds: Array[Transform3D] = []
	var rocks: Array[Dictionary] = []
	var gears: Array[Dictionary] = []
	var far_items: Array[Dictionary] = []
	var floes: Array[Dictionary] = []
	var trees: Array[Dictionary] = []
	for item in course.scenery:
		if (
			str(item.kind) not in ["cloud"] and not bool(item.get("anchored", false))
			and not clear_of_course(course, item.pos, float(item.size))
		):
			continue
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
			"tower":
				_gear_tower(parent, course, item)
			"hangar":
				_hangar(parent, course, item)
			"water":
				_water(parent, course, item)
			"jungle_tree":
				trees.append(item)
			"mountain", "pine_isle", "ice_tower", "crystal_column", "pyramid", "temple_wall":
				far_items.append(item)
			"floe":
				floes.append(item)
	if not clouds.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var sphere := sphere_mesh()
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
	_far_items(parent, course, far_items)
	_jungle_trees(parent, course, trees, lightweight)
	if not floes.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = cyl_mesh(1.0, 1.1, 0.5, 9)
		mm.instance_count = floes.size()
		for i in range(floes.size()):
			var f: Dictionary = floes[i]
			var size: float = float(f.size)
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, i * 1.3).scaled(Vector3(size, 1.0, size * 0.7)), f.pos))
		var node := MultiMeshInstance3D.new()
		node.name = "IceFloes"
		node.multimesh = mm
		node.material_override = lit(Color("eaf6ff"), 0.4)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
	var far_parts = MESHES.new()
	for item in rocks:
		var size: float = float(item.size)
		var p: Vector3 = item.pos
		far_parts.cylinder("rock", p + Vector3.DOWN * size * 1.4, p, size * 0.12, size, 9)
		far_parts.cylinder("grass", p + Vector3.DOWN * 0.1, p + Vector3.UP * size * 0.16, size * 1.02, size * 0.98, 9)
		for k in range(3):
			var t: Vector3 = p + Vector3(cos(k * 2.1) * size * 0.5, size * 0.16, sin(k * 2.1) * size * 0.5)
			far_parts.cylinder("trunk", t, t + Vector3.UP * size * 0.25, size * 0.05, size * 0.04, 6)
			far_parts.cylinder("tree", t + Vector3.UP * size * 0.2, t + Vector3.UP * size * 0.75, size * 0.26, size * 0.02, 8)
	if not rocks.is_empty():
		var islands := MeshInstance3D.new()
		islands.name = "SkyIslands"
		islands.mesh = far_parts.commit({
			"rock": lit(Color(course.theme.get("rock", Color("8d7a6b"))), 0.9),
			"grass": lit(Color(course.theme.get("grass", Color("79c66a"))), 0.9),
			"trunk": lit(Color("6b4a32"), 0.9),
			"tree": lit(Color(course.theme.get("tree", Color("3f9a52"))), 0.9)
		})
		islands.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(islands)
	for item in gears:
		var gear := Node3D.new()
		gear.name = "SkyGear"
		gear.position = item.pos
		gear.rotation = Vector3(PI * 0.5, float(item.get("yaw", 0.0)), 0)
		var size: float = float(item.size)
		var parts = MESHES.new()
		for k in range(14):
			var a: float = TAU * k / 14.0
			var dir := Vector3(cos(a), sin(a), 0)
			parts.box("gear", dir * size * 1.02, Vector3(size * 0.2, size * 0.24, size * 0.26), Basis(Vector3.BACK, a))
		var ring := MeshInstance3D.new()
		ring.mesh = torus_mesh(size * 0.62, size * 0.92, 28, 6)
		var gear_material := lit(Color(course.theme.get("gear", Color("d9a84a"))), 0.35, 0.8)
		ring.material_override = gear_material
		gear.add_child(ring)
		var teeth := MeshInstance3D.new()
		teeth.mesh = parts.commit({"gear": gear_material})
		gear.add_child(teeth)
		for child in gear.get_children():
			(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(gear)
		parent.animated.append({"kind": "spin", "node": gear, "axis": Vector3(0, 0, 1), "speed": 0.15})


## Großer Zahnradturm (Mitte der Spirale): Säule, Zahnkränze, Leuchtspitze.
static func _gear_tower(parent: Node3D, course, item: Dictionary) -> void:
	var p: Vector3 = item.pos
	var height: float = float(item.get("height", 40.0))
	var radius: float = float(item.size)
	var parts = MESHES.new()
	parts.cylinder("body", p + Vector3.DOWN * 30.0, p + Vector3.UP * height, radius * 1.1, radius * 0.8, 16)
	for k in range(int(height / 9.0)):
		var y: float = 4.0 + k * 9.0
		parts.cylinder("ring", p + Vector3.UP * y, p + Vector3.UP * (y + 1.2), radius * 1.35, radius * 1.35, 20)
		for t in range(16):
			var a: float = TAU * t / 16.0 + k * 0.2
			var dir := Vector3(cos(a), 0, sin(a))
			parts.box("ring", p + dir * radius * 1.45 + Vector3.UP * (y + 0.6), Vector3(1.0, 1.0, 0.8), Basis.looking_at(dir, Vector3.UP))
	parts.cylinder("glow", p + Vector3.UP * height, p + Vector3.UP * (height + 3.0), radius * 0.5, 0.2, 12)
	var node := MeshInstance3D.new()
	node.name = "GearTower"
	node.mesh = parts.commit({
		"body": lit(Color(course.theme.get("tower", Color("31507f"))), 0.5, 0.4),
		"ring": lit(Color(course.theme.get("gear", Color("d8a84a"))), 0.35, 0.8),
		"glow": glow(Color(course.theme.get("edge", Color("ffc23a"))), 2.0)
	})
	parent.add_child(node)


## Werkstatthalle neben dem Start: Bogendach, Fenster, Schornstein mit Ballon.
static func _hangar(parent: Node3D, course, item: Dictionary) -> void:
	var p: Vector3 = item.pos
	var yaw: float = float(item.get("yaw", 0.0))
	var size: float = float(item.size)
	var parts = MESHES.new()
	parts.xform = Transform3D(Basis(Vector3.UP, yaw), p)
	parts.box("wall", Vector3(0, size * 0.3, 0), Vector3(size * 1.4, size * 0.6, size))
	for i in range(9):
		var a0: float = PI * i / 9.0
		var a1: float = PI * (i + 1) / 9.0
		var r: float = size * 0.72
		var y0: float = size * 0.6
		var q0 := Vector3(cos(a0) * r, y0 + sin(a0) * r * 0.55, 0)
		var q1 := Vector3(cos(a1) * r, y0 + sin(a1) * r * 0.55, 0)
		var half := Vector3(0, 0, size * 0.52)
		parts.quad("roof", q0 - half, q1 - half, q1 + half, q0 + half, Color.BLACK, [], [], (q0 + q1) * 0.5 - Vector3(0, y0, 0))
	for k in range(4):
		parts.box("window", Vector3(-size * 0.45 + k * size * 0.3, size * 0.36, size * 0.505), Vector3(size * 0.18, size * 0.22, 0.1))
	parts.cylinder("wall", Vector3(size * 0.5, size * 0.6, -size * 0.3), Vector3(size * 0.5, size * 1.5, -size * 0.3), size * 0.08, size * 0.07, 10)
	var node := MeshInstance3D.new()
	node.name = "WorkshopHangar"
	node.mesh = parts.commit({
		"wall": lit(Color("e9eef7"), 0.6, 0.1), "roof": lit(Color(course.theme.get("accent", Color("ff7a3d"))), 0.5, 0.2),
		"window": glow(Color("ffd98a"), 1.2)
	})
	parent.add_child(node)
	var balloon := mesh_node(sphere_mesh(size * 0.22, 14), lit(Color("ff6f61"), 0.6), p + Basis(Vector3.UP, yaw) * Vector3(size * 0.5, size * 1.75, -size * 0.3))
	balloon.scale = Vector3(1, 1.25, 1)
	parent.add_child(balloon)


static func _water(parent: Node3D, course, item: Dictionary) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * float(item.size)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(course.theme.get("water", Color("0f3f6b")))
	m.roughness = 0.12
	m.metallic = 0.25
	m.metallic_specular = 0.8
	var node := mesh_node(plane, m, item.pos)
	node.name = "Water"
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


## Berge, Kieferninseln, Kristallturm und Kristallsäule in wenigen Flächen.
static func _far_items(parent: Node3D, course, items: Array[Dictionary]) -> void:
	if items.is_empty():
		return
	var parts = MESHES.new()
	for item in items:
		var p: Vector3 = item.pos
		var size: float = float(item.size)
		match str(item.kind):
			"mountain":
				parts.cylinder("rock", p, p + Vector3.UP * size * 1.1, size, size * 0.32, 10)
				parts.cylinder("snow", p + Vector3.UP * size * 1.1, p + Vector3.UP * size * 1.55, size * 0.32, 0.5, 10)
			"pine_isle":
				parts.cylinder("snow", p + Vector3.DOWN * 1.0, p + Vector3.UP * 1.2, size, size * 0.9, 10)
				for k in range(5):
					var a: float = TAU * k / 5.0 + size
					var t: Vector3 = p + Vector3(cos(a), 0, sin(a)) * size * 0.5 + Vector3.UP * 1.2
					parts.cylinder("tree", t, t + Vector3.UP * size * 0.9, size * 0.22, 0.2, 8)
					parts.cylinder("snow", t + Vector3.UP * size * 0.55, t + Vector3.UP * size * 0.95, size * 0.1, 0.05, 8)
			"ice_tower":
				var height: float = float(item.get("height", 40.0))
				parts.cylinder("ice", p, p + Vector3.UP * height, size * 1.05, size * 0.98, 8)
				for k in range(8):
					var a: float = TAU * (k + 0.5) / 8.0
					var dir := Vector3(cos(a), 0, sin(a))
					parts.box("glow", p + dir * size * 1.0 + Vector3.UP * height * 0.5, Vector3(0.5, height * 0.96, 0.5), Basis.looking_at(dir, Vector3.UP))
				for y in [height * 0.33, height * 0.66, height - 0.4]:
					parts.cylinder("rim", p + Vector3.UP * (y - 0.4), p + Vector3.UP * (y + 0.4), size * 1.12, size * 1.12, 16)
				for k in range(6):
					var a: float = TAU * k / 6.0 + 0.3
					var base: Vector3 = p + Vector3(cos(a), 0, sin(a)) * size * 1.2 + Vector3.UP * 2.0
					parts.cylinder("ice", base, base + Vector3(cos(a), 3.0, sin(a)) * 3.0 + Vector3.UP * 8.0, 2.6, 0.2, 6)
			"pyramid":
				for k in range(5):
					var step_size: float = size * (1.0 - k * 0.18)
					parts.box("stone_dark", p + Vector3.UP * (k * size * 0.22 + size * 0.11), Vector3(step_size * 2.0, size * 0.22, step_size * 2.0))
				parts.box("glow", p + Vector3.UP * (size * 1.15), Vector3(size * 0.3, size * 0.12, size * 0.3))
			"temple_wall":
				var yaw: float = float(item.yaw)
				var basis := Basis(Vector3.UP, yaw)
				var h2: float = float(item.get("height", 7.0))
				var length: float = size
				var blocks: int = maxi(1, int(length / 4.0))
				for k in range(blocks):
					var z: float = (float(k) + 0.5) / blocks - 0.5
					var c: Vector3 = p + basis * Vector3(0, 0, z * length)
					parts.box("stone_dark", c + Vector3.UP * (h2 * 0.5 - 0.5), Vector3(1.6, h2 + 1.0, length / blocks - 0.08), basis)
					if k % 2 == 0:
						parts.box("moss_top", c + Vector3.UP * (h2 + 0.05), Vector3(1.9, 0.5, length / blocks * 0.8), basis)
						parts.box("glow", c + Vector3.UP * (h2 * 0.55), Vector3(1.7, 0.5, 0.5), basis)
			"crystal_column":
				var h: float = float(item.get("height", 30.0))
				parts.cylinder("ice", p, p + Vector3.UP * h, size, size * 0.7, 6)
				parts.cylinder("glow", p + Vector3.UP * h, p + Vector3.UP * (h + 9.0), size * 0.7, 0.3, 6)
				for k in range(5):
					var a: float = TAU * k / 5.0
					var base: Vector3 = p + Vector3(cos(a), 0, sin(a)) * size * 0.8 + Vector3.UP * (h * 0.3 + k * 3.0)
					parts.cylinder("ice", base, base + Vector3(cos(a), 1.4, sin(a)) * 6.0, 1.6, 0.15, 6)
	var ice := lit(Color(course.theme.get("tower", Color("6fb8e6"))), 0.08, 0.1)
	ice.emission_enabled = true
	ice.emission = Color(course.theme.get("tower", Color("6fb8e6"))) * 0.35
	var node := MeshInstance3D.new()
	node.name = "FarScenery"
	node.mesh = parts.commit({
		"rock": lit(Color(course.theme.get("rock", Color("6f7f94"))), 0.9),
		"snow": lit(Color(course.theme.get("snow_cap", Color("eef4fb"))), 0.7), "tree": lit(Color(course.theme.get("tree", Color("2f6b58"))), 0.9),
		"ice": ice, "glow": glow(Color(course.theme.get("ice_glow", course.theme.get("edge", Color("7ff3ff")))), 1.6),
		"rim": lit(Color("dff4ff"), 0.2, 0.3),
		"stone_dark": lit(Color(course.theme.get("tower", Color("a9946f"))), 0.9),
		"moss_top": lit(Color(course.theme.get("grass", Color("5f9a3e"))), 0.9)
	})
	parent.add_child(node)


## Sonnenplatte im Boden: leuchtet, bis das Kart darüberfährt, dann sinkt sie ein.
static func pressure_plate(accent: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "PressurePlate"
	root.add_child(mesh_node(cyl_mesh(2.6, 2.8, 0.2, 24), lit(Color("7d6a52"), 0.8), Vector3(0, 0.05, 0)))
	var face := mesh_node(cyl_mesh(2.1, 2.2, 0.16, 24), glow(accent, 1.8), Vector3(0, 0.18, 0))
	face.name = "Face"
	root.add_child(face)
	for k in range(8):
		var a: float = TAU * k / 8.0
		var ray := mesh_node(box_mesh(Vector3(0.3, 0.08, 1.0)), glow(accent, 2.2), Vector3(cos(a) * 3.3, 0.06, sin(a) * 3.3))
		ray.rotation.y = -a + PI * 0.5
		root.add_child(ray)
	var label := Label3D.new()
	label.text = "☀"
	label.font_size = 160
	label.pixel_size = 0.012
	label.modulate = Color("fff4c8")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.2, 0)
	label.name = "Hint"
	root.add_child(label)
	return root


static func set_plate(node: Node3D, pressed: bool) -> void:
	var face := node.get_node_or_null("Face") as Node3D
	if face != null:
		face.position.y = lerpf(face.position.y, 0.06 if pressed else 0.18, 0.2)
		var m := (face as MeshInstance3D).material_override as StandardMaterial3D
		m.emission_energy_multiplier = 0.4 if pressed else 1.8
	var hint := node.get_node_or_null("Hint") as Label3D
	if hint != null:
		hint.visible = not pressed


## Urwaldbäume: Stamm, Brettwurzeln und drei Kronenballen; Kronen als MultiMesh.
static func _jungle_trees(parent: Node3D, course, items: Array[Dictionary], lightweight: bool) -> void:
	if items.is_empty():
		return
	var parts = MESHES.new()
	var crowns: Array[Transform3D] = []
	var count: int = items.size() if not lightweight else items.size() / 2
	for i in range(count):
		var item: Dictionary = items[i]
		var p: Vector3 = item.pos
		var size: float = float(item.size)
		var height: float = size * 3.2
		parts.cylinder("trunk", p + Vector3.DOWN * 2.0, p + Vector3.UP * height, size * 0.22, size * 0.12, 8)
		for k in range(3):
			var a: float = TAU * k / 3.0 + size
			var r := Vector3(cos(a), 0, sin(a))
			parts.cylinder("trunk", p + r * size * 0.55 + Vector3.DOWN, p + Vector3.UP * size * 0.9, size * 0.08, size * 0.05, 5)
		for k in range(3):
			var a: float = TAU * k / 3.0 + size * 0.7
			var offset := Vector3(cos(a) * size * 0.55, height - k * size * 0.25, sin(a) * size * 0.55)
			var s: float = size * (1.15 - k * 0.12)
			crowns.append(Transform3D(Basis().scaled(Vector3(s, s * 0.62, s)), p + offset))
	var node := MeshInstance3D.new()
	node.name = "JungleTrunks"
	node.mesh = parts.commit({"trunk": lit(Color("5b4632"), 0.9)})
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere_mesh(1.0, 10)
	mm.instance_count = crowns.size()
	for i in range(crowns.size()):
		mm.set_instance_transform(i, crowns[i])
	var canopy := MultiMeshInstance3D.new()
	canopy.name = "JungleCanopy"
	canopy.multimesh = mm
	canopy.material_override = lit(Color(course.theme.get("tree", Color("2f7a3a"))), 0.85)
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(canopy)
