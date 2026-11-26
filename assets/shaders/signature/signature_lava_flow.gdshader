shader_type spatial;
render_mode cull_disabled;
// Fließende Lava auf einem Band (UV.x = quer in m, UV.y = entlang in m, Fluss Richtung +y).
// Abgekühlte Krustenplatten treiben mit dem Strom, in den Spalten glüht es. Die Mitte
// fließt schneller als der Rand (wie in einem echten Lavakanal).
uniform vec4 hot : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.86, 0.35, 1.0);
uniform float speed = 1.2;
uniform float half_width = 4.0;
uniform float glow = 2.2;

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

void fragment() {
	float edge = clamp(abs(UV.x) / max(half_width, 0.1), 0.0, 1.0);
	float flow = speed * (1.0 - edge * edge * 0.7);
	vec2 p = vec2(UV.x * 0.45, UV.y * 0.32 - TIME * flow * 0.32);
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 n = vec2(float(x), float(y));
			float d = length(n + hash2(cell + n) - f);
			if (d < first) { second = first; first = d; } else { second = min(second, d); }
		}
	}
	float crack = 1.0 - smoothstep(0.03, 0.2, second - first);
	float heat = mix(crack, 1.0, smoothstep(0.55, 0.15, edge) * 0.35);
	float pulse = 0.85 + 0.15 * sin(TIME * 2.1 + UV.y * 0.15);
	vec3 crust = mix(vec3(0.05, 0.025, 0.03), vec3(0.18, 0.06, 0.04), first);
	vec3 molten = mix(hot.rgb, core.rgb, crack * (1.0 - edge));
	ALBEDO = mix(crust, molten, heat * 0.9);
	EMISSION = molten * heat * pulse * glow;
	ROUGHNESS = mix(0.92, 0.3, heat);
}
