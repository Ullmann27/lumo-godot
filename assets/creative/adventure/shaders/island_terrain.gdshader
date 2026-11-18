// Inselboden: Gras/Sand/Pfad/Fels nach Vertexfarbe (R Sand, G Pfad, B Fels) plus Hangneigung.
// Zwei Maßstäbe pro Textur gegen sichtbares Kacheln; nasser Sand an der Wasserlinie.
shader_type spatial;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float grass_scale = 0.16;
uniform float sand_scale = 0.22;
uniform float path_scale = 0.3;
uniform float rock_scale = 0.12;
uniform float water_level = -1.65;

varying vec3 w_pos;
varying vec3 w_normal;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = w_pos.xz;
	vec3 grass = texture(grass_albedo, p * grass_scale).rgb;
	vec3 grass_far = texture(grass_albedo, p * grass_scale * 0.21 + vec2(0.31, 0.17)).rgb;
	grass *= mix(vec3(0.82), vec3(1.18), grass_far.g * 1.6 - 0.25);
	vec3 sand = texture(sand_albedo, p * sand_scale).rgb;
	vec3 path = texture(path_albedo, p * path_scale).rgb;
	vec3 rock = texture(rock_albedo, p * rock_scale).rgb;
	float slope = 1.0 - w_normal.y;
	float noise = texture(grass_albedo, p * 0.037).g;
	float w_sand = clamp(COLOR.r + (noise - 0.35) * 0.35 * COLOR.r, 0.0, 1.0);
	float w_path = smoothstep(0.25, 0.75, COLOR.g + (texture(path_albedo, p * 0.09).r - 0.4) * 0.5);
	float w_rock = clamp(COLOR.b + smoothstep(0.32, 0.55, slope), 0.0, 1.0);
	vec3 col = grass;
	vec3 nrm = texture(grass_normal, p * grass_scale).rgb;
	col = mix(col, sand, w_sand);
	nrm = mix(nrm, texture(sand_normal, p * sand_scale).rgb, w_sand);
	col = mix(col, path, w_path);
	nrm = mix(nrm, texture(path_normal, p * path_scale).rgb, w_path);
	col = mix(col, rock, w_rock);
	nrm = mix(nrm, texture(rock_normal, p * rock_scale).rgb, w_rock);
	float wet = 1.0 - smoothstep(water_level + 0.05, water_level + 0.75, w_pos.y);
	col *= mix(1.0, 0.58, wet);
	ALBEDO = col;
	NORMAL_MAP = nrm;
	ROUGHNESS = mix(mix(0.93, 0.98, w_sand), 0.35, wet);
	SPECULAR = mix(0.3, 0.55, wet);
}
