extends SceneTree
## Abenteuer-Parcours in der echten Szene (kart_parcours.tscn): Weltwahl zeigt nur spielbare
## Welten, Bot fährt Start bis Ziel mit dem echten Kart, Ergebnis geht genau einmal an den
## Host, Pause/Weiter/Zurück, Speichern und Fortsetzen, Fortschritt je Kind getrennt.

const STEP: float = 1.0 / 60.0
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[ParcoursScene] FAIL: " + text)


func _open(options: Dictionary) -> Node:
	var router = root.get_node("SceneRouter")
	router.launch_options = options
	var game: Node = load("res://scenes/games/kart_parcours.tscn").instantiate()
	root.add_child(game)
	for i in range(3):
		await process_frame
	# Der Test treibt die Physik selbst (feste Schritte, keine Doppelschritte).
	game.set_physics_process(false)
	return game


func _drive_to_finish(game: Node, world_id: String) -> Dictionary:
	var bot = load("res://scripts/games/parcours/parcours_bot.gd").new(5, 0.3, 0.12)
	game.countdown = 0.0
	var frames: int = 0
	var rewards: Array = []
	var bridge = root.get_node("HostBridge")
	var listener := func(payload: Dictionary): rewards.append(payload)
	bridge.reward_reported.connect(listener)
	while not game.finished and frames < 60 * 400:
		var run = game.run
		if run.on_foot:
			var f: Dictionary = bot.foot_input(run)
			if bool(f.jump):
				game.jump_pressed(true)
			if bool(f.lever) or run.can_enter_kart():
				game.context_action()
				if not run.on_foot:
					bot.foot_target = 0
			game.step_game(STEP, 0.0, 0.0, false, f.move)
			if bool(f.jump):
				game.jump_pressed(false)
		else:
			if run.can_leave_kart():
				game.context_action()
			var input: Dictionary = bot.drive_input(run, STEP)
			game.step_game(STEP, float(input.axis), float(input.brake), true, Vector2.ZERO)
		frames += 1
		if frames % 600 == 0:
			await process_frame
	# Nach dem Ziel weiterlaufen lassen: es darf nichts ein zweites Mal gebucht werden.
	for i in range(120):
		game._physics_process(STEP)
	game.retry_reward()
	bridge.reward_reported.disconnect(listener)
	return {"rewards": rewards, "frames": frames, "world": world_id}


func _run() -> void:
	var worlds = load("res://scripts/games/parcours/parcours_worlds.gd")
	var progress_script = load("res://scripts/games/parcours/parcours_progress.gd")
	for child in ["parcours_kind_a", "parcours_kind_b"]:
		DirAccess.remove_absolute(progress_script.path_for(child))
		DirAccess.remove_absolute(progress_script.session_path_for(child))
	# 1) Weltwahl: nur spielbare Welten als Karten, Zurück zum Kart-Menü vorhanden.
	var game: Node = await _open({"childKey": "parcours_kind_a"})
	var cards: Node = game.hud.choice.find_child("WorldCards", true, false)
	_check(cards != null and cards.get_child_count() == worlds.playable_ids().size(), "Weltwahl zeigt genau die spielbaren Welten")
	_check(game.hud.choice.find_child("BackToKartMenu", true, false) != null, "Weltwahl hat Zurück zum Kart-Menü")
	_check(game.hud.choice.find_child("ResumeSaved", true, false) == null, "Kein Weiterfahren ohne Spielstand")
	for world_id in worlds.playable_ids():
		# 2) Welt starten über die echte Karte.
		var card: Button = cards.get_node("World_" + world_id)
		card.pressed.emit()
		await process_frame
		_check(game.playing and game.world_id == world_id, "%s startet aus der Weltwahl" % world_id)
		_check(game.kart is LumoRaceKart, "%s: echtes Kart-Fahrzeug" % world_id)
		_check(game.lumo.uses_original, "%s: Lumo zu Fuß ist das geriggte Original" % world_id)
		# 3) Pause und weiter: Zeit steht still.
		game.countdown = 0.0
		for i in range(30):
			game._physics_process(STEP)
		var before: float = game.run.elapsed
		game.handle_back()
		_check(game.paused and game.hud.modal.visible, "%s: Zurück pausiert" % world_id)
		for i in range(30):
			game._physics_process(STEP)
		_check(is_equal_approx(game.run.elapsed, before), "%s: Pause hält die Zeit an" % world_id)
		game.handle_back()
		_check(not game.paused and not game.hud.modal.visible, "%s: Zurück in der Pause fährt weiter" % world_id)
		# 4) Speichern und fortsetzen am Checkpoint.
		game.run.checkpoint = 1
		game.run.reached[1] = true
		game.run.stars_taken[0] = true
		game.pause_game()
		var saved: Dictionary = game.progress.load_session()
		_check(int(saved.get("checkpoint", -1)) == 1 and (saved.stars as Array).has(0), "%s: Spielstand gespeichert" % world_id)
		game.leave_to_choice()
		await process_frame
		_check(game.hud.choice.find_child("ResumeSaved", true, false) != null, "%s: Weltwahl bietet Weiterfahren" % world_id)
		var saved_id: String = str(saved.result_id)
		game.continue_saved()
		await process_frame
		_check(game.run.checkpoint == 1 and game.run.stars_taken.has(0), "%s: Fortsetzen am Checkpoint mit Sternen" % world_id)
		_check(game.result_id == saved_id, "%s: Fortsetzen behält die Ergebnis-ID" % world_id)
		# 5) Neu starten und bis ins Ziel fahren.
		game.restart_world()
		await process_frame
		var stars_before: int = root.get_node("ProgressStore").total_stars()
		var booked_before: int = game.rewards_booked
		var outcome: Dictionary = await _drive_to_finish(game, world_id)
		_check(game.finished, "%s: Szene fährt bis ins Ziel" % world_id)
		_check((outcome.rewards as Array).size() == 1, "%s: Ergebnis genau einmal an den Host (%d)" % [world_id, (outcome.rewards as Array).size()])
		_check(game.rewards_booked == booked_before + 1, "%s: Belohnung genau einmal gebucht" % world_id)
		_check(root.get_node("ProgressStore").total_stars() == stars_before + 3, "%s: 3 Sterne gutgeschrieben" % world_id)
		var payload: Dictionary = game.result_payload
		_check(str(payload.game) == "kart" and str(payload.mode) == "parcours" and int(payload.solved) == 0, "%s: Ergebnisvertrag" % world_id)
		_check(game.hud.modal.visible and game.hud.modal_column.find_child("Again", true, false) != null, "%s: Ergebnisfenster" % world_id)
		_check(game.progress.load_session().is_empty(), "%s: Spielstand nach dem Ziel gelöscht" % world_id)
		_check(int(game.progress.world(world_id).completed) == 1, "%s: Fortschritt für Kind A" % world_id)
		game.show_world_choice()
		await process_frame
		cards = game.hud.choice.find_child("WorldCards", true, false)
	game.queue_free()
	await process_frame
	# 6) Anderes Kind: eigener Fortschritt, kein fremder Spielstand.
	var other: Node = await _open({"childKey": "parcours_kind_b"})
	for world_id in worlds.playable_ids():
		_check(int(other.progress.world(world_id).completed) == 0, "%s: Kind B hat eigenen Fortschritt" % world_id)
	_check(other.hud.choice.find_child("ResumeSaved", true, false) == null, "Kind B sieht keinen fremden Spielstand")
	other.queue_free()
	await process_frame
	if root.has_node("GameSoundscape"):
		root.get_node("GameSoundscape").release_audio()
	await create_timer(0.4).timeout
	if failures == 0:
		print("[ParcoursScene] PASS: %d Prüfungen" % checks)
	else:
		print("[ParcoursScene] FAIL: %d von %d Prüfungen" % [failures, checks])
	quit(1 if failures > 0 else 0)
