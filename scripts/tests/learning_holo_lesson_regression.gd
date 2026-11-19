extends SceneTree
## Holo-Lernräume: Textaufgabe (Zehnerübergang) und Deutsch (Tunwort, Satzbau).
## Echte Eingaben über die öffentlichen Kind-Aktionen der Szene.

const FIXTURES = preload("res://scripts/tests/holo_lesson_fixtures.gd")

var checks := 0
var failures := 0
var plan_script: GDScript


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[HoloLesson] FAIL " + message)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _open(
	learning: Dictionary, reduced: bool = true, size_value: Vector2i = Vector2i(1080, 2340)
) -> Node3D:
	root.size = size_value
	var scene := load("res://scenes/learning/holo_lesson.tscn") as PackedScene
	var game: Node3D = scene.instantiate()
	game.capture_options = {"learning": learning, "reduceAnimations": reduced}
	root.add_child(game)
	await _frames(3)
	return game


func _close(game: Node3D) -> void:
	game.queue_free()
	await _frames(3)


func _idle(game: Node3D, limit: float = 30.0) -> void:
	var started := Time.get_ticks_msec()
	while game.busy and Time.get_ticks_msec() - started < limit * 1000.0:
		await process_frame


func _run() -> void:
	plan_script = load("res://scripts/learning/holo/holo_lesson_plan.gd")
	var bridge = root.get_node("HostBridge")
	bridge._options["displayDensity"] = 2.625
	_plan_validation()
	_ten_frame_for_all_sums()
	await _math_flow(true)
	await _math_flow(false)
	await _verb_flow()
	await _order_flow()
	await _noun_flow()
	_noun_validation()
	await _layouts()
	await _low_profile()
	print("[HoloLesson] checks=%d failures=%d" % [checks, failures])
	var sound := root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	await create_timer(0.4).timeout
	quit(0 if failures == 0 else 1)


func _plan_validation() -> void:
	var plan = plan_script.new()
	_check(plan.configure(FIXTURES.math()), "valid math payload accepted")
	_check(plan.configure(FIXTURES.verb()), "valid verb payload accepted")
	_check(plan.configure(FIXTURES.order()), "valid order payload accepted")
	var broken: Array[Dictionary] = []
	var no_bridge := FIXTURES.math(4, 5, 6, 7)
	broken.append(no_bridge)
	var no_twin := FIXTURES.math()
	no_twin.erase("twin")
	broken.append(no_twin)
	var same_sum := FIXTURES.math(8, 5, 6, 7)
	broken.append(same_sum)
	var missing_answer := FIXTURES.math()
	missing_answer.choices = [12, 14, 15]
	broken.append(missing_answer)
	var wrong_prompt := FIXTURES.math()
	wrong_prompt.prompt = "Im Korb liegen viele Äpfel."
	broken.append(wrong_prompt)
	var wrong_words := FIXTURES.verb()
	wrong_words.words = ["Der", "Fuchs", "springt"]
	broken.append(wrong_words)
	var bad_verb := FIXTURES.verb()
	bad_verb.verbIndex = 9
	broken.append(bad_verb)
	for index in range(broken.size()):
		_check(
			not plan_script.new().configure(broken[index]), "invalid payload %d rejected" % index
		)


## Die ausführliche Hilfe zeigt für jedes a + b mit Zehnerübergang bis 20:
## a Äpfel, dann 10 - a aus der zweiten Gruppe → Zehnerfeld voll, Rest daneben.
func _ten_frame_for_all_sums() -> void:
	var tested := 0
	for a in range(2, 10):
		for b in range(2, 10):
			if a + b <= 10:
				continue
			var plan = plan_script.new()
			var twin_a := 9 if a != 9 else 8
			var twin_b := 9 if a + b != 18 else 3
			if twin_a + twin_b == a + b:
				twin_b = 4
			if not plan.configure(FIXTURES.math(a, b, twin_a, twin_b)):
				_check(false, "configure %d+%d" % [a, b])
				continue
			var parts: Vector2i = plan.bridge_parts()
			_check(parts.x == 10 - a and parts.y == a + b - 10, "bridge parts %d+%d" % [a, b])
			for index in range(a + parts.x):
				plan.toggle_frame(index)
			var first_frame_full := true
			var from_second_group := 0
			for index in range(a + b):
				var slot: int = plan.slot_of[index]
				if slot >= 0 and slot < 10 and index >= a:
					from_second_group += 1
			for slot in range(10):
				if not plan.slot_of.has(slot):
					first_frame_full = false
			_check(first_frame_full, "ten frame full for %d+%d" % [a, b])
			_check(from_second_group == 10 - a, "ten frame takes 10-a from b for %d+%d" % [a, b])
			for index in range(a + parts.x, a + b):
				plan.toggle_frame(index)
			_check(plan.frame_filled() == a + b, "all %d apples in the frame" % (a + b))
			tested += 1
	_check(tested == 36, "36 bridging sums checked (got %d)" % tested)


func _math_flow(reduced: bool) -> void:
	var game := await _open(FIXTURES.math(), reduced)
	var label := "math reduced=%s " % reduced
	_check(game.valid, label + "scene valid")
	_check(game.math_room.apples.size() == 13, label + "8 + 5 apples")
	await _idle(game)
	var first_view: String = game.prompt_label.text + game.bubble_text.text + game.feedback.text
	_check(not first_view.contains("13"), label + "first view does not reveal 13")
	_check(game.choice_buttons.size() == 4, label + "four answer choices")
	_check(game.tap_apple(0) == 1 and game.tap_apple(3) == 2, label + "counting numbers on apples")
	_check(game.tap_apple(8) == 1, label + "second group counts from 1")
	_check(game.move_apple_to_frame(1) == 0, label + "apple moved into first slot")
	_check(game.choose("12") == "wrong", label + "12 is wrong")
	_check(game.bubble_text.text.contains("stimmt noch nicht"), label + "calm feedback")
	_check(game.feedback.text.is_empty(), label + "old message hidden during help")
	_check(game.plan.hint_level == 1, label + "first mistake gives the focus hint")
	await _idle(game)
	_check(
		game.math_room.badges[0].visible and game.math_room.badges[1].visible,
		label + "both groups labelled"
	)
	_check(not (game.bubble_text.text.contains("13")), label + "focus hint does not reveal 13")
	_check(game.choose("14") == "wrong", label + "14 is wrong")
	_check(game.plan.hint_level == 2, label + "second mistake gives the full help")
	if not reduced:
		await process_frame
		_check(game.busy, label + "full help is animated")
		_check(game.skip_button.visible, label + "skip available during animation")
		_check(not game.hint_button.visible, label + "skip takes the hint's place")
		# Jeder Schritt der Vorführung: Lumo verdeckt das Zwanzigerfeld nie.
		var frame_rect := _screen_rect(game, game.math_room.frame_box()).grow(-2.0)
		var covered_frames := 0
		var watched := 0
		var reached_spot := false
		while game.busy and watched < 4000:
			await process_frame
			watched += 1
			if _screen_rect(game, _fox_box(game)).intersects(frame_rect):
				if covered_frames == 0:
					print(
						(
							"[HoloLesson] Lumo over frame at %s: %s vs %s"
							% [game._fox_ground(), _screen_rect(game, _fox_box(game)), frame_rect]
						)
					)
				covered_frames += 1
			if game._fox_ground().distance_to(game._math_point_spot()) < 0.05:
				reached_spot = true
		_check(covered_frames == 0, label + "Lumo never covers the frame (%d)" % covered_frames)
		_check(reached_spot, label + "Lumo walks to the frame and points")
		_check(
			game._fox_ground().distance_to(game._fox_home) < 0.05,
			label + "Lumo returns to his place"
		)
	await _idle(game)
	_check(game.events.has("ten_complete"), label + "ten frame completed in the help")
	_check(game.bubble_text.text.contains("= 10 + 3."), label + "explains 8 + 5 as 10 + 3")
	_check(not game.bubble_text.text.contains("13"), label + "full help leaves 10 + 3 to the child")
	_check(game.events.has("borrowed:2"), label + "two apples borrowed with a visible path")
	_check(game.math_room.paths.get_child_count() >= 2, label + "golden paths shown")
	_check(game.plan.frame_filled() == 13, label + "13 apples in the frames")
	var hints: Array[String] = []
	for event: String in game.events:
		if event.begins_with("hint:"):
			hints.append(event)
	_check(hints == ["hint:1:original", "hint:2:original"], label + "hints in order " + str(hints))
	_check(game.choose("13") == "correct", label + "13 is correct")
	await _idle(game)
	_check(game.twin_button.visible, label + "similar task offered")
	_check(game.start_twin(), label + "similar task starts")
	await _idle(game)
	_check(game.plan.phase == "twin" and game.math_room.apples.size() == 14, label + "twin 6 + 8")
	_check(game.prompt_label.text.contains("6 Äpfel"), label + "twin prompt")
	_check(game.choose("12") == "wrong", label + "twin wrong")
	_check(game.plan.hint_level == 2, label + "twin does not escalate help")
	_check(game.choose("14") == "correct", label + "twin solved")
	await _idle(game)
	_check(game.plan.phase == "done", label + "lesson done")
	game.return_to_lesson()
	game.return_to_lesson()
	_check(game.return_count == 1, label + "returned exactly once")
	var holo: Dictionary = game.last_return.get("holo", {})
	_check(game.last_return.get("status") == "illustrated", label + "existing status contract")
	_check(
		holo.get("originalCorrect") == true and holo.get("originalAnswer") == "13",
		label + "original result"
	)
	_check(
		int(holo.get("hintLevel", -1)) == 2 and int(holo.get("originalAttempts", 0)) == 3,
		label + "help level"
	)
	_check(
		holo.get("twinSolved") == true and int(holo.get("twinAttempts", 0)) == 2,
		label + "twin result"
	)
	_check(str(holo.get("resultId", "")).length() > 8, label + "result id")
	_check(holo.get("taskId") == "task-korb-8-5", label + "task id")
	await _close(game)


func _verb_flow() -> void:
	var game := await _open(FIXTURES.verb(), false)
	_check(game.valid, "verb scene valid")
	var room = game.word_room
	_check(room.cards.size() == 4, "four word cards")
	_cards_neutral(room, "verb")
	var first_view: String = game.bubble_text.text + game.feedback.text
	_check(not first_view.contains("springt"), "first view does not name the verb in Lumo's text")
	game.tap_card(2)
	_check(room.selected == 2, "tap selects card")
	_check(game.confirm() == "wrong", "Fuchs is not the verb")
	_check(game.bubble_text.text.contains("Namenwort"), "concrete help for a noun")
	_check(game.plan.hint_level == 1, "focus hint after first mistake")
	await process_frame
	_check(game.busy, "Lumo demonstrates")
	await _idle(game)
	_check(game.events.has("lumo_jump"), "Lumo jumped once")
	_check(game.bubble_text.text.contains("Was tut der Fuchs?"), "Lumo asks what the fox does")
	_check(game.drop_card_on_field(1) == "wrong", "kleine dropped is wrong")
	_check(game.bubble_text.text.contains("Wiewort"), "concrete help for an adjective")
	await _idle(game)
	_check(game.events.has("show_verb:springt"), "full help shows the verb card")
	game.tap_card(3)
	_check(game.confirm() == "correct", "springt is correct")
	await _idle(game)
	_check(game.start_twin(), "twin sentence starts")
	await _idle(game)
	_check(game.plan.current().sentence == "Die Ente schwimmt im Teich.", "twin sentence")
	_check(int(game.plan.current().verbIndex) == 2, "verb not at the end in twin")
	game.tap_card(2)
	_check(game.confirm() == "correct", "schwimmt chosen independently")
	game.return_to_lesson()
	var holo: Dictionary = game.last_return.get("holo", {})
	_check(
		holo.get("originalAnswer") == "springt" and holo.get("twinSolved") == true, "verb result"
	)
	await _close(game)


## Alle Karten gleich gefärbt (Papier, Kante, Halo) und in Lesereihenfolge
## (Zeile für Zeile, links nach rechts): weder Farbe noch Lage verrät etwas.
func _cards_neutral(room: Node3D, label: String) -> void:
	var color: Color = room.paper(0).get_shader_parameter("albedo")
	var halo: Color = room.halo_color(0)
	for index in range(room.cards.size()):
		_check(
			room.paper(index).get_shader_parameter("albedo") == color,
			label + " card %d same colour" % index
		)
		_check(room.halo_color(index) == halo, label + " card %d same halo" % index)
		if index > 0:
			var before: Vector3 = room.home[index - 1]
			var here: Vector3 = room.home[index]
			_check(
				here.z > before.z + 0.5 or (absf(here.z - before.z) < 0.01 and here.x > before.x),
				label + " reading order %d" % index
			)


func _noun_flow() -> void:
	var game := await _open(FIXTURES.noun(), true)
	_check(game.valid and game.plan.mode == "noun", "noun scene valid")
	var room = game.word_room
	_cards_neutral(room, "noun")
	_check(room.answer_field.get_node("Feldname").text == "Namenwort", "field says Namenwort")
	_check(not is_instance_valid(room.picture), "no picture before the answer")
	_check(not game.bubble_text.text.contains("Fuchs"), "first view does not name the noun")
	game.tap_card(1)
	_check(game.confirm() == "wrong", "kleine is not the noun")
	_check(game.bubble_text.text.contains("Wiewort"), "noun: concrete help for an adjective")
	_check(game.feedback.text.is_empty(), "noun: old message hidden during help")
	await _idle(game)
	_check(game.events.has("article_glow:Der"), "noun hint: the article lights up")
	_check(room.halo_color(0) == room.HALO_HINT, "noun hint: article halo")
	_check(game.bubble_text.text.contains("Wer oder was?"), "noun hint asks Wer oder was?")
	_check(not is_instance_valid(room.picture), "no picture during the hint")
	_check(game.drop_card_on_field(3) == "wrong", "springt dropped is wrong")
	await _idle(game)
	_check(game.events.has("show_noun:Fuchs"), "noun full help shows the noun card")
	_check(not is_instance_valid(room.picture), "no picture before the child answers")
	game.tap_card(2)
	_check(game.confirm() == "correct", "Fuchs is the noun")
	await _idle(game)
	_check(is_instance_valid(room.picture), "hologram appears after the right choice")
	_check(game.events.has("picture:fuchs"), "fox hologram")
	_check(game.feedback.text.contains("der Fuchs"), "feedback names der Fuchs")
	_check(game.start_twin(), "noun twin starts")
	await _idle(game)
	_check(not is_instance_valid(room.picture), "twin starts without a picture")
	_check(game.plan.current().sentence == "Die Katze schläft.", "noun twin sentence")
	game.request_hint()
	await _idle(game)
	_check(game.bubble_text.text.contains("Wer oder was?"), "noun twin tip")
	game.tap_card(2)
	_check(game.confirm() == "wrong", "schläft is not the noun")
	_check(game.feedback.text.contains("Tunwort"), "noun: concrete help for a verb")
	game.tap_card(1)
	_check(game.confirm() == "correct", "Katze chosen independently")
	await _idle(game)
	_check(game.events.has("picture:katze"), "cat hologram")
	game.return_to_lesson()
	var holo: Dictionary = game.last_return.get("holo", {})
	_check(holo.get("mode") == "noun" and holo.get("originalAnswer") == "Fuchs", "noun result")
	_check(holo.get("twinSolved") == true, "noun twin result")
	await _close(game)


func _noun_validation() -> void:
	var broken: Array[Dictionary] = []
	var unknown_picture := FIXTURES.noun()
	unknown_picture.picture = "drache"
	broken.append(unknown_picture)
	var on_verb := FIXTURES.noun()
	on_verb.nounIndex = 3
	broken.append(on_verb)
	var missing := FIXTURES.noun()
	missing.erase("nounIndex")
	broken.append(missing)
	for index in range(broken.size()):
		_check(
			not plan_script.new().configure(broken[index]),
			"invalid noun payload %d rejected" % index
		)


func _order_flow() -> void:
	var game := await _open(FIXTURES.order(), true)
	_check(game.valid, "order scene valid")
	var shuffled: Array = game.plan.shuffled
	_check(shuffled != [0, 1, 2, 3], "cards are shuffled")
	_check(shuffled[0] != 0, "first word is not first on the tray")
	for word_index in [0, 2, 1, 3]:
		game.tap_card(word_index)
	_check(game.plan.built_sentence() == "Der Fuchs kleine springt.", "built wrong order")
	_check(game.confirm() == "wrong", "wrong order")
	_check(game.bubble_text.text.contains("Wer tut etwas?"), "order hint asks who does something")
	_check(not game.bubble_text.text.contains("Was tut"), "order hint is not the verb question")
	_check(game.feedback.text.is_empty(), "order: old message hidden during help")
	await _idle(game)
	_check(game.plan.hint_level == 1, "hint after wrong order")
	for word_index in [0, 2, 1, 3]:
		game.tap_card(word_index)
	_check(game.plan.placed.is_empty(), "tapping placed cards takes them back")
	game.request_hint()
	await _idle(game)
	_check(game.events.has("show_sentence"), "order full help lays the sentence")
	var laid := true
	for index in range(4):
		laid = (
			laid
			and game.word_room.cards[index].position.distance_to(game.word_room.slots[index]) < 0.01
		)
	_check(laid, "calm mode: the laid sentence stays visible")
	game.tap_card(0)
	var home_again := true
	for index in range(1, 4):
		home_again = (
			home_again and game.word_room.cards[index].position == game.word_room.home[index]
		)
	_check(home_again, "calm mode: the demo sentence goes back on the first tap")
	game.tap_card(0)
	for word_index in [0, 1, 2, 3]:
		game.tap_card(word_index)
	_check(game.plan.built_sentence() == "Der kleine Fuchs springt.", "rebuilt sentence")
	_check(game.confirm() == "correct", "sentence correct")
	await _idle(game)
	_check(game.start_twin(), "twin order")
	game.request_hint()
	await _idle(game)
	_check(game.bubble_text.text.contains("Wer tut etwas?"), "order twin tip fits Satzbau")
	_check(not game.bubble_text.text.contains("Was tut"), "order twin tip is not the verb question")
	for word_index in [0, 1, 2, 3]:
		game.tap_card(word_index)
	_check(game.confirm() == "correct", "Mia malt ein Bild.")
	await _close(game)


func _screen_rect(game: Node3D, box: AABB) -> Rect2:
	var rect := Rect2(game.camera.unproject_position(box.get_endpoint(0)), Vector2.ZERO)
	for corner in range(1, 8):
		rect = rect.expand(game.camera.unproject_position(box.get_endpoint(corner)))
	return rect


## Bildrechteck eines runden Körpers (Korb, Schale): Kreis unten und oben,
## statt der viel größeren Ecken seines Hüllquaders.
func _round_rect(game: Node3D, box: AABB) -> Rect2:
	var center := box.get_center()
	var radius := box.size.x * 0.5
	var rect := Rect2(game.camera.unproject_position(center), Vector2.ZERO)
	for step in range(32):
		var angle := TAU * step / 32.0
		for height in [box.position.y, box.end.y]:
			var point := Vector3(
				center.x + cos(angle) * radius, height, center.z + sin(angle) * radius
			)
			rect = rect.expand(game.camera.unproject_position(point))
	return rect


func _fox_box(game: Node3D) -> AABB:
	var ground: Vector3 = game._fox_ground()
	return AABB(ground + Vector3(-0.45, 0, -0.35), Vector3(0.9, game.FOX_HEIGHT, 0.7))


## Nichts überdeckt das Zwanzigerfeld: Korb, Schale (mit Äpfeln) und Lumo
## liegen im Bild außerhalb des Felds; die zweite Gruppe überlappt nicht.
func _stage_free(game: Node3D, name_value: String) -> void:
	var room = game.math_room
	var frame_rect := _screen_rect(game, room.frame_box()).grow(-2.0)
	var basket_box: AABB = room.basket_box()
	var plate_box: AABB = room.plate_box()
	var covers := [
		["basket", basket_box],
		["handle", room.handle_box()],
		["plate", plate_box],
		["Lumo", _fox_box(game)]
	]
	for group in range(2):
		if room.badges[group].visible:
			var badge: Vector3 = room.badges[group].position
			covers.append(
				["badge%d" % group, AABB(badge - Vector3(0.9, 0.3, 0), Vector3(1.8, 0.6, 0))]
			)
	for entry in covers:
		var covered := (
			_round_rect(game, entry[1])
			if entry[0] in ["basket", "plate"]
			else _screen_rect(game, entry[1])
		)
		if covered.intersects(frame_rect):
			print("[HoloLesson] overlap %s %s frame=%s" % [entry[0], covered, frame_rect])
		_check(
			not covered.intersects(frame_rect),
			name_value + " %s does not cover the ten frame" % entry[0]
		)
	_check(
		not _screen_rect(game, _fox_box(game)).intersects(_screen_rect(game, basket_box)),
		name_value + " Lumo does not cover the basket"
	)
	var a: int = room.a
	for first in range(a, room.apples.size()):
		for second in range(first + 1, room.apples.size()):
			var gap: float = room.apples[first].position.distance_to(room.apples[second].position)
			_check(
				gap >= 0.64, name_value + " second group apart %d/%d %.2f" % [first, second, gap]
			)


func _low_profile() -> void:
	var manager = root.get_node("PerformanceManager")
	var before = manager.current_profile
	manager.current_profile = manager.Profile.LOW
	var game := await _open(FIXTURES.math(), false)
	_check(game.low_effects, "LOW profile reduces effects")
	var environment: WorldEnvironment = game.find_children("*", "WorldEnvironment", true, false)[0]
	_check(not environment.environment.glow_enabled, "LOW: no glow")
	_check(not game.wonder.visible, "LOW: no celebration particles")
	_check(game.math_room.apples.size() == 13, "LOW: same 8 + 5 apples")
	_check(game.choice_buttons.size() == 4, "LOW: same answers")
	await _idle(game)
	game.choose("12")
	await _idle(game)
	game.choose("14")
	await _idle(game)
	_check(game.events.has("ten_complete"), "LOW: same ten-frame help")
	_check(game.events.has("borrowed:2"), "LOW: same borrowed apples with paths")
	_check(not game._key_light.shadow_enabled, "LOW: no realtime shadows")
	_check(game.choose("13") == "correct", "LOW: same solution")
	await _close(game)
	# Deutsch im LOW-Profil: gleiche Hilfen, gleiches Bild, ruhiges Hologramm.
	game = await _open(FIXTURES.noun(), false)
	_check(game.low_effects and not game.wonder.visible, "LOW noun: no particles")
	game.tap_card(1)
	game.confirm()
	await _idle(game)
	_check(game.events.has("article_glow:Der"), "LOW noun: same article hint")
	game.tap_card(2)
	_check(game.confirm() == "correct", "LOW noun: same solution")
	await _idle(game)
	_check(game.events.has("picture:fuchs"), "LOW noun: same picture")
	var figure: Node3D = game.word_room.picture.get_node("Figur")
	var part: MeshInstance3D = figure.get_child(0)
	_check(
		part.material_override.get_shader_parameter("lines") == 0.0, "LOW noun: calm hologram lines"
	)
	await _close(game)
	manager.current_profile = before
	# Profilwechsel während des Raums wirkt sofort.
	game = await _open(FIXTURES.math(), false)
	var full: bool = not game.low_effects
	manager.set_profile(manager.Profile.LOW, false)
	_check(full and game.low_effects, "switch to LOW applies at once")
	_check(not game._environment.glow_enabled, "switch to LOW: glow off")
	manager.set_profile(before, false)
	_check(not game.low_effects and game._environment.glow_enabled, "switch back restores effects")
	await _close(game)


func _rects_overlap(first: Rect2, second: Rect2) -> bool:
	return first.grow(-1.0).intersects(second.grow(-1.0))


## Lage der Bedienfelder prüfen (im Bild, keine Überlappung, Touch-Ziele).
func _panels_ok(game: Node3D, name_value: String, size_value: Vector2i) -> Array[Rect2]:
	var view := Rect2(Vector2.ZERO, Vector2(size_value))
	var panels: Array[Rect2] = []
	for panel: Control in [game.header, game.bubble, game.footer, game.note_panel]:
		if not panel.is_visible_in_tree():
			continue
		var rect := panel.get_global_rect()
		if not view.encloses(rect):
			print("[HoloLesson] outside %s %s %s" % [name_value, panel.name, rect])
		_check(view.encloses(rect), name_value + " panel inside screen " + panel.name)
		for other in panels:
			_check(not _rects_overlap(other, rect), name_value + " panels free " + panel.name)
		panels.append(rect)
	for button: Button in game.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			var height: float = button.size.y * game.ui.scale.y
			_check(height >= 126.0, name_value + " touch target %s %.0f px" % [button.text, height])
	for panel_rect in panels:
		_check(not _rects_overlap(game.free_rect, panel_rect), name_value + " 3D area free")
	return panels


func _layouts() -> void:
	for size_value in [Vector2i(1080, 2340), Vector2i(2340, 1080), Vector2i(1812, 2176)]:
		for fixture in [FIXTURES.math(), FIXTURES.verb(), FIXTURES.order(), FIXTURES.noun()]:
			var game := await _open(fixture, true, size_value)
			await _frames(4)
			var name_value := (
				"%s %dx%d"
				% [fixture.kind + str(fixture.get("mode", "")), size_value.x, size_value.y]
			)
			_panels_ok(game, name_value + " start", size_value)
			var free: Rect2 = game.free_rect
			var objects: Array[Node3D] = []
			if fixture.kind == "holo_word_problem":
				objects.assign(game.math_room.apples)
			else:
				objects.assign(game.word_room.cards)
			for node in objects:
				var point: Vector2 = game.camera.unproject_position(node.global_position)
				_check(
					free.grow(4).has_point(point),
					name_value + " object in the free area " + node.name
				)
			if fixture.kind == "holo_word_problem":
				_stage_free(game, name_value + " start")
				game.choose("12")
				await _idle(game)
				_panels_ok(game, name_value + " hint", size_value)
				_same_stage(game, free, name_value + " hint")
				game.choose("14")
				await _idle(game)
				_panels_ok(game, name_value + " full help", size_value)
				_same_stage(game, free, name_value + " full help")
				_stage_free(game, name_value + " after full help")
				_check(game.math_room.ten_outline.visible, name_value + " one ten outlined")
				for index in range(game.math_room.apples.size()):
					var radius: float = maxf(
						game.math_room.screen_radius(game.camera, index), 126.0 * 0.5
					)
					_check(radius * 2.0 >= 126.0, name_value + " apple target")
				game.choose("13")
				await _idle(game)
				_same_stage(game, free, name_value + " solved")
			else:
				for index in range(game.word_room.cards.size()):
					var rect: Rect2 = game.word_room.card_rect(game.camera, index)
					_check(
						rect.size.y >= 60.0, name_value + " card readable height %.0f" % rect.size.y
					)
				_lumo_beside_cards(game, name_value + " start")
				await _wrong_sentence(game)
				await _idle(game)
				_panels_ok(game, name_value + " hint", size_value)
				_same_stage(game, free, name_value + " hint")
				_lumo_beside_cards(game, name_value + " hint")
				game.request_hint()
				await _idle(game)
				_same_stage(game, free, name_value + " full help")
			print(
				(
					"[HoloLesson] layout %s free=%s cam=%s"
					% [name_value, game.free_rect, game.camera.global_position]
				)
			)
			await _close(game)


## Eine falsche Antwort je Deutsch-Variante (löst die erste Hilfe aus).
func _wrong_sentence(game: Node3D) -> void:
	if game.plan.mode == "order":
		for index in game.plan.shuffled:
			game.tap_card(index)
	else:
		game.tap_card(1)
	game.confirm()
	await process_frame


## Die 3D-Fläche bleibt gleich groß, egal wie lang Lumos Text oder die
## Rückmeldung ist (Hoch- und Querformat).
func _same_stage(game: Node3D, before: Rect2, name_value: String) -> void:
	var now: Rect2 = game.free_rect
	var same := (
		absf(now.position.y - before.position.y) < 1.5 and absf(now.size.y - before.size.y) < 1.5
	)
	if not same:
		print(
			(
				"[HoloLesson] stage moved %s: %s -> %s lines=%d text=%s"
				% [
					name_value,
					before,
					now,
					game.bubble_text.get_line_count(),
					game.bubble_text.text
				]
			)
		)
	_check(same, name_value + " 3D area keeps its size")


## Lumo steht seitlich: Er verdeckt keine Wortkarte und kein Antwortfeld.
func _lumo_beside_cards(game: Node3D, name_value: String) -> void:
	var fox := _screen_rect(game, _fox_box(game))
	for index in range(game.word_room.cards.size()):
		var card: Rect2 = game.word_room.card_rect(game.camera, index)
		_check(not fox.intersects(card.grow(-2.0)), name_value + " Lumo beside card %d" % index)
	var room = game.word_room
	if room.mode == "order":
		for slot in range(room.slots.size()):
			var point: Vector2 = game.camera.unproject_position(room.slots[slot])
			_check(not fox.has_point(point), name_value + " Lumo beside slot %d" % slot)
	elif is_instance_valid(room.answer_field):
		var field: Vector2 = game.camera.unproject_position(room.answer_field.global_position)
		_check(not fox.has_point(field), name_value + " Lumo beside the answer field")
