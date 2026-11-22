extends RefCounted
## Runde zwei öffnet die Sicht und schaltet die Wasserbögen über der Fahrbahn ein.

const MORNING_DENSITY := 0.0045
const CLEAR_DENSITY := 0.0018
const CLEAR_SECONDS := 4.0

var environment: Environment
var parts: Dictionary
var low_detail: bool
var progress := 0.0
var second_lap_started := false


func _init(garden_environment: Environment, landmarks: Dictionary, low: bool) -> void:
	environment = garden_environment
	parts = landmarks
	low_detail = low


func advance(second_lap: bool, delta: float) -> void:
	# Auch beim Rückwärtsfahren über die Ziellinie läuft die Bewässerung weiter.
	second_lap_started = second_lap_started or second_lap
	if not second_lap_started or progress >= 1.0:
		return
	progress = move_toward(progress, 1.0, delta / CLEAR_SECONDS)
	var amount := smoothstep(0.0, 1.0, progress)
	environment.fog_density = lerpf(MORNING_DENSITY, CLEAR_DENSITY, amount)
	if parts.has("mist"):
		var mist_material: StandardMaterial3D = parts.mist_material
		mist_material.albedo_color.a = 0.16 * (1.0 - amount)
		parts.mist.visible = progress < 1.0
	for sprinkler in parts.sprinklers:
		sprinkler.arc.visible = true
		sprinkler.arc.material_override.set_shader_parameter("amount", amount)
		if not low_detail:
			sprinkler.rainbow.visible = true
			sprinkler.rainbow.material_override.set_shader_parameter("amount", amount)
