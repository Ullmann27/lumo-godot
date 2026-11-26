shader_type spatial;
render_mode cull_disabled;
// Meer und Seen der Signatur-Strecken: sanfte Wellen (Gerstner-artig, zwei Richtungen),
// Fresnel-Glanz, Schaumkronen. Ohne Bildschirm-/Tiefentextur, läuft auf allen Renderern.
uniform vec4 deep : source_color = vec4(0.04, 0.22, 0.36, 1.0);
uniform vec4 shallow : source_color = vec4(0.12, 0.55, 0.62, 1.0);
uniform vec4 foam : source_color = vec4(0.92, 0.97, 1.0, 1.0);
uniform float wave_height = 0.35;
uniform float wave_scale = 0.045;
uniform float glint = 0.6;
// Aussparungen (x, z, Radius): dort, wo eine Felsröhre unter den Meeresspiegel taucht,
// wird die Wasseroberfläche nicht gezeichnet (sonst stünde sie quer im Tunnel).
uniform vec4 holes[24];
uniform int hole_count = 0;

varying vec3 v_world;

float wave(vec2 p, vec2 dir, float freq, float speed) {
	return sin(dot(p, dir) * freq + TIME * speed);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = wave(w.xz, vec2(0.8, 0.6), 0.09, 1.1) * 0.6 + wave(w.xz, vec2(-0.3, 0.95), 0.15, 1.7) * 0.4;
	VERTEX.y += h * wave_height;
	v_world = w;
}

void fragment() {
	for (int i = 0; i < hole_count; i++) {
		if (distance(v_world.xz, holes[i].xy) < holes[i].z) {
			discard;
		}
	}
	vec2 p = v_world.xz * wave_scale;
	float ripple = sin(p.x * 7.0 + TIME * 1.3) * sin(p.y * 6.0 - TIME * 1.1);
	float ripple2 = sin((p.x + p.y) * 11.0 - TIME * 2.0);
	vec3 n = normalize(vec3(ripple * 0.18 + ripple2 * 0.06, 1.0, ripple2 * 0.12 - ripple * 0.05));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float crest = smoothstep(0.82, 0.98, ripple * 0.5 + 0.5 + ripple2 * 0.15);
	vec3 colour = mix(deep.rgb, shallow.rgb, 0.45 + 0.35 * ripple);
	colour = mix(colour, foam.rgb, crest * 0.35);
	ALBEDO = colour;
	ROUGHNESS = 0.08;
	METALLIC = 0.1;
	SPECULAR = 0.6 + glint * 0.4;
	EMISSION = vec3(0.6, 0.75, 0.85) * fres * 0.18;
}
