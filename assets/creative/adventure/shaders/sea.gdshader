// Meer: zwei laufende Wellen-Normalen, Fresnel-Himmel, Sonnenglanz. Undurchsichtig.
shader_type spatial;
render_mode cull_back;

uniform sampler2D wave_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 deep_color : source_color = vec4(0.05, 0.24, 0.36, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.12, 0.52, 0.56, 1.0);
uniform vec4 sky_color : source_color = vec4(0.62, 0.82, 0.94, 1.0);
uniform vec2 island_center = vec2(0.0, -29.0);
uniform vec2 island_radius = vec2(39.0, 52.0);
uniform float wave_speed = 1.0;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float swell = sin(w_pos.x * 0.11 + TIME * 0.9 * wave_speed) * 0.08 + sin(w_pos.z * 0.09 - TIME * 0.7 * wave_speed) * 0.07;
	VERTEX.y += swell;
}

void fragment() {
	vec2 uv = w_pos.xz * 0.045;
	vec3 n1 = texture(wave_normal, uv + TIME * vec2(0.012, 0.007) * wave_speed).rgb;
	vec3 n2 = texture(wave_normal, uv * 2.3 - TIME * vec2(0.009, 0.016) * wave_speed).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5) * 2.0 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.9;
	vec2 d = (w_pos.xz - island_center) / island_radius;
	float shore = 1.0 - smoothstep(0.95, 1.45, length(d));
	vec3 water = mix(deep_color.rgb, shallow_color.rgb, shore);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(water, sky_color.rgb, fres * 0.55);
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.65;
}
