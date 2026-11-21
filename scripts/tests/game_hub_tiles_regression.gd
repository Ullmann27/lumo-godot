extends SceneTree
## Spielewelt am Handy (Dichte 2,625): jede Spielkachel zeigt ein Bild aus dem
## echten Spiel neben gut lesbarem Titel, ist mindestens 48 dp hoch, Bild und
## Text überlappen nicht, quer stehen zwei Kacheln nebeneinander, und die
## Klassen-/Fachauswahl hat fingergroße Listeneinträge.

const ROUTES := [
	"kart", "settlement", "jump", "run", "puzzle", "treasure", "rhythm", "build", "stars"
]
const DENSITY: float = 2.625

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("[HubTiles] FAIL " + message)


func _run() -> void:
	var bridge: Node = root.get_node("HostBridge")
	bridge._options["displayDensity"] = DENSITY
	root.get_node("SceneRouter").launch_options = {"reduceAnimations": true}
	root.size = Vector2i(1080, 2340)
	var hub: Node3D = load("res://scenes/games/game_hub.tscn").instantiate()
	root.add_child(hub)
	for sample in [Vector2i(1080, 2340), Vector2i(2176, 1812)]:
		root.size = sample
		for _i in range(6):
			await process_frame
		var physical: float = Vector2(root.size).x / root.get_visible_rect().size.x
		var grid := hub.find_child("LiveGameRoutes", true, false) as GridContainer
		if sample.x > sample.y:
			_check(grid.columns == 2, "quer zwei Kacheln nebeneinander (%d)" % grid.columns)
		for route in ROUTES:
			var tile := hub.find_child("GameRoute_" + route, true, false) as Button
			_check(tile != null, "Kachel %s vorhanden" % route)
			if tile == null:
				continue
			var height_dp: float = tile.size.y * physical / DENSITY
			_check(height_dp >= 48.0, "%s: Kachel ≥ 48 dp (%.0f)" % [route, height_dp])
			var picture := tile.find_child("PortalPicture", true, false) as TextureRect
			_check(picture != null and picture.texture != null, "%s: Bild aus dem Spiel" % route)
			var title := tile.find_child("PortalTitle", true, false) as Label
			_check(title.get_theme_font_size("font_size") >= 22, "%s: Titel groß" % route)
			if picture != null:
				var tile_rect: Rect2 = tile.get_global_rect().grow(1.0)
				_check(
					tile_rect.encloses(picture.get_global_rect()), "%s: Bild in der Kachel" % route
				)
				_check(
					not picture.get_global_rect().intersects(title.get_global_rect()),
					"%s: Bild und Titel getrennt" % route
				)
	for name in ["GradeChoice", "SubjectChoice"]:
		var choice := hub.find_child(name, true, false) as OptionButton
		var popup := choice.get_popup()
		_check(popup.get_theme_font_size("font_size") >= 26, name + ": große Listenschrift")
		_check(popup.get_theme_constant("v_separation") >= 22, name + ": Abstand für Finger")
	hub.queue_free()
	bridge._options.erase("displayDensity")
	for _i in range(4):
		await process_frame
	if failures.is_empty():
		print("[HubTiles] PASS: %d checks" % checks)
	else:
		print("[HubTiles] FAIL: %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
