shader_type spatial;

uniform sampler2D grain_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 wood_color : source_color = vec4(0.58, 0.37, 0.21, 1.0);

void fragment() {
	// Quiet grain keeps the picture readable, without a repeating high-contrast
	// voxel normal map competing with the puzzle at phone resolutions.
	float grain = texture(grain_texture, UV * vec2(3.0, 1.0)).r;
	ALBEDO = wood_color.rgb * (0.94 + 0.12 * grain);
	ROUGHNESS = 0.86;
	SPECULAR = 0.12;
}
