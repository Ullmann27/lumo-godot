// Distant coastal rock. Authored pigment and directional shading keep the
// silhouette legible across GLES and Vulkan without a texture or shadow pass.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 limestone : source_color = vec4(0.54, 0.52, 0.44, 1.0);
uniform vec4 shaded_rock : source_color = vec4(0.22, 0.30, 0.32, 1.0);
uniform vec4 scrub : source_color = vec4(0.30, 0.39, 0.34, 1.0);

varying vec3 rock_normal;
varying vec3 rock_position;

void vertex() {
	rock_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	rock_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 normal = normalize(rock_normal);
	float light = clamp(dot(normal, normalize(vec3(-0.45, 0.63, 0.64))) * 0.64 + 0.38, 0.0, 1.0);
	vec3 stone = mix(shaded_rock.rgb, limestone.rgb, light);
	float fold = sin(rock_position.x * 0.06) * 0.9 + sin(rock_position.z * 0.04) * 0.6;
	float bedding = sin(rock_position.y * 0.73 + fold * 2.3 + rock_position.x * 0.15 + rock_position.z * 0.08);
	float stratum = mix(0.94, 1.03, smoothstep(-0.38, 0.48, bedding));
	float slope_mask = smoothstep(0.50, 0.85, normal.y);
	float plants = slope_mask * smoothstep(-0.4, 0.7, fold) * 0.8;
	ALBEDO = mix(stone * stratum, scrub.rgb * mix(0.75, 1.13, light), plants);
}
