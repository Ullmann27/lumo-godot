// LUMO Dorfwelt · Schornsteinrauch, alle Rauchwolken in EINEM Draw-Call.
// INSTANCE_CUSTOM.x = Phase. Weiche, runde Puffs ohne Textur; Billboard im
// Vertex-Shader. Kein Bildschirm-/Tiefenpuffer, Mobile/gl_compat-fähig.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform vec4 smoke_color : source_color = vec4(0.88, 0.88, 0.9, 1.0);
uniform float rise = 3.4;
uniform vec2 wind = vec2(1.1, 0.35);
uniform float speed = 0.16;
uniform float opacity = 0.42;

varying float life;

void vertex() {
	float t = fract(TIME * speed + INSTANCE_CUSTOM.x);
	life = t;
	vec4 origin = MODEL_MATRIX[3];
	origin.xyz += vec3(wind.x * t * t * 1.4, rise * t, wind.y * t);
	float size = 0.35 + t * 1.35;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, origin);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = dot(c, c);
	float puff = smoothstep(1.0, 0.25, r);
	float wisp = 0.75 + 0.25 * sin(c.x * 5.0 + life * 9.0) * cos(c.y * 4.0 - life * 7.0);
	float fade = smoothstep(0.0, 0.12, life) * (1.0 - smoothstep(0.55, 1.0, life));
	ALBEDO = smoke_color.rgb * mix(1.0, 0.82, life);
	ALPHA = puff * wisp * fade * opacity;
}
