shader_type spatial;
render_mode cull_disabled;
uniform vec4 hot : source_color = vec4(1.0, 0.36, 0.055, 1.0);
void fragment() {
	vec2 p = UV * vec2(34.0, 20.0) + vec2(TIME * 0.08, -TIME * 0.05);
	float seams = abs(sin(p.x + sin(p.y * 1.7)) * sin(p.y + sin(p.x * 1.3)));
	float crust = smoothstep(0.08, 0.42, seams);
	ALBEDO = mix(hot.rgb, vec3(0.19, 0.055, 0.06), crust * 0.74);
	EMISSION = hot.rgb * (1.2 - crust * 0.90);
	ROUGHNESS = 0.42;
}
