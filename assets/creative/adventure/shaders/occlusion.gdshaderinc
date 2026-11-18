// Sichtschutz für Lumo: Fragmente zwischen Kamera und Fokus (Lumo) sowie sehr
// nahe an der Kamera werden im Raster ausgeblendet (keine Transparenz-Sortierung,
// mobil- und gl_compatibility-tauglich). focus_world.y < -500 schaltet ab.
uniform vec3 focus_world = vec3(0.0, -1000.0, 0.0);
uniform float focus_radius = 2.2;
uniform float near_fade = 2.6;

float lumo_dither(vec2 frag) {
	vec2 p = floor(frag);
	return fract(dot(p, vec2(0.5, 0.25)) + p.y * 0.125 + p.x * 0.0625);
}

void lumo_occlusion(vec3 view_pos, mat4 view_matrix, vec2 frag) {
	float cam_d = length(view_pos);
	float fade = 0.0;
	if (cam_d < near_fade) {
		fade = 1.0 - cam_d / near_fade;
	}
	if (focus_world.y > -500.0) {
		vec3 f = (view_matrix * vec4(focus_world, 1.0)).xyz;
		float fd = length(f);
		if (cam_d < fd - 0.9) {
			float along = cam_d / max(fd, 0.001);
			vec3 ray = normalize(f) * cam_d;
			float off = length(view_pos - ray);
			float r = focus_radius * mix(0.55, 1.0, along);
			fade = max(fade, (1.0 - smoothstep(r * 0.6, r, off)) * 0.85);
		}
	}
	if (fade > 0.0 && lumo_dither(frag) < fade) {
		discard;
	}
}
