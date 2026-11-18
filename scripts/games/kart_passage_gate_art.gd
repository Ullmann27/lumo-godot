extends RefCounted
## LUMO-Tore: Hafenschranke, Steintor, Lichtweiche, Lavapuls und Transportroboter. Ein Querband
## wird im Takt gesperrt; Wartelinie und Pfeile zeigen Grün/Orange/Rot, die freie Spur bleibt grün.
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const MESH = preload("res://scripts/games/kart_passage_mesh.gd")
const PHASE_COLOURS: Dictionary = {
	"open": Color("4dff7a"), "warn": Color("ffab2e"), "swing": Color("ff4b3a")
}


static func build(world, entry: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Passage_%s" % str(entry.id)
	root.set_meta("passage", entry.duplicate())
	world.add_child(root)
	var plane: float = float(entry.plane)
	var basis: Basis = world.frame(plane)
	root.set_meta("basis", basis)
	root.set_meta("centre", world.position_at(plane, 0.0))
	var half_road: float = world.road_width_at(plane) * 0.5
	var sides: Array = [Vector2(float(entry.lat_min), float(entry.lat_max))]
	if bool(entry.get("alternate", false)):
		sides.append(Vector2(-float(entry.lat_max), -float(entry.lat_min)))
	for k in range(sides.size()):
		var band: Vector2 = sides[k]
		var line := MeshInstance3D.new()
		line.name = "WaitLine%d" % k
		line.mesh = _band_strip(
			world, float(entry.wait_line) - 0.35, float(entry.wait_line) + 0.35, band.x, band.y
		)
		line.material_override = MESH.material(PHASE_COLOURS.open, 2.0, 0.4)
		root.add_child(line)
		var arrows := MeshInstance3D.new()
		arrows.name = "WaitArrows%d" % k
		arrows.mesh = MESH.arrow_mesh(world, float(entry.wait_line), [(band.x + band.y) * 0.5])
		arrows.material_override = MESH.material(PHASE_COLOURS.open, 1.6, 0.4)
		root.add_child(arrows)
		var object: Node3D = _gate_object(world, entry, band, basis)
		object.name = "GateObject%d" % k
		root.add_child(object)
	# A post between the gated band and the open lane (boom post, temple pillar) stands on a
	# low striped kerb island, so the two ways read as separate lanes. Visual only: as action
	# obstacles the island points stopped rivals in both lanes (18.11.2026 test run).
	if str(entry.get("object", "barrier")) in ["barrier", "stone"]:
		_divider(world, root, entry, sides[0])
	# The always open outer line: green chevrons, independent of the phase.
	if not bool(entry.get("alternate", false)):
		var band0: Vector2 = sides[0]
		var free: float = (
			(-half_road + band0.x) * 0.5
			if band0.x - (-half_road) >= half_road - band0.y
			else (band0.y + half_road) * 0.5
		)
		var safe := MeshInstance3D.new()
		safe.name = "OpenLaneArrows"
		safe.mesh = MESH.arrow_mesh(world, float(entry.wait_line), [free])
		safe.material_override = MESH.material(Color("8ff7ff"), 1.4, 0.4)
		root.add_child(safe)
	update(world, entry, 0.0)


static func _divider(world, root: Node3D, entry: Dictionary, band: Vector2) -> void:
	var half_road: float = world.road_width_at(float(entry.plane)) * 0.5
	# Post side: the band edge that faces the open road.
	var inner_edge: float = band.y if half_road - band.y > band.x + half_road else band.x
	var side: float = 1.0 if inner_edge == band.y else -1.0
	var post_lateral: float = inner_edge + side * 0.5
	var a: float = float(entry.wait_line) - 4.0
	var b: float = float(entry.plane) + float(entry.band) + 3.0
	var island := MeshInstance3D.new()
	island.name = "DividerIsland"
	island.mesh = MESH.strip(world, a, b, post_lateral - 0.35, post_lateral + 0.35, 0.16, 0.0, 1.0)
	island.material_override = MESH.material(Color("f2f4f6"), 0.0, 0.7)
	root.add_child(island)
	for k in range(int((b - a) / 2.0)):
		var stripe := MeshInstance3D.new()
		stripe.mesh = MESH.strip(
			world,
			a + float(k) * 2.0,
			a + float(k) * 2.0 + 1.0,
			post_lateral - 0.36,
			post_lateral + 0.36,
			0.17,
			0.16,
			1.0
		)
		stripe.material_override = MESH.material(Color("ff4b3a"), 0.5)
		root.add_child(stripe)


static func _band_strip(world, a: float, b: float, left: float, right: float) -> ArrayMesh:
	# Above the road decal layer (volcano lava veins hid lines lifted only 0.03 m).
	return MESH.strip(world, a, b, left, right, 0.07, 0.07, 0.35)


static func _gate_object(world, entry: Dictionary, band: Vector2, basis: Basis) -> Node3D:
	var node := Node3D.new()
	var plane: float = float(entry.plane)
	var width: float = band.y - band.x
	var mid: Vector3 = world.position_at(plane, (band.x + band.y) * 0.5)
	node.position = mid
	node.basis = basis
	var box := BoxMesh.new()
	match str(entry.get("object", "barrier")):
		"barrier":
			# Striped harbour boom: pivots on its post at the outer band edge.
			var post := MeshInstance3D.new()
			post.mesh = box
			# High boom with hanging pennants: seen from the chase camera above the kart
			# (a 1.6 m boom disappeared behind Lumo while the child waited in front of it).
			post.scale = Vector3(0.5, 3.4, 0.5)
			post.position = Vector3(width * 0.5 + 0.5, 1.7, 0.0)
			post.material_override = MESH.material(Color("e9eef2"))
			node.add_child(post)
			var pivot := Node3D.new()
			pivot.name = "Pivot"
			pivot.position = Vector3(width * 0.5 + 0.5, 3.0, 0.0)
			node.add_child(pivot)
			for k in range(int(ceil(width + 0.5))):
				var red: bool = k % 2 == 0
				var stripe := MeshInstance3D.new()
				stripe.mesh = box
				stripe.scale = Vector3(1.0, 0.45, 0.35)
				stripe.position = Vector3(-0.5 - float(k), 0.0, 0.0)
				stripe.material_override = MESH.material(
					Color("ff4b3a") if red else Color("fafafa"), 0.6 if red else 0.0
				)
				pivot.add_child(stripe)
				var pennant := MeshInstance3D.new()
				pennant.mesh = box
				pennant.scale = Vector3(0.5, 1.1, 0.06)
				pennant.position = Vector3(-0.5 - float(k), -0.8, 0.0)
				pennant.material_override = MESH.material(
					Color("fafafa") if red else Color("ff4b3a"), 0.0 if red else 0.6
				)
				pivot.add_child(pennant)
		"stone":
			for side in [-1.0, 1.0]:
				var pillar := MeshInstance3D.new()
				pillar.mesh = box
				pillar.scale = Vector3(1.0, 6.0, 1.4)
				pillar.position = Vector3(side * (width * 0.5 + 0.6), 3.0, 0.0)
				pillar.material_override = MESH.material(Color("8d7a55"), 0.0, 0.9)
				node.add_child(pillar)
			var lintel := MeshInstance3D.new()
			lintel.mesh = box
			lintel.scale = Vector3(width + 2.4, 1.0, 1.6)
			lintel.position = Vector3(0.0, 6.4, 0.0)
			lintel.material_override = MESH.material(Color("a08a60"), 0.0, 0.9)
			node.add_child(lintel)
			var slab := MeshInstance3D.new()
			slab.name = "Mover"
			slab.mesh = box
			slab.scale = Vector3(width, 3.2, 0.8)
			slab.material_override = MESH.material(Color("7f6d4c"), 0.05, 0.9)
			node.add_child(slab)
			var glyph := MeshInstance3D.new()
			glyph.mesh = box
			glyph.scale = Vector3(1.2, 1.2, 0.05)
			glyph.position = Vector3(0.0, 0.0, 0.43)
			glyph.material_override = MESH.material(Color("5fffd2"), 1.4)
			slab.add_child(glyph)
		"light":
			for side in [-1.0, 1.0]:
				var mast := MeshInstance3D.new()
				mast.mesh = box
				mast.scale = Vector3(0.3, 4.0, 0.3)
				mast.position = Vector3(side * (width * 0.5 + 0.3), 2.0, 0.0)
				mast.material_override = MESH.material(Color("2a3b5c"), 0.0, 0.3, 0.6)
				node.add_child(mast)
			var wall := MeshInstance3D.new()
			wall.name = "Mover"
			wall.mesh = box
			wall.scale = Vector3(width, 3.2, 0.12)
			wall.position = Vector3(0.0, 1.6, 0.0)
			wall.material_override = MESH.material(Color("ff4bd8"), 2.4, 0.2)
			wall.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wall.material_override.albedo_color.a = 0.55
			node.add_child(wall)
		"lava":
			var pool := MeshInstance3D.new()
			pool.name = "Mover"
			pool.top_level = true
			pool.mesh = MESH.strip(
				world,
				plane - float(entry.band),
				plane + float(entry.band),
				band.x,
				band.y,
				0.08,
				0.08,
				0.5
			)
			pool.material_override = MESH.material(Color("2b2226"), 0.01, 0.9)
			node.add_child(pool)
			for side in [-1.0, 1.0]:
				var rim := MeshInstance3D.new()
				rim.top_level = true
				rim.mesh = MESH.strip(
					world,
					plane - float(entry.band) - 0.4,
					plane + float(entry.band) + 0.4,
					band.x - 0.3 if side < 0.0 else band.y,
					band.x if side < 0.0 else band.y + 0.3,
					0.12,
					0.0,
					0.5
				)
				rim.material_override = MESH.material(Color("ffd23a"), 1.8)
				node.add_child(rim)
		_:
			var robot := Node3D.new()
			robot.name = "Mover"
			node.add_child(robot)
			var body := MeshInstance3D.new()
			body.mesh = box
			body.scale = Vector3(1.8, 1.6, 1.4)
			body.position = Vector3(0.0, 1.0, 0.0)
			body.material_override = MESH.material(Color("e6f4f1"), 0.1, 0.3, 0.3)
			robot.add_child(body)
			for side in [-1.0, 1.0]:
				var eye := MeshInstance3D.new()
				eye.mesh = box
				eye.scale = Vector3(0.3, 0.3, 0.06)
				eye.position = Vector3(side * 0.4, 1.35, 0.72)
				eye.material_override = MESH.material(Color("4ff7ff"), 2.0)
				robot.add_child(eye)
			var cargo := MeshInstance3D.new()
			cargo.mesh = box
			cargo.scale = Vector3(1.2, 0.7, 1.0)
			cargo.position = Vector3(0.0, 2.15, 0.0)
			cargo.material_override = MESH.material(Color("ffb84d"), 0.3)
			robot.add_child(cargo)
			var rail := MeshInstance3D.new()
			rail.mesh = box
			rail.scale = Vector3(width + 4.0, 0.06, 0.5)
			rail.position = Vector3(0.0, 0.04, 0.0)
			rail.material_override = MESH.material(Color("ffd23a"), 1.2)
			node.add_child(rail)
	return node


static func update(world, entry: Dictionary, t: float) -> void:
	var root: Node3D = world.get_node_or_null("Passage_%s" % str(entry.id))
	if root == null:
		return
	var state: Dictionary = PASSAGES.swing_state(entry, t)
	var phase: String = str(state.phase)
	var active: Vector2 = PASSAGES.gate_band(entry, state)
	var count: int = 2 if bool(entry.get("alternate", false)) else 1
	for k in range(count):
		var band := Vector2(float(entry.lat_min), float(entry.lat_max))
		if k == 1:
			band = Vector2(-band.y, -band.x)
		var mine: bool = absf(band.x - active.x) < 0.01
		var shown: String = phase if mine else "open"
		var colour: Color = PHASE_COLOURS[shown]
		if shown == "warn" and fposmod(t * 4.0, 1.0) < 0.5:
			colour = colour.darkened(0.45)  # Blinking: the change is announced, not sudden.
		for name in ["WaitLine%d" % k, "WaitArrows%d" % k]:
			var mat: StandardMaterial3D = root.get_node(name).material_override
			mat.albedo_color = colour
			mat.emission = colour
		var object: Node3D = root.get_node("GateObject%d" % k)
		var amount: float = 0.0  # 0 open … 1 closed
		if shown == "warn":
			amount = 0.15 * float(state.progress)
		elif shown == "swing":
			var p: float = float(state.progress)
			amount = clampf(minf(p / 0.15, (1.0 - p) / 0.12), 0.15, 1.0)
		var width: float = band.y - band.x
		match str(entry.get("object", "barrier")):
			"barrier":
				object.get_node("Pivot").rotation.z = lerpf(PI * 0.5, 0.0, amount) * -1.0
			"stone":
				object.get_node("Mover").position.y = lerpf(5.0, 1.6, amount)
			"light":
				var wall: MeshInstance3D = object.get_node("Mover")
				wall.visible = amount > 0.2 or (shown == "warn" and fposmod(t * 4.0, 1.0) < 0.5)
			"lava":
				# Cool dark crust → blinking orange cracks → bright flowing lava. On the
				# veined volcano road a constant orange pool was not readable (18.11.2026).
				var lava: StandardMaterial3D = object.get_node("Mover").material_override
				var crust := Color("2b2226")
				var hot := Color("ffd84a").lerp(Color("ff5a1f"), 0.5 + 0.5 * sin(t * 9.0))
				var glow: Color = crust
				var energy: float = 0.0
				if shown == "warn":
					var blink: bool = fposmod(t * 4.0, 1.0) < 0.5
					glow = Color("ff7a1f") if blink else crust.lerp(Color("ff7a1f"), 0.35)
					energy = 1.6 if blink else 0.4
				elif shown == "swing":
					glow = hot
					energy = lerpf(1.0, 4.5, amount)
				lava.albedo_color = glow
				lava.emission = glow
				lava.emission_energy_multiplier = energy
			_:
				var robot: Node3D = object.get_node("Mover")
				var x: float = -width * 0.5 - 1.8
				if shown == "swing":
					var p2: float = float(state.progress)
					x = lerpf(-width * 0.5 - 1.8, width * 0.5 + 1.8, p2) * float(state.direction)
				elif shown == "warn":
					x = (-width * 0.5 - 1.8) * float(state.direction) + 0.15 * sin(t * 20.0)
				else:
					x = (-width * 0.5 - 1.8) * float(state.direction)
				robot.position.x = x
