extends Control
## Lumos Einführung in die Dorfwelt – Kapitel 1 derselben Speicherdatei.
## Erster Besuch: kurzer Luftblick über das eigene Tal, die Kamera setzt neben
## Lumo an einem freien Bauplatz auf, Lumo fragt: „Hier entsteht dein Dorf.
## Wollen wir das erste Haus bauen?“ Danach handelt das Kind selbst: Platz
## wählen, Haus bauen, „Versorgen“ öffnen, Bauernhof setzen, ersten Tag
## erleben. Beim ersten Ertrag fliegen die Karotten sichtbar vom Hof in den
## Vorrat und vom Vorrat zur Familie.
## Jeder Schritt erklärt genau eine Handlung: ein kurzer Satz (Text) und ein
## eigener Sprechsatz (Stimme) – beides funktioniert auch allein. Ein Zeiger
## zeigt auf genau das Bedienelement, das Spiel wartet auf die ECHTE Handlung.
## Überspringbar; „Lumo, zeig mir mein Dorf“ startet den Rundgang jederzeit
## neu; bei Rückkehr geht es am letzten sinnvollen Schritt weiter. Alte Dörfer
## ohne gespeicherten Stand werden nie still als „erledigt“ markiert, sondern
## bekommen das Angebot. Reine Bedienhilfe: verändert nie Rohstoffe oder Regeln.
signal finished
const VHUD = preload("res://scripts/creative/build_village_hud.gd")
const GUIDE = preload("res://scripts/creative/build_village_guide.gd")
const VOICE = preload("res://scripts/creative/build_village_voice.gd")
const STATE_VERSION := 2
const TOUR_CAPTION := "Lumo, zeig mir mein Dorf"
## id, Text (≤ 12 Wörter), Sprechsatz, Ziel, Abschluss:
## "flight" = Luftblick, "start" = Frage, "wait" = echte Handlung, "ok" = Knopf.
## "replay" = nur beim Wiederholen eines Themas.
const STEPS := [
	{"id": "luftblick", "text": "Das ist dein Tal. Schau es dir von oben an!",
		"say": "Schau, das ist dein Tal. Gleich landen wir.", "target": "", "mode": "flight"},
	{"id": "hallo", "text": "Hier entsteht dein Dorf. Wollen wir das erste Haus bauen?",
		"say": "Hier entsteht dein Dorf. Wollen wir das erste Haus bauen?", "target": "lumo", "mode": "start"},
	{"id": "bauplatz", "text": "Tippe auf einen hellen Bauplatz.",
		"say": "Tippe auf einen hellen Platz auf der Wiese.", "target": "plot", "mode": "wait"},
	{"id": "wohnhaus", "text": "Tippe auf das Wohnhaus. Dort wohnt eine Familie.",
		"say": "Jetzt tippe auf das Wohnhaus. Dort wohnt eine Familie.", "target": "card_house", "mode": "wait"},
	{"id": "versorgen", "text": "Tippe auf „Versorgen“. Dort wächst das Essen.",
		"say": "Tippe unten auf Versorgen. Dort wächst das Essen.", "target": "tab_versorgen", "mode": "wait"},
	{"id": "bauernhof", "text": "Tippe auf den Bauernhof. Er macht Karotten.",
		"say": "Tippe auf den Bauernhof. Er macht Karotten.", "target": "card_farm", "mode": "wait"},
	{"id": "tag", "text": "Tippe auf „Nächster Tag“. Dann arbeitet dein Dorf.",
		"say": "Tippe auf Nächster Tag. Dann arbeitet dein Dorf.", "target": "day", "mode": "wait"},
	{"id": "ernte", "text": "Dein Hof hat %d Karotten geerntet. Sie kommen in den Vorrat.",
		"say": "Schau! Dein Hof hat %d Karotten geerntet. Sie kommen in den Vorrat.", "target": "harvest", "mode": "ok"},
	{"id": "familie", "text": "Aus dem Vorrat isst die Familie: %d Karotten. Alle satt!",
		"say": "Aus dem Vorrat isst die Familie %d Karotten. Alle sind satt.", "target": "people", "mode": "ok"},
	{"id": "ziel", "text": "Hier steht dein Ziel. Jetzt baust du weiter!",
		"say": "Hier steht dein nächstes Ziel. Jetzt baust du weiter.", "target": "goal", "mode": "ok"},
	{"id": "kamera", "text": "Wische mit einem Finger, um dich umzusehen.",
		"say": "Wische mit einem Finger über das Bild, um dich umzusehen.", "target": "world", "mode": "wait", "replay": true},
	{"id": "rohstoffe", "text": "Oben siehst du Holz, Stein und Essen.",
		"say": "Oben siehst du dein Holz, deinen Stein und dein Essen.", "target": "chips", "mode": "ok", "replay": true},
]
## Gespeicherte Schritt-Nummern aus Version 1 (alte Reihenfolge) → neue IDs.
const V1_IDS := ["hallo", "bauplatz", "bauplatz", "wohnhaus", "versorgen", "bauernhof", "tag", "familie", "ziel"]
## Themen für „Lumo zeigt es noch einmal“: erster und letzter Schritt.
const TOPICS := {
	"Umsehen": ["kamera", "kamera"], "Bauen": ["bauplatz", "wohnhaus"], "Rohstoffe": ["rohstoffe", "rohstoffe"],
	"Essen": ["versorgen", "bauernhof"], "Tage": ["tag", "familie"], "Ziele": ["ziel", "ziel"],
}
## Kontext-Erklärungen: genau einmal, nie als Textwand. Optional mit Zeigerziel.
const CONTEXT := {
	"handel": "Beim Handeln tauschst du fünf gegen fünf. Rechne mit!",
	"tilda": "Tilda bringt Waren am nächsten Tag. Bezahlt wird mit Münzen.",
	"stadtkasse": "Zwei von zehn Münzen gehen in die Stadtkasse.",
	"nachbarn": "Das sind deine Nachbarn. Sie bauen wie du.",
	"angriff": "Achtung! Lumo erklärt, wer kommt und was hilft.",
	"verteidigung": "Mauern und Wachen schützen. Plane vorher!",
	"karawane": "Eine Karawane bringt Waren zum Nachbarn und zurück.",
	"bereich_tools": "Neu beim Bauen und Versorgen: mehr Gebäude!",
	"bereich_nachbarn": "Neu: „Nachbarn“. Dort sind Karte, Handel und Freunde.",
	"bereich_schuetzen": "Neu: „Schützen“. Dort planst du Wachen und Mauern.",
}
const CONTEXT_TARGETS := {"bereich_nachbarn": "tab_nachbarn", "bereich_schuetzen": "tab_schuetzen", "bereich_tools": "tab_bauen"}
var world: Node
var step := 0
var done := false
## Altes Dorf ohne Einführungsstand: Lumo bietet den Rundgang an.
var offering := false
var replay_end := -1
## Schritt der Ersteinführung, zu dem eine Themen-Wiederholung zurückkehrt.
var resume_step := -1
var resume_offer := false
var seen: Array = []
var start_day := 1
var camera_start := Vector3.ZERO
var camera_turn := 0.0
var bubble: PanelContainer
var bubble_text: Label
var bubble_buttons: HFlowContainer
var pointer: Control
var ring: Control
var guide: Control
var voice
var show_text := true
var context_topic := ""
var clock := 0.0
var spoken_step := ""
var harvest: Dictionary = {}


func setup(owner_world: Node, saved: Variant, options: Dictionary = {}) -> void:
	world = owner_world
	name = "VillageTutorial"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	show_text = options.get("villageTutorialText", true) != false
	voice = VOICE.from_options(options)
	guide = GUIDE.new()
	add_child(guide)
	guide.setup(world)
	guide.landed.connect(_landed)
	_build()
	var data: Dictionary = saved if saved is Dictionary else {}
	if data.get("version") == STATE_VERSION:
		step = _index(str(data.get("step_id", "")))
		done = bool(data.get("done", false))
		offering = bool(data.get("offer", false)) and not done
		start_day = maxi(1, int(data.get("start_day", 1)))
		_restore_seen(data.get("seen", []))
	elif data.get("version") == 1:
		# Version 1 stored a position in the old nine-step list.
		var old := clampi(int(data.get("step", 0)), 0, V1_IDS.size())
		step = _index(str(V1_IDS[old])) if old < V1_IDS.size() else STEPS.size()
		done = bool(data.get("done", false))
		start_day = maxi(1, int(data.get("start_day", 1)))
		_restore_seen(data.get("seen", []))
	else:
		# No saved state. A brand-new village starts with the flight; a grown one
		# is never silently marked done: Lumo offers the tour instead.
		var town: Dictionary = world.model.player()
		offering = town.buildings.size() > 0 or int(world.model.day) > 1
		start_day = int(world.model.day)
		step = 0
	if not done and not offering:
		if step > 0:
			_skip_satisfied()
			if active():
				guide.land_now()
	_show()
	if active() and STEPS[step].mode == "flight":
		guide.start_flight()


func _restore_seen(raw: Variant) -> void:
	if not raw is Array:
		return
	for topic in raw:
		if str(topic) in CONTEXT and not seen.has(str(topic)):
			seen.append(str(topic))


func _index(id: String) -> int:
	for index in range(STEPS.size()):
		if str(STEPS[index].id) == id:
			return index
	return STEPS.size()


func snapshot() -> Dictionary:
	var id := current_id()
	if replay_end >= 0:
		# Replays are not progress: the interrupted first run stays where it was.
		id = str(STEPS[resume_step].id) if resume_step >= 0 and resume_step < STEPS.size() else ""
	return {"version": STATE_VERSION, "step_id": id, "done": done, "offer": offering or (replay_end >= 0 and resume_offer),
		"seen": seen.duplicate(), "start_day": start_day}


func active() -> bool:
	return not offering and (not done or replay_end >= 0) and step < STEPS.size()


func current_id() -> String:
	return str(STEPS[step].id) if step < STEPS.size() else ""


## The first run uses every step except the replay-only ones.
func _main_step(index: int) -> bool:
	return index < STEPS.size() and not bool(STEPS[index].get("replay", false))


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
	# Fully opaque, bright card: easy to read for beginning readers.
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("fffaf0")
	paper.border_color = Color("c99a52")
	paper.set_border_width_all(3)
	paper.border_width_bottom = 6
	paper.set_corner_radius_all(22)
	paper.set_content_margin_all(14)
	paper.shadow_color = Color(0.02, 0.08, 0.12, 0.35)
	paper.shadow_size = 10
	paper.shadow_offset = Vector2(0, 4)
	bubble.add_theme_stylebox_override("panel", paper)
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bubble)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bubble.add_child(row)
	var face := TextureRect.new()
	face.name = "LumoFace"
	face.texture = VHUD.texture("lumo_portrait")
	face.custom_minimum_size = Vector2(90, 90)
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


## Satz eines Schritts mit den echten Zahlen des ersten Erntetags.
func step_text(index: int, spoken := false) -> String:
	var spec: Dictionary = STEPS[index]
	var text := str(spec.say if spoken else spec.text)
	match str(spec.id):
		"hallo":
			if world.model.player().buildings.size() > 0:
				text = "Das ist dein Dorf. Bauen wir zusammen weiter?"
		"ernte":
			text = text % int(harvest.get("food", 0))
		"familie":
			text = text % int(harvest.get("eaten", 0))
	return text


func _show() -> void:
	_clear_buttons()
	if not context_topic.is_empty():
		_say_line(str(CONTEXT[context_topic]), str(CONTEXT[context_topic]), "context_" + context_topic)
		_add_button("Verstanden", _close_context)
		visible = true
		_relayout()
		return
	if offering:
		_say_line("Willkommen zurück! Soll ich dir dein Dorf zeigen?", "Willkommen zurück! Soll ich dir dein Dorf zeigen?", "angebot")
		_add_button(TOUR_CAPTION, tour)
		_add_button("Nein, ich baue weiter", decline_offer, "cream")
		visible = true
		_relayout()
		return
	visible = active()
	_sync_guide()
	if not visible:
		return
	var spec: Dictionary = STEPS[step]
	_say_line(step_text(step), step_text(step, true), str(spec.id))
	match str(spec.mode):
		"flight":
			_add_button("Überspringen", skip, "cream")
		"start":
			_add_button("Ja, los!", _next)
			if replay_end < 0:
				_add_button("Ich kenne das schon", skip, "cream")
		"ok":
			_add_button("Verstanden", _next)
		_:
			if replay_end < 0:
				_add_button("Überspringen", skip, "cream")
	if str(spec.id) == "kamera":
		camera_start = world.focus
		camera_turn = world.orbit + world.radius * 0.1 + world.tilt
	if str(spec.id) == "tag":
		start_day = int(world.model.day)
	_relayout()
	if world.has_method("tutorial_focus"):
		world.tutorial_focus(str(spec.target))


## Text und Stimme getrennt: der Text kann aus sein, die Stimme kann fehlen.
func _say_line(text: String, spoken: String, key: String) -> void:
	bubble_text.text = text
	bubble_text.visible = show_text
	if spoken_step != key:
		spoken_step = key
		voice.say(spoken, key)
	if voice.available():
		_add_button("🔊", func(): voice.say(spoken, key), "cream")


func _sync_guide() -> void:
	if not is_instance_valid(guide):
		return
	var id := current_id() if active() else ""
	match id:
		"ernte":
			guide.start_flow("hof_vorrat", int(harvest.get("food", 0)))
		"familie":
			guide.start_flow("vorrat_familie", int(harvest.get("eaten", 0)))
		_:
			guide.stop_flow()
	if not active() or replay_end >= 0:
		guide.release_lumo()


func _landed() -> void:
	if active() and current_id() == "luftblick":
		_next()


func _next() -> void:
	if current_id() == "luftblick" and guide.flying:
		guide.finish_flight()
		return
	step += 1
	if replay_end >= 0 and step > replay_end:
		replay_end = -1
		step = resume_step if resume_step >= 0 else STEPS.size()
		resume_step = -1
		offering = resume_offer
		resume_offer = false
	while replay_end < 0 and step < STEPS.size() and not _main_step(step):
		step += 1
	_skip_satisfied()
	if step >= STEPS.size() and not done:
		done = true
		finished.emit()
	world.tutorial_changed()
	_show()


func skip() -> void:
	if guide.flying:
		guide.finish_flight()
	replay_end = -1
	resume_step = -1
	done = true
	offering = false
	step = STEPS.size()
	world.tutorial_changed()
	_show()


## „Lumo, zeig mir mein Dorf“: der ganze Rundgang mit Luftblick. Bereits
## erledigte Handlungen werden übersprungen, also geht es am letzten
## sinnvollen Schritt weiter (z. B. beim nächsten Tag und der Ernte).
func tour() -> void:
	offering = false
	done = false
	replay_end = -1
	resume_step = -1
	context_topic = ""
	step = 0
	spoken_step = ""
	world.tutorial_changed()
	_show()
	guide.start_flight()


## Altes Dorf: das Kind lehnt bewusst ab (nicht still erledigt).
func decline_offer() -> void:
	offering = false
	done = true
	step = STEPS.size()
	world.tutorial_changed()
	_show()


## „Lumo zeigt es noch einmal“ für ein Thema.
func replay(topic: String) -> void:
	if not TOPICS.has(topic):
		return
	var span: Array = TOPICS[topic]
	if replay_end < 0:
		resume_step = step if not done and not offering else -1
		resume_offer = offering
	offering = false
	step = _index(str(span[0]))
	replay_end = _index(str(span[1]))
	context_topic = ""
	spoken_step = ""
	_show()


## Neue Themen genau einmal kurz erklären (erster Handel, neuer Bereich ...).
func explain_once(topic: String) -> bool:
	if not CONTEXT.has(topic) or seen.has(topic) or active() or offering:
		return false
	seen.append(topic)
	context_topic = topic
	world.tutorial_changed()
	_show()
	return true


func _close_context() -> void:
	context_topic = ""
	_show()


## Echte Zahlen des ersten Tageswechsels (vom Spiel übergeben).
func record_day(report: Dictionary) -> void:
	var own: Dictionary = report.get("player", {})
	harvest = {
		"food": int((own.get("produced", {}) as Dictionary).get("food", 0)),
		"eaten": int(own.get("food_needed", 0)) - int(own.get("food_shortfall", 0)),
	}


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
		"versorgen":
			return world.dock_section() == "versorgen" or world.model._count(town, "farm") > 0
		"bauernhof":
			return world.model._count(town, "farm") > 0
		"tag":
			return int(world.model.day) > start_day
	return false


func _skip_satisfied() -> void:
	# Replays always show their steps; the first run skips what is done already.
	while replay_end < 0 and step < STEPS.size() and (str(STEPS[step].mode) == "wait" or not _main_step(step)):
		if not _main_step(step):
			step += 1
			continue
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
	var face := bubble.find_child("LumoFace", true, false) as TextureRect
	if face != null:
		face.pivot_offset = face.size * Vector2(0.5, 1.0)
		var breath := 1.0 + sin(clock * 2.2) * 0.025
		var blink := 0.92 if fmod(clock, 3.7) < 0.12 else 1.0
		face.scale = Vector2(breath, breath * blink)
	pointer.queue_redraw()
	ring.queue_redraw()


func target_id() -> String:
	if not context_topic.is_empty():
		return str(CONTEXT_TARGETS.get(context_topic, ""))
	if offering or not active():
		return ""
	return str(STEPS[step].target)


func target_rect() -> Rect2:
	var target := target_id()
	if target.is_empty():
		return Rect2()
	return world.tutorial_target_rect(target)


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
