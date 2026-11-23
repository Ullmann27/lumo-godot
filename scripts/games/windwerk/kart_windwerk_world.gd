extends RefCounted
const COURSE = preload("res://scripts/games/windwerk/kart_windwerk_course.gd")
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const SPECTACLE = preload("res://scripts/games/kart_course_spectacle.gd")
const THRILLS = preload("res://scripts/games/kart_track_thrills.gd")
const THRILL_ART = preload("res://scripts/games/kart_track_thrill_art.gd")
const PIECES = preload("res://scripts/games/track_pieces/kart_track_pieces.gd")
const DECK = preload("res://assets/shaders/kart_windwerk_deck.gdshader")
const ART_PATH := "res://scripts/games/kart_windwerk_art.gd"
const HALF := COURSE.WIDTH * .5
const SKY_SHADER = preload("res://assets/shaders/kart_scenery_sky.gdshader")
static var _valley_sky: Sky


static func build(world, geometry_only: bool) -> void:
	var road_root := Node3D.new()
	road_root.name = "Windbahn"
	world.add_child(road_root)
	world.action = COURSE.action_plan()
	world.set_meta("item_zone_hazards", {COURSE.ID: COURSE.TRIALS})
	# Windwerk has its own world builder, so it must opt into the same bank
	# planner explicitly before any road span asks world.frame() for its basis.
	THRILLS.plan(world)
	SPECTACLE.plan(world)
	PIECES.plan(world, world._piece_markers + SPECTACLE.markers(world))
	var deck := ShaderMaterial.new()
	deck.shader = DECK
	for section in range(20):
		var from: float = world.length * section / 20.0
		var to: float = world.length * (section + 1) / 20.0
		var mesh := _span(world, from, to, Vector2(-HALF, 0), Vector2(HALF, 0))
		var piece := MeshInstance3D.new()
		piece.name = "Viadukt%02d" % section
		piece.mesh = mesh
		piece.material_override = deck
		road_root.add_child(piece)
		if section == 0:
			world.road = piece
		var solid := StaticBody3D.new()
		solid.collision_mask = 0
		road_root.add_child(solid)
		_collider(solid, mesh)
		for side in [-1.0, 1.0]:
			_collider(solid, _span(world, from, to, Vector2(HALF * side, -.3), Vector2(HALF * side, .92)))
	ACTION.build(world)
	_rails(world)
	THRILL_ART.build(world)
	for row in range(2):
		for tile in range(20):
			var at: Vector3 = world.position_at(1.0 + .72 * row, (tile - 9.5) * .71)
			world._prop("box", at + world.frame(1).y * .025, Vector3(.72,.035,.72),
				Color("fff2d1") if (row + tile) % 2 == 0 else Color("20394c"), world.frame(1))
	if not geometry_only:
		world._lighting()
		_valley(world)
		load(ART_PATH).build(world)
	PIECES.build(world)
	SPECTACLE.build(world)
	world._flush_instances()


static func _collider(body: StaticBody3D, mesh: ArrayMesh) -> void:
	var holder := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	holder.shape = shape
	body.add_child(holder)


static func _span(world, from: float, to: float, a: Vector2, b: Vector2) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := ceili((to - from) / 2.5)
	for i in range(steps + 1):
		var d := lerpf(from, to, float(i) / steps)
		var normal: Vector3 = world.frame(d).y
		for point: Vector2 in [a, b]:
			surface.set_normal(normal)
			surface.set_uv(Vector2(point.x, d))
			surface.add_vertex(world.position_at(d, point.x) + normal * point.y)
		if i > 0:
			var k := 2 * i
			for index: int in [k - 2, k, k - 1, k - 1, k, k + 1]:
				surface.add_index(index)
	return surface.commit()


static func _rails(world) -> void:
	var count := ceili(float(world.length) / 8)
	for i in range(count):
		var d: float = world.length * i / count
		var next: float = world.length * (i + 1) / count
		var basis: Basis = world.frame(d)
		for side in [-1.0, 1.0]:
			var p: Vector3 = world.position_at(d, side * 7.6)
			var q: Vector3 = world.position_at(next, side * 7.6)
			world._beam(p + basis.y * .92, q + world.frame(next).y * .92, .20, Color("d8a45d"))
			world._beam(p - basis.y * .4, q - world.frame(next).y * .4, .68, Color("386d74"))
			world._prop("box", p + basis.y * .29, Vector3(.29,1.5,.32), Color("436e77"), basis)
			if i % 3 == 0:
				var low := ground_height(p.x, p.z) - .15
				world._prop("box", Vector3(p.x, (low + p.y) * .5, p.z), Vector3(1.25,p.y-low,1.65),
					Color("807667"), Basis(Vector3.UP, basis.get_euler().y))
			if i % 2 == 0:
				world._prop("box", p + basis.y * .94, Vector3(.36,.13,.6),Color("ffe7a3"), basis)


static func ground_height(x: float, z: float) -> float:
	var fold := sin(x * .015 + sin(z * .011)) * 2.4 + cos(z * .016 - x * .009) * 2.0
	var river := absf(x - 125.0 * sin(z * .007) + 40.0)
	var trough := smoothstep(7.0, 90.0, river)
	var outer := smoothstep(420.0, 735.0, Vector2(x, z).length())
	return lerpf(-5.7, 1.6 + fold, trough) + outer * (85.0 + 42.0 * sin(x*.019) * cos(z*.012))


static func _valley(world) -> void:
	# Soft warm horizon behind darker ridges leaves the foreground machines readable.
	if _valley_sky == null:
		var cloud := ShaderMaterial.new()
		cloud.shader = SKY_SHADER
		cloud.set_shader_parameter("zenith", Color("24669d"))
		cloud.set_shader_parameter("horizon", Color("8cbfc9"))
		cloud.set_shader_parameter("haze", Color("efbd8f"))
		cloud.set_shader_parameter("ground", Color("6a8888"))
		cloud.set_shader_parameter("cloud_shadow", Color("889bab"))
		cloud.set_shader_parameter("cloud_color", Color("fff0d4"))
		cloud.set_shader_parameter("clouds", .55)
		cloud.set_shader_parameter("energy", .87)
		_valley_sky = Sky.new()
		_valley_sky.sky_material = cloud
	var worlds := world.find_children("*", "WorldEnvironment", false, false) as Array
	if not worlds.is_empty():
		var env: Environment = worlds[0].environment
		env.sky = _valley_sky
		env.fog_sky_affect = .12
		env.fog_density = .00075
		env.fog_light_color = Color("b6b6a7")
		env.tonemap_exposure = .93
	# Grid of terraced meadows below the raised track, river and a connected
	# distant ridgeline. Fixed coordinates keep the horizon stable as karts move.
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size := 100
	for iz in range(size + 1):
		for ix in range(size + 1):
			var x := (ix - size * .5) * 20.0
			var z := (iz - size * .5) * 20.0
			var h := ground_height(x,z)
			var normal := Vector3(ground_height(x-1,z)-ground_height(x+1,z), 2, ground_height(x,z-1)-ground_height(x,z+1)).normalized()
			var tone := Color("8cb88b").lerp(Color("5e9a80"), .5 + .5 * sin(.043*x + floor(z/70.0)))
			tone = tone.lerp(Color("52697c"), smoothstep(12,85,h))
			ground.set_color(tone)
			ground.set_normal(normal)
			ground.add_vertex(Vector3(x,h,z))
			if iz > 0 and ix > 0:
				var k := iz * (size + 1) + ix
				for n: int in [k-size-2,k-size-1,k-1,k-size-1,k,k-1]:
					ground.add_index(n)
	var land := MeshInstance3D.new()
	land.name = "Muehlental"
	land.mesh = ground.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	land.material_override = mat
	world.add_child(land)
	var river := MeshInstance3D.new()
	river.name = "Muehlenfluss"
	var water := PlaneMesh.new()
	water.size = Vector2(1980,1980)
	river.mesh = water
	river.position.y = -4.8
	river.material_override = world._material(Color("57abbe"))
	world.add_child(river)
