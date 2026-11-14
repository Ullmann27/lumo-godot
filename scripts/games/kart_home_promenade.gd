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
var _canopy_batches: Dictionary = {"leaf": [], "grass": []}


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
	_build_clouds()
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
	_build_lighthouse(Vector3(-32, 0.55, 61))
	_build_town()
	var pavilion: Node3D = PAVILION.instantiate()
	pavilion.name = "OriginalHarborWavePavilion"
	pavilion.position = Vector3(-20, -0.35, 50)
	pavilion.scale = Vector3.ONE * 0.46
	pavilion.rotation.y = PI - 0.32
	add_child(pavilion)
	_batch_box("wood", Vector3(8.5, 0.5, 4.8), pavilion.position - Vector3.UP * 0.25)
	for side in [-1, 1]:
		_batch_box("sand", Vector3(0.45, 1.25, 0.45), pavilion.position + Vector3(side * 3.7, -0.7, -1.9))
	for mesh in pavilion.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_flags()
	_build_sailboat(Vector3(-7, -0.66, 13), 0.65, 0.6)
	_build_sailboat(Vector3(9, -0.66, 28), 0.85, -0.5)
	_build_gulls()
	_flush_batches()
	_flush_canopies()
	set_meta("original_asset", PAVILION.resource_path)
	set_meta("home_material_families", _materials.size())
	set_meta("home_static_batches", _batches.size() + _canopy_batches.size() + 1)
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
	float height = smoothstep(-0.12, 0.22, d.y);
	vec3 blue = mix(vec3(0.61, 0.82, 0.95), vec3(0.065, 0.34, 0.70), height);
	float horizon = exp(-abs(d.y + 0.035) * 18.0);
	vec3 sky = mix(blue, vec3(1.0, 0.84, 0.68), horizon * 0.22);
	float sun = pow(max(0.0, dot(d, normalize(vec3(-0.45, 0.10, 0.86)))), 220.0);
	ALBEDO = sky + vec3(0.18, 0.15, 0.09) * sun;
}
"""
	material.shader = shader
	sky.material_override = material
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)


func _build_clouds() -> void:
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 16
	puff.rings = 8
	var transforms: Array[Transform3D] = []
	for spec in [[Vector3(-45, 8.5, 115), 1.0], [Vector3(-3, 10, 130), 1.25],
		[Vector3(-67, 7.0, 105), 0.85], [Vector3(24, 8.8, 98), 0.9]]:
		var center: Vector3 = spec[0]
		var size_factor: float = spec[1]
		for lobe in [[Vector3(-5.2, -0.2, 0), Vector3(4.8, 1.25, 2.7)],
			[Vector3(-1.5, 0.8, 0.4), Vector3(4.3, 2.0, 3.1)],
			[Vector3(2.5, 0.4, -0.2), Vector3(4.8, 1.7, 2.9)],
			[Vector3(6.0, -0.3, 0), Vector3(3.4, 1.0, 2.2)]]:
			transforms.append(Transform3D(Basis.from_scale(lobe[1] * size_factor), center + lobe[0] * size_factor))
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, fog_disabled;
varying float cloud_height;
void vertex() { cloud_height = NORMAL.y; }
void fragment() {
	float illumination = smoothstep(-0.65, 0.65, cloud_height);
	ALBEDO = mix(vec3(0.57, 0.73, 0.83), vec3(1.0, 0.97, 0.89), illumination);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var data := MultiMesh.new()
	data.transform_format = MultiMesh.TRANSFORM_3D
	data.mesh = puff
	data.instance_count = transforms.size()
	for i in range(transforms.size()):
		data.set_instance_transform(i, transforms[i])
	var clouds := MultiMeshInstance3D.new()
	clouds.name = "HarborLayeredClouds"
	clouds.multimesh = data
	clouds.material_override = material
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(clouds)


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
			_mat(Color("83a8ba").lerp(Color("c2d1d3"), float(i % 3) / 3.0), 0.0, 1.0),
			Vector3(-74 + i * 19, -2, 90 + (i % 2) * 14))
		mountain.scale = Vector3(19 + i % 3 * 6, 5.0 + i % 4 * 1.3, 13)


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
	var loop_mesh := _mesh("DistantCoastalLoop", loop, _materials.teal, Vector3(-18, 4.1, 83))
	loop_mesh.rotation.x = PI * 0.5
	loop_mesh.scale = Vector3.ONE * 0.8
	_batch_box("sand", Vector3(0.55, 4.2, 0.65), Vector3(-20.8, 1.3, 83))
	_batch_box("sand", Vector3(0.55, 4.2, 0.65), Vector3(-15.2, 1.3, 83))


func _build_lighthouse(location: Vector3) -> void:
	var island := _mesh("LighthouseRockyIslet", SHAPES.rock(), _materials.stone, location - Vector3.UP * 1.55)
	island.scale = Vector3(4.2, 1.3, 3.5)
	var tower := Node3D.new()
	tower.name = "HarborLighthouseLandmark"
	tower.position = location
	tower.scale = Vector3.ONE * 0.72
	add_child(tower)
	for i in range(5):
		var section := _cylinder("HarborLighthouse", 1.1 - i * 0.08, 1.25,
			Vector3(0, i * 1.25, 0), _materials.cream if i % 2 == 0 else _materials.roof)
		section.reparent(tower, false)
	_cylinder("LighthouseFoundation", 1.32, 0.22, Vector3(0, -0.5, 0), _materials.sand).reparent(tower, false)
	_cylinder("LighthouseGallery", 1.18, 0.14, Vector3(0, 5.62, 0), _materials.cream).reparent(tower, false)
	_cylinder("LighthouseLantern", 0.83, 0.9, Vector3(0, 6.1, 0), _materials.gold).reparent(tower, false)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.05
	roof.bottom_radius = 1.22
	roof.height = 0.52
	roof.radial_segments = 16
	_mesh("LighthouseRoof", roof, _materials.teal, Vector3(0, 6.78, 0)).reparent(tower, false)
	var lantern_frame := Transform3D(Basis.from_scale(Vector3.ONE * 0.72), location)
	for i in range(8):
		var angle := i * TAU / 8.0
		_detail_box("dark", Vector3(0.08, 0.95, 0.08), lantern_frame, Vector3(cos(angle) * 0.91, 6.1, sin(angle) * 0.91))
	_detail_box("cream", Vector3(0.55, 1.18, 0.10), lantern_frame, Vector3(0, 0.05, -1.11))
	_detail_box("teal", Vector3(0.39, 1.04, 0.08), lantern_frame, Vector3(0, 0.04, -1.18))


func _build_town() -> void:
	_batch_box("stone", Vector3(20.2, 0.9, 9.2), Vector3(-7.8, -0.05, 40.4))
	_batch_box("cream", Vector3(20.4, 0.12, 0.26), Vector3(-7.8, 0.42, 35.8))
	for i in range(8):
		var location := Vector3(-16.0 + i * 2.35, 0.4, 39.0 + sin(i * 1.3) * 1.6)
		var height := 2.5 + (i % 3) * 0.65
		_batch_box("cream" if i % 2 == 0 else "sand", Vector3(1.8, height, 2.1), location + Vector3.UP * height * 0.5)
		_batch_box("cream", Vector3(2.02, 0.12, 2.28), location + Vector3.UP * (height - 0.02))
		_batch_box("stone", Vector3(1.9, 0.18, 2.2), location + Vector3.UP * 0.09)
		var roof := _mesh("HarborTerracottaRoof", _roof_mesh(), _materials.roof, location + Vector3.UP * height)
		roof.scale = Vector3(1.15, 1.0, 1.25)
		_batch_box("stone", Vector3(0.26, 0.58, 0.30), location + Vector3(0.52, height + 0.42, 0.28))
		_batch_box("cream", Vector3(0.36, 0.10, 0.40), location + Vector3(0.52, height + 0.75, 0.28))
		for floor_index in range(3 if height > 3.5 else 2):
			for column in [-1, 1]:
				_window_detail(location + Vector3(column * 0.51, 0.88 + floor_index * 1.1, -1.08), 0.0)
			_window_detail(location + Vector3(0.93, 0.88 + floor_index * 1.1, 0.25), -PI * 0.5)
		var facade := Transform3D(Basis.IDENTITY, location)
		_detail_box("cream", Vector3(0.54, 1.24, 0.10), facade, Vector3(0, 0.62, -1.09))
		_detail_box("wood" if i % 2 == 0 else "teal", Vector3(0.40, 1.12, 0.07), facade, Vector3(0, 0.60, -1.16))
		_detail_box("dark", Vector3(0.27, 0.34, 0.04), facade, Vector3(0, 0.88, -1.21))
		_detail_box("gold", Vector3(0.06, 0.06, 0.08), facade, Vector3(0.13, 0.53, -1.24))
		_detail_box("cream", Vector3(0.74, 0.13, 0.48), facade, Vector3(0, 0.04, -1.25))
		if i % 3 == 0:
			_detail_box("cream", Vector3(1.66, 0.14, 0.62), facade, Vector3(0, 1.61, -1.30))
			_detail_box("dark", Vector3(1.66, 0.065, 0.06), facade, Vector3(0, 2.14, -1.60))
			for column in range(5):
				_detail_box("dark", Vector3(0.055, 0.50, 0.055), facade, Vector3(-0.74 + column * 0.37, 1.89, -1.60))
			for side in [-1, 1]:
				_detail_box("dark", Vector3(0.055, 0.065, 0.57), facade, Vector3(side * 0.79, 2.14, -1.32))
		elif i % 3 == 1:
			var awning := Transform3D(Basis(Vector3.RIGHT, -0.18), location + Vector3(0, 1.34, -1.28))
			_detail_box("teal", Vector3(0.86, 0.09, 0.68), awning, Vector3.ZERO)
			for side in [-1, 1]:
				_detail_box("wood", Vector3(0.055, 1.30, 0.055), facade, Vector3(side * 0.36, 0.66, -1.51))
	var grove: Array[Vector3] = [Vector3(-14, 2.6, 53), Vector3(-10, 2.8, 54),
		Vector3(-6, 2.9, 55), Vector3(-2, 2.7, 53), Vector3(2, 2.6, 54),
		Vector3(7, 0.65, 38), Vector3(12, 0.8, 39), Vector3(17, 0.65, 37),
		Vector3(21, 0.5, 39), Vector3(-15, 0.4, 43), Vector3(-9, 0.4, 43)]
	for i in range(grove.size()):
		var location := grove[i]
		_cylinder("CoastalTreeTrunk", 0.16, 2.8, location + Vector3.UP, _materials.wood)
		_cluster_canopy(location + Vector3.UP * 2.8, 1.0 + (i % 3) * 0.08, i * 0.73)


func _window_detail(location: Vector3, yaw: float) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), location)
	_detail_box("cream", Vector3(0.43, 0.65, 0.10), frame, Vector3.ZERO)
	_detail_box("teal", Vector3(0.30, 0.51, 0.045), frame, Vector3(0, 0, -0.07))
	_detail_box("cream", Vector3(0.028, 0.51, 0.028), frame, Vector3(0, 0, -0.11))
	_detail_box("cream", Vector3(0.30, 0.035, 0.028), frame, Vector3(0, 0.04, -0.11))
	_detail_box("cream", Vector3(0.53, 0.075, 0.24), frame, Vector3(0, -0.35, -0.06))
	for side in [-1, 1]:
		_detail_box("wood", Vector3(0.085, 0.59, 0.06), frame, Vector3(side * 0.27, 0, -0.015))


func _cluster_canopy(center: Vector3, size_factor: float, yaw: float) -> void:
	var rotation := Basis(Vector3.UP, yaw)
	var lobes := [[Vector3(-0.48, -0.10, 0.05), Vector3(0.85, 0.78, 0.80)],
		[Vector3(0.40, 0.10, 0.15), Vector3(0.94, 0.95, 0.86)],
		[Vector3(-0.08, 0.55, -0.10), Vector3(0.67, 0.86, 0.70)],
		[Vector3(0.45, -0.35, -0.40), Vector3(0.70, 0.63, 0.75)],
		[Vector3(-0.33, 0.20, 0.50), Vector3(0.70, 0.80, 0.70)]]
	for i in range(lobes.size()):
		var dimensions: Vector3 = lobes[i][1] * size_factor
		var location: Vector3 = center + rotation * (lobes[i][0] * size_factor)
		_canopy_batches["grass" if i == 2 else "leaf"].append(Transform3D(rotation * Basis.from_scale(dimensions), location))


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


func _cylinder(label: String, radius: float, height: float, location: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.06
	mesh.height = height
	mesh.radial_segments = 16
	return _mesh(label, mesh, material, location)


func _detail_box(family: String, dimensions: Vector3, frame: Transform3D, offset: Vector3) -> void:
	_batch_transform(family, frame * Transform3D(Basis.from_scale(dimensions), offset))


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


func _flush_canopies() -> void:
	var crown := SHAPES.crown()
	for family in _canopy_batches:
		var data := MultiMesh.new()
		data.transform_format = MultiMesh.TRANSFORM_3D
		data.mesh = crown
		data.instance_count = _canopy_batches[family].size()
		for i in range(data.instance_count):
			data.set_instance_transform(i, _canopy_batches[family][i])
		var batch := MultiMeshInstance3D.new()
		batch.name = "CoastalCanopy_" + family
		batch.multimesh = data
		batch.material_override = _materials[family]
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
