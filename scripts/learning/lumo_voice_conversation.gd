extends RefCounted
class_name LumoLearningVoiceConversation

## Chat 4, Android Godot adapter. This class does not grade answers or store
## recordings. The Android LumoHost plugin owns local ASR and the licensed
## player. Chat 3's scene director owns mesh IDs, gaze, gestures and visuals.
##
## Setup from an active learning_world.gd:
## var dialogue := LumoLearningVoiceConversation.new()
## dialogue.open(Engine.get_singleton("LumoHost"), SceneRouter.launch_options)
## dialogue.reply_ready.connect(_show_checked_dialogue)
## dialogue.focus_requested.connect(_focus_checked_object)
## dialogue.audio_frame.connect(_use_native_mouth_envelope)
## In _process(delta): dialogue.poll(delta)
## On mic tap: dialogue.start()
## On stop tap: dialogue.stop()
##
## This is half-duplex: the mic closes while the speaker is audible. Spoken
## "Stopp" can be detected during listening, not reliably while TTS speaks.
## Touch stop must always be visible in the host learning scene.

signal state_changed(state: String)
signal transcript_updated(text: String, is_final: bool)
signal reply_ready(utterance_id: String, text: String)
signal focus_requested(object_id: String)
signal audio_frame(utterance_id: String, position_ms: int, amplitude: float, audible: bool)
signal cancelled()
signal unavailable(reason: String)

const CONTRACT_VERSION := 1
const POLL_INTERVAL := 0.05
const MAX_MESSAGE_LENGTH := 1200
const ALLOWED_ACTIONS := ["explain", "repeat", "slower", "hint", "stop"]

var _host: Object
var _scope: Dictionary = {}
var _object_ids: Array[String] = []
var _session := ""
var _task := ""
var _turn := 0
var _utterance := 0
var _last_state_key := ""
var _last_audio_key := ""
var _active_utterance := ""
var _expected_audio_id := 0
var _phase := "idle"
var _poll_clock := 0.0
var _continuous := false
var _enabled := false
var _can_speak := false
var _audio_pending := false
var _disposed := false


func open(host: Object, launch_options: Dictionary) -> bool:
	if _disposed or host == null:
		return false
	for name in [
		"updateLearningContext", "requestLearningConversation",
		"startLearningListening", "getLearningConversationStatus",
		"stopLearningConversation", "speakLearning", "getLearningSpeechStatus",
		"stopLearningSpeech"
	]:
		if not host.has_method(name):
			_set_unavailable("Der Android-Lernsprachkanal ist hier nicht angeschlossen.")
			return false
	var raw_learning: Variant = launch_options.get("learning")
	if not raw_learning is Dictionary:
		_set_unavailable("Keine gültige Lernaufgabe für das Gespräch.")
		return false
	var learning: Dictionary = raw_learning
	var raw_scope: Variant = learning.get("scope")
	if not raw_scope is Dictionary:
		_set_unavailable("Die geprüfte Aufgabenkennung fehlt.")
		return false
	var candidate: Dictionary = raw_scope
	_session = str(launch_options.get("sessionId", ""))
	_task = str(candidate.get("taskId", ""))
	if _session.is_empty() or _task.is_empty() or int(candidate.get("protocolVersion", 0)) != CONTRACT_VERSION:
		_set_unavailable("Die Aufgabenkennung ist nicht gültig.")
		return false
	_scope = candidate.duplicate(true)
	_scope["sessionId"] = _session
	_object_ids.clear()
	for element in learning.get("objectIds", []):
		var id := str(element)
		if id.length() > 0 and id.length() <= 80 and not _object_ids.has(id):
			_object_ids.append(id)
	_can_speak = launch_options.get("learningVoiceEnabled", false) == true \
		and launch_options.get("localVoiceLicenseAccepted", false) == true
	_host = host
	_enabled = bool(_host.updateLearningContext(JSON.stringify(_scope)))
	if not _enabled:
		_set_unavailable("Android hat die Aufgabenkennung abgelehnt. Die normale Touch-Aufgabe bleibt nutzbar.")
		return false
	_set_phase("ready")
	return true


func start() -> bool:
	if not _enabled or _disposed:
		return false
	_continuous = true
	_audio_pending = false
	_active_utterance = ""
	_host.stopLearningSpeech()
	_turn += 1
	var packet := _scope.duplicate(true)
	packet["turnId"] = _turn
	var accepted := bool(_host.startLearningListening(JSON.stringify(packet)))
	if not accepted:
		_continuous = false
		_set_unavailable("Mikrofon oder lokale Spracherkennung nicht verfügbar. Tippen bleibt möglich.")
		return false
	_set_phase("listening")
	return true


func ask(text: String, action: String = "explain") -> bool:
	if not _enabled or _disposed or action not in ALLOWED_ACTIONS:
		return false
	var question := text.strip_edges()
	if question.length() > MAX_MESSAGE_LENGTH:
		_set_unavailable("Die Frage ist zu lang. Bitte in kürzeren Sätzen fragen.")
		return false
	if question.is_empty() and action == "explain":
		return false
	_host.stopLearningSpeech()
	_audio_pending = false
	_active_utterance = ""
	_turn += 1
	var packet := _scope.duplicate(true)
	packet["turnId"] = _turn
	packet["action"] = action
	packet["text"] = question
	var accepted := bool(_host.requestLearningConversation(JSON.stringify(packet)))
	if accepted:
		_set_phase("thinking")
	else:
		_set_unavailable("Diese Hilfe wurde für die aktuelle Aufgabe nicht freigegeben.")
	return accepted


func stop() -> void:
	if _disposed:
		return
	_continuous = false
	_audio_pending = false
	_active_utterance = ""
	_expected_audio_id = 0
	_last_audio_key = ""
	_last_state_key = ""
	if _host != null:
		_host.stopLearningConversation()
		_host.stopLearningSpeech()
	audio_frame.emit("", 0, 0.0, false)
	focus_requested.emit("")
	_set_phase("interrupted")
	cancelled.emit()


## Task switches are never guessed. The host validates the next revision; a
## different taskId cannot be adopted silently within one Android activity.
func update_context(next_scope: Dictionary, explanation: String = "",
		next_object_ids: Array[String] = []) -> bool:
	if _disposed or not _enabled:
		return false
	if str(next_scope.get("sessionId", _session)) != _session \
		or str(next_scope.get("taskId", "")) != _task \
		or int(next_scope.get("protocolVersion", 0)) != CONTRACT_VERSION:
		stop()
		_set_unavailable("Die Aufgabe wurde gewechselt. Bitte öffne die neue Lernszene.")
		return false
	stop()
	var packet := next_scope.duplicate(true)
	packet["sessionId"] = _session
	packet["explanation"] = explanation.substr(0, MAX_MESSAGE_LENGTH)
	packet["objectIds"] = next_object_ids
	if not bool(_host.updateLearningContext(JSON.stringify(packet))):
		_set_unavailable("Die neue Aufgabenversion wurde nicht angenommen.")
		return false
	_scope = next_scope.duplicate(true)
	_scope["sessionId"] = _session
	_object_ids = next_object_ids.duplicate()
	_set_phase("ready")
	return true


## Call from the actual scene frame loop; no fake text or fabricated audio
## timestamps. No network, persisted transcript or timer-based visemes.
func poll(delta: float) -> void:
	if _disposed or not _enabled:
		return
	_poll_clock += maxf(0.0, delta)
	if _poll_clock < POLL_INTERVAL:
		return
	_poll_clock = 0.0
	_poll_recognizer()
	_poll_audio()


func _poll_recognizer() -> void:
	var raw: Variant = JSON.parse_string(str(_host.getLearningConversationStatus()))
	if not raw is Dictionary:
		return
	var result: Dictionary = raw
	if not _same_scope(result):
		return
	var state := str(result.get("state", ""))
	var turn := int(result.get("turnId", 0))
	if turn != _turn:
		return
	var recognized := str(result.get("transcript", ""))
	var reply := str(result.get("reply", ""))
	var key := str(turn) + ":" + state + ":" + recognized + ":" + reply
	if key == _last_state_key:
		return
	_last_state_key = key
	match state:
		"listening", "recognizing":
			_set_phase("listening")
			if not recognized.is_empty():
				transcript_updated.emit(recognized, false)
				if _is_stop(recognized):
					stop()
		"transcribed":
			if _is_stop(recognized):
				stop()
				return
			transcript_updated.emit(recognized, true)
			# A question is ungraded, so it can be answered without requiring
			# another tap. This never submits a child's candidate answer.
			if not ask(recognized, "explain"):
				_continuous = false
		"thinking":
			_set_phase("thinking")
		"ready":
			_deliver_reply(result)
		"cancelled":
			stop()
		"permission", "error":
			_continuous = false
			_set_unavailable(reply if not reply.is_empty() else "Spracherkennung nicht verfügbar.")
		"paused":
			_continuous = false
			_set_phase("paused")


func _deliver_reply(result: Dictionary) -> void:
	var text := str(result.get("reply", ""))
	if text.strip_edges().is_empty() or text.length() > MAX_MESSAGE_LENGTH:
		_set_phase("waiting")
		if _continuous:
			start()
		return
	var target := str(result.get("objectId", ""))
	if not _object_ids.has(target):
		target = ""
	focus_requested.emit(target)
	_utterance += 1
	_active_utterance = "native.lesson.%d" % _utterance
	reply_ready.emit(_active_utterance, text)
	_set_phase("speaking" if _can_speak else "waiting")
	if not _can_speak:
		if _continuous:
			start()
		return
	_expected_audio_id = _utterance
	var packet := {
		"id": _expected_audio_id,
		"text": text,
		"style": "explain",
		"sessionId": _session,
		"taskId": _task,
		"turnId": str(_turn),
		"utteranceId": _active_utterance,
		"contextRevision": int(_scope.get("revision", 0)),
		"rate": float(result.get("rate", 1.0))
	}
	_audio_pending = bool(_host.speakLearning(JSON.stringify(packet)))
	if not _audio_pending:
		_set_unavailable("Diese Erklärung kann gerade nicht vorgelesen werden. Der Text bleibt sichtbar.")
		if _continuous:
			start()


func _poll_audio() -> void:
	if not _audio_pending or _active_utterance.is_empty():
		return
	var raw: Variant = JSON.parse_string(str(_host.getLearningSpeechStatus()))
	if not raw is Dictionary:
		return
	var value: Dictionary = raw
	if int(value.get("id", 0)) != _expected_audio_id:
		return
	var status := str(value.get("state", ""))
	var audible: bool = value.get("audible", false) == true and status == "playing"
	var envelope := clampf(float(value.get("envelope", 0.0)), 0.0, 1.0) if audible else 0.0
	var position := maxi(0, int(value.get("positionMs", 0)))
	var key := str(_expected_audio_id) + ":" + status + ":" + str(position)
	if key != _last_audio_key:
		_last_audio_key = key
		audio_frame.emit(_active_utterance, position, envelope, audible)
	if status == "completed":
		_audio_pending = false
		audio_frame.emit(_active_utterance, position, 0.0, false)
		focus_requested.emit("")
		_set_phase("waiting")
		if _continuous:
			start()
	elif status in ["unavailable", "interrupted", "error", "stopped"]:
		_audio_pending = false
		audio_frame.emit(_active_utterance, position, 0.0, false)
		focus_requested.emit("")
		_set_phase("waiting")
		if _continuous:
			start()


func _same_scope(value: Dictionary) -> bool:
	var scope: Variant = value.get("scope", {})
	if not scope is Dictionary:
		return false
	var received: Dictionary = scope
	return str(received.get("sessionId", "")) == _session \
		and str(received.get("taskId", "")) == _task \
		and int(received.get("revision", -1)) == int(_scope.get("revision", -2)) \
		and int(received.get("cancelEpoch", -1)) == int(_scope.get("cancelEpoch", -2))


func _is_stop(text: String) -> bool:
	var words := text.to_lower().strip_edges().trim_suffix(".")
	return words in ["stopp", "stop", "halt", "hör auf", "hoer auf"]


func _set_phase(value: String) -> void:
	if _phase == value:
		return
	_phase = value
	state_changed.emit(value)


func _set_unavailable(reason: String) -> void:
	_set_phase("error")
	unavailable.emit(reason)


func dispose() -> void:
	if _disposed:
		return
	stop()
	_disposed = true
	_host = null
	_scope.clear()
	_object_ids.clear()
