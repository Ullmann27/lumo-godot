extends SceneTree
const DROP = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const BOARD := "res://scenes/games/kart_island.tscn"
const DT := 1.0/60.0
var errors: Array[String] = []
var checks := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		errors.append(detail)
		push_error(detail)


func run() -> void:
	var game = load(BOARD).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.lightweight = true
	game._show_reference_landing()
	await process_frame
	var menu = game.reference_landing
	menu._open_overlay("race")
	menu.find_child("Mode_arena", true, false).pressed.emit()
	var start: Button = menu.find_child("ArenaTrefferjagd", true, false)
	check(start.is_visible_in_tree(), "Echter Arena-Einstieg bietet beide Spielarten")
	start.pressed.emit()
	await process_frame
	check(game.mode == "arena" and is_instance_valid(game.battle) and game.gems.size() == 6, "Sechs Ladebuchten")
	game.countdown = 0.0
	game.racing = true
	var battle = game.battle
	var rivals: Array = game.opponents
	for i in rivals.size():
		rivals[i].position = Vector3(30.0 - i, 0.035, 18)
	game.player.position = Vector3(0,0.035,6)
	game.player.rotation.y = 0
	rivals[0].position = Vector3(0,0.035,-3)
	game.item_button.pressed.emit()
	check(battle.shots.size() == 1 and game.item == "", "Gegenstand über den Rennknopf abfeuern")
	if not battle.shots.is_empty():
		for f in 25:
			if battle._advance_shot(game, battle.shots[0], DT):
				break
	check(game.arena_scores == 1 and game.opponent_shield_times[0] > 2.9, "Raketenberührung, Punkt und Respawnschutz")
	var safe_spawn: Vector3 = rivals[0].position
	battle._hit(game, 0, 1)
	check(game.arena_scores == 1 and rivals[0].position == safe_spawn, "Schutz verhindert Doppelpunkte")
	for s in battle.shots:
		s.node.queue_free()
	battle.shots.clear()
	game.opponent_shield_times[0] = 0
	game.player.position = Vector3(16, 0.035, 5)
	rivals[0].position = Vector3(16, 0.035, -5)
	game.item = "star_rocket"
	game.item_charges = 1
	game._use_item()
	for f in 30:
		if battle._advance_shot(game, battle.shots[0], DT):
			break
	check(game.arena_scores == 1, "Pfeiler fängt die Rakete")
	battle.shots[0].node.queue_free()
	battle.shots.clear()
	game.player.position = game.gems[1].position - Vector3.UP * 0.9
	battle.tick(game, DT)
	check(game.item == "fire_meteor", "Orange Bucht lädt den Meteor")
	game._use_item()
	check(battle.shots.size() >= 1 and battle.shots.back().has("warning"), "Einschlagkreis zeigt das Ziel")
	var meteor: Dictionary = battle.shots.back()
	for i in rivals.size():
		rivals[i].position = meteor.aim + Vector3.RIGHT * (8 + i)
	battle._advance_shot(game, meteor, 1.3)
	check(game.arena_scores == 1, "Verlassen des Zielkreises verhindert Treffer")
	meteor.age = 0.0
	meteor.aim = rivals[0].position
	battle._advance_shot(game, meteor, 1.3)
	check(game.arena_scores >= 2, "Meteor wertet tatsächliche Einschlagposition")
	game._save_session()
	var before: Array = battle.save_shots()
	check(not before.is_empty() and not before[0].has("node"), "Laufende Projektile sind speicherbar")
	var sample: String = OS.get_environment("LUMO_ARENA_BATTLE_SHOT")
	for frame in 3800:
		if not game.item.is_empty() and frame % 90 == 0:
			game.item_button.pressed.emit()
		game.steering = sin(float(frame) * 0.013) * 0.6
		game._physics_process(DT)
		if frame == 420 and not sample.is_empty():
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(sample)
		if game.finished:
			break
	var rival_points := 0
	for score in game.opponent_scores:
		rival_points += score
	check(rival_points > 0, "KI sammelt und erzielt eigene Treffer")
	check(game.finished and game.result_payload.get("arenaRule") == "battle" and game.elapsed >= 60 and game.elapsed < 61, "60-Sekunden-Ergebnis")
	check(game.result_payload.get("hits") == game.arena_scores, "Treffer im Endergebnis")
	print("[Arena] Punkte Lumo=",game.arena_scores," Gegner=",game.opponent_scores)
	game._start_selected_race({"mode":"arena","track":"sonnenhafen","driver":"fox","kart":"comet"})
	check(not is_instance_valid(game.battle) and game.gems.size() == 30 and game.arena_time_limit() == 90.0, "Klassische Arena")
	check(await DROP.release_scene(self,game,"[ArenaBattle]"), "Freigabe")
	print("ARENA_BATTLE_%s checks=%d failures=%d" % ["PASS" if errors.is_empty() else "FAIL", checks, errors.size()])
	quit(0 if errors.is_empty() else 1)
