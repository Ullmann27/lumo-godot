extends SceneTree
## Actual ResourceLoader, real boot/rig and real router transition.
## Stable screenshots hold the ready state only in this harness, never the app.
var checks := 0
var failures := 0
var output := "/tmp/lumo-kart-loading"
var evidence: Array = []
var navigation_only := false


func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		output = OS.get_cmdline_user_args()[0]
	navigation_only = "--navigation-only" in OS.get_cmdline_user_args()
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("[KartLoading] " + label)


func _settle(frames := 4) -> void:
	for frame in range(frames):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _wait_ready(boot) -> void:
	var prior := 0.0
	for frame in range(400):
		await process_frame
		_check(boot.actual_progress >= prior, "Engine progress stays monotonic within one attempt")
		prior = boot.actual_progress
		if boot.load_phase != "loading":
			break
	_check(boot.load_phase == "ready", "Real threaded scene/model become ready before timeout")
	_check(is_equal_approx(boot.actual_progress, 1.0), "Ready corresponds to both engine resources loaded")


func _check_model_textures(scene: PackedScene) -> void:
	var model := scene.instantiate()
	var materials := 0
	var identities := {}
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material = mesh.mesh.surface_get_material(surface)
			if not material is StandardMaterial3D:
				continue
			materials += 1
			for texture in [material.albedo_texture, material.normal_texture,
					material.roughness_texture, material.metallic_texture]:
				_check(texture is Texture2D, "Imported Lumo retains each original material texture")
				if texture is Texture2D:
					_check(texture.get_width() > 0 and texture.get_height() > 0,
						"Real embedded texture has actual dimensions")
					_check(not texture.resource_path.ends_with(".png"),
						"Native model never depends on newly extracted PNG sidecars")
					identities[texture.get_instance_id()] = true
	_check(materials > 0 and identities.size() >= 3,
		"Native packed Lumo retains distinct albedo, normal and PBR images")
	model.free()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var host = root.get_node("HostBridge")
	var router = root.get_node("SceneRouter")
	host._options = {"soundEnabled": false, "reduceAnimations": false, "displayDensity": 1.0}
	var baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var boot = load("res://scenes/app/boot.tscn").instantiate()
	boot.auto_begin = false
	boot.auto_transition = false
	root.add_child(boot)
	current_scene = boot
	await _settle()
	boot._begin_loading("kart")
	_check(boot.load_phase == "loading", "Actual boot starts a real request")
	await _wait_ready(boot)
	_check(boot._resources.size() == 2, "Scene and native imported GLB, not a fictitious timer")
	_check(boot._resources[boot.LUMO_MODEL] is PackedScene, "Imported character is genuinely loaded")
	_check_model_textures(boot._resources[boot.LUMO_MODEL])
	_check(is_instance_valid(boot._hero.lumo_animation), "Actual loading screen attaches the existing rig")
	_check(boot._hero.lumo_animation.actor.skeleton.get_bone_count() == 65, "Same 65-bone Lumo")
	_check(not boot._hero.driver.visible, "No competing static Lumo in loading screen")
	_check(not boot.get_node("Layer/LoadBar").indeterminate, "Known engine progress is determinate")
	_check(not boot.get_node("Layer/LoadBar").show_percentage, "No false precision for overall initialization")
	_check(not boot._retry_row.visible, "No spurious retry while successfully ready")
	_check(router.goto_loaded("kart", PackedScene.new()) == ERR_INVALID_PARAMETER,
		"Router rejects an unusable packed scene before altering navigation")
	var matrix := [
		[Vector2i(360, 800), 1.0],
		[Vector2i(640, 360), 1.0],
		[Vector2i(1200, 896), 1.0],
		[Vector2i(2176, 1812), 2.25],
	]
	if navigation_only:
		matrix = []
	for sample in matrix:
		var pixels: Vector2i = sample[0]
		host._options["displayDensity"] = sample[1]
		root.size = pixels
		await _settle()
		boot._layout()
		await _settle()
		_check(root.get_visible_rect().encloses(boot._logo.get_global_rect()), "Whole wordmark visible " + str(pixels))
		_check(root.get_visible_rect().encloses(boot._hero_box.get_global_rect()), "Actual 3D stage visible " + str(pixels))
		_check(root.get_visible_rect().encloses(boot.get_node("Layer/BottomPanel").get_global_rect()), "Real status visible " + str(pixels))
		var frame_rect := Rect2(Vector2.ZERO, Vector2(boot._hero_viewport.size))
		for rotor in boot._hero.wheel_rotors:
			# Both existing wheel builders attach the actual tyre first;
			# only the older builder assigns a literal DirectionalTyre name.
			var tyre: MeshInstance3D = rotor.get_child(0)
			var inside := true
			var extent := Rect2()
			var initialized := false
			# Test the real rounded tyre silhouette, not corners of an AABB
			# which sit outside a circular wheel and are never rendered.
			for surface in range(tyre.mesh.get_surface_count()):
				var vertices: PackedVector3Array = tyre.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					var projected: Vector2 = boot._hero_camera.unproject_position(tyre.global_transform * vertex)
					inside = inside and frame_rect.grow(1).has_point(projected)
					extent = extent.expand(projected) if initialized else Rect2(projected, Vector2.ZERO)
					initialized = true
			_check(inside, "Actual tyre stays inside camera " + str(pixels)
				+ " tyre=" + str(extent) + " frame=" + str(frame_rect))
		var file := "loading-ready-%dx%d.png" % [pixels.x, pixels.y]
		if DisplayServer.get_name() != "headless":
			_check(root.get_texture().get_image().save_png(output.path_join(file)) == OK, "Save genuine ready-state frame")
		evidence.append({"surface_px": [pixels.x, pixels.y], "density": sample[1],
			"phase": boot.load_phase, "engine_progress": boot.actual_progress,
			"ready_state_held_by_test_only": true, "image": file,
			"physical_android_device": false})
	# Genuine invalid target, followed by the actual native retry action.
	boot._begin_loading("not-a-real-scene")
	_check(boot.load_phase == "error" and boot._retry_row.visible, "Invalid target gives a child-friendly error")
	_check(not boot.get_node("Layer/LoadBar").visible, "Failed load does not keep an endless progress indicator")
	for button in [boot._retry_button, boot._back_button]:
		var size_dp: Vector2 = button.size * Vector2(root.size) / root.get_visible_rect().size / float(host._options["displayDensity"])
		_check(size_dp.y >= 47.8, "Error actions preserve 48dp touch height")
		_check(root.get_visible_rect().encloses(button.get_global_rect()), "Error action stays inside actual viewport")
	# Force expiry of the real attempt clock, not a fake completion percentage.
	boot._begin_loading("kart")
	boot._load_started_ms -= 31000
	boot._poll_loading()
	_check(boot.load_phase == "error", "Expired engine request cannot hang the child forever")
	await _settle()
	if DisplayServer.get_name() != "headless":
		_check(root.get_texture().get_image().save_png(
			output.path_join("loading-timeout-%dx%d.png" % [root.size.x, root.size.y])) == OK,
			"Save actual timeout/retry controls")
	boot._retry_button.pressed.emit()
	_check(boot.load_phase == "loading", "Actual Retry starts a new bounded attempt")
	await _wait_ready(boot)
	_check(boot._hero.is_processing(), "Retry resumes the existing visual rather than leaving it frozen")
	_check(boot._hero_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Retry resumes renderer")
	boot._reduced_motion = true
	boot._hero.reduced_motion = true
	boot._hero._process(0.1)
	_check(not boot._hero.lumo_animation.play_menu_behavior("greeting_wave"), "Quiet mode blocks repeated greeting")
	# Real router transition into the native, already-loaded Kart scene.
	boot._finish_loading()
	for frame in range(20):
		await process_frame
		# SceneTree deliberately clears current_scene between removing boot
		# and attaching the loaded scene. Null is not a completed transition.
		if is_instance_valid(current_scene) and current_scene.scene_file_path == router.SCENES.kart:
			break
	var game = current_scene
	_check(is_instance_valid(game) and game.scene_file_path == router.SCENES.kart, "Actual existing Kart scene opened")
	await _settle()
	_check(game.menu_active and is_instance_valid(game.garage), "Loaded Kart shows its real native menu")
	_check(not is_instance_valid(game.intro), "No second long intro after the boot entry")
	_check(router.current_scene_id == "kart", "Router state changes only after successful navigation")
	game.abandoned = true
	current_scene = null
	game.queue_free()
	await _settle(8)
	await create_timer(0.5).timeout
	var after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if after != baseline:
		Node.print_orphan_nodes()
	_check(after == baseline, "Boot, preview and actual menu return orphan count to baseline")
	var report := {"checks": checks, "failures": failures, "cases": evidence,
		"actual_threaded_loader": true, "actual_router_transition": true,
		"timeout_uses_test_clock_expiry": true, "physical_android_device": false,
		"orphan_nodes_before": baseline, "orphan_nodes_after": after}
	FileAccess.open(output.path_join("loading-report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	if failures == 0:
		print("[KartLoading] PASS:", checks, " real loading, rig, dp, timeout, Retry and existing Kart transition checks")
	quit(0 if failures == 0 else 1)
