// Rauch, Dampf, Funken und Gischt ohne Partikelsystem (Signatur-Strecken): jede Instanz
// eines MultiMesh ist ein Quad an ihrem Quellpunkt. INSTANCE_CUSTOM = (Phase, Zyklen je s,
// Größe m, Steighöhe m bzw. Startgeschwindigkeit m/s); die Länge der x-Achse der Instanz
// ist die Streuung. Physik: Rauch/Dampf steigt mit Auftrieb und bremst ab (gravity = 0);
// Funken und Lava fliegen ballistisch (y = v·t − g·t²/2). Wind (m/s) treibt mit dem Alter ab.
uniform float intensity = 1.0;
uniform vec3 wind = vec3(1.2, 0.0, 0.4);
uniform float gravity = 0.0;

varying vec2 v_uv;
varying float v_life;

void vertex() {
	vec4 rnd = INSTANCE_CUSTOM;
	float t = fract(TIME * rnd.y + rnd.x);
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float spread = length(MODEL_MATRIX[0].xyz);
	float a = rnd.x * 37.7;
	vec3 side = vec3(sin(a), 0.0, cos(a)) * spread * (0.35 + 0.65 * t);
	float age = t / max(rnd.y, 0.001);
	float rise = rnd.w * (1.0 - (1.0 - t) * (1.0 - t));
	if (gravity > 0.0) {
		rise = rnd.w * age - 0.5 * gravity * age * age;
	}
	vec3 world = origin + side + vec3(0.0, rise, 0.0) + wind * age;
	float size = rnd.z * (0.45 + 1.1 * t);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	world += (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	v_uv = UV;
	v_life = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.55, 1.0, t)) * intensity;
}
