extends Node3D
## Eine Figur am Kartentisch: Lumo oder ein Mitspieler aus dem Figurenbestand.
## Sitzt auf ihrem Hocker, schaut dem Spiel zu, überlegt, freut und ärgert sich.
## Reine Darstellung – die Figur kennt weder Regeln noch Karten.

const LUMO = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const ROOM = preload("res://scripts/games/cards/cards_room.gd")
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const EMOTES := {
	"think": "res://assets/cards_table/ui/emote_think.webp",
	"happy": "res://assets/cards_table/ui/emote_happy.webp",
	"grumpy": "res://assets/cards_table/ui/emote_grumpy.webp",
	"idea": "res://assets/cards_table/ui/emote_idea.webp",
	"ask": "res://assets/cards_table/ui/emote_ask.webp",
}
const NAMES := {"lumo": "Lumo", "lion": "Leo", "owl": "Eule Ella", "rabbit": "Nova", "squirrel": "Fips", "turtle": "Toni"}
const TINTS := {
	"lumo": Color("ff9a3d"), "lion": Color("f4ae52"), "owl": Color("c7a585"),
	"rabbit": Color("c0abff"), "squirrel": Color("f39154"), "turtle": Color("8fd16a"),
}

var kind := ""
var display_name := ""
var tint := Color.WHITE
var seat_index := -1
var mood := "idle"
var reduced_motion := false
var suspended := false
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var _is_lumo := false
var _pivot: Node3D
var _head := -1
var _neck := -1
var _pelvis := -1
var _legs: Dictionary = {}
var _seat_anchor := Vector3.ZERO
var _look := Vector2.ZERO
var _look_goal := Vector2.ZERO
var _look_point := Vector3.ZERO
var _has_look := false
var _mood_left := 0.0
var _clock := 0.0
var _bubble: Sprite3D
var _bubble_tween: Tween
var _clip := ""
var _clip_left := 0.0
var _hop := 0.0


## Setzt die Figur auf ihren Platz. `seat` hat den Ursprung am Boden und
## schaut mit −Z zur Tischmitte.
func setup(id: String, seat: Transform3D, index: int) -> bool:
	kind = id
	seat_index = index
	display_name = str(NAMES.get(id, id.capitalize()))
	tint = TINTS.get(id, Color.WHITE)
	_is_lumo = id == "lumo"
	transform = seat
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_clock = float(index) * 1.7
	if _is_lumo:
		return _setup_lumo()
	return _setup_rival(id)


func _setup_rival(id: String) -> bool:
	var level := 1 if PerformanceManager.get_profile_name() != "low" else 2
	var path := ROSTER.racing_model_path(id, level)
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		push_warning("[CardsSeat] Figur fehlt: " + id)
		return false
	model = (load(path) as PackedScene).instantiate() as Node3D
	_pivot.add_child(model)
	for node: Node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = node
	for node: Node in model.find_children("*", "AnimationPlayer", true, false):
		player = node
	if skeleton == null or player == null or not player.has_animation("kart_seated"):
		return false
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.get_animation("kart_seated").loop_mode = Animation.LOOP_LINEAR
	player.play("kart_seated")
	player.seek(fmod(_clock, 3.0), true)
	_head = skeleton.find_bone("Head")
	_neck = skeleton.find_bone("Neck")
	_build_bubble(1.95)
	return true


func _setup_lumo() -> bool:
	var actor: Node3D = LUMO.new()
	actor.name = "OriginalLumo"
	_pivot.add_child(actor)
	# Lumos Modell schaut nach +Z, der Platz nach −Z.
	actor.rotation.y = PI
	actor.scale = Vector3.ONE * 1.14
	model = actor
	if not actor.is_usable():
		return false
	skeleton = actor.skeleton
	player = actor.player
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor.play_behavior("kart_seated")
	player.stop()
	player.play("kart_seated", 0.0)
	player.advance(0.0)
	player.seek(0.3, true)
	skeleton.force_update_all_bone_transforms()
	_pelvis = skeleton.find_bone("Pelvis")
	_head = skeleton.find_bone("Head")
	_neck = skeleton.find_bone("Neck")
	for side: String in ["L", "R"]:
		for part: String in ["Thigh.", "Shin.", "Foot.", "Toe.", "ToeTip."]:
			var bone: int = skeleton.find_bone(part + side)
			if bone >= 0:
				_legs[bone] = skeleton.get_bone_pose_rotation(bone)
	actor.behavior_finished.connect(_lumo_finished)
	_seat_anchor = Vector3(0, ROOM.STOOL_HEIGHT + 0.14 + ROOM.LUMO_LIFT, 0.04)
	_build_bubble(1.98)
	advance(0.0)
	return _pelvis >= 0 and _legs.size() == 10


func _lumo_finished(_behavior: String) -> void:
	if is_instance_valid(model) and not suspended:
		model.play_behavior("kart_seated")


func usable() -> bool:
	return is_instance_valid(skeleton) and is_instance_valid(player)


func _build_bubble(height: float) -> void:
	_bubble = Sprite3D.new()
	_bubble.name = "Emote"
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.shaded = false
	_bubble.double_sided = true
	_bubble.no_depth_test = true
	_bubble.render_priority = 4
	_bubble.pixel_size = 0.0034
	_bubble.position = Vector3(0.34, height + 0.2, 0)
	_bubble.visible = false
	add_child(_bubble)


## Zeigt kurz eine Denk- oder Gefühlsblase über dem Kopf.
func emote(what: String, seconds: float = 1.6) -> void:
	if not EMOTES.has(what) or _bubble == null:
		return
	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()
	_bubble.texture = load(EMOTES[what])
	_bubble.visible = true
	_bubble.scale = Vector3.ONE * (1.0 if reduced_motion else 0.2)
	_bubble_tween = create_tween()
	if not reduced_motion:
		_bubble_tween.tween_property(_bubble, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bubble_tween.tween_interval(seconds)
	_bubble_tween.tween_callback(func() -> void: _bubble.visible = false)


func hide_emote() -> void:
	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()
	if _bubble != null:
		_bubble.visible = false


func look_at_point(world: Vector3) -> void:
	_look_point = world
	_has_look = true


func look_home() -> void:
	_has_look = false


## Stimmung: idle, think, happy, grumpy, play, wave, nod, point.
func react(what: String) -> void:
	if suspended:
		return
	mood = what
	match what:
		"think":
			_mood_left = 30.0
			emote("think", 30.0)
		"happy":
			_mood_left = 1.9
			_hop = 1.0
			emote("happy", 1.5)
			_play_clip("celebrate", 1.9)
		"grumpy":
			_mood_left = 1.5
			emote("grumpy", 1.3)
		"play":
			_mood_left = 0.55
			hide_emote()
			_play_clip("kart_steer_right" if seat_index % 2 == 0 else "kart_steer_left", 0.55)
		"wave":
			_mood_left = 1.8
			_play_clip("greeting_wave", 1.8)
		"nod":
			_mood_left = 1.1
			_play_clip("agree_nod", 1.1)
		"point":
			_mood_left = 1.6
			_play_clip("point_portal", 1.6)
		_:
			mood = "idle"
			_mood_left = 0.0
			hide_emote()


func calm() -> void:
	if mood == "think":
		mood = "idle"
		_mood_left = 0.0
		hide_emote()


func _play_clip(clip: String, seconds: float) -> void:
	if not usable() or reduced_motion:
		return
	if _is_lumo:
		if model.CLIPS.has(clip):
			model.play_behavior(clip)
		return
	if not player.has_animation(clip):
		return
	_clip = clip
	_clip_left = seconds
	player.play(clip, 0.15)


func set_suspended(value: bool) -> void:
	suspended = value
	if _is_lumo and is_instance_valid(model):
		model.set_suspended(value)


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value


## Einmal je Bild vom Tisch aufgerufen: Animation, Blick, kleine Körpersprache.
func advance(delta: float) -> void:
	if not usable():
		return
	var step := 0.0 if (suspended or reduced_motion) else minf(delta, 0.1)
	_clock += step
	if _mood_left > 0.0:
		_mood_left -= step
		if _mood_left <= 0.0:
			mood = "idle"
	player.advance(step)
	if not _is_lumo and not _clip.is_empty():
		_clip_left -= step
		if _clip_left <= 0.0:
			_clip = ""
			player.play("kart_seated", 0.25)
	if _is_lumo:
		for bone: int in _legs:
			skeleton.set_bone_pose_rotation(bone, _legs[bone])
	_apply_look(step)
	_apply_body(step)
	if _is_lumo:
		# Becken bleibt auf dem Kissen, egal was der Oberkörper tut.
		skeleton.force_update_all_bone_transforms()
		var hips: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(_pelvis).origin)
		model.global_position += to_global(_seat_anchor) - hips


func _apply_look(step: float) -> void:
	if _head < 0:
		return
	var goal := Vector2.ZERO
	if _has_look:
		var head_at: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(_head).origin)
		var local := global_basis.inverse() * (_look_point - head_at)
		var flat := Vector2(local.x, local.z).length()
		goal.x = clampf(atan2(-local.x, -local.z), -1.0, 1.0)
		goal.y = clampf(atan2(local.y, maxf(flat, 0.001)), -0.5, 0.35)
	match mood:
		"think":
			goal += Vector2(0.22 * sin(_clock * 0.9), 0.16 + 0.05 * sin(_clock * 1.7))
		"grumpy":
			goal += Vector2(0.28 * sin(_clock * 15.0), -0.32)
		"happy":
			goal.y += 0.2
	_look_goal = goal
	var blend := 1.0 if reduced_motion else clampf(step * 7.0, 0.0, 1.0)
	_look = _look.lerp(_look_goal, blend)
	# Drehung im Raum der Figur, verteilt auf Hals und Kopf.
	var to_skeleton := (skeleton.global_basis.inverse() * global_basis).orthonormalized()
	var up := (to_skeleton * Vector3.UP).normalized()
	var right := (to_skeleton * Vector3.RIGHT).normalized()
	for part: Array in [[_neck, 0.35], [_head, 0.65]]:
		var bone: int = part[0]
		if bone < 0:
			continue
		var share: float = part[1]
		var turn := Quaternion(up, _look.x * share) * Quaternion(right, _look.y * share)
		var parent := skeleton.get_bone_parent(bone)
		var parent_rotation := Quaternion.IDENTITY
		if parent >= 0:
			parent_rotation = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
		var current := skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(bone, (parent_rotation.inverse() * turn * current).normalized())


func _apply_body(step: float) -> void:
	var lean := 0.0
	var sway := 0.0
	var lift := 0.0
	var breath := 0.012 * sin(_clock * 1.6)
	match mood:
		"think":
			lean = -0.05
			sway = 0.035 * sin(_clock * 1.1)
		"grumpy":
			lean = -0.09
			sway = 0.05 * sin(_clock * 17.0) * clampf(_mood_left, 0.0, 1.0)
		"play":
			lean = -0.16 * sin(clampf(_mood_left / 0.55, 0.0, 1.0) * PI)
		"happy":
			lift = 0.10 * absf(sin(_clock * 9.0)) * clampf(_mood_left / 1.2, 0.0, 1.0)
	if reduced_motion:
		lift = 0.0
		sway = 0.0
		breath = 0.0
	var blend := 1.0 if reduced_motion else clampf(step * 9.0, 0.0, 1.0)
	_pivot.rotation.x = lerpf(_pivot.rotation.x, lean, blend)
	_pivot.rotation.z = lerpf(_pivot.rotation.z, sway, blend)
	_pivot.position.y = lerpf(_pivot.position.y, lift, blend)
	_pivot.scale = Vector3(1.0 - breath * 0.5, 1.0 + breath, 1.0 - breath * 0.5)


## Mitte des Kartenfächers vor der Brust (Weltkoordinaten), Karten zur Figur.
func fan_transform() -> Transform3D:
	var tilt := deg_to_rad(18.0)
	var basis := Basis(Vector3.RIGHT, Vector3(0, sin(tilt), cos(tilt)), Vector3(0, -cos(tilt), sin(tilt)))
	return global_transform * Transform3D(basis, Vector3(0, 1.08, -0.44))


func head_top() -> Vector3:
	# Über Ohren und Brille: das Namensschild darf kein Gesicht verdecken.
	return to_global(Vector3(0, 2.16 if not _is_lumo else 1.95, 0.0))


func chest() -> Vector3:
	return to_global(Vector3(0, 1.2, -0.25))
