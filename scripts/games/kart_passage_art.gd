extends RefCounted
## Sichtbarer Aufbau der LUMO-Passagen: Brückendecks, Gletscherspalte, Kronenbrücke,
## Wurzel-S-Kurve, Wasserfall-Blick und Lianenaffe Kiri (mit Bewegung je Rennzeit).
## Alle Maße und Zustände kommen aus kart_passages.gd, damit Bild und Fahrphysik gleich sind.
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const MESH = preload("res://scripts/games/kart_passage_mesh.gd")
const GATE_ART = preload("res://scripts/games/kart_passage_gate_art.gd")


static func build(world) -> void:
	for entry in PASSAGES.of(world):
		match str(entry.kind):
			"bridge":
				_build_bridge(world, entry)
			"gate":
				GATE_ART.build(world, entry)
			"swing":
				_build_swing(world, entry)
			"flow":
				_build_flow(world, entry)
			"view":
				_build_view(world, entry)
		# Two signs: the first one ≥ 3 s ahead even at full pace (1.17 × fastest kart ≈ 54 m/s).
		_warning_sign(
			world, float(entry.zone_start) - PASSAGES.SIGN_LEAD_M, str(entry.sign), _accent(entry)
		)
		_warning_sign(world, float(entry.zone_start) - 30.0, str(entry.sign), _accent(entry))


static func _accent(entry: Dictionary) -> Color:
	match str(entry.theme):
		"ice":
			return Color("8fe3ff")
		"canopy":
			return Color("b8ff6a")
	return Color("ffd23a")


static func _warning_sign(world, distance: float, text: String, color: Color) -> void:
	var basis: Basis = world.frame(distance)
	var side: float = world.road_width_at(distance) * 0.5 + 1.6
	var post: Vector3 = world.position_at(distance, side)
	world._prop("box", post + basis.y * 1.6, Vector3(0.18, 3.2, 0.18), Color("dfe6ee"), basis)
	world._prop("box", post + basis.y * 3.6, Vector3(3.2, 1.6, 0.10), color, basis, true)
	world._prop(
		"box",
		post + basis.y * 3.6 + basis.z * 0.06,
		Vector3(3.0, 1.4, 0.05),
		Color("13233a"),
		basis
	)
	world._sign(post + basis.y * 3.6 + basis.z * 0.10, basis, text, 0.015)


## Box-förmiges Band entlang der Fahrbahn (Deck, Kanten, Vorplatz-Belag).


static func _build_bridge(world, entry: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Passage_%s" % str(entry.id)
	root.set_meta("passage", entry.duplicate())
	world.add_child(root)
	var ice: bool = str(entry.theme) == "ice"
	var half: float = float(entry.deck_width) * 0.5
	var a: float = float(entry.deck_start)
	var b: float = float(entry.deck_end)
	var accent: Color = _accent(entry)
	var deck_color: Color = Color("bfe9ff") if ice else Color("8a5a36")
	var grip_color: Color = Color("f2f8ff") if ice else Color("b98a55")
	# Expansion roads: the shared asphalt ribbon stops at the gap edge; the deck is the road.
	if not world.track_id == "jungle_emerald_3600":
		MESH.mesh_node(
			root,
			"PassageDeck",
			MESH.strip(world, a, b, -half, half, 0.0, -0.75, 0.8),
			MESH.material(
				deck_color, 0.18 if ice else 0.0, 0.18 if ice else 0.8, 0.15 if ice else 0.0
			)
		)
	else:
		# The jungle road strip is the walking surface; this is its plank body below.
		MESH.mesh_node(
			root,
			"PassageDeckBody",
			MESH.strip(world, a, b, -half, half, -0.03, -0.7, 0.8),
			MESH.material(deck_color, 0.0, 0.85)
		)
	MESH.mesh_node(
		root,
		"PassageGripLine",
		MESH.strip(world, a, b, -0.65, 0.65, 0.012, 0.012, 0.8),
		MESH.material(grip_color, 0.0, 0.95)
	)
	for side in [-1.0, 1.0]:
		# Bright edge bands: the precision line reads from far away and on a small display.
		MESH.mesh_node(
			root,
			"PassageEdgeGlow%s" % ("L" if side < 0.0 else "R"),
			MESH.strip(
				world,
				a,
				b,
				side * half - (0.22 if side > 0.0 else 0.0),
				side * half + (0.0 if side > 0.0 else 0.22),
				0.022,
				0.022,
				0.8
			),
			MESH.material(accent, 1.6, 0.4)
		)
	# Plaza: full width, grippy and level; chevrons point into the bridge mouth.
	var plaza_a: float = float(entry.plaza_start)
	MESH.mesh_node(
		root,
		"PassagePlaza",
		MESH.strip(
			world,
			plaza_a,
			a,
			-world.road_width_at(plaza_a) * 0.5 + 0.35,
			world.road_width_at(plaza_a) * 0.5 - 0.35,
			0.008,
			0.008,
			1.0
		),
		MESH.material(Color("e6f1f7") if ice else Color("a7865c"), 0.0, 1.0)
	)
	for i in range(5):
		var d: float = a - 22.0 + float(i) * 4.4
		var basis: Basis = world.frame(d)
		for side in [-1.0, 1.0]:
			var tilted: Basis = basis.rotated(basis.y, -side * 0.55)
			var lateral: float = side * lerpf(4.0, half + 0.4, float(i) / 4.0)
			world._prop(
				"box",
				world.position_at(d, lateral) + basis.y * 0.03,
				Vector3(0.34, 0.03, 1.7),
				accent,
				tilted,
				true
			)
	# Abutments at both gap edges and supports in the gap.
	var abut_color: Color = Color("9fd4ee") if ice else Color("6b4a2e")
	for end in [a, b]:
		var basis: Basis = world.frame(end)
		var width: float = world.road_width_at(end - (1.0 if end == a else -1.0))
		var down: float = 9.0
		var offset: float = -0.6 if end == a else 0.6
		world._prop(
			"box",
			world.position_at(end + offset, 0.0) - basis.y * (down * 0.5),
			Vector3(width + 1.4, down, 1.2),
			abut_color,
			basis
		)
	for fraction in [0.33, 0.67]:
		var d: float = lerpf(a, b, fraction)
		var basis: Basis = world.frame(d)
		var height: float = 12.0
		var foot: Vector3 = world.position_at(d, 0.0) - basis.y * (0.75 + height)
		if ice:
			# Crystal mesh grows from its base (1.7 units tall): the tip carries the deck.
			world._prop(
				"crystal", foot, Vector3(1.5, height / 1.7, 1.5), Color("b5ecff"), basis, true
			)
		else:
			world._prop(
				"cylinder",
				foot + basis.y * (height * 0.5),
				Vector3(0.55, height, 0.55),
				Color("5c4128"),
				basis
			)
	if ice:
		_build_crevasse(world, root, entry)
	else:
		_build_canopy_bridge(world, root, entry)


static func _build_crevasse(world, root: Node3D, entry: Dictionary) -> void:
	# Deep glacier crack across the full road width, readable as "here is no ground".
	var a: float = float(entry.deck_start)
	var b: float = float(entry.deck_end)
	var outer: float = world.road_width_at(a - 1.0) * 0.5 + 6.0
	var floor_mesh: ArrayMesh = MESH.strip(world, a, b, -outer, outer, -11.0, -11.0, 1.0)
	MESH.mesh_node(root, "CrevasseGlow", floor_mesh, MESH.material(Color("1f5f9e"), 0.45, 0.3))
	for side in [-1.0, 1.0]:
		for d in [a + 3.0, (a + b) * 0.5, b - 3.0]:
			var basis: Basis = world.frame(d)
			world._prop(
				"crystal",
				world.position_at(d, side * (outer - 2.5)) - basis.y * 11.0,
				Vector3(1.6, 5.0, 1.6),
				Color("a6e6ff"),
				basis.rotated(basis.y, side * 0.4),
				true
			)
		# Ice walls along the crack, below the plaza height.
		var wall_mesh: ArrayMesh = MESH.strip(
			world, a, b, side * outer - 0.6, side * outer + 0.6, -0.25, -11.0, 1.0
		)
		MESH.mesh_node(
			root,
			"CrevasseWall%s" % ("L" if side < 0.0 else "R"),
			wall_mesh,
			MESH.material(Color("cfeefc"), 0.05, 0.3)
		)


static func _build_canopy_bridge(world, _root: Node3D, entry: Dictionary) -> void:
	var a: float = float(entry.deck_start)
	var b: float = float(entry.deck_end)
	var half: float = float(entry.deck_width) * 0.5
	# Plank seams across the deck for reading speed and scale.
	var d: float = a + 0.6
	var index: int = 0
	while d < b:
		var basis: Basis = world.frame(d)
		world._prop(
			"box",
			world.position_at(d, 0.0) + basis.y * 0.015,
			Vector3(half * 2.0 - 0.3, 0.02, 0.07),
			Color("5a3a22"),
			basis
		)
		d += 1.2
		index += 1
	# Gate trunks at both ends with a leafy lintel; hanging vines mark the deck edges.
	for end in [a, b]:
		var basis: Basis = world.frame(end)
		for side in [-1.0, 1.0]:
			var trunk: Vector3 = world.position_at(end, side * (half + 1.6))
			world._prop(
				"cylinder", trunk + basis.y * 2.6, Vector3(0.9, 5.2, 0.9), Color("6b4a2e"), basis
			)
			world._prop(
				"ball", trunk + basis.y * 5.6, Vector3(2.8, 1.8, 2.8), Color("2f8a3c"), basis
			)
		world._prop(
			"box",
			world.position_at(end, 0.0) + basis.y * 5.3,
			Vector3(half * 2.0 + 3.6, 0.35, 0.4),
			Color("5a3e26"),
			basis
		)
	var along: float = a + 2.0
	while along < b - 1.0:
		var basis: Basis = world.frame(along)
		for side in [-1.0, 1.0]:
			var at: Vector3 = world.position_at(along, side * (half + 0.15))
			world._prop(
				"ball", at + basis.y * 0.12, Vector3(0.22, 0.22, 0.22), Color("e9ff9a"), basis, true
			)
		along += 3.0


## Allee der Riesenwurzeln: root arches frame each apex, glowing apex stones show the line.
static func _build_flow(world, entry: Dictionary) -> void:
	match str(entry.theme):
		"garden":
			return  # Riesengarten baut seinen Kürbis selbst (garden/kart_garden_landmarks.gd).
		"forest":
			_build_root_chicane(world, entry)
			return
		"crystal", "candy", "galaxy", "desert":
			_build_line_curve(world, entry)
			return
	for apex in entry.apexes:
		var d: float = float(apex[0])
		var inside: float = float(apex[1])
		var basis: Basis = world.frame(d)
		var half: float = world.road_width_at(d) * 0.5
		for k in range(5):
			var along: float = d - 16.0 + float(k) * 8.0
			var frame: Basis = world.frame(along)
			world._prop(
				"ball",
				world.position_at(along, inside * (half - 0.9)) + frame.y * 0.15,
				Vector3(0.7, 0.3, 0.7),
				Color("b8ff6a"),
				frame,
				true
			)
		for offset in [-22.0, 0.0, 22.0]:
			var at_d: float = d + offset
			var frame: Basis = world.frame(at_d)
			var left: Vector3 = world.position_at(at_d, -(half + 2.0))
			var right: Vector3 = world.position_at(at_d, half + 2.0)
			# Two giant roots rise from the verges and meet high above the road.
			for side_point in [left, right]:
				var top: Vector3 = (left + right) * 0.5 + frame.y * 9.5
				var middle: Vector3 = side_point.lerp(top, 0.5) + frame.y * 1.6
				world._beam(side_point, middle, 1.3, Color("6b4a2e"))
				world._beam(middle, top, 1.0, Color("6b4a2e"))
			world._prop(
				"ball",
				(left + right) * 0.5 + frame.y * 10.2,
				Vector3(5.0, 2.2, 3.0),
				Color("2f7a3a"),
				frame
			)
		# Outside of each bend: a mossy root wall that leans over the verge.
		for k in range(4):
			var along2: float = d - 18.0 + float(k) * 12.0
			var frame2: Basis = world.frame(along2)
			world._prop(
				"rock",
				world.position_at(along2, -inside * (half + 3.0)) + frame2.y * 0.9,
				Vector3(3.5, 2.2, 4.0),
				Color("55663f"),
				frame2
			)


## Wasserfall-Blick: a calm, straight run that points at a large waterfall.
static func _build_view(world, entry: Dictionary) -> void:
	var d: float = float(entry.landmark)
	var at: Vector3 = world.position_at(d, float(entry.lateral))
	at.y = 0.0
	var facing: Basis = Basis.looking_at(
		(
			world.position_at(float(entry.zone_start), 0.0)
			- world.position_at(d, float(entry.lateral))
		),
		Vector3.UP
	)
	# -facing.z points at the approaching karts: cliff behind, water in front of it, pool nearest.
	world._prop(
		"rock",
		at + Vector3.UP * 1.0 + facing.z * 7.0,
		Vector3(16.0, 19.0, 9.0),
		Color("4f5a52"),
		facing
	)
	world._prop(
		"rock",
		at + Vector3.UP * 0.5 + facing.x * 13.0 + facing.z * 3.0,
		Vector3(7.0, 9.0, 7.0),
		Color("56614f"),
		facing
	)
	world._prop(
		"rock",
		at + Vector3.UP * 0.5 - facing.x * 13.0 + facing.z * 3.0,
		Vector3(7.0, 9.0, 7.0),
		Color("56614f"),
		facing
	)
	for strand in range(5):
		var x: float = (float(strand) - 2.0) * 2.4
		world._prop(
			"box",
			at + facing.x * x + Vector3.UP * (11.5 - absf(x) * 0.25) - facing.z * 1.0,
			Vector3(2.3, 23.0 - absf(x) * 0.5, 0.5),
			Color("bff3ff"),
			facing,
			true
		)
	world._prop(
		"cylinder",
		at + Vector3.UP * 0.2 - facing.z * 6.0,
		Vector3(11.0, 0.4, 11.0),
		Color("2fb7c4"),
		facing,
		true
	)
	for k in range(6):
		world._prop(
			"ball",
			(
				at
				- facing.z * (2.5 + float(k) * 0.6)
				+ facing.x * (float(k) - 2.5) * 2.2
				+ Vector3.UP * 1.4
			),
			Vector3(3.2, 2.2, 3.2),
			Color("eefcff"),
			facing
		)
	# A soft rainbow over the pool.
	var colours: Array[Color] = [
		Color("ff6b6b"),
		Color("ffb84d"),
		Color("fff36b"),
		Color("6bff8f"),
		Color("6bc8ff"),
		Color("b18cff")
	]
	for band in range(colours.size()):
		var radius: float = 13.0 - float(band) * 0.55
		for k in range(13):
			var angle: float = PI * float(k) / 12.0
			var p: Vector3 = (
				at
				- facing.z * 7.0
				+ facing.x * (cos(angle) * radius)
				+ Vector3.UP * (sin(angle) * radius + 2.0)
			)
			world._prop("ball", p, Vector3(0.6, 0.6, 0.6), colours[band], facing, true)


static func _build_swing(world, entry: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Passage_%s" % str(entry.id)
	root.set_meta("passage", entry.duplicate())
	world.add_child(root)
	var plane: float = float(entry.plane)
	var basis: Basis = world.frame(plane)
	var centre: Vector3 = world.position_at(plane, 0.0)
	var reach: float = float(entry.reach)
	var pivot: float = float(entry.pivot_height)
	# Two giant trees with a branch over the road carry the vine.
	for side in [-1.0, 1.0]:
		var trunk: Vector3 = world.position_at(
			plane, side * (world.road_width_at(plane) * 0.5 + 2.4)
		)
		world._prop(
			"cylinder", trunk + basis.y * 7.5, Vector3(1.8, 15.0, 1.8), Color("5b3d25"), basis
		)
		world._prop("ball", trunk + basis.y * 15.5, Vector3(9.0, 5.0, 9.0), Color("2d7a3a"), basis)
		var rest: Vector2 = PASSAGES.swing_offset(entry, {"phase": "open", "direction": -side})
		world._prop(
			"box",
			centre + basis.x * rest.x + basis.y * (rest.y - 1.15),
			Vector3(3.2, 0.45, 0.6),
			Color("6b4a2e"),
			basis
		)
	world._prop(
		"box",
		centre + basis.y * (pivot + 0.4),
		Vector3(world.road_width_at(plane) + 6.0, 0.6, 0.7),
		Color("5a3e26"),
		basis
	)
	# Waiting line and floor arrows: their colour follows the swing phase.
	var line := MeshInstance3D.new()
	line.name = "WaitLine"
	var half_road: float = world.road_width_at(float(entry.wait_line)) * 0.5 - 0.3
	line.mesh = MESH.strip(
		world,
		float(entry.wait_line) - 0.35,
		float(entry.wait_line) + 0.35,
		-half_road,
		half_road,
		0.03,
		0.03,
		0.35
	)
	line.material_override = MESH.material(Color("4dff7a"), 2.0, 0.4)
	root.add_child(line)
	var arrows := MeshInstance3D.new()
	arrows.name = "WaitArrows"
	var arrow_tool := SurfaceTool.new()
	arrow_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(4):
		var d: float = float(entry.wait_line) - 6.0 - float(i) * 6.0
		var frame: Basis = world.frame(d)
		for lane in [-2.8, 0.0, 2.8]:
			var tip: Vector3 = world.position_at(d + 1.1, lane) + frame.y * 0.03
			var l: Vector3 = world.position_at(d - 0.6, lane - 0.9) + frame.y * 0.03
			var r: Vector3 = world.position_at(d - 0.6, lane + 0.9) + frame.y * 0.03
			for corner in [l, tip, r]:
				arrow_tool.set_normal(frame.y)
				arrow_tool.add_vertex(corner)
	arrows.mesh = arrow_tool.commit()
	arrows.material_override = MESH.material(Color("4dff7a"), 1.6, 0.4)
	root.add_child(arrows)
	var monkey := _monkey()
	monkey.name = "Kiri"
	root.add_child(monkey)
	var call := Label3D.new()
	call.name = "KiriCall"
	call.text = "UH-UH-AAH!"
	call.font_size = 64
	call.pixel_size = 0.018
	call.outline_size = 10
	call.modulate = Color("fff3a0")
	call.outline_modulate = Color("3a2412")
	call.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	call.no_depth_test = true
	call.visible = false
	root.add_child(call)
	var vine := MeshInstance3D.new()
	vine.name = "Vine"
	var vine_mesh := CylinderMesh.new()
	vine_mesh.top_radius = 0.13
	vine_mesh.bottom_radius = 0.13
	vine_mesh.height = 1.0
	vine.mesh = vine_mesh
	vine.material_override = MESH.material(Color("58c94a"), 0.35, 0.8)
	root.add_child(vine)
	root.set_meta("pivot", centre + basis.y * pivot)
	root.set_meta("basis", basis)
	root.set_meta("centre", centre)
	update_visuals(world, 0.0)


static func _monkey() -> Node3D:
	var body := Node3D.new()
	var fur: StandardMaterial3D = MESH.material(Color("c46f2c"), 0.12, 0.85)
	var face: StandardMaterial3D = MESH.material(Color("ffe0b0"), 0.1, 0.8)
	var dark: StandardMaterial3D = MESH.material(Color("2a1a10"), 0.0, 0.5)
	var parts: Array = [
		["Torso", Vector3(0, 0.0, 0), Vector3(0.9, 1.1, 0.8), fur],
		["Head", Vector3(0, 0.85, 0.05), Vector3(0.78, 0.72, 0.72), fur],
		["Face", Vector3(0, 0.80, 0.33), Vector3(0.52, 0.46, 0.2), face],
		["EarL", Vector3(-0.42, 0.95, 0.0), Vector3(0.26, 0.3, 0.12), face],
		["EarR", Vector3(0.42, 0.95, 0.0), Vector3(0.26, 0.3, 0.12), face],
		["EyeL", Vector3(-0.12, 0.88, 0.44), Vector3(0.1, 0.12, 0.06), dark],
		["EyeR", Vector3(0.12, 0.88, 0.44), Vector3(0.1, 0.12, 0.06), dark],
		["ArmUp", Vector3(0.0, 1.25, 0.0), Vector3(0.22, 1.1, 0.22), fur],
		["ArmL", Vector3(-0.5, -0.1, 0.1), Vector3(0.2, 0.8, 0.2), fur],
		["LegL", Vector3(-0.25, -0.75, 0.1), Vector3(0.24, 0.6, 0.24), fur],
		["LegR", Vector3(0.25, -0.75, 0.1), Vector3(0.24, 0.6, 0.24), fur],
		["Tail", Vector3(0.0, -0.4, -0.55), Vector3(0.16, 0.16, 0.9), fur],
	]
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	for part in parts:
		var node := MeshInstance3D.new()
		node.name = str(part[0])
		node.mesh = sphere
		node.position = part[1]
		node.scale = part[2]
		node.material_override = part[3]
		body.add_child(node)
	return body


## Bewegt Kiri, Liane, Wartelinie und Pfeile zur Rennzeit t (rein visuell, deterministisch).
static func update_visuals(world, t: float) -> void:
	for entry in PASSAGES.of(world):
		if str(entry.kind) == "gate":
			GATE_ART.update(world, entry, t)
			continue
		if str(entry.kind) != "swing":
			continue
		var root: Node3D = world.get_node_or_null("Passage_%s" % str(entry.id))
		if root == null:
			continue
		var state: Dictionary = PASSAGES.swing_state(entry, t)
		var offset: Vector2 = PASSAGES.swing_offset(entry, state)
		var basis: Basis = root.get_meta("basis")
		var centre: Vector3 = root.get_meta("centre")
		var pivot: Vector3 = root.get_meta("pivot")
		var monkey: Node3D = root.get_node("Kiri")
		var at: Vector3 = centre + basis.x * offset.x + basis.y * offset.y
		monkey.position = at
		var facing: Basis = basis.rotated(basis.y, -float(state.direction) * PI * 0.5)
		monkey.basis = facing.scaled(Vector3.ONE * 1.6)
		var call: Label3D = root.get_node("KiriCall")
		call.visible = str(state.phase) == "warn"
		call.position = at + basis.y * 2.6
		var vine: MeshInstance3D = root.get_node("Vine")
		var top: Vector3 = pivot if str(state.phase) == "swing" else at + basis.y * 3.5
		var span: Vector3 = top - (at + basis.y * 1.6)
		vine.position = (top + at + basis.y * 1.6) * 0.5
		var up: Vector3 = span.normalized()
		var side: Vector3 = up.cross(basis.z).normalized()
		vine.basis = Basis(side, up, side.cross(up)).scaled_local(
			Vector3(1.0, maxf(0.1, span.length()), 1.0)
		)
		var colour := Color("4dff7a")
		if str(state.phase) == "warn":
			colour = Color("ffab2e")
		elif str(state.phase) == "swing":
			colour = Color("ff4b3a")
		for name in ["WaitLine", "WaitArrows"]:
			var node: MeshInstance3D = root.get_node(name)
			var material: StandardMaterial3D = node.material_override
			material.albedo_color = colour
			material.emission = colour


# ---------------------------------------------- Kurven-Passagen der übrigen Welten


## Zauberwald: two offset root arches. Each has a narrow precision opening (≥ 1.6 × widest
## kart) on the short line and a wide outer opening lined with glowing mushrooms. The root
## pillar between both openings is a real obstacle (world.action_obstacles).
static func _build_root_chicane(world, entry: Dictionary) -> void:
	for arch in entry.arches:
		var d: float = float(arch[0])
		var side: float = float(arch[1])  # side of the narrow opening
		var basis: Basis = world.frame(d)
		var half: float = world.road_width_at(d) * 0.5
		var narrow: float = float(entry.narrow_width)
		var pillar_lateral: float = side * (half - narrow - 0.5)
		var pillar: Vector3 = world.position_at(d, pillar_lateral)
		world._prop(
			"cylinder", pillar + basis.y * 3.0, Vector3(0.5, 6.0, 0.5), Color("5b3d25"), basis
		)
		world.action_obstacles.append(pillar)
		for edge in [-1.0, 1.0]:
			var foot: Vector3 = world.position_at(d, edge * (half + 1.0))
			var top: Vector3 = world.position_at(d, 0.0) + basis.y * 7.5
			world._beam(foot, foot.lerp(top, 0.5) + basis.y * 1.2, 1.1, Color("6b4a2e"))
			world._beam(foot.lerp(top, 0.5) + basis.y * 1.2, top, 0.9, Color("6b4a2e"))
		world._beam(
			pillar + basis.y * 6.0, world.position_at(d, 0.0) + basis.y * 7.5, 0.7, Color("6b4a2e")
		)
		# Glowing frame around the narrow opening, mushrooms along the wide outer line.
		for k in range(6):
			var along: float = d - 7.0 + float(k) * 2.8
			var frame: Basis = world.frame(along)
			var lateral: float = -side * (half - 0.6)
			world._prop(
				"cylinder",
				world.position_at(along, lateral) + frame.y * 0.4,
				Vector3(0.12, 0.8, 0.12),
				Color("efe6d0"),
				frame
			)
			world._prop(
				"ball",
				world.position_at(along, lateral) + frame.y * 0.9,
				Vector3(0.9, 0.4, 0.9),
				Color("8af7ff"),
				frame,
				true
			)
		for edge2 in [side * (half - 0.15), pillar_lateral + side * 0.6]:
			world._prop(
				"box",
				world.position_at(d, edge2) + basis.y * 0.04,
				Vector3(0.22, 0.05, 3.0),
				Color("ffe76b"),
				basis,
				true
			)


## Curve passages (Kristall-Canyon, Candy Cloud, Galaxy Ringway, Desert Dune Drift): a
## readable line. Apex markers on the inside, a lit landmark (crystal, planet, …) that makes
## the radius visible and a glowing line for the wide safe path.
static func _build_line_curve(world, entry: Dictionary) -> void:
	var theme: String = str(entry.theme)
	var accent: Color = (
		{
			"crystal": Color("c9a6ff"),
			"candy": Color("ff8ad8"),
			"galaxy": Color("9fd0ff"),
			"desert": Color("ffd27a")
		}
		. get(theme, Color("ffd23a"))
	)
	for apex in entry.apexes:
		var d: float = float(apex[0])
		var inside: float = float(apex[1])
		var basis: Basis = world.frame(d)
		var half: float = world.road_width_at(d) * 0.5
		for k in range(7):
			var along: float = d - 15.0 + float(k) * 5.0
			var frame: Basis = world.frame(along)
			world._prop(
				"box",
				world.position_at(along, inside * (half - 0.35)) + frame.y * 0.05,
				Vector3(0.5, 0.08, 2.6),
				accent,
				frame,
				true
			)
		match theme:
			"crystal":
				var at: Vector3 = world.position_at(d, inside * (half + 4.5))
				world._prop(
					"crystal",
					at - basis.y * 0.5,
					Vector3(3.2, 6.0, 3.2),
					Color("b28cff"),
					basis,
					true
				)
				world._prop(
					"crystal",
					at + basis.z * 3.0 - basis.y * 0.5,
					Vector3(1.6, 3.0, 1.6),
					Color("d6c2ff"),
					basis,
					true
				)
			"candy":
				var pole: Vector3 = world.position_at(d, inside * (half + 1.4))
				world._prop(
					"cylinder",
					pole + basis.y * 1.8,
					Vector3(0.18, 3.6, 0.18),
					Color("fff4fa"),
					basis
				)
				world._prop(
					"ball",
					pole + basis.y * 3.9,
					Vector3(1.4, 1.4, 0.35),
					Color("ff6fb7"),
					basis,
					true
				)
				var top: Vector3 = world.position_at(d, 0.0) + basis.y * 6.5
				for edge in [-1.0, 1.0]:
					world._beam(
						world.position_at(d, edge * (half + 0.8)), top, 0.6, Color("ffc2e4")
					)
			"galaxy":
				# The sphere mesh has unit RADIUS: scale30 means a60m diameter.
				# Its visible orbital ring has42m outer radius; reserve that entire footprint.
				var initial: Vector3 = world.position_at(d, inside * (half + 26.0)) + basis.y * 12.0
				var planet: Vector3 = world.EXPANSION._planet_at(world, d, initial, inside, 42.0, 0.0)
				world._prop("ball", planet, Vector3(30.0, 30.0, 30.0), Color("6a7dff"), basis, true)
				world._prop(
					"torus",
					planet,
					Vector3(84.0, 2.0, 84.0),
					Color("ffd27a"),
					basis.rotated(basis.x, 0.35),
					true
				)
			"desert":
				var trail_out: float = -inside * (half - 1.6)
				for k in range(9):
					var along2: float = d - 32.0 + float(k) * 6.0
					var frame2: Basis = world.frame(along2)
					world._prop(
						"box",
						world.position_at(along2, trail_out) + frame2.y * 0.03,
						Vector3(0.7, 0.03, 3.4),
						Color("f4e1b0"),
						frame2
					)
				world._prop(
					"cylinder",
					world.position_at(d + 6.0, inside * (half + 2.5)) + basis.y * 3.0,
					Vector3(0.4, 6.0, 0.4),
					Color("6b4a2e"),
					basis
				)
				world._prop(
					"ball",
					world.position_at(d + 6.0, inside * (half + 2.5)) + basis.y * 6.5,
					Vector3(4.5, 1.4, 4.5),
					Color("3f9a4a"),
					basis
				)
