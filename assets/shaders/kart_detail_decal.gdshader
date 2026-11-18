shader_type spatial;
// Verwitterungs-/Gebrauchsspuren als Alpha-Karten aus einem 1024er-Atlas.
// COLOR.rgb = Tönung, COLOR.a = Deckkraft. UV2.x = 1 kennzeichnet Pfützen:
// die bekommen Spiegelglanz als Fake (Himmelsfarbe über Fresnel, keine
// Bildschirm- oder Tiefentextur -> Mobile/gl_compatibility-tauglich).
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 sky_tint : source_color = vec3(0.62, 0.78, 0.95);
uniform vec3 horizon_tint : source_color = vec3(1.0, 0.86, 0.66);

void fragment() {
	vec4 tex = texture(atlas, UV);
	float wet = step(0.5, UV2.x);
	ALBEDO = tex.rgb * COLOR.rgb;
	ALPHA = tex.a * COLOR.a;
	ROUGHNESS = mix(0.86, 0.04, wet);
	SPECULAR = mix(0.3, 0.9, wet);
	if (wet > 0.5) {
		float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float fresnel = pow(1.0 - facing, 3.0);
		vec3 mirror = mix(sky_tint, horizon_tint, fresnel);
		// Leichte Kräuselung, langsam (kein Flackern).
		float ripple = 0.5 + 0.5 * sin(UV.x * 160.0 + TIME * 1.3) * sin(UV.y * 150.0 - TIME * 1.1);
		ALBEDO = mix(ALBEDO, mirror * 0.35, 0.6);
		EMISSION = mirror * (0.18 + 0.55 * fresnel) * (0.9 + 0.1 * ripple) * tex.a;
	}
}
