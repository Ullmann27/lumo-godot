extends Node3D
## A lightweight outdoor home for the selected real kart. This is menu scenery,
## not a second race world: no physics bodies, race state or hidden simulation.
const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")
const PAVILION = preload("res://assets/kart/harbor_pavilion/wave_pavilion_lod2.glb")
var elapsed := 0.0
var active := false
var reduced_motion := false
var water: ShaderMaterial
var pennant: ShaderMaterial
var sailboats: Array[Node3D] = []
var gulls: MultiMeshInstance3D
var _materials: Dictionary = {}
var _batches: Dictionary = {}


func build() -> void:
	name = "LumoKartHomePromenade"
	_materials = {
		"sand": _mat(Color("dbb781"), 0.0, 0.85),
		"stone": _mat(Color("b7835e"), 0.0, 0.9),
		"paving": _mat(Color("a59880"), 0.0, 0.82),
		"wood": _mat(Color("81543e"), 0.0, 0.8),
		"cream": _mat(Color("ffefd0"), 0.0, 0.7),
		"roof": _mat(Color("c46742"), 0.0, 0.72),
		"teal": _mat(Color("409ca2"), 0.1, 0.6),
		"grass": _mat(Color("70a96d"), 0.0, 0.92),
		"leaf": _mat(Color("3d8f72"), 0.0, 0.9),
		"road": _mat(Color("53677b"), 0.03, 0.88),
		"gold": _mat(Color("ffd169"), 0.18, 0.4),
		"dark": _mat(Color("345269"), 0.1, 0.75),
	}
	_build_sky()
	_build_water()
	# Wide foreground terrace catches the existing key-light contact shadows.
	_batch_box("paving", Vector3(15.0, 0.30, 13.0), Vector3(0, -0.50, -0.5))
	for x in range(-7, 8):
		_batch_box("sand", Vector3(0.035, 0.014, 13.0), Vector3(x, -0.342, -0.5))
	for z in range(-6, 6):
		_batch_box("sand", Vector3(15.0, 0.014, 0.035), Vector3(0, -0.342, z))
	_batch_box("cream", Vector3(15.4, 0.18, 0.4), Vector3(0, -0.24, 5.8))
	# Low balustrades remain behind the car; its complete chassis stays clear.
	for x in range(-7, 8):
		_batch_box("cream", Vector3(0.16, 0.72, 0.16), Vector3(x, 0.03, 5.9))
	_batch_box("cream", Vector3(15.3, 0.12, 0.18), Vector3(0, 0.43, 5.9))
	for side in [-1, 1]:
		_lantern(Vector3(side * 6.3, -0.34, 3.7))
		_planter(Vector3(side * 6.0, -0.3, -1.8))
	_build_islands()
	_build_route()
	_build_lighthouse(Vector3(-10, 0, 24))
	_build_town()
	var pavilion: Node3D = PAVILION.instantiate()
	pavilion.name = "OriginalHarborWavePavilion"
	pavilion.position = Vector3(15, -0.8, 16)
	pavilion.scale = Vector3.ONE * 0.56
	pavilion.rotation.y = -0.32
	add_child(pavilion)
	for mesh in pavilion.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_flags()
	_build_sailboat(Vector3(-7, -0.66, 13), 0.65, 0.6)
	_build_sailboat(Vector3(9, -0.66, 28), 0.85, -0.5)
	_build_gulls()
	_flush_batches()
	set_meta("original_asset", PAVILION.resource_path)
	set_meta("home_material_families", _materials.size())
	set_meta("home_static_batches", _batches.size())
	visible = false


func set_active(value: bool, motion_reduced: bool) -> void:
	var became_active := value and not active
	var motion_changed := motion_reduced != reduced_motion
	active = value
	visible = value
	reduced_motion = motion_reduced
	if not active:
		return
	if reduced_motion and (became_active or motion_changed):
		elapsed = 0.0
		_update_motion()


func advance(delta: float) -> void:
	if not active or reduced_motion:
		return
	elapsed += clampf(delta, 0.0, 0.1)
	_update_motion()


func _update_motion() -> void:
	if water != null:
		water.set_shader_parameter("elapsed", elapsed)
	if pennant != null:
		pennant.set_shader_parameter("elapsed", elapsed)
	for i in range(sailboats.size()):
		var boat := sailboats[i]
		var anchor: Vector3 = boat.get_meta("anchor")
		boat.position = anchor + Vector3(sin(elapsed * 0.035 + i) * 0.9, sin(elapsed * 0.8 + i) * 0.05, 0)
		boat.rotation.z = sin(elapsed * 0.6 + i) * 0.035
	if is_instance_valid(gulls):
		for i in range(gulls.multimesh.instance_count):
			var phase := elapsed * 0.06 + i * 1.4
			var location := Vector3(sin(phase) * 13.0, 7.0 + sin(phase * 1.7) * 1.4, 22.0 + cos(phase) * 7.0)
			gulls.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -phase), location))


func _build_sky() -> void:
	var sky := MeshInstance3D.new()
	sky.name = "PaintedHarborSkyDome"
	var sphere := SphereMesh.new()
	sphere.radius = 160.0
	sphere.height = 320.0
	sphere.radial_segments = 32
	sphere.rings = 16
	sky.mesh = sphere
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;
varying vec3 direction;
void vertex() { direction = normalize(VERTEX); }
void fragment() {
	vec3 d = normalize(direction);
	float height = smoothstep(-0.08, 0.62, d.y);
	vec3 dusk = mix(vec3(1.0, 0.76, 0.53), vec3(0.22, 0.56, 0.74), height);
	float sun = pow(max(0.0, dot(d, normalize(vec3(-0.45, 0.28, 0.86)))), 160.0);
	ALBEDO = dusk + vec3(0.35, 0.23, 0.09) * sun;
}
"""
	material.shader = shader
	sky.material_override = material
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)


func _build_water() -> void:
	var sea := MeshInstance3D.new()
	sea.name = "HarborWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(280, 280)
	sea.mesh = plane
	sea.position = Vector3(0, -1.0, 45)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float elapsed = 0.0;
varying vec2 water_position;
void vertex() { water_position = VERTEX.xz; }
void fragment() {
	float wave = sin(water_position.x * 1.4 + water_position.y * 0.85 + elapsed * 0.55)
		* sin(water_position.y * 2.1 - elapsed * 0.38);
	float glint = pow(max(wave, 0.0), 10.0);
	float distance_tint = smoothstep(-20.0, 100.0, water_position.y);
	ALBEDO = mix(vec3(0.11, 0.50, 0.61), vec3(0.48, 0.70, 0.70), distance_tint)
		+ vec3(0.28, 0.27, 0.16) * glint;
}
"""
	water = ShaderMaterial.new()
	water.shader = shader
	sea.material_override = water
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)


func _build_islands() -> void:
	var rock := SHAPES.rock()
	for spec in [[Vector3(-17, -2.3, 31), Vector3(12, 4.3, 8)],
		[Vector3(13, -2.2, 36), Vector3(15, 4.0, 9)],
		[Vector3(-6, -2.5, 54), Vector3(17, 7, 10)],
		[Vector3(28, -1.8, 53), Vector3(14, 5, 12)]]:
		var island := _mesh("LayeredHarborIsland", rock, _materials.stone, spec[0])
		island.scale = spec[1]
		var top := _mesh("GrassyHarborCrown", rock, _materials.grass, spec[0] + Vector3(0, 0.55, 0))
		top.scale = Vector3(spec[1].x * 0.94, spec[1].y * 0.9, spec[1].z * 0.94)
	for i in range(9):
		var mountain := _mesh("DistantCoastalPeak", SHAPES.mountain(),
			_mat(Color("83a7a5").lerp(Color("b1c2b1"), float(i % 3) / 3.0), 0.0, 1.0),
			Vector3(-74 + i * 19, -2, 90 + (i % 2) * 14))
		mountain.scale = Vector3(19 + i % 3 * 6, 9 + i % 4 * 4, 13)


func _build_route() -> void:
	var route := Curve3D.new()
	for spec in [[Vector3(-28, 0.8, 18), Vector3(-5, 0, -3), Vector3(5, 0, 3)],
		[Vector3(-11, 1.3, 29), Vector3(-7, -0.2, -1), Vector3(7, 0.2, 1)],
		[Vector3(10, 4.0, 25), Vector3(-7, -1.6, 3), Vector3(7, 1.6, -3)],
		[Vector3(25, 5.1, 32), Vector3(-1, 0, -6), Vector3(1, 0, 6)],
		[Vector3(14, 4.4, 46), Vector3(7, 0, -1), Vector3(-7, 0, 1)]]:
		route.add_point(spec[0], spec[1], spec[2])
	var length := route.get_baked_length()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples := 76
	for i in range(samples):
		var a := route.sample_baked(length * i / samples)
		var b := route.sample_baked(length * (i + 1) / samples)
		var direction := (b - a).normalized()
		var side := direction.cross(Vector3.UP).normalized()
		for vertex in [a - side * 1.55, b - side * 1.55, a + side * 1.55,
			a + side * 1.55, b - side * 1.55, b + side * 1.55]:
			surface.add_vertex(vertex)
		var frame := Basis.looking_at(direction, Vector3.UP)
		for edge in [-1, 1]:
			_batch_transform("cream" if i % 2 == 0 else "teal",
				Transform3D(frame * Basis.from_scale(Vector3(0.18, 0.17, a.distance_to(b) + 0.04)), (a + b) * 0.5 + side * 1.55 * edge))
		if i % 3 == 0:
			_batch_transform("cream", Transform3D(frame * Basis.from_scale(Vector3(0.08, 0.015, 0.55)), (a + b) * 0.5 + Vector3.UP * 0.03))
		if i % 8 == 0:
			var height := maxf(0.8, a.y + 1.2)
			_batch_box("sand", Vector3(0.64, height, 0.72), Vector3(a.x, a.y - height * 0.5 - 0.1, a.z))
	surface.generate_normals()
	var road := _mesh("HomeScenicCoastalRoad", surface.commit(), _materials.road, Vector3.ZERO)
	road.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	# A loop is a distant visual landmark, never presented as drivable menu input.
	var loop := TorusMesh.new()
	loop.inner_radius = 4.45
	loop.outer_radius = 4.92
	loop.rings = 48
	loop.ring_segments = 8
	var loop_mesh := _mesh("DistantCoastalLoop", loop, _materials.teal, Vector3(-23, 5.3, 38))
	loop_mesh.rotation.x = PI * 0.5
	_batch_box("sand", Vector3(0.7, 5.5, 0.8), Vector3(-26.5, 1.6, 38))
	_batch_box("sand", Vector3(0.7, 5.5, 0.8), Vector3(-19.5, 1.6, 38))


func _build_lighthouse(location: Vector3) -> void:
	for i in range(5):
		_cylinder("HarborLighthouse", 1.1 - i * 0.08, 1.25,
			location + Vector3(0, i * 1.25, 0), _materials.cream if i % 2 == 0 else _materials.roof)
	_cylinder("LighthouseLantern", 0.98, 0.9, location + Vector3(0, 6.1, 0), _materials.gold)
	_cylinder("LighthouseRoof", 1.22, 0.24, location + Vector3(0, 6.7, 0), _materials.teal)
	for i in range(8):
		var angle := i * TAU / 8.0
		_batch_box("dark", Vector3(0.08, 0.95, 0.08), location + Vector3(cos(angle) * 0.91, 6.1, sin(angle) * 0.91))


func _build_town() -> void:
	for i in range(8):
		var location := Vector3(-19.0 + i * 2.3, 1.0, 32.0 + sin(i * 1.3) * 2.5)
		var height := 2.4 + (i % 3) * 0.8
		_batch_box("cream" if i % 2 == 0 else "sand", Vector3(1.8, height, 2.1), location + Vector3.UP * height * 0.5)
		var roof := _mesh("HarborTerracottaRoof", _roof_mesh(), _materials.roof, location + Vector3.UP * height)
		roof.scale = Vector3(1.15, 1.0, 1.25)
		for floor_index in range(2):
			for column in [-1, 1]:
				_batch_box("teal", Vector3(0.32, 0.5, 0.025), location + Vector3(column * 0.44, 0.65 + floor_index * 1.1, -1.065))
	for i in range(11):
		var location := Vector3(-24 + i * 5.0, 1.3, 39 + (i % 3) * 3)
		_cylinder("CoastalTreeTrunk", 0.16, 2.8, location + Vector3.UP, _materials.wood)
		var canopy := _mesh("CoastalTreeCrown", SHAPES.crown(), _materials.leaf, location + Vector3.UP * 2.8)
		canopy.scale = Vector3(1.2, 1.4, 1.2)


func _build_flags() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform float elapsed = 0.0;
void vertex() { VERTEX.z += sin(UV.x * 5.0 + elapsed * 1.7) * UV.x * 0.11; }
void fragment() {
	float stripe = step(0.5, fract((UV.x + UV.y) * 3.0));
	ALBEDO = mix(vec3(0.98, 0.72, 0.26), vec3(0.1, 0.50, 0.57), stripe);
	ROUGHNESS = 0.9;
}
"""
	pennant = ShaderMaterial.new()
	pennant.shader = shader
	for side in [-1, 1]:
		var location := Vector3(side * 5.2, 0, 7.2)
		_cylinder("PromenadeFlagpole", 0.045, 3.6, location + Vector3.UP * 1.4, _materials.cream)
		var cloth := PlaneMesh.new()
		cloth.size = Vector2(1.4, 0.72)
		cloth.subdivide_width = 8
		var flag := _mesh("LivingHarborPennant", cloth, pennant, location + Vector3(0.65, 2.7, 0))
		flag.rotation.x = PI * 0.5


func _build_sailboat(location: Vector3, size_factor: float, yaw: float) -> void:
	var boat := Node3D.new()
	boat.name = "HarborSailboat"
	boat.position = location
	boat.scale = Vector3.ONE * size_factor
	boat.rotation.y = yaw
	boat.set_meta("anchor", location)
	add_child(boat)
	var hull := _mesh("OriginalLumoBoatHull", SHAPES.boat_hull(), _materials.wood, Vector3.ZERO)
	hull.reparent(boat, false)
	var sail := _mesh("CoastalSail", SHAPES.sail(), _materials.cream, Vector3(0, 0.3, 0))
	sail.reparent(boat, false)
	sailboats.append(boat)


func _build_gulls() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(-0.7, 0.15, 0.15), Vector3(-0.2, 0, 0), Vector3(0, 0.04, -0.1),
		Vector3(0, 0.04, -0.1), Vector3(0.2, 0, 0), Vector3(0.7, 0.15, 0.15)]:
		surface.add_vertex(point)
	surface.generate_normals()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = surface.commit()
	multimesh.instance_count = 5
	gulls = MultiMeshInstance3D.new()
	gulls.name = "CoastalGulls"
	gulls.multimesh = multimesh
	var gull_material: StandardMaterial3D = _materials.cream.duplicate()
	gull_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	gulls.material_override = gull_material
	gulls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gulls)
	_update_motion()


func _lantern(location: Vector3) -> void:
	_cylinder("PromenadeLanternPost", 0.06, 2.8, location + Vector3.UP * 1.4, _materials.dark)
	_batch_box("gold", Vector3(0.32, 0.42, 0.32), location + Vector3.UP * 2.85)
	_batch_box("dark", Vector3(0.43, 0.09, 0.43), location + Vector3.UP * 3.1)


func _planter(location: Vector3) -> void:
	_cylinder("StonePlanter", 0.64, 0.65, location + Vector3.UP * 0.25, _materials.sand)
	var bush := _mesh("PromenadeTopiary", SHAPES.crown(), _materials.leaf, location + Vector3.UP * 0.9)
	bush.scale = Vector3(0.8, 0.6, 0.8)


func _roof_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for points in [[Vector3(-1, 0, -1), Vector3(0, 0.7, -1), Vector3(-1, 0, 1)],
		[Vector3(-1, 0, 1), Vector3(0, 0.7, -1), Vector3(0, 0.7, 1)],
		[Vector3(0, 0.7, -1), Vector3(1, 0, -1), Vector3(0, 0.7, 1)],
		[Vector3(0, 0.7, 1), Vector3(1, 0, -1), Vector3(1, 0, 1)],
		[Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(0, 0.7, -1)],
		[Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(0, 0.7, 1)]]:
		for point in points:
			surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()


func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _mesh(label: String, mesh: Mesh, material: Material, location: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _cylinder(label: String, radius: float, height: float, location: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.06
	mesh.height = height
	mesh.radial_segments = 16
	_mesh(label, mesh, material, location)


func _batch_box(family: String, dimensions: Vector3, location: Vector3) -> void:
	_batch_transform(family, Transform3D(Basis.IDENTITY.scaled(dimensions), location))


func _batch_transform(family: String, transform: Transform3D) -> void:
	if not _batches.has(family):
		_batches[family] = []
	_batches[family].append(transform)


func _flush_batches() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	for family in _batches:
		var data := MultiMesh.new()
		data.transform_format = MultiMesh.TRANSFORM_3D
		data.mesh = cube
		data.instance_count = _batches[family].size()
		for i in range(data.instance_count):
			data.set_instance_transform(i, _batches[family][i])
		var batch := MultiMeshInstance3D.new()
		batch.name = "HomeBatch_" + family
		batch.multimesh = data
		batch.material_override = _materials[family]
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
