shader_type spatial;
render_mode unshaded, cull_disabled;
// A slowly drifting sea of moonlit clouds far below the floating islands.

uniform vec4 shadow_color : source_color = vec4(0.20, 0.21, 0.50, 1.0);
uniform vec4 lit_color : source_color = vec4(0.70, 0.73, 0.95, 1.0);
uniform float scale = 0.018;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 4; i++) {
		value += noise(p) * amplitude;
		p = p * 2.03 + vec2(4.1, 1.7);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = world.xz * scale + vec2(TIME * 0.006, TIME * 0.003);
	float puff = smoothstep(0.30, 0.82, fbm(p));
	float rim = smoothstep(0.55, 0.95, fbm(p * 1.9 + 3.0));
	ALBEDO = mix(shadow_color.rgb, lit_color.rgb, puff * 0.75 + rim * 0.25);
	// Fade to the sky colour towards the horizon so the sea has no visible edge.
	float far = smoothstep(260.0, 620.0, length(world.xz));
	ALBEDO = mix(ALBEDO, shadow_color.rgb * 0.85, far);
}
