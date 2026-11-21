extends Node3D
## 3D-Zwanziger-Rechenrahmen mit Fünferstruktur (je Reihe 5 rote, 5 weiße
## Perlen). Perlen links zählen. Zwei MultiMeshes halten alle 20 Perlen in zwei
## Draw Calls; Bewegungen federn weich, mit „Animationen reduzieren“ sofort.

const SLOT := 0.56
const BEAD := 0.5
const ROD_Y: Array[float] = [1.9, 1.05]
const LEFT := -4.3
const RIGHT := 4.3
const SPRING := 14.0

var reduced_motion := false
var counts: Array[int] = [0, 0]
var _current: Array[float] = []
var _red: MultiMeshInstance3D
var _white: MultiMeshInstance3D
var _labels: Array[Label3D] = []
var _ten_glow: Array[MeshInstance3D] = []
var _settled := true


func _ready() -> void:
	name = "LumoNachhilfeRechenrahmen"
	_build()
	for index in range(20):
		_current.append(_target_x(floori(index / 10.0), index % 10))
	_apply()


func _material(
	color: Color, rough: float, metal: float = 0.0, glow: float = 0.0
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	material.metallic = metal
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


func _build() -> void:
	var wood := _material(Color("b97a45"), 0.55)
	var wood_dark := _material(Color("7a4a26"), 0.6)
	var metal := _material(Color("dfe7ef"), 0.25, 0.85)
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.36, 2.9, 0.5)
		post.mesh = post_mesh
		post.material_override = wood
		post.position = Vector3(side * (RIGHT + 0.35), 1.45, 0)
		add_child(post)
		var cap := MeshInstance3D.new()
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = 0.24
		cap_mesh.height = 0.48
		cap.mesh = cap_mesh
		cap.material_override = wood_dark
		cap.position = Vector3(side * (RIGHT + 0.35), 2.98, 0)
		add_child(cap)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3((RIGHT + 0.8) * 2.0, 0.28, 1.3)
	base.mesh = base_mesh
	base.material_override = wood_dark
	base.position = Vector3(0, 0.14, 0)
	add_child(base)
	for row in range(2):
		var rod := MeshInstance3D.new()
		var rod_mesh := CylinderMesh.new()
		rod_mesh.top_radius = 0.045
		rod_mesh.bottom_radius = 0.045
		rod_mesh.height = (RIGHT + 0.35) * 2.0
		rod.mesh = rod_mesh
		rod.material_override = metal
		rod.rotation.z = PI * 0.5
		rod.position = Vector3(0, ROD_Y[row], 0)
		add_child(rod)
		var label := Label3D.new()
		label.name = "Reihe%dZahl" % (row + 1)
		label.font_size = 96
		label.pixel_size = 0.006
		label.outline_size = 18
		label.modulate = Color("fff6d8")
		label.outline_modulate = Color("10243a")
		label.position = Vector3(RIGHT + 1.15, ROD_Y[row], 0.1)
		label.no_depth_test = false
		add_child(label)
		_labels.append(label)
		var glow := MeshInstance3D.new()
		var glow_mesh := BoxMesh.new()
		glow_mesh.size = Vector3(SLOT * 10.0 + 0.2, 0.62, 0.08)
		glow.mesh = glow_mesh
		var glow_material := _material(Color("ffc94a"), 0.4, 0.0, 1.6)
		glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow_material.albedo_color.a = 0.32
		glow.material_override = glow_material
		glow.position = Vector3(LEFT + SLOT * 4.5, ROD_Y[row], -0.32)
		glow.visible = false
		add_child(glow)
		_ten_glow.append(glow)
	_red = _beads(Color("e53935"), "RotePerlen")
	_white = _beads(Color("f4f7fb"), "WeissePerlen")


func _beads(color: Color, label: String) -> MultiMeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = BEAD * 0.5
	mesh.height = BEAD
	mesh.radial_segments = 20
	mesh.rings = 10
	var material := _material(color, 0.28, 0.05)
	material.clearcoat_enabled = true
	material.clearcoat = 0.6
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = 10
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	add_child(node)
	return node


func _target_x(row: int, index: int) -> float:
	if index < counts[row]:
		return LEFT + index * SLOT
	return RIGHT - (9 - index) * SLOT


func set_counts(row1: int, row2: int, animate: bool = true) -> void:
	counts = [clampi(row1, 0, 10), clampi(row2, 0, 10)]
	if not animate or reduced_motion:
		for index in range(20):
			_current[index] = _target_x(floori(index / 10.0), index % 10)
	_settled = false
	_apply()


func is_settled() -> bool:
	return _settled


func bead_position(row: int, index: int) -> Vector3:
	return to_global(Vector3(_current[row * 10 + index], ROD_Y[row], 0))


func row_anchor(row: int) -> Vector3:
	return to_global(Vector3(LEFT + SLOT * 4.5, ROD_Y[row], 0))


## Mitte der links gezählten Perlen einer Reihe (dorthin zeigt Lumo).
func counted_anchor(row: int) -> Vector3:
	var count := maxi(1, counts[row])
	return to_global(Vector3(LEFT + SLOT * (count - 1) * 0.5, ROD_Y[row], 0))


func _process(delta: float) -> void:
	if _settled:
		return
	var moving := false
	for index in range(20):
		var goal := _target_x(floori(index / 10.0), index % 10)
		var value := _current[index]
		if absf(goal - value) > 0.002:
			_current[index] = lerpf(value, goal, minf(1.0, delta * SPRING))
			moving = true
		else:
			_current[index] = goal
	_settled = not moving
	_apply()


func _apply() -> void:
	if _red == null:
		return
	for row in range(2):
		for index in range(10):
			var position := Vector3(_current[row * 10 + index], ROD_Y[row], 0)
			var basis := Basis.from_euler(Vector3(0, 0, PI * 0.5)).scaled(Vector3(0.82, 1.0, 1.0))
			var transform := Transform3D(basis, position)
			# Fünferstruktur: Perlen 0–4 rot, 5–9 weiß in jeder Reihe.
			if index < 5:
				_red.multimesh.set_instance_transform(row * 5 + index, transform)
			else:
				_white.multimesh.set_instance_transform(row * 5 + index - 5, transform)
		_labels[row].text = str(counts[row])
		_ten_glow[row].visible = counts[row] == 10


## Bildschirm-Treffer: Vector2i(reihe 1|2, perlenindex) oder (-1, -1).
func pick(camera: Camera3D, screen: Vector2, tolerance: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := tolerance
	for row in range(2):
		for index in range(10):
			var point := camera.unproject_position(bead_position(row, index))
			var distance := point.distance_to(screen)
			if distance < best_distance:
				best_distance = distance
				best = Vector2i(row + 1, index)
	return best


## Anzahl links, wenn ein Finger in Reihe [row] bei screen.x steht (Ziehen).
func count_at(camera: Camera3D, row: int, screen_x: float) -> int:
	var left := (
		camera.unproject_position(to_global(Vector3(LEFT - SLOT * 0.5, ROD_Y[row - 1], 0))).x
	)
	var right := (
		camera.unproject_position(to_global(Vector3(LEFT + SLOT * 9.5, ROD_Y[row - 1], 0))).x
	)
	if right - left < 1.0:
		return counts[row - 1]
	return clampi(roundi((screen_x - left) / (right - left) * 10.0), 0, 10)


## Bildschirmpunkt, an dem ein Finger in Reihe [row] [count] Perlen links hält
## (Umkehrung von count_at; für Bildbelege und Tests).
func count_point(camera: Camera3D, row: int, count: int) -> Vector2:
	var y_value := ROD_Y[row - 1]
	var left := camera.unproject_position(to_global(Vector3(LEFT - SLOT * 0.5, y_value, 0)))
	var right := camera.unproject_position(to_global(Vector3(LEFT + SLOT * 9.5, y_value, 0)))
	return left.lerp(right, clampf(count / 10.0, 0.0, 1.0))


func row_at(camera: Camera3D, screen: Vector2, tolerance: float) -> int:
	for row in range(2):
		var y := camera.unproject_position(row_anchor(row)).y
		if absf(screen.y - y) < tolerance:
			return row + 1
	return 0
