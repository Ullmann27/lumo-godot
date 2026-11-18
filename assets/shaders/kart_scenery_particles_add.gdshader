// Leuchtende Umgebungspartikel (Glut, Gluehwuermchen, Neon, Funkeln), additiv.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
#include "res://assets/shaders/kart_scenery_particles.gdshaderinc"

void fragment() {
	vec4 s = texture(atlas, v_uv);
	float twinkle = 0.75 + 0.25 * sin(TIME * 4.0 + v_uv.x * 300.0);
	ALBEDO = tint.rgb * s.a * v_fade * 1.6 * twinkle;
}
