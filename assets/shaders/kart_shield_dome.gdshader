shader_type spatial;
// Lumo-Kart Sternenschild: energy dome with a honeycomb lattice, Fresnel rim,
// slow breathing pulse, a reveal sweep (activation / fade out) and an impact ripple.
// Mobile + gl_compatibility safe: unshaded, additive, no screen/depth textures.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.40, 0.92, 1.0, 1.0);
uniform vec4 rim_tint : source_color = vec4(0.85, 0.98, 1.0, 1.0);
uniform float strength = 1.0;
// 0 = invisible, 1 = fully raised. The sweep runs from the ground up.
uniform float reveal = 1.0;
// Breathing pulse amplitude (0 in reduced motion). Pulse rate stays below 1 Hz.
uniform float pulse_amount = 0.25;
uniform float time_offset = 0.0;
// Impact ripple: object-space direction of the hit and its age in seconds.
uniform vec3 hit_direction = vec3(0.0, 0.0, -1.0);
uniform float hit_age = 9.0;
uniform float cell_scale = 7.0;

varying vec3 object_position;

void vertex() {
	object_position = VERTEX;
}

// Distance to the nearest hexagon edge (0 at the edge, ~0.5 in the centre).
float hex_edge(vec2 p) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	return 0.5 - max(dot(q, normalize(r)), q.x);
}

void fragment() {
	vec3 dir = normalize(object_position);
	// Spherical lattice coordinates; latitude compression keeps cells even.
	float lon = atan(dir.x, dir.z) / 6.2831853;
	float lat = asin(clamp(dir.y, -1.0, 1.0)) / 3.1415926;
	vec2 cell_uv = vec2(lon * cell_scale * 2.2, lat * cell_scale * 1.25);
	float edge = hex_edge(cell_uv);
	float lattice = 1.0 - smoothstep(0.02, 0.085, edge);
	float t = TIME + time_offset;
	float breathe = 1.0 + sin(t * 4.4) * pulse_amount * 0.5;
	float fresnel = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.4);
	// A slow shimmer band crawls upward across the lattice (0.35 Hz).
	float band = smoothstep(0.82, 1.0, sin((lat * 6.0 - t * 2.2)) * 0.5 + 0.5);
	// Ripple ring travelling away from the impact point.
	float impact_angle = acos(clamp(dot(dir, normalize(hit_direction)), -1.0, 1.0));
	float ripple_front = hit_age * 3.6;
	float ripple = exp(-pow((impact_angle - ripple_front) * 5.0, 2.0)) * exp(-hit_age * 2.2);
	float impact_glow = exp(-impact_angle * 3.2) * exp(-hit_age * 5.0);
	// Reveal sweep from the ground (lat = -0.5) to the top (0.5) with a bright edge.
	float height = lat + 0.5;
	float shown = 1.0 - smoothstep(reveal * 1.15 - 0.16, reveal * 1.15 - 0.08, height);
	float sweep_edge = exp(-pow((height - reveal * 1.15 + 0.12) * 18.0, 2.0)) * step(reveal, 0.999);
	// Kept translucent: both faces add up on bright daytime tracks, and the
	// kart and its driver must stay clearly visible inside the dome.
	float body = 0.025 + lattice * (0.20 + band * 0.32) + fresnel * 0.50;
	vec3 colour = tint.rgb * body * breathe + rim_tint.rgb * (fresnel * 0.28 + ripple * 1.1 + impact_glow * 0.9);
	ALBEDO = (colour * shown + rim_tint.rgb * sweep_edge * 1.6) * strength;
}
