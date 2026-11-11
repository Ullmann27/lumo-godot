extends Node3D
## Original Mediterranean streetfront kit derived from Lumo reference pp.16–17.
## Architecture is merged into opaque material surfaces in 48 m spatial cells.
## Existing house masses, road/physics and collision ownership remain unchanged.
## Animated fabric has one owner: advance(), called by the race controller.

const STONE := Color("e7ddc6")
const STONE_LIGHT := Color("f5ead5")
const NAVY := Color("244657")
const BLUE := Color("2765a1")
const TEAL := Color("378c91")
const BRASS := Color("c59a55")
const WINDOW := Color("244457")
const WINDOW_LIGHT := Color("427889")
const TERRACOTTA := Color("b96c4d")
const LEAF := Color("447651")
const CELL_SIZE := 48.0
const ACTIVE_DISTANCE := 170.0
const ENTER_DISTANCE := 30.0
const EXIT_DISTANCE := 43.0
const REACTION_SECONDS := 1.8

var metrics: Dictionary = {}
var phase := 0.0
var trigger_count := 0
var low_detail := false
var _cells: Dictionary = {}
var _materials: Dictionary = {}
var _frame := Transform3D.IDENTITY
var _active_cell := Vector2i.ZERO
var _surface_pieces := 0
var _house_count := 0
var _windows := 0
var _accumulator := 0.0
var _banner_states: Array[Dictionary] = []
var _banners: MultiMesh
var _flower: SphereMesh


func configure(lightweight: bool) -> void:
	name = "SonnenhafenStreetfronts"
	low_detail = lightweight
	for kind in ["Masonry", "Joinery", "Glazing", "Fabric"]:
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.roughness = 0.88
		if kind == "Joinery":
			material.roughness = 0.46
			material.metallic = 0.14
		elif kind == "Glazing":
			material.roughness = 0.24
			material.metallic_specular = 0.42
		elif kind == "Fabric":
			material.roughness = 0.96
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[kind] = material
	_flower = SphereMesh.new()
	_flower.radius = 1.0
	_flower.height = 2.0
	_flower.radial_segments = 8
	_flower.rings = 4


func add_villa(
	at: Vector3, basis: Basis, width: float, height: float, depth: float,
	index: int, road_side: float
) -> void:
	_active_cell = Vector2i(floori(at.x / CELL_SIZE), floori(at.z / CELL_SIZE))
	_frame = Transform3D(basis, at)
	_house_count += 1
	# Both the incoming-race face and the inward street face receive real depth.
	# No repositioning or rotation of the existing house body is needed.
	_facade(width, height, depth * 0.5, index, true)
	_frame = Transform3D(basis * Basis(Vector3.UP, -road_side * PI * 0.5), at)
	_facade(depth, height, width * 0.5, index, false)


func _facade(width: float, height: float, front: float, index: int, primary: bool) -> void:
	var floors: int = roundi(height / 3.4)
	var columns := 3 if width > 6.0 else 2
	var spacing: float = width / float(columns + 1)
	# Thick sill bands and alternating corner stone create readable facade scale.
	for floor_index in range(1, floors):
		_box("Masonry", Vector3(0, floor_index * 3.15 + 0.10, front + 0.13),
			Vector3(width + 0.12, 0.16, 0.34), STONE)
	for side in [-1.0, 1.0]:
		var stones: int = 4 if low_detail else floors * 3
		for i in range(stones):
			var y: float = 0.58 + float(i) * (height - 1.05) / float(stones)
			_box("Masonry", Vector3(side * (width * 0.5 - 0.18), y, front + 0.09),
				Vector3(0.44 if i % 2 == 0 else 0.30, 0.32, 0.18), STONE)
	_box("Masonry", Vector3(0, height - 0.24, front + 0.12),
		Vector3(width + 0.20, 0.24, 0.38), STONE_LIGHT)
	for floor_index in range(floors):
		for column in range(columns):
			var x: float = (float(column) - float(columns - 1) * 0.5) * spacing
			var bottom: float = 0.66 + float(floor_index) * 3.15
			var is_door: bool = floor_index == 0 and column == columns / 2
			if is_door:
				bottom = 0.08
			_window(Vector3(x, bottom, front + 0.045), 0.56,
				2.30 if is_door else 1.72, is_door, (index + column) % 2 == 0)
	if primary:
		_balcony(width, front, index)
	_awning(width * 0.91, front, index)
	# Two flat paving terraces join each original foundation to its facade.
	_box("Masonry", Vector3(0, 0.12, front + 0.64), Vector3(width + 0.28, 0.18, 1.55),
		Color("bfaf95"))
	_box("Masonry", Vector3(0, 0.035, front + 1.25), Vector3(width + 0.36, 0.10, 0.42),
		STONE)
	if not low_detail:
		for i in range(5):
			_box("Masonry", Vector3((float(i) - 2.0) * width / 5.0, 0.217, front + 0.64),
				Vector3(0.025, 0.008, 1.40), Color("918a7c"))
	for side in [-1.0, 1.0]:
		_lamp(Vector3(side * (width * 0.5 - 0.42), 2.08, front + 0.25))
	if primary:
		_banner(Vector3(-width * 0.41, height - 1.95, front + 0.30), index)


func _window(at: Vector3, radius: float, height: float, door: bool, teal: bool) -> void:
	_windows += 1
	var spring: float = height - radius
	var stone_width := 0.15
	# Opaque dark reveal behind the brighter glazed inset; no transparency sorting.
	_arch_panel("Glazing", at, radius + 0.035, height + 0.035, WINDOW)
	_arch_panel("Glazing", at + Vector3(0, 0.05, 0.035), radius - 0.075,
		height - 0.13, WINDOW_LIGHT if not door else WINDOW)
	for side in [-1.0, 1.0]:
		_box("Masonry", at + Vector3(side * (radius + stone_width * 0.5), spring * 0.5, 0.10),
			Vector3(stone_width, spring + 0.06, 0.28), STONE_LIGHT)
	_arch_rim(at + Vector3(0, spring, 0.11), radius, radius + stone_width, 0.26)
	_box("Masonry", at + Vector3(0, -0.04, 0.13), Vector3(radius * 2 + 0.43, 0.15, 0.42), STONE)
	_box("Joinery", at + Vector3(0, height * 0.47, 0.10), Vector3(0.055, height - 0.10, 0.07), NAVY)
	_box("Joinery", at + Vector3(0, spring * 0.59, 0.105), Vector3(radius * 1.80, 0.06, 0.07), NAVY)
	if door:
		_box("Joinery", at + Vector3(radius * 0.40, 0.94, 0.18), Vector3(0.07, 0.25, 0.06), BRASS)
		return
	var shutter := TEAL if teal else BLUE
	for side in [-1.0, 1.0]:
		var center := at + Vector3(side * (radius + 0.36), spring * 0.52, 0.065)
		_box("Joinery", center, Vector3(0.31, spring * 0.92, 0.12), shutter)
		if not low_detail:
			for slat in range(4):
				_box("Joinery", center + Vector3(0, (float(slat) - 1.5) * 0.21, 0.075),
					Vector3(0.24, 0.035, 0.04), shutter.lightened(0.13))


func _balcony(width: float, front: float, index: int) -> void:
	var span: float = width * 0.83
	_box("Masonry", Vector3(0, 3.24, front + 0.58), Vector3(span, 0.23, 1.22), STONE_LIGHT)
	for y in [3.52, 4.16]:
		_box("Joinery", Vector3(0, y, front + 1.12), Vector3(span - 0.12, 0.07, 0.07), NAVY)
	for side in [-1.0, 1.0]:
		_box("Joinery", Vector3(side * (span * 0.5 - 0.08), 4.16, front + 0.62),
			Vector3(0.07, 0.07, 1.05), NAVY)
	var rails := 5 if low_detail else 9
	for i in range(rails):
		var x: float = (float(i) / float(rails - 1) - 0.5) * (span - 0.16)
		_box("Joinery", Vector3(x, 3.80, front + 1.12), Vector3(0.055, 0.77, 0.055), NAVY)
	for side in [-1.0, 1.0]:
		var planter := Vector3(side * span * 0.32, 3.43, front + 0.95)
		_box("Masonry", planter, Vector3(1.16, 0.30, 0.42), TERRACOTTA)
		_box("Masonry", planter + Vector3(0, 0.17, 0), Vector3(1.24, 0.08, 0.50), STONE)
		for i in range(3):
			var foliage: Vector3 = planter + Vector3((float(i) - 1.0) * 0.36, 0.27, 0.03)
			_sphere(foliage, Vector3(0.30, 0.19, 0.24), LEAF)
			_sphere(foliage + Vector3(0, 0.12, 0.10), Vector3.ONE * 0.14,
				Color("d67ba5") if (i + index) % 2 == 0 else Color("e8c36b"))


func _awning(span: float, front: float, index: int) -> void:
	var stripes := 7 if low_detail else 11
	var canopy_basis := Basis(Vector3.RIGHT, -0.16)
	for i in range(stripes):
		var x: float = (float(i) + 0.5) * span / float(stripes) - span * 0.5
		var fabric: Color = (BLUE if index % 3 != 1 else TEAL) if i % 2 == 0 else STONE_LIGHT
		_box("Fabric", Vector3(x, 2.68, front + 0.76),
			Vector3(span / float(stripes) + 0.006, 0.075, 1.55), fabric, canopy_basis)
		_box("Fabric", Vector3(x, 2.46, front + 1.50),
			Vector3(span / float(stripes) + 0.006, 0.27, 0.08), fabric)
	for side in [-1.0, 1.0]:
		_box("Joinery", Vector3(side * span * 0.46, 2.42, front + 0.68),
			Vector3(0.055, 0.055, 1.46), NAVY, Basis(Vector3.RIGHT, 0.24))


func _lamp(at: Vector3) -> void:
	_box("Joinery", at + Vector3(0, 0.27, 0), Vector3(0.09, 0.46, 0.10), NAVY)
	_box("Joinery", at + Vector3(0, 0.45, 0.18), Vector3(0.09, 0.09, 0.45), NAVY)
	_box("Joinery", at + Vector3(0, 0.27, 0.37), Vector3(0.26, 0.43, 0.26), NAVY)
	_box("Glazing", at + Vector3(0, 0.28, 0.508), Vector3(0.17, 0.28, 0.025), Color("ebd3a4"))
	_box("Joinery", at + Vector3(0, 0.51, 0.37), Vector3(0.34, 0.08, 0.32), BRASS)


func _banner(at: Vector3, index: int) -> void:
	_box("Joinery", at + Vector3(0.34, 0.12, 0), Vector3(0.85, 0.075, 0.075), BRASS)
	_banner_states.append({
		"rest": _frame * Transform3D(Basis.IDENTITY, at + Vector3(0.35, 0.08, 0)),
		"offset": float(index) * 0.71, "near": false, "reaction": 0.0,
	})


func _surface(kind: String) -> SurfaceTool:
	var key := "%d_%d" % [_active_cell.x, _active_cell.y]
	if not _cells.has(key):
		_cells[key] = {}
	if not _cells[key].has(kind):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_cells[key][kind] = surface
	return _cells[key][kind]


func _box(kind: String, at: Vector3, size: Vector3, tint: Color, basis: Basis = Basis.IDENTITY) -> void:
	_surface_pieces += 1
	var half: Vector3 = size * 0.5
	var frame: Transform3D = _frame * Transform3D(basis, at)
	for axis in range(3):
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		for side in [-1.0, 1.0]:
			var center := Vector3.ZERO
			var a := Vector3.ZERO
			var b := Vector3.ZERO
			var normal := Vector3.ZERO
			center[axis] = half[axis] * side
			a[u] = half[u]
			b[v] = half[v]
			normal[axis] = side
			_quad(_surface(kind), [center - a - b, center + a - b, center + a + b, center - a + b],
				frame, normal, tint)


func _arch_panel(kind: String, at: Vector3, radius: float, height: float, tint: Color) -> void:
	_surface_pieces += 1
	var spring: float = height - radius
	var surface: SurfaceTool = _surface(kind)
	_quad(surface, [at + Vector3(-radius, 0, 0), at + Vector3(radius, 0, 0),
		at + Vector3(radius, spring, 0), at + Vector3(-radius, spring, 0)],
		_frame, Vector3.BACK, tint)
	var steps := 7 if low_detail else 12
	for i in range(steps):
		var a: float = PI * float(i) / float(steps)
		var b: float = PI * float(i + 1) / float(steps)
		var center: Vector3 = at + Vector3.UP * spring
		_triangle(surface, [center, center + Vector3(cos(a), sin(a), 0) * radius,
			center + Vector3(cos(b), sin(b), 0) * radius], _frame, Vector3.BACK, tint)


func _arch_rim(center: Vector3, inner: float, outer: float, depth: float) -> void:
	var steps := 7 if low_detail else 12
	var surface: SurfaceTool = _surface("Masonry")
	for i in range(steps):
		var a: float = PI * float(i) / float(steps) + 0.008
		var b: float = PI * float(i + 1) / float(steps) - 0.008
		var va := Vector3(cos(a), sin(a), 0)
		var vb := Vector3(cos(b), sin(b), 0)
		var back := Vector3(0, 0, -depth * 0.5)
		var front := -back
		var pigment: Color = STONE_LIGHT if i % 3 != 0 else STONE
		_quad(surface, [center + va * inner + front, center + va * outer + front,
			center + vb * outer + front, center + vb * inner + front], _frame, Vector3.BACK, pigment)
		_quad(surface, [center + va * inner + back, center + va * inner + front,
			center + vb * inner + front, center + vb * inner + back], _frame, -(va + vb).normalized(), STONE)
		_quad(surface, [center + va * outer + back, center + va * outer + front,
			center + vb * outer + front, center + vb * outer + back], _frame, (va + vb).normalized(), pigment)
	_surface_pieces += 1


func _sphere(at: Vector3, size: Vector3, tint: Color) -> void:
	var data: Array = _flower.surface_get_arrays(0)
	var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	var surface: SurfaceTool = _surface("Masonry")
	var frame: Transform3D = _frame * Transform3D(Basis.IDENTITY.scaled(size), at)
	var normal_basis: Basis = frame.basis.inverse().transposed()
	for i in indices:
		surface.set_normal((normal_basis * normals[i]).normalized())
		surface.set_color(tint)
		surface.add_vertex(frame * vertices[i])
	_surface_pieces += 1


func _triangle(surface: SurfaceTool, vertices: Array, frame: Transform3D, normal: Vector3, tint: Color) -> void:
	var order: Array[int] = [0, 1, 2]
	if (Vector3(vertices[1]) - Vector3(vertices[0])).cross(Vector3(vertices[2]) - Vector3(vertices[0])).dot(normal) > 0.0:
		order = [0, 2, 1]
	for i in order:
		surface.set_normal((frame.basis * normal).normalized())
		surface.set_color(tint)
		surface.add_vertex(frame * Vector3(vertices[i]))


func _quad(surface: SurfaceTool, vertices: Array, frame: Transform3D, normal: Vector3, tint: Color) -> void:
	_triangle(surface, [vertices[0], vertices[1], vertices[2]], frame, normal, tint)
	_triangle(surface, [vertices[0], vertices[2], vertices[3]], frame, normal, tint)


func finish() -> void:
	var triangles := 0
	var surfaces := 0
	for cell: String in _cells:
		var mesh := ArrayMesh.new()
		for kind: String in _cells[cell]:
			var surface: SurfaceTool = _cells[cell][kind]
			surface.set_material(_materials[kind])
			surface.commit(mesh)
			surfaces += 1
		triangles += mesh.get_faces().size() / 3
		var instance := MeshInstance3D.new()
		instance.name = "Streetfront_" + cell
		instance.mesh = mesh
		instance.visibility_range_end = 150.0 if low_detail else 220.0
		instance.visibility_range_end_margin = 14.0
		add_child(instance)
	_cells.clear()
	_finish_banners()
	metrics = {"houses": _house_count, "windows": _windows, "authored_parts": _surface_pieces,
		"triangles": triangles, "material_surfaces": surfaces, "materials": _materials.size(),
		"banner_instances": _banner_states.size(), "banner_draw_batches": 1 if _banners != null else 0,
		"low_detail": low_detail, "external_assets": 0, "collision_nodes": 0}
	set_meta("production_metrics", metrics)


func _finish_banners() -> void:
	if _banner_states.is_empty():
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(surface, [Vector3(-0.34, 0, 0), Vector3(0.34, 0, 0), Vector3(0.34, -1.16, 0), Vector3(-0.34, -1.16, 0)],
		Transform3D.IDENTITY, Vector3.BACK, BLUE)
	_quad(surface, [Vector3(-0.12, -0.22, 0.008), Vector3(-0.025, -0.22, 0.008),
		Vector3(-0.025, -0.91, 0.008), Vector3(-0.12, -0.91, 0.008)], Transform3D.IDENTITY, Vector3.BACK, BRASS)
	_quad(surface, [Vector3(-0.12, -0.81, 0.008), Vector3(0.19, -0.81, 0.008),
		Vector3(0.19, -0.91, 0.008), Vector3(-0.12, -0.91, 0.008)], Transform3D.IDENTITY, Vector3.BACK, BRASS)
	_banners = MultiMesh.new()
	_banners.transform_format = MultiMesh.TRANSFORM_3D
	_banners.mesh = surface.commit()
	_banners.instance_count = _banner_states.size()
	for i in range(_banner_states.size()):
		_banners.set_instance_transform(i, _banner_states[i].rest)
	var node := MultiMeshInstance3D.new()
	node.name = "StreetfrontWelcomePennants"
	node.multimesh = _banners
	node.material_override = _materials.Fabric
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = ACTIVE_DISTANCE
	add_child(node)


func advance(delta: float, racer_position: Vector3, active: bool, reduced_motion: bool) -> void:
	if not active or reduced_motion or delta <= 0.0 or not is_finite(delta) or not racer_position.is_finite():
		return
	var step: float = minf(delta, 0.1)
	phase += step
	_accumulator += step
	if _accumulator < 1.0 / (20.0 if low_detail else 30.0):
		return
	var elapsed: float = _accumulator
	_accumulator = 0.0
	for i in range(_banner_states.size()):
		var state: Dictionary = _banner_states[i]
		var rest: Transform3D = state.rest
		var separation: float = rest.origin.distance_to(racer_position)
		if separation > EXIT_DISTANCE:
			state.near = false
		if separation > ACTIVE_DISTANCE:
			continue
		if separation < ENTER_DISTANCE and not bool(state.near):
			state.near = true
			state.reaction = REACTION_SECONDS
			trigger_count += 1
		state.reaction = maxf(0.0, float(state.reaction) - elapsed)
		var welcome: float = sin((1.0 - float(state.reaction) / REACTION_SECONDS) * PI) if float(state.reaction) > 0.0 else 0.0
		var tilt: float = sin(phase * 1.6 + float(state.offset)) * 0.055 + welcome * 0.16
		_banners.set_instance_transform(i, rest * Transform3D(Basis(Vector3.RIGHT, tilt), Vector3.ZERO))
