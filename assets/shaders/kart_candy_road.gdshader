shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float lane = (UV.x + 5.4) / 10.8;
	vec3 rainbow = 0.64 + 0.24 * cos(6.2831853 * (vec3(0.02, 0.35, 0.68) + lane * 0.78));
	float ribbons = 1.0 - smoothstep(0.015, 0.055, abs(fract(lane * 7.0) - 0.5));
	ALBEDO = rainbow * (0.91 + ribbons * 0.08);
	ROUGHNESS = 0.22;
	SPECULAR = 0.88;
	METALLIC = 0.14;
	EMISSION = rainbow * 0.10;
}
