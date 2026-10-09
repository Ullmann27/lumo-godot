shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
// Falling water ribbon: streaks scroll downwards and dissolve into mist at the bottom.

uniform vec4 water : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform vec4 foam : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform float speed = 0.9;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743);
}

void fragment() {
	// UV.x across the fall (0..1), UV.y from the lip (0) to the bottom (1).
	float column = floor(UV.x * 18.0);
	float flow = fract(UV.y * 3.0 - TIME * speed * (0.8 + hash(vec2(column, 1.0)) * 0.6));
	float streak = smoothstep(0.0, 0.25, flow) * (1.0 - smoothstep(0.55, 1.0, flow));
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	ALBEDO = mix(water.rgb, foam.rgb, streak * 0.75 + smoothstep(0.75, 1.0, UV.y) * 0.5);
	ALPHA = edge * (0.62 + streak * 0.3) * (1.0 - smoothstep(0.82, 1.0, UV.y));
}
