shader_type spatial;
// Lumos Riesengarten – Wasserbogen des Rasensprengers (Band entlang der Wurfparabel).
// UV.y = Weg entlang des Bogens (0 Düse, 1 Aufschlag), UV.x quer. Laufende Wasserfäden,
// Funkeln in der Sonne; "amount" blendet den Bogen beim Anspringen ein.
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 colour : source_color = vec4(0.86, 0.96, 1.0, 1.0);
uniform float amount = 1.0;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(27.1, 61.7))) * 43758.5);
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float threads = smoothstep(0.55, 1.0, sin(UV.x * 38.0 + hash1(vec2(floor(UV.x * 19.0), 0.0)) * 6.0) * 0.5 + 0.5);
	float pulse = fract(UV.y * 6.0 - TIME * 2.4 + hash1(vec2(floor(UV.x * 19.0), 3.0)));
	float body = smoothstep(0.0, 0.2, pulse) * (1.0 - smoothstep(0.5, 1.0, pulse));
	float spark = step(0.97, hash1(floor(vec2(UV.x * 30.0, UV.y * 80.0 - TIME * 12.0))));
	float fade = smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.8, 1.0, UV.y));
	ALBEDO = colour.rgb + spark * 0.6;
	ALPHA = clamp((threads * body * 0.55 + spark * 0.8) * across * fade * amount, 0.0, 0.85);
}
