extends RefCounted
## Lumos Stimme in der Dorf-Einführung – unabhängig vom Text.
## Jeder Schritt hat einen eigenen Sprechsatz („say“); die Blase kann den Text
## zeigen oder ausblenden, die Stimme kann an oder aus sein. Gesprochen wird
## nur, wenn die Eltern die Sprachausgabe freigegeben haben (dieselben
## Startoptionen wie im Lernen) und die App einen Sprecher anbietet. Ohne
## Freigabe bleibt alles stumm; die Einführung funktioniert dann über Text,
## Zeiger und Lumos Gesten.
const TASK := "village-tutorial"

var enabled := false
var host: Object
var session := "village"
var next_id := 0
## Was zuletzt gesprochen werden sollte (auch ohne Sprecher, für Tests/Protokoll).
var requested: Array[String] = []


static func from_options(options: Dictionary):
	var voice = load("res://scripts/creative/build_village_voice.gd").new()
	voice.enabled = (
		options.get("learningVoiceEnabled", false) == true
		and options.get("localVoiceLicenseAccepted", false) == true
	)
	var supplied := str(options.get("sessionId", ""))
	if not supplied.is_empty() and supplied.length() <= 128:
		voice.session = supplied
	if Engine.has_singleton("LumoHost"):
		voice.host = Engine.get_singleton("LumoHost")
	return voice


func available() -> bool:
	return enabled and is_instance_valid(host) and HostBridge.supports_method(host, "speakLearning")


func say(text: String, step_id: String) -> bool:
	if text.is_empty():
		return false
	requested.append(text)
	if requested.size() > 32:
		requested = requested.slice(-32)
	if not available():
		return false
	stop()
	next_id += 1
	var request := {
		"protocolVersion": 1, "sessionId": session, "taskId": TASK, "revision": 0, "cancelEpoch": next_id,
		"stepId": step_id, "utteranceId": "%s-%d" % [step_id, next_id], "id": next_id, "text": text,
		"rate": 1.0, "style": "explain",
	}
	return HostBridge.durable_ack(host.call("speakLearning", JSON.stringify(request)))


func stop() -> void:
	if is_instance_valid(host) and HostBridge.supports_method(host, "stopLearningSpeech"):
		host.call("stopLearningSpeech")
