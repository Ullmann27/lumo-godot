// Lichtkegel/Lichtschacht: additiv, weiche Ränder, Abfall entlang der Kegelachse.
// beam_length = Höhe des Zylinders; invert = 1 lässt das Licht unten am stärksten sein.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 beam_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float intensity = 0.35;
uniform float beam_length = 11.0;
uniform float invert = 0.0;

varying float v_fall;

void vertex() {
	float t = clamp(0.5 - VERTEX.y / beam_length, 0.0, 1.0);
	v_fall = mix(t, 1.0 - t, invert);
}

void fragment() {
	float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float k = facing * facing * (1.0 - v_fall * 0.88) * intensity;
	ALBEDO = beam_color.rgb * k;
}
