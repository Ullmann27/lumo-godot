shader_type spatial;
// Lumo-Kart soft particles: tyre smoke, dust plumes, snow powder, pebbles,
// leaves, heat-shimmer wisps and confetti. Same spawn-data layout as
// kart_fx_spark.gdshader; CUSTOM = (drag, spin seed, spin speed, kind).
//   kind 0 smoke/dust, 1 pebble/clump, 2 leaf, 3 heat wisp, 4 confetti
// Mobile + Compatibility safe: no screen or depth texture.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, skip_vertex_transform;

uniform float fx_time = 0.0;
uniform vec3 light_tint = vec3(1.0);

varying vec4 v_color;
varying vec4 v_data;
varying float v_depth;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 p0 = MODEL_MATRIX[3].xyz;
	vec3 v0 = MODEL_MATRIX[0].xyz;
	vec3 sz = MODEL_MATRIX[1].xyz;
	vec3 tl = MODEL_MATRIX[2].xyz;
	vec4 extra = INSTANCE_CUSTOM;
	float age = fx_time - tl.x;
	float life = max(tl.y, 0.001);
	float k = age / life;
	v_color = COLOR;
	v_data = vec4(clamp(k, 0.0, 1.0), extra.w, extra.y, age);
	v_depth = 10.0;
	if (age < 0.0 || k >= 1.0) {
		VERTEX = vec3(0.0);
	} else {
		float drag = max(extra.x, 0.0001);
		float slow = exp(-drag * age);
		vec3 gravity = vec3(0.0, -9.8 * tl.z, 0.0);
		vec3 p = p0 + v0 * (1.0 - slow) / drag + 0.5 * gravity * age * age;
		// Smoke grows fast, then slowly (ease-out); solid bits keep their size.
		float grow = extra.w < 0.5 || extra.w > 2.5 && extra.w < 3.5 ? 1.0 - (1.0 - k) * (1.0 - k) : k;
		float size = mix(sz.x, sz.y, grow);
		vec3 center = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
		v_depth = -center.z;
		float angle = extra.y * 6.2831853 + age * extra.z;
		vec2 corner = VERTEX.xy;
		if (extra.w > 3.5) {
			// Confetti flips while it flutters down.
			corner.x *= cos(age * extra.z * 1.7 + extra.y * 9.0);
			corner.y *= 0.55;
		}
		mat2 spin = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
		VERTEX = center + vec3(spin * corner * size, 0.0);
	}
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float k = v_data.x;
	float kind = v_data.y;
	vec3 colour = v_color.rgb * light_tint;
	float alpha;
	if (kind < 0.5) {
		float n = value_noise(q * 2.3 + v_data.z * 17.0 + vec2(0.0, v_data.w * 0.6));
		// Billowy edge: the noise eats into the rim, the core stays dense.
		float soft = smoothstep(1.0, 0.25, r + (n - 0.5) * 0.45);
		float fade = smoothstep(0.0, 0.06, k) * (1.0 - k) * (1.0 - k * 0.5);
		alpha = soft * fade * 1.35;
		// Sunlit top, softer underside: volume without lighting cost.
		colour *= 0.82 + 0.3 * (0.5 - q.y * 0.5) + 0.12 * n;
	} else if (kind < 1.5) {
		alpha = smoothstep(1.0, 0.72, r) * (1.0 - smoothstep(0.75, 1.0, k));
		colour *= 1.15 - 0.55 * r - 0.25 * q.y;
	} else if (kind < 2.5) {
		float leaf = length(vec2(q.x * 2.1, q.y));
		alpha = smoothstep(1.0, 0.85, leaf) * (1.0 - smoothstep(0.7, 1.0, k));
		colour *= 0.85 + 0.3 * step(abs(q.x), 0.06);
	} else if (kind < 3.5) {
		// Heat wisp: a faint wavering ring brightens what is behind the jet.
		float wave = sin((r + v_data.w * 2.0) * 14.0 + q.x * 6.0) * 0.5 + 0.5;
		alpha = smoothstep(1.0, 0.3, r) * wave * (1.0 - k) * smoothstep(0.0, 0.15, k);
	} else {
		alpha = step(abs(q.x), 0.9) * step(abs(q.y), 0.9) * (1.0 - smoothstep(0.8, 1.0, k));
		colour *= 1.05;
	}
	ALBEDO = colour;
	// Clouds that drift right up to the lens thin out instead of covering the picture.
	ALPHA = clamp(alpha * v_color.a * smoothstep(1.2, 4.0, v_depth), 0.0, 1.0);
}
