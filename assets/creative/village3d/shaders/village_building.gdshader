// LUMO Dorfwelt · ein Material für alle Gebäude, Requisiten und Bäume.
// UV  = Texturkoordinate in Metern / Kachelgröße (wiederholend),
// COLOR.rgb = Zielfarbe relativ zum Kachelmittel (0.5 = Textur unverändert),
// UV2 = Kachelmitte im 4x4-Atlas, COLOR.rgb = Tönung, 1-COLOR.a = Windgewicht.
// Fensterkacheln leuchten abends (Alpha des Atlas = Leuchtmaske).
// Läuft in Mobile und gl_compatibility (nur textureGrad und Ableitungen).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D atlas_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec4 window_glow : source_color = vec4(1.0, 0.68, 0.32, 1.0);
uniform float glow_energy = 2.6;
uniform float wind_strength = 1.0;
uniform float normal_strength = 1.0;
uniform float build_progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint_mix : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float lit_ratio : hint_range(0.0, 1.0) = 0.7;

varying vec2 tile;
varying float lit;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	tile = floor(UV2 * 4.0);
	float wave = 1.0 - COLOR.a;
	if (wave > 0.01) {
		vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float t = TIME * (1.6 + wave * 2.4);
		float sway = sin(t + w.x * 0.7 + w.z * 0.5) * 0.6 + sin(t * 2.3 + w.z * 1.3) * 0.4;
		VERTEX.x += sway * 0.09 * wave * wind_strength;
		VERTEX.z += cos(t * 1.3 + w.x) * 0.05 * wave * wind_strength;
	}
	vec3 origin = NODE_POSITION_WORLD;
	lit = step(hash(origin.xz * 0.37 + floor(UV2 * 4.0)), lit_ratio);
}

void fragment() {
	vec2 local = fract(UV);
	vec2 auv = (tile + 0.012 + local * 0.976) * 0.25;
	vec2 gx = dFdx(UV) * 0.25 * 0.976;
	vec2 gy = dFdy(UV) * 0.25 * 0.976;
	vec4 albedo = textureGrad(atlas_albedo, auv, gx, gy);
	vec3 nrm = textureGrad(atlas_normal, auv, gx, gy).rgb;
	// COLOR.rgb is authored as colour / (2 · tile mean): 0.5 keeps the texture.
	vec3 col = albedo.rgb * COLOR.rgb * 2.0;
	col = mix(col, col * tint_mix.rgb, tint_mix.a);
	ALBEDO = col;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = normal_strength;
	float glass = 1.0 - albedo.a;
	ROUGHNESS = mix(0.86, 0.18, glass);
	SPECULAR = mix(0.3, 0.7, glass);
	EMISSION = window_glow.rgb * glass * night * glow_energy * lit;
}
