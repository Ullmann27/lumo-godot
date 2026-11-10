shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// One two-triangle translucent stage, no reflection probe or extra shadow map.
// Motion is supplied by the existing menu clock, never uncontrolled shader TIME.
uniform float illumination = 1.0;

void fragment() {
	vec2 point = (UV - vec2(0.5)) * 2.0;
	float radius = length(point);
	float edge = 1.0 - smoothstep(0.85, 1.0, radius);
	float rim = smoothstep(0.74, 0.81, radius) * (1.0 - smoothstep(0.84, 0.90, radius));
	float inner = smoothstep(0.56, 0.58, radius) * (1.0 - smoothstep(0.61, 0.64, radius));
	float midring = smoothstep(0.30, 0.33, radius) * (1.0 - smoothstep(0.36, 0.39, radius));
	float radial = max(0.0, 1.0 - radius);
	// Soft contact shadow under the kart, so the 3D hero sits on the glass.
	float contact = exp(-radius * radius * 7.2) * 0.58;
	vec2 highlight_at = point - vec2(-0.22, -0.16);
	float highlight = pow(max(0.0, 1.0 - length(highlight_at) * 1.15), 3.0) * 0.24;
	vec3 glass = mix(vec3(0.018, 0.090, 0.205), vec3(0.16, 0.78, 0.92), radial * 0.24);
	glass = mix(glass, vec3(0.012, 0.020, 0.045), contact);
	ALBEDO = glass;
	EMISSION = vec3(0.16, 0.74, 0.92) * (rim * 0.46 + inner * 0.20 + midring * 0.14 + highlight) * illumination;
	ALPHA = edge * (0.56 + rim * 0.30 + inner * 0.10 + contact * 0.38);
}
