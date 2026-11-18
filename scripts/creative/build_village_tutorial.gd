extends Control
## Lumos Einführung in die Dorfwelt – Kapitel 1 derselben Speicherdatei.
## Jeder Schritt: ein kurzer Satz, ein Zeiger auf genau das Bedienelement, und
## das Spiel wartet auf die ECHTE Handlung (Kamera, Bauplatz, Kauf, Tag).
## Danach läuft das Dorf nahtlos weiter. Überspringbar; je Thema wiederholbar.
## Reine Bedienhilfe: verändert nie Rohstoffe, Regeln oder den Spielstand.
signal finished
const VHUD = preload("res://scripts/creative/build_village_hud.gd")
const STATE_VERSION := 1
## id, Satz (≤ 12 Wörter), Ziel, Abschluss ("wait" = echte Handlung, "ok" = Knopf)
const STEPS := [
	{"id": "hallo", "text": "Hallo, ich bin Lumo! Bauen wir zusammen ein Dorf?", "target": "lumo", "mode": "start"},
	{"id": "kamera", "text": "Wische mit einem Finger, um dich umzusehen.", "target": "world", "mode": "wait"},
	{"id": "bauplatz", "text": "Tippe auf einen hellen Bauplatz.", "target": "plot", "mode": "wait"},
	{"id": "wohnhaus", "text": "Wähle das Wohnhaus. Dort wohnt eine Familie.", "target": "card_house", "mode": "wait"},
	{"id": "rohstoffe", "text": "Oben siehst du Holz, Stein und Essen.", "target": "chips", "mode": "ok"},
	{"id": "bauernhof", "text": "Ein Bauernhof macht Essen. Baue einen!", "target": "card_farm", "mode": "wait"},
	{"id": "tag", "text": "Tippe auf „Nächster Tag“. Dann arbeitet dein Dorf.", "target": "day", "mode": "wait"},
	{"id": "bewohner", "text": "Mit Essen und Platz ziehen neue Familien ein.", "target": "people", "mode": "ok"},
	{"id": "ziel", "text": "Hier steht dein Ziel. Jetzt baust du weiter!", "target": "goal", "mode": "ok"},
]
## Themen für „Lumo zeigt es noch einmal“: erster und letzter Schritt.
const TOPICS := {
	"Umsehen": [1, 1], "Bauen": [2, 3], "Rohstoffe": [4, 4], "Essen": [5, 5], "Tage": [6, 7], "Ziele": [8, 8],
}
## Kontext-Erklärungen: genau einmal, nie als Textwand.
const CONTEXT := {
	"handel": "Beim Handeln tauschst du fünf gegen fünf. Rechne mit!",
	"tilda": "Tilda bringt Waren am nächsten Tag. Bezahlt wird mit Münzen.",
	"stadtkasse": "Zwei von zehn Münzen gehen in die Stadtkasse.",
	"nachbarn": "Das sind deine Nachbarn. Sie bauen wie du.",
	"angriff": "Achtung! Lumo erklärt, wer kommt und was hilft.",
	"verteidigung": "Mauern und Wachen schützen. Plane vorher!",
	"karawane": "Eine Karawane bringt Waren zum Nachbarn und zurück.",
}
var world: Node
var step := 0
var done := false
var replay_end := -1
var seen: Array = []
var start_day := 1
var camera_start := Vector3.ZERO
var camera_turn := 0.0
var bubble: PanelContainer
var bubble_text: Label
var bubble_buttons: HFlowContainer
var pointer: Control
var ring: Control
var context_topic := ""
var clock := 0.0


func setup(owner_world: Node, saved: Variant) -> void:
	world = owner_world
	name = "VillageTutorial"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	var data: Dictionary = saved if saved is Dictionary else {}
	if data.get("version") == STATE_VERSION:
		step = clampi(int(data.get("step", 0)), 0, STEPS.size())
		done = bool(data.get("done", false))
		start_day = maxi(1, int(data.get("start_day", 1)))
		for topic in data.get("seen", []):
			if str(topic) in CONTEXT and not seen.has(str(topic)):
				seen.append(str(topic))
	else:
		# Villages that already exist are not sent back to school.
		var town: Dictionary = world.model.player()
		done = town.buildings.size() >= 2 or int(world.model.day) > 3
		start_day = int(world.model.day)
	if not done:
		_skip_satisfied()
	_show()


func snapshot() -> Dictionary:
	return {"version": STATE_VERSION, "step": step, "done": done, "seen": seen.duplicate(), "start_day": start_day}


func active() -> bool:
	return (not done or replay_end >= 0) and step < STEPS.size()


func current_id() -> String:
	return str(STEPS[step].id) if step < STEPS.size() else ""


func _build() -> void:
	ring = Control.new()
	ring.name = "TutorialHighlight"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(_draw_ring)
	add_child(ring)
	pointer = Control.new()
	pointer.name = "TutorialPointer"
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.size = Vector2(56, 56)
	pointer.draw.connect(_draw_pointer)
	add_child(pointer)
	bubble = PanelContainer.new()
	bubble.name = "LumoBubble"
	bubble.add_theme_stylebox_override("panel", VHUD.panel("parchment", 12))
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bubble)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bubble.add_child(row)
	var face := TextureRect.new()
	face.name = "LumoFace"
	face.texture = VHUD.texture("lumo_portrait")
	face.custom_minimum_size = Vector2(64, 64)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(face)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	bubble_text = VHUD.label("", 19, Color("183d4c"))
	bubble_text.remove_theme_constant_override("outline_size")
	bubble_text.add_theme_constant_override("outline_size", 0)
	bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(bubble_text)
	bubble_buttons = HFlowContainer.new()
	bubble_buttons.add_theme_constant_override("h_separation", 8)
	bubble_buttons.add_theme_constant_override("v_separation", 8)
	column.add_child(bubble_buttons)


func _clear_buttons() -> void:
	for child in bubble_buttons.get_children():
		bubble_buttons.remove_child(child)
		child.queue_free()


func _add_button(caption: String, action: Callable, variant := "primary") -> Button:
	# Deferred: the pressed button is replaced only after its own input event.
	var button := VHUD.button(caption, func(): action.call_deferred(), 140, variant, 16)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	bubble_buttons.add_child(button)
	return button


func _show() -> void:
	_clear_buttons()
	if not context_topic.is_empty():
		bubble_text.text = str(CONTEXT[context_topic])
		_add_button("Verstanden", _close_context)
		visible = true
		_relayout()
		return
	visible = active()
	if not visible:
		return
	var spec: Dictionary = STEPS[step]
	bubble_text.text = str(spec.text)
	match str(spec.mode):
		"start":
			_add_button("Los geht's!", _next)
			if replay_end < 0:
				_add_button("Ich kenne das schon", skip, "cream")
		"ok":
			_add_button("Verstanden", _next)
		_:
			if replay_end < 0:
				_add_button("Überspringen", skip, "cream")
	if str(spec.id) == "kamera" and replay_end >= 0:
		camera_start = world.focus
		camera_turn = world.orbit + world.radius * 0.1 + world.tilt
	if str(spec.id) == "tag":
		start_day = int(world.model.day)
	_relayout()
	if world.has_method("tutorial_focus"):
		world.tutorial_focus(str(spec.target))


func _next() -> void:
	step += 1
	if replay_end >= 0 and step > replay_end:
		replay_end = -1
		step = STEPS.size()
	_skip_satisfied()
	if step >= STEPS.size() and not done:
		done = true
		finished.emit()
	world.tutorial_changed()
	_show()


func skip() -> void:
	replay_end = -1
	done = true
	step = STEPS.size()
	world.tutorial_changed()
	_show()


## „Lumo zeigt es noch einmal“ für ein Thema.
func replay(topic: String) -> void:
	if not TOPICS.has(topic):
		return
	var span: Array = TOPICS[topic]
	step = int(span[0])
	replay_end = int(span[1])
	context_topic = ""
	_show()


## Neue Themen genau einmal kurz erklären (erster Handel, erster Angriff ...).
func explain_once(topic: String) -> bool:
	if not CONTEXT.has(topic) or seen.has(topic) or active():
		return false
	seen.append(topic)
	context_topic = topic
	world.tutorial_changed()
	_show()
	return true


func _close_context() -> void:
	context_topic = ""
	_show()


func _condition_met(id: String) -> bool:
	var town: Dictionary = world.model.player()
	match id:
		"kamera":
			var turned: float = world.orbit + world.radius * 0.1 + world.tilt
			return world.focus.distance_to(camera_start) > 4.0 or absf(turned - camera_turn) > 0.35
		"bauplatz":
			return world.selected_plot >= 0 or world.model._count(town, "house") > 0
		"wohnhaus":
			return world.model._count(town, "house") > 0
		"bauernhof":
			return world.model._count(town, "farm") > 0
		"tag":
			return int(world.model.day) > start_day
	return false


func _skip_satisfied() -> void:
	# Replays always show their steps; the first run skips what is done already.
	while replay_end < 0 and step < STEPS.size() and str(STEPS[step].mode) == "wait":
		if str(STEPS[step].id) == "kamera":
			# Looking around is always shown once; measured from this moment.
			camera_start = world.focus
			camera_turn = world.orbit + world.radius * 0.1 + world.tilt
			break
		if not _condition_met(str(STEPS[step].id)):
			break
		step += 1
	if step >= STEPS.size() and replay_end < 0:
		done = true


func _process(delta: float) -> void:
	clock += delta
	if not visible:
		return
	if context_topic.is_empty() and active() and str(STEPS[step].mode) == "wait" and _condition_met(str(STEPS[step].id)):
		_next()
		return
	_relayout()
	pointer.queue_redraw()
	ring.queue_redraw()


func target_rect() -> Rect2:
	if not context_topic.is_empty() or not active():
		return Rect2()
	return world.tutorial_target_rect(str(STEPS[step].target))


func _relayout() -> void:
	var area := size
	var width := minf(clampf(area.x * 0.92, 260.0, 560.0), area.x - 16.0)
	bubble.custom_minimum_size = Vector2(width, 0)
	bubble.size = Vector2(width, 0)
	bubble.reset_size()
	var target := target_rect()
	# Above the dock when the target is high, below the top bar otherwise.
	var dock_top: float = world.tutorial_safe_band().y
	var top_end: float = world.tutorial_safe_band().x
	var y := dock_top - bubble.size.y - 12.0
	if target.size != Vector2.ZERO and target.end.y > y - 8.0 and target.position.y > area.y * 0.45:
		y = top_end + 12.0
	if target.size != Vector2.ZERO and Rect2(Vector2((area.x - width) * 0.5, y), bubble.size).intersects(target):
		y = top_end + 12.0 if target.position.y > area.y * 0.5 else dock_top - bubble.size.y - 12.0
	bubble.position = Vector2((area.x - width) * 0.5, clampf(y, top_end + 4.0, maxf(top_end + 4.0, area.y - bubble.size.y - 4.0)))
	ring.visible = target.size != Vector2.ZERO
	pointer.visible = ring.visible
	if ring.visible:
		ring.position = target.position - Vector2(6, 6)
		ring.size = target.size + Vector2(12, 12)
		var bob := sin(clock * 5.0) * 7.0
		var above := target.position.y > 70.0
		pointer.position = Vector2(target.get_center().x - 28.0, (target.position.y - 60.0 + bob) if above else (target.end.y + 4.0 - bob))
		pointer.set_meta("down", above)


func _draw_ring() -> void:
	var pulse := 0.6 + 0.4 * sin(clock * 4.0)
	var rect := Rect2(Vector2.ZERO, ring.size)
	ring.draw_rect(rect, Color(1.0, 0.85, 0.3, 0.9 * pulse), false, 5.0)
	ring.draw_rect(rect.grow(4.0), Color(1.0, 1.0, 1.0, 0.35 * pulse), false, 2.0)


func _draw_pointer() -> void:
	var down: bool = pointer.get_meta("down", true)
	var tip := Vector2(28, 54) if down else Vector2(28, 2)
	var base_y := 18.0 if down else 38.0
	var shaft := Rect2(18, 0, 20, 22) if down else Rect2(18, 34, 20, 22)
	var outline := Color("193b47")
	var fill := Color("ffd25a")
	var head := PackedVector2Array([Vector2(4, base_y), Vector2(52, base_y), tip])
	pointer.draw_rect(shaft.grow(3.0), outline)
	pointer.draw_colored_polygon(PackedVector2Array([head[0] + Vector2(-4, -2 if down else 2), head[1] + Vector2(4, -2 if down else 2), tip + Vector2(0, 5 if down else -5)]), outline)
	pointer.draw_rect(shaft, fill)
	pointer.draw_colored_polygon(head, fill)
