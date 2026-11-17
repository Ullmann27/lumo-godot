extends Node3D
## Zahlenstrahl als Steinweg 0–20. Die 10 ist ein goldener Stein. Jeder
## gesprungene Einerschritt hinterlässt einen leuchtenden Bogen, damit das Kind
## Sprünge zählt, nicht Steine. Steine und Bogenpunkte sind MultiMeshes.

const SPACING := 1.0
const ARC_DOTS := 7
const MAX_HOPS := 40

var _stones: MultiMeshInstance3D
var _gold: MeshInstance3D
var _labels: Array[Label3D] = []
var _dots: MultiMeshInstance3D
var _hops := 0
var _highlight: MeshInstance3D


func _ready() -> void:
	name = "LumoNachhilfeZahlenstrahl"
	_build()


func stone_position(number: int) -> Vector3:
	return to_global(Vector3((number - 10) * SPACING, 0.18, 0))


func _material(color: Color, rough: float, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


func _build() -> void:
	var path := MeshInstance3D.new()
	var path_mesh := BoxMesh.new()
	path_mesh.size = Vector3(21.6 * SPACING, 0.06, 1.1)
	path.mesh = path_mesh
	path.material_override = _material(Color("2f5d7c"), 0.8)
	path.position = Vector3(0, 0.03, 0)
	add_child(path)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 0.44
	mesh.height = 0.24
	mesh.radial_segments = 24
	mesh.material = _material(Color("d8e3ec"), 0.55)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = 20
	_stones = MultiMeshInstance3D.new()
	_stones.name = "Steine"
	_stones.multimesh = multi
	add_child(_stones)
	var slot := 0
	for number in range(21):
		if number == 10:
			continue
		multi.set_instance_transform(slot, Transform3D(Basis(), Vector3((number - 10) * SPACING, 0.12, 0)))
		slot += 1
	_gold = MeshInstance3D.new()
	var gold_mesh := CylinderMesh.new()
	gold_mesh.top_radius = 0.46
	gold_mesh.bottom_radius = 0.5
	gold_mesh.height = 0.3
	gold_mesh.radial_segments = 24
	_gold.mesh = gold_mesh
	_gold.name = "ZehnerStein"
	_gold.material_override = _material(Color("ffc94a"), 0.35, 0.6)
	_gold.position = Vector3(0, 0.15, 0)
	add_child(_gold)
	for number in range(21):
		var label := Label3D.new()
		label.text = str(number)
		label.font_size = 72
		label.pixel_size = 0.0065
		label.outline_size = 14
		label.modulate = Color("10243a") if number == 10 else Color("163a5c")
		label.outline_modulate = Color("ffffff")
		label.rotation.x = -PI * 0.5
		label.position = Vector3((number - 10) * SPACING, 0.32, 0)
		add_child(label)
		_labels.append(label)
	_highlight = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.46
	ring.outer_radius = 0.56
	_highlight.mesh = ring
	_highlight.material_override = _material(Color("73d4ed"), 0.3, 1.4)
	_highlight.visible = false
	add_child(_highlight)
	var dot := SphereMesh.new()
	dot.radius = 0.06
	dot.height = 0.12
	dot.radial_segments = 8
	dot.rings = 4
	dot.material = _material(Color("ffb347"), 0.3, 2.2)
	var dots := MultiMesh.new()
	dots.transform_format = MultiMesh.TRANSFORM_3D
	dots.mesh = dot
	dots.instance_count = MAX_HOPS * ARC_DOTS
	dots.visible_instance_count = 0
	_dots = MultiMeshInstance3D.new()
	_dots.name = "Sprungboegen"
	_dots.multimesh = dots
	add_child(_dots)


func clear_hops() -> void:
	_hops = 0
	_dots.multimesh.visible_instance_count = 0
	_highlight.visible = false


## Einen Einersprung als Bogen eintragen.
func add_hop(from_number: int, to_number: int) -> void:
	if _hops >= MAX_HOPS:
		return
	var start := Vector3((from_number - 10) * SPACING, 0.4, 0)
	var finish := Vector3((to_number - 10) * SPACING, 0.4, 0)
	for index in range(ARC_DOTS):
		var t := float(index + 1) / float(ARC_DOTS + 1)
		var point := start.lerp(finish, t)
		point.y += sin(t * PI) * 0.75
		_dots.multimesh.set_instance_transform(_hops * ARC_DOTS + index, Transform3D(Basis(), point))
	_hops += 1
	_dots.multimesh.visible_instance_count = _hops * ARC_DOTS


func hop_count() -> int:
	return _hops


func highlight(number: int) -> void:
	_highlight.visible = number >= 0 and number <= 20
	if _highlight.visible:
		_highlight.position = Vector3((number - 10) * SPACING, 0.3, 0)


func stone_at(camera: Camera3D, screen: Vector2, tolerance: float) -> int:
	var best := -1
	var best_distance := tolerance
	for number in range(21):
		var point := camera.unproject_position(stone_position(number))
		var distance := point.distance_to(screen)
		if distance < best_distance:
			best_distance = distance
			best = number
	return best
