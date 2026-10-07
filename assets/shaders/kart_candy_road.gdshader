shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float lane = (UV.x + 5.4) / 10.8;
	vec3 rainbow = 0.39 + 0.32 * cos(6.2831853 * (vec3(0.02, 0.35, 0.68) + lane * 0.78));
	float seams = 1.0 - smoothstep(0.002, 0.008, min(fract(lane * 7.0), 1.0 - fract(lane * 7.0)));
	float sheen = pow(0.5 + 0.5 * sin(UV.y * 0.12 + UV.x * 0.5), 14.0);
	ALBEDO = rainbow * (0.86 + sheen * 0.13) + vec3(seams * 0.10);
	ROUGHNESS = 0.16 + sheen * 0.06;
	SPECULAR = 0.88;
	METALLIC = 0.14;
	EMISSION = rainbow * (0.035 + sheen * 0.08) + vec3(seams * 0.06);
}
