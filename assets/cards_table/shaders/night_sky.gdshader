// Abendhimmel hinter dem Baumhausfenster: Verlauf mit Abendrot am Horizont,
// Mond mit Hof, funkelnde Sterne und langsam ziehende Wolkenbänder.
// unshaded – läuft auf Forward+, Mobile und gl_compatibility gleich.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;

uniform vec3 zenith : source_color = vec3(0.020, 0.035, 0.130);
uniform vec3 middle : source_color = vec3(0.075, 0.110, 0.360);
uniform vec3 horizon : source_color = vec3(0.180, 0.300, 0.560);
uniform vec3 haze : source_color = vec3(0.420, 0.300, 0.620);
uniform vec2 moon_at = vec2(0.72, 0.085);
uniform float moon_radius = 0.030;
uniform vec3 dusk : source_color = vec3(0.95, 0.46, 0.36);
uniform float cloud_amount = 1.0;

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float stars(vec2 uv, float scale, float amount) {
	vec2 cell = floor(uv * scale);
	vec2 local = fract(uv * scale) - 0.5;
	float seed = hash(cell);
	vec2 offset = vec2(hash(cell + 7.1), hash(cell + 13.7)) - 0.5;
	float size = mix(0.035, 0.10, hash(cell + 3.3));
	float twinkle = 0.65 + 0.35 * sin(TIME * (0.8 + seed * 2.4) + seed * 40.0);
	float core = smoothstep(size, 0.0, length(local - offset * 0.7));
	return step(1.0 - amount, seed) * core * twinkle;
}

void fragment() {
	// Bildschirmbezogen: oben tiefe Nacht, zur Bildmitte hin heller Dunst.
	vec2 uv = SCREEN_UV;
	float ratio = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	float up = 1.0 - uv.y;
	vec3 color = mix(horizon, middle, smoothstep(0.50, 0.78, up));
	color = mix(color, zenith, smoothstep(0.72, 1.0, up));
	color += haze * 0.25 * smoothstep(0.78, 0.50, up);
	// Letztes Abendrot knapp über den Baumkronen.
	color = mix(color, dusk, 0.55 * smoothstep(0.62, 0.40, up));
	vec2 wide = vec2(uv.x * ratio, uv.y);
	float field = stars(wide, 34.0, 0.36) + stars(wide + 0.37, 17.0, 0.24) * 1.4;
	color += vec3(0.85, 0.92, 1.0) * field * smoothstep(0.50, 0.75, up);
	// Mond: helle Scheibe mit weichem Hof und einer Sichelschattierung.
	vec2 to_moon = (uv - moon_at) * vec2(ratio, 1.0);
	float d = length(to_moon);
	float disc = smoothstep(moon_radius, moon_radius - 0.004, d);
	float shade = smoothstep(moon_radius * 1.05, moon_radius * 0.2, length(to_moon - vec2(moon_radius * 0.55, -moon_radius * 0.25)));
	vec3 moon = mix(vec3(1.0, 0.96, 0.82), vec3(0.78, 0.80, 0.86), shade * 0.55);
	color = mix(color, moon, disc);
	color += vec3(0.55, 0.68, 1.0) * 0.55 * exp(-d * 9.0) * (1.0 - disc);
	// Wolkenbänder ziehen langsam von links nach rechts, der Mond scheint durch.
	if (cloud_amount > 0.0) {
		vec2 cp = vec2(wide.x * 2.2 - TIME * 0.012, uv.y * 7.0);
		float n = vnoise(cp * 1.7) * 0.6 + vnoise(cp * 3.9 + 4.0) * 0.3 + vnoise(cp * 8.3 + 9.0) * 0.1;
		float band = smoothstep(0.35, 0.75, up) * smoothstep(0.95, 0.72, up);
		float cloud = smoothstep(0.52, 0.78, n) * band * cloud_amount;
		vec3 lit = mix(vec3(0.20, 0.20, 0.38), vec3(0.85, 0.62, 0.62), smoothstep(0.75, 0.45, up));
		lit += vec3(0.35, 0.4, 0.55) * exp(-d * 6.0);
		color = mix(color, lit, cloud * 0.7);
	}
	ALBEDO = color;
}
