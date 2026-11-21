shader_type spatial;
// Lumos Riesengarten – Teichwasser ohne Screen-Texture: Wellen über zwei laufende
// Rauschfelder, Fresnel-Spiegelung zum Himmelsverlauf, Sonnenglitzern, flacher Rand hell.
// Läuft auf gl_compatibility, Mobile und Forward+ gleich.
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec4 deep : source_color = vec4(0.10, 0.36, 0.42, 1.0);
uniform vec4 shallow : source_color = vec4(0.32, 0.66, 0.62, 1.0);
uniform vec4 sky_top : source_color = vec4(0.47, 0.77, 0.94, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.91, 0.96, 0.85, 1.0);
uniform float wave_scale = 0.11;
uniform float wave_speed = 0.35;
uniform float alpha = 0.9;

float hash2(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * wave_scale;
	float t = TIME * wave_speed;
	float e = 0.08;
	float h0 = noise2(p + vec2(t, t * 0.6)) + noise2(p * 2.3 - vec2(t * 1.3, -t * 0.4)) * 0.5;
	float hx = noise2(p + vec2(e, 0.0) + vec2(t, t * 0.6)) + noise2((p + vec2(e, 0.0)) * 2.3 - vec2(t * 1.3, -t * 0.4)) * 0.5;
	float hz = noise2(p + vec2(0.0, e) + vec2(t, t * 0.6)) + noise2((p + vec2(0.0, e)) * 2.3 - vec2(t * 1.3, -t * 0.4)) * 0.5;
	vec3 n_world = normalize(vec3((h0 - hx) * 2.4, 1.0, (h0 - hz) * 2.4));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	vec3 reflected = mix(sky_horizon.rgb, sky_top.rgb, clamp(n_world.y * 0.4 + facing * 0.5, 0.0, 1.0));
	vec3 body = mix(deep.rgb, shallow.rgb, h0 * 0.45);
	ALBEDO = mix(body, reflected, 0.25 + fresnel * 0.6);
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	ALPHA = mix(alpha, 1.0, fresnel);
}
