shader_type spatial;
// Lumo-Kart Sternen-Duplikat: holografische Kopie eines Karts.
// Unshaded + Alpha-Mischung (auch auf hellem Schnee sichtbar), keine Screen-/Depth-Textur:
// läuft auch in gl_compatibility (Android).
// Waagerechte Lichtzeilen wandern nach oben, Fresnel-Rand, leichtes Flimmern (0 bei ruhiger
// Bewegung). Das echte Kart bleibt dadurch eindeutig unterscheidbar (fest, beleuchtet, farbig).
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.12, 0.62, 1.0, 1.0);
uniform float strength = 1.0;
uniform float flicker = 1.0;
uniform float time_offset = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME + time_offset;
	float lines = smoothstep(0.55, 1.0, sin(world_pos.y * 38.0 - t * 6.0) * 0.5 + 0.5);
	float fresnel = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float shimmer = 1.0 - flicker * 0.18 * (0.5 + 0.5 * sin(t * 23.0) * sin(t * 7.0));
	vec3 colour = mix(tint.rgb, vec3(0.85, 1.0, 1.0), lines * 0.6 + fresnel * 0.5);
	ALBEDO = colour;
	ALPHA = clamp((0.32 + lines * 0.3 + fresnel * 0.45) * shimmer * strength, 0.0, 1.0);
}
