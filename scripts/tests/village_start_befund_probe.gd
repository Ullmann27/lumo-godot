extends SceneTree
## Befund: App-Einstieg (HostBridge-Startoptionen wie aus Flutter) mit neuem Profil,
## altem Dorf ohne Tutorialstatus und unterbrochenem Tutorial. Druckt nur Fakten.
const SLOT := 4


func _initialize() -> void:
	call_deferred("_run")


func _frames(count := 8) -> void:
	for _i in range(count):
		await process_frame


func _open(child: String) -> Node:
	var launch := {
		"game": "settlement", "scene": "settlement", "livingVillage": true, "settlementMode": "settlement",
		"childKey": child, "buildSlot": SLOT,
	}
	root.get_node("HostBridge").set("_options", launch.duplicate(true))
	root.get_node("SceneRouter").launch_options = launch.duplicate(true)
	var village: Node = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	await _frames(10)
	return village


func _report(label: String, village: Node) -> void:
	var tutorial: Node = village.tutorial
	print("[Befund] ", label, " ", JSON.stringify({
		"day": int(village.model.day), "buildings": village.model.player().buildings.size(),
		"active": tutorial.active(), "done": tutorial.done, "step": tutorial.current_id(),
		"visible": tutorial.visible, "save_blocked": village.save_blocked,
	}))


func _write(path: String, raw: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()


func _run() -> void:
	root.size = Vector2i(906, 1088)
	var world: GDScript = load("res://scripts/creative/build_settlement_world.gd")
	var child := "befund_probe"
	var save: String = world.project_path(child, SLOT, "village")
	DirAccess.remove_absolute(save)
	# 1) Neues Profil
	var village: Node = await _open(child)
	_report("neues_profil", village)
	# Build two buildings and advance some days, then save.
	village.model.try_build("house", village._next_free_plot())
	village.model.try_build("farm", village._next_free_plot())
	village._save()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save))
	village.queue_free()
	await _frames(4)
	# 2) Altes Dorf: zwei Gebäude, kein village_meta (Stand vor der Einführung).
	var legacy := raw.duplicate(true)
	legacy.erase("village_meta")
	_write(save, legacy)
	village = await _open(child)
	_report("altes_dorf_2_gebaeude", village)
	village.queue_free()
	await _frames(4)
	# 3) Altes Dorf an Tag 4 ohne Gebäude (echte Tageswechsel, Datei ohne village_meta).
	DirAccess.remove_absolute(save)
	village = await _open(child)
	for _i in range(3):
		village.model.next_day()
	village._save()
	var day_four: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save))
	day_four.erase("village_meta")
	village.queue_free()
	await _frames(4)
	_write(save, day_four)
	village = await _open(child)
	_report("altes_dorf_tag_4", village)
	village.queue_free()
	await _frames(4)
	# 4) Unterbrochenes Tutorial: echte Schritte bis „Wohnhaus“, speichern, neu öffnen.
	DirAccess.remove_absolute(save)
	village = await _open(child)
	village.tutorial._next()
	village.selected_plot = village._next_free_plot()
	await _frames(4)
	_report("vor_unterbrechung", village)
	village._save()
	village.queue_free()
	await _frames(4)
	village = await _open(child)
	_report("unterbrochen_fortsetzen", village)
	village.queue_free()
	await _frames(4)
	DirAccess.remove_absolute(save)
	print("[Befund] PASS probe finished")
	quit(0)
