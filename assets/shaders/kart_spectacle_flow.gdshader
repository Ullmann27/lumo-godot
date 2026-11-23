shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform bool motes = false;
uniform float motion_gain : hint_range(0.0, 1.0) = 1.0;
uniform vec4 flow_color : source_color = vec4(0.3, 0.8, 0.9, 1.0);
varying vec4 instance_tint;
varying float phase;
void vertex() {
	instance_tint = COLOR;
	phase = INSTANCE_CUSTOM.x * 6.2831853;
	if (motes) {
		VERTEX.x += sin(TIME * 0.7 + phase) * 0.65 * motion_gain;
		VERTEX.y += sin(TIME * 1.1 + phase) * 0.75 * motion_gain;
		VERTEX.z += cos(TIME * 0.8 + phase) * 0.45 * motion_gain;
	}
}
void fragment() {
	if (motes) {
		ALBEDO = instance_tint.rgb;
		EMISSION = instance_tint.rgb * 0.8;
		ROUGHNESS = 0.65;
	} else {
		float run = UV.y * 18.0 - TIME * 1.5 * motion_gain;
		float ribbon = 0.5 + 0.5 * sin(run + sin(UV.x * 31.0) * 0.5);
		float strands = 0.5 + 0.5 * sin(UV.x * 71.0 + run * 0.15);
		ALBEDO = flow_color.rgb * (0.55 + ribbon * 0.3 + strands * 0.15);
		EMISSION = flow_color.rgb * (0.2 + ribbon * 0.22);
		ROUGHNESS = 0.25;
		METALLIC = 0.12;
	}
}
