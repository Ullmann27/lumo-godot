shader_type spatial;
// Lumo-Kart turbo speed lines at the screen edge. The mesh is a ring in clip
// space (written straight to POSITION), so the centre of the picture stays
// clear and no screen texture is read. Lines stream outwards continuously;
// nothing blinks (no flicker above 3 Hz). Mobile + Compatibility safe.
render_mode unshaded, blend_add, cull_disabled, depth_test_disabled, depth_draw_never, skip_vertex_transform, fog_disabled;

uniform float fx_time = 0.0;
uniform float intensity = 0.0;
uniform float aspect = 1.7778;
uniform vec4 tint : source_color = vec4(0.85, 0.97, 1.0, 1.0);

varying vec2 v_ndc;

float hash(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

void vertex() {
	v_ndc = VERTEX.xy;
	POSITION = vec4(VERTEX.xy, 0.5, 1.0);
}

void fragment() {
	vec2 p = v_ndc * vec2(max(aspect, 1.0), max(1.0 / aspect, 1.0));
	float r = length(p);
	float turn = atan(p.y, p.x) / 6.2831853 + 0.5;
	float lanes = 90.0;
	float cell = floor(turn * lanes);
	float h = hash(cell);
	float lane = fract(turn * lanes);
	float width = 0.08 + 0.1 * h;
	float line = smoothstep(width, 0.0, abs(lane - 0.5));
	float dash = fract(r * (0.55 + h * 0.5) - fx_time * (1.1 + h * 1.3) + h * 7.0);
	float streak = smoothstep(0.0, 0.08, dash) * smoothstep(0.85, 0.3, dash);
	float edge = smoothstep(0.62, 1.25, r);
	float on = step(0.38, h);
	float a = line * streak * edge * on * intensity;
	ALBEDO = tint.rgb * 1.3;
	ALPHA = clamp(a * 0.85, 0.0, 1.0);
}
