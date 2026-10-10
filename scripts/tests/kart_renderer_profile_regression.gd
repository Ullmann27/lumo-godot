extends SceneTree
## Actual renderer, not project default; capability downgrade clears old effects.
const POLISH = preload("res://scripts/games/visual/kart_environment_polish.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for method in ["forward_plus", "mobile", "gl_compatibility"]:
		for low in [true, false]:
			for mobile_platform in [true, false]:
				var profile: Dictionary = POLISH.profile_for(method, low, mobile_platform)
				assert(profile.ssao == (method == "forward_plus" and not low and not mobile_platform))
				assert(not profile.ssr and not profile.sdfgi and not profile.ssil)
				assert(profile.glow == not low)
	var environment := Environment.new()
	var actual := RenderingServer.get_current_rendering_method()
	var original = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	ProjectSettings.set_setting("rendering/renderer/rendering_method", "forward_plus")
	var full: Dictionary = POLISH.configure(environment, false)
	assert(full.renderer == actual, "CLI/runtime renderer must override project default")
	assert(environment.ssao_enabled == full.ssao)
	var low: Dictionary = POLISH.configure(environment, true)
	assert(not low.ssao and not environment.ssao_enabled)
	assert(not environment.ssr_enabled and not environment.sdfgi_enabled)
	assert(not environment.ssil_enabled and not environment.glow_enabled)
	var restored: Dictionary = POLISH.configure(environment, false)
	assert(environment.glow_enabled and environment.ssao_enabled == restored.ssao)
	ProjectSettings.set_setting("rendering/renderer/rendering_method", original)
	print("[RendererProfiles] PASS: 12 capability combinations, actual renderer, full-low-full downgrade")
	quit(0)
