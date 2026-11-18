// Tageshimmel der Lumo-Kart-Strecken: klarer Verlauf, Sonnenscheibe mit Hof,
// statische Haufenwolken (kein TIME: die Himmelsspiegelung wird nicht jedes Bild
// neu berechnet), optional Sterne und Nordlicht. Mobile/gl_compatibility-tauglich.
shader_type sky;

uniform vec4 zenith : source_color = vec4(0.18, 0.43, 0.77, 1.0);
uniform vec4 horizon : source_color = vec4(0.66, 0.8, 0.92, 1.0);
uniform vec4 haze : source_color = vec4(0.95, 0.85, 0.72, 1.0);
uniform vec4 ground : source_color = vec4(0.55, 0.6, 0.62, 1.0);
uniform float clouds : hint_range(0.0, 1.0) = 0.4;
uniform vec4 cloud_color : source_color = vec4(1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.66, 0.72, 0.8, 1.0);
uniform float sun_size = 0.03;
uniform float stars : hint_range(0.0, 1.0) = 0.0;
uniform float aurora : hint_range(0.0, 1.0) = 0.0;
uniform float energy = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 col;
	if (h >= 0.0) {
		float t = pow(clamp(h, 0.0, 1.0), 0.45);
		col = mix(horizon.rgb, zenith.rgb, t);
		col = mix(col, haze.rgb, pow(1.0 - clamp(h, 0.0, 1.0), 9.0) * 0.75);
	} else {
		col = mix(haze.rgb * 0.92, ground.rgb, clamp(-h * 4.0, 0.0, 1.0));
	}
	vec3 sun_dir = -LIGHT0_DIRECTION;
	float sun_dot = LIGHT0_ENABLED ? max(dot(dir, normalize(sun_dir)), 0.0) : 0.0;
	vec3 sun_col = LIGHT0_ENABLED ? LIGHT0_COLOR : vec3(1.0);
	col += sun_col * pow(sun_dot, 8.0) * 0.08 + sun_col * pow(sun_dot, 80.0) * 0.3;
	if (h > 0.0) {
		// Wolken auf einer flachen Schicht ueber der Strecke
		vec2 uv = dir.xz / (h + 0.12) * 1.3;
		float shape = fbm(uv * 0.9 + vec2(3.1, 0.7));
		float detail = fbm(uv * 3.1 + vec2(shape * 1.4));
		float cover = smoothstep(1.0 - clouds * 0.8, 1.08 - clouds * 0.55, shape * 0.75 + detail * 0.35);
		cover *= smoothstep(0.0, 0.14, h);
		float light_side = clamp(dot(normalize(vec3(dir.x, 0.0, dir.z)), normalize(vec3(sun_dir.x, 0.0, sun_dir.z))) * 0.5 + 0.5, 0.0, 1.0);
		vec3 cloud = mix(cloud_shadow.rgb, cloud_color.rgb, clamp(detail * 1.2 - 0.1 + light_side * 0.25, 0.0, 1.0));
		cloud += sun_col * pow(sun_dot, 12.0) * 0.4 * (1.0 - cover * 0.6);
		col = mix(col, cloud, cover * 0.92);
		if (stars > 0.0) {
			vec2 g = dir.xz / (h + 0.3) * 160.0;
			float s = step(0.996, hash(floor(g))) * smoothstep(0.15, 0.6, h) * (1.0 - cover);
			col += vec3(s) * stars;
		}
		if (aurora > 0.0) {
			float band = sin(dir.x * 6.0 + fbm(dir.xz * 3.0) * 4.0) * 0.5 + 0.5;
			float a = smoothstep(0.08, 0.3, h) * smoothstep(0.75, 0.35, h) * pow(band, 3.0) * (1.0 - cover);
			col += mix(vec3(0.25, 1.0, 0.65), vec3(0.6, 0.4, 1.0), clamp(h * 2.0, 0.0, 1.0)) * a * aurora * 0.35;
		}
	}
	if (LIGHT0_ENABLED && h > -0.02) {
		float disc = smoothstep(1.0 - sun_size * 0.02, 1.0 - sun_size * 0.012, sun_dot);
		col = mix(col, sun_col * 3.0, disc);
	}
	COLOR = col * energy;
}
