extends SceneTree
## Echte Fenstergrößen (Handy hoch/quer, Fold7 innen, Tablet): Touch-Größen in dp,
## alles im sichtbaren Bereich, keine überlappenden Bedienflächen.
const HUB = preload("res://scripts/games/kart_neon_hub.gd")
const SURFACES := [Vector2i(360, 800), Vector2i(412, 915), Vector2i(884, 1032), Vector2i(840, 960), Vector2i(960, 720), Vector2i(1280, 800), Vector2i(915, 412), Vector2i(800, 360)]
var checks := 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func _min_dp(control: Control, k: float, w: float, h: float, tag: String) -> void:
	_check(control.size.x / k >= w - 0.6 and control.size.y / k >= h - 0.6,
		"%s: mindestens %dx%d dp (ist %.0fx%.0f)" % [tag, w, h, control.size.x / k, control.size.y / k])

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	var hub = HUB.new()
	hub.total_stars = 17
	root.add_child(hub)
	for dimensions in SURFACES:
		root.size = dimensions
		for frame in range(3):
			await process_frame
		hub.size = hub.get_viewport_rect().size
		hub._layout()
		for frame in range(4):
			await process_frame
		var k: float = hub._layout_scale
		var surface := Rect2(Vector2.ZERO, hub.size).grow(1.0)
		var tag := "%dx%d" % [dimensions.x, dimensions.y]
		_check(hub.size.is_equal_approx(Vector2(dimensions)), tag + ": Leinwand entspricht Fenster")
		for id in hub._mode_tiles:
			_min_dp(hub._mode_tiles[id], k, 64, 64, tag + "/Modus " + id)
		for id in hub._feature_tiles:
			_min_dp(hub._feature_tiles[id], k, 64, 52, tag + "/Kachel " + id)
		for tile in hub._navigation.get_children():
			if tile.visible:
				_min_dp(tile, k, 56, 60, tag + "/Leiste " + str(tile.name))
		for chip in [hub._back, hub._stars_chip, hub._rotation_left, hub._rotation_right, hub._player]:
			_min_dp(chip, k, 48, 48, tag + "/" + str(chip.name))
		for thumb in hub._track_buttons.values():
			if thumb.visible:
				_min_dp(thumb, k, 44, 44, tag + "/Vorschau " + str(thumb.name))
		var panels: Array[Control] = [hub._back, hub._logo, hub._player, hub._stars_chip, hub._highlight, hub._progress, hub._dock]
		panels.append_array(hub._mode_tiles.values())
		panels.append_array(hub._feature_tiles.values())
		for control in panels:
			_check(surface.encloses(control.get_global_rect()), tag + "/" + str(control.name) + ": im sichtbaren Bereich")
		for a in range(panels.size()):
			for b in range(a + 1, panels.size()):
				var ra: Rect2 = panels[a].get_global_rect().grow(-1.0)
				var rb: Rect2 = panels[b].get_global_rect().grow(-1.0)
				_check(not ra.intersects(rb), tag + ": keine Überlappung " + str(panels[a].name) + "/" + str(panels[b].name))
		var stage: Rect2 = hub._stage_bounds
		_check(stage.size.x / k >= 140.0 and stage.size.y / k >= 140.0, tag + ": Bühne für Lumo im Kart mindestens 140 dp")
		for control in [hub._highlight] + hub._mode_tiles.values() + hub._feature_tiles.values():
			_check(not stage.grow(-1.0).intersects(control.get_global_rect().grow(-1.0)), tag + ": Bühne frei von " + str(control.name))
		var shown := 0
		for tile in hub._navigation.get_children():
			if tile.visible:
				shown += 1
				_check(surface.encloses(tile.get_global_rect()), tag + "/Leiste " + str(tile.name) + ": ganz sichtbar, kein Abschneiden")
		_check(shown >= 6, tag + ": mindestens sechs Leisten-Ziele")
		captures.append({"window": [dimensions.x, dimensions.y], "scale": k, "stage_dp": [stage.size.x / k, stage.size.y / k]})
	hub.free()
	var report := {"checks": checks, "failures": failures, "surfaces": captures, "status": "PASS" if failures.is_empty() else "FAIL",
		"scope": "Godot-Control-Layout; keine Android-Installation"}
	print("[NeonReadability] ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
