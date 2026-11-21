shader_type spatial;
// Lumos Riesengarten – Lichtstrahl durch die Glasscheiben (additive Lichtkarte).
// UV.x quer, UV.y längs (0 oben, 1 unten); weich an allen Rändern, tanzender Staub.
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, fog_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.93, 0.70, 1.0);
uniform float strength = 0.22;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(41.7, 289.1))) * 15731.743);
}

void fragment() {
	float side = smoothstep(0.0, 0.35, UV.x) * smoothstep(1.0, 0.65, UV.x);
	float along = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	vec2 grain = floor(vec2(UV.x * 40.0, UV.y * 60.0 - TIME * 3.0));
	float dust = step(0.985, hash1(grain)) * 0.8;
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = colour.rgb * (side * along * strength * (0.4 + facing * 0.6) + dust * side * along * 0.25);
}
