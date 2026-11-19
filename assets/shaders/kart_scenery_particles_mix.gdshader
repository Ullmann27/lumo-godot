// Umgebungspartikel (Laub, Pollen, Schnee, Sand, Gischt), alpha-gemischt.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://assets/shaders/kart_scenery_particles.gdshaderinc"

void fragment() {
	vec4 s = texture(atlas, v_uv);
	ALBEDO = s.rgb * tint.rgb;
	ALPHA = s.a * tint.a * v_fade;
}
