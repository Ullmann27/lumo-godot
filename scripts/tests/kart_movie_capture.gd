extends SceneTree
## Echte Engine-Aufnahme mit Ton (Godot Movie Maker): Intro, Streckenvorschau,
## einrollende Startaufstellung, Startampel und die ersten Sekunden des Rennens.
## Aufruf: godot --rendering-method gl_compatibility --write-movie out.avi --fixed-fps 30 \
##   --script scripts/tests/kart_movie_capture.gd
## Keine Bildbearbeitung; Lenkung im Rennen automatisch entlang der Fahrbahn.

var game
var frame: int = 0
var phase: String = "intro"
var race_frames: int = 0


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	game.intro_mode = "force"
	root.add_child(game)


func _process(_delta: float) -> bool:
	frame += 1
	if not is_instance_valid(game):
		return false
	match phase:
		"intro":
			if frame > 20 and not is_instance_valid(game.intro):
				game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "flott"})
				phase = "race"
		"race":
			if game.racing:
				race_frames += 1
				var target: Vector3 = game.world.position_at(game.previous_road_distance + 10, 0)
				var direction: Vector3 = target - game.player.position
				var heading: float = atan2(-direction.x, -direction.z)
				game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.1, -1, 1)
				game.gas_held = true
				if race_frames > 150:
					print("[KartMovie] PASS: Intro, Vorschau, Startaufstellung, Ampel und Rennstart aufgenommen")
					return true
	if frame > 1500:
		print("[KartMovie] FAIL: Zeitüberschreitung in Phase ", phase)
		return true
	return false
