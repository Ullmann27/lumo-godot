// Brandung: Band entlang der Küste; UV.y 0 = Wasser, 1 = Strand. Wellen laufen zum Ufer.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float speed = 0.35;
uniform float strength = 0.85;

void fragment() {
	float n = texture(noise_tex, vec2(UV.x * 18.0, UV.y * 1.2 + TIME * 0.05)).r;
	float bands = sin((UV.y * 3.0 - TIME * speed) * 6.2831 + n * 3.0) * 0.5 + 0.5;
	float edge = smoothstep(0.0, 0.35, UV.y) * (1.0 - smoothstep(0.75, 1.0, UV.y));
	float lace = smoothstep(0.55, 0.85, bands * 0.7 + n * 0.5);
	ALBEDO = vec3(0.95, 0.98, 1.0);
	ALPHA = clamp(lace * edge * strength + smoothstep(0.82, 0.95, UV.y) * (1.0 - smoothstep(0.95, 1.0, UV.y)) * 0.45, 0.0, 1.0);
}
