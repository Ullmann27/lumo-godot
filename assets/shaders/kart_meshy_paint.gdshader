shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D original_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 factory_paint : source_color;
uniform vec4 selected_paint : source_color;
uniform float factory_roughness = 1.0;

float peak(vec3 color) {
	return max(color.r, max(color.g, color.b));
}

void fragment() {
	vec3 original = texture(original_albedo, UV).rgb;
	float reference_value = max(peak(factory_paint.rgb), 0.01);
	float value = peak(original);
	// Compare chromaticity independently of brightness to keep shading and wear.
	// A brightness gate leaves the tyres, cavities and bright lamps alone.
	vec3 normalized = original / max(value, 0.01);
	vec3 reference = factory_paint.rgb / reference_value;
	float similarity = 1.0 - smoothstep(0.24, 0.81, length(normalized - reference));
	float lower = max(0.018, reference_value * 0.22);
	float mask = similarity * smoothstep(lower, lower + 0.08, value);
	float shade = clamp(value / reference_value, 0.15, 1.25);
	ALBEDO = mix(original, clamp(selected_paint.rgb * shade, vec3(0.0), vec3(1.0)), mask);
	ROUGHNESS = mix(factory_roughness, 0.34, mask);
	METALLIC = 0.18 * mask;
}
