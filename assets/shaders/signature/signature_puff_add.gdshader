// Funken, Glut und Leuchtstaub (additiv), siehe signature_puff.gdshaderinc.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
#include "res://assets/shaders/signature/signature_puff.gdshaderinc"

void fragment() {
	float r = length(v_uv - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.0, 1.0, r);
	ALBEDO = COLOR.rgb * core * core * v_life * 1.6;
}
