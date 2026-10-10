extends RefCounted
## Optional renderer-specific grade applied to existing WorldEnvironment.
## Never creates a second environment, replaces the game loop or changes physics.
## SSR and SDFGI remain disabled pending a verified GPU performance budget.


static func configure(environment: Environment, low_detail: bool) -> Dictionary:
	var method: String = RenderingServer.get_rendering_method()
	var forward_plus: bool = method == "forward_plus"
	if low_detail:
		return {"renderer": method, "quality": "low", "ssao": false, "ssr": false}
	# Keep original atmospheric colors; raise the HDR-only emission threshold.
	environment.glow_enabled = true
	environment.glow_hdr_threshold = 1.06
	environment.glow_bloom = minf(environment.glow_bloom, 0.08)
	if forward_plus:
		# SSAO is Forward+ only. Mobile and GL Compatibility use built-in shadows.
		environment.ssao_enabled = true
		environment.ssao_intensity = 0.62
		environment.ssao_radius = 0.85
		environment.ssr_enabled = false
		environment.sdfgi_enabled = false
	return {"renderer": method, "quality": "full", "ssao": forward_plus, "ssr": false}
