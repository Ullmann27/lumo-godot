shader_type spatial;
// LUMO Abenteuer-Parcours: durchsichtige Eisbrücke. Läuft auch mit gl_compatibility.
// UV2 = Abstand zur linken / rechten Kante (Kantenlicht wie parcours_surface).
render_mode blend_mix, depth_draw_always, cull_disabled;
uniform vec4 base_color : source_color = vec4(0.62, 0.86, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.55, 0.95, 1.0, 1.0);
uniform float opacity = 0.42;
uniform float glow_strength = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float grid = 1.0 - smoothstep(0.03, 0.07, abs(fract(uv.x / 2.0 + 0.5) - 0.5) * 2.0);
	float sparkle = step(0.985, hash(floor(uv * 6.0)));
	float edge = 1.0 - smoothstep(0.18, 0.4, min(UV2.x, UV2.y));
	float centre = (1.0 - smoothstep(0.07, 0.13, abs(UV2.x - UV2.y) * 0.5)) * step(0.5, fract(uv.x / 2.4));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(base_color.rgb, vec3(1.0), grid * 0.4 + fres * 0.3);
	EMISSION = glow_color.rgb * (edge * 1.6 + centre * 0.9 + grid * 0.25 + sparkle * 0.8) * glow_strength;
	ALPHA = clamp(opacity + edge * 0.5 + grid * 0.25 + centre * 0.5 + fres * 0.3, 0.0, 1.0);
	ROUGHNESS = 0.05;
	METALLIC = 0.0;
	SPECULAR = 0.9;
}
