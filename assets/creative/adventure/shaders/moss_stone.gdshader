// Fels/Ruine: Grundtextur + Moos auf nach oben zeigenden Flächen + Bodenschmutz.
shader_type spatial;
#include "res://assets/creative/adventure/shaders/occlusion.gdshaderinc"

uniform sampler2D base_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D moss_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 base_tint : source_color = vec4(1.0);
uniform float uv_scale = 1.0;
uniform float moss_amount = 0.5;
uniform float normal_strength = 1.0;
uniform float ground_y = 0.0;

varying vec3 w_normal;
varying vec3 w_pos;

void vertex() {
	w_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	lumo_occlusion(VERTEX, VIEW_MATRIX, FRAGCOORD.xy);
	vec2 uv = UV * uv_scale;
	vec3 base = texture(base_albedo, uv).rgb * base_tint.rgb;
	vec3 moss = texture(moss_albedo, uv * 1.4).rgb;
	float breakup = texture(moss_albedo, uv * 0.31 + vec2(0.37, 0.11)).g;
	float up = w_normal.y + (breakup - 0.45) * 0.9;
	float m = smoothstep(1.0 - moss_amount, 1.15 - moss_amount, up);
	float grime = 1.0 - clamp((w_pos.y - ground_y) * 0.9, 0.0, 1.0);
	vec3 col = mix(base, moss, m);
	col *= mix(1.0, 0.62, grime);
	col = mix(col, col * vec3(0.78, 0.84, 0.62), grime * 0.4);
	ALBEDO = col;
	NORMAL_MAP = texture(base_normal, uv).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = mix(0.86, 0.98, m);
	SPECULAR = 0.3;
}
