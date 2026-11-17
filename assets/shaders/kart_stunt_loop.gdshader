shader_type spatial;
render_mode cull_disabled;

// Sonnenhafen stunt loop deck: dark glossy track with glowing cyan chevrons
// pointing in the driving direction and warm Lumo-orange edge lines.
// UV.x runs across the deck (0..1), UV.y along the riding line in metres.
// No TIME and no screen/depth textures: identical on Mobile and Compatibility.

uniform vec4 deck_color : source_color = vec4(0.06, 0.11, 0.23, 1.0);
uniform vec4 chevron_color : source_color = vec4(0.25, 0.86, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.6, 0.16, 1.0);
uniform float chevron_spacing = 2.6;
uniform float glow = 2.4;

void fragment() {
	float across = UV.x * 2.0 - 1.0;
	float side = abs(across);
	float stripe = fract(UV.y / chevron_spacing - side * 0.42);
	float chevron = smoothstep(0.0, 0.06, stripe) * (1.0 - smoothstep(0.30, 0.37, stripe));
	chevron *= 1.0 - smoothstep(0.60, 0.70, side);
	float edge = smoothstep(0.80, 0.84, side) * (1.0 - smoothstep(0.93, 0.97, side));
	float sheen = 0.82 + 0.18 * (1.0 - side * side);
	ALBEDO = mix(deck_color.rgb * sheen, chevron_color.rgb, chevron * 0.55);
	ROUGHNESS = 0.3;
	METALLIC = 0.2;
	SPECULAR = 0.6;
	EMISSION = chevron_color.rgb * chevron * glow + edge_color.rgb * edge * glow * 0.75;
}
