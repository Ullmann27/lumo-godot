extends SceneTree
## Existing Borin/Yuki art must be selectable, persisted and used by the real race.

const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const SCENE := "res://scenes/games/kart_island.tscn"
const EXTRA := {
	"badger": "Borin",
	"cat": "Yuki",
	"lion": "Löwe",
	"owl": "Eule",
	"squirrel": "Eichhörnchen",
	"turtle": "Schildkröte",
}
const SESSION := "user://kart_sonnenhafen_session.cfg"
var checks := 0
var failures: Array[String] = []
var shots := OS.get_environment("LUMO_EXTRA_DRIVERS_SHOTS")


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("[ExtraDrivers] " + detail)


func settle(frames := 4) -> void:
	for frame in frames:
		await process_frame


func create_game():
	var game = load(SCENE).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.graphics_profile = "low"
	game.lightweight = true
	await settle()
	return game


func check_model(kart, identity: String, context: String) -> void:
	check(kart.animal == identity, context + ": selected animal")
	var actor = kart.production_driver
	check(is_instance_valid(actor), context + ": authored production driver")
	if not is_instance_valid(actor):
		return
	check(actor.is_usable() and actor.is_visible_in_tree(), context + ": visible imported skin")
	check(actor.species == identity, context + ": matching authored species")
	check(actor.model_path.contains("/" + identity + "/"), context + ": matching GLB path")
	check(actor.player.has_animation("kart_seated"), context + ": seated animation")
	for clip in ["greeting_wave", "agree_nod", "kart_hit", "kart_celebrate"]:
		check(actor.player.has_animation(clip), context + ": authored " + clip)
	check(
		not actor.visual.find_children("*", "MeshInstance3D", true, false).is_empty(),
		context + ": real 3D meshes"
	)


func capture(label: String) -> void:
	if shots.is_empty() or DisplayServer.get_name() == "headless":
		return
	await settle(3)
	await RenderingServer.frame_post_draw
	check(
		root.get_texture().get_image().save_png(shots.path_join(label + ".png")) == OK,
		label + ": capture"
	)


func _run() -> void:
	if not shots.is_empty():
		DirAccess.make_dir_recursive_absolute(shots)
	root.size = Vector2i(1280, 720)
	var router := root.get_node("SceneRouter")
	router.launch_options = {}
	check(CATALOG.DRIVERS.size() == 10, "ten playable drivers")
	check(int(CATALOG.entry(CATALOG.DRIVERS, "rabbit").unlock) == 6, "Nova unlock retained")
	check(int(CATALOG.entry(CATALOG.DRIVERS, "otter").unlock) == 12, "Milo unlock retained")
	for identity: String in EXTRA:
		DirAccess.remove_absolute(SESSION)
		var game = await create_game()
		game._reference_select_mode("driver")
		var menu = game.garage
		menu.stars = 0
		menu.unlocked_ids = []
		menu._refresh()
		await settle()
		var card = menu.choices.get_node_or_null("DriverCard_" + identity)
		check(card != null, identity + ": real menu card exists")
		if card == null:
			await TEARDOWN.release_scene(self, game, "[ExtraDrivers]")
			continue
		check(
			card.title == EXTRA[identity] and not card.disabled,
			identity + ": available by existing name at zero stars"
		)
		check(
			card.art != null and card.art.resource_path.ends_with("/" + identity + ".webp"),
			identity + ": actual portrait"
		)
		for dimensions in [Vector2i(390, 844), Vector2i(1280, 720)]:
			root.size = dimensions
			await settle(6)
			var drawer := menu.choices.get_parent() as ScrollContainer
			if drawer != null:
				drawer.ensure_control_visible(card)
				await settle()
			check(
				card.is_visible_in_tree() and card.size.x >= 48 and card.size.y >= 48,
				identity + ": usable card " + str(dimensions)
			)
		card.pressed.emit()
		# Selection replacement is intentionally deferred so the old 3D preview
		# is never mutated while its button signal is still dispatching. Observe
		# the real imported actor over a short bounded window instead of sampling
		# before the deferred refresh has necessarily run. Eight frames are far
		# shorter than the authored 1.46 s agree_nod clip, so this stays a strict
		# runtime assertion rather than accepting a later fallback animation.
		var garage_actor = null
		var saw_selection_nod := false
		for attempt in range(8):
			await settle(1)
			if is_instance_valid(menu.preview_kart):
				garage_actor = menu.preview_kart.production_driver
			if (
				menu.setup.driver == identity
				and is_instance_valid(garage_actor)
				and garage_actor.current_behavior == &"agree_nod"
			):
				saw_selection_nod = true
				break
		check(menu.setup.driver == identity, identity + ": real selection action")
		check(saw_selection_nod, identity + ": visible production driver runs authored agree_nod")
		await settle(5)
		check_model(menu.preview_kart, identity, identity + " garage")
		check(
			is_instance_valid(garage_actor) and garage_actor.play_menu_behavior("greeting_wave"),
			identity + ": imported driver accepts greeting"
		)
		if is_instance_valid(garage_actor):
			garage_actor.advance_tick(1.0 / 30.0)
			check(garage_actor.current_behavior == &"greeting_wave", identity + ": authored greeting is visible")
		await capture(identity + "-garage")
		menu.setup.mode = "race"
		menu.setup.track = "windwerk_3000"
		menu.setup.kart = "comet"
		menu.setup.difficulty = "flott"
		check(menu.next_button.is_visible_in_tree(), identity + ": race start action visible")
		menu.next_button.pressed.emit()
		await settle()
		check(not game.menu_active and game.mode == "race", identity + ": real race start button")
		check(game.opponents.size() == 5, identity + ": original five-opponent field")
		check_model(game.player, identity, identity + " race")
		var race_actor = game.player.production_driver
		if is_instance_valid(race_actor):
			race_actor.apply_vehicle_sample(12.0, 0.0, false, true)
			race_actor.advance_tick(1.0 / 30.0)
			check(race_actor.current_behavior == &"kart_hit", identity + ": real hit uses authored kart_hit")
			race_actor.celebrate_finished_race(1)
			race_actor.advance_tick(1.0 / 30.0)
			check(
				race_actor.current_behavior == &"kart_celebrate",
				identity + ": finish uses authored kart_celebrate"
			)
			race_actor.clear_celebration()
		game._end_preview()
		game.countdown = 0.0
		game.racing = true
		game.auto_gas = true
		for frame in 30:
			game._physics_process(1.0 / 60.0)
		game._save_session()
		var config := ConfigFile.new()
		check(config.load(SESSION) == OK, identity + ": real race saved")
		check(
			str(config.get_value("race", "selected_driver", "")) == identity,
			identity + ": persisted selected driver"
		)
		check(
			str(config.get_value("race", "setup_snapshot", {}).get("driver", "")) == identity,
			identity + ": persisted setup"
		)
		var result_id: String = game.result_id
		await capture(identity + "-race")
		check(
			await TEARDOWN.release_scene(self, game, "[ExtraDrivers]"),
			identity + ": first scene released"
		)
		game = await create_game()
		check(game.saved_session_available, identity + ": saved race discovered after reopening")
		game.garage.resume_requested.emit()
		await settle()
		check(game.selected_driver == identity and game.paused, identity + ": real resume action")
		check(game.result_id == result_id, identity + ": saved race identity retained")
		check_model(game.player, identity, identity + " reopened race")
		game.abandoned = true
		check(
			await TEARDOWN.release_scene(self, game, "[ExtraDrivers]"),
			identity + ": reopened scene released"
		)
		DirAccess.remove_absolute(SESSION)
	print(
		(
			"EXTRA_DRIVERS_%s checks=%d failures=%d"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()]
		)
	)
	quit(0 if failures.is_empty() else 1)
