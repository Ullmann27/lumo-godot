shader_type spatial;
render_mode cull_disabled;

void fragment() {
	float wave = sin(UV.x * 850.0 + TIME * 0.9) * sin(UV.y * 920.0 - TIME * 0.6);
	ALBEDO = mix(vec3(0.045, 0.48, 0.69), vec3(0.13, 0.70, 0.77), wave * 0.5 + 0.5);
	ROUGHNESS = 0.28;
	METALLIC = 0.15;
}
