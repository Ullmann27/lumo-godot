extends SceneTree
## Bildbeleg der Holo-Bildmodelle (Namenwort-, Wiewort-, Silben- und Leseraum)
## mit echtem Renderer: alle Figuren nebeneinander auf dem Holo-Podest, gleiches
## Licht wie im Lernraum. Aufruf (xvfb, gl_compatibility):
## godot --path . --rendering-method gl_compatibility --audio-driver Dummy
##   --script res://scripts/tests/holo_models_capture.gd -- --output=DIR [--calm] [--first=N]

const MODELS = preload("res://scripts/learning/holo/holo_models.gd")
const FIGURES = preload("res://scripts/learning/holo/holo_figures.gd")

var output := "res://exports/holo-models"
var calm := false
## Nur die ersten N Figuren (Vorher/Nachher mit gleichem Ausschnitt).
var only_first := 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument == "--calm":
			calm = true
		elif argument.begins_with("--first="):
			only_first = int(argument.trim_prefix("--first="))
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[HoloModels] real renderer required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1800, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("081a33")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b9d6f5")
	settings.ambient_light_energy = 0.55
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_white = 6.0
	settings.glow_enabled = not calm
	settings.glow_intensity = 0.55
	settings.glow_bloom = 0.06
	settings.glow_hdr_threshold = 1.1
	environment.environment = settings
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58, -24, 0)
	key.light_color = Color("fff1d6")
	key.light_energy = 1.05
	key.shadow_enabled = not calm
	key.shadow_opacity = 0.72
	stage.add_child(key)
	var floor_plate := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(26, 0.1, 5)
	floor_plate.mesh = plate
	floor_plate.material_override = MODELS.flat(Color("17406a"), 0.35, 0.4)
	floor_plate.position.y = -0.05
	stage.add_child(floor_plate)
	var ids: Array[String] = []
	ids.assign(FIGURES.PICTURES)
	ids.append_array(FIGURES.PROPS)
	if only_first > 0:
		ids.resize(only_first)
	var step := 1.9
	for index in range(ids.size()):
		var figure: Node3D = FIGURES.build(ids[index])
		figure.position = Vector3((index - (ids.size() - 1) * 0.5) * step, 0.0, 0.0)
		figure.rotation.y = -0.45
		figure.scale = Vector3.ONE * 1.4
		stage.add_child(figure)
		var label := Label3D.new()
		label.text = ids[index]
		label.font_size = 64
		label.pixel_size = 0.004
		label.position = figure.position + Vector3(0, -0.02, 1.0)
		label.rotation_degrees = Vector3(-60, 0, 0)
		stage.add_child(label)
	var camera := Camera3D.new()
	camera.fov = 32
	stage.add_child(camera)
	var width := ids.size() * step
	camera.position = Vector3(0, width * 0.3, width * 0.98)
	camera.look_at(Vector3(0, 0.55, 0))
	camera.current = true
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := output.path_join("holo-modelle%s.png" % ("-ruhig" if calm else ""))
	var saved := image.save_png(path) == OK
	print("[HoloModels] saved=%s figures=%d path=%s" % [saved, ids.size(), path])
	stage.queue_free()
	for frame in range(4):
		await process_frame
	var sound := root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	await create_timer(0.4).timeout
	quit(0 if saved else 1)
