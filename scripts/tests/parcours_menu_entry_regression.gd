extends SceneTree
## Menüweg: Kart-Menü -> „Abenteuer-Parcours“ öffnet die Weltwahl mit dem gewählten Kart,
## „Zum Kart-Menü“ führt zurück ins Kart-Menü (ohne Intro). Auch der Garagenweg
## (Rennart-Karte, Start) und der Direkteinstieg kartEntry=parcours landen dort.

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[ParcoursMenu] FAIL: " + text)


func _settle(frames: int = 8) -> void:
	for i in range(frames):
		await process_frame


func _run() -> void:
	var router = root.get_node("SceneRouter")
	router.launch_options = {"childKey": "parcours_menu"}
	router.goto("kart")
	await _settle(12)
	var kart: Node = current_scene
	_check(kart != null and kart.has_method("_reference_select_mode"), "Kart-Menü offen")
	var catalog = load("res://scripts/games/kart_catalog.gd")
	var ids: Array = []
	for entry in catalog.MODES:
		ids.append(str(entry.id))
	_check(ids.has("parcours"), "Rennart Abenteuer-Parcours im Katalog")
	kart.garage.setup["kart"] = "comet"
	kart._reference_select_mode("parcours")
	await _settle(12)
	var parcours: Node = current_scene
	_check(parcours != null and parcours.has_method("start_world"), "Abenteuer-Parcours geöffnet")
	_check(parcours.hud.choice != null and parcours.hud.choice.visible, "Weltwahl sichtbar")
	_check(parcours.selected_kart == "comet", "Gewähltes Kart übernommen")
	parcours.leave_to_kart_menu()
	await _settle(12)
	_check(current_scene.has_method("_reference_select_mode"), "Zurück im Kart-Menü")
	_check(bool(router.launch_options.get("kartEntryPrepared", false)), "Rückkehr ohne Intro")
	# Garagenweg: Rennart-Karte gewählt, Start gedrückt.
	current_scene._start_selected_race({"mode": "parcours", "kart": "comet", "driver": "fox"})
	await _settle(12)
	_check(current_scene.has_method("start_world"), "Garagenweg öffnet den Parcours")
	current_scene.leave_to_kart_menu()
	await _settle(12)
	if failures == 0:
		print("[ParcoursMenu] PASS: %d Prüfungen" % checks)
	else:
		print("[ParcoursMenu] FAIL: %d von %d Prüfungen" % [failures, checks])
	current_scene.queue_free()
	await _settle(4)
	await create_timer(0.4).timeout
	quit(1 if failures > 0 else 0)
