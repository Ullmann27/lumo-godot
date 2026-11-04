extends SceneTree

const POLISH = preload("res://scripts/games/visual/kart_environment_polish.gd")


func _initialize() -> void:
	call_deferred("_run")


func _make_environment_scene(scene_name: String) -> Dictionary:
	var scene := Node3D.new()
	scene.name = scene_name
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	POLISH.configure(environment, false)
	world.environment = environment
	scene.add_child(world)
	return {"scene": scene, "environment": environment}


func _assert_supported_effects(environment: Environment, stage: String) -> void:
	var method := RenderingServer.get_current_rendering_method()
	var supported := method == "forward_plus" and not OS.has_feature("mobile")
	print("[KartQualityRenderer] %s renderer=%s ssao=%s volumetric_fog=%s expected=%s" % [
		stage, method, environment.ssao_enabled, environment.volumetric_fog_enabled, supported])
	assert(environment.ssao_enabled == supported, "HIGH must preserve the renderer/platform SSAO capability gate")
	assert(environment.volumetric_fog_enabled == supported, "HIGH must respect the renderer/platform volumetric fog capability gate")


func _run() -> void:
	await process_frame
	await process_frame
	var performance := root.get_node_or_null("PerformanceManager")
	assert(performance != null)
	var previous_profile := int(performance.current_profile)
	var previous_method = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	# The runtime renderer can differ from the saved project default on Android or via CLI.
	ProjectSettings.set_setting("rendering/renderer/rendering_method", "forward_plus")
	var first := _make_environment_scene("RendererQualityFirst")
	assert(change_scene_to_node(first.scene) == OK)
	await scene_changed
	await process_frame
	performance.call("set_profile", 2, false)
	_assert_supported_effects(first.environment, "high")
	performance.call("set_profile", 0, false)
	assert(not first.environment.ssao_enabled and not first.environment.volumetric_fog_enabled)
	performance.call("set_profile", 2, false)
	_assert_supported_effects(first.environment, "low-to-high")
	var second := _make_environment_scene("RendererQualitySecond")
	# Start opposite to the verified HIGH state so every renderer must reapply it.
	second.environment.ssao_enabled = not first.environment.ssao_enabled
	second.environment.volumetric_fog_enabled = not first.environment.volumetric_fog_enabled
	assert(change_scene_to_node(second.scene) == OK)
	await scene_changed
	await process_frame
	_assert_supported_effects(second.environment, "scene-switch-high")
	ProjectSettings.set_setting("rendering/renderer/rendering_method", previous_method)
	performance.call("set_profile", previous_profile, false)
	print("[KartQualityRenderer] PASS: HIGH respects runtime capabilities through quality and scene changes")
	quit(0)
