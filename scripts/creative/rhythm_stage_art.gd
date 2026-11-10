class_name RhythmStageArt
extends RefCounted

## Konzertbühne für Rhythm Party: LED-Wand, Scheinwerfer, Trefferlinie,
## Bühnenlippe und Dekor. Keine Änderung an Timing, Spuren oder Kollision.


static func apply(root: Node3D) -> void:
	var budget: Dictionary = LumoQuality.budget()
	var density: float = clampf(float(budget.get("decor_density", 1.0)), 0.35, 1.0)
	var sparkles: int = int(budget.get("sparkles", 24))
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_backdrop(root, box, density)
	_hit_rail(root, box)
	_stage_lip(root, box)
	_spotlights(root, sparkles)
	_stars(root, box, sparkles)
	_podium(root, box)


static func _mat(
	albedo: Color, emission: Color = Color.BLACK, energy: float = 0.0
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.72
	mat.metallic = 0.08
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	return mat


static func _xform(origin: Vector3, size: Vector3, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(size), origin)


static func _backdrop(root: Node3D, mesh: BoxMesh, density: float) -> void:
	var panel := MeshInstance3D.new()
	panel.name = "RhythmBackdrop"
	var slab := BoxMesh.new()
	slab.size = Vector3(17.6, 11.2, 0.32)
	panel.mesh = slab
	panel.position = Vector3(0.0, 5.6, -33.55)
	panel.material_override = _mat(Color("14081f"))
	root.add_child(panel)
	var palette: Array[Color] = [
		Color("62dcff"), Color("b997ff"), Color("ffc985"), Color("77efbd"), Color("ff8ad4")
	]
	var rows: int = 6 if density > 0.55 else 4
	var cols: int = 16 if density > 0.55 else 12
	# Eine MultiMesh-Farbe: violett-cyan Mischton; Akzente als zweite Charge.
	var tiles: Array[Transform3D] = []
	var accents: Array[Transform3D] = []
	for row in range(rows):
		for col in range(cols):
			var x: float = (float(col) - float(cols - 1) * 0.5) * 1.02
			var y: float = 1.15 + float(row) * 1.55
			var pulse: float = 0.22 + 0.10 * float((row + col) % 3)
			var xform := _xform(Vector3(x, y, -33.28), Vector3(0.84, 1.22, pulse))
			if (row + col) % 4 == 0:
				accents.append(xform)
			else:
				tiles.append(xform)
	BuildVoxelStyle.multimesh(
		root, "RhythmLeds", mesh, _mat(Color("5a3cff"), Color("7a5cff"), 0.85), tiles
	)
	BuildVoxelStyle.multimesh(
		root,
		"RhythmLedAccents",
		mesh,
		_mat(Color("ff8ad4"), Color("ffa0e0"), 1.05),
		accents
	)
	var curtain: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		curtain.append(_xform(Vector3(side * 8.55, 5.8, -33.1), Vector3(1.15, 11.4, 0.55)))
		curtain.append(_xform(Vector3(side * 8.55, 11.3, -22.0), Vector3(1.05, 0.42, 22.4)))
	curtain.append(_xform(Vector3(0.0, 11.35, -33.0), Vector3(18.2, 0.48, 0.7)))
	BuildVoxelStyle.multimesh(
		root, "RhythmTruss", mesh, _mat(Color("241436"), Color("3a2460"), 0.25), curtain
	)


static func _hit_rail(root: Node3D, mesh: BoxMesh) -> void:
	var rail: Array[Transform3D] = [
		_xform(Vector3(0.0, 0.08, 3.0), Vector3(10.4, 0.07, 0.42)),
		_xform(Vector3(0.0, 0.22, 3.18), Vector3(10.2, 0.05, 0.08))
	]
	for lane in range(4):
		var x: float = (float(lane) - 1.5) * 2.35
		rail.append(_xform(Vector3(x, 0.05, 3.0), Vector3(2.05, 0.04, 0.58)))
	BuildVoxelStyle.multimesh(
		root, "RhythmHitRail", mesh, _mat(Color("fff4c2"), Color("ffe37a"), 1.35), rail
	)


static func _stage_lip(root: Node3D, mesh: BoxMesh) -> void:
	var lip: Array[Transform3D] = [
		_xform(Vector3(0.0, 0.12, 5.15), Vector3(13.2, 0.22, 1.15)),
		_xform(Vector3(0.0, 0.42, 5.55), Vector3(13.4, 0.38, 0.28)),
	]
	for side in [-1.0, 1.0]:
		lip.append(_xform(Vector3(side * 6.35, 0.55, 4.4), Vector3(0.42, 1.05, 2.4)))
	BuildVoxelStyle.multimesh(
		root, "RhythmStageLip", mesh, _mat(Color("2a1850"), Color("4a2890"), 0.35), lip
	)
	var shine: Array[Transform3D] = [
		_xform(Vector3(0.0, 0.045, -8.0), Vector3(11.6, 0.02, 26.0))
	]
	BuildVoxelStyle.multimesh(
		root, "RhythmStageSheen", mesh, _mat(Color("2c1a4c"), Color("3d2470"), 0.2), shine
	)


static func _spotlights(root: Node3D, sparkles: int) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.08
	cone.bottom_radius = 1.85
	cone.height = 7.2
	cone.radial_segments = 12
	cone.rings = 1
	var xforms: Array[Transform3D] = []
	var positions: Array[Vector3] = [
		Vector3(-4.6, 8.4, -6.0),
		Vector3(0.0, 8.8, -10.5),
		Vector3(4.6, 8.4, -6.0)
	]
	if sparkles > 0:
		positions.append(Vector3(-2.2, 8.6, -16.0))
		positions.append(Vector3(2.2, 8.6, -16.0))
	for at in positions:
		var basis := Basis.from_euler(Vector3(deg_to_rad(18.0), 0.0, 0.0)).scaled(Vector3.ONE)
		xforms.append(Transform3D(basis, at))
	var mat := _mat(Color(1.0, 0.92, 0.75, 0.16), Color("ffe9b0"), 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	BuildVoxelStyle.multimesh(root, "RhythmSpots", cone, mat, xforms)


static func _stars(root: Node3D, mesh: BoxMesh, sparkles: int) -> void:
	if sparkles <= 0:
		return
	var count: int = mini(18, maxi(8, sparkles / 3))
	var xforms: Array[Transform3D] = []
	for i in range(count):
		var x: float = sin(float(i) * 0.9) * 7.6
		var y: float = 6.4 + float(i % 5) * 0.55
		var z: float = -28.0 + float(i % 4) * 3.4
		xforms.append(_xform(Vector3(x, y, z), Vector3(0.22, 0.22, 0.08), float(i) * 0.4))
	BuildVoxelStyle.multimesh(
		root, "RhythmStars", mesh, _mat(Color("ffe1a2"), Color("ffe9b8"), 1.2), xforms
	)


static func _podium(root: Node3D, mesh: BoxMesh) -> void:
	var xforms: Array[Transform3D] = [
		_xform(Vector3(0.0, 0.16, -21.8), Vector3(2.4, 0.32, 2.0)),
		_xform(Vector3(0.0, 0.38, -21.8), Vector3(1.7, 0.16, 1.45)),
	]
	BuildVoxelStyle.multimesh(
		root, "RhythmPodium", mesh, _mat(Color("3a2468"), Color("6a40b8"), 0.55), xforms
	)
