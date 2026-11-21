extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var plan_script: GDScript = load("res://scripts/learning/tutor/tutor_plan.gd")
	var text := FileAccess.get_file_as_string("res://scripts/tests/fixtures/tutor_payloads.json")
	var doc: Dictionary = JSON.parse_string(text)
	for entry: Dictionary in doc.cases:
		var plan = plan_script.new()
		print(entry.name, " configure=", plan.configure(entry.learning))
	root.size = Vector2i(1080, 2340)
	for entry: Dictionary in doc.cases:
		var scene: PackedScene = load("res://scenes/learning/tutor_world.tscn")
		for weg: String in entry.learning.wege:
			for stufe: String in ["hinweis", "teilschritt", "vorzeigen", "ueben"]:
				var learning: Dictionary = entry.learning.duplicate(true)
				learning.startWeg = weg
				learning.startStufe = stufe
				var game: Node3D = scene.instantiate()
				if game.get_script() == null:
					quit(1)
					return
				game.capture_options = {"learning": learning, "reduceAnimations": true}
				root.add_child(game)
				for f in range(3):
					await process_frame
				var steps := 0
				var guard := 0
				while not game.tutor.current().is_empty() and guard < 20:
					guard += 1
					if game.tutor.lumo_turn() or game.tutor.vorgezeigt:
						game._next_step()
					else:
						game.tutor.demonstrate()
						game._next_step()
					steps += 1
					await process_frame
				print("%s %s/%s valid=%s steps=%d fertig=%s" % [entry.name, weg, stufe, game.valid, steps, game.tutor.fertig])
				game.queue_free()
				for f in range(2):
					await process_frame
	quit(0)
