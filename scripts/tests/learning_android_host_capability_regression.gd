extends SceneTree
# Java API names are the actual @UsedByGodot contract.
# gdlint: disable=function-name

const Bridge = preload("res://scripts/systems/host_bridge.gd")
const WORLD := "res://scenes/learning/learning_world.tscn"
const NEXT_WORLD := "res://scripts/lumo_next/learning_world_next.gd"
const JAVA_METHODS: Array[StringName] = [
	&"speakLearning",
	&"getLearningSpeechStatus",
	&"stopLearningSpeech",
	&"updateLearningContext",
	&"requestLearningConversation",
	&"startLearningListening",
	&"getLearningConversationStatus",
	&"stopLearningConversation",
]


class AndroidHostShape:
	extends RefCounted
	# These advertised JNI methods deliberately have no GDScript declaration:
	# Object.has_method returns false, as for the real 4.6.3 JNISingleton map.
	var exported: Array[StringName] = []
	var queries: Array[StringName] = []
	var answer: Variant = true

	func has_java_method(method: StringName) -> Variant:
		queries.append(method)
		return answer if method in exported else false


class ScriptHost:
	extends RefCounted
	var stopped := false
	var speech_stops := 0
	var conversation_stops := 0

	func stopLearningSpeech() -> void:
		stopped = true
		speech_stops += 1

	func stopLearningConversation() -> void:
		conversation_stops += 1


class TargetRegistry:
	extends RefCounted

	func clear_targets() -> void:
		pass


class PresentationOwner:
	extends Node3D
	var registry := TargetRegistry.new()
	var context: Dictionary = {}

	func is_usable() -> bool:
		return true

	func bind_interaction_context(value: Dictionary) -> bool:
		context = value.duplicate(true)
		return true

	func interaction_context_matches(value: Dictionary) -> bool:
		return context == value

	func stop_audio_turn(_reason: String) -> void:
		pass

	func set_teacher_speaking(_active: bool) -> void:
		pass

	func apply_speech_sample(_position: float, _envelope: float, _active: bool) -> bool:
		return true


var checks := 0
var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _initialize() -> void:
	var android := AndroidHostShape.new()
	android.exported.assign(JAVA_METHODS)
	for method in JAVA_METHODS:
		check(not android.has_method(method), "JNI method absent from Object reflection: " + method)
		check(Bridge.supports_method(android, method), "registered JNI capability found: " + method)
	check(
		android.queries == JAVA_METHODS, "real Java capability reader called for every JNI method"
	)
	check(
		not Bridge.supports_method(android, &"unknownLegacyApi"), "unregistered Java API rejected"
	)
	check(not Bridge.supports_method(android, &""), "empty API rejected")
	check(android.queries.size() == JAVA_METHODS.size() + 1, "empty API never queried")
	for malformed: Variant in [null, 1, 0, "true", {}, []]:
		android.answer = malformed
		check(
			not Bridge.supports_method(android, &"speakLearning"),
			"non-boolean Java report rejected"
		)
	android.answer = false
	check(
		not Bridge.supports_method(android, &"speakLearning"),
		"explicitly absent Java method rejected"
	)
	var legacy := RefCounted.new()
	check(
		not Bridge.supports_method(legacy, &"speakLearning"),
		"legacy object has no guessed Java API"
	)
	check(not Bridge.supports_method(null, &"speakLearning"), "missing host rejected")
	var script := ScriptHost.new()
	check(
		Bridge.supports_method(script, &"stopLearningSpeech"), "normal script reflection preserved"
	)
	if Bridge.supports_method(script, &"stopLearningSpeech"):
		script.call("stopLearningSpeech")
	check(script.stopped, "existing reflected stop remains callable")
	check(
		not Bridge.supports_method(script, &"startLearningListening"),
		"partial script host rejected"
	)
	_check_routed_owner()
	print(
		(
			JSON
			. stringify(
				{
					"test": "learning_android_host_capability",
					"checks": checks,
					"failures": failures,
					"status": "PASS" if failures.is_empty() else "FAIL",
					"scope":
					(
						"4.6.3 capability dispatch and actual routed Stop owners; "
						+ "no Android audio or device PASS claim"
					),
				}
			)
		)
	)
	quit(0 if failures.is_empty() else 1)


func _check_routed_owner() -> void:
	# Instantiate the registered production subclass, but do not attach it to
	# the tree: assets, rendering and Android playback are outside this fixture.
	var packed := load(WORLD) as PackedScene
	check(packed != null, "the production learning route loads")
	if packed == null:
		return
	var game = packed.instantiate()
	check(game.get_script().resource_path == NEXT_WORLD, "registered Next owner is exercised")
	game.content = Node3D.new()
	game.add_child(game.content)
	game.fox = PresentationOwner.new()
	game.add_child(game.fox)
	var android := AndroidHostShape.new()
	android.exported.assign(JAVA_METHODS)
	# A partially available JNI host must be queried, without calling a method
	# it has explicitly declined. This catches direct Object.has_method guards
	# in the actual scene functions without inventing a callable Java runtime.
	android.answer = false
	game._speech_host = android
	game._director_stop_requested("old-audio", "segment_replaced")
	check(
		android.queries == [&"stopLearningSpeech"],
		"routed segment Stop asks the Java capability reader"
	)
	check(not game._native_stop_guard, "segment Stop releases the reentrancy guard")
	var context := {
		"protocolVersion": 1,
		"sessionId": "capability-route",
		"taskId": "banane",
		"revision": 1,
		"cancelEpoch": 0,
		"stepId": "word",
		"allowedActions": ["explain", "repeat", "stop"],
	}
	android.queries.clear()
	check(game.bind_interaction_context(context), "routed context accepts the valid owner")
	check(
		&"stopLearningConversation" in android.queries,
		"routed owner change asks the Java conversation Stop capability"
	)
	var script := ScriptHost.new()
	game._speech_host = script
	game._director_stop_requested("old-audio", "segment_replaced")
	check(script.speech_stops == 1, "routed segment replacement invokes an existing speech Stop")
	context.revision = 2
	context.cancelEpoch = 1
	check(game.bind_interaction_context(context), "next valid owner remains bindable")
	check(script.speech_stops == 2, "owner replacement stops its preceding speech transport")
	check(script.conversation_stops == 1, "owner replacement invokes existing conversation Stop")
	game._native_stop_guard = true
	game._director_stop_requested("nested-stop", "segment_replaced")
	check(script.speech_stops == 2, "nested Stop does not re-enter the transport")
	game._native_stop_guard = false
	game.free()
