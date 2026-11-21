shader_type spatial;
// LUMO Abenteuer-Parcours: Fahrbahnoberflächen ohne Texturdateien.
// UV.x = Meter entlang der Fahrbahn, UV.y = Meter quer ab der linken Kante,
// UV2 = Abstand zur linken / rechten Kante in Metern (für Kantenlicht und Mittellinie).
// Läuft auf Forward+, Mobile und gl_compatibility (keine Bildschirm-/Tiefentextur).
// style: 0 Metallplatten, 1 Holzbohlen, 2 Schwebeglas, 3 Eis, 4 Tempelstein,
//        5 Warnstreifen (Aufzug/Wartefeld), 6 Schwungband, 7 Moos/Erde
uniform vec4 base_color : source_color = vec4(0.85, 0.89, 0.96, 1.0);
uniform vec4 line_color : source_color = vec4(0.25, 0.36, 0.55, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.78, 0.25, 1.0);
uniform int style = 0;
uniform float panel = 3.0;
uniform float glow_strength = 1.0;
uniform float time_scale = 1.0;
uniform float roughness_value = 0.55;
uniform float metallic_value = 0.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float seam(float v, float size, float thickness) {
	float f = abs(fract(v / size + 0.5) - 0.5) * size;
	return 1.0 - smoothstep(thickness * 0.5, thickness, f);
}

void fragment() {
	vec2 uv = UV;
	vec3 color = base_color.rgb;
	vec3 emission = vec3(0.0);
	float rough = roughness_value;
	float metal = metallic_value;
	float edge_distance = min(UV2.x, UV2.y);
	if (style == 0) {
		float s = max(seam(uv.x, panel, 0.06), seam(uv.y, panel, 0.06));
		color = mix(color, line_color.rgb, s * 0.75);
		vec2 cell = floor(uv / panel);
		color *= 0.94 + 0.08 * hash(cell);
		vec2 local = fract(uv / panel) * panel;
		float rivet = 0.0;
		for (int i = 0; i < 4; i++) {
			vec2 c = vec2(i % 2 == 0 ? 0.28 : panel - 0.28, i < 2 ? 0.28 : panel - 0.28);
			rivet = max(rivet, 1.0 - smoothstep(0.05, 0.09, length(local - c)));
		}
		color = mix(color, line_color.rgb * 1.3, rivet * 0.6);
		metal = 0.35;
	} else if (style == 1) {
		float plank = floor(uv.x / 0.55);
		float s = seam(uv.x, 0.55, 0.05);
		color *= 0.82 + 0.22 * hash(vec2(plank, 3.0));
		color *= 0.9 + 0.12 * noise(vec2(uv.x * 2.0, uv.y * 14.0 + plank * 7.0));
		color = mix(color, line_color.rgb, s);
		rough = 0.8;
		metal = 0.0;
	} else if (style == 2) {
		float grid = max(seam(uv.x, 1.5, 0.05), seam(uv.y, 1.5, 0.05));
		color = mix(color, glow_color.rgb, grid * 0.35);
		emission = glow_color.rgb * (grid * 0.6 + 0.12) * glow_strength;
		rough = 0.18;
		metal = 0.1;
	} else if (style == 3) {
		float n = noise(uv * 0.7) * 0.6 + noise(uv * 3.1) * 0.4;
		float crack = 1.0 - smoothstep(0.0, 0.05, abs(noise(uv * 0.9 + 4.0) - 0.5));
		color = mix(color, vec3(1.0), n * 0.25);
		color = mix(color, line_color.rgb, crack * 0.4);
		emission = glow_color.rgb * crack * 0.25 * glow_strength;
		rough = 0.08;
		metal = 0.0;
	} else if (style == 4) {
		vec2 brick = vec2(uv.x / 1.6, uv.y / 1.1);
		brick.x += floor(brick.y) * 0.5;
		float s = max(seam(brick.x * 1.6, 1.6, 0.08), seam(uv.y, 1.1, 0.08));
		color *= 0.82 + 0.2 * hash(floor(brick));
		color *= 0.85 + 0.2 * noise(uv * 2.3);
		color = mix(color, line_color.rgb, s * 0.8);
		rough = 0.9;
		metal = 0.0;
	} else if (style == 5) {
		float stripe = step(0.5, fract((uv.x + uv.y) / 1.2));
		float band = step(edge_distance, 0.9);
		color = mix(color, mix(line_color.rgb, glow_color.rgb, stripe), band);
		float s = max(seam(uv.x, 2.0, 0.05), seam(uv.y, 2.0, 0.05));
		color = mix(color, line_color.rgb, s * 0.5 * (1.0 - band));
		emission = glow_color.rgb * band * stripe * 0.25 * glow_strength;
		metal = 0.4;
	} else if (style == 6) {
		float chevron = fract((uv.x * 0.5 - abs(UV2.x - UV2.y) * 0.175) - TIME * 1.8 * time_scale);
		float lit = smoothstep(0.55, 0.62, chevron) * (1.0 - smoothstep(0.85, 0.92, chevron));
		color = mix(color, glow_color.rgb, lit);
		emission = glow_color.rgb * lit * 1.6 * glow_strength;
		metal = 0.3;
	} else {
		float n = noise(uv * 0.9) * 0.5 + noise(uv * 4.0) * 0.5;
		color = mix(line_color.rgb, color, smoothstep(0.25, 0.7, n));
		rough = 0.95;
		metal = 0.0;
	}
	// Leuchtende Kantenmarkierung nur an offenen Rändern (Vertex-Farbe Rot = offen links,
	// Grün = offen rechts), damit Kinder die Kante klar sehen.
	float open_left = COLOR.r * (1.0 - smoothstep(0.18, 0.32, UV2.x));
	float open_right = COLOR.g * (1.0 - smoothstep(0.18, 0.32, UV2.y));
	float open_edge = max(open_left, open_right);
	color = mix(color, glow_color.rgb, open_edge);
	emission += glow_color.rgb * open_edge * 1.4 * glow_strength;
	// Mittellinie auf schmalen Brücken (Vertex-Farbe Blau).
	float centre = COLOR.b * (1.0 - smoothstep(0.07, 0.13, abs(UV2.x - UV2.y) * 0.5));
	centre *= step(0.5, fract(uv.x / 2.4));
	color = mix(color, glow_color.rgb, centre);
	emission += glow_color.rgb * centre * 0.9 * glow_strength;
	ALBEDO = color;
	EMISSION = emission;
	ROUGHNESS = rough;
	METALLIC = metal;
}
