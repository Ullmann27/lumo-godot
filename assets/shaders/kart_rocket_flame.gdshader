shader_type spatial;
// Lumo-Kart rocket flame / nozzle fire: hot white core, gold to coral tail, scrolling tongues.
// Unshaded + additive, no screen or depth textures: Mobile and gl_compatibility safe.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.97, 0.82, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.72, 0.22, 1.0);
uniform vec4 tail_color : source_color = vec4(1.0, 0.32, 0.42, 1.0);
uniform float intensity = 1.0;
uniform float scroll_speed = 3.0;

void fragment() {
	// UV.y = 0 at the nozzle, 1 at the flame tip (CylinderMesh convention).
	float along = clamp(UV.y, 0.0, 1.0);
	float around = UV.x * 6.2831853;
	float tongues = sin(around * 3.0 + along * 9.0 - TIME * scroll_speed * 3.1) * 0.5 + 0.5;
	float body = pow(1.0 - along, 1.6) * (0.75 + 0.25 * tongues);
	float rim = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	vec3 colour = mix(core_color.rgb, mid_color.rgb, smoothstep(0.0, 0.35, along));
	colour = mix(colour, tail_color.rgb, smoothstep(0.35, 0.95, along));
	ALBEDO = colour * body * (0.45 + rim * 0.9) * intensity * 1.8;
}
