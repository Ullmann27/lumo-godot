shader_type spatial;
// Lumo-Kart road and rail marks: brake and drift rubber, sand grooves, snow
// tracks, scrape streaks on the rail. Each instance is one piece of a
// continuous band; its corners are rebuilt here from packed end points, so
// neighbouring pieces share their joint edge exactly (no overlaps, no rungs).
//   origin = start centre, basis.x = start->end, basis.y / basis.z = half
//   width vectors at start / end.  CUSTOM = (birth, life, kind, length so far)
//   kind 0 tyre rubber, 1 glowing streak, 2 metal scratch, 3 hot scrape (cools)
// fx_time stops while paused. Mobile + Compatibility safe.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, skip_vertex_transform;

uniform float fx_time = 0.0;

varying vec4 v_color;
varying vec4 v_info;

void vertex() {
	v_color = COLOR;
	vec3 p0 = MODEL_MATRIX[3].xyz;
	vec3 along = MODEL_MATRIX[0].xyz;
	vec3 a0 = MODEL_MATRIX[1].xyz;
	vec3 a1 = MODEL_MATRIX[2].xyz;
	float s = VERTEX.z + 0.5;
	float x = VERTEX.x * 2.0;
	float age = fx_time - INSTANCE_CUSTOM.x;
	float k = age / max(INSTANCE_CUSTOM.y, 0.001);
	v_info = vec4(k, INSTANCE_CUSTOM.z, INSTANCE_CUSTOM.w + length(along) * s, x);
	if (age < 0.0 || k >= 1.0) {
		VERTEX = vec3(0.0);
	} else {
		vec3 p = p0 + along * s + mix(a0, a1, s) * x;
		VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	}
}

void fragment() {
	float k = clamp(v_info.x, 0.0, 1.0);
	float kind = v_info.y;
	float v = v_info.z;
	float x = v_info.w;
	float across = abs(x);
	// Slow fade: full for most of the life, then gone.
	float fade = 1.0 - smoothstep(0.35, 1.0, k);
	float start = smoothstep(0.0, 0.6, v);
	vec3 colour = v_color.rgb;
	float alpha;
	if (kind < 0.5) {
		// Rubber band: soft edges, darker core, fine tread blocks along the band.
		float body = smoothstep(1.0, 0.45, across);
		float core = 0.75 + 0.25 * smoothstep(0.8, 0.0, across);
		float tread = 0.86 + 0.14 * sin(v * 26.0 + sign(x) * 1.6) * smoothstep(0.15, 0.6, across);
		alpha = body * core * tread;
	} else if (kind < 1.5) {
		alpha = smoothstep(1.0, 0.2, across);
		colour *= 1.0 + 0.6 * smoothstep(0.4, 0.0, across);
	} else if (kind < 2.5) {
		float line = smoothstep(0.25, 0.0, across);
		alpha = smoothstep(1.0, 0.6, across) * 0.75 + line * 0.5;
		colour = mix(colour, vec3(0.93, 0.95, 1.0), line);
	} else {
		// Hot scrape: glows orange-white, cools to a dark scratch within a second.
		float heat = 1.0 - smoothstep(0.0, 0.14, k);
		float line = smoothstep(0.5, 0.0, across);
		vec3 hot = mix(vec3(1.0, 0.45, 0.1), vec3(1.0, 0.92, 0.7), line);
		colour = mix(colour, hot * 1.6, heat);
		alpha = smoothstep(1.0, 0.5, across) * (0.8 + 0.2 * heat);
	}
	ALBEDO = colour;
	ALPHA = clamp(alpha * v_color.a * fade * start, 0.0, 1.0);
}
