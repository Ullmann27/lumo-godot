shader_type spatial;
// Leuchtende Kleinteile (Laternen, Bojen, Ampeln, Lichterketten, Reflektoren).
// COLOR.a = Blinkanteil (0 = ruhig, 1 = pulsiert). UV2.x = Phase.
// Pulsfrequenz <= 1 Hz (kein Flackern über 3 Hz). Unshaded = billig und
// auf Mobile/gl_compatibility gleich.
render_mode unshaded, cull_back;

uniform float energy = 2.2;
uniform float pulse_hz : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	float blink = COLOR.a;
	float wave = 0.5 + 0.5 * sin(TIME * 6.2831 * pulse_hz + UV2.x * 6.2831);
	float level = mix(1.0, 0.25 + 0.75 * wave, blink);
	ALBEDO = COLOR.rgb * energy * level;
}
