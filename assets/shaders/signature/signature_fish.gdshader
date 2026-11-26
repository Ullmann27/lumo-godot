shader_type spatial;
render_mode cull_disabled;
// Fischschwärme ohne CPU-Arbeit: jede Instanz schwimmt im Kreis um ihren Ursprung.
// INSTANCE_CUSTOM = (Phase, Umläufe je s, Radius m, Höhenpendel m). Der Körper zeigt in
// Schwimmrichtung, der Schwanz (VERTEX.z > 0) schlägt mit.
varying vec3 v_color;

void vertex() {
	vec4 rnd = INSTANCE_CUSTOM;
	float angle = (TIME * rnd.y + rnd.x) * 6.2831;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 centre = origin + vec3(cos(angle) * rnd.z, sin(angle * 2.0 + rnd.x * 9.0) * rnd.w, sin(angle) * rnd.z);
	vec3 ahead = normalize(vec3(-sin(angle), 0.0, cos(angle)));
	vec3 right = normalize(cross(ahead, vec3(0.0, 1.0, 0.0)));
	vec3 local = VERTEX;
	local.x += sin(TIME * 9.0 + rnd.x * 20.0) * 0.25 * max(local.z, 0.0);
	vec3 world = centre + (right * local.x + vec3(0.0, local.y, 0.0) - ahead * local.z) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	v_color = COLOR.rgb;
}

void fragment() {
	ALBEDO = v_color;
	ROUGHNESS = 0.35;
	METALLIC = 0.2;
	EMISSION = v_color * 0.15;
}
