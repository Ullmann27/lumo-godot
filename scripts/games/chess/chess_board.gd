extends SubViewportContainer

signal square_pressed(index: int)

const RULES = preload("res://scripts/games/chess/chess_position.gd")

var _camera: Camera3D
var _pieces: Node3D
var _markers: Node3D
var _ivory: StandardMaterial3D
var _ebony: StandardMaterial3D
var _shapes: Dictionary = {}
var _tile_marks: StandardMaterial3D
var _target_mark: StandardMaterial3D
var _choice_mark: StandardMaterial3D


func _ready() -> void:
	stretch = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("102035")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d3e3ff")
	env.ambient_light_energy = 0.66
	environment.environment = env
	world.add_child(environment)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(_camera)
	_camera.position = Vector3(0, 11.5, 6.7)
	_camera.look_at(Vector3(0, 0, 0.10))
	_camera.make_current()
	resized.connect(_fit)
	_fit()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53, -33, 0)
	sun.light_color = Color("ffe1b7")
	sun.light_energy = 1.02
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, 153, 0)
	fill.light_color = Color("8ac9ff")
	fill.light_energy = 0.48
	world.add_child(fill)
	var table := _material(Color("16283d"), 0.92)
	var edge := _material(Color("402923"), 0.56)
	var trim := _material(Color("ac7445"), 0.44, 0.37)
	_box(world, Vector3(0, -0.53, 0), Vector3(28, 0.24, 28), table)
	_box(world, Vector3(0, -0.20, 0), Vector3(8.92, 0.43, 8.92), edge)
	_box(world, Vector3(0, -0.01, 0), Vector3(8.64, 0.10, 8.64), trim)
	var light := _wood(Color("efc78f"), Color("bb834c"))
	var dark := _wood(Color("94604b"), Color("613d38"))
	for index in range(64):
		var position := _square_position(index)
		_box(world, position, Vector3(0.995, 0.12, 0.995), light if (index % 8 + RULES.rank_of(index)) % 2 == 0 else dark)
	for index in range(8):
		_coordinate(world, "abcdefgh"[index], Vector3(index - 3.5, 0.053, 4.19))
		_coordinate(world, str(8 - index), Vector3(-4.20, 0.053, index - 3.5))
	_pieces = Node3D.new()
	_markers = Node3D.new()
	world.add_child(_pieces)
	world.add_child(_markers)
	_ivory = _material(Color("fff0ce"), 0.32)
	_ebony = _material(Color("253245"), 0.29, 0.13)
	_tile_marks = _material(Color("50cfbe"), 0.55)
	_target_mark = _material(Color("ffce78"), 0.48, 0.15)
	_choice_mark = _material(Color("e48377"), 0.58)


func _fit() -> void:
	if _camera == null or size.x <= 0 or size.y <= 0:
		return
	if size.x >= size.y:
		_camera.keep_aspect = Camera3D.KEEP_HEIGHT
		_camera.size = maxf(8.6, 9.24 * size.y / size.x)
	else:
		_camera.keep_aspect = Camera3D.KEEP_WIDTH
		_camera.size = maxf(9.24, 8.6 * size.x / size.y)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var point: Vector2 = event.position
	var origin := _camera.project_ray_origin(point)
	var ray := _camera.project_ray_normal(point)
	var hit: Variant = Plane(Vector3.UP, 0.06).intersects_ray(origin, ray)
	if hit is Vector3:
		var index := RULES.square(floori(hit.x + 4.0), floori(hit.z + 4.0))
		if index >= 0:
			square_pressed.emit(index)
			accept_event()


func display(position: RefCounted, selected: int, targets: Array[int], last: Vector3i, guide: Vector3i) -> void:
	for piece in _pieces.get_children():
		_pieces.remove_child(piece)
		piece.queue_free()
	for marker in _markers.get_children():
		_markers.remove_child(marker)
		marker.queue_free()
	for index in range(64):
		var piece: int = position.board[index]
		if piece != 0:
			_place_piece(index, piece)
	if last.x >= 0:
		_mark(last.x, _target_mark, 0.79)
		_mark(last.y, _target_mark, 0.79)
	if guide.x >= 0:
		_mark(guide.x, _tile_marks, 0.90)
		_mark(guide.y, _tile_marks, 0.90)
	if selected >= 0:
		_mark(selected, _target_mark, 0.94)
		for index in targets:
			_disc(_markers, _square_position(index) + Vector3.UP * 0.085, 0.11 if position.board[index] == 0 else 0.37, 0.025, _tile_marks if position.board[index] == 0 else _choice_mark)
	if position.in_check(position.side):
		_mark(position.board.find(RULES.KING * position.side), _choice_mark, 0.89)


func _place_piece(index: int, piece: int) -> void:
	var type := absi(piece)
	if not _shapes.has(type):
		_shapes[type] = _make_piece(type)
	var container := _shapes[type].duplicate() as Node3D
	container.visible = true
	_pieces.add_child(container)
	container.position = _square_position(index) + Vector3.UP * 0.065
	if piece < 0:
		container.rotation.y = PI
	for mesh: MeshInstance3D in container.get_children():
		mesh.material_override = _ivory if piece > 0 else _ebony


func _make_piece(type: int) -> Node3D:
	var model := Node3D.new()
	add_child(model)
	model.visible = false
	var height := [0.0, 0.37, 0.48, 0.59, 0.48, 0.69, 0.72][type] as float
	var shoulder := 0.155 if type != RULES.PAWN else 0.121
	var radius := 0.26 if type != RULES.PAWN else 0.204
	_profile(model, [
		Vector2(radius * 0.90, 0), Vector2(radius, 0.04), Vector2(radius, 0.08),
		Vector2(radius * 0.84, 0.12), Vector2(radius * 0.63, 0.15),
		Vector2(shoulder * 0.66, height - 0.12), Vector2(shoulder, height - 0.061),
		Vector2(shoulder * 0.94, height - 0.016), Vector2(shoulder * 0.75, height),
	])
	match type:
		RULES.PAWN:
			_sphere(model, Vector3(0, height + 0.070, 0), Vector3.ONE * 0.133)
		RULES.KNIGHT:
			var outline := PackedVector2Array([
				Vector2(-0.16, 0.0), Vector2(-0.15, 0.14), Vector2(-0.09, 0.25),
				Vector2(0.02, 0.31), Vector2(0.065, 0.38), Vector2(0.10, 0.31),
				Vector2(0.17, 0.23), Vector2(0.26, 0.17), Vector2(0.214, 0.10),
				Vector2(0.117, 0.12), Vector2(0.111, 0.0),
			])
			_horse(model, outline, height - 0.02)
		RULES.BISHOP:
			_sphere(model, Vector3(0, height + 0.104, 0), Vector3(0.128, 0.171, 0.128))
			_sphere(model, Vector3(0, height + 0.267, 0), Vector3.ONE * 0.043)
		RULES.ROOK:
			_disc(model, Vector3(0, height + 0.062, 0), 0.196, 0.15)
			for index in range(6):
				var angle := TAU * index / 6
				var tower := _box(model, Vector3(sin(angle) * 0.144, height + 0.155, cos(angle) * 0.144), Vector3(0.105, 0.11, 0.112))
				tower.rotation.y = angle
		RULES.QUEEN:
			_disc(model, Vector3(0, height + 0.04, 0), 0.182, 0.085)
			for index in range(6):
				var angle := TAU * index / 6
				_sphere(model, Vector3(sin(angle) * 0.145, height + 0.125, cos(angle) * 0.145), Vector3.ONE * 0.052)
			_sphere(model, Vector3(0, height + 0.15, 0), Vector3.ONE * 0.077)
		RULES.KING:
			_disc(model, Vector3(0, height + 0.04, 0), 0.179, 0.095)
			_box(model, Vector3(0, height + 0.205, 0), Vector3(0.086, 0.26, 0.087))
			_box(model, Vector3(0, height + 0.228, 0), Vector3(0.260, 0.074, 0.087))
	return model


func _profile(parent: Node3D, points: Array) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size() - 1):
		for side in range(24):
			var a := side * TAU / 24.0
			var b := (side + 1) * TAU / 24.0
			var p: Vector2 = points[index]
			var q: Vector2 = points[index + 1]
			var low_a := Vector3(sin(a) * p.x, p.y, cos(a) * p.x)
			var low_b := Vector3(sin(b) * p.x, p.y, cos(b) * p.x)
			var high_a := Vector3(sin(a) * q.x, q.y, cos(a) * q.x)
			var high_b := Vector3(sin(b) * q.x, q.y, cos(b) * q.x)
			for point: Vector3 in [low_a, high_a, high_b, low_a, high_b, low_b]:
				tool.add_vertex(point)
	tool.generate_normals()
	_mesh(parent, tool.commit(), Vector3.ZERO, null)


func _horse(parent: Node3D, points: PackedVector2Array, height: float) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := Geometry2D.triangulate_polygon(points)
	for index in range(0, triangles.size(), 3):
		for side in [-1, 1]:
			for shift in ([0, 1, 2] if side == 1 else [2, 1, 0]):
				var point := points[triangles[index + shift]]
				tool.add_vertex(Vector3(side * 0.094, height + point.y, point.x))
	for index in range(points.size()):
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		for point: Vector3 in [
			Vector3(-0.094, height + a.y, a.x), Vector3(0.094, height + a.y, a.x), Vector3(0.094, height + b.y, b.x),
			Vector3(-0.094, height + a.y, a.x), Vector3(0.094, height + b.y, b.x), Vector3(-0.094, height + b.y, b.x),
		]:
			tool.add_vertex(point)
	tool.generate_normals()
	_mesh(parent, tool.commit(), Vector3.ZERO, null)


func _mark(index: int, material: Material, width: float) -> void:
	var position := _square_position(index) + Vector3.UP * 0.065
	for sign in [-1, 1]:
		_box(_markers, position + Vector3(sign * width / 2, 0, 0), Vector3(0.025, 0.016, width), material)
		_box(_markers, position + Vector3(0, 0, sign * width / 2), Vector3(width, 0.016, 0.025), material)


func _square_position(index: int) -> Vector3:
	return Vector3(index % 8 - 3.5, 0.0, RULES.rank_of(index) - 3.5)


func _coordinate(parent: Node3D, value: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.text = value
	label.position = position
	label.rotation.x = -PI / 2
	label.font_size = 30
	label.pixel_size = 0.006
	label.modulate = Color("f4dbb8")
	label.outline_size = 0
	parent.add_child(label)


func _wood(pale: Color, rich: Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
uniform vec4 light_tone : source_color;
uniform vec4 dark_tone : source_color;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 x = world_position.xz;
	float fine = sin(x.x * 81.0 + 2.5 * sin(x.y * 1.9 + x.x * 5.1));
	float broad = sin(x.x * 17.0 + 0.8 * sin(x.y * 2.1));
	ALBEDO = mix(light_tone.rgb, dark_tone.rgb, 0.15 + 0.09 * fine + 0.12 * broad);
	ROUGHNESS = 0.57;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("light_tone", pale)
	material.set_shader_parameter("dark_tone", rich)
	return material


func _material(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _box(parent: Node3D, position: Vector3, dimensions: Vector3, material: Material = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _mesh(parent, mesh, position, material)


func _disc(parent: Node3D, position: Vector3, radius: float, height: float, material: Material = null) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	_mesh(parent, mesh, position, material)


func _sphere(parent: Node3D, position: Vector3, scale: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	_mesh(parent, mesh, position, null).scale = scale


func _mesh(parent: Node3D, shape: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var object := MeshInstance3D.new()
	object.mesh = shape
	object.position = position
	object.material_override = material
	parent.add_child(object)
	return object
