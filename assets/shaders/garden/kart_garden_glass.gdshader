shader_type spatial;
// Lumos Riesengarten – Glas (Gartenschlauch, Gewächshaus). Durchsichtig mit Tönung,
// heller Fresnel-Kante, Rippen quer zur Röhre und herablaufenden Tropfen (rein prozedural).
// UV.x = Umfang/Breite in Metern, UV.y = Strecke in Metern. Beidseitig sichtbar.
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.36, 0.82, 0.42, 0.22);
uniform vec4 rim_colour : source_color = vec4(0.82, 1.0, 0.78, 1.0);
uniform float rib_period = 1.6;
uniform float rib_strength = 0.18;
uniform float drops = 1.0;
uniform float wetness = 0.0;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float fresnel = pow(1.0 - facing, 3.0);
	float rib = 1.0 - smoothstep(0.0, 0.18, abs(fract(UV.y / rib_period) - 0.5) - 0.32);
	// Tropfen: Zellen von 0,9 m, je Zelle ein Tropfen, der langsam herabläuft.
	vec2 cell_uv = vec2(UV.x / 0.9, UV.y / 0.9);
	vec2 cell = floor(cell_uv);
	float seed = hash1(cell);
	vec2 local = fract(cell_uv) - vec2(0.5, fract(0.5 + seed - TIME * (0.03 + 0.12 * wetness) * (0.5 + seed)));
	float drop = (1.0 - smoothstep(0.05, 0.11, length(local * vec2(1.0, 0.7)))) * step(0.55 - wetness * 0.4, seed) * drops;
	vec3 colour = tint.rgb + rib * rib_strength + fresnel * rim_colour.rgb * 0.55 + drop * 0.5;
	ALBEDO = colour;
	EMISSION = rim_colour.rgb * fresnel * 0.25 + vec3(drop) * 0.25;
	ROUGHNESS = 0.05;
	SPECULAR = 0.8;
	ALPHA = clamp(tint.a + fresnel * 0.45 + rib * rib_strength * 0.6 + drop * 0.35, 0.0, 0.92);
}
