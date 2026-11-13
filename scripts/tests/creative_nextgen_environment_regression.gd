extends SceneTree
const FINISH = preload("res://scripts/creative/creative_nextgen_environment.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const FACILITY = preload("res://scripts/creative/build_settlement_visual.gd")
var checks := 0
var failures: Array[String] = []


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_warning("[CreativeNextgenEnvironment] " + label)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var kit := KIT.new()
	kit.environment(holder, "bauwelt_day")
	var world := holder.get_node("WorldEnvironment") as WorldEnvironment
	var original := world.environment
	var original_sky := original.sky
	var original_ambient := original.ambient_light_energy
	var independent := Node3D.new()
	kit.environment(independent, "bauwelt_day")
	var other_environment: Environment = independent.get_node("WorldEnvironment").environment
	var sun := holder.get_node("Sun") as DirectionalLight3D
	var original_shadow := sun.shadow_enabled
	var original_distance := sun.directional_shadow_max_distance
	var original_features := [
		original.glow_enabled, original.ssao_enabled, original.volumetric_fog_enabled
	]
	var node_count := holder.get_child_count()
	var report: Dictionary = FINISH.apply_day(holder)
	_check(report.applied, "Day finish is applied to existing environment")
	_check(
		(
			holder.get_child_count() == node_count
			and report.extra_lights == 0
			and report.extra_draw_calls == 0
		),
		"No new lights or draw-call nodes"
	)
	_check(
		original == world.environment and original_sky == world.environment.sky,
		"Finish reuses the scene-owned environment and GPU sky"
	)
	_check(
		(
			is_equal_approx(other_environment.ambient_light_energy, 0.75)
			and other_environment.sky.sky_material.sky_top_color.is_equal_approx(Color("3d8fe0"))
		),
		"Independent scene preset resources remain unchanged"
	)
	_check(
		world.environment.ambient_light_energy < original_ambient and sun.light_energy < 1.25,
		"Fill and direct light no longer bleach the surfaces"
	)
	_check(
		(
			sun.shadow_enabled == original_shadow
			and sun.directional_shadow_max_distance == original_distance
		),
		"Original quality shadow policy and budget preserved"
	)
	_check(
		(
			original_features
			== [
				world.environment.glow_enabled,
				world.environment.ssao_enabled,
				world.environment.volumetric_fog_enabled
			]
		),
		"No expensive feature switched on by finishing pass"
	)
	var clouds := holder.get_node("DayClouds") as MultiMeshInstance3D
	_check(
		clouds.multimesh.visible_instance_count <= FINISH.MAX_CLOUD_PUFFS,
		"Cloud batch has a fixed mobile ceiling"
	)
	# The headless Dummy renderer returns identity for every MultiMesh readback.
	# Audit authored geometry here; real renderer runs also verify the buffer.
	await process_frame
	for index in range(clouds.multimesh.visible_instance_count):
		var xform: Transform3D = clouds.get_meta("nextgen_cloud_transforms")[index]
		_check(
			xform.origin.z <= -25 and xform.basis.get_scale().x < 5.6,
			"Cloud stays behind the buildable banks and away from the overview camera"
		)
		if DisplayServer.get_name() != "headless":
			_check(
				clouds.multimesh.get_instance_transform(index).is_equal_approx(xform),
				"Actual renderer cloud transform matches the authored scene"
			)
	_check(
		not clouds.material_override.emission_enabled,
		"Cloud surfaces react to light without self-bleaching"
	)
	_check(
		(
			FINISH.ground_material().albedo_texture != null
			and FINISH.ground_material().normal_texture != null
		),
		"Ground reuses original real albedo and normal texture"
	)
	_check(
		FINISH.ground_material() == FINISH.ground_material(),
		"Ground material is shared between both banks"
	)
	_check(
		(
			FINISH.plot_material().albedo_texture != null
			and FINISH.bank_material().albedo_texture != null
		),
		"Build plots and banks have actual material detail"
	)
	_check(
		not FINISH.apply_day(holder).applied and holder.get_child_count() == node_count,
		"Finishing twice is idempotent"
	)
	var ground := kit.box(holder, Vector3.ZERO, Vector3.ONE, Color.WHITE)
	ground.material_override = FINISH.ground_material()
	var ground_reference: WeakRef = weakref(ground.material_override)
	var first := FACILITY.create("house")
	var second := FACILITY.create("house")
	holder.add_child(first)
	holder.add_child(second)
	var asset_reference: WeakRef = weakref(first.get_meta("settlement_visual_asset"))
	_check(
		first.get_meta("settlement_visual_asset") == second.get_meta("settlement_visual_asset"),
		"Live buildings share one baked facility bundle"
	)
	first.queue_free()
	await process_frame
	_check(asset_reference.get_ref() != null, "A live second building retains its actual geometry")
	holder.queue_free()
	independent.free()
	original = null
	original_sky = null
	other_environment = null
	await process_frame
	_check(
		ground_reference.get_ref() == null,
		"The final terrain mesh releases its material without static retention"
	)
	_check(
		asset_reference.get_ref() == null,
		"The final building releases its baked material and geometry bundle"
	)
	if failures.is_empty():
		print(
			"[CreativeNextgenEnvironment] PASS checks=",
			checks,
			": original textures, bounded cloud batch, preserved quality and no added lights"
		)
		quit(0)
	else:
		print("[CreativeNextgenEnvironment] FAIL ", failures)
		quit(1)
