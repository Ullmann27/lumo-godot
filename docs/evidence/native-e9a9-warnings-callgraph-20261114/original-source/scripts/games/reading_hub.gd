## ReadingHub - Mini-Game-Auswahl-Bühne.
##
## 4 große Karten (Alphabet / Bild-Match / Anlaut-Hören / Wort-Bauen).
## Tap auf Karte: SceneRouter.goto(...). HUD oben zeigt Sterne, gelernte
## Buchstaben und Best-Streak.
extends Node3D

@export var lumo_path: NodePath
@export var stars_label_path: NodePath
@export var letters_label_path: NodePath
@export var streak_label_path: NodePath
@export var back_button_path: NodePath
@export var card_alphabet_path: NodePath
@export var card_picture_path: NodePath
@export var card_sound_path: NodePath
@export var card_build_path: NodePath

var _lumo: LumoCharacterController


func _ready() -> void:
	_lumo = get_node_or_null(lumo_path) as LumoCharacterController
	_connect(back_button_path, _back_to_home)
	_connect(card_alphabet_path, func(): _open("alphabet"))
	_connect(card_picture_path, func(): _open("word_picture_match"))
	_connect(card_sound_path, func(): _open("sound_letter_match"))
	_connect(card_build_path, func(): _open("word_build"))
	_refresh_hud()
	ProgressStore.stars_changed.connect(_on_stars_changed)
	ProgressStore.letters_changed.connect(_on_letters_changed)
	ProgressStore.streak_changed.connect(_on_streak_changed)
	if _lumo != null:
		_lumo.play_behavior("greet")
	print("[Hub] reading_hub ready")


func _connect(path: NodePath, fn: Callable) -> void:
	var n: Node = get_node_or_null(path)
	if n == null:
		return
	if n is Button:
		(n as Button).pressed.connect(fn)
	elif n is BaseButton:
		(n as BaseButton).pressed.connect(fn)


func _refresh_hud() -> void:
	_on_stars_changed(ProgressStore.total_stars())
	_on_letters_changed(ProgressStore.learned_letters().size())
	_on_streak_changed(ProgressStore.best_streak(), ProgressStore.current_streak())


func _on_stars_changed(total: int) -> void:
	var lbl: Label = get_node_or_null(stars_label_path) as Label
	if lbl != null:
		lbl.text = "★ %d" % total


func _on_letters_changed(count: int) -> void:
	var lbl: Label = get_node_or_null(letters_label_path) as Label
	if lbl != null:
		lbl.text = "🔤 %d / 26" % count


func _on_streak_changed(best: int, _current: int) -> void:
	var lbl: Label = get_node_or_null(streak_label_path) as Label
	if lbl != null:
		lbl.text = "🔥 Rekord %d" % best


func _open(scene_id: String) -> void:
	if _lumo != null:
		_lumo.play_behavior("point")
	AudioManager.play_sfx("ui_confirm")
	SceneRouter.goto(scene_id)


func _back_to_home() -> void:
	AudioManager.play_sfx("ui_back")
	SceneRouter.goto("home")
