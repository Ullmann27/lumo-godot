class_name TreasureIslandArt
extends RefCounted

## Visuelle Anreicherung der Schatzsuche: Runenbogen statt Sandsteinsturz,
## Pfotenpfad, Felsen, Ruinen, Runensteine, Wasserfallnebel, Schatzkammer
## und Lichtstrahlen. Keine Gameplay-, Collision- oder Hinweis-Änderungen.


static func apply(root: Node3D) -> void:
	var budget: Dictionary = LumoQuality.budget()
	var density: float = clampf(float(budget.get("decor_density", 1.0)), 0.35, 1.0)
	var sparkles: int = int(budget.get("sparkles", 24))
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_stone_dressing(root, box, density)
	_rune_glow(root, box, density)
	_paw_path(root, box, density)
	_compass_rose(root, box)
	_waterfall_dressing(root, box, sparkles)
	_sea(root)
	_foliage(root, box, density)
	_flowers(root, box, density)
	_chamber_light(root, sparkles)
	_light_rays(root, sparkles)


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
	# Runenbogen über den bestehenden Pfeilern (Collision des Tors bleibt unverändert).
	for i in range(17):
		var t: float = float(i) / 16.0
		var angle: float = PI * (1.0 - t)
		var x: float = cos(angle) * 3.25
		var y: float = 4.38 + sin(angle) * 2.42
		xforms.append(_xform(Vector3(x, y, -31.08), Vector3(1.18, 0.58, 0.98), angle - PI * 0.5))
	# Extra Felsen abseits des Pfads und am Wasserfall.
	var rocks: Array = [
		Vector3(-16.2, 0.0, -6.4),
		Vector3(17.6, 0.0, -8.1),
		Vector3(-18.4, 0.0, -17.8),
		Vector3(15.6, 0.0, -16.2),
		Vector3(-14.6, 0.0, -27.4),
		Vector3(16.8, 0.0, -29.1),
		Vector3(-19.2, 0.0, -36.5),
		Vector3(18.4, 0.0, -42.6),
		Vector3(-13.8, 0.0, -50.4),
		Vector3(14.6, 0.0, -54.2),
		Vector3(-8.6, 0.0, -62.4),
		Vector3(8.9, 0.0, -63.6),
		Vector3(11.0, 0.0, -21.8),
		Vector3(16.2, 0.0, -23.4),
		Vector3(-20.4, 0.0, -12.2),
		Vector3(20.2, 0.0, -33.5),
	]
	var rock_count: int = maxi(7, int(round(float(rocks.size()) * density)))
	for i in range(rock_count):
		var p: Vector3 = rocks[i]
		var h: float = 0.58 + float(i % 4) * 0.24
		var w: float = 0.9 + float(i % 3) * 0.3
		xforms.append(_xform(Vector3(p.x, h * 0.46, p.z), Vector3(w, h, w * 0.78), float(i) * 0.47))
		if density > 0.72:
			xforms.append(
				_xform(
					Vector3(p.x + 0.72, h * 0.28, p.z + 0.38),
					Vector3(w * 0.52, h * 0.52, w * 0.48),
					float(i) * -0.33
				)
			)
	# Ruinenblöcke als Landmarken vor Burg und Kammer.
	var ruins: Array = [
		[Vector3(-7.5, 0.55, -56.4), Vector3(1.65, 1.12, 0.95), 0.22],
		[Vector3(-6.3, 1.38, -56.7), Vector3(0.72, 0.58, 0.7), -0.18],
		[Vector3(7.7, 0.48, -55.6), Vector3(1.42, 0.95, 1.12), -0.34],
		[Vector3(8.5, 1.18, -56.1), Vector3(0.62, 0.5, 0.58), 0.41],
		[Vector3(-9.3, 0.42, -48.1), Vector3(1.22, 0.82, 0.88), 0.52],
		[Vector3(9.1, 0.38, -46.4), Vector3(1.08, 0.72, 0.82), -0.58],
		[Vector3(-5.9, 0.32, -33.6), Vector3(0.92, 0.62, 0.72), 0.24],
		[Vector3(6.2, 0.34, -34.1), Vector3(0.88, 0.66, 0.74), -0.2],
	]
	var ruin_count: int = maxi(4, int(round(float(ruins.size()) * density)))
	for i in range(ruin_count):
		var block: Array = ruins[i]
		xforms.append(_xform(block[0], block[1], block[2]))
	# Stehende Runensteine am Wegrand zur Orientierung.
	var marker_z: Array[float] = [-10.0, -22.0, -38.0, -52.0]
	var marker_count: int = maxi(2, int(round(float(marker_z.size()) * density)))
	for i in range(marker_count):
		var z: float = marker_z[i]
		for side in [-1.0, 1.0]:
			xforms.append(
				_xform(Vector3(side * 6.45, 1.08, z), Vector3(0.44, 2.16, 0.3), side * 0.08)
			)
	# Steinbogen mit Pfoten-Emblem direkt vor dem Spawn (keine Collision).
	xforms.append(_xform(Vector3(-2.55, 1.75, 1.35), Vector3(0.78, 3.5, 0.82)))
	xforms.append(_xform(Vector3(2.55, 1.75, 1.35), Vector3(0.78, 3.5, 0.82)))
	xforms.append(_xform(Vector3(-2.55, 3.62, 1.35), Vector3(1.02, 0.38, 1.02)))
	xforms.append(_xform(Vector3(2.55, 3.62, 1.35), Vector3(1.02, 0.38, 1.02)))
	for i in range(13):
		var wt: float = float(i) / 12.0
		var wangle: float = PI * (1.0 - wt)
		var wx: float = cos(wangle) * 2.55
		var wy: float = 3.45 + sin(wangle) * 2.05
		xforms.append(_xform(Vector3(wx, wy, 1.35), Vector3(0.95, 0.48, 0.9), wangle - PI * 0.5))
	# Kompass-Sockel neben dem Start (rechts vom Pfad).
	xforms.append(_xform(Vector3(2.45, 0.2, 4.55), Vector3(1.25, 0.4, 1.25)))
	xforms.append(_xform(Vector3(2.45, 0.72, 4.55), Vector3(0.58, 0.85, 0.58)))
	xforms.append(_xform(Vector3(2.45, 1.22, 4.55), Vector3(1.35, 0.18, 1.35)))
	# Felsen für den sichtbaren Start-Wasserfall links vom Pfad.
	xforms.append(_xform(Vector3(-12.6, 1.35, 2.1), Vector3(3.4, 2.7, 2.2), 0.18))
	xforms.append(_xform(Vector3(-11.4, 2.55, 1.6), Vector3(2.2, 2.1, 1.6), -0.22))
	xforms.append(_xform(Vector3(-13.5, 0.7, 3.2), Vector3(1.8, 1.4, 1.5), 0.4))
	xforms.append(_xform(Vector3(-10.6, 0.55, 3.4), Vector3(1.35, 1.1, 1.2), -0.3))
	# Offene Schatzkammer hinter der echten GLB-Truhe.
	xforms.append(_xform(Vector3(0.0, 2.2, -69.45), Vector3(7.6, 4.4, 0.58)))
	xforms.append(_xform(Vector3(-3.95, 2.05, -67.35), Vector3(0.58, 4.1, 3.7)))
	xforms.append(_xform(Vector3(3.95, 2.05, -67.35), Vector3(0.58, 4.1, 3.7)))
	xforms.append(_xform(Vector3(-3.45, 2.45, -65.35), Vector3(0.74, 4.9, 0.74)))
	xforms.append(_xform(Vector3(3.45, 2.45, -65.35), Vector3(0.74, 4.9, 0.74)))
	xforms.append(_xform(Vector3(0.0, 4.55, -65.55), Vector3(7.4, 0.58, 0.74)))
	xforms.append(_xform(Vector3(0.0, 0.045, -67.05), Vector3(7.2, 0.09, 4.4)))
	BuildVoxelStyle.multimesh(
		root,
		"TreasureStoneDressing",
		mesh,
		BuildVoxelStyle.material("stone", Color("6a645a")),
		xforms
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
		root, "TreasurePawPath", mesh, _mat(Color("d4a018"), Color("ffcc44"), 1.25), xforms
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


static func _waterfall_dressing(root: Node3D, mesh: BoxMesh, sparkles: int) -> void:
	var water: Array[Transform3D] = []
	water.append(_xform(Vector3(13.0, 0.07, -20.7), Vector3(7.4, 0.16, 4.2)))
	water.append(_xform(Vector3(16.0, 0.07, -20.7), Vector3(4.6, 0.14, 3.2)))
	water.append(_xform(Vector3(19.0, 0.07, -20.7), Vector3(3.4, 0.12, 2.6)))
	water.append(_xform(Vector3(14.6, 0.16, -20.05), Vector3(6.6, 0.1, 1.15)))
	# Teich und Fall links vom Start, im Blick der Startkamera.
	water.append(_xform(Vector3(-12.2, 0.1, 3.8), Vector3(6.2, 0.2, 4.8)))
	water.append(_xform(Vector3(-12.4, 2.05, 2.15), Vector3(1.45, 3.8, 0.32)))
	water.append(_xform(Vector3(-11.5, 1.75, 1.95), Vector3(1.15, 3.2, 0.28)))
	water.append(_xform(Vector3(-13.1, 1.55, 2.25), Vector3(0.95, 2.8, 0.24)))
	water.append(_xform(Vector3(-12.2, 0.28, 2.85), Vector3(3.0, 0.18, 1.6)))
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.32, 0.62, 0.78, 0.58)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.16
	water_mat.metallic = 0.08
	water_mat.emission_enabled = true
	water_mat.emission = Color("7ec8e8")
	water_mat.emission_energy_multiplier = 0.38
	BuildVoxelStyle.multimesh(root, "TreasureFallsWater", mesh, water_mat, water)
	if sparkles <= 0:
		return
	var mist := GPUParticles3D.new()
	mist.name = "TreasureFallsMist"
	mist.position = Vector3(16.0, 2.5, -20.2)
	mist.amount = mini(28, sparkles)
	mist.lifetime = 2.2
	mist.visibility_aabb = AABB(Vector3(-6, -3, -4), Vector3(12, 8, 8))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(3.2, 1.7, 0.4)
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
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.92, 0.62, 0.13)
	mat.emission_enabled = true
	mat.emission = Color("ffe7a1")
	mat.emission_energy_multiplier = 0.8
	BuildVoxelStyle.multimesh(root, "TreasureLightRays", mesh, mat, rays)


static func _sea(root: Node3D) -> void:
	var sea := MeshInstance3D.new()
	sea.name = "TreasureSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(280, 280)
	sea.mesh = plane
	sea.position = Vector3(0.0, -1.65, -22.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.42, 0.58, 1.0)
	mat.roughness = 0.2
	mat.metallic = 0.18
	mat.emission_enabled = true
	mat.emission = Color("2a6a88")
	mat.emission_energy_multiplier = 0.22
	sea.material_override = mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sea)


static func _foliage(root: Node3D, mesh: BoxMesh, density: float) -> void:
	var xforms: Array[Transform3D] = []
	# Ranken am Startbogen.
	for i in range(7):
		var y: float = 0.45 + float(i) * 0.42
		xforms.append(_xform(Vector3(-2.95, y, 1.35), Vector3(0.16, 0.48, 0.16), 0.35))
		xforms.append(_xform(Vector3(2.95, y, 1.35), Vector3(0.16, 0.48, 0.16), -0.35))
		xforms.append(_xform(Vector3(-2.15, y + 0.1, 1.55), Vector3(0.14, 0.4, 0.14), -0.5))
		xforms.append(_xform(Vector3(2.15, y + 0.1, 1.55), Vector3(0.14, 0.4, 0.14), 0.5))
	# Farne im Vordergrund und am Wegrand (zwischen Kamera und Spawn).
	var ferns: Array = [
		Vector3(-4.4, 0.0, 11.6),
		Vector3(5.1, 0.0, 10.8),
		Vector3(-5.6, 0.0, 8.4),
		Vector3(5.8, 0.0, 7.6),
		Vector3(-6.4, 0.0, 13.2),
		Vector3(6.8, 0.0, 12.4),
		Vector3(-3.9, 0.0, 5.2),
		Vector3(4.6, 0.0, 4.4),
		Vector3(-7.2, 0.0, 9.5),
		Vector3(7.4, 0.0, 9.0),
		Vector3(-5.0, 0.0, 15.4),
		Vector3(6.0, 0.0, 14.6),
		Vector3(-8.1, 0.0, 6.2),
		Vector3(8.2, 0.0, 5.5),
		Vector3(-4.8, 0.0, 2.4),
		Vector3(4.4, 0.0, 1.8),
	]
	var count: int = maxi(8, int(round(float(ferns.size()) * density)))
	for i in range(count):
		var at: Vector3 = ferns[i]
		xforms.append(_xform(Vector3(at.x, 0.55, at.z), Vector3(0.22, 1.1, 0.12), float(i) * 0.4))
		xforms.append(
			_xform(
				Vector3(at.x + 0.12, 0.42, at.z + 0.08),
				Vector3(0.16, 0.82, 0.1),
				float(i) * 0.4 + 0.5
			)
		)
		xforms.append(
			_xform(
				Vector3(at.x - 0.1, 0.38, at.z - 0.06),
				Vector3(0.14, 0.7, 0.1),
				float(i) * 0.4 - 0.45
			)
		)
	BuildVoxelStyle.multimesh(root, "TreasureFoliage", mesh, _mat(Color("3d8f36")), xforms)


static func _flowers(root: Node3D, mesh: BoxMesh, density: float) -> void:
	var purple: Array[Transform3D] = []
	var blue: Array[Transform3D] = []
	var spots: Array = [
		Vector3(-3.6, 0.0, 10.2),
		Vector3(4.4, 0.0, 9.4),
		Vector3(-5.2, 0.0, 7.1),
		Vector3(5.4, 0.0, 6.4),
		Vector3(-6.0, 0.0, 12.0),
		Vector3(6.2, 0.0, 11.2),
		Vector3(-3.4, 0.0, 3.8),
		Vector3(3.8, 0.0, 3.1),
		Vector3(-7.0, 0.0, 8.2),
		Vector3(7.1, 0.0, 7.5),
		Vector3(-4.6, 0.0, 14.0),
		Vector3(5.2, 0.0, 13.3),
		Vector3(-8.4, 0.0, 4.6),
		Vector3(3.6, 0.0, 1.2),
		Vector3(-2.9, 0.0, 8.6),
		Vector3(2.9, 0.0, 8.0),
	]
	var count: int = maxi(8, int(round(float(spots.size()) * density)))
	for i in range(count):
		var at: Vector3 = spots[i]
		var dest: Array[Transform3D] = purple if i % 2 == 0 else blue
		dest.append(_xform(Vector3(at.x, 0.22, at.z), Vector3(0.06, 0.44, 0.06)))
		dest.append(_xform(Vector3(at.x, 0.5, at.z), Vector3(0.2, 0.16, 0.2)))
		dest.append(_xform(Vector3(at.x + 0.22, 0.18, at.z + 0.16), Vector3(0.05, 0.36, 0.05)))
		dest.append(_xform(Vector3(at.x + 0.22, 0.4, at.z + 0.16), Vector3(0.16, 0.13, 0.16)))
	# Eine Farbe pro MultiMesh, beide im selben Draw-Call-Budget wie zwei Batches.
	BuildVoxelStyle.multimesh(
		root, "TreasureFlowersPurple", mesh, _mat(Color("7a4ad6"), Color("b28cff"), 0.45), purple
	)
	BuildVoxelStyle.multimesh(
		root, "TreasureFlowersBlue", mesh, _mat(Color("3a78e0"), Color("7eb6ff"), 0.45), blue
	)
