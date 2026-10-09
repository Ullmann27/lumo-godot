shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	// UV.x follows metres along the curved passage; UV.y runs around its arch.
	float ripple = sin(UV.x * 0.85 + sin(UV.y * 19.0) + TIME * 0.32)
		* sin(UV.y * 29.0 - TIME * 0.24);
	float caustic = pow(max(0.0, ripple), 5.0);
	float depth_light = pow(max(0.0, sin(UV.y * 3.14159265)), 0.8);
	ALBEDO = mix(vec3(0.012, 0.09, 0.17), vec3(0.045, 0.34, 0.43), depth_light);
	ALBEDO += vec3(0.055, 0.19, 0.16) * caustic;
}
