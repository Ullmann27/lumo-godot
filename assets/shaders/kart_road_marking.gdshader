// Fahrbahnmarkierung mit leichter Abnutzung (Abrieb, Ausbrueche, Glasperlen-Glanz)
// und Bankett/Randstreifen aus Splitt mit Grasnarbe. UV.x quer (m), UV.y laengs (m).
shader_type spatial;

uniform vec4 paint : source_color = vec4(0.96, 0.97, 0.91, 1.0);
uniform vec4 under : source_color = vec4(0.3, 0.31, 0.33, 1.0);
// 0 Markierung, 1 Bankett
uniform int mode = 0;
uniform float wear : hint_range(0.0, 1.0) = 0.35;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	if (mode == 0) {
		float worn = vnoise(UV * vec2(18.0, 2.2)) * 0.6 + vnoise(UV * vec2(60.0, 9.0)) * 0.4;
		float gone = smoothstep(0.62, 0.78, worn) * wear;
		vec3 colour = mix(paint.rgb, under.rgb, gone * 0.85);
		colour *= 0.93 + 0.07 * vnoise(UV * 40.0);
		ALBEDO = colour;
		ROUGHNESS = mix(0.5, 0.85, gone);
		float beads = step(0.985, hash21(floor(UV * vec2(90.0, 90.0)))) * (1.0 - gone);
		SPECULAR = 0.5 + beads * 0.5;
		EMISSION = paint.rgb * beads * 0.08;
	} else {
		float grit = hash21(floor(UV * 34.0));
		float clumps = vnoise(UV * vec2(3.0, 0.8));
		vec3 gravel = under.rgb * (0.75 + grit * 0.4);
		float grass = smoothstep(0.55, 0.75, clumps) * smoothstep(0.1, 0.5, abs(fract(UV.x) - 0.5));
		ALBEDO = mix(gravel, paint.rgb * (0.8 + grit * 0.3), grass);
		ROUGHNESS = 0.95;
		vec2 p = UV * 22.0;
		float h0 = vnoise(p);
		NORMAL_MAP = normalize(vec3((h0 - vnoise(p + vec2(0.1, 0.0))) * 2.5, (h0 - vnoise(p + vec2(0.0, 0.1))) * 2.5, 1.0)) * 0.5 + 0.5;
	}
}
