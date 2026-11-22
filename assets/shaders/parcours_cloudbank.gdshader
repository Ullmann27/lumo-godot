shader_type spatial;
render_mode unshaded, cull_disabled;

float hash_cloud(vec2 p) {
	return fract(sin(dot(mod(p, 256.0), vec2(127.1, 311.7))) * 43758.5453);
}

float cloud_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_cloud(cell), hash_cloud(cell + vec2(1, 0)), f.x),
		mix(hash_cloud(cell + vec2(0, 1)), hash_cloud(cell + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 54.0;
	float dunes = cloud_noise(p) * 0.62 + cloud_noise(p * 2.17 + 3.2) * 0.26
		+ cloud_noise(p * 5.26 + 8.0) * 0.12;
	float light = smoothstep(0.20, 0.82, dunes);
	ALBEDO = mix(vec3(0.18, 0.32, 0.48), vec3(0.73, 0.79, 0.81), light);
}
