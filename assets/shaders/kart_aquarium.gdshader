shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 water_position;

void vertex() { water_position = VERTEX; }

void fragment() {
	float ripple = sin(water_position.x * 0.55 + TIME * 0.32)
		* sin(water_position.z * 0.73 - TIME * 0.24);
	float caustic = pow(max(0.0, ripple), 5.0);
	ALBEDO = mix(vec3(0.015, 0.16, 0.24), vec3(0.035, 0.40, 0.49),
		clamp(water_position.y * 0.07 + 0.35, 0.0, 1.0));
	ALBEDO += vec3(0.035, 0.19, 0.17) * caustic;
}
