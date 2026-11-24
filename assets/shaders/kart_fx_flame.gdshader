shader_type spatial;
// Lumo-Kart turbo flames. One teardrop mesh per exhaust: white-blue core,
// coloured mantle, licking noise and shock diamonds ("Mach-Ringe") right
// after ignition. The same batch draws the warm glow patch on the road
// (flattened teardrop, kind 1) and the cooling afterglow of the pipes (kind 2).
// CUSTOM = (intensity, mach, kind, seed). Noise only moves the shape; the
// brightness never pulses, so nothing blinks. Mobile + Compatibility safe.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform float fx_time = 0.0;

varying vec3 v_local;
varying vec4 v_data;
varying vec4 v_color;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float profile(float t) {
	return 0.5 * pow(max(1.0 - t, 0.0), 0.6) * (0.6 + 0.4 * smoothstep(0.0, 0.25, t));
}

void vertex() {
	v_local = VERTEX;
	v_data = INSTANCE_CUSTOM;
	v_color = COLOR;
	if (INSTANCE_CUSTOM.x <= 0.001) {
		VERTEX = vec3(0.0);
	} else if (INSTANCE_CUSTOM.z < 0.5) {
		float t = VERTEX.z;
		float seed = INSTANCE_CUSTOM.w * 7.0;
		VERTEX.xy += vec2(
			sin(t * 9.0 - fx_time * 21.0 + seed), cos(t * 7.0 - fx_time * 17.0 + seed)
		) * 0.07 * t;
	}
}

void fragment() {
	float intensity = v_data.x;
	float kind = v_data.z;
	float t = clamp(v_local.z, 0.0, 1.0);
	vec3 colour;
	float alpha;
	if (kind < 0.5) {
		float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.1);
		float angle = atan(v_local.y, v_local.x);
		float n = value_noise(vec2(t * 5.0 - fx_time * 9.0 + v_data.w * 3.0, angle * 1.6));
		float body = 1.0 - smoothstep(0.45, 1.0, t + (n - 0.5) * 0.45);
		// Small blue-white core at the nozzle, orange body, deep red licking tips.
		float core = smoothstep(0.32, 0.0, t + (1.0 - edge) * 0.6);
		colour = mix(v_color.rgb, vec3(0.75, 0.9, 1.0) * 1.3, core);
		colour = mix(colour, v_color.rgb * vec3(1.0, 0.45, 0.25), smoothstep(0.35, 0.9, t));
		float diamonds = v_data.y * pow(max(0.0, sin(t * 34.0 - 1.2)), 10.0) * (1.0 - t);
		colour += vec3(1.0, 0.95, 0.85) * diamonds * 1.5;
		alpha = (edge * body * (0.45 + 0.4 * n) + diamonds) * intensity * 0.8;
	} else if (kind < 1.5) {
		vec2 p = vec2(v_local.x * 2.0, (v_local.z - 0.35) * 1.6);
		float glow = clamp(1.0 - length(p), 0.0, 1.0);
		colour = v_color.rgb;
		alpha = glow * glow * intensity * 0.55;
	} else {
		float edge = abs(dot(normalize(NORMAL), normalize(VIEW)));
		colour = v_color.rgb * (0.7 + 0.6 * edge);
		alpha = intensity * edge;
	}
	ALBEDO = colour;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
