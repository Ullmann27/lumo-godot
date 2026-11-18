shader_type spatial;
// Lumo-Kart glowing particles (rail sparks, drift sparks, exhaust jets, embers).
// The whole flight is evaluated here from spawn data packed into the MultiMesh
// instance: the CPU only writes a particle once, when it is born.
//   origin  = spawn position (world)       basis.x = start velocity
//   basis.y = (size start, size end, streak seconds)
//   basis.z = (birth time, life, gravity scale)
//   CUSTOM  = (drag, spin seed, cooling*2 + white core, bounce ground + 10000 | 0)
// Sparks with a ground height bounce once, analytically (restitution 0.38),
// then skid along the road.
// fx_time is the race clock: it stops while paused, so sparks freeze in place.
// Mobile + Compatibility safe: no screen or depth texture.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, skip_vertex_transform, fog_disabled;

uniform float fx_time = 0.0;
uniform float intensity = 1.0;

varying vec4 v_color;
varying vec3 v_life;

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
	float cooling = step(1.5, extra.z);
	v_life = vec3(clamp(k, 0.0, 1.0), cooling, extra.z - cooling * 2.0);
	if (age < 0.0 || k >= 1.0) {
		VERTEX = vec3(0.0);
	} else {
		float drag = max(extra.x, 0.0001);
		float slow = exp(-drag * age);
		vec3 gravity = vec3(0.0, -9.8 * tl.z, 0.0);
		vec3 p = p0 + v0 * (1.0 - slow) / drag + 0.5 * gravity * age * age;
		vec3 vel = v0 * slow + gravity * age;
		if (extra.w > 5000.0) {
			// Vertical flight without drag so the landing time is exact.
			float g = max(9.8 * tl.z, 0.01);
			float ground = extra.w - 10000.0;
			float h = max(p0.y - ground, 0.0);
			float hit = (v0.y + sqrt(v0.y * v0.y + 2.0 * g * h)) / g;
			if (age < hit) {
				p.y = p0.y + v0.y * age - 0.5 * g * age * age;
				vel.y = v0.y - g * age;
			} else {
				float up_again = (g * hit - v0.y) * 0.38;
				float after = age - hit;
				p.y = ground + max(0.0, up_again * after - 0.5 * g * after * after);
				vel.y = p.y > ground + 0.001 ? up_again - g * after : 0.0;
			}
		}
		float size = mix(sz.x, sz.y, k);
		vec3 center = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
		vec2 flow = (VIEW_MATRIX * vec4(vel, 0.0)).xy;
		float flow_len = length(flow);
		vec2 offset;
		if (sz.z > 0.0 && flow_len > 0.01) {
			// Streak along the projected velocity: a spark reads as a hot line.
			vec2 along = flow / flow_len;
			vec2 across = vec2(-along.y, along.x);
			offset = along * VERTEX.y * (size + flow_len * sz.z) + across * VERTEX.x * size;
		} else {
			float angle = extra.y * 6.2831853;
			mat2 spin = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
			offset = spin * VERTEX.xy * size;
		}
		VERTEX = center + vec3(offset, 0.0);
	}
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = clamp(length(q), 0.0, 1.0);
	float body = (1.0 - r) * (1.0 - r);
	float core = pow(1.0 - r, 5.0);
	float k = v_life.x;
	float fade = (1.0 - k) * (1.0 - k * 0.35);
	// Cooling: hot white-yellow turns orange-red as it flies (rail and landing sparks).
	vec3 hot = mix(v_color.rgb, v_color.rgb * vec3(1.0, 0.42, 0.16), v_life.y * k);
	vec3 colour = hot * body + vec3(1.0, 0.97, 0.88) * core * v_life.z;
	ALBEDO = colour * intensity * 1.6;
	ALPHA = clamp(v_color.a * fade * (body + core), 0.0, 1.0);
}
