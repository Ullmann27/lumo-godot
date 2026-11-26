shader_type spatial;
render_mode cull_disabled;

uniform vec4 deck_tint : source_color = vec4(0.29, 0.31, 0.33, 1.0);
uniform vec4 side_tint : source_color = vec4(0.25, 0.27, 0.29, 1.0);
uniform vec4 paint_tint : source_color = vec4(0.92, 0.77, 0.47, 1.0);
uniform float half_width = 4.6;
uniform float deck_length = 7.0;

float cell_noise(vec2 p) {
	p = fract(p * vec2(0.1031, 0.11369));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

void fragment() {
	// UV uses metres on the deck. Vertical bracing carries a negative UV.y.
	if (UV.y < 0.0) {
		ALBEDO = side_tint.rgb;
		ROUGHNESS = 0.73;
		METALLIC = 0.15;
	} else {
		vec2 metres = UV;
		float width = max(0.003, max(fwidth(metres.x), fwidth(metres.y)));
		float near_grain = 1.0 - smoothstep(0.024, 0.065, width);
		float grain = cell_noise(floor(metres * 19.0)) - 0.5;
		float grit = cell_noise(floor(metres * 5.5 + 3.0)) - 0.5;
		float tread = abs(abs(metres.x) - 1.8);
		float rubber = exp(-3.8 * tread * tread)
			* (0.77 + 0.23 * sin(metres.y * 1.45 + metres.x * 0.47));
		float panel_phase = fract(metres.y / 2.6);
		float joint = 1.0 - smoothstep(0.009, 0.013 + width * 0.46,
			min(panel_phase, 1.0 - panel_phase));
		float kerb = half_width - abs(metres.x);
		float edge = smoothstep(0.06, 0.06 + width, kerb)
			* (1.0 - smoothstep(0.17, 0.17 + width, kerb));
		float last_line = 1.0 - smoothstep(0.18, 0.18 + width, deck_length - metres.y);
		float column = abs(metres.x);
		float arrow_phase = fract((metres.y + column * 0.64 + 0.18) / 2.2);
		float arrow = (1.0 - smoothstep(0.045, 0.045 + width * 0.70,
			min(arrow_phase, 1.0 - arrow_phase))) * (1.0 - smoothstep(0.91, 0.96, column));
		vec3 deck = deck_tint.rgb * (0.98 + (grain * 0.17 + grit * 0.12) * near_grain
			- rubber * 0.22 - joint * 0.18);
		float marking = max(max(edge * 0.88, last_line), arrow * 0.67);
		marking *= 0.86 + grain * near_grain * 0.17;
		ALBEDO = mix(deck, paint_tint.rgb, marking);
		ROUGHNESS = clamp(0.85 - rubber * 0.18 + grain * near_grain * 0.14, 0.5, 0.96);
		SPECULAR = 0.30;
	}
}
