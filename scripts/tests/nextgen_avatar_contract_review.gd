extends SceneTree
## Independent integration gate for the producer's imported learning character.
## Transport packets below are explicit fixtures, never claims of audible TTS.
## Missing producer files fail closed instead of becoming a skipped PASS.

const MODEL := "res://assets/lumo_next/character/Lumo-Learning.glb"
const ORIGINAL_MODEL := "res://assets/characters/lumo_facial/Lumo-Facial-Mobile.glb"
const DIRECTOR := "res://scripts/lumo_next/avatar_director.gd"
const REGISTRY := "res://scripts/lumo_next/learning_target_registry.gd"
const ACTOR := "res://scripts/lumo_next/learning_lumo_actor.gd"
const ORIGINAL_CLIPS: Array[String] = [
	"idle",
	"greeting_wave",
	"celebrate",
	"point_portal",
	"agree_nod",
	"kart_seated",
	"kart_steer_left",
	"kart_steer_right",
	"kart_jump",
]
const LEARNING_CLIPS: Array[String] = [
	"idle_breathe",
	"greeting",
	"listening",
	"thinking",
	"answer",
	"explain",
	"point",
	"nod",
	"unsure",
	"encourage",
	"celebrate_step",
	"interrupt",
	"farewell",
	"focused_input",
]
const MOUTH: Array[String] = ["AA", "EE", "OH", "OU", "MBP", "FV", "L", "TH", "Neutral"]
var checks := 0
var failures: Array[String] = []
var stage: Node3D
var visual: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var director
var registry
var camera: Camera3D
var target: Node3D
var stops: Array[Dictionary] = []
var fixture_pcm := PackedByteArray()


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[NextgenAvatarReview] " + message)
	return condition


func _finish() -> void:
	print(
		(
			"[NextgenAvatarReview] %s checks=%d failures=%d"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()]
		)
	)
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	for path: String in [MODEL, DIRECTOR, REGISTRY, ACTOR]:
		_check(ResourceLoader.exists(path), "producer resource exists/imports: " + path)
	if not failures.is_empty():
		_finish()
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	stage = Node3D.new()
	root.add_child(stage)
	var packed := load(MODEL) as PackedScene
	if not _check(packed != null, "production GLB resolves through the actual Godot importer"):
		_finish()
		return
	visual = packed.instantiate() as Node3D
	stage.add_child(visual)
	for node in visual.find_children("*", "Skeleton3D", true, false):
		skeleton = node as Skeleton3D
	for node in visual.find_children("*", "AnimationPlayer", true, false):
		player = node as AnimationPlayer
	if not _check(
		is_instance_valid(skeleton) and is_instance_valid(player),
		"imported skeleton and animation player exist"
	):
		_finish()
		return
	_test_original_rig()
	for clip: String in ORIGINAL_CLIPS + LEARNING_CLIPS:
		_check(player.has_animation(clip), "actual imported animation exists: " + clip)
	for shape: String in (
		MOUTH + ["Smile", "Concern", "LookLeft", "LookRight", "LookUp", "LookDown"]
	):
		_check(_shape_exists(shape), "actual imported mesh morph exists: " + shape)
	registry = load(REGISTRY).new()
	stage.add_child(registry)
	director = load(DIRECTOR).new()
	stage.add_child(director)
	director.set_process(false)
	if not _check(
		director.bind_character(visual, registry), "director binds the imported production rig"
	):
		_finish()
		return
	director.stop_playback_requested.connect(
		func(turn: String, reason: String) -> void: stops.append({"turn": turn, "reason": reason})
	)
	_check(registry.begin_lesson("review/8plus5", 1), "lesson owner is established")
	target = Node3D.new()
	stage.add_child(target)
	target.position = _bone_position("Head") + Vector3(0.7, -0.3, 2.0)
	_check(registry.register_target("addend_b_00", target), "real lesson object is registered")
	var other := Node3D.new()
	stage.add_child(other)
	_check(
		not registry.register_target("addend_b_00", other),
		"duplicate ID cannot silently redirect a gesture"
	)
	_check(
		registry.world_target("unknown") == null, "missing target never becomes the world origin"
	)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.0
	stage.add_child(camera)
	camera.position = _bone_position("Head") + Vector3(0.0, 0.4, 8.0)
	camera.look_at(_bone_position("Head"))
	camera.current = true
	director.set_view(camera, Rect2(Vector2.ZERO, Vector2(root.size)))
	await process_frame
	_test_target_and_geometry()
	_test_playback_boundary()
	await _test_bound_audio_player()
	_test_interrupt_and_lifecycle()
	_test_revision_and_disappearing_target()
	await _test_outer_contract()
	stage.queue_free()
	await process_frame
	_finish()


func _event(turn: String, type: String, identifier: String = "") -> Dictionary:
	return {
		"protocol": 1,
		"turn_id": turn,
		"lesson_id": "review/8plus5",
		"revision": 1,
		"type": type,
		"target_id": identifier
	}


func _test_original_rig() -> void:
	var original := (load(ORIGINAL_MODEL) as PackedScene).instantiate()
	var original_skeleton: Skeleton3D
	for node in original.find_children("*", "Skeleton3D", true, false):
		original_skeleton = node as Skeleton3D
	if not _check(is_instance_valid(original_skeleton), "original rig is independently importable"):
		original.free()
		return
	_check(original_skeleton.get_bone_count() == 65, "reference contains the original 65-bone rig")
	for index in range(original_skeleton.get_bone_count()):
		var name_value := original_skeleton.get_bone_name(index)
		var retained := skeleton.find_bone(name_value)
		if not _check(retained >= 0, "original bone retained: " + name_value):
			continue
		var old_parent := original_skeleton.get_bone_parent(index)
		var new_parent := skeleton.get_bone_parent(retained)
		_check(
			(
				(old_parent == -1 and new_parent == -1)
				or (
					old_parent >= 0
					and new_parent >= 0
					and (
						original_skeleton.get_bone_name(old_parent)
						== skeleton.get_bone_name(new_parent)
					)
				)
			),
			"original hierarchy retained: " + name_value
		)
	original.free()


func _sample(
	turn: String,
	position: float,
	state_value: String = "playing",
	audible: bool = true,
	measured: bool = true
) -> Dictionary:
	return {
		"protocol": 1,
		"turn_id": turn,
		"lesson_id": "review/8plus5",
		"revision": 1,
		"audio_id": "review-wave",
		"position_ms": position,
		"state": state_value,
		"audible": audible,
		"envelope_available": measured,
		"envelope": 0.8
	}


func _advance(seconds: float) -> void:
	for frame in range(ceili(seconds * 60.0)):
		director.advance(1.0 / 60.0)


func _test_target_and_geometry() -> void:
	_check(director.begin_turn("point/0", "review/8plus5", 1), "fresh point turn accepted")
	_check(
		not director.handle_event(_event("point/0", "point", "unknown")),
		"point requires a registered target"
	)
	target.hide()
	_check(
		not director.handle_event(_event("point/0", "point", "addend_b_00")),
		"hidden target cannot be pointed at"
	)
	target.show()
	director.set_view(camera, Rect2(0, 0, 1, 1))
	_check(
		not director.handle_event(_event("point/0", "point", "addend_b_00")),
		"offscreen target is rejected"
	)
	director.set_view(camera, Rect2(Vector2.ZERO, Vector2(root.size)))
	_check(
		director.handle_event(_event("point/0", "point", "addend_b_00")),
		"visible exact target accepted"
	)
	_advance(0.75)
	_check(
		director.target_id == director.point_target_id and director.target_id == "addend_b_00",
		"gaze and paw refer to the same object"
	)
	var desired := (target.global_position - _bone_position("Head")).normalized()
	var head := skeleton.find_bone("Head")
	var forward := (
		(
			skeleton.global_basis
			* skeleton.get_bone_global_pose(head).basis
			* skeleton.get_bone_global_rest(head).basis.inverse()
			* Vector3.BACK
		)
		. normalized()
	)
	_check(forward.angle_to(desired) < 0.23, "actual head orientation follows the front target")
	var best_angle := PI
	for side: String in [".L", ".R"]:
		var wrist := _bone_position("Wrist" + side)
		var hand := _bone_position("Hand" + side)
		best_angle = minf(best_angle, (hand - wrist).angle_to(target.global_position - wrist))
	_check(
		best_angle < 0.13,
		"actual wrist-to-paw ray points at the object, independent of diagnostics"
	)
	for dimensions: Vector2i in [Vector2i(412, 915), Vector2i(900, 1100), Vector2i(1280, 720)]:
		root.size = dimensions
		director.set_view(camera, Rect2(Vector2.ZERO, Vector2(dimensions)))
		_check(
			registry.world_target("addend_b_00") == target.global_position,
			"layout change retains the same 3D object identity"
		)
		_check(
			(
				registry
				. viewport_visibility(
					"addend_b_00", camera, Rect2(Vector2.ZERO, Vector2(dimensions))
				)
				. visible
			),
			"target projects inside each active viewport"
		)


func _test_playback_boundary() -> void:
	_check(
		director.begin_turn("audio/0", "review/8plus5", 1), "new audio turn supersedes point turn"
	)
	_check(
		director.push_playback_sample(_sample("audio/0", 0, "preparing")),
		"preparing snapshot accepted"
	)
	_advance(0.1)
	_check(_mouth_closed(), "preparation does not move the mouth")
	director.push_playback_sample(_sample("audio/0", 20, "playing", false))
	_advance(0.1)
	_check(_mouth_closed(), "muted playback does not move the mouth")
	director.push_playback_sample(_sample("audio/0", 40, "playing", true, false))
	_advance(0.1)
	_check(_mouth_closed(), "missing envelope does not invent mouth motion")
	_check(
		director.push_playback_sample(_sample("audio/0", 60)), "measured audible snapshot accepted"
	)
	_advance(0.1)
	_check(_shape_weight("AA") > 0.2, "actual imported AA morph follows measured amplitude")
	for frame in range(30):
		director.push_playback_sample(_sample("audio/0", 60))
		director.advance(1.0 / 60.0)
	_check(_mouth_closed(), "repeated frozen player snapshots expire")
	director.push_playback_sample(_sample("audio/0", 100))
	_advance(0.05)
	var invalid := _sample("audio/0", 120)
	invalid.envelope = NAN
	_check(
		not director.push_playback_sample(invalid) and _mouth_closed(),
		"invalid PCM data closes geometry immediately"
	)
	_check(
		not director.push_playback_sample(_sample("old-turn", 500)),
		"old turn cannot restart speech"
	)
	var wrong_version := _sample("audio/0", 140)
	wrong_version.protocol = 2
	_check(not director.push_playback_sample(wrong_version), "unknown protocol rejected")
	_check(
		director.set_mouth_cues(
			"audio/0",
			"review-wave",
			[{"start_ms": 0.0, "end_ms": 100.0, "shape": "OH", "weight": 0.7}],
			"authored_fixture"
		),
		"explicit test cue is bound to an audio identity"
	)
	director.push_playback_sample(_sample("audio/0", 50))
	_advance(0.08)
	_check(_shape_weight("OH") > 0.5, "actual media position selects the imported OH shape")
	director.push_playback_sample(_sample("audio/0", 110))
	_check(_mouth_closed_after_advance(), "cue interval end is a closed interval, not a text timer")
	_check(
		not director.set_mouth_cues(
			"audio/0",
			"review-wave",
			[
				{"start_ms": 50, "end_ms": 100, "shape": "AA"},
				{"start_ms": 90, "end_ms": 140, "shape": "EE"}
			],
			"authored_fixture"
		),
		"overlapping cue intervals rejected"
	)
	director.push_playback_sample(_sample("audio/0", 150, "completed", false))
	_check(
		_mouth_closed() and not director.diagnostics().turn_open,
		"completion closes the current turn and mouth"
	)
	_check(
		not director.push_playback_sample(_sample("audio/0", 160)),
		"completed turn cannot resume through a late sample"
	)


func _test_bound_audio_player() -> void:
	# This generated tone checks the real Godot media clock/PCM path. A headless
	# Dummy mixer is not proof of a physical speaker or the Android TTS voice.
	var rate := 16000
	fixture_pcm.resize(rate * 2)
	for index in range(fixture_pcm.size()):
		fixture_pcm[index] = int(128.0 + 100.0 * sin(TAU * 440.0 * float(index) / rate))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_8_BITS
	wave.mix_rate = rate
	wave.stereo = false
	wave.data = fixture_pcm
	var output := AudioStreamPlayer.new()
	output.stream = wave
	var bus := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, "NextgenReviewFixture")
	AudioServer.set_bus_send(bus, "Master")
	output.bus = "NextgenReviewFixture"
	stage.add_child(output)
	_check(
		director.begin_turn("player/0", "review/8plus5", 1), "real player fixture owns a fresh turn"
	)
	output.play()
	_check(
		director.bind_audio_player(output, "player/0", "generated-pcm-fixture", _fixture_amplitude),
		"actual AudioStreamPlayer is bound to its turn and measured PCM"
	)
	await create_timer(0.12).timeout
	_advance(0.08)
	_check(output.playing, "the real Godot player has started the generated stream")
	_check(
		director.last_media_ms > 10.0 and director.last_media_ms < 1000.0,
		"mouth transport position comes from the running media player"
	)
	_check(
		_shape_weight("AA") > 0.15,
		"measured PCM from the actual player drives imported mouth geometry"
	)
	AudioServer.set_bus_mute(bus, true)
	director.advance(1.0 / 60.0)
	_check(_mouth_closed(), "muting the real output bus closes the mouth")
	AudioServer.set_bus_mute(bus, false)
	output.seek(0.5)
	await create_timer(0.06).timeout
	_advance(0.08)
	_check(
		director.last_media_ms >= 450.0 and director.last_media_ms < 1000.0,
		"seeking the stream updates the mouth timeline from actual media position"
	)
	output.stream_paused = true
	director.advance(1.0 / 60.0)
	_check(_mouth_closed(), "pausing the real player closes the mouth")
	var before_stop := stops.size()
	director.interrupt("real_player_stop")
	_check(
		not output.playing and _mouth_closed(),
		"interrupt stops the real bound player and mouth together"
	)
	director.interrupt("duplicate_stop")
	_check(
		stops.size() == before_stop + 1, "repeated interrupt does not duplicate the transport stop"
	)
	output.free()
	AudioServer.remove_bus(bus)
	fixture_pcm.clear()


func _fixture_amplitude(position_seconds: float) -> float:
	var begin := clampi(int(position_seconds * 16000), 0, fixture_pcm.size())
	var end := mini(begin + 320, fixture_pcm.size())
	if begin >= end:
		return 0.0
	var energy := 0.0
	for index in range(begin, end):
		var sample := (float(fixture_pcm[index]) - 128.0) / 128.0
		energy += sample * sample
	return sqrt(energy / float(end - begin))


func _test_interrupt_and_lifecycle() -> void:
	for cause: String in ["stop", "suspend", "input"]:
		var turn := cause + "/0"
		_check(director.begin_turn(turn, "review/8plus5", 1), "new lifecycle fixture turn accepted")
		director.handle_event(_event(turn, "point", "addend_b_00"))
		director.push_playback_sample(_sample(turn, 10))
		_advance(0.05)
		_check(not _mouth_closed(), "fixture has actually opened imported mouth geometry")
		var previous_stops := stops.size()
		match cause:
			"stop":
				director.interrupt("review_stop")
			"suspend":
				director.set_suspended(true)
			"input":
				director.set_focused_input(true)
		_check(_mouth_closed(), "stop/lifecycle/input closes actual mouth immediately")
		_check(
			director.target_id.is_empty() and director.point_target_id.is_empty(),
			"interruption discards gaze and pointing targets"
		)
		_check(
			not director.diagnostics().turn_open, "interruption invalidates the audio/gesture turn"
		)
		_check(
			stops.size() == previous_stops + 1 and stops[-1].turn == turn,
			"one transport stop belongs to the interrupted turn"
		)
		_check(
			not director.push_playback_sample(_sample(turn, 40)),
			"interrupted snapshot cannot reopen the mouth"
		)
		_check(
			not director.handle_event(_event(turn, "celebrate")),
			"late gesture cannot revive the interrupted turn"
		)
		if cause == "suspend":
			var position: float = player.current_animation_position
			_advance(0.2)
			_check(
				is_equal_approx(player.current_animation_position, position),
				"paused animation clock stays frozen"
			)
			director.set_suspended(false)
		elif cause == "input":
			director.set_focused_input(false)
		_advance(0.25)
		_check(
			director.state == "listening" and _mouth_closed(),
			"resume returns to listening without replaying the old gesture"
		)
		_check(
			not director.begin_turn(turn, "review/8plus5", 1),
			"retired turn identifiers cannot be reused"
		)


func _test_revision_and_disappearing_target() -> void:
	_check(
		director.begin_turn("remove/0", "review/8plus5", 1),
		"target removal fixture owns an open turn"
	)
	_check(
		director.handle_event(_event("remove/0", "point", "addend_b_00")),
		"target removal fixture has an active point"
	)
	director.push_playback_sample(_sample("remove/0", 10))
	_advance(0.05)
	_check(not _mouth_closed(), "target removal fixture has actual speech geometry")
	var unrelated := Node3D.new()
	stage.add_child(unrelated)
	registry.register_target("unrelated", unrelated)
	var before_removal := stops.size()
	registry.unregister_target("unrelated", unrelated)
	_check(
		not _mouth_closed() and director.diagnostics().turn_open and stops.size() == before_removal,
		"removing another object does not interrupt this object's explanation"
	)
	_check(registry.unregister_target("addend_b_00", target), "actual target unregisters")
	_check(
		_mouth_closed() and director.target_id.is_empty(),
		"removing an active object cancels its spoken gesture"
	)
	_check(
		(
			not director.diagnostics().turn_open
			and stops.size() == before_removal + 1
			and stops[-1].turn == "remove/0"
		),
		"only the removed target's turn receives one transport stop"
	)
	_check(
		not director.push_playback_sample(_sample("remove/0", 50)),
		"removed target's queued speech cannot restart"
	)
	registry.register_target("addend_b_00", target)
	director.begin_turn("revision/0", "review/8plus5", 1)
	director.handle_event(_event("revision/0", "point", "addend_b_00"))
	director.push_playback_sample(_sample("revision/0", 10))
	_advance(0.05)
	_check(
		registry.begin_lesson("review/banane", 2), "new lesson revision replaces the object scope"
	)
	_check(registry.target_ids().is_empty(), "old task objects are not carried into a new lesson")
	_check(
		_mouth_closed() and not director.diagnostics().turn_open,
		"new lesson cancels the old explanation"
	)
	_check(
		not director.push_playback_sample(_sample("revision/0", 60)),
		"old task audio cannot alter a new scene"
	)


func _test_outer_contract() -> void:
	var actor_script := load(ACTOR) as GDScript
	if not _check(
		actor_script != null and actor_script.can_instantiate(), "actual actor script compiles"
	):
		return
	var actor = actor_script.new()
	stage.add_child(actor)
	await process_frame
	if not _check(actor.is_usable(), "actual learning actor imports the producer GLB"):
		actor.queue_free()
		return
	actor.director.set_process(false)
	actor.begin_audio_turn("4711", "native-utterance:4711")
	var native_status: Dictionary = JSON.parse_string(
		(
			'{"id":4711,"state":"playing","positionMs":80,'
			+ '"audible":true,"envelopeAvailable":true,"envelope":0.8}'
		)
	)
	_check(
		actor.apply_playback_status(native_status),
		"native numeric utterance ID survives actual JSON parsing: " + str(native_status.id)
	)
	for invalid_id: Variant in [4710, 4711.5, "4711.5", null]:
		var invalid_status := native_status.duplicate(true)
		invalid_status.id = invalid_id
		_check(
			not actor.apply_playback_status(invalid_status),
			"old, nonintegral or missing native IDs reject"
		)
	var context: Dictionary = JSON.parse_string(
		(
			'{"protocolVersion":1,"sessionId":"review-session","taskId":"8plus5",'
			+ '"revision":1,"cancelEpoch":0,"stepId":"before-ten",'
			+ '"allowedActions":["explain","point","look","highlight","stop"]}'
		)
	)
	if not _check(
		actor.bind_interaction_context(context),
		"actual canonical JSON identity binds without legacy schema/version/contextRevision"
	):
		# A separately labelled diagnostic reproduces ordering on the old adapter.
		# Its acceptance must never count as canonical compatibility.
		_test_legacy_turn_order(actor)
		actor.queue_free()
		await process_frame
		return
	var event: Dictionary = JSON.parse_string(
		(
			'{"protocolVersion":1,"sessionId":"review-session","taskId":"8plus5",'
			+ '"revision":1,"cancelEpoch":0,"stepId":"before-ten",'
			+ '"turnId":2,"action":"explain"}'
		)
	)
	_check(
		actor.apply_interaction_event(event),
		"actual canonical JSON action reaches the imported actor"
	)
	var active: String = actor.director.active_turn
	var state_before: String = actor.director.state
	var late := event.duplicate(true)
	late.turnId = 1
	_check(
		not actor.apply_interaction_event(late),
		"previously unseen Turn 1 cannot supersede active Turn 2 in the same task"
	)
	_check(
		actor.director.active_turn == active and actor.director.state == state_before,
		"rejected old turn leaves the current presentation untouched"
	)
	for key: String in [
		"sessionId", "taskId", "revision", "cancelEpoch", "stepId", "protocolVersion"
	]:
		var stale := event.duplicate(true)
		stale[key] = "other" if key in ["sessionId", "taskId", "stepId"] else int(stale[key]) + 1
		_check(
			not actor.apply_interaction_event(stale),
			"canonical identity/version mismatch rejects: " + key
		)
	var missing_step := event.duplicate(true)
	missing_step.erase("stepId")
	_check(
		not actor.apply_interaction_event(missing_step),
		"missing step cannot match an explicitly bound step"
	)
	for invalid_turn: Variant in [0, -1, 2.5, "3", null, true]:
		var invalid := event.duplicate(true)
		invalid.turnId = invalid_turn
		_check(
			not actor.apply_interaction_event(invalid),
			"outer turn ID must be a positive exact integer"
		)
	_check(
		actor.registry.register_target("addend_b_00", target),
		"canonical target refers to a real scoped object"
	)
	var pointing := event.duplicate(true)
	pointing.action = "point"
	pointing.objectId = "addend_b_00"
	_check(
		actor.apply_interaction_event(pointing),
		"same-turn canonical objectId selects the actual registered target"
	)
	_check(
		actor.director.point_target_id == "addend_b_00",
		"canonical point action does not invent coordinates"
	)
	var missing_object := pointing.duplicate(true)
	missing_object.objectId = "unknown"
	_check(
		not actor.apply_interaction_event(missing_object),
		"canonical point to absent object rejects"
	)
	var forbidden := event.duplicate(true)
	forbidden.action = "awardStars"
	_check(
		not actor.apply_interaction_event(forbidden),
		"unsupported action cannot gain presentation or reward authority"
	)
	var stop := event.duplicate(true)
	stop.action = "stop"
	_check(actor.apply_interaction_event(stop), "canonical scoped Stop is accepted")
	_check(
		not actor.apply_interaction_event(event), "cancel epoch invalidates queued canonical events"
	)
	_check(actor.director.point_target_id.is_empty(), "outer Stop leaves no pending point")
	var no_step := context.duplicate(true)
	no_step.sessionId = "review-no-step"
	no_step.erase("stepId")
	_check(
		actor.bind_interaction_context(no_step),
		"optional step may be absent on both sides of the new identity"
	)
	var no_step_event := no_step.duplicate(true)
	no_step_event.merge({"turnId": 2, "action": "explain"})
	_check(
		actor.apply_interaction_event(no_step_event),
		"turn numbers are scoped to the new owner, not retired globally"
	)
	no_step_event.stepId = "before-ten"
	_check(
		not actor.apply_interaction_event(no_step_event),
		"explicit step cannot replace an absent bound step"
	)
	actor.queue_free()
	await process_frame


func _test_legacy_turn_order(actor: Node3D) -> void:
	var legacy: Dictionary = JSON.parse_string(
		(
			'{"schema":"lumo.learning.interaction","version":1,'
			+ '"sessionId":"legacy-order-diagnostic","taskId":"same-task",'
			+ '"revision":1,"contextRevision":1,"cancelEpoch":0,"stepId":"start"}'
		)
	)
	if not actor.bind_interaction_context(legacy):
		print(
			"[NextgenAvatarReview] Legacy-only ordering diagnostic unavailable; canonical gate failed"
		)
		return
	var newer := legacy.duplicate(true)
	newer.merge({"turnId": 2, "type": "explain"})
	_check(
		actor.apply_interaction_event(newer), "legacy-only ordering diagnostic has an active Turn 2"
	)
	var late := newer.duplicate(true)
	late.turnId = 1
	_check(
		not actor.apply_interaction_event(late),
		"legacy-only diagnostic: unseen late Turn 1 must not replace Turn 2"
	)
	var wrong_step := newer.duplicate(true)
	wrong_step.stepId = "different-step"
	wrong_step.turnId = 3
	_check(
		not actor.apply_interaction_event(wrong_step),
		"legacy-only diagnostic: a different step cannot take over the active owner"
	)


func _bone_position(name: String) -> Vector3:
	var index := skeleton.find_bone(name)
	return skeleton.to_global(skeleton.get_bone_global_pose(index).origin)


func _shape_exists(name: String) -> bool:
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for index in range(mesh.mesh.get_blend_shape_count()):
			if str(mesh.mesh.get_blend_shape_name(index)) == name:
				return true
	return false


func _shape_weight(name: String) -> float:
	var result := 0.0
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for index in range(mesh.mesh.get_blend_shape_count()):
			if str(mesh.mesh.get_blend_shape_name(index)) == name:
				result = maxf(result, absf(mesh.get_blend_shape_value(index)))
	return result


func _mouth_closed() -> bool:
	for name: String in MOUTH + ["JawArticulation"]:
		if _shape_weight(name) > 0.0001:
			return false
	return true


func _mouth_closed_after_advance() -> bool:
	_advance(0.02)
	return _mouth_closed()
