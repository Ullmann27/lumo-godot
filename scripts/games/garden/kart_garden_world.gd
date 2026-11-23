extends RefCounted
## Aufbau von Lumos Riesengarten in kart_world.gd (ein Einhängepunkt: build()).
## Reihenfolge wie Dschungelherz: Fahrbahn + Kollision → Passagen → Umgebung → Instanzen.
const COURSE = preload("res://scripts/games/garden/kart_garden_course.gd")
const SPECTACLE = preload("res://scripts/games/kart_course_spectacle.gd")
const PIECES = preload("res://scripts/games/track_pieces/kart_track_pieces.gd")
const EDGES = preload("res://scripts/games/garden/kart_garden_edges.gd")
const PASSAGE_ART = preload("res://scripts/games/kart_passage_art.gd")
const ROAD_SHADER = preload("res://assets/shaders/garden/kart_garden_road.gdshader")
const PIECE_LENGTH: float = 201.0
const ROW_STEP: float = 2.0
const COLUMNS: int = 6

## Beläge der Fahrbahn (Bedeutung siehe kart_garden_road.gdshader).
const SURFACES: Array = [
	[0.0, 0],
	[118.0, 1],
	[398.0, 2],
	[462.0, 3],
	[521.0, 4],
	[735.0, 5],
	[984.0, 6],
	[1236.0, 1],
	[1286.0, 7],
	[1390.0, 1],
	[1946.0, 8],
	[2321.0, 0],
]


static func build(world: Node3D, geometry_only: bool) -> void:
	world.road_width = 13.0
	world.action = COURSE.action_plan(world)
	world.set_meta("item_zone_hazards", {COURSE.ID: COURSE.item_hazards()})
	SPECTACLE.plan(world)
	PIECES.plan(world, world._piece_markers + SPECTACLE.markers(world))
	_road(world)
	EDGES.build(world, geometry_only)
	PASSAGE_ART.build(world)
	if not geometry_only:
		var environment_script: Script = load(
			"res://scripts/games/garden/kart_garden_environment.gd"
		)
		var environment: Node3D = environment_script.new()
		environment.name = "RiesengartenEnvironment"
		world.add_child(environment)
		environment.build(world)
	SPECTACLE.build_new_action(world)
	PIECES.build(world)
	SPECTACLE.build(world)
	world._flush_instances()
	world.set_meta("garden_sections", COURSE.SECTIONS.size())
	world.set_meta("garden_length_m", world.length)


static func surface_at(distance: float) -> int:
	var d: float = fposmod(distance, COURSE.LENGTH)
	var result: int = 0
	for entry in SURFACES:
		if d >= float(entry[0]):
			result = int(entry[1])
	return result


static func _road(world: Node3D) -> void:
	var road_root := Node3D.new()
	road_root.name = "RiesengartenRoad"
	world.add_child(road_root)
	var material := ShaderMaterial.new()
	material.shader = ROAD_SHADER
	world.set_meta("garden_road_material", material)
	var pieces: int = ceili(float(world.length) / PIECE_LENGTH)
	for index in range(pieces):
		var start: float = float(index) * PIECE_LENGTH
		var end: float = minf(float(world.length), start + PIECE_LENGTH)
		var piece := MeshInstance3D.new()
		piece.name = "RoadPiece%02d" % index
		piece.mesh = _road_mesh(world, start, end)
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
	world.set_meta("garden_road_pieces", pieces)


static func _road_mesh(world: Node3D, start: float, end: float) -> ArrayMesh:
	var rows: int = ceili((end - start) / ROW_STEP)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(rows + 1):
		var d: float = lerpf(start, end, float(row) / float(rows))
		var basis: Basis = world.frame(d)
		var half: float = COURSE.width_at(d) * 0.5
		var surface: float = float(surface_at(d))
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
		var edge: Vector3 = world.position_at(d, side * COURSE.width_at(d) * 0.5)
		vertices.append(edge - basis.y * 0.08)
		vertices.append(edge + basis.y * 1.45)
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


## Start-/Ziellinie: zwei Reihen Schachbrett auf den Planken.
static func _start_line(world: Node3D) -> void:
	for row in range(2):
		var d: float = 1.0 + float(row) * 0.8
		var basis: Basis = world.frame(d)
		var half: float = COURSE.width_at(d) * 0.5
		var columns: int = int(half * 2.0 / 0.8)
		for column in range(columns):
			var lateral: float = -half + 0.4 + float(column) * 0.8
			world._prop(
				"box",
				world.position_at(d, lateral) + basis.y * 0.02,
				Vector3(0.8, 0.03, 0.8),
				Color("fbf4dc") if (row + column) % 2 == 0 else Color("2b3a2c"),
				basis
			)
