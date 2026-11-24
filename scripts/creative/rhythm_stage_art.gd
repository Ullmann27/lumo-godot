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
	_stars(root, box, sparkles)


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


static func _backdrop(root: Node3D, mesh: BoxMesh, _density: float) -> void:
	var panel := MeshInstance3D.new()
	panel.name = "RhythmBackdrop"
	var slab := BoxMesh.new()
	slab.size = Vector3(17.6, 11.2, 0.32)
	panel.mesh = slab
	panel.position = Vector3(0.0, 5.6, -33.55)
	panel.material_override = _mat(Color("14081f"))
	root.add_child(panel)
	var curtain: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		curtain.append(_xform(Vector3(side * 8.55, 5.8, -33.1), Vector3(1.15, 11.4, 0.55)))
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
	var shine: Array[Transform3D] = [_xform(Vector3(0.0, 0.045, -8.0), Vector3(11.6, 0.02, 26.0))]
	BuildVoxelStyle.multimesh(
		root, "RhythmStageSheen", mesh, _mat(Color("2c1a4c"), Color("3d2470"), 0.2), shine
	)


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
