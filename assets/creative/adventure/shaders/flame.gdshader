// Lagerfeuer: additiv, ruhiges Züngeln (unter 3 Hz), keine Lichtblitze.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform sampler2D flame_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float energy = 1.6;

void vertex() {
	float h = clamp(VERTEX.y / 1.5, 0.0, 1.0);
	VERTEX.x += sin(TIME * 2.3 + VERTEX.z * 3.0) * 0.08 * h;
	VERTEX.z += cos(TIME * 1.9 + VERTEX.x * 3.0) * 0.08 * h;
}

void fragment() {
	vec2 uv = vec2(UV.x + sin(TIME * 1.7 + UV.y * 5.0) * 0.03 * UV.y, 1.0 - UV.y);
	vec4 c = texture(flame_tex, uv);
	ALBEDO = c.rgb * energy * c.a;
}
