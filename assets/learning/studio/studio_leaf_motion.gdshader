shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.20, 0.43, 0.30, 1.0);
uniform float motion_weight : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	float tip_weight = smoothstep(0.48, 1.05, VERTEX.y);
	float breeze = sin(TIME * 1.35 + VERTEX.x * 0.7 + VERTEX.z * 0.4);
	VERTEX.x += breeze * tip_weight * 0.022 * motion_weight;
	VERTEX.z += cos(TIME * 0.95 + VERTEX.x) * tip_weight * 0.013 * motion_weight;
}

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.86;
	SPECULAR = 0.18;
}
