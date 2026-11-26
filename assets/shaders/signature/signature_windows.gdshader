shader_type spatial;
// Hochhausfassaden aus der Weltlage: Glasbänder mit Himmelsspiegelung, Fensterraster,
// einzelne leuchtende Fenster. Dächer dunkel. Ein Material für alle Türme (MultiMesh).
uniform vec4 frame : source_color = vec4(0.86, 0.9, 0.97, 1.0);
uniform vec4 glass : source_color = vec4(0.32, 0.55, 0.82, 1.0);
uniform vec4 lit : source_color = vec4(1.0, 0.86, 0.6, 1.0);
uniform float glow = 0.9;

varying vec3 v_world;
varying vec3 v_normal;

float hash_value(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(v_normal);
	if (abs(n.y) > 0.6) {
		ALBEDO = vec3(0.16, 0.18, 0.24);
		ROUGHNESS = 0.7;
	} else {
		float u = abs(n.x) > abs(n.z) ? v_world.z : v_world.x;
		vec2 cell = vec2(u / 3.0, v_world.y / 3.6);
		vec2 f = fract(cell);
		float pane = step(0.12, f.x) * step(f.x, 0.88) * step(0.18, f.y) * step(f.y, 0.86);
		float on = step(0.82, hash_value(floor(cell)));
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		vec3 window = mix(glass.rgb, vec3(0.85, 0.93, 1.0), fres * 0.6);
		ALBEDO = mix(frame.rgb, window, pane);
		EMISSION = lit.rgb * pane * on * glow;
		ROUGHNESS = mix(0.6, 0.06, pane);
		METALLIC = pane * 0.4;
	}
}
