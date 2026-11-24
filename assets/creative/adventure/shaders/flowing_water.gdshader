// Wasserfall und Bach: UV.y = Fließrichtung. Streifen, Schaum, Glanz; halbtransparent.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, blend_mix;

uniform sampler2D streak_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D wave_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 water_color : source_color = vec4(0.42, 0.72, 0.82, 0.78);
uniform float speed = 1.4;
uniform float stretch = 4.0;
uniform float foam_bottom = 0.0;

void fragment() {
	vec2 uv = vec2(UV.x * 2.0, UV.y / stretch - TIME * speed * 0.25);
	float s1 = texture(streak_tex, vec2(uv.x, uv.y)).r;
	float s2 = texture(streak_tex, vec2(uv.x * 1.7 + 0.3, uv.y * 1.3 - TIME * speed * 0.11)).r;
	float streak = smoothstep(0.45, 0.85, s1 * 0.6 + s2 * 0.5);
	float edges = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	float foam = foam_bottom * smoothstep(0.75, 1.0, UV.y) * (0.6 + 0.4 * s2);
	vec3 col = mix(water_color.rgb, vec3(0.94, 0.98, 1.0), clamp(streak * 0.75 + foam, 0.0, 1.0));
	ALBEDO = col;
	EMISSION = col * 0.12;
	NORMAL_MAP = texture(wave_normal, uv * 0.6).rgb;
	ALPHA = clamp(water_color.a * edges + streak * 0.2 + foam, 0.0, 1.0) * edges;
	ROUGHNESS = 0.05;
	SPECULAR = 0.7;
}
