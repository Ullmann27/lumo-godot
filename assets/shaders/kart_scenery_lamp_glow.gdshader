// Leuchtmittel, Lichthof, Lichtkegel und Lichtfleck der Streckenleuchten (additiv).
// Volumen-Ersatz ohne Bildschirmtextur: Kegel blendet mit Blickwinkel und Hoehe aus.
// COLOR.r Helligkeit, COLOR.g Art (0 Leuchtkoerper, .25 Hof, .5 Kegel, .75 Bodenfleck,
// 1 Flamme/Gluehwuermchen), COLOR.b Phase. INSTANCE_CUSTOM.rgb Lichtfarbe, .a Faktor.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float intensity : hint_range(0.0, 4.0) = 1.0;
// Leuchtmittel hell genug fuer Glow/Bloom (Werte ueber 1).
uniform float bulb_energy : hint_range(0.0, 8.0) = 2.6;
// 0 Tag (Kegel/Fleck fast unsichtbar), 1 Nacht.
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float cone_strength : hint_range(0.0, 2.0) = 1.0;

varying float v_kind;
varying float v_power;
varying float v_phase;
varying vec4 v_light;

void vertex() {
	v_kind = COLOR.g;
	v_power = COLOR.r;
	v_phase = COLOR.b;
	v_light = INSTANCE_CUSTOM;
	if (COLOR.g > 0.9 && COLOR.a < 0.75) {
		// Gluehwuermchen und Funken schweben langsam
		float ph = COLOR.b * 6.2831 + MODEL_MATRIX[3].x * 0.37;
		VERTEX += vec3(sin(TIME * 0.7 + ph) * 0.35, sin(TIME * 1.1 + ph * 1.3) * 0.25 + fract(TIME * 0.12 + COLOR.b) * 0.2,
			cos(TIME * 0.6 + ph) * 0.35);
	}
}

void fragment() {
	vec3 colour = v_light.rgb * 2.0;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec2 c = UV - vec2(0.5);
	float radial = clamp(1.0 - length(c) * 2.0, 0.0, 1.0);
	float k = 0.0;
	float day = 1.0 - night;
	if (v_kind < 0.12) {
		k = bulb_energy * (0.55 + 0.45 * night) * (0.75 + 0.25 * facing);
		colour = mix(colour, vec3(1.0), 0.35);
	} else if (v_kind < 0.37) {
		k = radial * radial * facing * (0.28 + 0.72 * night);
	} else if (v_kind < 0.62) {
		float along = UV.y;
		float body = pow(1.0 - along, 1.25) * smoothstep(0.0, 0.08, along);
		k = body * pow(facing, 1.6) * 0.32 * cone_strength * (0.08 + 0.92 * night);
	} else if (v_kind < 0.87) {
		k = radial * radial * (0.1 + 0.9 * night) * 0.55;
	} else {
		float flick = 0.6 + 0.4 * sin(TIME * 9.0 + v_phase * 23.0) * sin(TIME * 5.3 + v_phase * 11.0);
		k = radial * radial * flick * 1.8;
		colour = mix(colour, vec3(1.0, 0.85, 0.4), 0.3);
	}
	ALBEDO = colour * k * v_power * intensity * v_light.a;
}
