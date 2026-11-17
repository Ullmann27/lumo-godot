shader_type spatial;

// Hot-air balloon envelope with vertical gores in Lumo colours.
// Object-space stripes, no TIME and no screen textures (Mobile + Compatibility).

uniform vec4 color_a : source_color = vec4(1.0, 0.56, 0.16, 1.0);
uniform vec4 color_b : source_color = vec4(0.16, 0.42, 0.86, 1.0);
uniform vec4 color_c : source_color = vec4(0.98, 0.96, 0.9, 1.0);
uniform float gores = 12.0;

varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float angle = atan(local_position.z, local_position.x) / 6.28318 + 0.5;
	float index = floor(angle * gores);
	float pick = mod(index, 3.0);
	vec3 base = pick < 1.0 ? color_a.rgb : (pick < 2.0 ? color_b.rgb : color_c.rgb);
	float seam = smoothstep(0.0, 0.04, fract(angle * gores)) * (1.0 - smoothstep(0.96, 1.0, fract(angle * gores)));
	ALBEDO = base * (0.86 + 0.14 * seam);
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
}
