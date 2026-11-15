extends CanvasLayer
## Parent-authorized, on-device lesson dialogue UI. The verified native Android
## host owns recognition, reviewed replies and session/turn freshness.
## No independent grading, network requests, raw microphone storage or reward.
signal reply_ready(text: String, object_id: String, action: String)
signal dialog_stopped

var _host: Object
var _scope: Dictionary = {}
var _kind := ""
var _object_ids: Array = []
var _enabled := false
var _microphone_allowed := false
var _turn_id := 0
var _last_delivered_turn := -1
var _last_transcript_turn := -1
var _poll_clock := 0.0
var _root: Control
var _frame: PanelContainer
var _center: CenterContainer
var _hint: Label
var _heard: Label
var _reply: Label
var _question: LineEdit
var _microphone: Button


func configure(options: Dictionary, host: Object) -> void:
	_host = host
	var descriptor: Variant = options.get("learning", {})
	if not descriptor is Dictionary or not is_instance_valid(host):
		return
	_kind = str(descriptor.get("kind", ""))
	var raw_scope: Variant = descriptor.get("scope", {})
	if not raw_scope is Dictionary or str(raw_scope.get("taskId", "")).is_empty():
		return
	_scope = raw_scope.duplicate(true)
	if (
		int(_scope.get("protocolVersion", -1)) != 1
		or str(_scope.get("sessionId", "")) != str(options.get("sessionId", ""))
		or not host.has_method("requestLearningConversation")
		or not host.has_method("getLearningConversationStatus")
		or not host.has_method("updateLearningContext")
		or not host.has_method("stopLearningConversation")
	):
		return
	var raw_ids: Variant = descriptor.get("objectIds", [])
	if raw_ids is Array:
		for element in raw_ids:
			if element is String and element.length() <= 80:
				_object_ids.append(element)
	_microphone_allowed = (
		options.get("learningMicrophoneEnabled", false) == true
		and host.has_method("startLearningListening")
	)
	_enabled = true


func is_available() -> bool:
	return _enabled


func _ready() -> void:
	layer = 12
	visible = false
	if not _enabled:
		return
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.04, 0.09, 0.75)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_center)
	_frame = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("112e49")
	panel_style.border_color = Color("70dbd5")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(20)
	panel_style.set_content_margin_all(16)
	_frame.add_theme_stylebox_override("panel", panel_style)
	_center.add_child(_frame)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	_frame.add_child(body)
	var heading := Label.new()
	heading.text = "Frag Lumo"
	heading.add_theme_font_size_override("font_size", 23)
	heading.add_theme_color_override("font_color", Color("ffd68b"))
	body.add_child(heading)
	_hint = Label.new()
	_hint.text = "Schreib deine Frage oder verwende das Mikrofon."
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 16)
	body.add_child(_hint)
	_heard = Label.new()
	_heard.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heard.add_theme_font_size_override("font_size", 15)
	_heard.add_theme_color_override("font_color", Color("8ee5d3"))
	body.add_child(_heard)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 90
	body.add_child(scroll)
	_reply = Label.new()
	_reply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reply.add_theme_font_size_override("font_size", 19)
	_reply.text = "Ich bin da. Was möchtest du wissen?"
	scroll.add_child(_reply)
	_question = LineEdit.new()
	_question.placeholder_text = "Zum Beispiel: Warum zuerst zwei?"
	_question.custom_minimum_size.y = 52
	_question.add_theme_font_size_override("font_size", 17)
	_question.text_submitted.connect(_submit_text)
	body.add_child(_question)
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 8)
	controls.add_theme_constant_override("v_separation", 8)
	body.add_child(controls)
	_make_button(controls, "Fragen", _submit_question)
	_microphone = _make_button(controls, "Mikrofon", _start_microphone)
	_microphone.disabled = not _microphone_allowed
	_make_button(controls, "Hinweis", _request_action.bind("hint"))
	_make_button(controls, "Langsamer", _request_action.bind("slower"))
	_make_button(controls, "Noch einmal", _request_action.bind("repeat"))
	_make_button(controls, "Stopp", stop_dialog)
	_make_button(controls, "Schließen", close_dialog)
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_process(true)


func _make_button(parent: Control, title: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = title
	b.custom_minimum_size = Vector2(116, 52)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _layout() -> void:
	if not is_instance_valid(_center) or not is_instance_valid(_frame):
		return
	var dim := get_viewport().get_visible_rect().size
	var density := maxf(1.0, MobileRuntime.get_ui_density())
	var safe := MobileRuntime.get_safe_area_insets() if OS.has_feature("android") else Rect2()
	var remaining := dim - safe.position - safe.size
	_center.position = safe.position + Vector2(8, 8)
	_center.size = remaining - Vector2(16, 16)
	var width := maxf(270.0, minf(610.0 * density, remaining.x - 32.0))
	var height := maxf(250.0, minf(430.0 * density, remaining.y - 32.0))
	_frame.custom_minimum_size = Vector2(width, height)


func open_dialog() -> void:
	if not _enabled or not is_instance_valid(_question):
		return
	visible = true
	_last_delivered_turn = maxi(_last_delivered_turn, _turn_id - 1)
	_hint.text = "Du kannst jederzeit unterbrechen oder nachfragen."


func close_dialog() -> void:
	stop_dialog()
	visible = false


func stop_dialog() -> void:
	if _enabled and is_instance_valid(_host):
		_host.call("stopLearningConversation")
	_turn_id += 1
	_last_delivered_turn = _turn_id
	_last_transcript_turn = _turn_id
	if is_instance_valid(_hint):
		_hint.text = "Gestoppt. Du kannst eine neue Frage stellen."
	dialog_stopped.emit()


func update_explanation(explanation: String) -> void:
	if not _enabled or not is_instance_valid(_host) or explanation.length() > 1200:
		return
	var packet := {
		"scope": _scope,
		"kind": _kind,
		"explanation": explanation,
		"objectIds": _object_ids,
		"allowedActions": ["explain", "hint", "slower", "repeat", "stop"]
	}
	_host.call("updateLearningContext", JSON.stringify(packet))


func _submit_text(value: String) -> void:
	if value.strip_edges().is_empty():
		return
	_send_request("explain", value.strip_edges())


func _submit_question() -> void:
	_submit_text(_question.text)


func _request_action(action: String) -> void:
	_send_request(action, "")


func _send_request(action: String, content: String) -> void:
	if not _enabled or not is_instance_valid(_host):
		return
	_turn_id += 1
	var packet := {"scope": _scope, "turnId": _turn_id, "action": action, "text": content}
	var accepted: Variant = _host.call("requestLearningConversation", JSON.stringify(packet))
	if accepted == true or accepted == 1:
		_hint.text = "Lumo denkt über deine Frage nach …"
		_heard.text = "Deine Frage: " + content if not content.is_empty() else ""
		_question.clear()
	else:
		_hint.text = "Die Frage konnte nicht übernommen werden. Versuche es noch einmal."


func _start_microphone() -> void:
	if not _enabled or not _microphone_allowed or not is_instance_valid(_host):
		return
	_turn_id += 1
	var request := JSON.stringify({"scope": _scope, "turnId": _turn_id})
	var accepted: Variant = _host.call("startLearningListening", request)
	_hint.text = (
		"Ich höre zu. Du kannst die erkannte Frage danach prüfen."
		if accepted == true or accepted == 1
		else "Die lokale Spracherkennung ist nicht verfügbar. Du kannst schreiben."
	)


func _same_scope(reply_scope: Variant) -> bool:
	if not reply_scope is Dictionary:
		return false
	for key in ["protocolVersion", "sessionId", "taskId", "revision", "cancelEpoch", "stepId"]:
		if str(reply_scope.get(key, "")) != str(_scope.get(key, "")):
			return false
	return true


func _process(delta: float) -> void:
	if not visible or not _enabled or not is_instance_valid(_host):
		return
	_poll_clock += delta
	if _poll_clock < 0.08:
		return
	_poll_clock = 0.0
	var raw: Variant = JSON.parse_string(str(_host.call("getLearningConversationStatus")))
	if not raw is Dictionary or not _same_scope(raw.get("scope", {})):
		return
	var turn := int(raw.get("turnId", -1))
	if turn != _turn_id:
		return
	var state := str(raw.get("state", "idle"))
	match state:
		"listening":
			_hint.text = "Ich höre zu …"
		"recognizing", "thinking":
			_hint.text = "Lumo verarbeitet deine Frage …"
		"transcribed":
			if turn != _last_transcript_turn:
				_last_transcript_turn = turn
				_question.text = str(raw.get("transcript", "")).left(1200)
				_heard.text = "Bitte prüfe den erkannten Text und tippe auf Fragen."
				_hint.text = "Erkannte Wörter sind noch keine bewertete Antwort."
		"ready":
			if turn != _last_delivered_turn:
				_last_delivered_turn = turn
				_reply.text = str(raw.get("reply", "")).left(1200)
				_hint.text = "Du kannst nachfragen oder eine andere Erklärung verlangen."
				reply_ready.emit(_reply.text, str(raw.get("objectId", "")), str(raw.get("action", "explain")))
		"permission", "error":
			if turn != _last_delivered_turn:
				_last_delivered_turn = turn
				_hint.text = str(raw.get("reply", "Bitte verwende die Texteingabe.")).left(300)
		"cancelled":
			_hint.text = "Gestoppt."
