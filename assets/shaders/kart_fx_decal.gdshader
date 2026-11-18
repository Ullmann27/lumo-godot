shader_type spatial;
// Lumo-Kart road and rail marks: brake and drift rubber, sand grooves, snow
// tracks, scrape streaks on the rail. Each instance is one flat ribbon
// segment. CUSTOM = (birth time, life, start opacity, kind)
//   kind 0 tyre mark with tread, 1 glowing streak, 2 metal scratch
// fx_time stops while paused. Mobile + Compatibility safe.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform float fx_time = 0.0;

varying vec4 v_color;
varying vec2 v_mark;

void vertex() {
	v_color = COLOR;
	float age = fx_time - INSTANCE_CUSTOM.x;
	float life = max(INSTANCE_CUSTOM.y, 0.001);
	float k = age / life;
	float fade = age < 0.0 || k >= 1.0 ? 0.0 : (1.0 - k * k) * INSTANCE_CUSTOM.z;
	v_mark = vec2(fade, INSTANCE_CUSTOM.w);
	if (fade <= 0.0) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	float across = UV.x;
	float edge = smoothstep(0.0, 0.2, across) * smoothstep(1.0, 0.8, across);
	float alpha;
	vec3 colour = v_color.rgb;
	if (v_mark.y < 0.5) {
		float tread = 0.72 + 0.28 * sin(across * 34.0);
		alpha = edge * tread;
	} else if (v_mark.y < 1.5) {
		alpha = edge * edge;
		colour *= 1.0 + 0.6 * smoothstep(0.35, 0.5, 0.5 - abs(across - 0.5));
	} else {
		float line = smoothstep(0.12, 0.0, abs(across - 0.5));
		alpha = edge * 0.75 + line * 0.5;
		colour = mix(colour, vec3(0.93, 0.95, 1.0), line);
	}
	ALBEDO = colour;
	ALPHA = clamp(alpha * v_color.a * v_mark.x, 0.0, 1.0);
}
