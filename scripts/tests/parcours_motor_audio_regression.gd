extends SceneTree
## Real course choice and player input share the race's chassis-aware motor.
const STEP := 1.0 / 60.0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _run() -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": "parcours_motor", "kart": "zuri_volt"}
	var game = load("res://scenes/games/kart_parcours.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var worlds = load("res://scripts/games/parcours/parcours_worlds.gd")
	var card: Button = game.hud.choice.find_child("World_" + worlds.playable_ids()[0], true, false)
	card.pressed.emit()
	var audio = game.kart_audio
	var voice = audio.player_motor
	check(voice.electric == 1.0 and voice.body.stream is AudioStreamWAV, "selected electric kart voices the course")
	game.auto_gas = false
	game._physics_process(STEP)
	var idle: float = voice.body.pitch_scale
	check(audio.rival_motors.size() == 2, "Nova and Milo have positional engines")
	check(audio.rival_motors[0].body.playing, "nearby rival idles on the grid")
	game.gas_held = true
	for i in 30:
		game._physics_process(STEP)
	check(voice.body.playing and voice.body.pitch_scale > idle + .7 and game.run.drive.speed == 0.0, "countdown pedal revs at rest")
	game.countdown = 0.0
	for i in 45:
		game.step_game(STEP, 0.0, 1.0, true, Vector2.ZERO)
	check(voice.rpm > .75 and is_zero_approx(game.run.drive.speed), "brake and gas hold station")
	for i in 48:
		game.step_game(STEP, 0.0, 0.0, true, Vector2.ZERO)
	check(voice.previous_speed > 1.0 and voice.load_amount > .5, "course physics accelerates motor")
	for i in 36:
		game.step_game(STEP, 0.0, 0.0, false, Vector2.ZERO)
	check(voice.load_amount < .01, "lifting removes intake load")
	game.pause_game()
	check(not voice.body.playing, "pause stops motor")
	game.resume_game()
	game.run.on_foot = true
	game.step_game(STEP, 0.0, 0.0, false, Vector2.ZERO)
	check(not voice.body.playing and not voice.induction.playing, "walking silences kart")
	game.run.on_foot = false
	game.step_game(STEP, 0.0, 0.0, true, Vector2.ZERO)
	game.show_world_choice()
	check(not voice.body.playing and not voice.induction.playing, "world choice silences kart")
	game.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("[ParcoursMotor] ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
