// Rueckstrahler an den Leitplanken: leuchten auf, wenn man frontal darauf zufaehrt
// (Scheinwerfer-/Laternenlicht wird zurueckgeworfen). INSTANCE_CUSTOM = Farbe.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

varying vec4 v_color;
varying float v_dist;

void vertex() {
	v_color = INSTANCE_CUSTOM;
	v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float retro = pow(facing, 10.0) * smoothstep(90.0, 12.0, v_dist);
	vec2 c = UV - vec2(0.5);
	float rim = smoothstep(0.5, 0.36, max(abs(c.x), abs(c.y)));
	ALBEDO = v_color.rgb * (0.22 + 2.6 * retro) * (0.6 + 0.4 * rim);
}
