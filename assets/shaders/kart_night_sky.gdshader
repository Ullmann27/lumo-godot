shader_type sky;
// Blue-hour sky for the floating-island course: gradient, procedural stars and a soft moon.

uniform vec4 zenith : source_color = vec4(0.015, 0.03, 0.12, 1.0);
uniform vec4 horizon : source_color = vec4(0.17, 0.16, 0.45, 1.0);
uniform vec4 glow : source_color = vec4(0.62, 0.40, 0.72, 1.0);
uniform vec4 below : source_color = vec4(0.10, 0.11, 0.30, 1.0);
uniform vec3 moon_direction = vec3(0.32, 0.42, -0.85);
uniform vec4 moon_color : source_color = vec4(0.86, 0.90, 1.0, 1.0);
uniform float star_density = 0.0016;

float hash31(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y, -1.0, 1.0);
	vec3 color = mix(horizon.rgb, zenith.rgb, smoothstep(0.0, 0.55, up));
	// A soft violet band just above the horizon, like the blue hour in the references.
	color = mix(color, glow.rgb, (1.0 - smoothstep(0.0, 0.16, abs(up - 0.03))) * 0.38);
	color = mix(color, below.rgb, smoothstep(0.0, -0.25, up));
	// Stars: one candidate per small direction cell, brighter higher up.
	vec3 cell = floor(d * 260.0);
	float star = step(1.0 - star_density, hash31(cell));
	float twinkle = 0.65 + 0.35 * sin(TIME * 2.3 + hash31(cell + 7.0) * 40.0);
	color += vec3(0.85, 0.90, 1.0) * star * twinkle * smoothstep(0.05, 0.35, up) * 1.4;
	// Moon disc with halo.
	vec3 m = normalize(moon_direction);
	float facing = dot(d, m);
	float disc = smoothstep(0.9988, 0.9992, facing);
	float halo = pow(max(facing, 0.0), 220.0) * 0.55 + pow(max(facing, 0.0), 18.0) * 0.10;
	color += moon_color.rgb * (disc * 2.2 + halo);
	COLOR = color;
}
