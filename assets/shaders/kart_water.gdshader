shader_type spatial;
render_mode cull_disabled;

// Farben aus #71 (Gemini-Analyse: tieferes Wasser), Uferschaum aus #72.
uniform vec4 deep_water : source_color = vec4(0.026, 0.23, 0.42, 1.0);
uniform vec4 shallow_water : source_color = vec4(0.10, 0.57, 0.66, 1.0);
// Optional beach foam is enabled only for full-detail Sonnenhafen.
// Uses the same authored shoreline profile as LumoRaceWorld._ground_height().
uniform float coastal_foam : hint_range(0.0, 1.0) = 0.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float swell = sin(p.x * 0.12 + p.y * 0.17 + TIME * 0.5);
	float small_wave = sin(p.x * 1.3 + p.y * 0.4 + TIME * 1.15)
		* sin(p.y * 1.65 - TIME * 0.75);
	float crest = pow(max(0.0, small_wave * 0.5 + swell * 0.5), 7.0);
	float light = smoothstep(-0.6, 1.0, swell * 0.4 + small_wave * 0.15);
	vec3 ocean_color = mix(deep_water.rgb, shallow_water.rgb, light * 0.65) + crest * 0.18;
	if (coastal_foam > 0.0) {
		// World-space foam ring. Matching shore harmonics retain the irregular
		// island contour without a texture lookup or additional geometry.
		float angle = atan(p.y, p.x);
		float shoreline = 1.0 + sin(angle * 5.0 + 0.6) * 0.035 + sin(angle * 9.0) * 0.018;
		float radius = length(vec2(p.x / 101.0, p.y / 91.0));
		float rim = 1.0 - smoothstep(0.004, 0.042, abs(radius - shoreline));
		float breakers = 0.70 + 0.30 * sin(p.x * 0.26 - p.y * 0.37 + TIME * 1.75);
		float foam_amount = clamp(coastal_foam * rim * breakers * 0.72, 0.0, 0.72);
		ocean_color = mix(ocean_color, vec3(0.75, 0.93, 0.98), foam_amount);
	}
	ALBEDO = ocean_color;
	NORMAL_MAP = vec3(0.5 + small_wave * 0.025, 0.5 + swell * 0.022, 1.0);
	NORMAL_MAP_DEPTH = 0.2;
	ROUGHNESS = 0.22;
	METALLIC = 0.22;
	SPECULAR = 0.54;
}
