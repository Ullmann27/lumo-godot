extends SceneTree
## Aufnahmen der Streckenwahl auf dem echten Weg: Kart-Hauptmenü → Kachel „Strecken“.
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://scripts/tests/kart_track_stage_capture.gd -- --out=<dir> [--label=vorher]
##     [--tracks=a,b] [--formats=fold,schmal,quer] [--sheet]
##
## Je Format (Fold offen, schmales Hochformat, Fold quer) ein Bild nach dem Öffnen und je
## Strecke aus --tracks ein Bild nach dem Antippen. Desktop-GL im Container, kein Handy-Wert.
const SIZES := [
	[Vector2i(1812, 2176), 2.625, "fold"],
	[Vector2i(1080, 2340), 2.625, "schmal"],
	[Vector2i(2176, 1812), 2.625, "quer"]
]
var game
var out := ""
var label := "vorher"
var tracks: Array[String] = []
var sheet := false
var formats: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames := 3) -> void:
	for _index in range(frames):
		await process_frame


func _touch(control: Control) -> void:
	var scale: Vector2 = Vector2(root.size) / root.get_visible_rect().size
	var center := control.get_global_rect().get_center() * scale
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 2
		event.position = center
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out.path_join("%s_%s.png" % [label, name])
	var image := root.get_texture().get_image()
	if image.save_png(path) != OK:
		push_error("[TrackStageCapture] kann nicht speichern: " + path)
	print("[TrackStageCapture] ", path, " ", image.get_size())


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		var text := str(argument)
		if text.begins_with("--out="):
			out = text.trim_prefix("--out=")
		elif text.begins_with("--label="):
			label = text.trim_prefix("--label=")
		elif text.begins_with("--tracks="):
			for part in text.trim_prefix("--tracks=").split(",", false):
				tracks.append(part)
		elif text.begins_with("--formats="):
			for part in text.trim_prefix("--formats=").split(",", false):
				formats.append(part)
		elif text == "--sheet":
			sheet = true
	if out.is_empty():
		push_error("[TrackStageCapture] --out=<dir> fehlt")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var host = root.get_node("HostBridge")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	game.lightweight = true
	root.add_child(game)
	game.set_physics_process(false)
	await _settle(6)
	for sample in SIZES:
		if not formats.is_empty() and not formats.has(sample[2]):
			continue
		host._options["displayDensity"] = sample[1]
		root.size = sample[0]
		await _settle(6)
		game._show_reference_landing()
		await _settle(8)
		var tile: Control = game.reference_landing.find_child("Feature_world", true, false)
		await _touch(tile)
		await _settle(30)
		print(
			"[TrackStageCapture] Menüpfad: Kart-Hauptmenü → Feature_world → step=",
			game.garage.step,
			" title=",
			game.garage.title_label.text,
			" track=",
			game.garage.setup.track
		)
		await _save("%s_offen" % sample[2])
		for id in tracks:
			await _choose(id)
			await _settle(30)
			await _save("%s_%s" % [sample[2], id])
		if sheet and sample[2] == "fold":
			await _contact_sheet()
	game.queue_free()
	await _settle()
	print("[TrackStageCapture] PASS")
	quit(0)


func _choose(id: String) -> void:
	var stage = game.garage.get("track_stage")
	if stage != null and is_instance_valid(stage) and stage.is_visible_in_tree():
		var card: Control = stage.card_for(id)
		(game.garage.choices.get_parent() as ScrollContainer).ensure_control_visible(card)
		await _settle(4)
		await _touch(card)
	else:
		# Vorher-Stand: die alte Liste der Rennwelten.
		var entries: Array = game.garage.CATALOG.TRACKS
		for index in range(entries.size()):
			if str(entries[index].id) == id:
				await _touch(game.garage.choices.get_child(index))


## Bildfolge der laufenden Vorschau: 6 Bilder im Abstand von 1 s als Kontaktbogen.
func _contact_sheet() -> void:
	var stage = game.garage.get("track_stage")
	if stage == null:
		return
	for id in tracks:
		await _choose(id)
		var frames: Array[Image] = []
		for index in range(6):
			var until := Time.get_ticks_msec() + 1000
			while Time.get_ticks_msec() < until:
				await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var scale := Vector2(root.size) / root.get_visible_rect().size
			var rect: Rect2 = stage.picture_rect()
			var area := Rect2i(Rect2(rect.position * scale, rect.size * scale))
			frames.append(image.get_region(area))
			print(
				(
					"[TrackStageCapture] sheet %s %d playing=%s"
					% [id, index, stage.is_preview_playing()]
				)
			)
		var tile := Vector2i(frames[0].get_width() / 2, frames[0].get_height() / 2)
		var board := Image.create(tile.x * 3 + 16, tile.y * 2 + 12, false, Image.FORMAT_RGBA8)
		board.fill(Color("061233"))
		for index in range(frames.size()):
			var frame := frames[index]
			frame.convert(Image.FORMAT_RGBA8)
			frame.resize(tile.x, tile.y, Image.INTERPOLATE_BILINEAR)
			board.blit_rect(
				frame,
				Rect2i(Vector2i.ZERO, tile),
				Vector2i(4 + (index % 3) * (tile.x + 4), 4 + (index / 3) * (tile.y + 4))
			)
		board.save_png(out.path_join("%s_vorschau_%s_kontaktbogen.png" % [label, id]))
