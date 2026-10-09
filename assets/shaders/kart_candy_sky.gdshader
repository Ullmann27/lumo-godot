shader_type sky;
// Original candy-world atmosphere: blue gradient with soft, rose-lit cloud banks.
uniform vec4 zenith : source_color = vec4(0.14, 0.34, 0.64, 1.0);
uniform vec4 horizon : source_color = vec4(0.64, 0.75, 0.92, 1.0);
uniform vec4 cloud_light : source_color = vec4(0.96, 0.89, 0.91, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.62, 0.66, 0.83, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}
void sky() {
	vec3 d = normalize(EYEDIR);
	float up = max(d.y, 0.0);
	vec3 color = mix(horizon.rgb, zenith.rgb, pow(clamp(up, 0.0, 1.0), 0.5));
	vec2 p = d.xz / max(d.y + 0.16, 0.08) * 2.1;
	float large = noise(p);
	float detail = noise(p * 3.2 + vec2(3.0, 8.0));
	float cloud = smoothstep(0.45, 0.69, large * 0.78 + detail * 0.22);
	cloud *= smoothstep(0.015, 0.12, up) * (1.0 - smoothstep(0.78, 1.0, up));
	vec3 lit = mix(cloud_shadow.rgb, cloud_light.rgb, smoothstep(0.43, 0.78, large));
	COLOR = mix(color, lit, cloud * 0.91);
}
