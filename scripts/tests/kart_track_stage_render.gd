extends SceneTree
## Rendert die Bilder der Streckenwahl-Bühne aus den echten, befahrbaren Strecken.
## Ein Aufruf erzeugt alles neu (wiederholbar nach einem Streckenumbau):
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
##     --fixed-fps 30 --script res://scripts/tests/kart_track_stage_render.gd -- \
##     [--tracks=a,b] [--clips=winter_sprint,jungle_emerald_3600]
##     [--frames=<dir>] [--candidates=<dir>] [--maps-only]
##
## Ergebnis je Strecke: assets/kart/track_stage/<id>.webp (1920×1080, Standbild = erstes
## Clipbild), cards/<id>.webp (512×288) und für --clips clips/<id>.ogv (Theora, stumm,
## 1280×720, 30 fps, ~6,5 s; braucht ffmpeg). --candidates schreibt stattdessen je Strecke
## Probebilder aller Kurven-Kandidaten, um SHOTS zu wählen.
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")
const OUT := "res://assets/kart/track_stage/"
## Kamerapunkt je Strecke: Kurvenscheitel als Anteil der Rundenlänge, Seite der
## Kamera (+1 = außen, −1 = innen) und Höhe. Gewählt am Probebild (Kurve + Landmarke).
const SHOTS := {
	"windwerk_3000": {"f": .052, "back": 55.0, "h": 3.6, "off": -3.5, "abs": 1.0, "ahead": 48.0, "look_lat": -8.5},
	"sonnenhafen": {"f": 0.988, "side": 1.0},
	"zauberwald": {"f": 0.562, "side": 1.0},
	"bergwelt": {"f": 0.156, "side": -1.0},
	"holo_city": {"f": 0.988, "side": 1.0},
	"crystal_canyon": {"f": 0.569, "side": 1.0},
	"jungle_temple": {"f": 0.031, "side": 1.0},
	"candy_cloud": {"f": 0.025, "side": 1.0},
	"volcano_night": {"f": 0.412, "side": 1.0},
	# Passagen-Strecken zeigen ihre neue Engstelle: Vorplatz und Gletscher-Eisbrücke.
	"winter_sprint":
	{
		"f": 0.0563,
		"back": 21.0,
		"travel": 12.0,
		"h": 3.3,
		"off": -3.0,
		"ahead": 22.0,
		"look_lat": 0.0
	},
	"galaxy_ringway": {"f": 0.325, "side": 1.0},
	"desert_drift": {"f": 0.062, "side": 1.0},
	"learning_lab": {"f": 0.800, "side": 1.0},
	# Dschungelherz: Anfahrt auf die Kronenbrücke (Vorplatz, schmales Deck über der Schlucht).
	"jungle_emerald_3600":
	{
		"f": 0.5275,
		"back": 36.0,
		"travel": 7.0,
		"h": 2.8,
		"off": -3.5,
		"ahead": 30.0,
		"look_lat": 0.0
	},
}
const CLIP_SECONDS := 6.5
const FPS := 30
var root_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tracks: Array[String] = []
	var clips: Array[String] = []
	var frames_dir := ""
	var candidates := ""
	var maps_only := false
	for argument in OS.get_cmdline_user_args():
		var text := str(argument)
		if text.begins_with("--tracks="):
			tracks.assign(text.trim_prefix("--tracks=").split(",", false))
		elif text.begins_with("--clips="):
			clips.assign(text.trim_prefix("--clips=").split(",", false))
		elif text.begins_with("--frames="):
			frames_dir = text.trim_prefix("--frames=")
		elif text == "--maps-only":
			maps_only = true
		elif text.begins_with("--candidates="):
			candidates = text.trim_prefix("--candidates=")
	if tracks.is_empty():
		for entry in CATALOG.TRACKS:
			tracks.append(str(entry.id))
	root_dir = ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(root_dir.path_join("cards"))
	DirAccess.make_dir_recursive_absolute(root_dir.path_join("clips"))
	if frames_dir.is_empty():
		frames_dir = OS.get_user_data_dir().path_join("track_stage_frames")
	root.msaa_3d = Viewport.MSAA_4X
	var failures := 0
	var maps := _read_maps()
	for id in tracks:
		var started := Time.get_ticks_msec()
		var world = WORLD.new()
		root.add_child(world)
		world.build(maps_only, id, maps_only)
		for _frame in range(6):
			await process_frame
		var camera := Camera3D.new()
		camera.fov = 56.0
		camera.near = 0.08
		camera.far = 1400.0
		world.add_child(camera)
		camera.current = true
		maps[id] = _map_points(world)
		if maps_only:
			root.remove_child(world)
			world.free()
			continue
		if not candidates.is_empty():
			await _candidates(world, camera, id, candidates)
		else:
			var shot: Dictionary = SHOTS.get(id, _auto_shot(world))
			root.size = Vector2i(1920, 1080)
			_pose(world, camera, shot, 0.0)
			for _frame in range(10):
				await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			failures += _save_still(id, image)
			if clips.has(id):
				failures += await _clip(world, camera, id, shot, frames_dir)
		print(
			(
				"[TrackStageRender] %s fertig in %.1f s"
				% [id, (Time.get_ticks_msec() - started) / 1000.0]
			)
		)
		root.remove_child(world)
		world.queue_free()
		for _frame in range(3):
			await process_frame
	_write_maps(maps)
	print(
		(
			"[TrackStageRender] %s: %d Strecken, %d Fehler"
			% ["PASS" if failures == 0 else "FAIL", tracks.size(), failures]
		)
	)
	quit(0 if failures == 0 else 1)


## Kurven der Strecke, stärkste zuerst, mindestens 7 % der Runde auseinander.
func _bends(world) -> Array[Dictionary]:
	var length: float = world.length
	var samples: Array[Dictionary] = []
	var steps := 160
	for index in range(steps):
		var d := length * index / steps
		var before: Vector3 = world.forward(d - 14.0)
		var after: Vector3 = world.forward(d + 14.0)
		var turn := before.signed_angle_to(after, Vector3.UP)
		samples.append({"f": float(index) / steps, "turn": turn})
	samples.sort_custom(func(a, b): return absf(a.turn) > absf(b.turn))
	var chosen: Array[Dictionary] = []
	for sample in samples:
		var near := false
		for other in chosen:
			var gap := absf(float(sample.f) - float(other.f))
			if minf(gap, 1.0 - gap) < 0.07:
				near = true
		if not near:
			chosen.append(sample)
		if chosen.size() >= 6:
			break
	return chosen


func _auto_shot(world) -> Dictionary:
	var bend: Dictionary = _bends(world)[0]
	return {"f": bend.f, "side": 1.0, "h": 2.4}


## Kamera nahe der Fahrbahn vor dem Kurvenscheitel; t = 0 Standbild, t = 1 Clipende.
## Die Kamera fährt niedrig in die Kurve hinein und schaut am Ende über die Kurve hinaus.
func _pose(world, camera: Camera3D, shot: Dictionary, t: float) -> void:
	var length: float = world.length
	var apex: float = float(shot.f) * length
	var turn: float = world.forward(apex - 14.0).signed_angle_to(
		world.forward(apex + 14.0), Vector3.UP
	)
	# Positive Seitenlage = rechts. Linkskurve: außen ist rechts.
	var outside := 1.0 if turn > 0.0 else -1.0
	var side: float = outside * float(shot.get("side", 1.0))
	if shot.has("abs"):
		# Feste Seite (rechts = +1), wenn die Landmarke an einer geraden Stelle steht.
		side = float(shot.abs)
	var width: float = world.road_width_at(apex)
	var ease_t := smoothstep(0.0, 1.0, t)
	var back: float = float(shot.get("back", 26.0))
	var travel: float = float(shot.get("travel", 30.0))
	var eye_d := apex - back + travel * ease_t
	var lateral := side * (width * 0.5 + float(shot.get("off", 2.0))) * (1.0 - 0.55 * ease_t)
	var height: float = float(shot.get("h", 2.9)) + 0.8 * ease_t
	var eye: Vector3 = world.position_at(eye_d, lateral) + Vector3.UP * height
	var look_d := eye_d + float(shot.get("ahead", 30.0)) + 8.0 * ease_t
	var look: Vector3 = (
		world.position_at(look_d, float(shot.get("look_lat", -side * width * 0.2)))
		+ Vector3.UP * float(shot.get("lh", 1.3))
	)
	camera.fov = float(shot.get("fov", 56.0))
	camera.look_at_from_position(eye, look, Vector3.UP)


func _candidates(world, camera: Camera3D, id: String, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(640, 360)
	var bends := _bends(world)
	var tiles: Array[Image] = []
	var labels: Array[String] = []
	for bend in bends:
		for side in [1.0, -1.0]:
			_pose(world, camera, {"f": bend.f, "side": side}, 0.0)
			for _frame in range(5):
				await process_frame
			await RenderingServer.frame_post_draw
			tiles.append(root.get_texture().get_image())
			labels.append("f=%.3f side=%+d" % [bend.f, side])
	var sheet := Image.create(640 * 3, 360 * ceili(tiles.size() / 3.0), false, Image.FORMAT_RGB8)
	for index in range(tiles.size()):
		var tile := tiles[index]
		tile.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(
			tile, Rect2i(0, 0, 640, 360), Vector2i((index % 3) * 640, (index / 3) * 360)
		)
	sheet.save_jpg(dir.path_join("%s_kandidaten.jpg" % id), 0.8)
	print("[TrackStageRender] Kandidaten %s: %s" % [id, " | ".join(labels)])


func _save_still(id: String, image: Image) -> int:
	image.convert(Image.FORMAT_RGB8)
	var still_path := root_dir.path_join(id + ".webp")
	var error := image.save_webp(still_path, true, 0.82)
	var card := image.duplicate()
	card.resize(512, 288, Image.INTERPOLATE_LANCZOS)
	error = (
		error
		if error != OK
		else card.save_webp(root_dir.path_join("cards/%s.webp" % id), true, 0.85)
	)
	var bytes := FileAccess.get_file_as_bytes(still_path).size()
	print(
		(
			"[TrackStageRender] Standbild %s %dx%d %d KB"
			% [id, image.get_width(), image.get_height(), bytes / 1024]
		)
	)
	if error != OK or bytes > 300 * 1024:
		push_error("[TrackStageRender] Standbild %s: Fehler %d, %d KB" % [id, error, bytes / 1024])
		return 1
	return 0


func _clip(world, camera: Camera3D, id: String, shot: Dictionary, frames_dir: String) -> int:
	var dir := frames_dir.path_join(id)
	DirAccess.make_dir_recursive_absolute(dir)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	root.size = Vector2i(1280, 720)
	var count := int(CLIP_SECONDS * FPS)
	for index in range(count):
		_pose(world, camera, shot, float(index) / float(count - 1))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("%04d.png" % index))
		if index % 30 == 0:
			print("[TrackStageRender] Clip %s Bild %d/%d" % [id, index, count])
	var target := root_dir.path_join("clips/%s.ogv" % id)
	var output: Array = []
	var code := OS.execute(
		"ffmpeg",
		[
			"-y",
			"-loglevel",
			"error",
			"-framerate",
			str(FPS),
			"-i",
			dir.path_join("%04d.png"),
			"-c:v",
			"libtheora",
			"-b:v",
			"1500k",
			"-g",
			"30",
			"-pix_fmt",
			"yuv420p",
			"-an",
			target
		],
		output,
		true
	)
	var bytes := (
		FileAccess.get_file_as_bytes(target).size() if FileAccess.file_exists(target) else 0
	)
	print(
		(
			"[TrackStageRender] Clip %s: %d Bilder, %d KB, ffmpeg=%d %s"
			% [id, count, bytes / 1024, code, "".join(output)]
		)
	)
	return 0 if code == 0 and bytes > 0 else 1


## Kleine Karte: 64 Punkte der echten Mittellinie (x, z), auf 0..1 normiert.
func _map_points(world) -> Array:
	var points: Array[Vector2] = []
	var route: Curve3D = world.curve
	for sample in range(64):
		var point := route.sample_baked(route.get_baked_length() * sample / 64.0)
		points.append(Vector2(point.x, point.z))
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var extent := maxf(bounds.size.x, bounds.size.y)
	var result: Array = []
	for point in points:
		var normal := (point - bounds.position) / extent
		result.append([snappedf(normal.x, 0.001), snappedf(normal.y, 0.001)])
	return result


func _read_maps() -> Dictionary:
	var path := "res://scripts/games/kart_track_maps.gd"
	if ResourceLoader.exists(path):
		return (load(path).POINTS as Dictionary).duplicate(true)
	return {}


func _write_maps(maps: Dictionary) -> void:
	var ids := maps.keys()
	ids.sort()
	var lines: Array[String] = [
		"extends RefCounted",
		"## Mittellinien der Strecken für die kleine Karte der Streckenwahl.",
		"## Erzeugt von scripts/tests/kart_track_stage_render.gd – nicht von Hand ändern.",
		"const POINTS := {",
	]
	for id in ids:
		var pairs: Array[String] = []
		for point in maps[id]:
			pairs.append("[%s, %s]" % [point[0], point[1]])
		# Gleiche Form wie gdformat, damit ein Neuerzeugen nur echte Änderungen zeigt.
		lines.append('\t"%s":' % id)
		lines.append("\t[")
		for pair in pairs:
			lines.append("\t\t%s," % pair)
		lines.append("\t],")
	lines.append("}")
	var file := FileAccess.open(
		ProjectSettings.globalize_path("res://scripts/games/kart_track_maps.gd"), FileAccess.WRITE
	)
	file.store_string("\n".join(lines) + "\n")
	file.close()
