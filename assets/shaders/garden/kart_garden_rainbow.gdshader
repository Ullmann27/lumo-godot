shader_type spatial;
// Lumos Riesengarten – Regenbogen im Sprühnebel (additiv, weich). UV.y = Radius im Band.
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, fog_disabled;

uniform float amount = 1.0;

vec3 spectrum(float x) {
	return clamp(vec3(
		1.5 - abs(4.0 * x - 1.0),
		1.5 - abs(4.0 * x - 2.0),
		1.5 - abs(4.0 * x - 3.0)), 0.0, 1.0);
}

void fragment() {
	float edge = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.82, UV.y);
	float ends = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	ALBEDO = spectrum(UV.y) * edge * ends * 0.38 * amount;
}
