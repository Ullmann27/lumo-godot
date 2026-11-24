shader_type spatial;
// Lumos Riesengarten – Rasen unter allem: großflächige Farbinseln, Mähstreifen und
// feine Halm-Körnung nur in der Nähe (fwidth), damit es in der Ferne ruhig bleibt.
render_mode cull_back, specular_schlick_ggx;

uniform vec4 base : source_color = vec4(0.36, 0.60, 0.24, 1.0);
uniform vec4 light : source_color = vec4(0.52, 0.74, 0.30, 1.0);
uniform vec4 dry : source_color = vec4(0.62, 0.66, 0.32, 1.0);

varying vec3 world_pos;

float hash2(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float large = noise2(p * 0.012) * 0.6 + noise2(p * 0.05) * 0.4;
	float stripes = smoothstep(0.35, 0.65, abs(fract(p.x * 0.025 + p.y * 0.01) - 0.5) * 2.0);
	float fine = 1.0 - smoothstep(0.15, 0.6, length(fwidth(p)));
	float blades = (hash2(floor(p * 3.0)) - 0.5) * fine;
	vec3 colour = mix(base.rgb, light.rgb, large * 0.7 + stripes * 0.18);
	colour = mix(colour, dry.rgb, smoothstep(0.72, 0.95, noise2(p * 0.008 + 7.0)) * 0.5);
	ALBEDO = colour * (1.0 + blades * 0.25);
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
