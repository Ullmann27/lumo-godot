extends SceneTree
## Bildfolge „Teilewechsel vom Antippen bis zum ersten Bild im Rennen“ (Weg A) und die
## Garage-Ansichten dazu. Echter Renderer (xvfb, gl_compatibility), kein FPS-Test.
## Aufruf: godot --rendering-method gl_compatibility --script
##   res://scripts/tests/kart_parts_capture.gd -- --out=<ordner>
##   [--sizes=1812x2176,2176x1812,1080x2340] [--kart=comet] [--race] [--only=garage,werte]
##   [--perf]  Leistungsteile: Motor wählen → Prüfstand → gesperrtes Teil → montieren
##             (Motor, Reifen, Flügel, Turbo, Fahrwerk) → erstes Bild im Rennen.
## Setzt die Teile des gewählten Karts zu Beginn auf Serie (nur im XDG-Profil des Aufrufs).
const PERF_SET: Dictionary = {
	"engine": "sprint", "tires": "haft", "wing": "gross", "booster": "kurz", "suspension": "sprung"
}
var game
var out_dir: String = "user://kart_parts_capture"
var sizes: Array[Vector2i] = [Vector2i(1812, 2176)]
var kart_id: String = "comet"
var with_race := false
var with_perf := false
var new_parts := false
var only: PackedStringArray = PackedStringArray()
var written: int = 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--kart="):
			kart_id = arg.trim_prefix("--kart=")
		elif arg == "--race":
			with_race = true
		elif arg == "--new-parts":
			new_parts = true
		elif arg == "--perf":
			with_perf = true
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--sizes="):
			sizes.clear()
			for part in arg.trim_prefix("--sizes=").split(",", false):
				var pair := part.split("x")
				if pair.size() == 2:
					sizes.append(Vector2i(int(pair[0]), int(pair[1])))
	call_deferred("_run")


func _frames(count: int) -> void:
	for _index in range(mini(count, 3) if new_parts else count):
		await process_frame


func _shot(label: String) -> void:
	if not only.is_empty() and not only.has(label):
		return
	await _frames(20)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := out_dir.path_join("%s_%s_%dx%d.png" % [label, kart_id, root.size.x, root.size.y])
	if image.save_png(path) == OK:
		written += 1
		print("[KartPartsCapture] ", path)
	else:
		push_error("[KartPartsCapture] Bild nicht gespeichert: " + path)


func _open_garage() -> void:
	game._show_reference_landing(true)
	await _frames(12)
	game.reference_landing.mode_selected.emit("garage")
	await _frames(12)
	game.garage._select("kart", kart_id)
	await _frames(30)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[KartPartsCapture] braucht einen echten Renderer (xvfb)")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = sizes[0]
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _frames(30)
	var workshop = game.garage.workshop
	for slot in ["wheel_cover", "exhaust"]:
		workshop.choose(kart_id, slot, "serie")
	if new_parts:
		game.garage.reduced_motion = true
		for window in sizes:
			root.size = window
			await _open_garage()
			var bay = game.garage.parts_bay
			bay._on_open()
			for selection in [["tires", "regen"], ["wing", "tandem"], ["steering", "direkt"],
				["brakes", "sport"], ["gearbox", "kurz"], ["ballast", "vorn"]]:
				bay._on_slot(selection[0])
				bay._on_tile(selection[1])
				await _shot(selection[0] + "_" + selection[1])
			bay._on_back()
		await _finish_capture()
		return
	if with_perf:
		await _perf_sequence(workshop)
		_finish_capture()
		return
	for window in sizes:
		root.size = window
		await _frames(12)
		await _open_garage()
		var bay = game.garage.parts_bay
		await _shot("01_garage")
		bay._on_stats()
		await _shot("02_werte")
		bay.stats_panel.hide()
		bay._on_open()
		bay._on_slot("wheel_cover")
		await _frames(50)
		await _shot("03_teile_raeder")
		bay._on_tile("turbine")
		await _frames(10)
		await _shot("04_vorschau_turbinenrad")
		bay._on_tile("stern")
		await _frames(10)
		await _shot("05_vorschau_sternrad")
		bay._on_tile("turbine")
		bay._on_mount()
		await _frames(10)
		bay._on_open()
		bay._on_slot("exhaust")
		await _frames(50)
		bay._on_tile("rakete")
		await _frames(10)
		await _shot("06_vorschau_raketenduese")
		bay._on_tile("doppel")
		await _frames(10)
		await _shot("07_vorschau_doppelrohr")
		bay._on_mount()
		await _frames(50)
		await _shot("08_garage_montiert")
		for slot in ["wheel_cover", "exhaust"]:
			workshop.choose(kart_id, slot, "serie")
	if with_race:
		workshop.choose(kart_id, "wheel_cover", "turbine")
		workshop.choose(kart_id, "exhaust", "doppel")
		await _open_garage()
		game.selected_kart = kart_id
		game.garage.start_requested.emit(game.garage.setup.duplicate(true))
		await _frames(40)
		await _shot("09_rennen_erstes_bild")
		var vehicle = (
			game.player.get("production_vehicle") if is_instance_valid(game.player) else null
		)
		if vehicle != null:
			print("[KartPartsCapture] Rennfahrzeug-Teile ", vehicle.mounted_parts)
		for slot in ["wheel_cover", "exhaust"]:
			workshop.choose(kart_id, slot, "serie")
	_finish_capture()


func _reset_perf(workshop) -> void:
	for slot in PERF_SET:
		workshop.choose(kart_id, slot, "serie")
	for slot in ["wheel_cover", "exhaust"]:
		workshop.choose(kart_id, slot, "serie")


func _perf_sequence(workshop) -> void:
	for window in sizes:
		root.size = window
		_reset_perf(workshop)
		await _frames(12)
		await _open_garage()
		var bay = game.garage.parts_bay
		await _shot("10_garage_serie")
		bay._on_open()
		bay._on_slot("engine")
		await _frames(50)
		await _shot("11_motor_waehlen")
		bay._on_tile("sprint")
		await _frames(20)
		await _shot("12_pruefstand_sprintmotor")
		bay._on_tile("dauer")
		await _frames(20)
		await _shot("13_pruefstand_langstrecke")
		bay._on_tile("sprint")
		bay._on_mount()
		for slot in ["tires", "wing", "booster", "suspension"]:
			bay._on_open()
			bay._on_slot(slot)
			await _frames(40)
			bay._on_tile(str(PERF_SET[slot]))
			await _frames(20)
			await _shot("14_pruefstand_" + slot)
			bay._on_mount()
		await _frames(50)
		await _shot("15_garage_montiert")
	if with_race:
		await _open_garage()
		game.selected_kart = kart_id
		game.garage.start_requested.emit(game.garage.setup.duplicate(true))
		await _frames(40)
		await _shot("16_rennen_erstes_bild")
		var vehicle = (
			game.player.get("production_vehicle") if is_instance_valid(game.player) else null
		)
		if vehicle != null:
			print("[KartPartsCapture] Rennfahrzeug-Teile ", vehicle.mounted_parts)
	_reset_perf(workshop)


func _finish_capture() -> void:
	print("[KartPartsCapture] bilder=%d" % written)
	var sound := root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	game.queue_free()
	await _frames(24)
	quit(0 if written > 0 else 1)
