class_name LumoKartSpeedFx
extends Node3D
## Lightweight camera-local speed streaks for the Lumo race camera.
## Purely visual: no collision, speed, steering or item rule lives here.

const CYAN := Color("67ecff")
const GOLD := Color("ffd45c")
const VIOLET := Color("b890ff")
const STREAK_LAYOUT: Array[Vector3] = [
	Vector3(-3.65, -1.25, -7.0),
	Vector3(-2.85, 1.45, -8.4),
	Vector3(-2.35, -1.70, -10.2),
	Vector3(-1.85, 1.65, -11.4),
	Vector3(1.85, -1.65, -9.4),
	Vector3(2.35, 1.55, -10.8),
	Vector3(2.90, -1.35, -7.8),
	Vector3(3.55, 1.20, -9.9),
	Vector3(-4.05, 0.35, -12.0),
	Vector3(4.05, -0.25, -11.2),
	Vector3(-3.20, 0.78, -13.0),
	Vector3(3.10, -0.82, -12.6),
]

var streaks: Array[MeshInstance3D] = []
var phases: Array[float] = []
var speed_ratio: float = 0.0
var boosting: bool = false
var reduced_motion: bool = false


func _ready() -> void:
	_build()


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, 0.42)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.2
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _build() -> void:
	if not streaks.is_empty():
		return
	for index in range(STREAK_LAYOUT.size()):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.035, 0.028, 2.6 + float(index % 3) * 0.7)
		var node := MeshInstance3D.new()
		node.name = "SpeedStreak%02d" % index
		node.mesh = mesh
		node.position = STREAK_LAYOUT[index]
		node.material_override = _material(
			CYAN if index % 3 == 0 else (GOLD if index % 3 == 1 else VIOLET)
		)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		add_child(node)
		streaks.append(node)
		phases.append(float(index) / float(STREAK_LAYOUT.size()))


func set_motion(value: float, is_boosting: bool, reduce_motion: bool) -> void:
	speed_ratio = clampf(value, 0.0, 1.0)
	boosting = is_boosting
	reduced_motion = reduce_motion
	var active: bool = not reduced_motion and (boosting or speed_ratio >= 0.76)
	for index in range(streaks.size()):
		streaks[index].visible = active and (boosting or index % 2 == 0)


func _process(delta: float) -> void:
	if reduced_motion:
		return
	var intensity: float = 1.0 if boosting else clampf((speed_ratio - 0.76) / 0.24, 0.0, 1.0)
	if intensity <= 0.0:
		return
	var travel: float = lerpf(8.0, 24.0, intensity) * delta
	for index in range(streaks.size()):
		var node: MeshInstance3D = streaks[index]
		if not node.visible:
			continue
		node.position.z += travel
		if node.position.z > -2.4:
			node.position.z = -12.5 - phases[index] * 5.0
		var pulse: float = 0.82 + sin(Time.get_ticks_msec() * 0.014 + index) * 0.18
		node.scale = Vector3(1.0, 1.0, lerpf(0.72, 1.45, intensity) * pulse)


func visual_state() -> Dictionary:
	var visible_count: int = 0
	for node in streaks:
		if node.visible:
			visible_count += 1
	return {
		"speed_ratio": speed_ratio,
		"boosting": boosting,
		"reduced_motion": reduced_motion,
		"visible_count": visible_count,
	}
