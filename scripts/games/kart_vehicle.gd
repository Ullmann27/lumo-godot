class_name LumoRaceKart
extends Node3D
## Original Lumo vehicles: reusable geometry, animated wheels and animal drivers.

const FAR_DETAIL_DISTANCE: float = 28.0
const DETAIL_HYSTERESIS: float = 3.0

var vehicle_color: Color = Color("7760ef")
var animal: String = "fox"
var wheel_pivots: Array[Node3D] = []
var wheel_rotors: Array[Node3D] = []
var eyes: Array[Node3D] = []
var head: Node3D
var tail: Node3D
var steering_wheel: Node3D
var flames: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var motion_speed: float = 0.0
var motion_steer: float = 0.0
var motion_boost: bool = false
var motion_drift: bool = false
var reduced_motion: bool = false
var animation_time: float = 0.0
var materials: Dictionary = {}
var geometries: Dictionary = {}
var near_meshes: Array[MeshInstance3D] = []
var far_mesh: MeshInstance3D
var far_detail: bool = false
var detail_check_time: float = 0.0
var wheel_spin_phase: float = 0.0


func configure(kind: String, color: Color) -> void:
	animal = kind
	vehicle_color = color
	_build()


func _mat(color: Color, metal: float = 0.0, rough: float = 0.5) -> StandardMaterial3D:
	var key: String = color.to_html() + str(metal) + str(rough)
	if materials.has(key):
		return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = rough
	materials[key] = material
	return material


func _mesh(
	parent: Node3D, geometry: Mesh, at: Vector3, color: Color, metal: float = 0.0
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = geometry
	node.position = at
	node.material_override = _mat(color, metal)
	parent.add_child(node)
	return node


func _ellipsoid(
	parent: Node3D, at: Vector3, size: Vector3, color: Color, metal: float = 0.0
) -> MeshInstance3D:
	if not geometries.has("sphere"):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 24
		mesh.rings = 12
		geometries["sphere"] = mesh
	var node := _mesh(parent, geometries["sphere"], at, color, metal)
	node.scale = size
	return node


func _box(
	parent: Node3D, at: Vector3, size: Vector3, color: Color, metal: float = 0.0
) -> MeshInstance3D:
	var key: String = str(size)
	if not geometries.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		geometries[key] = mesh
	return _mesh(parent, geometries[key], at, color, metal)


func _rod(
	parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color, metal: float = 0.0
) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = start.distance_to(end)
	cylinder.radial_segments = 12
	var node := _mesh(parent, cylinder, (start + end) * 0.5, color, metal)
	node.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	return node


func _body_mesh() -> ArrayMesh:
	# A curved nose and broad rear chassis, with smooth surface normals.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Vector4] = [
		Vector4(-1.03, 0.20, 0.10, 0.49),
		Vector4(-0.88, 0.43, 0.21, 0.53),
		Vector4(-0.54, 0.57, 0.25, 0.52),
		Vector4(0.0, 0.63, 0.19, 0.48),
		Vector4(0.54, 0.61, 0.18, 0.47),
		Vector4(0.90, 0.44, 0.13, 0.49),
		Vector4(1.0, 0.08, 0.05, 0.49),
	]
	var sections: int = 24
	for row in range(rings.size() - 1):
		for segment in range(sections):
			var vertices: Array[Vector3] = []
			for r in [row, row + 1]:
				var ring: Vector4 = rings[r]
				for s in [segment, segment + 1]:
					var angle: float = TAU * float(s) / float(sections)
					vertices.append(
						Vector3(cos(angle) * ring.y, ring.w + sin(angle) * ring.z, ring.x)
					)
			for index in [0, 2, 1, 1, 2, 3]:
				surface.add_vertex(vertices[index])
	surface.generate_normals()
	return surface.commit()


func _build() -> void:
	name = "Kart_" + animal
	var ink := Color("283443")
	var chrome := Color("d3e9ec")
	var cream := Color("fff1d5")
	_mesh(self, _body_mesh(), Vector3.ZERO, vehicle_color, 0.22)
	_ellipsoid(self, Vector3(0, 0.33, 0), Vector3(0.69, 0.12, 0.93), ink, 0.18)
	_ellipsoid(
		self,
		Vector3(0, 0.73, -0.58),
		Vector3(0.46, 0.20, 0.43),
		vehicle_color.lightened(0.15),
		0.18
	)
	_box(self, Vector3(0, 0.88, 0.43), Vector3(0.69, 0.52, 0.20), ink)
	_ellipsoid(self, Vector3(0, 0.70, 0.13), Vector3(0.34, 0.12, 0.37), ink)
	_box(self, Vector3(0, 0.52, -1.02), Vector3(1.04, 0.12, 0.14), chrome, 0.65)
	_box(self, Vector3(0, 1.01, 0.96), Vector3(1.48, 0.10, 0.30), vehicle_color, 0.2)
	for side in [-1.0, 1.0]:
		_rod(
			self,
			Vector3(side * 0.37, 0.5, 0.73),
			Vector3(side * 0.37, 0.98, 0.95),
			0.035,
			chrome,
			0.65
		)
		_box(
			self,
			Vector3(side * 0.61, 0.46, 0.10),
			Vector3(0.12, 0.15, 0.95),
			vehicle_color.darkened(0.18),
			0.18
		)
		_ellipsoid(self, Vector3(side * 0.31, 0.62, -0.86), Vector3(0.14, 0.08, 0.045), cream)
		_rod(
			self,
			Vector3(side * 0.25, 0.58, 0.85),
			Vector3(side * 0.32, 0.70, 1.16),
			0.085,
			ink,
			0.4
		)
		var flame := _ellipsoid(
			self, Vector3(side * 0.32, 0.7, 1.35), Vector3(0.065, 0.07, 0.30), Color("69e2ff")
		)
		flame.material_override = _mat(Color("69e2ff"))
		flame.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flame.hide()
		flames.append(flame)
	for side in [-1.0, 1.0]:
		for axle in [-0.65, 0.61]:
			_make_wheel(side, axle, ink, chrome)
	steering_wheel = Node3D.new()
	steering_wheel.position = Vector3(0, 1.0, -0.36)
	steering_wheel.rotation.x = -0.45
	add_child(steering_wheel)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.13
	ring.outer_radius = 0.18
	ring.rings = 16
	ring.ring_segments = 8
	var wheel := _mesh(steering_wheel, ring, Vector3.ZERO, ink)
	wheel.rotation.x = PI / 2.0
	_rod(steering_wheel, Vector3(-0.13, 0, 0), Vector3(0.13, 0, 0), 0.024, chrome)
	_make_driver()
	_make_far_mesh()
	_merge_static(self)


func _merge_static(parent: Node3D) -> void:
	# Vertex colours batch different paints without changing PBR settings or joints.
	var surfaces: Dictionary = {}
	for child in parent.get_children():
		if (
			child is MeshInstance3D
			and child != far_mesh
			and not flames.has(child)
			and not sparks.has(child)
		):
			var material: StandardMaterial3D = child.material_override
			var key: String = str(material.metallic) + ":" + str(material.roughness)
			if not surfaces.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tool.set_material(_vertex_material(material.metallic, material.roughness))
				surfaces[key] = tool
			surfaces[key].append_from(
				_paint_mesh(child.mesh, material.albedo_color), 0, child.transform
			)
			child.free()
		elif child is Node3D and not child is MeshInstance3D:
			_merge_static(child)
	if surfaces.is_empty():
		return
	var merged := ArrayMesh.new()
	for tool in surfaces.values():
		tool.commit(merged)
	# GLES3 requires a matching shadow surface for each visible material surface.
	# Retain every position/index while omitting data the depth pass does not need.
	var shadow := ArrayMesh.new()
	for surface in range(merged.get_surface_count()):
		var shadow_arrays: Array = merged.surface_get_arrays(surface)
		for attribute in [
			Mesh.ARRAY_NORMAL,
			Mesh.ARRAY_TANGENT,
			Mesh.ARRAY_COLOR,
			Mesh.ARRAY_TEX_UV,
			Mesh.ARRAY_TEX_UV2
		]:
			shadow_arrays[attribute] = null
		shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shadow_arrays)
	merged.shadow_mesh = shadow
	var node := MeshInstance3D.new()
	node.mesh = merged
	if eyes.has(parent) or parent == steering_wheel:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	near_meshes.append(node)


func _vertex_material(metal: float, rough: float) -> StandardMaterial3D:
	var key: String = "vertex:" + str(metal) + ":" + str(rough)
	if not materials.has(key):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.metallic = metal
		material.roughness = rough
		materials[key] = material
	return materials[key]


func _paint_mesh(mesh: Mesh, color: Color) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var colors := PackedColorArray()
	colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
	colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var painted := ArrayMesh.new()
	painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return painted


func _far_geometry(mesh: Mesh) -> Mesh:
	# Curves retain their silhouettes at racing distances with fewer segments.
	if mesh is SphereMesh:
		var simple := mesh.duplicate() as SphereMesh
		simple.radial_segments = 12
		simple.rings = 6
		return simple
	if mesh is CylinderMesh:
		var simple := mesh.duplicate() as CylinderMesh
		simple.radial_segments = 10
		return simple
	if mesh is TorusMesh:
		var simple := mesh.duplicate() as TorusMesh
		simple.rings = 12
		simple.ring_segments = 4
		return simple
	return mesh


func _append_far(parent: Node3D, transform_from_kart: Transform3D, tool: SurfaceTool) -> void:
	for child in parent.get_children():
		if child is MeshInstance3D:
			if flames.has(child) or sparks.has(child):
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				continue
			var material: StandardMaterial3D = child.material_override
			tool.append_from(
				_paint_mesh(_far_geometry(child.mesh), material.albedo_color),
				0,
				transform_from_kart * child.transform
			)
		elif child is Node3D:
			_append_far(child, transform_from_kart * child.transform, tool)


func _make_far_mesh() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(_vertex_material(0.18, 0.5))
	_append_far(self, Transform3D.IDENTITY, tool)
	far_mesh = MeshInstance3D.new()
	far_mesh.name = "DistantKart"
	far_mesh.mesh = tool.commit()
	far_mesh.hide()
	add_child(far_mesh)


func _set_far_detail(enabled: bool) -> void:
	far_detail = enabled
	far_mesh.visible = enabled
	for node in near_meshes:
		node.visible = not enabled


func _update_detail(camera: Camera3D) -> void:
	var distance_squared: float = camera.global_position.distance_squared_to(global_position)
	var switch_distance: float = (
		FAR_DETAIL_DISTANCE - DETAIL_HYSTERESIS if far_detail else FAR_DETAIL_DISTANCE
	)
	var distant: bool = distance_squared > switch_distance * switch_distance
	if distant != far_detail:
		_set_far_detail(distant)


func _make_wheel(side: float, axle: float, ink: Color, chrome: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.75, 0.34, axle)
	pivot.set_meta("front", axle < 0)
	add_child(pivot)
	wheel_pivots.append(pivot)
	var rotor := Node3D.new()
	rotor.rotation.z = PI / 2
	pivot.add_child(rotor)
	wheel_rotors.append(rotor)
	var rubber := CylinderMesh.new()
	rubber.top_radius = 0.34
	rubber.bottom_radius = 0.34
	rubber.height = 0.32
	rubber.radial_segments = 24
	_mesh(rotor, rubber, Vector3.ZERO, ink)
	var rim := CylinderMesh.new()
	rim.top_radius = 0.22
	rim.bottom_radius = 0.22
	rim.height = 0.035
	rim.radial_segments = 20
	_mesh(rotor, rim, Vector3(0, -side * 0.18, 0), vehicle_color.lightened(0.2), 0.55)
	_ellipsoid(rotor, Vector3(0, -side * 0.205, 0), Vector3(0.07, 0.035, 0.07), chrome, 0.65)
	for spoke in range(6):
		var angle: float = float(spoke) * TAU / 6
		_box(
			rotor,
			Vector3(cos(angle) * 0.13, -side * 0.205, sin(angle) * 0.13),
			Vector3(0.06, 0.025, 0.06),
			ink
		)
	var spring := TorusMesh.new()
	spring.inner_radius = 0.32
	spring.outer_radius = 0.34
	spring.rings = 24
	spring.ring_segments = 6
	_mesh(rotor, spring, Vector3(0, -side * 0.13, 0), ink.lightened(0.15))
	_rod(self, Vector3(side * 0.42, 0.38, axle), pivot.position, 0.05, chrome, 0.65)
	_rod(
		self,
		Vector3(side * 0.41, 0.63, axle),
		pivot.position + Vector3.UP * 0.08,
		0.043,
		Color("ffe2a1"),
		0.3
	)
	if axle > 0:
		var spark := _ellipsoid(
			self,
			pivot.position + Vector3(0, -0.18, 0.25),
			Vector3(0.14, 0.06, 0.26),
			Color("56dfff")
		)
		spark.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark.hide()
		sparks.append(spark)


func _make_driver() -> void:
	var fur := Color("ed853c")
	if animal == "otter":
		fur = Color("8e6758")
	elif animal == "rabbit":
		fur = Color("eee6cf")
	elif animal == "badger":
		fur = Color("6b7890")
	elif animal == "cat":
		fur = Color("d7af6c")
	var cream := Color("fff1db")
	var ink := Color("253345")
	_ellipsoid(self, Vector3(0, 1.08, 0.16), Vector3(0.29, 0.36, 0.25), vehicle_color)
	_ellipsoid(self, Vector3(0, 1.1, -0.07), Vector3(0.21, 0.26, 0.07), cream)
	head = Node3D.new()
	head.position = Vector3(0, 1.64, 0.11)
	add_child(head)
	_ellipsoid(head, Vector3.ZERO, Vector3(0.37, 0.37, 0.33), fur)
	for side in [-1.0, 1.0]:
		var ear_at := Vector3(side * 0.25, 0.31, 0.02)
		if animal == "rabbit":
			_ellipsoid(head, ear_at + Vector3(0, 0.19, 0), Vector3(0.085, 0.34, 0.075), fur)
			_ellipsoid(
				head, ear_at + Vector3(0, 0.19, -0.066), Vector3(0.048, 0.23, 0.02), Color("e6acb8")
			)
		elif animal in ["otter", "badger"]:
			_ellipsoid(head, ear_at, Vector3(0.115, 0.12, 0.08), fur.darkened(0.08))
		else:
			var ear := PrismMesh.new()
			ear.size = Vector3(0.20, 0.32, 0.14)
			var node := _mesh(head, ear, ear_at, fur)
			node.rotation.z = -side * 0.18
			var inside := PrismMesh.new()
			inside.size = Vector3(0.12, 0.21, 0.028)
			var inner := _mesh(head, inside, ear_at + Vector3(0, -0.025, -0.077), cream)
			inner.rotation.z = -side * 0.18
		_ellipsoid(head, Vector3(side * 0.18, -0.13, -0.22), Vector3(0.21, 0.15, 0.15), cream)
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.15, 0.055, -0.30)
		head.add_child(eye)
		eyes.append(eye)
		_ellipsoid(eye, Vector3.ZERO, Vector3(0.102, 0.132, 0.056), Color.WHITE)
		_ellipsoid(eye, Vector3(0, -0.01, -0.052), Vector3(0.057, 0.077, 0.022), Color("268aa2"))
		_ellipsoid(eye, Vector3(0, -0.008, -0.070), Vector3(0.034, 0.052, 0.012), ink)
		_ellipsoid(eye, Vector3(-0.023, 0.03, -0.081), Vector3(0.018, 0.023, 0.009), Color.WHITE)
		_rod(
			head,
			Vector3(side * 0.08, 0.21, -0.29),
			Vector3(side * 0.23, 0.19, -0.25),
			0.023,
			fur.darkened(0.5)
		)
		_rod(self, Vector3(side * 0.25, 1.19, 0.05), Vector3(side * 0.28, 1.0, -0.37), 0.075, fur)
		_ellipsoid(self, Vector3(side * 0.28, 1.0, -0.37), Vector3(0.083, 0.082, 0.085), cream)
	_ellipsoid(head, Vector3(0, -0.08, -0.40), Vector3(0.09, 0.07, 0.07), ink)
	_rod(head, Vector3(-0.12, -0.23, -0.31), Vector3(0.12, -0.23, -0.31), 0.012, ink)
	# Flight goggles sit above the eyes; the face stays readable.
	_rod(
		head,
		Vector3(-0.30, 0.25, -0.10),
		Vector3(0.30, 0.25, -0.10),
		0.05,
		vehicle_color.darkened(0.5)
	)
	for side in [-1.0, 1.0]:
		_ellipsoid(
			head,
			Vector3(side * 0.12, 0.27, -0.25),
			Vector3(0.11, 0.066, 0.057),
			Color("c6edff"),
			0.25
		)
	if animal in ["fox", "cat"]:
		tail = Node3D.new()
		tail.position = Vector3(0.25, 0.88, 0.50)
		tail.rotation.x = -0.4
		add_child(tail)
		_ellipsoid(tail, Vector3(0.15, 0.10, 0.30), Vector3(0.17, 0.20, 0.43), fur)
		_ellipsoid(tail, Vector3(0.17, 0.11, 0.58), Vector3(0.14, 0.17, 0.22), cream)


func set_motion(speed: float, steer: float, boost: bool, drift: bool) -> void:
	motion_speed = speed
	motion_steer = steer
	motion_boost = boost
	motion_drift = drift


func _process(delta: float) -> void:
	animation_time += delta
	wheel_spin_phase = fposmod(wheel_spin_phase + motion_speed * delta / 0.34, TAU)
	for flame in flames:
		flame.visible = motion_boost and motion_speed > 0.5
		flame.scale.z = 0.3 if reduced_motion else 0.25 + sin(animation_time * 30) * 0.08
	for spark in sparks:
		spark.visible = motion_drift and absf(motion_steer) > 0.2 and motion_speed > 1
	detail_check_time -= delta
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera and detail_check_time <= 0:
		_update_detail(camera)
		detail_check_time = 0.2
	if far_detail:
		return
	# Frustum culling still renders whole kart bounds; this only skips unseen animation.
	if camera and camera.global_position.distance_squared_to(global_position) > 225.0:
		if not camera.is_position_in_frustum(global_position + Vector3.UP):
			return
	for i in range(wheel_rotors.size()):
		wheel_rotors[i].quaternion = (
			Quaternion(Vector3.BACK, PI / 2) * Quaternion(Vector3.UP, wheel_spin_phase)
		)
		wheel_pivots[i].rotation.y = (
			-motion_steer * 0.30 if wheel_pivots[i].get_meta("front") else 0
		)
	if head:
		head.rotation.y = lerpf(head.rotation.y, -motion_steer * 0.16, minf(1, delta * 8))
		head.rotation.z = (
			0 if reduced_motion else sin(animation_time * 5) * minf(0.018, motion_speed * 0.001)
		)
	for eye in eyes:
		var blink: float = 0.08 if fposmod(animation_time, 4.3) < 0.10 else 1.0
		eye.scale.y = blink
	if tail and not reduced_motion:
		tail.rotation.y = sin(animation_time * 2.5) * 0.16
	if steering_wheel:
		steering_wheel.rotation.z = -motion_steer * 0.34
