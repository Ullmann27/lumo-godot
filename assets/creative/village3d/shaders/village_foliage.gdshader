// LUMO Dorfwelt · Blattbüschel (Alpha-Karten aus leaf_cards.png).
// Normalen zeigen vom Kronenmittelpunkt weg (in Blender gesetzt), damit die
// Krone wie ein weiches Volumen schattiert; COLOR = Grünton und Eigenschatten,
// 1-COLOR.a = Windgewicht. Durchscheinendes Gegenlicht als billiger Ersatz für
// Subsurface. Mobile/gl_compatibility-fähig (Alpha-Scissor, keine Bildschirmtextur).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D leaf_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.45;
uniform float wind_strength = 1.0;

void vertex() {
	float wave = 1.0 - COLOR.a;
	vec3 w = NODE_POSITION_WORLD;
	float t = TIME * 1.7 + w.x * 0.21 + w.z * 0.17;
	float gust = sin(t) * 0.6 + sin(t * 2.7 + VERTEX.y) * 0.25;
	VERTEX.x += gust * 0.07 * wave * wind_strength * max(VERTEX.y, 0.0) * 0.3;
	VERTEX.z += cos(t * 1.3) * 0.05 * wave * wind_strength * max(VERTEX.y, 0.0) * 0.3;
}

void fragment() {
	vec4 leaf = texture(leaf_texture, UV);
	ALBEDO = leaf.rgb * COLOR.rgb * 2.0;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 0.78;
	SPECULAR = 0.25;
}
