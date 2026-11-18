// Rinde/Holz mit Normalen und Sichtschutz für Lumo (Stämme vor der Kamera).
shader_type spatial;
#include "res://assets/creative/adventure/shaders/occlusion.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness_value = 0.95;

void fragment() {
	lumo_occlusion(VERTEX, VIEW_MATRIX, FRAGCOORD.xy);
	ALBEDO = texture(albedo_tex, UV).rgb * tint.rgb;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.25;
}
