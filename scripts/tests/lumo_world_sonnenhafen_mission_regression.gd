extends SceneTree
## All five Sonnenhafen missions in the production World, played through the
## real action button, dialog buttons, crates, shop, delivery board and the
## learning round. The learning round is verified twice: the in-world fallback
## (standalone) and the app bridge receipt delivered on World re-entry.
## Resident positions are live; Lumo is placed next to them as a fixture.
const PROFILE := "lumo_c12_sonnenhafen_missions"
const TALK := 3.4
var checks := 0
var failures: Array[String] = []
var scene: Node
var harbour: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("[SonnenhafenMissions] " + label)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _world_path() -> String:
	return "user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json"


func _enter(extra: Dictionary = {}) -> bool:
	var router: Node = root.get_node("SceneRouter")
	var options := {"childKey": PROFILE, "grade": 2, "reduceAnimations": true}
	options.merge(extra, true)
	router.launch_options = options
	router.goto("world")
	await _frames(40)
	scene = current_scene
	if not is_instance_valid(scene) or scene.name != "LumoWorld":
		return false
	harbour = scene.sonnenhafen
	return harbour != null and harbour.unlocked()


func _place(at: Vector3) -> void:
	if scene.paused:
		scene._close_dialog()
	scene.joystick.axis = Vector2.ZERO
	scene.joystick.target = Vector2.ZERO
	scene.player.velocity = Vector3.ZERO
	scene.player.position = Vector3(at.x, 0.1, at.z)
	scene.last_safe = scene.player.position
	await _frames(3)


func _press_action() -> void:
	scene.action_button.pressed.emit()
	await _frames(2)


func _button(label: String) -> Button:
	for node in scene.modal_box.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == label or button.name == label:
			return button
	return null


func _press(label: String) -> bool:
	var button := _button(label)
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	await _frames(2)
	return true


func _close_popups() -> void:
	if scene.paused:
		scene._close_dialog()
	await _frames(1)


## Stand next to a live resident and talk to it with the real action button.
func _talk(id: String, harbour_dialog := true) -> bool:
	for attempt in range(12):
		await _close_popups()
		var at: Vector3 = harbour.crowd.position_of(id)
		for offset in [
			Vector3(1.4, 0, 0), Vector3(-1.4, 0, 0), Vector3(0, 0, 1.4), Vector3(0, 0, -1.4)
		]:
			var spot: Vector3 = at + offset
			if not harbour.layout.is_walkable(Vector2(spot.x, spot.z)):
				continue
			await _place(spot)
			if harbour.crowd.nearest(scene.player.position, TALK) != id:
				continue
			if scene.action_button.text != "Ansprechen":
				continue
			await _press_action()
			if scene.paused and (scene.modal.has_meta("sonnenhafen_dialog") or not harbour_dialog):
				return true
		await _frames(20)
	return false


func _run() -> void:
	DirAccess.remove_absolute(_world_path())
	root.size = Vector2i(1080, 2340)
	_check(await _enter(), "production World with Sonnenhafen opens")
	if harbour == null:
		_finish()
		return
	var model = harbour.model
	_check(
		model.ready() and model.mission_ids().size() == 5, "five Sonnenhafen missions are loaded"
	)
	_check(harbour.wallet == harbour.START_SHELLS, "new profile starts with the small shell purse")

	# --- 1 Willkommen in Sonnenhafen -------------------------------------------
	_check(await _talk("ida"), "talk to Ida with the action button")
	_check(
		await _press("Ja, gern!") and await _press("Ich gehe los"), "Ida's welcome dialog completes"
	)
	_check(model.state("hafen_willkommen") == "active", "welcome mission is active")
	await _close_popups()
	await _place(Vector3(200, 0, -158))
	await _frames(20)
	_check(
		str(model.current_step("hafen_willkommen").id) == "see_lighthouse",
		"visiting the market advances the mission"
	)
	await _place(Vector3(258, 0, -209))
	await _frames(20)
	_check(
		str(model.current_step("hafen_willkommen").id) == "back_to_ida",
		"visiting the lighthouse advances the mission"
	)
	_check(await _talk("ida"), "return to Ida")
	_check(
		await _press("Der Leuchtturm war toll!") and await _press("Danke, Ida!"),
		"Ida's closing dialog completes"
	)
	_check(model.state("hafen_willkommen") == "done", "welcome mission done")
	_check("card_ida" in model.cards(), "Ida's figure card was earned")
	_check(harbour.wallet == 14, "welcome gift of ten shells (14)")
	_check(harbour.crowd.brain_of("ida").knows("helped"), "Ida remembers that Lumo helped")

	# --- 2 Frischer Fang ----------------------------------------------------------
	_check(await _talk("jonte"), "talk to Jonte")
	_check(
		await _press("Klar helfe ich!") and await _press("Los geht's"), "Jonte's request completes"
	)
	for crate in range(3):
		await _close_popups()
		await _place(harbour.layout.spot("pier_west_end"))
		_check(
			scene.action_button.text == "Kiste nehmen",
			"crate %d can be taken at the pier" % (crate + 1)
		)
		await _press_action()
		_check(
			str(harbour.carrying.get("kind", "")) == "fish", "Lumo carries crate %d" % (crate + 1)
		)
		await _place(harbour.layout.spot("fish_hall"))
		_check(
			scene.action_button.text == "Kiste abstellen",
			"crate %d can be set down in the hall" % (crate + 1)
		)
		await _press_action()
	_check(
		harbour.fish_crates == 3 and harbour.carrying.is_empty(),
		"three crates are in the fish hall"
	)
	_check(
		str(model.current_step("frischer_fang").id) == "tell_frieda",
		"carrying the crates completes the event step"
	)
	_check(await _talk("frieda"), "talk to Frieda")
	_check(
		await _press("Alle drei Kisten sind da.") and await _press("Ich sage es ihm"),
		"Frieda's dialog completes"
	)
	_check(await _talk("jonte"), "return to Jonte")
	_check(
		await _press("Gern geschehen.") and await _press("Danke, Jonte!"), "Jonte's thanks complete"
	)
	_check(model.state("frischer_fang") == "done", "fish mission done")
	_check(
		int(harbour.inventory.get("fisch", 0)) == 2 and harbour.wallet == 22,
		"reward: two fish and eight shells"
	)

	# --- 3 Waren berechnen (learning) --------------------------------------------
	_check(await _talk("greta"), "talk to Greta")
	_check(
		await _press("Ich rechne gern mit!") and await _press("Abgemacht!"),
		"Greta's learning request completes"
	)
	_check(
		str(model.current_step("waren_berechnen").id) == "world_school",
		"learning round is the current step"
	)
	_check(await _talk("greta"), "talk to Greta again")
	_check(_button("HarbourLesson") != null, "Greta offers the learning round in Lumos Weltschule")
	_check(await _press("HarbourLesson"), "learning round starts")
	var request: Dictionary = harbour.pending_lesson.duplicate(true)
	_check(
		str(request.get("id", "")) == "school_numbers" and int(request.get("grade", 0)) == 2,
		"request uses the existing learning bridge format"
	)
	scene._close_dialog()
	_check(scene._save(), "pending learning request is saved before leaving")
	# The app returns with a receipt: World re-entry must route it to Sonnenhafen.
	var wrong := {
		"version": 1,
		"requestId": "harbour_wrong_request",
		"missionId": "school_numbers",
		"completed": true,
		"subject": "Mathematik",
		"grade": 2,
		"returnGame": "world"
	}
	_check(
		not harbour.consume_learning_receipt(wrong), "a receipt with another request id is rejected"
	)
	var receipt := {
		"version": 1,
		"requestId": str(request.requestId),
		"missionId": "school_numbers",
		"completed": true,
		"subject": "Mathematik",
		"grade": 2,
		"returnGame": "world"
	}
	_check(
		await _enter({"worldLearningReceipt": receipt}), "World reopens with the learning receipt"
	)
	model = harbour.model
	_check(
		str(model.current_step("waren_berechnen").id) == "calculate",
		"the returning receipt completes the learning step"
	)
	_check(harbour.pending_lesson.is_empty(), "the request is consumed exactly once")
	_check(await _talk("greta"), "talk to Greta for the price calculation")
	_check(await _press("Zeig mir die Bestellung"), "the order is shown")
	_check(
		await _press("20") and await _press("Noch einmal rechnen"),
		"a wrong total opens help and a retry"
	)
	_check(model.state("waren_berechnen") == "active", "a wrong answer does not finish the mission")
	_check(await _press("24"), "the correct grade-2 total completes")
	_check(
		model.state("waren_berechnen") == "done" and "card_greta" in model.cards(),
		"learning mission done with Greta's card"
	)
	_check(harbour.wallet == 34, "learning reward twelve shells (34)")

	# --- 4 Licht für den Leuchtturm (trade) -------------------------------------
	_check(await _talk("ole"), "talk to Ole")
	_check(
		await _press("Kann ich helfen?") and await _press("Ich kaufe das Glas"),
		"Ole's request completes"
	)
	await _close_popups()
	var shop_open := false
	for wait in range(40):
		if harbour._shop_open():
			shop_open = true
			break
		await _frames(30)
	_check(shop_open, "Greta is in her shop")
	var room: Dictionary = harbour.layout.data.interiors.hafenkraemer
	await _place(Vector3(float(room.trade_spot[0]), 0, float(room.trade_spot[1])))
	_check(harbour.inside == "hafenkraemer", "Lumo is inside the shop (roof cut away)")
	_check(scene.action_button.text in ["Handeln", "Ansprechen"], "shop action is offered")
	harbour.open_shop()
	await _frames(2)
	_check(await _press("Buy_laternenglas"), "buy the lantern glass with the real shop button")
	_check(
		harbour.wallet == 28 and int(harbour.inventory.get("laternenglas", 0)) == 1,
		"trade: 34 − 6 = 28 shells and one glass"
	)
	_check(
		str(model.current_step("licht_leuchtturm").id) == "bring_glass",
		"buying completes the event step"
	)
	_check(await _press("Sell_laternenglas"), "the glass can be sold again")
	_check(
		harbour.wallet == 31 and int(harbour.inventory.get("laternenglas", 0)) == 0,
		"selling: 28 + 3 = 31 shells"
	)
	await _close_popups()
	_check(await _talk("ole", false), "talking to Ole without glass")
	_check(
		(
			not scene.modal.has_meta("sonnenhafen_dialog")
			and model.state("licht_leuchtturm") == "active"
		),
		"Ole asks for the glass first; nothing completes"
	)
	await _close_popups()
	await _place(Vector3(float(room.trade_spot[0]), 0, float(room.trade_spot[1])))
	harbour.open_shop()
	await _frames(2)
	_check(await _press("Buy_laternenglas"), "buy the glass again")
	_check(await _press("Sell_fisch"), "sell one fish")
	_check(
		harbour.wallet == 27 and int(harbour.inventory.get("fisch", 0)) == 1,
		"31 − 6 + 2 = 27 shells, one fish left"
	)
	await _close_popups()
	_check(await _talk("ole"), "bring the glass to Ole")
	_check(
		await _press("Wie weit sieht man das Licht?") and await _press("Gern geschehen, Ole!"),
		"Ole's thanks complete"
	)
	_check(
		(
			model.state("licht_leuchtturm") == "done"
			and int(harbour.inventory.get("laternenglas", 0)) == 0
		),
		"glass handed over, mission done"
	)
	_check(
		int(harbour.inventory.get("abzeichen", 0)) == 1 and harbour.wallet == 35,
		"reward: badge and eight shells"
	)

	# --- 5 Die erste Lieferung (reading + delivery) -------------------------------
	_check(await _talk("hinnerk"), "talk to Hinnerk")
	_check(
		await _press("Was soll ich tun?") and await _press("Ich nehme einen Auftrag"),
		"Hinnerk explains the board"
	)
	await _close_popups()
	await _place(harbour.layout.spot("kontor_board"))
	_check(scene.action_button.text == "Lieferbrett", "delivery board is offered in the Kontor")
	await _press_action()
	_check(await _press("TakeOrder_0"), "take the first order")
	var order: Dictionary = harbour.ORDERS[harbour._order_index()]
	_check(str(harbour.carrying.get("kind", "")) == "delivery", "Lumo carries the delivery crate")
	var wrong_person := "hinnerk" if str(order.to) != "hinnerk" else "kalle"
	_check(await _talk(wrong_person), "talk to someone else first")
	var hint_found := false
	for node in scene.modal_box.find_children("*", "Label", true, false):
		hint_found = hint_found or (node as Label).text.contains("Lieferzettel")
	_check(
		hint_found and _button("HarbourHandOver") == null,
		"the wrong person asks to read the slip again"
	)
	await _close_popups()
	_check(await _talk(str(order.to)), "talk to the addressee " + str(order.to))
	var before: int = harbour.wallet
	_check(await _press("HarbourHandOver"), "hand over the delivery")
	_check(
		harbour.carrying.is_empty() and harbour.wallet == before + int(order.reward),
		"delivery pays its reward"
	)
	_check(
		harbour.crowd.brain_of(str(order.to)).knows("delivered"),
		"the addressee remembers the delivery"
	)
	_check(
		str(model.current_step("erste_lieferung").id) == "report",
		"delivery completes the event step"
	)
	await _close_popups()
	_check(await _talk("hinnerk"), "report to Hinnerk")
	_check(
		await _press("Gibt es noch mehr Aufträge?") and await _press("Danke, Hinnerk!"),
		"Hinnerk's thanks complete"
	)
	var all_done := true
	for mission_id in model.mission_ids():
		all_done = all_done and model.state(mission_id) == "done"
	_check(all_done, "all five Sonnenhafen missions are done")
	_check(model.cards().size() == 5, "five Sonnenhafen figure cards")
	_check(harbour.rewarded.size() == 5, "every mission rewarded exactly once")

	# --- Journal and map ---------------------------------------------------------------
	await _close_popups()
	scene._open_journal_from_dialog()
	await _frames(2)
	var journal: Node = scene.modal_box.find_child("SonnenhafenJournal", true, false)
	_check(journal != null, "the journal lists the Sonnenhafen missions")
	_check(
		(
			journal != null
			and journal.find_children("HarbourCard_*", "PanelContainer", true, false).size() == 5
		),
		"the journal shows five harbour cards"
	)
	await _close_popups()
	scene._map_dialog()
	await _frames(2)
	_check(scene.overview.region_figures.size() == 14, "the world map shows the fourteen residents")
	_check(scene.overview.world_figures.size() == 9, "chapter-two figures stay separate on the map")
	await _close_popups()

	# --- Persistence ------------------------------------------------------------------
	await _close_popups()
	_check(scene._save(), "World saves the region")
	var saved: Dictionary = harbour.to_data()
	_check(await _enter(), "World reopens")
	_check(
		harbour.to_data().quests == saved.quests and harbour.wallet == saved.wallet,
		"missions and purse survive re-entry"
	)
	_check(harbour.crowd.brain_of("ida").knows("helped"), "resident memory survives re-entry")
	_finish()


func _finish() -> void:
	print(
		"[SonnenhafenMissions] %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks]
	)
	for failure in failures:
		print("  FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
