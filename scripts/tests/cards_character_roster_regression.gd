extends SceneTree

const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[CardsCharacters] " + label)


func _run() -> void:
	# SceneTree --script starts compiling before autoload names exist. Load the
	# unchanged Cards runtime after startup so its real managers are available.
	var seat_script := load("res://scripts/games/cards/cards_seat.gd")
	var table_script := load("res://scripts/games/cards/cards_table.gd")
	var hud_script := load("res://scripts/games/cards/cards_hud.gd")
	var shared := ROSTER.for_game("lumo_cards")
	var expected := ["lion", "owl", "rabbit", "squirrel", "turtle", "frog", "otter", "badger", "cat"]
	var ids: Array[String] = []
	for entry in shared:
		ids.append(str(entry.id))
	_check(ids == expected, "Cards consumes the complete shared production roster.")
	_check(table_script.ROSTER.size() == expected.size(), "Cards table exposes every shared production character.")
	var table_ids: Dictionary = {}
	for id in table_script.ROSTER:
		table_ids[str(id)] = true
	for id in expected:
		_check(table_ids.has(id), "Cards table can select " + id)
		_check(seat_script.NAMES.has(id), "Cards has a visible name for " + id)
		_check(seat_script.PERSONALITIES.has(id), "Cards has a personality for " + id)
		var portrait: String = hud_script.portrait_path(id)
		_check(portrait == "res://assets/kart/menu/drivers/%s.webp" % id,
			"Cards HUD shares the current production portrait for " + id)
		_check(ResourceLoader.exists(portrait), "Cards HUD has the matching portrait for " + id)

	var stage := Node3D.new()
	root.add_child(stage)
	for index in range(expected.size()):
		var id: String = expected[index]
		var seat = seat_script.new()
		seat.name = "Seat_" + id
		stage.add_child(seat)
		var placed := Transform3D(Basis.IDENTITY, Vector3(float(index) * 2.5, 0, 0))
		var ok: bool = seat.setup(id, placed, index + 1)
		_check(ok, id + " production model can sit at the Cards table.")
		_check(seat.usable(), id + " exposes a usable skeleton and AnimationPlayer.")
		if ok and seat.usable():
			seat.react("smug")
			_check(seat.mood == "smug", id + " has the playful winner-pride state.")
			_check(seat._mood_left >= 3.5, id + " winner reaction is deliberately held, not a twitch.")
			_check(seat._clip_rate <= 0.90, id + " winner animation is slowed below robotic playback.")
			var expected_clip := "celebrate" if seat.player.has_animation("celebrate") else "kart_celebrate"
			_check(seat._clip == expected_clip, id + " Cards uses its authored celebration before the race alias.")
			var start_rotation: Vector3 = seat._pivot.rotation
			for frame in range(75):
				seat.advance(1.0 / 60.0)
			var moved: float = seat._pivot.rotation.distance_to(start_rotation)
			_check(moved > 0.015, id + " winner pride changes readable body posture.")
			_check(absf(seat._pivot.rotation.x) < 0.22 and absf(seat._pivot.rotation.z) < 0.22,
				id + " humanized reaction remains restrained and seated.")
		seat.queue_free()
		await process_frame
	stage.queue_free()
	await process_frame
	print("[CardsCharacters] checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
