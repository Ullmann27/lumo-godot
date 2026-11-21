extends RefCounted
## Kulissen der Parcours-Welten (Wolken, Himmelsinseln, Zahnräder, Werkstatthalle, Zahnradturm,
## See, Berge, Kieferninseln, Kristallturm, Tempelmauern, Pyramiden, Urwaldbäume).
## Wenige zusammengefasste Flächen bzw. MultiMesh, ohne Schatten, nie auf der Fahrbahn.

const KIT = preload("res://scripts/games/parcours/parcours_kit.gd")
const MESHES = preload("res://scripts/games/parcours/parcours_meshes.gd")


## Kulisse nie in oder dicht an der Fahrbahn (auch nicht im Blick der Fahrerkamera).
static func clear_of_course(course, p: Vector3, size: float) -> bool:
	var probe := Vector3(p.x, 10000.0, p.z)
	for index in range(course.slabs.size()):
		if not course._near_bounds(course.slabs[index], p):
			var c: Vector3 = course.slabs[index].reach_center
			var r: float = float(course.slabs[index].reach_radius) + size + 8.0
			if Vector2(p.x - c.x, p.z - c.z).length() > r:
				continue
		if not (
			course._slab_ground(index, probe, 0.0, course.mechanisms, size * 0.7 + 5.0).is_empty()
		):
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
			str(item.kind) not in ["cloud"]
			and not bool(item.get("anchored", false))
			and not clear_of_course(course, item.pos, float(item.size))
		):
			continue
		match str(item.kind):
			"cloud":
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(item.pos)
				var size: float = float(item.size)
				for k in range(5 if not lightweight else 3):
					var offset := Vector3(
						rng.randf_range(-1, 1) * size,
						rng.randf_range(-0.2, 0.3) * size * 0.4,
						rng.randf_range(-1, 1) * size * 0.6
					)
					var s: float = size * rng.randf_range(0.45, 0.8)
					clouds.append(
						Transform3D(
							Basis().scaled(Vector3(s, s * 0.55, s)), (item.pos as Vector3) + offset
						)
					)
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
		var sphere := KIT.sphere_mesh()
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
		mm.mesh = KIT.cyl_mesh(1.0, 1.1, 0.5, 9)
		mm.instance_count = floes.size()
		for i in range(floes.size()):
			var f: Dictionary = floes[i]
			var size: float = float(f.size)
			mm.set_instance_transform(
				i,
				Transform3D(
					Basis(Vector3.UP, i * 1.3).scaled(Vector3(size, 1.0, size * 0.7)), f.pos
				)
			)
		var node := MultiMeshInstance3D.new()
		node.name = "IceFloes"
		node.multimesh = mm
		node.material_override = KIT.lit(Color("eaf6ff"), 0.4)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
	var far_parts = MESHES.new()
	for item in rocks:
		var size: float = float(item.size)
		var p: Vector3 = item.pos
		far_parts.cylinder("rock", p + Vector3.DOWN * size * 1.4, p, size * 0.12, size, 9)
		far_parts.cylinder(
			"grass",
			p + Vector3.DOWN * 0.1,
			p + Vector3.UP * size * 0.16,
			size * 1.02,
			size * 0.98,
			9
		)
		for k in range(3):
			var t: Vector3 = (
				p + Vector3(cos(k * 2.1) * size * 0.5, size * 0.16, sin(k * 2.1) * size * 0.5)
			)
			far_parts.cylinder(
				"trunk", t, t + Vector3.UP * size * 0.25, size * 0.05, size * 0.04, 6
			)
			far_parts.cylinder(
				"tree",
				t + Vector3.UP * size * 0.2,
				t + Vector3.UP * size * 0.75,
				size * 0.26,
				size * 0.02,
				8
			)
	if not rocks.is_empty():
		var islands := MeshInstance3D.new()
		islands.name = "SkyIslands"
		islands.mesh = far_parts.commit(
			{
				"rock": KIT.lit(Color(course.theme.get("rock", Color("8d7a6b"))), 0.9),
				"grass": KIT.lit(Color(course.theme.get("grass", Color("79c66a"))), 0.9),
				"trunk": KIT.lit(Color("6b4a32"), 0.9),
				"tree": KIT.lit(Color(course.theme.get("tree", Color("3f9a52"))), 0.9)
			}
		)
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
			parts.box(
				"gear",
				dir * size * 1.02,
				Vector3(size * 0.2, size * 0.24, size * 0.26),
				Basis(Vector3.BACK, a)
			)
		var ring := MeshInstance3D.new()
		ring.mesh = KIT.torus_mesh(size * 0.62, size * 0.92, 28, 6)
		var gear_material := KIT.lit(Color(course.theme.get("gear", Color("d9a84a"))), 0.35, 0.8)
		ring.material_override = gear_material
		gear.add_child(ring)
		var teeth := MeshInstance3D.new()
		teeth.mesh = parts.commit({"gear": gear_material})
		gear.add_child(teeth)
		for child in gear.get_children():
			(child as GeometryInstance3D).cast_shadow = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)
		parent.add_child(gear)
		parent.animated.append(
			{"kind": "spin", "node": gear, "axis": Vector3(0, 0, 1), "speed": 0.15}
		)


## Großer Zahnradturm (Mitte der Spirale): Säule, Zahnkränze, Leuchtspitze.
static func _gear_tower(parent: Node3D, course, item: Dictionary) -> void:
	var p: Vector3 = item.pos
	var height: float = float(item.get("height", 40.0))
	var radius: float = float(item.size)
	var parts = MESHES.new()
	parts.cylinder(
		"body", p + Vector3.DOWN * 30.0, p + Vector3.UP * height, radius * 1.1, radius * 0.8, 16
	)
	for k in range(int(height / 9.0)):
		var y: float = 4.0 + k * 9.0
		parts.cylinder(
			"ring", p + Vector3.UP * y, p + Vector3.UP * (y + 1.2), radius * 1.35, radius * 1.35, 20
		)
		for t in range(16):
			var a: float = TAU * t / 16.0 + k * 0.2
			var dir := Vector3(cos(a), 0, sin(a))
			parts.box(
				"ring",
				p + dir * radius * 1.45 + Vector3.UP * (y + 0.6),
				Vector3(1.0, 1.0, 0.8),
				Basis.looking_at(dir, Vector3.UP)
			)
	parts.cylinder(
		"glow", p + Vector3.UP * height, p + Vector3.UP * (height + 3.0), radius * 0.5, 0.2, 12
	)
	var node := MeshInstance3D.new()
	node.name = "GearTower"
	node.mesh = parts.commit(
		{
			"body": KIT.lit(Color(course.theme.get("tower", Color("31507f"))), 0.5, 0.4),
			"ring": KIT.lit(Color(course.theme.get("gear", Color("d8a84a"))), 0.35, 0.8),
			"glow": KIT.glow(Color(course.theme.get("edge", Color("ffc23a"))), 2.0)
		}
	)
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
		parts.quad(
			"roof",
			q0 - half,
			q1 - half,
			q1 + half,
			q0 + half,
			Color.BLACK,
			[],
			[],
			(q0 + q1) * 0.5 - Vector3(0, y0, 0)
		)
	for k in range(4):
		parts.box(
			"window",
			Vector3(-size * 0.45 + k * size * 0.3, size * 0.36, size * 0.505),
			Vector3(size * 0.18, size * 0.22, 0.1)
		)
	parts.cylinder(
		"wall",
		Vector3(size * 0.5, size * 0.6, -size * 0.3),
		Vector3(size * 0.5, size * 1.5, -size * 0.3),
		size * 0.08,
		size * 0.07,
		10
	)
	var node := MeshInstance3D.new()
	node.name = "WorkshopHangar"
	node.mesh = parts.commit(
		{
			"wall": KIT.lit(Color("e9eef7"), 0.6, 0.1),
			"roof": KIT.lit(Color(course.theme.get("accent", Color("ff7a3d"))), 0.5, 0.2),
			"window": KIT.glow(Color("ffd98a"), 1.2)
		}
	)
	parent.add_child(node)
	var balloon := KIT.mesh_node(
		KIT.sphere_mesh(size * 0.22, 14),
		KIT.lit(Color("ff6f61"), 0.6),
		p + Basis(Vector3.UP, yaw) * Vector3(size * 0.5, size * 1.75, -size * 0.3)
	)
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
	var node := KIT.mesh_node(plane, m, item.pos)
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
				parts.cylinder(
					"snow",
					p + Vector3.UP * size * 1.1,
					p + Vector3.UP * size * 1.55,
					size * 0.32,
					0.5,
					10
				)
			"pine_isle":
				parts.cylinder(
					"snow", p + Vector3.DOWN * 1.0, p + Vector3.UP * 1.2, size, size * 0.9, 10
				)
				for k in range(5):
					var a: float = TAU * k / 5.0 + size
					var t: Vector3 = p + Vector3(cos(a), 0, sin(a)) * size * 0.5 + Vector3.UP * 1.2
					parts.cylinder("tree", t, t + Vector3.UP * size * 0.9, size * 0.22, 0.2, 8)
					parts.cylinder(
						"snow",
						t + Vector3.UP * size * 0.55,
						t + Vector3.UP * size * 0.95,
						size * 0.1,
						0.05,
						8
					)
			"ice_tower":
				var height: float = float(item.get("height", 40.0))
				parts.cylinder("ice", p, p + Vector3.UP * height, size * 1.05, size * 0.98, 8)
				for k in range(8):
					var a: float = TAU * (k + 0.5) / 8.0
					var dir := Vector3(cos(a), 0, sin(a))
					parts.box(
						"glow",
						p + dir * size * 1.0 + Vector3.UP * height * 0.5,
						Vector3(0.5, height * 0.96, 0.5),
						Basis.looking_at(dir, Vector3.UP)
					)
				for y in [height * 0.33, height * 0.66, height - 0.4]:
					parts.cylinder(
						"rim",
						p + Vector3.UP * (y - 0.4),
						p + Vector3.UP * (y + 0.4),
						size * 1.12,
						size * 1.12,
						16
					)
				for k in range(6):
					var a: float = TAU * k / 6.0 + 0.3
					var base: Vector3 = (
						p + Vector3(cos(a), 0, sin(a)) * size * 1.2 + Vector3.UP * 2.0
					)
					parts.cylinder(
						"ice",
						base,
						base + Vector3(cos(a), 3.0, sin(a)) * 3.0 + Vector3.UP * 8.0,
						2.6,
						0.2,
						6
					)
			"pyramid":
				for k in range(5):
					var step_size: float = size * (1.0 - k * 0.18)
					parts.box(
						"stone_dark",
						p + Vector3.UP * (k * size * 0.22 + size * 0.11),
						Vector3(step_size * 2.0, size * 0.22, step_size * 2.0)
					)
				parts.box(
					"glow",
					p + Vector3.UP * (size * 1.15),
					Vector3(size * 0.3, size * 0.12, size * 0.3)
				)
			"temple_wall":
				var yaw: float = float(item.yaw)
				var basis := Basis(Vector3.UP, yaw)
				var h2: float = float(item.get("height", 7.0))
				var length: float = size
				var blocks: int = maxi(1, int(length / 4.0))
				for k in range(blocks):
					var z: float = (float(k) + 0.5) / blocks - 0.5
					var c: Vector3 = p + basis * Vector3(0, 0, z * length)
					parts.box(
						"stone_dark",
						c + Vector3.UP * (h2 * 0.5 - 0.5),
						Vector3(1.6, h2 + 1.0, length / blocks - 0.08),
						basis
					)
					if k % 2 == 0:
						parts.box(
							"moss_top",
							c + Vector3.UP * (h2 + 0.05),
							Vector3(1.9, 0.5, length / blocks * 0.8),
							basis
						)
						parts.box(
							"glow", c + Vector3.UP * (h2 * 0.55), Vector3(1.7, 0.5, 0.5), basis
						)
			"crystal_column":
				var h: float = float(item.get("height", 30.0))
				parts.cylinder("ice", p, p + Vector3.UP * h, size, size * 0.7, 6)
				parts.cylinder(
					"glow", p + Vector3.UP * h, p + Vector3.UP * (h + 9.0), size * 0.7, 0.3, 6
				)
				for k in range(5):
					var a: float = TAU * k / 5.0
					var base: Vector3 = (
						p
						+ Vector3(cos(a), 0, sin(a)) * size * 0.8
						+ Vector3.UP * (h * 0.3 + k * 3.0)
					)
					parts.cylinder(
						"ice", base, base + Vector3(cos(a), 1.4, sin(a)) * 6.0, 1.6, 0.15, 6
					)
	var ice := KIT.lit(Color(course.theme.get("tower", Color("6fb8e6"))), 0.08, 0.1)
	ice.emission_enabled = true
	ice.emission = Color(course.theme.get("tower", Color("6fb8e6"))) * 0.35
	var node := MeshInstance3D.new()
	node.name = "FarScenery"
	node.mesh = parts.commit(
		{
			"rock": KIT.lit(Color(course.theme.get("rock", Color("6f7f94"))), 0.9),
			"snow": KIT.lit(Color(course.theme.get("snow_cap", Color("eef4fb"))), 0.7),
			"tree": KIT.lit(Color(course.theme.get("tree", Color("2f6b58"))), 0.9),
			"ice": ice,
			"glow":
			KIT.glow(
				Color(course.theme.get("ice_glow", course.theme.get("edge", Color("7ff3ff")))), 1.6
			),
			"rim": KIT.lit(Color("dff4ff"), 0.2, 0.3),
			"stone_dark": KIT.lit(Color(course.theme.get("tower", Color("a9946f"))), 0.9),
			"moss_top": KIT.lit(Color(course.theme.get("grass", Color("5f9a3e"))), 0.9)
		}
	)
	parent.add_child(node)


## Urwaldbäume: Stamm, Brettwurzeln und drei Kronenballen; Kronen als MultiMesh.
static func _jungle_trees(
	parent: Node3D, course, items: Array[Dictionary], lightweight: bool
) -> void:
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
		parts.cylinder(
			"trunk", p + Vector3.DOWN * 2.0, p + Vector3.UP * height, size * 0.22, size * 0.12, 8
		)
		for k in range(3):
			var a: float = TAU * k / 3.0 + size
			var r := Vector3(cos(a), 0, sin(a))
			parts.cylinder(
				"trunk",
				p + r * size * 0.55 + Vector3.DOWN,
				p + Vector3.UP * size * 0.9,
				size * 0.08,
				size * 0.05,
				5
			)
		for k in range(3):
			var a: float = TAU * k / 3.0 + size * 0.7
			var offset := Vector3(
				cos(a) * size * 0.55, height - k * size * 0.25, sin(a) * size * 0.55
			)
			var s: float = size * (1.15 - k * 0.12)
			crowns.append(Transform3D(Basis().scaled(Vector3(s, s * 0.62, s)), p + offset))
	var node := MeshInstance3D.new()
	node.name = "JungleTrunks"
	node.mesh = parts.commit({"trunk": KIT.lit(Color("5b4632"), 0.9)})
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = KIT.sphere_mesh(1.0, 10)
	mm.instance_count = crowns.size()
	for i in range(crowns.size()):
		mm.set_instance_transform(i, crowns[i])
	var canopy := MultiMeshInstance3D.new()
	canopy.name = "JungleCanopy"
	canopy.multimesh = mm
	canopy.material_override = KIT.lit(Color(course.theme.get("tree", Color("2f7a3a"))), 0.85)
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(canopy)
