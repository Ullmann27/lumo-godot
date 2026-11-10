shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled;

uniform sampler2D picture : source_color, filter_linear;
uniform float shimmer : hint_range(0.0, 0.4) = 0.16;

void fragment() {
	vec4 col = texture(picture, UV);
	float wave = sin((UV.x * 14.0 + UV.y * 9.0) + TIME * 1.55) * 0.5 + 0.5;
	col.rgb += vec3(0.06, 0.11, 0.18) * wave * shimmer;
	float twinkle = fract(sin(dot(floor(UV * 42.0 + TIME * 1.8), vec2(12.9898, 78.233))) * 43758.5453);
	col.rgb += vec3(1.0, 0.94, 0.68) * step(0.93, twinkle) * 0.42;
	ALBEDO = col.rgb;
	EMISSION = col.rgb * (0.10 + wave * 0.10);
}
