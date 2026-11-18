// Blattkarten, Palmwedel, Farne, Gräser: Alpha-Schnitt, Wind, Durchleuchtung.
// Mobile/gl_compatibility: keine Screen-/Depth-Texturen.
shader_type spatial;
#include "res://assets/creative/adventure/shaders/occlusion.gdshaderinc"
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_cut = 0.42;
uniform float wind = 0.12;
uniform float wind_speed = 1.1;
uniform float sway_height = 6.0;
uniform float translucency = 0.32;
uniform float ground_ao = 0.55;
uniform float roughness_value = 0.82;

varying float v_ao;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(VERTEX.y / sway_height, 0.0, 1.0);
	float phase = world.x * 0.31 + world.z * 0.23;
	float gust = sin(TIME * wind_speed + phase) * 0.65 + sin(TIME * wind_speed * 2.3 + phase * 1.7) * 0.25;
	float flutter = sin(TIME * 4.1 + dot(world, vec3(2.1, 1.3, 1.7))) * 0.25;
	vec3 offset = vec3(gust, 0.0, cos(TIME * wind_speed * 0.8 + phase) * 0.55) * wind * h * h;
	offset += NORMAL * flutter * wind * 0.35 * h;
	VERTEX += offset;
	v_ao = mix(ground_ao, 1.0, smoothstep(0.0, 0.85, h));
}

void fragment() {
	lumo_occlusion(VERTEX, VIEW_MATRIX, FRAGCOORD.xy);
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb * tint.rgb * v_ao;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.22;
	BACKLIGHT = c.rgb * translucency;
}
