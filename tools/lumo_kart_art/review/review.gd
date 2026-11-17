extends Node3D
## Isolated, reproducible visual review. Production race scenes are untouched.

const THEMES := ["zauberwald", "bergwelt", "holo_city", "crystal_canyon", "jungle_temple", "candy_cloud", "volcano_night", "winter_sprint", "galaxy_ringway", "desert_drift", "learning_lab"]
const DRIVER_CLIPS := ["kart_seated", "kart_steer_left", "kart_steer_right", "kart_jump", "celebrate", "idle"]
var repo := ""
var evidence := ""
var frame_root := ""
var content: Node3D
var camera: Camera3D
var heading: Label
var subheading: Label
var world_environment: WorldEnvironment
var players: Array[AnimationPlayer] = []
var views: Array[Dictionary] = []
var view_index := 0
var capture_running := false
var records: Array = []


func _ready() -> void:
	repo = ProjectSettings.globalize_path("res://../../../").simplify_path().trim_suffix("/")
	evidence = repo.path_join("evidence/lumo_kart_art/review")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--repo="):
			repo = arg.trim_prefix("--repo=")
		elif arg.begins_with("--out="):
			evidence = arg.trim_prefix("--out=")
		elif arg.begins_with("--frames-root="):
			frame_root = arg.trim_prefix("--frames-root=")
	if frame_root.is_empty():
		frame_root = evidence
	_make_stage()
	_make_views()
	if views.is_empty():
		heading.text = "LUMO · keine exportierten Modelle gefunden"
		return
	var initial_view := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--view="):
			for index in views.size():
				if views[index].name == arg.trim_prefix("--view="):
					initial_view = index
	_show_view(initial_view)
	if "--suite" in OS.get_cmdline_user_args():
		_run_suite.call_deferred()
	elif "--movies" in OS.get_cmdline_user_args():
		_run_movies.call_deferred()
	elif "--movie=karts" in OS.get_cmdline_user_args():
		_run_one_movie.call_deferred("karts")
	elif "--movie=drivers" in OS.get_cmdline_user_args():
		_run_one_movie.call_deferred("drivers")
	elif "--movie=tunnel" in OS.get_cmdline_user_args():
		_run_one_movie.call_deferred("tunnel")
	elif "--capture" in OS.get_cmdline_user_args():
		_capture_all.call_deferred()


func _make_stage() -> void:
	content = Node3D.new()
	add_child(content)
	world_environment = WorldEnvironment.new()
	world_environment.environment = Environment.new()
	var env := world_environment.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("152639")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4d4e4")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -28, 0)
	key.light_color = Color("fff1d7")
	key.light_energy = 1.5
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 148, 0)
	fill.light_color = Color("b2d5f7")
	fill.light_energy = 0.65
	add_child(fill)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 200.0
	camera.fov = 45.0
	add_child(camera)
	camera.current = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := ColorRect.new()
	panel.color = Color(0.025, 0.055, 0.09, 0.9)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 82.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	heading = Label.new()
	heading.position = Vector2(30, 14)
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color("eff8ff"))
	canvas.add_child(heading)
	subheading = Label.new()
	subheading.position = Vector2(30, 49)
	subheading.add_theme_font_size_override("font_size", 16)
	subheading.add_theme_color_override("font_color", Color("9ac9df"))
	canvas.add_child(subheading)
	var capture_button := Button.new()
	capture_button.text = "Prüfbilder"
	capture_button.position = Vector2(1010, 16)
	capture_button.custom_minimum_size = Vector2(140, 48)
	capture_button.pressed.connect(_capture_all)
	canvas.add_child(capture_button)
	var movie_button := Button.new()
	movie_button.text = "Kamerafahrt"
	movie_button.position = Vector2(1164, 16)
	movie_button.custom_minimum_size = Vector2(160, 48)
	movie_button.pressed.connect(_record_tunnel)
	canvas.add_child(movie_button)


func _make_views() -> void:
	views = [
		{"name": "assembly_front", "kind": "assembly", "clip": "kart_seated", "camera": Vector3(3.35, 2.55, -4.9), "target": Vector3(0, 1.15, 0), "fov": 42.0},
		{"name": "assembly_race_camera", "kind": "assembly", "clip": "kart_seated", "camera": Vector3(0, 2.52, 4.35), "target": Vector3(0, 0.78, -4.15), "fov": 55.0},
		{"name": "assembly_rear", "kind": "assembly", "clip": "kart_seated", "camera": Vector3(-3.4, 2.45, 4.9), "target": Vector3(0, 1.12, 0), "fov": 43.0},
		{"name": "assembly_left_steer", "kind": "assembly", "clip": "kart_steer_left", "camera": Vector3(2.7, 2.7, -3.8), "target": Vector3(0, 1.2, 0), "fov": 40.0},
		{"name": "assembly_right_steer", "kind": "assembly", "clip": "kart_steer_right", "camera": Vector3(2.7, 2.7, -3.8), "target": Vector3(0, 1.2, 0), "fov": 40.0},
		{"name": "kart_underside", "kind": "kart", "camera": Vector3(2.8, -1.8, -3.8), "target": Vector3(0, 0.48, 0), "fov": 42.0},
		{"name": "kart_side_profile", "kind": "kart", "camera": Vector3(4.8, 1.2, 0), "target": Vector3(0, 0.6, 0), "fov": 42.0},
		{"name": "rabbit_rear", "kind": "driver", "clip": "kart_seated", "camera": Vector3(-2.25, 2.0, 3.8), "target": Vector3(0, 1.3, 0), "fov": 38.0},
	]
	for clip in DRIVER_CLIPS:
		views.append({"name": "rabbit_" + clip, "kind": "driver", "clip": clip, "camera": Vector3(2.25, 2.0, -3.8), "target": Vector3(0, 1.3, 0), "fov": 38.0})
	for id in ["lion", "owl", "squirrel", "turtle"]:
		if FileAccess.file_exists(repo.path_join("assets/kart/production/drivers/" + id + "/driver.glb")):
			views.append({"name": id + "_kart_seated", "kind": "driver", "driver": id, "clip": "kart_seated", "camera": Vector3(2.25, 2.0, -3.8), "target": Vector3(0, 1.3, 0), "fov": 38.0})
			views.append({"name": id + "_rear", "kind": "driver", "driver": id, "clip": "kart_seated", "camera": Vector3(-2.25, 2.0, 3.8), "target": Vector3(0, 1.3, 0), "fov": 38.0})
	for id in ["comet", "glider", "turbo"]:
		views.append({"name": id + "_front", "kind": "assembly", "kart": id, "clip": "kart_seated", "camera": Vector3(3.35, 2.55, -4.9), "target": Vector3(0, 1.15, 0), "fov": 42.0})
		views.append({"name": id + "_rear", "kind": "assembly", "kart": id, "clip": "kart_seated", "camera": Vector3(-3.4, 2.45, 4.9), "target": Vector3(0, 1.12, 0), "fov": 43.0})
	for theme in THEMES:
		if FileAccess.file_exists(repo.path_join("assets/kart/production/tracks/" + theme + "/straight_12m.glb")):
			views.append({"name": theme + "_interior", "kind": "tunnel", "theme": theme, "camera": Vector3(0, 2.52, -1), "target": Vector3(0, 2.7, -10), "fov": 62.0})
			views.append({"name": theme + "_curve_joint", "kind": "tunnel", "theme": theme, "camera": Vector3(0, 2.52, -8), "target": Vector3(1, 2.7, -18), "fov": 62.0})
			views.append({"name": theme + "_portal", "kind": "portal", "theme": theme, "camera": Vector3(25, 20, 30), "target": Vector3(2, 4, -12), "fov": 45.0})
	views.append({"name": "sonnenhafen_asset_comparison", "kind": "comparison", "camera": Vector3(28, 17, 32), "target": Vector3(0, 3, 0), "fov": 48.0})
	if FileAccess.file_exists(repo.path_join("evidence/lumo_kart_art/tracks/normal_probe/zauberwald_straight_12m_smooth_caps.glb")):
		views.append({"name": "terrain_normals_comparison", "kind": "normal_comparison", "camera": Vector3(0, 42, 38), "target": Vector3(0, 5, -12), "fov": 58.0})


func _load_model(relative: String) -> Node3D:
	var path := repo.path_join(relative)
	if not FileAccess.file_exists(path):
		push_error("Asset missing: " + relative)
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("GLB import failed: " + relative)
		return null
	var model := doc.generate_scene(state, 30.0, false, false) as Node3D
	return model


func _collect_players(node: Node) -> void:
	if node is AnimationPlayer:
		if not players.has(node):
			players.append(node)
		node.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for child in node.get_children():
		_collect_players(child)


func _play(node: Node, clip: String, at: float = 0.35) -> void:
	_collect_players(node)
	for player in players:
		if player.has_animation(clip):
			player.play(clip, 0.0)
			player.seek(at, true)
			player.advance(0.0)


func _steer_kart(kart: Node3D, clip: String, at: float, duration: float) -> void:
	var turn := 0.0
	if clip == "kart_steer_left" or clip == "kart_steer_right":
		# The exported driver keys start at Blender frame 1 (1/24 s).
		var t := clampf((at - 1.0 / 24.0) / maxf(duration - 1.0 / 24.0, 0.001), 0.0, 1.0)
		turn = sin(PI * minf(1.0, t / 0.25) / 2.0) if t < 0.25 else 1.0 if t < 0.75 else cos(PI * (t - 0.75) / 0.25 / 2.0)
		if clip == "kart_steer_right":
			turn = -turn
	var steering := kart.find_child("SteeringWheel", true, false) as Node3D
	if steering != null:
		if not steering.has_meta("review_rest_basis"):
			steering.set_meta("review_rest_basis", steering.basis)
		steering.basis = (steering.get_meta("review_rest_basis") as Basis) * Basis(Vector3.BACK, -turn * 0.4)
	for name in ["Steer_FL", "Steer_FR"]:
		var pivot := kart.find_child(name, true, false) as Node3D
		if pivot != null:
			pivot.rotation.y = turn * 0.34


func _clip_duration(clip: String) -> float:
	for player in players:
		if player.has_animation(clip):
			return player.get_animation(clip).length
	return 1.0


func _ground() -> void:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100, 140)
	mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("3c4d5c")
	material.roughness = 0.86
	mesh.material_override = material
	mesh.position = Vector3(0, -0.018, -40)
	content.add_child(mesh)


func _show_view(index: int) -> void:
	view_index = posmod(index, views.size())
	for child in content.get_children():
		child.free()
	players.clear()
	var view := views[view_index]
	var kind: String = view.kind
	var assembly_kart: Node3D = null
	if kind != "kart":
		_ground()
	if kind == "assembly" or kind == "kart":
		var kart := _load_model("assets/kart/production/karts/aurora_" + str(view.get("kart", "comet")) + ".glb")
		if kart != null:
			content.add_child(kart)
			assembly_kart = kart
	if kind == "assembly" or kind == "driver":
		var driver_id: String = view.get("driver", "rabbit")
		var driver := _load_model("assets/kart/production/drivers/" + driver_id + "/driver.glb")
		if driver != null:
			content.add_child(driver)
			_play(driver, view.get("clip", "kart_seated"))
			if assembly_kart != null:
				_steer_kart(assembly_kart, view.get("clip", "kart_seated"), 0.35, _clip_duration(view.get("clip", "kart_seated")))
	if kind == "portal":
		var portal := _load_model("assets/kart/production/tracks/" + str(view.theme) + "/portal_entry.glb")
		if portal != null:
			content.add_child(portal)
			_add_terrain_cover(portal, str(view.theme), "portal_entry")
			_add_tunnel_lights(portal)
			var previous: Node3D = portal
			for module_name in ["straight_12m", "curve_right_30", "portal_exit"]:
				var next := _load_model("assets/kart/production/tracks/" + str(view.theme) + "/" + str(module_name) + ".glb")
				if next == null:
					continue
				content.add_child(next)
				_join_modules(previous, next)
				_add_terrain_cover(next, str(view.theme), str(module_name))
				_add_tunnel_lights(next)
				previous = next
	if kind == "tunnel":
		var prefix: String = "assets/kart/production/tracks/" + str(view.theme) + "/"
		var straight := _load_model(prefix + "straight_12m.glb")
		var curve := _load_model(prefix + "curve_right_30.glb")
		if straight != null:
			content.add_child(straight)
		if curve != null and straight != null:
			content.add_child(curve)
			var outlet := straight.find_child("SocketOut", true, false) as Node3D
			var inlet := curve.find_child("SocketIn", true, false) as Node3D
			if outlet != null and inlet != null:
				var local_inlet := curve.global_transform.affine_inverse() * inlet.global_transform
				curve.global_transform = outlet.global_transform * local_inlet.affine_inverse()
		if straight != null:
			_add_tunnel_lights(straight)
			_add_terrain_cover(straight, str(view.theme), "straight_12m")
		if curve != null:
			_add_tunnel_lights(curve)
			_add_terrain_cover(curve, str(view.theme), "curve_right_30")
	if kind == "comparison":
		var original := _load_model("assets/kart/harbor_pavilion/wave_pavilion_lod0.glb")
		var tunnel := _load_model("assets/kart/production/tracks/zauberwald/portal_entry.glb")
		if original != null:
			content.add_child(original)
			original.position.x = -10.0
		if tunnel != null:
			content.add_child(tunnel)
			tunnel.position.x = 10.0
			_add_terrain_cover(tunnel, "zauberwald", "portal_entry")
	if kind == "normal_comparison":
		for spec in [["smooth_caps", -16.0], ["flat_caps", 16.0]]:
			for distance in [0.0, -12.0]:
				var relative := "evidence/lumo_kart_art/tracks/normal_probe/zauberwald_straight_12m_" + str(spec[0]) + ".glb"
				var model := _load_model(relative)
				if model != null:
					content.add_child(model)
					model.position = Vector3(float(spec[1]), 0, float(distance))
	camera.fov = float(view.fov)
	camera.look_at_from_position(view.camera, view.target)
	heading.text = "LUMO KART · " + str(view.name).replace("_", " ")
	subheading.text = "Godot 4.6 · Blender-Modelle · Ansicht %d/%d · Pfeiltasten: wechseln" % [view_index + 1, views.size()]
	if kind == "normal_comparison":
		heading.text = "LUMO KART · Terrain-Normalen · Vorher / Nachher"
		subheading.text = "Links: geglättete Endkappen · Rechts: getrennte Randnormalen · identische Kontur und Dreiecke"


func _add_tunnel_lights(model: Node3D) -> void:
	# Match the authored socket identifier even when a GLB exporter added a prefix.
	for marker in model.find_children("*LightSocket*", "Node3D", true, false):
		var light := OmniLight3D.new()
		light.position = marker.global_position
		light.light_color = Color("d8eadf")
		light.light_energy = 1.75
		light.omni_range = 11.0
		light.omni_attenuation = 0.8
		light.shadow_enabled = false
		content.add_child(light)


func _add_terrain_cover(model: Node3D, theme: String, module_name: String) -> void:
	var relative := "assets/kart/production/tracks/" + theme + "/" + module_name + "_terrain.glb"
	if not FileAccess.file_exists(repo.path_join(relative)):
		return
	var cover := _load_model(relative)
	if cover != null:
		content.add_child(cover)
		cover.global_transform = model.global_transform


func _join_modules(previous: Node3D, following: Node3D) -> void:
	var outlet := previous.find_child("SocketOut", true, false) as Node3D
	var inlet := following.find_child("SocketIn", true, false) as Node3D
	if outlet != null and inlet != null:
		var local_inlet := following.global_transform.affine_inverse() * inlet.global_transform
		following.global_transform = outlet.global_transform * local_inlet.affine_inverse()


func _unhandled_key_input(event: InputEvent) -> void:
	if capture_running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT:
			_show_view(view_index + 1)
		elif event.keycode == KEY_LEFT:
			_show_view(view_index - 1)


func _capture_all() -> void:
	if capture_running:
		return
	capture_running = true
	records.clear()
	DirAccess.make_dir_recursive_absolute(evidence)
	for index in views.size():
		_show_view(index)
		for frame in range(2):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if image == null or image.is_empty():
			push_error("Renderer returned no image")
			continue
		var name: String = str(views[index].name) + "_godot.png"
		var path := evidence.path_join(name)
		if image.save_png(path) != OK:
			push_error("Failed to save " + path)
			continue
		records.append({"view": views[index].name, "image": name,
			"sha256": FileAccess.get_sha256(path), "width": image.get_width(), "height": image.get_height(),
			"driver_clip": views[index].get("clip", ""), "camera_fov": camera.fov})
	var file := FileAccess.open(evidence.path_join("godot_render_capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"godot": Engine.get_version_info().string,
			"renderer": RenderingServer.get_video_adapter_name(), "physical_android": false,
			"product_runtime_changed": false, "sources": _source_hashes(), "captures": records,
			"review_script_sha256": FileAccess.get_sha256("res://review.gd")}, "  "))
		file.close()
	print("[LumoKartArtRender] captured ", records.size(), " actual Godot images")
	capture_running = false
	_show_view(0)
	if "--quit-after-capture" in OS.get_cmdline_user_args():
		get_tree().quit(0)


func _path_position(distance: float) -> Vector3:
	if distance <= 12.0:
		return Vector3(0, 2.52, -distance)
	var angle := (distance - 12.0) / 36.0
	return Vector3(36.0 * (1.0 - cos(angle)), 2.52, -12.0 - 36.0 * sin(angle))


func _record_tunnel() -> void:
	if capture_running:
		return
	var index := -1
	for item in views.size():
		if views[item].name == "zauberwald_interior":
			index = item
	if index < 0:
		return
	capture_running = true
	_show_view(index)
	var folder := frame_root.path_join("tunnel_frames")
	DirAccess.make_dir_recursive_absolute(folder)
	var captured: Array = []
	for frame in range(96):
		var distance := lerpf(0.75, 27.0, float(frame) / 95.0)
		camera.look_at_from_position(_path_position(distance), _path_position(distance + 3.8))
		camera.fov = 62.0
		heading.text = "LUMO KART · Zauberwald · Kurvenfahrt"
		subheading.text = "Kamerahöhe 2,52 m · durchgehende Hülle · Gerade und R36-Kurve"
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if image == null or image.is_empty():
			push_error("Empty flythrough frame")
			break
		var path := folder.path_join("%04d.png" % frame)
		if image.save_png(path) != OK:
			push_error("Cannot save flythrough frame")
			break
		captured.append({"frame": frame, "sha256": FileAccess.get_sha256(path), "distance_m": distance})
	var file := FileAccess.open(evidence.path_join("tunnel_capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"frames": captured, "fps": 24, "camera_height_m": 2.52,
			"curve_radius_m": 36.0, "renderer": RenderingServer.get_video_adapter_name(), "physical_android": false,
			"sources": _source_hashes()}, "  "))
		file.close()
	capture_running = false
	_show_view(0)
	print("[LumoKartTunnelMovie] frames=", captured.size())


func _source_hashes() -> Dictionary:
	var hashes := {}
	for id in ["comet", "glider", "turbo"]:
		var path: String = "assets/kart/production/karts/aurora_" + str(id) + ".glb"
		hashes[path] = FileAccess.get_sha256(repo.path_join(path))
	for id in ["rabbit", "lion", "owl", "squirrel", "turtle"]:
		var path: String = "assets/kart/production/drivers/" + str(id) + "/driver.glb"
		if FileAccess.file_exists(repo.path_join(path)):
			hashes[path] = FileAccess.get_sha256(repo.path_join(path))
	for theme in THEMES:
		for module_name in ["portal_entry", "straight_12m", "curve_right_30", "portal_exit"]:
			var path: String = "assets/kart/production/tracks/" + str(theme) + "/" + str(module_name) + ".glb"
			if FileAccess.file_exists(repo.path_join(path)):
				hashes[path] = FileAccess.get_sha256(repo.path_join(path))
			var cover_path := path.trim_suffix(".glb") + "_terrain.glb"
			if FileAccess.file_exists(repo.path_join(cover_path)):
				hashes[cover_path] = FileAccess.get_sha256(repo.path_join(cover_path))
	for mode in ["smooth_caps", "flat_caps"]:
		var path: String = "evidence/lumo_kart_art/tracks/normal_probe/zauberwald_straight_12m_" + str(mode) + ".glb"
		if FileAccess.file_exists(repo.path_join(path)):
			hashes[path] = FileAccess.get_sha256(repo.path_join(path))
	return hashes


func _clear_stage() -> void:
	for child in content.get_children():
		child.free()
	players.clear()


func _movie_frame(folder: String, frame: int) -> Dictionary:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Renderer returned empty movie frame")
		return {}
	var path := folder.path_join("%04d.png" % frame)
	if image.save_png(path) != OK:
		push_error("Cannot save movie frame: " + path)
		return {}
	return {"frame": frame, "sha256": FileAccess.get_sha256(path), "width": image.get_width(), "height": image.get_height()}


func _movie_receipt(name: String, frames: Array) -> void:
	var file := FileAccess.open(evidence.path_join(name + "_capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"frames": frames, "fps": 24, "godot": Engine.get_version_info().string,
			"renderer": RenderingServer.get_video_adapter_name(), "physical_android": false,
			"product_runtime_changed": false, "sources": _source_hashes(),
			"review_script_sha256": FileAccess.get_sha256("res://review.gd")}, "  "))
		file.close()
	print("[LumoKartArtMovie] ", name, " frames=", frames.size())


func _record_karts() -> void:
	if capture_running:
		return
	capture_running = true
	var folder := frame_root.path_join("turntable_frames")
	DirAccess.make_dir_recursive_absolute(folder)
	var frames: Array = []
	for id in ["comet", "glider", "turbo"]:
		_clear_stage()
		_ground()
		var kart := _load_model("assets/kart/production/karts/aurora_" + id + ".glb")
		if kart == null:
			continue
		content.add_child(kart)
		_play(kart, "mechanical_demo", 0.0)
		var duration := _clip_duration("mechanical_demo")
		for step in range(48):
			var t := float(step) / 48.0
			_play(kart, "mechanical_demo", duration * t)
			var angle := TAU * t
			camera.look_at_from_position(Vector3(3.8 * sin(angle), 1.85, -3.8 * cos(angle)), Vector3(0, 0.6, 0))
			camera.fov = 45.0
			heading.text = "LUMO KART · Aurora " + str(id).capitalize()
			subheading.text = "Echte GLB-Animation · Räder, Vorderachslenkung und Lenkrad"
			var record: Dictionary = await _movie_frame(folder, frames.size())
			if record.is_empty():
				break
			record.merge({"kart": id, "clip": "mechanical_demo", "clip_time": duration * t})
			frames.append(record)
	_movie_receipt("turntable", frames)
	capture_running = false
	_show_view(0)


func _record_drivers() -> void:
	if capture_running:
		return
	capture_running = true
	var folder := frame_root.path_join("animation_frames")
	DirAccess.make_dir_recursive_absolute(folder)
	var frames: Array = []
	var segments: Array[Dictionary] = []
	for clip in DRIVER_CLIPS:
		segments.append({"id": "rabbit", "clip": clip, "frames": 36})
	for id in ["lion", "owl", "squirrel", "turtle"]:
		segments.append({"id": id, "clip": "kart_seated", "frames": 24})
	for segment in segments:
		_clear_stage()
		_ground()
		var driver := _load_model("assets/kart/production/drivers/" + str(segment.id) + "/driver.glb")
		if driver == null:
			continue
		content.add_child(driver)
		var clip: String = segment.clip
		var kart: Node3D = null
		if clip != "idle":
			kart = _load_model("assets/kart/production/karts/aurora_comet.glb")
			if kart != null:
				content.add_child(kart)
		_play(driver, clip, 0.0)
		var duration := _clip_duration(clip)
		for step in int(segment.frames):
			var t := float(step) / float(int(segment.frames) - 1)
			_play(driver, clip, duration * t)
			if kart != null:
				_steer_kart(kart, clip, duration * t, duration)
			var angle := -0.42 + t * 0.84
			camera.look_at_from_position(Vector3(4.6 * sin(angle), 2.25, -4.6 * cos(angle)), Vector3(0, 0.86 if clip == "idle" else 1.15, 0))
			camera.fov = 40.0
			heading.text = "LUMO FAHRER · " + str(segment.id).capitalize() + " · " + clip
			subheading.text = "21-Knochen-Rig · tatsächliche Animationskanäle · gemeinsame Kart-Kontaktpunkte"
			var record: Dictionary = await _movie_frame(folder, frames.size())
			if record.is_empty():
				break
			record.merge({"driver": segment.id, "clip": clip, "clip_time": duration * t})
			frames.append(record)
	_movie_receipt("animation", frames)
	capture_running = false
	_show_view(0)


func _run_movies() -> void:
	await _record_tunnel()
	await _record_karts()
	await _record_drivers()
	if "--quit-after-suite" in OS.get_cmdline_user_args():
		get_tree().quit(0)


func _run_suite() -> void:
	await _capture_all()
	await _run_movies()


func _run_one_movie(kind: String) -> void:
	match kind:
		"karts": await _record_karts()
		"drivers": await _record_drivers()
		"tunnel": await _record_tunnel()
	if "--quit-after-suite" in OS.get_cmdline_user_args():
		get_tree().quit(0)
