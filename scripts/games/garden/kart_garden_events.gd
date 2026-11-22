extends RefCounted
## Runde zwei öffnet die Sicht und schaltet die Wasserbögen über der Fahrbahn ein.

const PASSAGES = preload("res://scripts/games/kart_passages.gd")
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


## Die Lok fährt nur während der Sperrphase über den linken Fahrstreifen und
## steht beim Öffnen der Schranke wieder hinter der Haltelinie.
func advance_train(elapsed: float) -> void:
	if not parts.has("train"):
		return
	var gate := PASSAGES.swing_state(parts.railway_gate, elapsed)
	var fraction := 0.0
	if gate.phase == "swing":
		fraction = sin(PI * float(gate.progress)) ** 2
	parts.train.position = (parts.train_rest as Vector3).lerp(parts.train_stop, fraction)
