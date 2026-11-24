// Vogel- und Schmetterlingsflügel: Schlag um die Körperachse (|x|), Phase je Instanz.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float flap_speed = 9.0;
uniform float flap_amount = 0.9;
uniform float span = 1.0;
uniform float alpha_cut = 0.4;

void vertex() {
	float side = sign(VERTEX.x);
	float r = abs(VERTEX.x);
	float phase = INSTANCE_CUSTOM.r * 6.2831;
	float a = sin(TIME * flap_speed + phase) * flap_amount * clamp(r / span, 0.0, 1.0);
	VERTEX.y += sin(a) * r;
	VERTEX.x = side * cos(a) * r;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.7;
	BACKLIGHT = c.rgb * 0.4;
}
