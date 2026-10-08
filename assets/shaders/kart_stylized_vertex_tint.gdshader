// Lumo Kart stylized directional vertex tint.
// Adapted from the directional-tint technique in GDQuest's godot-shaders
// (MIT, Copyright (c) 2020 GDQuest), itself based on Kenney's
// UnlitDirectionalTint idea. This variant is rewritten for Lumo's
// vertex-colored procedural meshes and uses no third-party art assets.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_disabled;

uniform vec4 top_tint : source_color = vec4(1.08, 1.08, 1.02, 1.0);
uniform vec4 side_tint : source_color = vec4(0.72, 0.86, 0.78, 1.0);
uniform vec4 bottom_tint : source_color = vec4(0.48, 0.58, 0.62, 1.0);
uniform vec4 overall_tint : source_color = vec4(1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.88;
uniform sampler2D ground_grain : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.0;

varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float up = clamp(world_normal.y, 0.0, 1.0);
	float down = clamp(-world_normal.y, 0.0, 1.0);
	float side = 1.0 - max(up, down);
	vec3 directional =
		top_tint.rgb * pow(up, 1.35)
		+ side_tint.rgb * side
		+ bottom_tint.rgb * pow(down, 0.8);
	directional = max(directional, vec3(0.15));
	ALBEDO = COLOR.rgb * directional * overall_tint.rgb;
	// Shared seamless grain keeps the coastal ground from reading as a flat
	// colour sheet. Mipmaps soften it in the distance without extra geometry.
	float grain = texture(ground_grain, world_position.xz * 0.17).r;
	ALBEDO *= 1.0 + (grain - 0.5) * grain_strength;
	ROUGHNESS = roughness_value;
}
