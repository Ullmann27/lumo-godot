## MultiChoiceGame - gemeinsame Logik für Bild-Match + Anlaut-Hören.
##
## Beide Spiele zeigen 4 Buchstaben-Tafeln und fragen den Anfangsbuchstaben
## eines Wortes ab. Unterschied:
##   - mode "picture": Emoji + Wort sichtbar (visuell)
##   - mode "sound":   nur Audio (pure Höraufgabe)
##
## Konfiguration via @export mode.
##
## Mechanik:
##   - 10 Runden
##   - Pro richtiger Antwort: +1 Stern, Streak +1
##   - 3er-Streak: +1 Bonus-Stern + Lumo celebrate
##   - Bei Fehler: Streak break + Lumo encourage + richtige Tafel pulst
##   - Game-Ende: Result-Dialog mit Sterne-Total + "Nochmal" / "Zurueck"
class_name MultiChoiceGame
extends Node3D

const ROUNDS_PER_GAME: int = 10
const STREAK_BONUS_EVERY: int = 3

@export_enum("picture", "sound") var mode: String = "picture"
@export var lumo_path: NodePath
@export var prompt_emoji_label_path: NodePath  # Label oben mit Emoji
@export var prompt_word_label_path: NodePath  # Label mit Wort
@export var question_counter_path: NodePath  # "3 / 10"
@export var stars_counter_path: NodePath  # "★ 42"
@export var streak_label_path: NodePath  # "Streak x4!" floating
@export var back_button_path: NodePath
@export var replay_button_path: NodePath
@export var speaker_button_path: NodePath  # Wort nochmal hoeren
@export var tiles_root_path: NodePath  # CanvasLayer-Knoten mit 4 Button-Kindern
@export var result_overlay_path: NodePath  # Panel das beim Game-Ende ausblendet

var _lumo: LumoCharacterController
var _questions: Array[Dictionary] = []
var _current_index: int = 0
var _correct_this_session: int = 0
var _stars_this_session: int = 0
var _accepting_input: bool = true


func _ready() -> void:
	randomize()
	_lumo = get_node_or_null(lumo_path) as LumoCharacterController
	var back: Button = get_node_or_null(back_button_path) as Button
	if back != null:
		back.pressed.connect(_go_back)
	var replay: Button = get_node_or_null(replay_button_path) as Button
	if replay != null:
		replay.pressed.connect(_start_new_game)
		replay.hide()
	var speaker: Button = get_node_or_null(speaker_button_path) as Button
	if speaker != null:
		speaker.pressed.connect(_replay_word_audio)
	_hide_result_overlay()
	# Tile-Buttons bind
	var tiles_root: Node = get_node_or_null(tiles_root_path)
	if tiles_root != null:
		for i in range(4):
			var b: Button = tiles_root.get_child(i) as Button
			if b != null:
				b.pressed.connect(_on_choice.bind(i))
	_start_new_game()


func _start_new_game() -> void:
	ProgressStore.streak_reset()
	_questions = ReadingWordPool.random_questions(ROUNDS_PER_GAME)
	_current_index = 0
	_correct_this_session = 0
	_stars_this_session = 0
	_hide_result_overlay()
	_update_stars_label()
	_show_question()


func _show_question() -> void:
	if _current_index >= _questions.size():
		_show_result()
		return
	_accepting_input = true
	var q: Dictionary = _questions[_current_index]
	# Counter "3 / 10"
	var counter: Label = get_node_or_null(question_counter_path) as Label
	if counter != null:
		counter.text = "%d / %d" % [_current_index + 1, ROUNDS_PER_GAME]
	# Emoji + Wort: bei picture-mode zeigen, bei sound-mode verstecken
	var emoji: Label = get_node_or_null(prompt_emoji_label_path) as Label
	var word: Label = get_node_or_null(prompt_word_label_path) as Label
	if mode == "picture":
		if emoji != null:
			emoji.text = String(q["emoji"])
			emoji.show()
		if word != null:
			word.text = String(q["word"])
			word.show()
	else:
		if emoji != null:
			emoji.text = "?"
			emoji.show()
		if word != null:
			word.text = "..."
			word.show()
	# Tafeln neu befuellen
	var tiles_root: Node = get_node_or_null(tiles_root_path)
	if tiles_root != null:
		var choices: Array = q["choices"]
		for i in range(4):
			var b: Button = tiles_root.get_child(i) as Button
			if b == null:
				continue
			b.text = String(choices[i]).to_upper()
			b.disabled = false
			b.modulate = Color(1, 1, 1, 1)
	# Lumo erklaert -> spricht das Wort
	if _lumo != null:
		_lumo.play_behavior("speak")
	_speak_current_word()


func _speak_current_word() -> void:
	var q: Dictionary = _questions[_current_index]
	var w: String = String(q["word"]).to_lower()
	AudioManager.play_voice("words/" + w)


func _replay_word_audio() -> void:
	if _current_index < _questions.size():
		_speak_current_word()


func _on_choice(button_index: int) -> void:
	if not _accepting_input:
		return
	_accepting_input = false
	var q: Dictionary = _questions[_current_index]
	var choices: Array = q["choices"]
	var tapped_letter: String = String(choices[button_index])
	var correct_letter: String = String(q["letter"])
	if tapped_letter == correct_letter:
		_handle_correct(button_index)
	else:
		_handle_wrong(button_index, correct_letter)


func _handle_correct(button_index: int) -> void:
	_correct_this_session += 1
	ProgressStore.streak_hit()
	ProgressStore.mark_letter_learned(String(_questions[_current_index]["letter"]))
	# Stars
	var earned: int = 1
	if ProgressStore.current_streak() % STREAK_BONUS_EVERY == 0:
		earned += 1
		_show_streak_banner(ProgressStore.current_streak())
	ProgressStore.add_stars(earned)
	_stars_this_session += earned
	_update_stars_label()
	AudioManager.play_sfx("ui_confirm")
	if _lumo != null:
		if ProgressStore.current_streak() >= STREAK_BONUS_EVERY:
			_lumo.play_behavior("celebrate")
		else:
			_lumo.play_behavior("reward")
	# Tafel-pulse
	_pulse_button(button_index, Color(0.55, 0.95, 0.55, 1))
	# Naechste Frage nach 1.2s
	get_tree().create_timer(1.2).timeout.connect(_advance)


func _handle_wrong(tapped_button: int, correct_letter: String) -> void:
	ProgressStore.streak_break()
	AudioManager.play_sfx("ui_cancel")
	if _lumo != null:
		_lumo.play_behavior("encourage")
	_pulse_button(tapped_button, Color(1.0, 0.45, 0.45, 1))
	# Richtige Tafel auch markieren (gruen blinken)
	var q: Dictionary = _questions[_current_index]
	var choices: Array = q["choices"]
	for i in range(4):
		if String(choices[i]) == correct_letter:
			_pulse_button(i, Color(0.55, 0.95, 0.55, 1))
			break
	# 1.8s warten dann naechste Frage
	get_tree().create_timer(1.8).timeout.connect(_advance)


func _pulse_button(idx: int, c: Color) -> void:
	var tiles_root: Node = get_node_or_null(tiles_root_path)
	if tiles_root == null:
		return
	var b: Button = tiles_root.get_child(idx) as Button
	if b == null:
		return
	b.modulate = c
	var tw: Tween = create_tween()
	tw.tween_property(b, "scale", Vector2(1.15, 1.15), 0.10)
	tw.tween_property(b, "scale", Vector2(1.0, 1.0), 0.20)


func _show_streak_banner(streak: int) -> void:
	var banner: Label = get_node_or_null(streak_label_path) as Label
	if banner == null:
		return
	banner.text = "🔥 STREAK x%d!" % streak
	banner.modulate = Color(1, 1, 1, 1)
	banner.show()
	var tw: Tween = create_tween()
	tw.tween_property(banner, "scale", Vector2(1.3, 1.3), 0.15)
	tw.tween_property(banner, "scale", Vector2(1.0, 1.0), 0.20)
	tw.tween_interval(1.0)
	tw.tween_property(banner, "modulate:a", 0.0, 0.40)
	tw.tween_callback(banner.hide)


func _advance() -> void:
	_current_index += 1
	_show_question()


func _show_result() -> void:
	var overlay: Control = get_node_or_null(result_overlay_path) as Control
	if overlay == null:
		return
	overlay.show()
	# Titel + Stats
	var title: Label = overlay.get_node_or_null("Panel/VBox/Title") as Label
	if title != null:
		if _correct_this_session == ROUNDS_PER_GAME:
			title.text = "🎉 Perfekt!"
		elif _correct_this_session >= ROUNDS_PER_GAME / 2:
			title.text = "Gut gemacht!"
		else:
			title.text = "Ueb weiter!"
	var stats: Label = overlay.get_node_or_null("Panel/VBox/Stats") as Label
	if stats != null:
		stats.text = (
			"%d / %d richtig\n+%d ★" % [_correct_this_session, ROUNDS_PER_GAME, _stars_this_session]
		)
	# Lumo final celebrate / encourage
	if _lumo != null:
		if _correct_this_session >= ROUNDS_PER_GAME / 2:
			_lumo.play_behavior("celebrate")
		else:
			_lumo.play_behavior("encourage")
	var replay: Button = get_node_or_null(replay_button_path) as Button
	if replay != null:
		replay.show()


func _hide_result_overlay() -> void:
	var overlay: Control = get_node_or_null(result_overlay_path) as Control
	if overlay != null:
		overlay.hide()
	var replay: Button = get_node_or_null(replay_button_path) as Button
	if replay != null:
		replay.hide()


func _update_stars_label() -> void:
	var stars: Label = get_node_or_null(stars_counter_path) as Label
	if stars != null:
		stars.text = "★ %d" % ProgressStore.total_stars()


func _go_back() -> void:
	if _lumo != null:
		_lumo.play_behavior("idle")
	SceneRouter.goto("reading_hub")
