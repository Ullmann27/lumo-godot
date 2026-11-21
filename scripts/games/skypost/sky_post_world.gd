extends Node3D
## Builds Wolkenhafen from sky_post_layout.gd: morning sky, sun, the endless
## cloud sea, floating islands with houses, mailboxes and address boards, the
## post office with its launch deck, lighthouse, windmill, zeppelin mast, trees,
## lanterns, cumulus clouds and the shimmering updraft columns. Mode objects
## (ring gates, star sparks, photo frames, the delivery beacon) are added and
## removed by sky_post.gd through the functions at the end.

const MODELS = preload("res://scripts/games/skypost/sky_post_models.gd")
const SHADERS = preload("res://scripts/games/skypost/sky_post_shaders.gd")
const LAYOUT = preload("res://scripts/games/skypost/sky_post_layout.gd")
const FONT = preload("res://assets/fonts/Nunito-Black.ttf")

const SUN_DIR := Vector3(0.55, 0.32, -0.77)
const WALLS: Array[Color] = [
	Color("f4d8a8"),
	Color("f6b9a2"),
	Color("acd8ea"),
	Color("c9e6b1"),
	Color("efd9f2"),
	Color("ffe38c")
]
const ROOFS: Array[Color] = [
	Color("d0573d"), Color("3f72bd"), Color("3f9a7d"), Color("8b52b2"), Color("e0823a")
]
const CLOUDS := {"low": 9, "medium": 16, "high": 24}

var layout
var profile: String = "medium"
var reduced_motion: bool = false
var sun: DirectionalLight3D
var environment: Environment
var cloud_sea: MeshInstance3D
var islands: Array[Node3D] = []
var houses: Array[Node3D] = []
var mailboxes: Array[Node3D] = []
var boards: Array[Node3D] = []
var board_faces: Array[Node3D] = []
var board_glow: Array[StandardMaterial3D] = []
var flags: Array[Node3D] = []
var flaps: Array[Node3D] = []
var sails: Node3D
var zeppelin: Node3D
var zeppelin_rest := Transform3D.IDENTITY
var updrafts: Array[MeshInstance3D] = []
var clouds: Array[MeshInstance3D] = []
## Mode objects.
var gates: Array[Node3D] = []
var gate_materials: Array[ShaderMaterial] = []
var sparks: MultiMeshInstance3D
var spark_positions := PackedVector3Array()
var spark_taken := PackedByteArray()
var photo_frames: Array[Node3D] = []
var beacon: MeshInstance3D
var markers: Array[MeshInstance3D] = []
var preview: MeshInstance3D
var build_ms: int = 0
var _build_steps: Array[Callable] = []
var _build_index: int = 0
var _face_cache: Dictionary = {}
var _clock: float = 0.0
var _materials: Dictionary = {}


## Starts building; call build_step() until it returns true (spread over frames).
func begin_build(world_profile: String, calm: bool) -> void:
	profile = world_profile
	reduced_motion = calm
	layout = LAYOUT.build()
	_build_steps = [_make_sky, _make_cloud_sea, _make_islands, _refine, _make_landmarks]
	for index in range(LAYOUT.DISTRICTS.size()):
		_build_steps.append(_make_district.bind(index))
	_build_steps += [_make_greenery, _make_clouds, _make_updrafts]
	_build_index = 0


func build_step() -> bool:
	if _build_index >= _build_steps.size():
		return true
	var started: int = Time.get_ticks_msec()
	_build_steps[_build_index].call()
	_build_index += 1
	build_ms += Time.get_ticks_msec() - started
	return _build_index >= _build_steps.size()


func build_all(world_profile: String, calm: bool) -> void:
	begin_build(world_profile, calm)
	while not build_step():
		pass


# ------------------------------------------------------------------ sky, light, cloud sea


func _make_sky() -> void:
	var holder := WorldEnvironment.new()
	holder.name = "Environment"
	environment = Environment.new()
	var sky := Sky.new()
	sky.sky_material = SHADERS.material("SKY", {"sun_dir": SUN_DIR})
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9cdf0")
	environment.ambient_light_energy = 0.48
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 4.2
	environment.glow_enabled = profile != "low"
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 1.1
	environment.fog_enabled = profile != "low"
	environment.fog_light_color = Color("f6dcc6")
	environment.fog_density = 0.0008
	environment.fog_sky_affect = 0.0
	environment.fog_aerial_perspective = 0.15
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.14
	environment.adjustment_contrast = 1.08
	holder.environment = environment
	add_child(holder)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("fff0d8")
	sun.light_energy = 1.25
	sun.look_at_from_position(Vector3.ZERO, -SUN_DIR, Vector3.UP)
	sun.shadow_enabled = profile != "low"
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0 if profile == "high" else 60.0
	sun.shadow_blur = 1.2
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.light_color = Color("9fc2ff")
	fill.light_energy = 0.22
	fill.look_at_from_position(Vector3.ZERO, Vector3(-0.3, -0.6, 0.6), Vector3.UP)
	add_child(fill)


func _make_cloud_sea() -> void:
	cloud_sea = MeshInstance3D.new()
	cloud_sea.name = "CloudSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2200, 2200)
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	cloud_sea.mesh = plane
	cloud_sea.material_override = SHADERS.material("CLOUD_SEA", {"sun_dir": SUN_DIR})
	cloud_sea.position = Vector3(0, LAYOUT.CLOUD_SEA_Y, 0)
	cloud_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloud_sea)


# ------------------------------------------------------------------ islands


func _island_materials() -> Dictionary:
	var detail: float = 0.0 if profile == "low" else 1.0
	return {
		"SP_Grass": SHADERS.material("GRASS", {"detail": detail}),
		"SP_Rock": SHADERS.material("ROCK", {"detail": detail}),
	}


func _make_islands() -> void:
	var overrides: Dictionary = _island_materials()
	for index in range(layout.islands.size()):
		var island: Dictionary = layout.islands[index]
		var scale: float = float(island.scale)
		var node: Node3D = MODELS.instance(
			"insel_%d" % int(island.model), profile, overrides, maxf(1.0, scale * 0.6)
		)
		node.name = "Island_" + str(island.id)
		node.position = island.at
		node.rotation.y = float(island.yaw)
		node.scale = Vector3(scale, scale * 0.85, scale)
		add_child(node)
		islands.append(node)


## Real meadow height below [param p] from the island's finest mesh.
func ground_at(p: Vector3) -> float:
	var best: float = NAN
	for index in range(islands.size()):
		var island: Dictionary = layout.islands[index]
		var at: Vector3 = island.at
		if Vector2(p.x - at.x, p.z - at.z).length() > float(island.radius) * 1.05:
			continue
		var faces: PackedVector3Array = _faces(index)
		var from := Vector3(p.x, at.y + 20.0, p.z)
		for i in range(0, faces.size(), 3):
			var a: Vector3 = faces[i]
			var b: Vector3 = faces[i + 1]
			var c: Vector3 = faces[i + 2]
			if maxf(a.x, maxf(b.x, c.x)) < p.x or minf(a.x, minf(b.x, c.x)) > p.x:
				continue
			if maxf(a.z, maxf(b.z, c.z)) < p.z or minf(a.z, minf(b.z, c.z)) > p.z:
				continue
			var hit: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, a, b, c)
			if hit is Vector3 and (is_nan(best) or (hit as Vector3).y > best):
				best = (hit as Vector3).y
	return best


func _faces(index: int) -> PackedVector3Array:
	if _face_cache.has(index):
		return _face_cache[index]
	var result := PackedVector3Array()
	var node: Node3D = islands[index]
	var lod := (
		node.get_node_or_null("insel_%d_lod0" % int(layout.islands[index].model)) as MeshInstance3D
	)
	if lod != null and lod.mesh != null:
		var xform: Transform3D = node.transform * lod.transform
		for v in lod.mesh.get_faces():
			result.append(xform * v)
	_face_cache[index] = result
	return result


func _refine() -> void:
	layout.refine_heights(ground_at)


# ------------------------------------------------------------------ landmarks


func _make_landmarks() -> void:
	for landmark in layout.landmarks:
		var overrides: Dictionary = {}
		if str(landmark.model) == "postamt":
			overrides = {"SP_Wall": _flat(Color("f6e3b4")), "SP_Roof": _flat(Color("3d5f9e"))}
		var node: Node3D = MODELS.instance(str(landmark.model), profile, overrides, 1.6)
		node.name = "Landmark_" + str(landmark.model)
		node.position = landmark.pos + Vector3(0, -0.15, 0)
		node.rotation.y = float(landmark.yaw)
		add_child(node)
		match str(landmark.model):
			"windmuehle":
				sails = MODELS.part(node, "Sails")
			"zeppelinmast":
				zeppelin = MODELS.part(node, "Zeppelin")
				if zeppelin != null:
					zeppelin_rest = zeppelin.transform
			"leuchtturm":
				var lamp := OmniLight3D.new()
				lamp.position = Vector3(0, 16.8, 0)
				lamp.light_color = Color("ffe6a0")
				lamp.light_energy = 1.4
				lamp.omni_range = 9.0
				lamp.visible = profile == "high"
				node.add_child(lamp)
	# Lanterns along the launch deck and around the harbour.
	var deck: Vector3 = layout.post_deck.pos
	for side in [-1.0, 1.0]:
		for k in range(2):
			var lamp: Node3D = MODELS.instance("laterne", profile)
			lamp.position = deck + Vector3(side * 2.6, -0.95, 4.0 + float(k) * 6.0)
			add_child(lamp)


func _flat(colour: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var key: String = colour.to_html() + str(roughness)
	if not _materials.has(key):
		var made := StandardMaterial3D.new()
		made.albedo_color = colour
		made.roughness = roughness
		_materials[key] = made
	return _materials[key]


func _make_district(index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711 + index * 31
	for house in layout.district_houses(index):
		var wall: Color = WALLS[(index * 2 + int(house.slot)) % WALLS.size()]
		var roof: Color = ROOFS[(index + int(house.slot) * 2) % ROOFS.size()]
		var node: Node3D = MODELS.instance(
			"haus_" + str(house.kind),
			profile,
			{"SP_Wall": _flat(wall), "SP_Roof": _flat(roof, 0.6)}
		)
		node.name = "House_%d_%d" % [index, int(house.slot)]
		node.position = house.pos + Vector3(0, -0.3, 0)
		node.rotation.y = float(house.yaw)
		add_child(node)
		houses.append(node)
		var box: Node3D = MODELS.instance("briefkasten", profile)
		box.name = "Mailbox_%d_%d" % [index, int(house.slot)]
		box.position = house.mailbox + Vector3(0, -0.05, 0)
		box.rotation.y = float(house.yaw)
		add_child(box)
		mailboxes.append(box)
		flags.append(MODELS.part(box, "Flag"))
		flaps.append(MODELS.part(box, "Flap"))
		var board: Node3D = MODELS.instance("adresstafel", profile)
		board.name = "Board_%d_%d" % [index, int(house.slot)]
		board.position = house.board + Vector3(0, -0.05, 0)
		add_child(board)
		boards.append(board)
		var face: Node3D = MODELS.part(board, "Board")
		if face == null:
			face = Node3D.new()
			face.position = Vector3(0, 4.1, 0)
			board.add_child(face)
		board_faces.append(face)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("ffd75e")
		var ring := MeshInstance3D.new()
		ring.name = "Glow"
		var torus := TorusMesh.new()
		torus.inner_radius = 1.05
		torus.outer_radius = 1.22
		torus.rings = 24
		torus.ring_segments = 6
		ring.mesh = torus
		ring.rotation.x = PI * 0.5
		ring.material_override = glow
		ring.visible = false
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		face.add_child(ring)
		board_glow.append(glow)


func house_index(district: int, slot: int) -> int:
	for index in range(layout.houses.size()):
		if (
			int(layout.houses[index].district) == district
			and int(layout.houses[index].slot) == slot
		):
			return index
	return -1


# ------------------------------------------------------------------ greenery, clouds, updrafts


func _make_greenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	var per_island: int = 3 if profile == "low" else 6 if profile == "medium" else 9
	for index in range(layout.islands.size()):
		var island: Dictionary = layout.islands[index]
		var at: Vector3 = island.at
		var radius: float = float(island.radius)
		var count: int = int(per_island * clampf(float(island.scale) / 1.6, 0.5, 1.8))
		var placed: int = 0
		for attempt in range(count * 6):
			if placed >= count:
				break
			var angle: float = rng.randf() * TAU
			var r: float = radius * sqrt(rng.randf_range(0.04, 0.8))
			var p := Vector3(at.x + sin(angle) * r, 0, at.z + cos(angle) * r)
			if _near_building(p, 5.5):
				continue
			var y: float = ground_at(p)
			if is_nan(y):
				continue
			p.y = y - 0.1
			var kind: String = "baum_rund" if rng.randf() < 0.62 else "baum_schlank"
			var tree: Node3D = MODELS.instance(kind, profile, {}, 0.8)
			tree.position = p
			tree.rotation.y = rng.randf() * TAU
			tree.scale = (
				Vector3.ONE * rng.randf_range(0.75, 1.25) * clampf(float(island.scale), 0.6, 1.3)
			)
			add_child(tree)
			placed += 1


func _near_building(p: Vector3, distance: float) -> bool:
	for pillar in layout.pillars:
		var at: Vector3 = pillar.at
		if Vector2(p.x - at.x, p.z - at.z).length() < float(pillar.r) + distance:
			return true
	for house in layout.houses:
		for key in ["mailbox", "board"]:
			var q: Vector3 = house[key]
			if Vector2(p.x - q.x, p.z - q.z).length() < distance * 0.6:
				return true
	var deck: Vector3 = layout.post_deck.pos
	if absf(p.x - deck.x) < 4.0 and p.z < deck.z + 12.0 and p.z > deck.z - 12.0:
		return true
	return false


func _make_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var shapes: Array[ArrayMesh] = []
	for shape in range(4):
		shapes.append(_cloud_mesh(rng, 5 + shape))
	var material: ShaderMaterial = SHADERS.material("CLOUD", {"sun_dir": SUN_DIR})
	var count: int = int(CLOUDS.get(profile, 16))
	for index in range(count):
		var cloud := MeshInstance3D.new()
		cloud.name = "Cloud_%d" % index
		cloud.mesh = shapes[index % shapes.size()]
		cloud.material_override = material
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle: float = rng.randf() * TAU
		var distance: float = rng.randf_range(60.0, 330.0)
		var p := Vector3(sin(angle) * distance, rng.randf_range(-24.0, 70.0), cos(angle) * distance)
		for attempt in range(8):
			if not layout.blocked(p, 18.0) and not _near_route(p):
				break
			angle = rng.randf() * TAU
			distance = rng.randf_range(80.0, 330.0)
			p = Vector3(sin(angle) * distance, rng.randf_range(-24.0, 70.0), cos(angle) * distance)
		cloud.position = p
		cloud.rotation.y = rng.randf() * TAU
		cloud.scale = Vector3.ONE * rng.randf_range(1.3, 3.4)
		add_child(cloud)
		clouds.append(cloud)


func _near_route(p: Vector3) -> bool:
	for gate in LAYOUT.GATES:
		if gate.distance_to(p) < 30.0:
			return true
	return false


func _cloud_mesh(rng: RandomNumberGenerator, blobs: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 14 if profile == "low" else 20
	sphere.rings = 8 if profile == "low" else 11
	var arrays: Array = sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.35
	for blob in range(blobs):
		var centre := Vector3(
			rng.randf_range(-6, 6), rng.randf_range(0, 2.2), rng.randf_range(-3.5, 3.5)
		)
		if blob == 0:
			centre = Vector3.ZERO
		var size: float = rng.randf_range(2.6, 4.4) * (1.25 if blob == 0 else 1.0)
		var base: int = 0
		for i in indices:
			var v: Vector3 = verts[i] * size
			var n: Vector3 = normals[i]
			v += n * noise.get_noise_3dv(v + centre) * size * 0.22
			var world: Vector3 = v + centre
			# Flat-ish bottoms like real cumulus.
			if world.y < -1.2:
				world.y = -1.2 + (world.y + 1.2) * 0.25
			tool.set_normal(n)
			tool.add_vertex(world)
			base += 1
	tool.generate_normals()
	return tool.commit()


func _make_updrafts() -> void:
	for index in range(LAYOUT.UPDRAFTS.size()):
		var column: Vector4 = LAYOUT.UPDRAFTS[index]
		var height: float = column.w - LAYOUT.CLOUD_SEA_Y
		var shaft := MeshInstance3D.new()
		shaft.name = "Updraft_%d" % index
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = column.z
		cylinder.bottom_radius = column.z * 1.15
		cylinder.height = height
		cylinder.radial_segments = 28
		cylinder.rings = 1
		cylinder.cap_top = false
		cylinder.cap_bottom = false
		shaft.mesh = cylinder
		shaft.material_override = SHADERS.material(
			"UPDRAFT", {"strength": 0.42 if profile != "low" else 0.36}
		)
		shaft.position = Vector3(column.x, LAYOUT.CLOUD_SEA_Y + height * 0.5, column.y)
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shaft)
		updrafts.append(shaft)
		var motes := MultiMeshInstance3D.new()
		motes.name = "Motes_%d" % index
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		var quad := QuadMesh.new()
		quad.size = Vector2(1, 1)
		multi.mesh = quad
		var count: int = 14 if profile == "low" else 34
		multi.instance_count = count
		for k in range(count):
			var a: float = float(k) * 2.399
			var r: float = column.z * 0.75 * sqrt(fmod(float(k) * 0.618, 1.0))
			multi.set_instance_transform(
				k,
				Transform3D(Basis().scaled(Vector3.ONE * 0.45), Vector3(sin(a) * r, 0, cos(a) * r))
			)
			multi.set_instance_custom_data(k, Color(fmod(float(k) * 0.381, 1.0), 0, 0, 0))
		motes.multimesh = multi
		motes.material_override = SHADERS.material("RISE", {"height": height, "speed": 7.0})
		motes.position = Vector3(column.x, LAYOUT.CLOUD_SEA_Y, column.y)
		motes.custom_aabb = AABB(
			Vector3(-column.z, 0, -column.z), Vector3(column.z * 2, height, column.z * 2)
		)
		motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(motes)


# ------------------------------------------------------------------ per frame


func advance(delta: float, camera_position: Vector3) -> void:
	_clock += delta
	if is_instance_valid(cloud_sea):
		cloud_sea.position = Vector3(
			snappedf(camera_position.x, 50.0), LAYOUT.CLOUD_SEA_Y, snappedf(camera_position.z, 50.0)
		)
	if reduced_motion:
		return
	if is_instance_valid(sails):
		sails.rotation.z -= delta * 0.9
	if is_instance_valid(zeppelin):
		zeppelin.transform = zeppelin_rest.rotated_local(Vector3.UP, sin(_clock * 0.15) * 0.25)
		zeppelin.position.y = zeppelin_rest.origin.y + sin(_clock * 0.6) * 0.15
	for index in range(board_faces.size()):
		var face: Node3D = board_faces[index]
		var to: Vector3 = camera_position - face.global_position
		face.global_rotation = Vector3(0, atan2(to.x, to.z), 0)


# ------------------------------------------------------------------ mode objects


func clear_mode_objects() -> void:
	for gate in gates:
		gate.queue_free()
	gates.clear()
	gate_materials.clear()
	if is_instance_valid(sparks):
		sparks.queue_free()
	sparks = null
	spark_positions = PackedVector3Array()
	spark_taken = PackedByteArray()
	for frame in photo_frames:
		frame.queue_free()
	photo_frames.clear()
	if is_instance_valid(beacon):
		beacon.queue_free()
	beacon = null
	for marker in markers:
		marker.queue_free()
	markers.clear()
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null
	for index in range(boards.size()):
		set_board(index, "", false)


func make_gates() -> void:
	for index in range(LAYOUT.GATES.size()):
		var frame: Transform3D = layout.gate_frame(index)
		var gate := Node3D.new()
		gate.name = "Gate_%d" % index
		gate.transform = frame
		add_child(gate)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 4.3
		torus.outer_radius = 5.0
		torus.rings = 48
		torus.ring_segments = 10
		ring.mesh = torus
		ring.rotation.x = PI * 0.5
		var material: ShaderMaterial = SHADERS.material(
			"RING",
			{
				"colour_a": Color("ffcf3e") if index == 0 else Color("47c8ff"),
				"colour_b": Color("fff6c8")
			}
		)
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gate.add_child(ring)
		for k in range(4):
			var lantern := MeshInstance3D.new()
			var star := SphereMesh.new()
			star.radius = 0.28
			star.height = 0.56
			star.radial_segments = 8
			star.rings = 4
			lantern.mesh = star
			var a: float = PI * 0.25 + PI * 0.5 * float(k)
			lantern.position = Vector3(cos(a) * 4.65, sin(a) * 4.65, 0)
			lantern.material_override = _glow(Color("fff2b0"))
			gate.add_child(lantern)
		var label := Label3D.new()
		label.text = "ZIEL" if index == 0 else str(index)
		label.font = FONT
		label.font_size = 120
		label.pixel_size = 0.012
		label.outline_size = 24
		label.modulate = Color("fff6d0")
		label.outline_modulate = Color("0b2247")
		label.position = Vector3(0, 6.2, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		gate.add_child(label)
		gates.append(gate)
		gate_materials.append(material)


func _glow(colour: Color) -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	made.albedo_color = colour
	return made


## Highlights gate [param next] (bright, pulsing) and dims the others.
func show_next_gate(next: int, flash: int = -1) -> void:
	for index in range(gate_materials.size()):
		var material: ShaderMaterial = gate_materials[index]
		material.set_shader_parameter("energy", 1.35 if index == next else 0.55)
		material.set_shader_parameter("pulse", 0.6 if index == flash else 0.0)


func make_sparks(positions: PackedVector3Array) -> void:
	spark_positions = positions
	spark_taken.resize(positions.size())
	spark_taken.fill(0)
	sparks = MultiMeshInstance3D.new()
	sparks.name = "Sparks"
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	multi.mesh = quad
	multi.instance_count = positions.size()
	for index in range(positions.size()):
		multi.set_instance_transform(
			index, Transform3D(Basis().scaled(Vector3.ONE * 1.5), positions[index])
		)
		multi.set_instance_custom_data(index, Color(fmod(float(index) * 0.137, 1.0), 1.0, 0, 0))
	sparks.multimesh = multi
	sparks.material_override = SHADERS.material("SPARK")
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.custom_aabb = AABB(Vector3(-400, -80, -400), Vector3(800, 220, 800))
	add_child(sparks)


func take_spark(index: int) -> void:
	if index < 0 or index >= spark_taken.size():
		return
	spark_taken[index] = 1
	if is_instance_valid(sparks):
		sparks.multimesh.set_instance_custom_data(index, Color(0, 0, 0, 0))


func make_photo_frames(taken: PackedByteArray) -> void:
	for index in range(LAYOUT.PHOTOS.size()):
		var spot: Dictionary = LAYOUT.PHOTOS[index]
		var frame := Node3D.new()
		frame.name = "Photo_%d" % index
		var look: Vector3 = spot.look
		frame.position = spot.at
		add_child(frame)
		frame.look_at(look, Vector3.UP)
		var colour := (
			Color("ff9fd2") if index < taken.size() and taken[index] == 1 else Color("ffe27a")
		)
		for side in range(4):
			var bar := MeshInstance3D.new()
			var box := BoxMesh.new()
			var horizontal: bool = side < 2
			box.size = Vector3(7.0 if horizontal else 0.45, 0.45 if horizontal else 5.0, 0.3)
			bar.mesh = box
			bar.position = (
				Vector3(0, 2.5 if side == 0 else -2.5, 0)
				if horizontal
				else Vector3(3.5 if side == 2 else -3.5, 0, 0)
			)
			bar.material_override = _glow(colour)
			frame.add_child(bar)
		var label := Label3D.new()
		label.text = "FOTO"
		label.font = FONT
		label.font_size = 96
		label.pixel_size = 0.012
		label.outline_size = 20
		label.modulate = colour
		label.outline_modulate = Color("0b2247")
		label.position = Vector3(0, 3.4, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		frame.add_child(label)
		photo_frames.append(frame)


func mark_photo(index: int) -> void:
	if index < 0 or index >= photo_frames.size():
		return
	for child in photo_frames[index].get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = _glow(Color("ff9fd2"))
		elif child is Label3D:
			(child as Label3D).modulate = Color("ff9fd2")


## Beacon of light above the active delivery district.
func show_beacon(at: Variant) -> void:
	if at == null:
		if is_instance_valid(beacon):
			beacon.visible = false
		return
	if not is_instance_valid(beacon):
		beacon = MeshInstance3D.new()
		beacon.name = "Beacon"
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 2.2
		cylinder.bottom_radius = 3.4
		cylinder.height = 70.0
		cylinder.cap_top = false
		cylinder.cap_bottom = false
		cylinder.radial_segments = 20
		beacon.mesh = cylinder
		beacon.material_override = SHADERS.material("BEACON", {"tint": Color("ffd75e")})
		beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beacon)
	beacon.visible = true
	beacon.position = (at as Vector3) + Vector3(0, 35.0, 0)


## Ground rings around the three mailboxes of the active district.
func show_targets(house_indices: Array, radius: float) -> void:
	for marker in markers:
		marker.queue_free()
	markers.clear()
	for house_index in house_indices:
		var house: Dictionary = layout.houses[int(house_index)]
		var marker := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(radius * 2.0, radius * 2.0)
		quad.orientation = PlaneMesh.FACE_Y
		marker.mesh = quad
		marker.material_override = SHADERS.material(
			"MARKER", {"tint": Color("ffd75e"), "fill": 0.08}
		)
		marker.position = house.mailbox + Vector3(0, 0.25, 0)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marker)
		markers.append(marker)


## Where the letter would land now (Entdecken, or after a miss).
func show_preview(at: Variant) -> void:
	if at == null:
		if is_instance_valid(preview):
			preview.visible = false
		return
	if not is_instance_valid(preview):
		preview = MeshInstance3D.new()
		preview.name = "LandingPreview"
		var quad := QuadMesh.new()
		quad.size = Vector2(2.2, 2.2)
		quad.orientation = PlaneMesh.FACE_Y
		preview.mesh = quad
		preview.material_override = SHADERS.material(
			"MARKER", {"tint": Color("7ff0ff"), "fill": 0.3}
		)
		preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(preview)
	preview.visible = true
	preview.position = (at as Vector3) + Vector3(0, 0.3, 0)


## Writes [param text] on address board [param index]; "clock:h:m" draws a clock.
func set_board(index: int, text: String, active: bool) -> void:
	if index < 0 or index >= board_faces.size():
		return
	var face: Node3D = board_faces[index]
	for child in face.get_children():
		if child.name in ["Text", "Clock"]:
			child.queue_free()
	var glow := face.get_node_or_null("Glow") as Node3D
	if glow != null:
		glow.visible = active
	face.scale = Vector3.ONE * (1.25 if active else 1.0)
	if text.is_empty():
		return
	if text.begins_with("clock:"):
		var parts: PackedStringArray = text.split(":")
		face.add_child(_clock_face(int(parts[1]), int(parts[2])))
		return
	for side in [1.0, -1.0]:
		var label := Label3D.new()
		label.name = "Text"
		label.text = text
		label.font = FONT
		var size: int = (
			150
			if text.length() <= 2
			else 110 if text.length() <= 5 else int(560.0 / float(text.length()))
		)
		label.font_size = maxi(48, size)
		label.pixel_size = 0.006
		label.outline_size = 10
		label.modulate = Color("0b2247")
		label.outline_modulate = Color("ffffff")
		label.position = Vector3(0, 0, 0.09 * side)
		label.rotation.y = 0.0 if side > 0 else PI
		label.double_sided = false
		face.add_child(label)


func _clock_face(hour: int, minute: int) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Clock"
	var ink := _flat(Color("0b2247"), 0.5)
	var red := _flat(Color("d9443b"), 0.5)
	for side in [1.0, -1.0]:
		var face := Node3D.new()
		face.position = Vector3(0, 0, 0.085 * side)
		face.rotation.y = 0.0 if side > 0 else PI
		holder.add_child(face)
		for tick in range(12):
			var mark := MeshInstance3D.new()
			var box := BoxMesh.new()
			var big: bool = tick % 3 == 0
			box.size = Vector3(0.06 if big else 0.04, 0.16 if big else 0.1, 0.02)
			mark.mesh = box
			var a: float = TAU * float(tick) / 12.0
			mark.position = Vector3(sin(a) * 0.72, cos(a) * 0.72, 0.01)
			mark.rotation.z = -a
			mark.material_override = ink
			face.add_child(mark)
		var minute_angle: float = TAU * float(minute) / 60.0
		var hour_angle: float = TAU * (float(hour % 12) + float(minute) / 60.0) / 12.0
		face.add_child(_hand(minute_angle, 0.62, 0.05, ink, 0.03))
		face.add_child(_hand(hour_angle, 0.4, 0.075, red, 0.04))
		var hub := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.07
		disc.bottom_radius = 0.07
		disc.height = 0.03
		hub.mesh = disc
		hub.rotation.x = PI * 0.5
		hub.position = Vector3(0, 0, 0.05)
		hub.material_override = ink
		face.add_child(hub)
	return holder


func _hand(
	angle: float, length: float, width: float, material: Material, z: float
) -> MeshInstance3D:
	var hand := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, length, 0.02)
	hand.mesh = box
	hand.position = Vector3(sin(angle) * length * 0.5, cos(angle) * length * 0.5, z)
	hand.rotation.z = -angle
	hand.material_override = material
	return hand


## Mailbox reaction: the flap opens, the flag goes up.
func mailbox_delivered(house: int) -> void:
	if house < 0 or house >= flags.size():
		return
	var flag: Node3D = flags[house]
	var flap: Node3D = flaps[house]
	if is_instance_valid(flag):
		var tween := create_tween()
		(
			tween
			. tween_property(flag, "rotation:x", -PI * 0.5, 0.0 if reduced_motion else 0.45)
			. set_trans(Tween.TRANS_BACK)
		)
	if is_instance_valid(flap) and not reduced_motion:
		var tween := create_tween()
		tween.tween_property(flap, "rotation:x", 0.9, 0.18)
		tween.tween_property(flap, "rotation:x", 0.0, 0.3).set_delay(0.4)


func reset_mailboxes() -> void:
	for flag in flags:
		if is_instance_valid(flag):
			flag.rotation.x = 0.0
