shader_type spatial;
render_mode unshaded, cull_disabled;
// Wolkenmeer unter der Himmelsmetropole: weiche, langsam ziehende Haufenwolken (fbm aus
// Wertrauschen), Licht von oben, lila-blaue Schatten in den Tälern. Ohne Texturen.
uniform vec4 bright : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shade : source_color = vec4(0.62, 0.68, 0.86, 1.0);
uniform vec2 drift = vec2(1.6, 0.6);
uniform float storm = 0.0;

varying vec3 v_world;

float hash_value(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_value(i), hash_value(i + vec2(1, 0)), f.x),
		mix(hash_value(i + vec2(0, 1)), hash_value(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 4; i++) {
		total += noise(p) * amp;
		p = p * 2.03 + vec2(17.1, 9.3);
		amp *= 0.5;
	}
	return total;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (v_world.xz + drift * TIME) * 0.012;
	float puff = fbm(p);
	float detail = fbm(p * 3.1 + 4.0);
	float light = smoothstep(0.25, 0.85, puff * 0.8 + detail * 0.3);
	vec3 colour = mix(shade.rgb, bright.rgb, light);
	colour = mix(colour, colour * vec3(0.55, 0.58, 0.7), storm);
	ALBEDO = colour;
}
