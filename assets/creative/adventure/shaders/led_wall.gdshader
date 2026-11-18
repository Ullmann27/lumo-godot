// LED-Wand der Konzertbühne: Pixelraster, Equalizer im Takt, Ringe, Themenfarben.
// beat_phase (0..1) kommt aus dem Spiel; Helligkeit ändert sich weich (keine Blitze,
// Puls < 3 Hz). calm = 1 ("Ruhige Bewegung") friert alle Lichtwechsel ein.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 color_a : source_color = vec4(0.38, 0.86, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.73, 0.59, 1.0, 1.0);
uniform vec4 color_c : source_color = vec4(1.0, 0.79, 0.52, 1.0);
uniform float beat_phase = 0.0;
uniform float beat_count = 0.0;
uniform float energy = 0.5;
uniform float calm = 0.0;
uniform vec2 pixels = vec2(112.0, 64.0);

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	vec2 cell = floor(uv * pixels);
	vec2 local = fract(uv * pixels);
	float dot_mask = smoothstep(0.5, 0.32, length(local - 0.5));
	vec2 c = (cell + 0.5) / pixels;
	float pulse = mix(0.5 + 0.5 * cos(beat_phase * 6.2831), 0.5, calm);
	float bars = 28.0;
	float b = floor(c.x * bars);
	float k = mix(floor(beat_count), 0.0, calm);
	float h0 = hash(b * 3.1 + k * 7.7);
	float h1 = hash(b * 3.1 + (k + 1.0) * 7.7);
	float level = mix(h0, h1, smoothstep(0.0, 1.0, mix(beat_phase, 0.0, calm)));
	level = 0.18 + level * (0.35 + energy * 0.45) * (0.75 + 0.25 * pulse);
	float y = 1.0 - c.y;
	float eq = step(y, level) * step(0.18, fract(c.x * bars));
	vec2 centered = (c - vec2(0.5, 0.45)) * vec2(pixels.x / pixels.y, 1.0);
	float r = length(centered);
	float ring = smoothstep(0.035, 0.0, abs(fract(r * 2.2 - mix(beat_phase * 0.5, 0.0, calm)) - 0.5) - 0.03) * (1.0 - smoothstep(0.3, 1.1, r));
	vec3 grad = mix(color_a.rgb, color_b.rgb, c.x);
	vec3 col = grad * eq * mix(0.55, 1.0, y);
	col += color_c.rgb * ring * 0.55;
	col += grad * 0.07;
	ALBEDO = col * dot_mask * (0.85 + 0.25 * pulse);
}
