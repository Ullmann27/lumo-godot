## StarField - performantes Sternenfeld via MultiMeshInstance3D.
##
## EIN Draw-Call fuer ALLE Sterne. Statt 80 einzelner Nodes.
## Sterne haben zufaellige Positionen auf einer Kugelschale, zufaellige
## warme Farbe (Gold/Bernstein/Tuerkis) und leichtes Bobbing pro Frame
## (nur ein Subset wird pro Frame animiert -> guenstig).
extends MultiMeshInstance3D

const PALETTE: Array[Color] = [
	Color(1.00, 0.85, 0.45, 1),  # gold
	Color(1.00, 0.62, 0.28, 1),  # warm amber
	Color(0.45, 0.85, 0.95, 1),  # turquoise
	Color(0.95, 0.55, 0.85, 1),  # soft magenta
]

@export var star_count: int = 80
@export var radius_min: float = 3.5
@export var radius_max: float = 8.5
@export var size_min: float = 0.04
@export var size_max: float = 0.11
@export var bob_amount: float = 0.18
@export var bob_speed: float = 0.6

var _base_positions: PackedVector3Array = PackedVector3Array()
var _base_scales: PackedFloat32Array = PackedFloat32Array()
var _time: float = 0.0


func _ready() -> void:
	_build_multimesh()


func _build_multimesh() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.85, 0.55, 1)
	mat.emission_energy_multiplier = 1.6
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	sphere.material = mat
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sphere
	mm.instance_count = star_count
	multimesh = mm
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	_base_positions.resize(star_count)
	_base_scales.resize(star_count)
	for i in range(star_count):
		var theta: float = rng.randf() * TAU
		var phi: float = acos(2.0 * rng.randf() - 1.0)
		var r: float = lerp(radius_min, radius_max, rng.randf())
		var pos: Vector3 = Vector3(
			r * sin(phi) * cos(theta),
			r * cos(phi) * 0.5 + 1.0,
			r * sin(phi) * sin(theta),
		)
		var size: float = lerp(size_min, size_max, rng.randf())
		var basis: Basis = Basis().scaled(Vector3(size, size, size))
		var xform: Transform3D = Transform3D(basis, pos)
		mm.set_instance_transform(i, xform)
		mm.set_instance_color(i, PALETTE[rng.randi() % PALETTE.size()])
		_base_positions[i] = pos
		_base_scales[i] = size


func _process(delta: float) -> void:
	_time += delta
	if multimesh == null:
		return
	# Subset-Animation: nur 10 Sterne pro Frame anfassen, weniger Cost.
	var subset: int = 10
	var frame_offset: int = wrapi(Engine.get_frames_drawn(), 0, star_count)
	for j in range(subset):
		var i: int = (frame_offset + j) % star_count
		var base_pos: Vector3 = _base_positions[i]
		var size: float = _base_scales[i]
		var phase: float = float(i) * 0.13
		var dy: float = sin(_time * bob_speed + phase) * bob_amount
		var basis: Basis = Basis().scaled(Vector3(size, size, size))
		var pos: Vector3 = base_pos + Vector3(0, dy, 0)
		multimesh.set_instance_transform(i, Transform3D(basis, pos))
