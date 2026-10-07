shader_type spatial;
render_mode cull_disabled;

uniform vec4 deep_water : source_color = vec4(0.035, 0.29, 0.48, 1.0);
uniform vec4 shallow_water : source_color = vec4(0.12, 0.63, 0.67, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float swell = sin(p.x * 0.12 + p.y * 0.17 + TIME * 0.5);
	float small_wave = sin(p.x * 1.3 + p.y * 0.4 + TIME * 1.15)
		* sin(p.y * 1.65 - TIME * 0.75);
	float crest = pow(max(0.0, small_wave * 0.5 + swell * 0.5), 8.0);
	float light = smoothstep(-0.6, 1.0, swell * 0.4 + small_wave * 0.15);
	ALBEDO = mix(deep_water.rgb, shallow_water.rgb, light * 0.65) + crest * 0.13;
	NORMAL_MAP = vec3(0.5 + small_wave * 0.025, 0.5 + swell * 0.022, 1.0);
	NORMAL_MAP_DEPTH = 0.2;
	ROUGHNESS = 0.24;
	METALLIC = 0.22;
	SPECULAR = 0.5;
}
