extends RefCounted
## Optional renderer-specific grade applied to existing WorldEnvironment.
## Never creates a second environment, replaces the game loop or changes physics.
## SSR and SDFGI remain disabled pending a verified GPU performance budget.


static func profile_for(method: String, low_detail: bool, mobile_platform: bool) -> Dictionary:
	return {
		"renderer": method,
		"quality": "low" if low_detail else "full",
		"ssao": method == "forward_plus" and not low_detail and not mobile_platform,
		"ssr": false,
		"sdfgi": false,
		"ssil": false,
		"glow": not low_detail,
	}


static func configure(environment: Environment, low_detail: bool) -> Dictionary:
	# Project defaults can differ from --rendering-method or an Android override.
	var profile := profile_for(
		RenderingServer.get_current_rendering_method(), low_detail, OS.has_feature("mobile")
	)
	# Reset all unsupported/inherited effects when switching profiles, not only
	# when enabling desktop effects. Reusing an Environment must be safe.
	environment.ssao_enabled = profile.ssao
	environment.ssr_enabled = false
	environment.sdfgi_enabled = false
	environment.ssil_enabled = false
	environment.glow_enabled = profile.glow
	if low_detail:
		return profile
	# Keep original atmospheric colors; raise the HDR-only emission threshold.
	environment.glow_hdr_threshold = 1.06
	environment.glow_bloom = minf(environment.glow_bloom, 0.08)
	if profile.ssao:
		# SSAO is Forward+ only. Mobile and GL Compatibility use built-in shadows.
		environment.ssao_intensity = 0.62
		environment.ssao_radius = 0.85
	return profile
