extends CanvasLayer
## Erste Einführung je Kind und Spiel („Lumo zeigt es dir“).
##
## Ein Spiel hängt sie über seinen Adapter in scripts/games/guides/ ein. Jeder
## Schritt erklärt genau eine Handlung, zeigt mit Leuchtrahmen und Pfeil auf das
## echte Bedienelement und wartet, bis das Kind die Handlung selbst ausführt.
## Der Stand liegt je Kind (childKey) und Spiel in einer eigenen Datei:
## gesehen („done“), übersprungen („skipped“) oder unterbrochen („running“ mit
## Schritt – beim nächsten Öffnen geht es dort weiter).
##
## Schritt: {id, text, target: Callable -> Control|Rect2|null,
##           done: Callable(guide) -> bool, skip: Callable -> bool (optional)}
##
## Automatisierte --script-Läufe sehen die Einführung nicht (wie das Kart-Intro);
## Tests schalten sie mit SceneRouter.launch_options["firstRunGuide"] = "force" ein.

signal step_completed(step_id: String)
signal closed(state: String)

const PORTRAIT_PATH := "res://assets/cards_table/portraits/lumo.webp"
const VOICE_DIR := "res://assets/audio/voice/guides/"
const BODY_FONT = preload("res://assets/fonts/Nunito-Bold.ttf")
const HEADING_FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const STORE_PREFIX := "user://lumo_first_run_"
const TOUCH_PX := 126.0
const PRAISE: Array[String] = ["Super!", "Toll gemacht!", "Klasse!", "Prima!"]
const PRAISE_SECONDS := 0.9
const OUTRO_SECONDS := 2.2
const GOLD := Color("ffd75e")
const INK := Color("0b2247")
const WHITE := Color("f7fbff")
const MUTED := Color("c3d3ea")

var game_id: String = ""
var child_key: String = "standalone"
var steps: Array[Dictionary] = []
## Spiel ist bereit (z. B. Rennen läuft, keine Pause). Sonst ist alles verborgen.
var active_check: Callable
## Oben links des Wiederholen-Knopfs in Bildschirmkoordinaten; bekommt dessen Größe.
var replay_position: Callable
var outro_text: String = "Geschafft! Jetzt kannst du allein los."
var reduced_motion: bool = false
## running | praise | outro | done | skipped
var state: String = "done"
var index: int = 0
var replaying: bool = false
var shown_steps: Array[String] = []
## Schritte, die in dieser Sitzung durch eine Handlung des Kindes erfüllt wurden.
var completed: Array[String] = []
var root: Control
var frame: Control
var bubble: PanelContainer
var portrait: TextureRect
var text_label: Label
var dots_label: Label
var skip_button: Button
var replay_button: Button
var voice: AudioStreamPlayer
var _events: Dictionary = {}
var _hold: float = 0.0
var _delta: float = 0.0
var _clock: float = 0.0
var _left: float = 0.0
var _praise: String = ""
var _was_on: bool = false
var _step_live: bool = false

# ------------------------------------------------------------------ Ablage je Kind


## "auto" (Standard), "force" (Tests) oder "off".
static func mode() -> String:
	var wanted := str(SceneRouter.launch_options.get("firstRunGuide", "auto"))
	if wanted in ["force", "off"]:
		return wanted
	if OS.get_cmdline_args().has("--script"):
		return "off"
	return "auto"


static func launch_child() -> String:
	var child := str(
		SceneRouter.launch_options.get("childKey", HostBridge.launch_options().get("childKey", ""))
	)
	return child if not child.is_empty() else "standalone"


static func store_path(child: String) -> String:
	var identity := child if not child.is_empty() else "standalone"
	return STORE_PREFIX + identity.sha256_text().substr(0, 32) + ".cfg"


static func load_status(child: String, game: String) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(store_path(child)) != OK:
		return {"state": "new", "step": 0}
	var saved := str(config.get_value(game, "state", "new"))
	if saved not in ["new", "running", "done", "skipped"]:
		saved = "new"
	return {"state": saved, "step": maxi(0, int(config.get_value(game, "step", 0)))}


static func save_status(child: String, game: String, saved: String, step: int) -> void:
	var config := ConfigFile.new()
	var path := store_path(child)
	config.load(path)
	config.set_value(game, "state", saved)
	config.set_value(game, "step", step)
	config.set_value(game, "updated", int(Time.get_unix_time_from_system()))
	if config.save(path) != OK:
		push_warning("[FirstRunGuide] could not save %s" % path)


## Hängt die Einführung an das Spiel. Ohne Einführung (Modus „off“) kommt null zurück.
static func attach(
	game: Node, id: String, guide_steps: Array, active: Callable, options: Dictionary = {}
) -> CanvasLayer:
	if mode() == "off" or not is_instance_valid(game):
		return null
	var existing := game.get_node_or_null("FirstRunGuide")
	if existing != null:
		return existing
	var guide = load("res://scripts/systems/first_run_guide.gd").new()
	guide.name = "FirstRunGuide"
	guide.game_id = id
	guide.child_key = str(options.get("child", launch_child()))
	guide.steps.assign(guide_steps)
	guide.active_check = active
	guide.replay_position = options.get("replay_position", Callable())
	guide.outro_text = str(options.get("outro", guide.outro_text))
	guide.layer = int(options.get("layer", 60))
	var calm: Variant = game.get("reduced_motion")
	guide.reduced_motion = (
		bool(calm)
		if calm != null
		else bool(SceneRouter.launch_options.get("reduceAnimations", false))
	)
	game.add_child(guide)
	return guide


# ------------------------------------------------------------------ Ablauf


func _ready() -> void:
	_build()
	var status := load_status(child_key, game_id)
	if status.state in ["done", "skipped"]:
		state = str(status.state)
	else:
		state = "running"
		index = clampi(int(status.step), 0, maxi(0, steps.size() - 1))
		_begin_step()
	print(
		(
			"[FirstRunGuide] %s child=%s state=%s step=%d"
			% [game_id, child_key.sha256_text().substr(0, 8), state, index]
		)
	)


func _process(delta: float) -> void:
	_delta = delta
	_clock += delta
	var on: bool = active_check.is_valid() and bool(active_check.call())
	root.visible = on
	if on != _was_on:
		_was_on = on
		if on and state == "running":
			_begin_step(false)
	if not on:
		# Eine Handlung, die das Spiel sofort weiterschaltet (z. B. Lumo ist dran),
		# zählt trotzdem; das Lob erscheint, sobald das Kind wieder dran ist.
		if state == "running" and _step_live and bool(steps[index].done.call(self)):
			_complete_step()
		return
	match state:
		"running":
			_skip_unavailable()
			_step_live = state == "running"
			if state == "running" and bool(steps[index].done.call(self)):
				_complete_step()
		"praise":
			_left -= delta
			if _left <= 0.0:
				index += 1
				state = "running"
				_skip_unavailable()
				if state == "running":
					_begin_step()
		"outro":
			_left -= delta
			if _left <= 0.0:
				_close("done")
	_refresh()


func _skip_unavailable() -> void:
	while index < steps.size() and _unavailable(steps[index]):
		index += 1
	if index >= steps.size():
		_start_outro()


func _unavailable(step: Dictionary) -> bool:
	var skip: Variant = step.get("skip", null)
	return skip is Callable and (skip as Callable).is_valid() and bool((skip as Callable).call())


func _begin_step(fresh: bool = true) -> void:
	if fresh:
		_events.clear()
		_hold = 0.0
		_step_live = false
	if index >= steps.size():
		_start_outro()
		return
	var step: Dictionary = steps[index]
	if str(step.id) not in shown_steps:
		shown_steps.append(str(step.id))
	if not replaying:
		save_status(child_key, game_id, "running", index)
	_play_voice(str(step.id))


func _complete_step() -> void:
	var id := str(steps[index].id)
	completed.append(id)
	step_completed.emit(id)
	print("[FirstRunGuide] step done ", id, " t=", _clock)
	_praise = PRAISE[index % PRAISE.size()]
	state = "praise"
	_left = PRAISE_SECONDS
	if not replaying:
		save_status(child_key, game_id, "running", index + 1)


func _start_outro() -> void:
	state = "outro"
	index = steps.size()
	_left = OUTRO_SECONDS
	if not replaying:
		save_status(child_key, game_id, "done", steps.size())


func _close(final_state: String) -> void:
	if not replaying or final_state == "skipped":
		save_status(
			child_key, game_id, final_state, index if final_state == "skipped" else steps.size()
		)
	state = final_state
	replaying = false
	_refresh()
	closed.emit(final_state)


## „Überspringen“: jederzeit möglich, merkt sich das für dieses Kind.
func skip() -> void:
	if state in ["running", "praise", "outro"]:
		_close("skipped" if state != "outro" else "done")


## „Lumo, zeig es mir nochmal“.
func replay() -> void:
	replaying = true
	index = 0
	state = "running"
	_skip_unavailable()
	if state == "running":
		_begin_step()
	_refresh()


func is_running() -> bool:
	return state in ["running", "praise", "outro"]


func current_step_id() -> String:
	if state in ["running", "praise"] and index < steps.size():
		return str(steps[index].id)
	return ""


# ------------------------------------------------------------------ Helfer für Adapter


## Merkt eine echte Eingabe (z. B. aus einem Knopf-Signal) für den laufenden Schritt.
func note(event: String) -> void:
	_events[event] = true


func seen(event: String) -> bool:
	return _events.has(event)


## Zuwachs eines Zählers (z. B. Sterne) seit Beginn des laufenden Schritts.
func since_step(key: String, value: float) -> float:
	if not _events.has("@" + key):
		_events["@" + key] = value
	return value - float(_events["@" + key])


## True, sobald ok ohne Unterbrechung für seconds Sekunden gilt.
func held(ok: bool, seconds: float) -> bool:
	_hold = _hold + _delta if ok else 0.0
	return _hold >= seconds


# ------------------------------------------------------------------ Darstellung


## Viewport-Einheiten je dp (wie run_ui.gd) und je Bildschirmpixel.
func pixels_per_unit() -> float:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var window: Vector2 = Vector2(get_window().size)
	if window.x <= 0.0 or window.y <= 0.0:
		window = view
	return maxf(0.1, minf(window.x / maxf(view.x, 1.0), window.y / maxf(view.y, 1.0)))


func unit() -> float:
	return MobileRuntime.get_ui_density() / pixels_per_unit()


## Kleinste Kantenlänge eines Touch-Ziels: 48 dp, mindestens 126 Bildschirmpixel.
func touch_size() -> float:
	return maxf(48.0 * unit(), TOUCH_PX / pixels_per_unit())


func target_rect() -> Rect2:
	if state != "running" or index >= steps.size():
		return Rect2()
	var target: Variant = steps[index].get("target", null)
	if not (target is Callable) or not (target as Callable).is_valid():
		return Rect2()
	var value: Variant = (target as Callable).call()
	if value is Rect2:
		return value
	if value is Control and is_instance_valid(value) and (value as Control).is_visible_in_tree():
		return (value as Control).get_global_rect()
	return Rect2()


func _build() -> void:
	root = Control.new()
	root.name = "GuideRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	frame = Control.new()
	frame.name = "Pointer"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(_draw_pointer)
	root.add_child(frame)
	bubble = PanelContainer.new()
	bubble.name = "GuideBubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bubble)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(row)
	portrait = TextureRect.new()
	portrait.name = "LumoPortrait"
	portrait.texture = load(PORTRAIT_PATH) as Texture2D
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	dots_label = Label.new()
	dots_label.name = "StepDots"
	dots_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots_label.add_theme_font_override("font", HEADING_FONT)
	dots_label.add_theme_color_override("font_color", GOLD)
	column.add_child(dots_label)
	text_label = Label.new()
	text_label.name = "GuideText"
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_font_override("font", HEADING_FONT)
	text_label.add_theme_color_override("font_color", WHITE)
	column.add_child(text_label)
	skip_button = _make_button("GuideSkip", "Überspringen ▸▸")
	skip_button.tooltip_text = "Einführung überspringen"
	skip_button.pressed.connect(skip)
	row.add_child(skip_button)
	replay_button = _make_button("GuideReplay", "")
	replay_button.tooltip_text = "Lumo, zeig es mir nochmal"
	replay_button.icon = portrait.texture
	replay_button.expand_icon = true
	replay_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay_button.pressed.connect(replay)
	replay_button.draw.connect(_draw_replay_badge)
	root.add_child(replay_button)
	voice = AudioStreamPlayer.new()
	voice.name = "GuideVoice"
	add_child(voice)
	root.visible = false


func _make_button(id: String, caption: String) -> Button:
	var button := Button.new()
	button.name = id
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", HEADING_FONT)
	for look in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (
			Color(0.06, 0.17, 0.36, 0.96) if look != "pressed" else Color(0.12, 0.3, 0.55, 1.0)
		)
		style.border_color = GOLD
		style.set_border_width_all(3)
		style.set_corner_radius_all(64)
		style.set_content_margin_all(10)
		button.add_theme_stylebox_override(look, style)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	return button


func _refresh() -> void:
	if not is_instance_valid(root):
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var u: float = unit()
	var touch: float = touch_size()
	var talking: bool = state in ["running", "praise", "outro"]
	bubble.visible = talking
	replay_button.visible = not talking
	if talking:
		_layout_bubble(view, u, touch)
	else:
		replay_button.custom_minimum_size = Vector2.ONE * touch
		replay_button.size = Vector2.ONE * touch
		var spot: Vector2 = Vector2(view.x - touch - 16.0 * u, view.y * 0.22)
		if replay_position.is_valid():
			spot = replay_position.call(replay_button.size)
		replay_button.position = spot.clamp(Vector2.ZERO, view - replay_button.size)
	frame.queue_redraw()
	replay_button.queue_redraw()


func _layout_bubble(view: Vector2, u: float, touch: float) -> void:
	match state:
		"praise":
			text_label.text = _praise
		"outro":
			text_label.text = outro_text
		_:
			text_label.text = str(steps[index].text) if index < steps.size() else ""
	var total: int = 0
	var done: int = 0
	for position in range(steps.size()):
		if _unavailable(steps[position]):
			continue
		total += 1
		if position < index or (position == index and state == "praise"):
			done += 1
	dots_label.text = "LUMO ZEIGT ES DIR  " + "●".repeat(done) + "○".repeat(maxi(0, total - done))
	dots_label.add_theme_font_size_override("font_size", roundi(15.0 * u))
	text_label.add_theme_font_size_override("font_size", roundi(25.0 * u))
	skip_button.add_theme_font_size_override("font_size", roundi(17.0 * u))
	skip_button.custom_minimum_size = Vector2(touch * 1.9, touch)
	skip_button.visible = state != "outro"
	portrait.custom_minimum_size = Vector2.ONE * maxf(touch * 0.95, 64.0 * u)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.09, 0.22, 0.93)
	style.border_color = GOLD
	style.set_border_width_all(maxi(2, roundi(2.5 * u)))
	style.set_corner_radius_all(roundi(24.0 * u))
	style.set_content_margin_all(12.0 * u)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = roundi(10.0 * u)
	bubble.add_theme_stylebox_override("panel", style)
	var width: float = minf(view.x - 32.0 * u, maxf(640.0 * u, view.x * 0.5))
	width = minf(width, view.x - 24.0)
	bubble.custom_minimum_size = Vector2(width, 0.0)
	bubble.size = Vector2(width, 0.0)
	bubble.reset_size()
	var target: Rect2 = target_rect()
	var y: float = view.y * 0.16
	if target.has_area() and target.get_center().y < view.y * 0.5:
		y = minf(view.y - bubble.size.y - 24.0 * u, target.end.y + 40.0 * u)
	var x: float = (view.x - bubble.size.x) * 0.5
	bubble.position = Vector2(maxf(12.0, x), maxf(12.0, y))
	# Nie über dem Ziel: notfalls an den oberen Rand.
	if target.has_area() and bubble.get_global_rect().intersects(target.grow(8.0 * u)):
		bubble.position.y = maxf(12.0, target.position.y - bubble.size.y - 40.0 * u)


func _draw_pointer() -> void:
	var rect: Rect2 = target_rect()
	if not rect.has_area():
		return
	var u: float = unit()
	var wave: float = 0.0 if reduced_motion else 0.5 + 0.5 * sin(_clock * 5.0)
	var glow: Rect2 = rect.grow((10.0 + 6.0 * wave) * u)
	for ring in range(3):
		var grow_by: float = float(ring) * 5.0 * u
		var alpha: float = 0.85 - 0.25 * float(ring) - 0.25 * wave
		_rounded_outline(
			glow.grow(grow_by), 18.0 * u + grow_by, Color(GOLD, alpha), (5.0 - ring) * u
		)
	# Pfeil von der Sprechblase zum Ziel.
	var from: Vector2 = (
		bubble.get_rect().get_center()
		if bubble.visible
		else rect.get_center() + Vector2(0, -120) * u
	)
	var tip: Vector2 = _edge_point(glow, from)
	var direction: Vector2 = (tip - from).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	tip -= direction * (8.0 + 10.0 * wave) * u
	var length: float = 70.0 * u
	var tail: Vector2 = tip - direction * length
	var side: Vector2 = direction.orthogonal()
	frame.draw_line(tail, tip - direction * 22.0 * u, Color(INK, 0.9), 16.0 * u, true)
	frame.draw_line(tail, tip - direction * 22.0 * u, GOLD, 10.0 * u, true)
	var head := PackedVector2Array(
		[
			tip,
			tip - direction * 30.0 * u + side * 20.0 * u,
			tip - direction * 30.0 * u - side * 20.0 * u
		]
	)
	frame.draw_colored_polygon(head, GOLD)
	frame.draw_polyline(head + PackedVector2Array([tip]), Color(INK, 0.9), 3.0 * u, true)


func _rounded_outline(rect: Rect2, radius: float, colour: Color, width: float) -> void:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = colour
	style.set_border_width_all(maxi(1, roundi(width)))
	style.set_corner_radius_all(roundi(radius))
	style.anti_aliasing = true
	frame.draw_style_box(style, rect)


func _edge_point(rect: Rect2, from: Vector2) -> Vector2:
	var centre: Vector2 = rect.get_center()
	var delta: Vector2 = from - centre
	if delta == Vector2.ZERO:
		return centre
	var half: Vector2 = rect.size * 0.5
	var factor: float = minf(
		half.x / maxf(absf(delta.x), 0.001), half.y / maxf(absf(delta.y), 0.001)
	)
	return centre + delta * minf(factor, 1.0)


func _draw_replay_badge() -> void:
	var size: Vector2 = replay_button.size
	var r: float = size.x * 0.2
	var centre := Vector2(size.x - r * 0.7, r * 0.7)
	replay_button.draw_circle(centre, r, GOLD)
	replay_button.draw_string(
		HEADING_FONT,
		centre + Vector2(-r * 0.36, r * 0.42),
		"?",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		roundi(r * 1.4),
		INK
	)


## Sprache nur mit echter Aufnahme (VOICE_DIR/<spiel>_<schritt>.ogg|.wav), sonst still.
func _play_voice(step_id: String) -> void:
	for extension in [".ogg", ".wav"]:
		var path: String = VOICE_DIR + game_id + "_" + step_id + extension
		if ResourceLoader.exists(path):
			voice.stream = load(path)
			voice.play()
			return
