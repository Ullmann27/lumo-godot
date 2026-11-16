extends Control
## Accessible, deliberately opened question surface. A recognizer result stays
## editable here; it is never submitted as a scored learning answer.
signal requested(text: String, action: String)
signal listen_requested
signal stopped
signal closed
signal answer_proposed(index: int)
var input: LineEdit
var reply: Label
var state_label: Label
var microphone: Button
var sheet: PanelContainer
var body: VBoxContainer
var _microphone_allowed := false
var choices: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.13, 0.12, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	sheet = PanelContainer.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("fff8e8")
	panel.border_color = Color("c4d6b9")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(22)
	panel.set_content_margin_all(18)
	sheet.add_theme_stylebox_override("panel", panel)
	add_child(sheet)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	var title := _label("Frag Lumo", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_button(heading, "Zurück", _close)
	body.add_child(_label("Du kannst fragen, verbessern oder eine andere Erklärung verlangen.", 18))
	input = LineEdit.new()
	input.placeholder_text = "Deine Frage oder Korrektur …"
	input.max_length = 500
	input.custom_minimum_size = Vector2(0, 54)
	input.add_theme_font_size_override("font_size", 19)
	input.add_theme_color_override("font_color", Color("193d35"))
	input.add_theme_color_override("font_placeholder_color", Color("66776c"))
	var field := StyleBoxFlat.new()
	field.bg_color = Color("ffffff")
	field.border_color = Color("a6c1ad")
	field.set_border_width_all(2)
	field.set_corner_radius_all(12)
	field.set_content_margin_all(12)
	input.add_theme_stylebox_override("normal", field)
	input.add_theme_stylebox_override("focus", field)
	input.text_submitted.connect(func(_value: String): _send())
	body.add_child(input)
	var entry := HFlowContainer.new()
	entry.add_theme_constant_override("h_separation", 8)
	entry.add_theme_constant_override("v_separation", 8)
	body.add_child(entry)
	microphone = _button(entry, "Sprechen", func(): listen_requested.emit())
	microphone.visible = _microphone_allowed
	_button(entry, "Frage senden", _send)
	_button(entry, "Stopp", func(): stopped.emit())
	state_label = _label("Deine erkannten Worte kannst du vor dem Senden ändern.", 16)
	body.add_child(state_label)
	reply = _label("", 19)
	body.add_child(reply)
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	body.add_child(choices)
	var shortcuts := HFlowContainer.new()
	shortcuts.add_theme_constant_override("h_separation", 8)
	shortcuts.add_theme_constant_override("v_separation", 8)
	body.add_child(shortcuts)
	_button(shortcuts, "Noch einmal", func(): requested.emit("", "repeat"))
	_button(shortcuts, "Langsamer", func(): requested.emit("", "slower"))
	_button(shortcuts, "Ein Hinweis", func(): requested.emit("", "hint"))
	resized.connect(_layout)
	visible = false


func _label(words: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = words
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("193d35"))
	return label


func _button(parent: Control, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(52, 52)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("18382f"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e2eddb")
	style.border_color = Color("a9bea1")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	button.add_theme_stylebox_override("normal", style)
	var focus := style.duplicate() as StyleBoxFlat
	focus.border_color = Color("315e4e")
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("cadcbe")
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func set_microphone_available(value: bool) -> void:
	_microphone_allowed = value
	if is_instance_valid(microphone):
		microphone.visible = value


func open_question() -> void:
	visible = true
	_layout()


func _send() -> void:
	var words := input.text.strip_edges()
	if words.is_empty():
		state_label.text = "Stelle eine Frage oder wähle einen Hinweis."
		return
	requested.emit(words, "explain")


func set_state(value: String, message: String = "") -> void:
	state_label.text = (
		message
		if not message.is_empty()
		else (
			{
				"starting": "Das Mikrofon wird vorbereitet …",
				"listening": "Ich höre zu …",
				"recognizing": "Ich schaue, welche Worte ich gehört habe …",
				"thinking": "Lumo schaut sich deine Frage an …",
				"ready": "Du kannst eine neue Frage stellen.",
				"idle": "Du kannst in deinem Tempo weitermachen.",
			}
			. get(value, "Versuche es noch einmal oder schreibe deine Frage.")
		)
	)


func set_transcript(words: String) -> void:
	input.text = words
	state_label.text = "Habe ich dich richtig verstanden? Ändere die Worte bei Bedarf und sende dann deine Frage."
	input.caret_column = input.text.length()


func show_task(words: String, options: Array[String]) -> void:
	open_question()
	reply.text = words
	for item in choices.get_children():
		item.free()
	for index in range(options.size()):
		var button := _button(choices, options[index], func(): answer_proposed.emit(index))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	state_label.text = "Deine Antwort wird erst in deiner Aufgabe geprüft. Hier kannst du einen Vorschlag wählen."


func _close() -> void:
	visible = false
	closed.emit()


func _layout() -> void:
	if not is_instance_valid(sheet):
		return
	var width := maxf(220.0, minf(620.0, size.x - 24.0))
	var height := maxf(120.0, minf(440.0, size.y - 24.0))
	sheet.size = Vector2(width, height)
	sheet.position = (size - sheet.size) * 0.5
