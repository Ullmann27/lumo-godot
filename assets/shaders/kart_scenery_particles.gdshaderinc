// Umgebungspartikel ohne Partikelsystem: jede Instanz ist ein Quad, dessen Weltlage
// im Vertex-Shader aus Zufallswerten (INSTANCE_CUSTOM) und Zeit entsteht und um die
// Kamera herum gewickelt wird. Ein Zeichenaufruf je Art, keine CPU-Arbeit je Bild.
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int sprite_first = 8;
uniform int sprite_count = 1;
uniform vec3 box_size = vec3(50.0, 16.0, 50.0);
uniform vec3 velocity = vec3(0.5, -0.3, 0.2);
uniform float sway = 0.8;
uniform float tumble = 0.0;
uniform float particle_size = 0.12;
uniform vec4 tint : source_color = vec4(1.0);

varying vec2 v_uv;
varying float v_fade;

void vertex() {
	vec4 rnd = INSTANCE_CUSTOM;
	vec3 cam = CAMERA_POSITION_WORLD;
	float speed = 0.7 + 0.6 * rnd.a;
	vec3 p = rnd.rgb * box_size + velocity * TIME * speed;
	float ph = rnd.a * 6.2831;
	p += vec3(sin(TIME * 0.9 + ph), sin(TIME * 1.3 + ph * 2.0) * 0.5, cos(TIME * 0.7 + ph)) * sway;
	vec3 rel = mod(p - cam + box_size * 0.5, box_size) - box_size * 0.5;
	vec3 world = cam + rel + vec3(0.0, box_size.y * 0.18, 0.0);
	float dist = length(rel);
	float edge = max(max(abs(rel.x) / box_size.x, abs(rel.z) / box_size.z), abs(rel.y) / box_size.y) * 2.0;
	v_fade = smoothstep(1.0, 0.75, edge) * smoothstep(0.8, 2.5, dist);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	float angle = tumble * (TIME * (1.0 + rnd.g * 2.0) + ph);
	vec2 local = vec2(VERTEX.x * cos(angle) - VERTEX.y * sin(angle), VERTEX.x * sin(angle) + VERTEX.y * cos(angle));
	float size = particle_size * (0.6 + 0.8 * rnd.b);
	world += (right * local.x + up * local.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	int sprite = sprite_first + int(floor(rnd.g * float(sprite_count) * 0.999));
	vec2 cell = vec2(float(sprite % 4), float(sprite / 4));
	v_uv = vec2(0.75 + (cell.x + UV.x) * 0.0625, 0.75 + (cell.y + UV.y) * 0.0625);
}
