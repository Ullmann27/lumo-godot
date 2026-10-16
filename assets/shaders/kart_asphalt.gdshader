shader_type spatial;
render_mode cull_disabled;

uniform vec4 road_tint : source_color = vec4(0.16, 0.20, 0.25, 1.0);
uniform vec4 edge_glow_color : source_color = vec4(0.35, 0.9, 1.0, 1.0);
uniform float night_course = 0.0;
uniform float sky_island_detail = 0.0;
uniform float cinematic_grade : hint_range(0.0, 1.0) = 0.95;
uniform float road_gloss : hint_range(0.0, 1.0) = 0.90;
uniform float edge_energy : hint_range(0.0, 1.0) = 0.50;
// Zero on low-detail devices; adds a mobile-friendly aggregate and worn tread.
uniform float surface_grit : hint_range(0.0, 1.0) = 0.0;

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
	// Two world-scale procedural aggregates: broad repairs and fine gravel.
	// The high-frequency layer fades with pixel footprint to avoid shimmer.
	float pebble_footprint = max(fwidth(UV.x), fwidth(UV.y)) * 14.0;
	float pebble_lod = 1.0 - smoothstep(0.28, 0.62, pebble_footprint);
	float pebbles = hash21(floor(UV * 14.0 + vec2(3.7, 9.1))) - 0.5;
	float repairs = hash21(floor(UV * 0.92 + vec2(13.0, 2.1))) - 0.5;
	float driven_lane = rubber * (0.86 + 0.14 * sin(UV.y * 0.17));
	float lane_wear = 0.96 - rubber * mix(0.085, 0.115, sky_island_detail);
	float joint_phase = fract(UV.y / 13.0);
	float joint = 1.0 - smoothstep(0.0, max(fwidth(joint_phase) * 1.5, 0.006), min(joint_phase, 1.0 - joint_phase));
	float surface_joint = joint * sky_island_detail * 0.055;
	float edge_distance = abs(abs(UV.x) - 5.08);
	float edge_band = 1.0 - smoothstep(0.05, 0.24, edge_distance);
	float wet_band = 0.5 + 0.5 * sin(UV.y * 0.11 + UV.x * 0.55);
	vec3 base = road_tint.rgb * (0.91 + aggregate * 0.13 + coarse * 0.04 - surface_joint) * lane_wear;
	base = mix(base, base * (0.92 + wet_band * 0.12), cinematic_grade * road_gloss * 0.45);
	// Keep the original color identity; make coarse aggregate and wheel polish
	// legible on the chase camera without increasing vertex or draw-call count.
	float grit_color = pebbles * pebble_lod * 0.21 + repairs * 0.18 - driven_lane * 0.045;
	base *= 1.0 + surface_grit * grit_color;
	ALBEDO = base;
	float original_roughness = mix(mix(0.90, 0.43, night_course), 0.22, cinematic_grade * road_gloss * 0.76);
	ROUGHNESS = clamp(original_roughness + surface_grit * (pebbles * pebble_lod * 0.11 + repairs * 0.09 - driven_lane * 0.035), 0.18, 0.94);
	METALLIC = mix(night_course * 0.18, 0.26, cinematic_grade * road_gloss * 0.30);
	SPECULAR = mix(0.42, 0.82, cinematic_grade * road_gloss);
	EMISSION = edge_glow_color.rgb * edge_band * edge_energy * cinematic_grade;
}
