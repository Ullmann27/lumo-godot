// Rauch und Dampf (alpha-gemischt), siehe signature_puff.gdshaderinc.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://assets/shaders/signature/signature_puff.gdshaderinc"

void fragment() {
	vec2 p = v_uv - 0.5;
	float r = length(p) * 2.0;
	float soft = 1.0 - smoothstep(0.35, 1.0, r);
	float lumps = 0.78 + 0.22 * sin(p.x * 9.0 + p.y * 7.0 + TIME * 0.6);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * soft * lumps * v_life;
}
