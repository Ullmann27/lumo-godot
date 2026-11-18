extends SceneTree
## Überall, wo Kinder Lumo sehen, ist es der ECHTE Lumo (geriggtes Modell,
## lumo_rigged_actor.gd) – nie die aus Grundformen gebaute Ersatzfigur.
## Instanziiert Schatzsuche, Rhythmus, Home und eine Lernszene wirklich und
## prüft Modell, Sichtbarkeit, Fußkontakt, Blickrichtung und Animationswechsel.
const TREASURE_STATE = preload("res://scripts/creative/treasure_state.gd")
## Nur hier darf die Ersatzfigur noch gebaut werden: im Kart (eigener Strang)
## und im Notfall-Zweig des Welt-Avatars, wenn das Modell nicht ladbar ist.
const STAND_IN_ALLOWED: Array[String] = [
	"res://scripts/games/kart_vehicle.gd",
	"res://scripts/characters/lumo/lumo_world_avatar.gd",
]
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[RealLumoEverywhere] " + message)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_scan_sources("res://scripts")
	await _treasure()
	await _rhythm()
	await _scene_lumo("res://scenes/app/home_3d.tscn", "Home")
	await _scene_lumo("res://scenes/games/star_collect.tscn", "Sternensammeln")
	if failures.is_empty():
		print("[RealLumoEverywhere] PASS: %d checks; Schatzsuche, Rhythmus, Home und Lernszenen zeigen den echten Lumo" % checks)
	else:
		print("[RealLumoEverywhere] FAIL: %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


## Kein Spielcode außerhalb der Tests baut den Grundformen-Fuchs als Lumo.
func _scan_sources(dir_path: String) -> void:
	for sub in DirAccess.get_directories_at(dir_path):
		if sub != "tests":
			_scan_sources(dir_path.path_join(sub))
	for file in DirAccess.get_files_at(dir_path):
		if not file.ends_with(".gd"):
			continue
		var path := dir_path.path_join(file)
		if path in STAND_IN_ALLOWED:
			continue
		var source := FileAccess.get_file_as_string(path)
		_check(not source.contains("configure_companion(\"fox\")"), path + " baut keine Ersatz-Fuchsfigur")


func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _physics(count: int) -> void:
	for _i in range(count):
		await physics_frame


## Sichtbare Meshes unterhalb von holder, die NICHT zum echten Modell gehören.
func _foreign_visible_meshes(holder: Node, rig: Node) -> int:
	var count := 0
	for node in holder.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.is_visible_in_tree() and not rig.is_ancestor_of(mesh):
			count += 1
	return count


func _lowest_point(rig: Node3D) -> float:
	var lowest := INF
	for node in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		lowest = minf(lowest, box.position.y)
	return lowest


func _treasure() -> void:
	var game = load("res://scenes/creative/treasure_world.tscn").instantiate()
	root.add_child(game)
	await _frames(6)
	game.model = TREASURE_STATE.new()
	game.model.result_id = "real-lumo-regression"
	game.save_path = "user://lumo_treasure_real_lumo_regression.json"
	game.player.position = Vector3(-9, 0.4, -4)
	game._update()
	await _physics(30)
	var avatar = game.fox
	_check(avatar.has_method("is_real") and avatar.is_real(), "Schatzsuche: echter Lumo geladen und nutzbar")
	if not (avatar.has_method("is_real") and avatar.is_real()):
		game.queue_free()
		return
	var rig: Node3D = avatar.rig
	_check(rig.skeleton.get_bone_count() == 65, "Schatzsuche: 65-Knochen-Skelett")
	_check(avatar.get_node_or_null("StandInFox") == null, "Schatzsuche: keine Ersatzfigur gebaut")
	_check(_foreign_visible_meshes(avatar, rig) == 0, "Schatzsuche: keine sichtbare Fremdfigur am Spieler")
	_check(game.player.is_on_floor(), "Schatzsuche: Spieler steht auf dem Boden")
	var foot_gap: float = _lowest_point(rig) - game.player.global_position.y
	_check(absf(foot_gap) < 0.08, "Schatzsuche: Füße auf dem Boden (Abstand %.3f m)" % foot_gap)
	_check(rig.get_current_behavior() == "idle", "Schatzsuche: im Stand idle (%s)" % rig.get_current_behavior())
	# Stick nach rechts-vorn: Lumo läuft und schaut in Laufrichtung.
	game.joystick.target = Vector2(1, 0)
	game.joystick.axis = Vector2(1, 0)
	await _physics(30)
	var moving: String = rig.get_current_behavior()
	_check(moving in ["walk_loop", "run_loop"], "Schatzsuche: Stick bewegt Lumo mit Lauf-Animation (%s)" % moving)
	var forward: Vector3 = rig.global_transform.basis.z.normalized()
	_check(forward.dot(Vector3.RIGHT) > 0.9, "Schatzsuche: Lumo schaut in Laufrichtung (%s)" % str(forward))
	game.joystick.target = Vector2.ZERO
	game.joystick.axis = Vector2.ZERO
	await _physics(45)
	_check(rig.get_current_behavior() == "idle", "Schatzsuche: nach dem Loslassen wieder idle (%s)" % rig.get_current_behavior())
	# Echter Schatzfund: Hinweis vor Ort richtig beantworten.
	var clue: Dictionary = TREASURE_STATE.CLUES[0]
	game.player.position = clue.at + Vector3.UP * 0.3
	await _physics(10)
	game._interact()
	game._answer(int(clue.correct))
	await _physics(4)
	_check(game.model.found.size() == 1, "Schatzsuche: Hinweis gefunden")
	_check(rig.get_current_behavior() == "celebrate", "Schatzsuche: Lumo jubelt beim Fund (%s)" % rig.get_current_behavior())
	game.queue_free()
	await _frames(2)


func _rhythm() -> void:
	var game = load("res://scenes/creative/rhythm_world.tscn").instantiate()
	root.add_child(game)
	await _frames(4)
	var avatar = game.performer_fox
	_check(avatar.has_method("is_real") and avatar.is_real(), "Rhythmus: echter Lumo geladen und nutzbar")
	if not (avatar.has_method("is_real") and avatar.is_real()):
		game.queue_free()
		return
	var rig: Node3D = avatar.rig
	_check(_foreign_visible_meshes(avatar, rig) == 0, "Rhythmus: keine sichtbare Ersatzfigur auf der Bühne")
	var foot_gap: float = _lowest_point(rig) - game.PERFORMER_FLOOR
	_check(absf(foot_gap) < 0.08, "Rhythmus: Füße auf dem Podest (Abstand %.3f m)" % foot_gap)
	var to_camera: Vector3 = (game.camera.global_position - rig.global_position) * Vector3(1, 0, 1)
	_check(rig.global_transform.basis.z.normalized().dot(to_camera.normalized()) > 0.9, "Rhythmus: Lumo schaut zum Kind")
	var height: float = game.camera.unproject_position(rig.global_position + Vector3.UP * game.PERFORMER_HEIGHT).y
	_check(height > 0.0, "Rhythmus: Lumo ist ganz im Bild")
	game.start()
	await _frames(2)
	_check(rig.get_current_behavior() == "greeting_wave", "Rhythmus: Lumo winkt zum Liedstart (%s)" % rig.get_current_behavior())
	avatar.gesture("idle")
	var note: Dictionary = {}
	for candidate in game.model.notes:
		if str(candidate.kind) == "tap":
			note = candidate
			break
	game.model.time = float(note.time)
	game._press(int(note.lane))
	game._animate_performer()
	_check(game.model.hits == 1, "Rhythmus: Treffer gezählt")
	_check(rig.get_current_behavior() == "agree_nod", "Rhythmus: Lumo nickt beim Treffer (%s)" % rig.get_current_behavior())
	avatar.gesture("idle")
	game.model.advance(30.0)
	game._animate_performer()
	_check(game.model.misses > 0, "Rhythmus: Fehler gezählt")
	_check(rig.get_current_behavior() == "greeting_wave", "Rhythmus: Lumo muntert nach Fehler auf (%s)" % rig.get_current_behavior())
	avatar.gesture("idle")
	game.cheer_until = game.model.time + 2.0
	game.model.hits += 1
	game._animate_performer()
	_check(rig.get_current_behavior() == "celebrate", "Rhythmus: Lumo jubelt bei der Serie (%s)" % rig.get_current_behavior())
	# Ruhige Bewegung: Lumo bleibt sichtbar, aber die Clips stehen still.
	avatar.set_reduced_motion(true)
	_check(rig.reduced_motion and not rig.player.is_playing(), "Rhythmus: ruhige Bewegung friert Clips ein")
	game.running = false
	game.audio.stop()
	game.queue_free()
	await _frames(2)


## Szenen mit lumo_character.tscn zeigen jetzt das echte Modell.
func _scene_lumo(path: String, label: String) -> void:
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	await _frames(6)
	var lumo: Node3D
	for node in scene.find_children("*", "Node3D", true, false):
		if node.has_method("has_original_lumo"):
			lumo = node
			break
	_check(lumo != null, label + ": Lumo vorhanden")
	if lumo == null:
		scene.queue_free()
		return
	_check(lumo.has_original_lumo(), label + ": echter Lumo geladen")
	var visual_root := lumo.get_node_or_null("VisualRoot") as Node3D
	_check(visual_root != null and not visual_root.is_visible_in_tree(), label + ": Grundformen-Figur unsichtbar")
	_check(_foreign_visible_meshes(lumo, lumo.original_lumo) == 0, label + ": keine sichtbare Ersatzfigur")
	var foot_gap: float = _lowest_point(lumo.original_lumo) - (lumo.global_position.y - lumo.FOOT_DEPTH * lumo.global_transform.basis.get_scale().y)
	_check(absf(foot_gap) < 0.08, label + ": Füße auf Höhe der bisherigen Figur (%.3f m)" % foot_gap)
	lumo.play_behavior("celebrate")
	_check(lumo.original_lumo.get_current_behavior() == "celebrate", label + ": Geste erreicht den echten Lumo")
	lumo.play_behavior("greet")
	_check(lumo.original_lumo.get_current_behavior() == "greeting_wave", label + ": Begrüßung winkt")
	scene.queue_free()
	await _frames(2)
