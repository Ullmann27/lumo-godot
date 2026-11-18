shader_type spatial;
// Lumo-Kart-Detailschicht: Kleinteile mit Vertex-Farbe (ein Material für alle).
// COLOR.a = Bewegungsgewicht (Arme winken, Fahnen flattern, Flügel schlagen).
// UV2.x = Phase je Kleinteil. Mobile/gl_compatibility: keine Bildschirm-/Tiefentextur.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float wave_strength = 0.22;
uniform float wave_speed = 3.1; // rad/s, ~0.5 Hz
uniform float orbit_speed = 0.0; // > 0: ganzes Mesh kreist um seinen Ursprung (Vogelschwarm)
uniform float flap = 0.0;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.72;

varying float v_weight;

void vertex() {
	float w = COLOR.a;
	v_weight = w;
	float phase = UV2.x;
	if (orbit_speed > 0.0) {
		float a = TIME * orbit_speed + phase;
		float c = cos(a);
		float s = sin(a);
		VERTEX = vec3(c * VERTEX.x + s * VERTEX.z, VERTEX.y + sin(TIME * 0.7 + phase) * 0.6, -s * VERTEX.x + c * VERTEX.z);
		NORMAL = vec3(c * NORMAL.x + s * NORMAL.z, NORMAL.y, -s * NORMAL.x + c * NORMAL.z);
	}
	if (w > 0.001) {
		vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float t = TIME * wave_speed + phase * 6.2831 + world.x * 0.07;
		if (flap > 0.0) {
			VERTEX.y += w * sin(TIME * 6.0 + phase * 9.0) * 0.35;
		} else {
			// Seitliches Schwingen + leichte Flatterwelle entlang der Normale.
			VERTEX.x += w * sin(t) * wave_strength;
			VERTEX.z += w * cos(t * 0.8) * wave_strength * 0.5;
			VERTEX += NORMAL * w * sin(t * 2.3 + world.y * 2.0) * wave_strength * 0.35;
		}
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness_base;
	SPECULAR = 0.4;
}
