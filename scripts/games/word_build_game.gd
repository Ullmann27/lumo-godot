## WordBuildGame - Buchstaben in richtige Reihenfolge bringen.
##
## Lumo zeigt ein Wort + Bild (z.B. "BALL", ⚽). Die Buchstaben des Wortes
## erscheinen unten gemischt als Tafeln. Spieler tippt sie in richtiger
## Reihenfolge an. Jeder Tap fügt den Buchstaben oben an die Antwort an.
##
## Mechanik:
##   - 5 Runden mit kurzen Worten (3-5 Buchstaben)
##   - Jeder richtige Buchstabe: +1 Stern
##   - Komplettes Wort richtig in 1. Versuch: +3 Bonus + Lumo celebrate
##   - Falsche Reihenfolge: Buchstabe blinkt rot, Antwort wird zurueckgesetzt
##   - "Tipp"-Button: zeigt fuer 1.5s den naechsten korrekten Buchstaben groen
extends Node3D

const ROUNDS_PER_GAME: int = 5

@export var lumo_path: NodePath
@export var prompt_emoji_label_path: NodePath
@export var prompt_word_label_path: NodePath
@export var answer_label_path: NodePath  # Aktuelle Antwort des Spielers
@export var question_counter_path: NodePath
@export var stars_counter_path: NodePath
@export var hint_button_path: NodePath
@export var clear_button_path: NodePath
@export var back_button_path: NodePath
@export var replay_button_path: NodePath
@export var tiles_root_path: NodePath
@export var result_overlay_path: NodePath

var _lumo: LumoCharacterController
var _words: Array[Dictionary] = []
var _current_index: int = 0
var _current_word: String = ""
var _expected_progress: int = 0  # bisher korrekt platzierte Buchstaben
var _stars_this_session: int = 0
var _mistakes_this_round: int = 0
var _accepting_input: bool = true
var _tile_buttons: Array[Button] = []


func _ready() -> void:
	randomize()
	_lumo = get_node_or_null(lumo_path) as LumoCharacterController
	_connect_btn(back_button_path, _go_back)
	_connect_btn(replay_button_path, _start_new_game)
	_connect_btn(hint_button_path, _show_hint)
	_connect_btn(clear_button_path, _clear_answer)
	_hide_result_overlay()
	_collect_tile_buttons()
	_start_new_game()


func _connect_btn(path: NodePath, fn: Callable) -> void:
	var b: Button = get_node_or_null(path) as Button
	if b != null:
		b.pressed.connect(fn)


func _collect_tile_buttons() -> void:
	_tile_buttons.clear()
	var root: Node = get_node_or_null(tiles_root_path)
	if root == null:
		return
	for child in root.get_children():
		if child is Button:
			_tile_buttons.append(child as Button)


func _start_new_game() -> void:
	ProgressStore.streak_reset()
	_words = ReadingWordPool.short_words(ROUNDS_PER_GAME)
	_current_index = 0
	_stars_this_session = 0
	_hide_result_overlay()
	_update_stars_label()
	_show_question()


func _show_question() -> void:
	if _current_index >= _words.size():
		_show_result()
		return
	_accepting_input = true
	_mistakes_this_round = 0
	var entry: Dictionary = _words[_current_index]
	_current_word = String(entry["word"]).to_upper()
	_expected_progress = 0
	# UI
	var counter: Label = get_node_or_null(question_counter_path) as Label
	if counter != null:
		counter.text = "%d / %d" % [_current_index + 1, _words.size()]
	var emoji: Label = get_node_or_null(prompt_emoji_label_path) as Label
	if emoji != null:
		emoji.text = String(entry["emoji"])
	var word_label: Label = get_node_or_null(prompt_word_label_path) as Label
	if word_label != null:
		word_label.text = _current_word
	_update_answer_label()
	# Tiles: jeder Buchstabe des Wortes wird in zufaelliger Reihenfolge auf
	# eine Tafel verteilt. Wenn weniger Buchstaben als Tiles: ueberzaehlige
	# Tiles deaktivieren.
	var letters_shuffled: Array[String] = []
	for c in _current_word:
		letters_shuffled.append(c)
	letters_shuffled.shuffle()
	for i in range(_tile_buttons.size()):
		var b: Button = _tile_buttons[i]
		if i < letters_shuffled.size():
			b.text = letters_shuffled[i]
			b.disabled = false
			b.visible = true
			b.modulate = Color(1, 1, 1, 1)
			# Pressed verbinden (alte connection erst trennen)
			for con in b.pressed.get_connections():
				b.pressed.disconnect(con["callable"])
			b.pressed.connect(_on_tile_pressed.bind(i, letters_shuffled[i]))
		else:
			b.visible = false
	# Lumo erklaert das Wort
	if _lumo != null:
		_lumo.play_behavior("speak")
	AudioManager.play_voice("words/" + String(entry["word"]).to_lower())


func _on_tile_pressed(button_index: int, letter: String) -> void:
	if not _accepting_input:
		return
	if _expected_progress >= _current_word.length():
		return
	var expected: String = _current_word[_expected_progress]
	if letter == expected:
		# Richtig: Tafel ausblenden, Progress erhoehen
		_expected_progress += 1
		var b: Button = _tile_buttons[button_index]
		b.disabled = true
		b.modulate = Color(0.5, 1, 0.5, 0.4)
		AudioManager.play_sfx("ui_confirm")
		# Lumo: kleiner positiver Tick
		if _lumo != null:
			_lumo.play_behavior("speak")
		_update_answer_label()
		# Wort komplett?
		if _expected_progress == _current_word.length():
			_round_complete()
	else:
		# Falsch: rot pulsen, Antwort zuruecksetzen
		_mistakes_this_round += 1
		var b: Button = _tile_buttons[button_index]
		var tw: Tween = create_tween()
		b.modulate = Color(1, 0.4, 0.4, 1)
		tw.tween_property(b, "scale", Vector2(1.15, 1.15), 0.10)
		tw.tween_property(b, "scale", Vector2(1.0, 1.0), 0.20)
		tw.tween_property(b, "modulate", Color(1, 1, 1, 1), 0.30)
		AudioManager.play_sfx("ui_cancel")
		if _lumo != null:
			_lumo.play_behavior("encourage")
		_clear_answer()


func _clear_answer() -> void:
	_expected_progress = 0
	for b in _tile_buttons:
		if not b.visible:
			continue
		b.disabled = false
		b.modulate = Color(1, 1, 1, 1)
	_update_answer_label()


func _show_hint() -> void:
	if _expected_progress >= _current_word.length():
		return
	var next_letter: String = _current_word[_expected_progress]
	for b in _tile_buttons:
		if b.visible and not b.disabled and b.text == next_letter:
			var tw: Tween = create_tween()
			b.modulate = Color(1, 1, 0.4, 1)
			tw.tween_interval(1.5)
			tw.tween_property(b, "modulate", Color(1, 1, 1, 1), 0.30)
			break


func _update_answer_label() -> void:
	var ans: Label = get_node_or_null(answer_label_path) as Label
	if ans == null:
		return
	var built: String = _current_word.substr(0, _expected_progress)
	var remaining: String = ""
	for i in range(_current_word.length() - _expected_progress):
		remaining += "_ "
	ans.text = built + remaining


func _round_complete() -> void:
	_accepting_input = false
	var earned: int = _current_word.length()  # 1 pro Buchstabe
	if _mistakes_this_round == 0:
		earned += 3  # Perfect-Bonus
		if _lumo != null:
			_lumo.play_behavior("celebrate")
		ProgressStore.streak_hit()
	else:
		if _lumo != null:
			_lumo.play_behavior("reward")
		ProgressStore.streak_break()
	ProgressStore.add_stars(earned)
	_stars_this_session += earned
	# Buchstaben als gelernt markieren
	for c in _current_word.to_lower():
		ProgressStore.mark_letter_learned(c)
	_update_stars_label()
	# Naechste Runde nach 1.5s
	get_tree().create_timer(1.5).timeout.connect(_advance)


func _advance() -> void:
	_current_index += 1
	_show_question()


func _show_result() -> void:
	var overlay: Control = get_node_or_null(result_overlay_path) as Control
	if overlay == null:
		return
	overlay.show()
	var title: Label = overlay.get_node_or_null("Panel/VBox/Title") as Label
	if title != null:
		if _stars_this_session >= 25:
			title.text = "🎉 Perfekt!"
		elif _stars_this_session >= 15:
			title.text = "Gut gemacht!"
		else:
			title.text = "Weiter ueben!"
	var stats: Label = overlay.get_node_or_null("Panel/VBox/Stats") as Label
	if stats != null:
		stats.text = "+%d ★\nin %d Worten" % [_stars_this_session, _words.size()]
	if _lumo != null:
		_lumo.play_behavior("celebrate")


func _hide_result_overlay() -> void:
	var overlay: Control = get_node_or_null(result_overlay_path) as Control
	if overlay != null:
		overlay.hide()


func _update_stars_label() -> void:
	var stars: Label = get_node_or_null(stars_counter_path) as Label
	if stars != null:
		stars.text = "★ %d" % ProgressStore.total_stars()


func _go_back() -> void:
	if _lumo != null:
		_lumo.play_behavior("idle")
	SceneRouter.goto("reading_hub")
