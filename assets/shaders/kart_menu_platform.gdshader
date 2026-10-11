shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// One two-triangle translucent stage, no reflection probe or extra shadow map.
// Motion is supplied by the existing menu clock, never uncontrolled shader TIME.
uniform float illumination = 1.0;

void fragment() {
	vec2 point = (UV - vec2(0.5)) * 2.0;
	float radius = length(point);
	float edge = 1.0 - smoothstep(0.85, 1.0, radius);
	float rim = smoothstep(0.75, 0.82, radius) * (1.0 - smoothstep(0.84, 0.88, radius));
	float inner = smoothstep(0.57, 0.59, radius) * (1.0 - smoothstep(0.61, 0.63, radius));
	float radial = max(0.0, 1.0 - radius);
	ALBEDO = mix(vec3(0.015, 0.085, 0.19), vec3(0.11, 0.69, 0.83), radial * 0.17);
	EMISSION = vec3(0.12, 0.65, 0.82) * (rim * 0.3 + inner * 0.12) * illumination;
	ALPHA = edge * (0.46 + rim * 0.22 + inner * 0.06);
}
