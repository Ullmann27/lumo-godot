shader_type spatial;
render_mode unshaded, cull_disabled;

// All motion is driven by the owning scene. TIME is deliberately unused so
// pause and reduced animation leave these real geometry batches still.
uniform float animation_time = 0.0;
uniform float wing_weight : hint_range(0.0, 1.0) = 0.0;
uniform float drift_scale : hint_range(0.0, 2.0) = 1.0;
uniform float emission_strength : hint_range(0.0, 2.0) = 0.35;
uniform vec4 palette_warm : source_color = vec4(1.0, 0.83, 0.60, 1.0);
uniform vec4 palette_cool : source_color = vec4(0.52, 0.84, 0.81, 1.0);

varying float color_mix;
varying float light_breath;
varying float wing_edge;

void vertex() {
	float phase = INSTANCE_CUSTOM.r * 6.28318530718;
	float flight_rate = mix(0.35, 0.65, INSTANCE_CUSTOM.g);
	float flight = animation_time * flight_rate + phase;
	vec3 point = VERTEX;
	wing_edge = clamp(abs(point.x) / 0.30, 0.0, 1.0);
	if (wing_weight > 0.5) {
		float fold = 0.55 + sin(animation_time * 7.0 + phase) * 0.55;
		point.y += abs(point.x) * sin(fold);
		point.x *= cos(fold);
	}
	point += vec3(
		sin(flight) * 0.9,
		sin(flight * 1.7) * 0.24,
		cos(flight * 0.83) * 0.7
	) * drift_scale;
	VERTEX = point;
	color_mix = INSTANCE_CUSTOM.b;
	light_breath = 0.88 + 0.12 * sin(animation_time * 0.7 + phase);
}

void fragment() {
	vec3 tint = mix(palette_warm.rgb, palette_cool.rgb, color_mix);
	float border = mix(1.0, mix(0.34, 1.0, smoothstep(0.06, 0.28, wing_edge)), wing_weight);
	ALBEDO = tint * border;
	EMISSION = tint * emission_strength * light_breath;
	ROUGHNESS = 0.8;
}
