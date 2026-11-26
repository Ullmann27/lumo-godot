shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Sichtbarer Wind (Windkanal) und Leuchtbahnen: schmale helle Striche, die mit
// speed m/s entlang UV.y ziehen. UV = (quer m, entlang m).
uniform vec4 tint : source_color = vec4(0.75, 0.95, 1.0, 1.0);
uniform float speed = 26.0;
uniform float density = 0.5;
uniform float intensity = 1.0;

float hash_value(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	float lane = floor(UV.x / 0.7);
	float offset = hash_value(vec2(lane, 3.0)) * 40.0;
	float along = fract((UV.y - TIME * speed * (0.8 + 0.4 * hash_value(vec2(lane, 7.0))) + offset) / 14.0);
	float streak = smoothstep(0.0, 0.08, along) * (1.0 - smoothstep(0.08, 0.45, along));
	float keep = step(1.0 - density, hash_value(vec2(lane, 11.0)));
	float across = 1.0 - smoothstep(0.05, 0.25, abs(fract(UV.x / 0.7) - 0.5));
	ALBEDO = tint.rgb * streak * keep * across * intensity;
}
