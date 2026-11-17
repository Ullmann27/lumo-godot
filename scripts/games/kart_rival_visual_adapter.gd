extends Node3D
## Optional imported rival visual. The vehicle owns the only animation clock.
## Clips are authored in seated kart space; existing rigs/materials stay intact.
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const CONTRACT = preload("res://scripts/games/kart_rival_model_contract.gd")
const TICK_SECONDS := 1.0 / 30.0
var model: Node3D
var player: AnimationPlayer
var clips: Dictionary = {}
var suspended := false
var reduced_motion := false
var elapsed := 0.0
var _tick := 0.0
var _steer := 0.0
var _hit_remaining := 0.0
var _celebrating := false
var _current := ""


func bind_visual(_kart: Node3D, identity: String) -> bool:
	if model != null:
		return is_instance_valid(player)
	var scene: PackedScene = ROSTER.racing_scene(identity)
	if scene == null:
		return false
	return bind_scene(scene)


func bind_scene(scene: PackedScene) -> bool:
	if model != null or scene == null:
		return false
	var candidate: Node = scene.instantiate()
	var verified: Dictionary = CONTRACT.inspect(candidate)
	if not bool(verified.get("valid", false)):
		candidate.free()
		return false
	model = candidate as Node3D
	player = verified.player
	clips = verified.clips
	# Stop every imported player before it enters the live tree. Only our
	# validated seated clips can be evaluated, once, by the parent vehicle.
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	for imported: AnimationPlayer in players:
		imported.autoplay = ""
		imported.stop()
		imported.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		imported.set_process(false)
		imported.set_physics_process(false)
	add_child(model)
	set_process(false)
	_select_clip("kart_seated")
	player.advance(0.0)
	return true


func set_suspended(value: bool) -> void:
	if suspended == value:
		return
	suspended = value
	_tick = 0.0


func set_reduced_motion(value: bool) -> void:
	if reduced_motion == value:
		return
	reduced_motion = value
	_tick = 0.0
	if value and is_instance_valid(player):
		_hit_remaining = 0.0
		_select_clip("kart_seated")
		player.seek(0.0, true)


func apply_vehicle_sample(_speed: float, steer: float, _airborne: bool, hit: bool = false, _boost: bool = false, _drift: bool = false) -> void:
	_steer = clampf(steer, -1.0, 1.0) if is_finite(steer) else 0.0
	if hit and not suspended and not reduced_motion and clips.has("kart_hit"):
		_hit_remaining = minf(1.0, player.get_animation(clips.kart_hit).length)


func celebrate_finished_race(_place: int = 1) -> void:
	_celebrating = true


func clear_celebration() -> void:
	_celebrating = false


func _select_clip(key: String) -> void:
	if not clips.has(key):
		key = "kart_seated"
	if _current == key:
		return
	_current = key
	player.play(clips[key], 0.10 if not reduced_motion else 0.0)


func advance_tick(delta: float) -> void:
	if not is_instance_valid(player) or suspended or reduced_motion or not is_finite(delta) or delta <= 0.0:
		return
	_tick += delta
	if _tick + 0.000000001 < TICK_SECONDS:
		return
	# Preserve fractional time at 50/75/144 Hz, while discarding an unbounded
	# hitch backlog. The scene still receives at most one evaluation per frame.
	var intervals: int = floori((_tick + 0.000000001) / TICK_SECONDS)
	var consumed: float = intervals * TICK_SECONDS
	_tick = maxf(0.0, _tick - consumed)
	var step: float = minf(consumed, 0.10)
	elapsed += step
	var selected := "kart_seated"
	if _hit_remaining > 0.0:
		selected = "kart_hit"
		_hit_remaining = maxf(0.0, _hit_remaining - step)
	elif _celebrating:
		selected = "kart_celebrate"
	elif absf(_steer) > 0.30:
		selected = "kart_steer_left" if _steer < 0.0 else "kart_steer_right"
	_select_clip(selected)
	if not player.is_playing():
		player.play(clips[_current], 0.0)
	player.advance(step)
