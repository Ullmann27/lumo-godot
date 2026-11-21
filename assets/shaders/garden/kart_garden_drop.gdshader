shader_type spatial;
// Lumos Riesengarten – Tautropfen so groß wie ein Kart. Lichtbrechung gefälscht: Innen
// erscheint der Himmel kopfüber (unten hell, oben grün), dazu harte Sonnenspiegelung,
// Fresnel-Rand und ein Brennfleck. Keine Screen- oder Tiefentextur nötig.
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec4 sky : source_color = vec4(0.72, 0.90, 1.0, 1.0);
uniform vec4 grass : source_color = vec4(0.36, 0.62, 0.22, 1.0);
uniform vec3 sun_dir = vec3(0.45, 0.75, 0.35);
uniform float glow = 0.0;

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	// Kopfstehendes Bild der Umgebung (Brechung in der Kugel).
	vec3 refracted = mix(sky.rgb * 1.05, grass.rgb * 0.8, smoothstep(-0.3, 0.6, n.y));
	vec3 reflected = mix(grass.rgb, sky.rgb * 1.1, smoothstep(-0.2, 0.5, reflect(-v, n).y));
	vec3 h = normalize(normalize(sun_dir) + v);
	float spark = pow(clamp(dot(n, h), 0.0, 1.0), 220.0) * 3.5;
	float caustic = pow(clamp(dot(n, -normalize(sun_dir)), 0.0, 1.0), 6.0) * 0.6;
	vec3 colour = mix(refracted, reflected, 0.2 + fresnel * 0.6) + spark + caustic * vec3(1.0, 0.98, 0.85);
	ALBEDO = colour * (1.0 + glow * 0.6);
	ALPHA = clamp(0.45 + fresnel * 0.5 + spark, 0.0, 1.0);
}
