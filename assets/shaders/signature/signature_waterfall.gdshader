shader_type spatial;
render_mode cull_disabled, depth_draw_never, shadows_disabled;
// Fallendes Wasser (Wasserfälle, Vorhang, Fontänenwand): helle Schaumstreifen ziehen mit
// speed m/s in Richtung +UV.y (Fallrichtung), dazwischen klares Türkis, Ränder ausgefranst.
// UV = (quer m, Fallweg m). Durchscheinend, ohne Bildschirmtextur (alle Renderer).
uniform vec4 water : source_color = vec4(0.55, 0.9, 0.95, 1.0);
uniform vec4 foam : source_color = vec4(0.97, 1.0, 1.0, 1.0);
uniform float speed = 9.0;
uniform float half_width = 3.0;
uniform float opacity = 0.75;
uniform float intensity = 1.0;

float hash_value(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_value(i), hash_value(i + vec2(1, 0)), f.x),
		mix(hash_value(i + vec2(0, 1)), hash_value(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = vec2(UV.x * 1.6, UV.y * 0.22 - TIME * speed * 0.22);
	float streak = noise(vec2(p.x, p.y)) * 0.6 + noise(vec2(p.x * 2.3, p.y * 1.7)) * 0.4;
	float edge = 1.0 - smoothstep(half_width * 0.65, half_width, abs(UV.x) + noise(vec2(UV.y * 0.5, TIME)) * 0.6);
	float white = smoothstep(0.5, 0.85, streak);
	ALBEDO = mix(water.rgb, foam.rgb, white);
	EMISSION = foam.rgb * white * 0.25;
	ROUGHNESS = 0.15;
	ALPHA = clamp((0.45 + white * 0.55) * edge * opacity * intensity, 0.0, 1.0);
}
