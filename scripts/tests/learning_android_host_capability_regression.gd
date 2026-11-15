extends SceneTree
# Java API names are the actual @UsedByGodot contract.
# gdlint: disable=function-name

const Bridge = preload("res://scripts/systems/host_bridge.gd")
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

	func stopLearningSpeech() -> void:
		stopped = true


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
	print(
		(
			JSON
			. stringify(
				{
					"test": "learning_android_host_capability",
					"checks": checks,
					"failures": failures,
					"status": "PASS" if failures.is_empty() else "FAIL",
					"scope": "4.6.3 capability dispatch; no Android audio or device PASS claim",
				}
			)
		)
	)
	quit(0 if failures.is_empty() else 1)
