shader_type spatial;
render_mode cull_disabled;
// Moving heat between irregular cooled crust plates; no repeated horizontal stripes.
uniform vec4 hot : source_color = vec4(1.0, 0.36, 0.055, 1.0);
vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1,311.7)), dot(p, vec2(269.5,183.3)))) * 43758.5453);
}
void fragment() {
	vec2 p = UV * 165.0 + vec2(TIME * 0.014, -TIME * 0.009);
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbour = vec2(float(x), float(y));
			vec2 offset = hash2(cell + neighbour);
			float distance = length(neighbour + offset - f);
			if (distance < first) { second = first; first = distance; }
			else { second = min(second, distance); }
		}
	}
	float channel = 1.0 - smoothstep(0.025, 0.15, second - first);
	float pulse = 0.87 + 0.13 * sin(TIME * 1.4 + cell.x * 0.8 + cell.y * 1.2);
	vec3 crust = mix(vec3(0.025,0.015,0.024), vec3(0.13,0.035,0.025), first);
	ALBEDO = mix(crust, hot.rgb, channel * 0.86);
	EMISSION = hot.rgb * channel * pulse * 1.9;
	ROUGHNESS = mix(0.91, 0.32, channel);
}
