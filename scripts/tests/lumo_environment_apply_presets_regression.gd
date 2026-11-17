extends SceneTree
## LumoEnvironment.apply is the single entry point for every known preset.


var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error("[LumoEnvironmentApply] FAIL: %s" % message)
		_failed = true


func _holder() -> Node3D:
	var node := Node3D.new()
	root.add_child(node)
	return node


func _run() -> void:
	# creative_night: values and "shadows always on" stay identical on every tier.
	var night_high: Dictionary = LumoEnvironment.apply(_holder(), "creative_night", "high")
	var night_env: Environment = night_high.environment
	var night_sky := night_env.sky.sky_material as ProceduralSkyMaterial
	_check(night_sky.sky_top_color.is_equal_approx(Color("081537")), "creative_night sky top")
	_check(is_equal_approx(night_env.ambient_light_energy, 0.36), "creative_night ambient energy")
	_check(night_env.tonemap_mode == Environment.TONE_MAPPER_FILMIC, "creative_night filmic")
	_check(is_equal_approx(night_env.glow_intensity, 0.75), "creative_night glow")
	_check(night_high.sun.shadow_enabled, "creative_night high shadows on")
	_check(is_equal_approx(night_high.sun.directional_shadow_max_distance, 70.0), "creative_night shadow distance")
	_check(is_equal_approx(night_high.sun.light_energy, 0.80), "creative_night sun energy")
	_check(night_high.sun.light_color.is_equal_approx(Color("d9e8ff")), "creative_night sun color")
	_check(night_high.rim == null, "creative_night has no rim")
	var night_low: Dictionary = LumoEnvironment.apply(_holder(), "creative_night", "low")
	_check(night_low.sun.shadow_enabled, "creative_night must stay identical on every tier")
	_check(night_low.rim == null, "creative_night low has no rim")

	# wolkeninseln: existing RimLight and budget shadows stay identical.
	var jump_high: Dictionary = LumoEnvironment.apply(_holder(), "wolkeninseln", "high")
	var jump_env: Environment = jump_high.environment
	var jump_sky := jump_env.sky.sky_material as ProceduralSkyMaterial
	_check(jump_sky.sky_top_color.is_equal_approx(Color("1557a8")), "wolkeninseln sky top")
	_check(jump_env.fog_enabled, "wolkeninseln fog")
	_check(jump_high.sun.shadow_enabled == true, "wolkeninseln high shadows follow budget")
	_check(jump_high.sun.light_color.is_equal_approx(Color("fff0d2")), "wolkeninseln sun color")
	_check(is_equal_approx(jump_high.sun.light_energy, 1.15), "wolkeninseln sun energy")
	_check(jump_high.rim is DirectionalLight3D, "wolkeninseln keeps RimLight")
	_check(jump_high.rim.name == "RimLight", "wolkeninseln rim name")
	_check(jump_high.rim.rotation_degrees.is_equal_approx(Vector3(-20, 150, 0)), "wolkeninseln rim rotation")
	_check(jump_high.rim.light_color.is_equal_approx(Color("a8e4ff")), "wolkeninseln rim color")
	_check(is_equal_approx(jump_high.rim.light_energy, 0.35), "wolkeninseln rim energy")
	_check(jump_high.rim.shadow_enabled == false, "wolkeninseln rim has no shadows")
	var jump_low: Dictionary = LumoEnvironment.apply(_holder(), "wolkeninseln", "low")
	_check(jump_low.sun.shadow_enabled == false, "wolkeninseln low shadows follow budget")
	_check(jump_low.rim is DirectionalLight3D and jump_low.rim.name == "RimLight", "wolkeninseln low keeps RimLight")

	# Creative-table presets: describe/configure/apply via LumoEnvironment.apply.
	var table: Array[String] = ["bauwelt_day", "puzzle_atelier", "rhythm_party", "treasure_day"]
	var fill_names := {
		"bauwelt_day": "SkyFill",
		"puzzle_atelier": "WarmFill",
		"rhythm_party": "CyanFill",
		"treasure_day": "SkyFill",
	}
	var expected_energy := {
		"bauwelt_day": 1.25,
		"puzzle_atelier": 1.18,
		"rhythm_party": 0.95,
		"treasure_day": 1.32,
	}
	for preset_id in table:
		var spec: Dictionary = LumoEnvironmentCreativePresets.describe(preset_id)
		_check(not spec.is_empty(), "%s describe is known" % preset_id)
		_check(str(spec.get("id", "")) == preset_id, "%s describe id" % preset_id)
		_check(str(spec.get("shadow_policy", "")) == "budget", "%s shadow_policy" % preset_id)
		if preset_id == "rhythm_party":
			_check(spec.has("rim") and str(spec.rim.get("name", "")) == "MagentaRim", "rhythm_party describe rim")
		else:
			_check(not spec.has("rim"), "%s describe has no rim" % preset_id)

		var high: Dictionary = LumoEnvironment.apply(_holder(), preset_id, "high")
		_check(high.world is WorldEnvironment, "%s high world" % preset_id)
		_check(high.environment is Environment, "%s high environment" % preset_id)
		_check(high.sun is DirectionalLight3D, "%s high sun" % preset_id)
		_check(high.sun.shadow_enabled == true, "%s high shadows from budget" % preset_id)
		_check(is_equal_approx(high.sun.light_energy, float(expected_energy[preset_id])), "%s sun energy" % preset_id)
		_check(high.fill is DirectionalLight3D, "%s high fill" % preset_id)
		_check(high.fill.name == fill_names[preset_id], "%s fill name" % preset_id)
		_check(high.fill.shadow_enabled == false, "%s fill has no shadows" % preset_id)
		if preset_id == "rhythm_party":
			_check(high.rim is DirectionalLight3D, "rhythm_party high rim")
			_check(high.rim.name == "MagentaRim", "rhythm_party rim name")
			_check(high.rim.light_color.is_equal_approx(Color("d080ff")), "rhythm_party rim color")
			_check(high.environment.glow_enabled, "rhythm_party glow enabled")
		else:
			_check(high.rim == null, "%s high has no rim" % preset_id)

		var low: Dictionary = LumoEnvironment.apply(_holder(), preset_id, "low")
		_check(low.sun.shadow_enabled == false, "%s low shadows from budget" % preset_id)
		if preset_id == "rhythm_party":
			_check(low.rim is DirectionalLight3D and low.rim.name == "MagentaRim", "rhythm_party low keeps rim")
		else:
			_check(low.rim == null, "%s low has no rim" % preset_id)

	# Unknown names still warn and do not pick up a creative table spec.
	_check(LumoEnvironmentCreativePresets.describe("creative_night").is_empty(), "creative_night is not a table preset")
	_check(LumoEnvironmentCreativePresets.describe("wolkeninseln").is_empty(), "wolkeninseln is not a table preset")

	if _failed:
		quit(1)
		return
	print("[LumoEnvironmentApply] PASS creative_night/wolkeninseln/bauwelt_day/puzzle_atelier/rhythm_party/treasure_day")
	quit(0)
