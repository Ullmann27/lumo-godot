extends RefCounted
## Aufbau einer Signatur-Strecke in kart_world.gd (ein Einhängepunkt: build()).
## Reihenfolge wie Riesengarten/Windwerk: Spannungsstellen (Steilkurve zuerst, damit jede
## Fahrbahnspanne world.frame() mit Überhöhung sieht) → Action-Plan → Fahrbahn, Wände und
## Kollision → Rampen/Turbofelder → Passagen-Schilder → Umgebung → Kurs-Show → Instanzen.
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const THRILLS = preload("res://scripts/games/kart_track_thrills.gd")
const THRILL_ART = preload("res://scripts/games/kart_track_thrill_art.gd")
const PASSAGE_ART = preload("res://scripts/games/kart_passage_art.gd")
const PIECES = preload("res://scripts/games/track_pieces/kart_track_pieces.gd")
const SPECTACLE = preload("res://scripts/games/kart_course_spectacle.gd")
const ROAD_SHADER = preload("res://assets/shaders/signature/kart_signature_road.gdshader")
const PIECE_LENGTH: float = 200.0
const ROW_STEP: float = 2.0
const COLUMNS: int = 6
const WALL_HEIGHT: float = 1.45


static func build(world: Node3D, course, geometry_only: bool) -> void:
	world.road_width = float(course.BASE_WIDTH)
	THRILLS.plan(world)
	world.action = course.action_plan(world)
	THRILLS.extend_action(world)
	world.set_meta("item_zone_hazards", {str(course.ID): course.item_hazards()})
	# Zusatz-Sequenzen der Kurs-Show nur in freien Stücken (Sperrbereiche wie oben).
	SPECTACLE.plan(world)
	PIECES.plan(world, world._piece_markers + SPECTACLE.markers(world))
	_road(world, course)
	ACTION.build(world)
	THRILL_ART.build(world)
	PASSAGE_ART.build(world)
	if not geometry_only:
		var environment_script: Script = load(str(course.ENVIRONMENT))
		var environment: Node3D = environment_script.new()
		environment.name = "SignatureEnvironment"
		world.add_child(environment)
		environment.build(world, course)
	PIECES.build(world)
	SPECTACLE.build(world)
	world._flush_instances()
	world.set_meta("signature_sections", course.SECTIONS.size())
	world.set_meta("signature_length_m", world.length)


static func surface_at(course, distance: float) -> int:
	var d: float = fposmod(distance, float(course.LENGTH))
	var result: int = 0
	for entry in course.SURFACES:
		if d >= float(entry[0]):
			result = int(entry[1])
	return result


static func _road(world: Node3D, course) -> void:
	var road_root := Node3D.new()
	road_root.name = "SignatureRoad"
	world.add_child(road_root)
	var material := ShaderMaterial.new()
	material.shader = ROAD_SHADER
	var look: Dictionary = course.ROAD_LOOK
	for key in look:
		material.set_shader_parameter(key, look[key])
	world.set_meta("signature_road_material", material)
	var pieces: int = ceili(float(world.length) / PIECE_LENGTH)
	for index in range(pieces):
		var start: float = float(index) * PIECE_LENGTH
		var end: float = minf(float(world.length), start + PIECE_LENGTH)
		var piece := MeshInstance3D.new()
		piece.name = "RoadPiece%02d" % index
		piece.mesh = _road_mesh(world, course, start, end)
		piece.material_override = material
		road_root.add_child(piece)
		if index == 0:
			world.road = piece
		var body := StaticBody3D.new()
		body.name = "RoadCollision%02d" % index
		body.collision_layer = 1
		body.collision_mask = 0
		var road_shape := CollisionShape3D.new()
		var trimesh: ConcavePolygonShape3D = piece.mesh.create_trimesh_shape()
		trimesh.backface_collision = true
		road_shape.shape = trimesh
		body.add_child(road_shape)
		for side in [-1.0, 1.0]:
			var rail := CollisionShape3D.new()
			rail.name = "RailLeft" if side < 0.0 else "RailRight"
			var wall: ConcavePolygonShape3D = (
				_wall_mesh(world, start, end, side).create_trimesh_shape()
			)
			wall.backface_collision = true
			rail.shape = wall
			body.add_child(rail)
		road_root.add_child(body)
	_start_line(world)
	world.set_meta("signature_road_pieces", pieces)


static func _road_mesh(world: Node3D, course, start: float, end: float) -> ArrayMesh:
	var rows: int = ceili((end - start) / ROW_STEP)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(rows + 1):
		var d: float = lerpf(start, end, float(row) / float(rows))
		var basis: Basis = world.frame(d)
		var half: float = world.road_width_at(d) * 0.5
		var surface: float = float(surface_at(course, d))
		for column in range(COLUMNS):
			var lateral: float = lerpf(-half, half, float(column) / float(COLUMNS - 1))
			vertices.append(world.position_at(d, lateral))
			normals.append(basis.y)
			uvs.append(Vector2(lateral, d))
			uv2s.append(Vector2(half, surface))
	for row in range(rows):
		for column in range(COLUMNS - 1):
			var a: int = row * COLUMNS + column
			indices.append_array(
				PackedInt32Array([a, a + COLUMNS, a + 1, a + 1, a + COLUMNS, a + COLUMNS + 1])
			)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _wall_mesh(world: Node3D, start: float, end: float, side: float) -> ArrayMesh:
	var rows: int = ceili((end - start) / ROW_STEP)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in range(rows + 1):
		var d: float = lerpf(start, end, float(row) / float(rows))
		var basis: Basis = world.frame(d)
		var edge: Vector3 = world.position_at(d, side * world.road_width_at(d) * 0.5)
		vertices.append(edge - basis.y * 0.08)
		vertices.append(edge + basis.y * WALL_HEIGHT)
	for row in range(rows):
		var a: int = row * 2
		indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Start-/Ziellinie: zwei Reihen Schachbrett.
static func _start_line(world: Node3D) -> void:
	for row in range(2):
		var d: float = 1.0 + float(row) * 0.8
		var basis: Basis = world.frame(d)
		var half: float = world.road_width_at(d) * 0.5
		var columns: int = int(half * 2.0 / 0.8)
		for column in range(columns):
			var lateral: float = -half + 0.4 + float(column) * 0.8
			world._prop(
				"box",
				world.position_at(d, lateral) + basis.y * 0.02,
				Vector3(0.8, 0.03, 0.8),
				Color("f8f4ea") if (row + column) % 2 == 0 else Color("1d1f27"),
				basis
			)
