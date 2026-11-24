extends SceneTree
# Java API names are the actual @UsedByGodot contract.
# gdlint: disable=function-name
## The Android host (Godot 4.6.3 JNISingleton) keeps @UsedByGodot methods in its
## own JNI map. Object.has_method is always false for them, so a game that asks
## has_method never talks to its Android host (the Quiz studio waited forever on
## "Die Spielverbindung wird geprüft …"). Host calls must go through
## HostBridge.supports_method, which also asks has_java_method.

const Bridge = preload("res://scripts/systems/host_bridge.gd")
const TABLE_METHODS: Array[StringName] = [
	&"getLaunchOptions",
	&"getTableState",
	&"submitTableAction",
	&"returnToApp",
]
## Every Java method a Godot game may probe before calling its Android host.
const JAVA_METHODS: Array[String] = [
	"getLaunchOptions",
	"getTableState",
	"submitTableAction",
	"returnToApp",
	"reward",
	"getCardsState",
	"submitCardsAction",
	"getConnectFourState",
	"submitConnectFourAction",
	"speakLearning",
	"getLearningSpeechStatus",
	"stopLearningSpeech",
	"updateLearningContext",
	"requestLearningConversation",
	"startLearningListening",
	"getLearningConversationStatus",
	"stopLearningConversation",
]
const SOURCE_ROOTS: Array[String] = ["res://scripts", "res://scenes", "res://assets"]


class AndroidTableHostShape:
	extends RefCounted
	# No GDScript declarations: like the real JNISingleton, has_method is false.
	var exported: Array[StringName] = []

	func has_java_method(method: StringName) -> bool:
		return method in exported


var checks := 0
var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _initialize() -> void:
	var android := AndroidTableHostShape.new()
	android.exported.assign(TABLE_METHODS)
	for method in TABLE_METHODS:
		check(not android.has_method(method), "JNI method absent from Object reflection: " + method)
		check(Bridge.supports_method(android, method), "registered JNI table method found: " + method)
	check(not Bridge.supports_method(android, &"getCardsState"), "unregistered Java API rejected")
	var offenders: Array[String] = []
	for root in SOURCE_ROOTS:
		_scan(root, offenders)
	check(offenders.is_empty(), "host Java calls probed via has_method: " + ", ".join(offenders))
	print(
		JSON.stringify(
			{
				"test": "table_android_host_capability",
				"checks": checks,
				"failures": failures,
				"status": "PASS" if failures.is_empty() else "FAIL",
			}
		)
	)
	quit(0 if failures.is_empty() else 1)


func _scan(folder: String, offenders: Array[String]) -> void:
	if folder.begins_with("res://scripts/tests"):
		return
	for sub in DirAccess.get_directories_at(folder):
		_scan(folder.path_join(sub), offenders)
	for file in DirAccess.get_files_at(folder):
		if not file.ends_with(".gd"):
			continue
		var path := folder.path_join(file)
		var text := FileAccess.get_file_as_string(path)
		for method in JAVA_METHODS:
			if text.contains('has_method("%s")' % method) or text.contains('has_method(&"%s")' % method):
				offenders.append("%s:%s" % [path, method])
