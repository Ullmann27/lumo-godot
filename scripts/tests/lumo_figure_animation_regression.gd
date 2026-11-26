extends SceneTree
## Standing animal figures (assets/characters/animals): imported rig, clip set,
## lengths, loop flags, real foot contact in walk/run, rig integrity and the
## seams between clips that follow each other. Headless; no renderer needed.

const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const SPECIES := ["lion", "owl", "rabbit", "squirrel", "turtle", "frog", "otter", "badger", "cat"]
const BONES := [
	"Root",
	"Pelvis",
	"Spine",
	"Chest",
	"Neck",
	"Head",
	"Tail",
	"TailMid",
	"TailTip",
	"UpperArm.L",
	"Forearm.L",
	"Hand.L",
	"Thigh.L",
	"Shin.L",
	"Foot.L",
	"Toe.L",
	"Ear.L",
	"UpperArm.R",
	"Forearm.R",
	"Hand.R",
	"Thigh.R",
	"Shin.R",
	"Foot.R",
	"Toe.R",
	"Ear.R",
	"Jaw",
	"Eye.L",
	"Eye.R",
	"Lid.L",
	"Lid.R"
]
const LOOPS := [
	"idle", "walk", "run", "turn_left", "turn_right", "sit_idle", "listen", "talk", "think", "drive"
]
const ONE_SHOTS := [
	"stop",
	"sit_down",
	"stand_up",
	"wave",
	"joy",
	"surprise",
	"disappointed",
	"interact",
	"enter_vehicle",
	"exit_vehicle",
	"greeting_wave",
	"celebrate",
	"agree_nod",
	"point_portal",
	"card_play"
]
## Clip pairs that play one after the other: end of the first == start of the second.
const SEAMS := [
	["sit_down", "sit_idle"],
	["sit_idle", "stand_up"],
	["stand_up", "idle"],
	["walk", "stop"],
	["stop", "idle"],
	["enter_vehicle", "drive"],
	["drive", "exit_vehicle"],
	["idle", "wave"],
	["wave", "idle"],
	["idle", "joy"],
	["joy", "idle"],
	["idle", "interact"],
	["interact", "idle"],
	["idle", "surprise"],
	["idle", "disappointed"],
	["disappointed", "idle"]
]
var checks := 0
var failures: Array[String] = []
var report: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[FigureAnimation] " + message)


func _typed(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _typed(child, type_name)
		if found != null:
			return found
	return null


func _sample(player: AnimationPlayer, skeleton: Skeleton3D, clip: String, time: float) -> void:
	player.play(clip, 0.0)
	player.seek(clamp(time, 0.0, player.get_animation(clip).length), true)
	skeleton.force_update_all_bone_transforms()


func _origins(skeleton: Skeleton3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for bone in range(skeleton.get_bone_count()):
		out.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin)
	return out


func _bone(skeleton: Skeleton3D, name: String) -> Vector3:
	return (
		skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin
	)


func _max_distance(a: Array[Vector3], b: Array[Vector3], skip: Array[int]) -> float:
	var worst := 0.0
	for index in range(a.size()):
		if index in skip:
			continue
		worst = maxf(worst, a[index].distance_to(b[index]))
	return worst


func _figure(species: String) -> void:
	var path := ROSTER.figure_model_path(species)
	_check(not path.is_empty(), "Roster resolves the standing figure: " + species)
	if path.is_empty():
		return
	_check(
		path != ROSTER.racing_model_path(species),
		"Standing figure is not the seated driver: " + species
	)
	var info := ROSTER.figure_info(species)
	_check(not info.is_empty(), "Manifest entry exists: " + species)
	var packed := load(path) as PackedScene
	_check(packed != null, "Imports as PackedScene: " + path)
	if packed == null:
		return
	var figure := packed.instantiate() as Node3D
	root.add_child(figure)
	var skeleton := _typed(figure, "Skeleton3D") as Skeleton3D
	var player := _typed(figure, "AnimationPlayer") as AnimationPlayer
	_check(skeleton != null and player != null, "Skin and AnimationPlayer: " + species)
	if skeleton == null or player == null:
		figure.free()
		return
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_check(skeleton.get_bone_count() == BONES.size(), "30-bone standing rig: " + species)
	for bone in BONES:
		_check(skeleton.find_bone(bone) >= 0, "Bone present: %s/%s" % [species, bone])
	var clips: Dictionary = info.get("clips", {})
	var lids: Array[int] = [skeleton.find_bone("Lid.L"), skeleton.find_bone("Lid.R")]
	# rest pose: feet on the ground, figure upright
	var rest := _origins(skeleton)
	var head_height: float = _bone(skeleton, "Head").y
	_check(
		head_height > 0.8 and head_height < 1.6,
		"Upright figure, head %.2f m: %s" % [head_height, species]
	)
	var lengths: Dictionary = {}
	for index in range(skeleton.get_bone_count()):
		var parent := skeleton.get_bone_parent(index)
		# The pelvis translates relative to the ground root on purpose.
		if parent > 0:
			lengths[index] = rest[index].distance_to(rest[parent])
	var worst_break := 0.0
	for clip in LOOPS + ONE_SHOTS:
		_check(player.has_animation(clip), "Clip %s/%s" % [species, clip])
		if not player.has_animation(clip):
			continue
		var animation := player.get_animation(clip)
		var expected: float = float((clips.get(clip, {}) as Dictionary).get("seconds", -1.0))
		_check(
			absf(animation.length - expected) < 0.04,
			"Length %s/%s %.3f vs %.3f" % [species, clip, animation.length, expected]
		)
		_check(
			animation.length >= 0.6 and animation.length <= 4.1,
			"Plausible length %s/%s" % [species, clip]
		)
		var looping: bool = clip in LOOPS
		_check(
			(animation.loop_mode == Animation.LOOP_LINEAR) == looping,
			"Loop flag %s/%s" % [species, clip]
		)
		_check(
			animation.get_track_count() >= BONES.size(), "Every bone keyed %s/%s" % [species, clip]
		)
		for step in range(13):
			_sample(player, skeleton, clip, animation.length * float(step) / 12.0)
			var now := _origins(skeleton)
			for index in lengths:
				if index in lids:
					continue
				var parent := skeleton.get_bone_parent(index)
				var stretch := absf(now[index].distance_to(now[parent]) - float(lengths[index]))
				worst_break = maxf(worst_break, stretch)
				if not now[index].is_finite():
					_check(false, "Finite pose %s/%s" % [species, clip])
		if looping:
			_sample(player, skeleton, clip, 0.0)
			var first := _origins(skeleton)
			_sample(player, skeleton, clip, animation.length)
			var gap := _max_distance(first, _origins(skeleton), lids)
			_check(gap < 0.004, "Seamless loop %s/%s gap %.4f m" % [species, clip, gap])
	_check(
		worst_break < 0.002,
		"No rig breaks (joint distances kept) %s: %.5f m" % [species, worst_break]
	)
	for pair in SEAMS:
		var a: String = pair[0]
		var b: String = pair[1]
		if not player.has_animation(a) or not player.has_animation(b):
			continue
		_sample(player, skeleton, a, player.get_animation(a).length)
		var end := _origins(skeleton)
		_sample(player, skeleton, b, 0.0)
		var gap := _max_distance(end, _origins(skeleton), lids)
		_check(gap < 0.03, "Natural transition %s -> %s (%s) gap %.3f m" % [a, b, species, gap])
	report[species] = {"worst_joint_drift_m": worst_break}
	for kind in ["walk", "run"]:
		report[species][kind] = _gait(species, kind, player, skeleton, clips.get(kind, {}))
	figure.free()


## Foot contact: a planted foot stays on the ground and slides backwards at the
## travelling speed, i.e. it stands still in the world while the node moves.
func _gait(
	species: String, clip: String, player: AnimationPlayer, skeleton: Skeleton3D, info: Dictionary
) -> Dictionary:
	var animation := player.get_animation(clip)
	var speed: float = float(info.get("speed_mps", 0.0))
	_check(speed > 0.2, "Manifest speed for %s/%s" % [species, clip])
	var steps := 90
	var heights: Dictionary = {"L": [], "R": []}
	var balls: Dictionary = {"L": [], "R": []}
	var forward: Dictionary = {"L": [], "R": []}
	for step in range(steps + 1):
		_sample(player, skeleton, clip, animation.length * float(step) / float(steps))
		for side in ["L", "R"]:
			var ankle := _bone(skeleton, "Foot." + side)
			var ball := _bone(skeleton, "Toe." + side)
			heights[side].append(ankle.y)
			balls[side].append(ball.y)
			forward[side].append(ball.z)
	var result: Dictionary = {}
	var both_airborne := 0
	var both_planted := 0
	for side in ["L", "R"]:
		var low: float = (heights[side] as Array).min()
		var high: float = (heights[side] as Array).max()
		var contact := 0
		var flat := 0
		var slide := 0.0
		var ball_low: float = (balls[side] as Array).min()
		var run: Array[float] = []
		var dt := animation.length / float(steps)
		for step in range(steps + 1):
			var h0: float = heights[side][step]
			if step < steps and h0 < low + 0.012:
				contact += 1
			# Foot flat on the ground: ankle and ball both at their lowest. In the
			# world (node moving forward at the travel speed) it must stand still.
			var planted: bool = h0 < low + 0.004 and float(balls[side][step]) < ball_low + 0.004
			if planted:
				run.append(float(forward[side][step]) - speed * dt * float(step))
				flat += 1
			if (not planted or step == steps) and run.size() > 1:
				slide = maxf(slide, run.max() - run.min())
			if not planted:
				run.clear()
		var samples := flat
		var slide_error := slide
		var duty := float(contact) / float(steps)
		result[side] = {
			"lift_m": high - low, "duty": duty, "flat_samples": flat, "world_slide_m": slide
		}
		_check(high - low > 0.05, "%s/%s foot %s lifts %.3f m" % [species, clip, side, high - low])
		_check(
			samples >= (6 if clip == "walk" else 3) and slide_error < 0.015,
			(
				"%s/%s foot %s planted (world slide %.4f m at %.2f m/s)"
				% [species, clip, side, slide_error, speed]
			)
		)
		if clip == "walk":
			_check(duty > 0.45 and duty < 0.75, "%s walk duty %s %.2f" % [species, side, duty])
		else:
			_check(duty > 0.2 and duty < 0.5, "%s run duty %s %.2f" % [species, side, duty])
	for step in range(steps):
		var l_low: bool = float(heights["L"][step]) < (heights["L"] as Array).min() + 0.012
		var r_low: bool = float(heights["R"][step]) < (heights["R"] as Array).min() + 0.012
		if not l_low and not r_low:
			both_airborne += 1
		if l_low and r_low:
			both_planted += 1
	if clip == "walk":
		_check(both_airborne == 0, "%s walk always keeps one foot on the ground" % species)
		_check(both_planted > 0, "%s walk has double support (weight transfer)" % species)
	else:
		_check(both_airborne > 0, "%s run has a flight phase" % species)
	result["flight_samples"] = both_airborne
	result["double_support_samples"] = both_planted
	return result


func _run() -> void:
	for species in SPECIES:
		_figure(species)
		await process_frame
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		if file != null:
			file.store_string(
				JSON.stringify(
					{
						"passed": failures.is_empty(),
						"checks": checks,
						"errors": failures,
						"figures": report,
						"godot": Engine.get_version_info().string
					},
					"  "
				)
			)
			file.close()
	print("[FigureAnimation] checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
