class_name TreasureIslandArt
extends RefCounted

## Visuelle Anreicherung der Schatzsuche: Runenbogen statt Sandsteinsturz,
## Pfotenpfad, Felsen, Ruinen, Runensteine, Wasserfallnebel, Schatzkammer
## und Lichtstrahlen. Landmarken der zusätzlichen Fundorte stehen nur als
## sichtbare Hinweise in der Welt; Fundregeln liegen in TreasureState.
const LANTERN_MODEL = preload("res://assets/creative/models/lumo_lantern.glb")
const CHEST_MODEL = preload("res://assets/creative/models/lumo_treasure_chest.glb")
const ADVENTURE = preload("res://scripts/creative/adventure_kit.gd")


static func apply(root: Node3D) -> void:
	var budget: Dictionary = LumoQuality.budget()
	var density: float = clampf(float(budget.get("decor_density", 1.0)), 0.35, 1.0)
	var sparkles: int = int(budget.get("sparkles", 24))
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	# Felsen, Ruinen, Bögen, Wasser, Meer und Pflanzen kommen aus TreasureIslandNature
	# (Blender-Modelle). Hier bleiben Runen, Pfotenspur, Kompass, Kammerlicht,
	# Lichtstrahlen und die Landmarken der Zusatzfunde.
	_stone_dressing(root, box, density)
	_rune_glow(root, box, density)
	_paw_path(root, box, density)
	_compass_rose(root, box)
	_waterfall_dressing(root, box, sparkles)
	_chamber_light(root, sparkles)
	_light_rays(root, sparkles)
	_secret_finds(root, box)


static func _mat(
	albedo: Color, emission: Color = Color.BLACK, energy: float = 0.0
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.8
	mat.metallic = 0.04
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	return mat


static func _xform(origin: Vector3, size: Vector3, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(size), origin)


static func _stone_dressing(root: Node3D, mesh: BoxMesh, density: float) -> void:
	var xforms: Array[Transform3D] = []
	# Stehende Runensteine am Wegrand zur Orientierung.
	var marker_z: Array[float] = [-10.0, -22.0, -38.0, -52.0]
	var marker_count: int = maxi(2, int(round(float(marker_z.size()) * density)))
	for i in range(marker_count):
		var z: float = marker_z[i]
		for side in [-1.0, 1.0]:
			xforms.append(
				_xform(Vector3(side * 6.45, 1.08, z), Vector3(0.44, 2.16, 0.3), side * 0.08)
			)
	# Kompass-Sockel neben dem Start (rechts vom Pfad).
	xforms.append(_xform(Vector3(2.45, 0.2, 4.55), Vector3(1.25, 0.4, 1.25)))
	xforms.append(_xform(Vector3(2.45, 0.72, 4.55), Vector3(0.58, 0.85, 0.58)))
	xforms.append(_xform(Vector3(2.45, 1.22, 4.55), Vector3(1.35, 0.18, 1.35)))
	BuildVoxelStyle.multimesh(
		root, "TreasureStoneDressing", mesh, ADVENTURE.material("stone_block"), xforms
	)


static func _rune_glow(root: Node3D, mesh: BoxMesh, density: float) -> void:
	var xforms: Array[Transform3D] = []
	for i in range(9):
		var t: float = float(i) / 8.0
		var angle: float = PI * (1.0 - t)
		var x: float = cos(angle) * 3.25
		var y: float = 4.38 + sin(angle) * 2.42
		xforms.append(_xform(Vector3(x, y, -30.52), Vector3(0.34, 0.2, 0.08), angle - PI * 0.5))
	xforms.append(_xform(Vector3(-3.45, 1.85, -30.42), Vector3(0.08, 0.7, 0.34)))
	xforms.append(_xform(Vector3(3.45, 1.85, -30.42), Vector3(0.08, 0.7, 0.34)))
	var marker_z: Array[float] = [-10.0, -22.0, -38.0, -52.0]
	var marker_count: int = maxi(2, int(round(float(marker_z.size()) * density)))
	for i in range(marker_count):
		for side in [-1.0, 1.0]:
			xforms.append(
				_xform(Vector3(side * 6.22, 1.28, marker_z[i]), Vector3(0.05, 0.62, 0.16))
			)
	xforms.append(_xform(Vector3(-3.45, 3.7, -65.0), Vector3(0.2, 0.95, 0.2)))
	xforms.append(_xform(Vector3(3.45, 3.7, -65.0), Vector3(0.2, 0.95, 0.2)))
	xforms.append(_xform(Vector3(0.0, 3.75, -69.1), Vector3(1.55, 0.24, 0.08)))
	BuildVoxelStyle.multimesh(
		root, "TreasureRuneGlow", mesh, _mat(Color("16343c"), Color("5ce1e6"), 1.55), xforms
	)


static func _paw_path(root: Node3D, mesh: BoxMesh, density: float) -> void:
	var xforms: Array[Transform3D] = []
	var z: float = 5.5
	var side: float = 1.0
	var step: float = 1.58 / clampf(density, 0.55, 1.0)
	while z > -63.6:
		var x: float = side * 0.46
		var yaw: float = side * 0.14
		xforms.append(_xform(Vector3(x, 0.07, z), Vector3(0.38, 0.045, 0.46), yaw))
		xforms.append(
			_xform(Vector3(x + side * 0.14, 0.072, z - 0.34), Vector3(0.15, 0.04, 0.15), yaw)
		)
		xforms.append(
			_xform(Vector3(x - side * 0.15, 0.072, z - 0.3), Vector3(0.13, 0.04, 0.13), yaw)
		)
		xforms.append(
			_xform(Vector3(x + side * 0.02, 0.072, z - 0.38), Vector3(0.12, 0.04, 0.12), yaw)
		)
		z -= step
		side *= -1.0
	BuildVoxelStyle.multimesh(
		root, "TreasurePawPath", mesh, _mat(Color("c89a2a"), Color("ffcc44"), 0.7), xforms
	)


static func _compass_rose(root: Node3D, mesh: BoxMesh) -> void:
	var xforms: Array[Transform3D] = []
	# Kompassrose auf dem Sockel neben dem Spawn.
	xforms.append(_xform(Vector3(2.45, 1.36, 4.55), Vector3(1.05, 0.05, 1.05), 0.78))
	xforms.append(_xform(Vector3(2.45, 1.4, 4.55), Vector3(0.14, 0.05, 1.15)))
	xforms.append(_xform(Vector3(2.45, 1.4, 4.55), Vector3(1.15, 0.05, 0.14)))
	xforms.append(_xform(Vector3(2.45, 1.42, 4.1), Vector3(0.16, 0.05, 0.24)))
	# Pfoten-Emblem am Scheitel des Startbogens.
	xforms.append(_xform(Vector3(0.0, 5.38, 0.68), Vector3(0.62, 0.48, 0.14)))
	xforms.append(_xform(Vector3(-0.32, 5.68, 0.68), Vector3(0.2, 0.2, 0.12)))
	xforms.append(_xform(Vector3(0.0, 5.78, 0.68), Vector3(0.2, 0.22, 0.12)))
	xforms.append(_xform(Vector3(0.32, 5.68, 0.68), Vector3(0.2, 0.2, 0.12)))
	BuildVoxelStyle.multimesh(
		root, "TreasureCompassRose", mesh, _mat(Color("d7a02a"), Color("ffe08a"), 1.35), xforms
	)


static func _waterfall_dressing(root: Node3D, _mesh: BoxMesh, sparkles: int) -> void:
	if sparkles <= 0:
		return
	var mist := GPUParticles3D.new()
	mist.name = "TreasureFallsMist"
	mist.position = Vector3(16.3, 2.4, -22.4)
	mist.amount = mini(28, sparkles)
	mist.lifetime = 2.2
	mist.visibility_aabb = AABB(Vector3(-6, -3, -4), Vector3(12, 8, 8))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(1.6, 1.7, 0.4)
	process.direction = Vector3(0, -1, 0.18)
	process.spread = 18.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.85
	process.gravity = Vector3(0, -0.35, 0)
	process.scale_min = 0.12
	process.scale_max = 0.34
	process.color = Color(0.82, 0.92, 0.98, 0.5)
	mist.process_material = process
	var draw := SphereMesh.new()
	draw.radius = 0.22
	draw.height = 0.44
	draw.radial_segments = 8
	draw.rings = 4
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(0.86, 0.94, 1.0, 0.32)
	draw.material = draw_mat
	mist.draw_pass_1 = draw
	root.add_child(mist)


static func _chamber_light(root: Node3D, sparkles: int) -> void:
	var light := OmniLight3D.new()
	light.name = "TreasureChamberLight"
	light.position = Vector3(0.0, 3.55, -66.5)
	light.light_color = Color("ffe2a8")
	light.light_energy = 2.35
	light.omni_range = 9.5
	light.shadow_enabled = false
	root.add_child(light)
	if sparkles <= 0:
		return
	var spark := GPUParticles3D.new()
	spark.name = "TreasureChamberSparkles"
	spark.position = Vector3(0.0, 1.55, -65.15)
	spark.amount = mini(20, sparkles)
	spark.lifetime = 2.6
	spark.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 6, 8))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 1.35
	process.direction = Vector3(0, 1, 0)
	process.spread = 48.0
	process.initial_velocity_min = 0.12
	process.initial_velocity_max = 0.42
	process.gravity = Vector3(0, 0.14, 0)
	process.scale_min = 0.05
	process.scale_max = 0.12
	process.color = Color("ffe7a1")
	spark.process_material = process
	var draw := SphereMesh.new()
	draw.radius = 0.08
	draw.height = 0.16
	draw.radial_segments = 6
	draw.rings = 3
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.emission_enabled = true
	draw_mat.emission = Color("ffe7a1")
	draw_mat.emission_energy_multiplier = 2.0
	draw_mat.albedo_color = Color("ffe7a1")
	draw.material = draw_mat
	spark.draw_pass_1 = draw
	root.add_child(spark)


static func _light_rays(root: Node3D, sparkles: int) -> void:
	if sparkles <= 0:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.32
	mesh.bottom_radius = 1.2
	mesh.height = 7.6
	mesh.radial_segments = 8
	mesh.rings = 1
	var rays: Array[Transform3D] = []
	rays.append(Transform3D(Basis.from_euler(Vector3(0.08, 0.0, 0.05)), Vector3(0.0, 6.45, -66.3)))
	rays.append(
		Transform3D(Basis.from_euler(Vector3(0.05, 0.35, -0.04)), Vector3(0.0, 7.15, -31.0))
	)
	var mat := ShaderMaterial.new()
	mat.shader = ADVENTURE.shader("light_beam")
	mat.set_shader_parameter("beam_color", Color("ffe7a1"))
	mat.set_shader_parameter("intensity", 0.22)
	mat.set_shader_parameter("beam_length", 7.6)
	BuildVoxelStyle.multimesh(root, "TreasureLightRays", mesh, mat, rays)


static func _secret_finds(root: Node3D, mesh: BoxMesh) -> void:
	# Muschelbank am rechten Ufer der Startbucht.
	var shell_at := Vector3(18.5, 0.0, -5.5)
	var shells: Array[Transform3D] = [ADVENTURE.xf(shell_at + Vector3(0, 0.02, 0), 0.4, 1.6)]
	ADVENTURE.scatter(root, "TreasureShells", "ruins", "shells", shells, false)
	# Pfadlaterne links der Hauptspur.
	var lamp: Node3D = LANTERN_MODEL.instantiate()
	lamp.name = "TreasurePathLantern"
	lamp.position = Vector3(-8.5, 0, -14.0)
	root.add_child(lamp)
	# Aussichtsfels rechts hinter dem Tor: kleine Steinpyramide mit Leuchtstein.
	var look := Vector3(20.5, 0.0, -36.5)
	var cairn: Array[Transform3D] = [
		ADVENTURE.xf(look + Vector3(0, 0.1, 0), 0.0, 0.9),
		ADVENTURE.xf(look + Vector3(0.1, 0.95, -0.1), 0.8, 0.55),
		ADVENTURE.xf(look + Vector3(0, 1.45, 0), 2.0, 0.32),
	]
	ADVENTURE.scatter(root, "TreasureLookout", "ruins", "rock_b", cairn, true)
	var beacon := SphereMesh.new()
	beacon.radius = 0.28
	beacon.height = 0.56
	beacon.radial_segments = 16
	beacon.rings = 8
	var beacon_x: Array[Transform3D] = [_xform(look + Vector3(0, 1.85, 0), Vector3.ONE)]
	BuildVoxelStyle.multimesh(
		root, "TreasureLookoutBeacon", beacon, _mat(Color("ffe08a"), Color("ffd56a"), 1.6), beacon_x
	)
	# Mondspiegel: flacher leuchtender Teich.
	var pool := CylinderMesh.new()
	pool.top_radius = 1.0
	pool.bottom_radius = 1.0
	pool.height = 1.0
	pool.radial_segments = 20
	var pool_mat := _mat(Color(0.45, 0.72, 0.92, 0.7), Color("b8e7ff"), 0.8)
	pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var pool_x: Array[Transform3D] = [
		Transform3D(Basis.from_scale(Vector3(1.8, 0.08, 1.8)), Vector3(8.0, 0.08, -43.0))
	]
	BuildVoxelStyle.multimesh(root, "TreasureMoonPool", pool, pool_mat, pool_x)
	# Versteckte Truhe in der Kammerflanke.
	var cache: Node3D = CHEST_MODEL.instantiate()
	cache.name = "TreasureHiddenCache"
	cache.position = Vector3(-16.0, 0, -58.5)
	cache.rotation.y = deg_to_rad(35)
	cache.scale = Vector3.ONE * 0.85
	root.add_child(cache)
	# Glanz an beiden Truhen: weiche Lichtpunkte, die kurz aufblitzen und sinken.
	for spot in [[Vector3(0.0, 0.9, -65.0), "TreasureChestGlint"], [Vector3(-16.0, 0.8, -58.5), "TreasureCacheGlint"]]:
		var glint := ADVENTURE.sparkle_particles(str(spot[1]), 10, Color(1.0, 0.86, 0.5, 0.9), 0.7, 1.8)
		glint.position = spot[0]
		root.add_child(glint)

