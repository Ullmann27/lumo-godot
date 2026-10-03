shader_type spatial;
render_mode cull_disabled;

uniform vec4 road_tint : source_color = vec4(0.24, 0.33, 0.42, 1.0);
uniform float night_course = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	// UV.x spans the road in metres; UV.y follows its centre line.
	float grain_visibility = 1.0 - smoothstep(0.012, 0.035, max(fwidth(UV.x), fwidth(UV.y)));
	float aggregate = mix(0.5, hash21(floor(UV * 26.0)), grain_visibility);
	float coarse = hash21(floor(UV * 1.8));
	float rubber = exp(-pow((abs(UV.x) - 2.4) * 1.1, 2.0));
	float lane_wear = 0.96 - rubber * 0.085;
	ALBEDO = road_tint.rgb * (0.91 + aggregate * 0.13 + coarse * 0.04) * lane_wear;
	ROUGHNESS = mix(0.93, 0.46, night_course);
	METALLIC = night_course * 0.18;
}
