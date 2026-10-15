shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
// Falling water ribbon: streaks scroll downwards and dissolve into mist at the bottom.

uniform vec4 water : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform vec4 foam : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform float speed = 0.9;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743);
}

void fragment() {
	// UV.x across the fall (0..1), UV.y from the lip (0) to the bottom (1).
	float column = floor(UV.x * 18.0);
	float flow = fract(UV.y * 3.0 - TIME * speed * (0.8 + hash(vec2(column, 1.0)) * 0.6));
	float streak = smoothstep(0.0, 0.25, flow) * (1.0 - smoothstep(0.55, 1.0, flow));
	// Keep smoothstep limits ascending: reversed limits are undefined in GLSL.
	float edge = smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x));
	// Fine, independently moving white-water filaments prevent a flat striped sheet.
	float filament_wave = sin(UV.x * 79.0 + UV.y * 23.0 - TIME * speed * 4.2);
	float filament = smoothstep(0.63, 0.96, filament_wave * 0.5 + 0.5);
	float bottom_foam = smoothstep(0.66, 0.98, UV.y);
	float white_water = clamp(streak * 0.58 + filament * 0.22 + bottom_foam * 0.28, 0.0, 1.0);
	ALBEDO = mix(water.rgb, foam.rgb, white_water);
	ALPHA = edge * (0.56 + streak * 0.26 + filament * 0.08) * (1.0 - smoothstep(0.82, 1.0, UV.y));
}
