shader_type canvas_item;
render_mode unshaded;

// Optional premium panel. Add to a dedicated ColorRect BEHIND controls.
// screen_texture uses mipmaps; on weak Android devices use kart_glass_lite instead.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 glass_tint : source_color = vec4(0.018, 0.075, 0.23, 0.70);
uniform vec4 neon_edge : source_color = vec4(0.24, 0.94, 1.0, 0.95);
uniform float blur_lod : hint_range(0.0, 4.0, 0.1) = 1.4;
uniform float corner_radius : hint_range(0.01, 0.20) = 0.070;
uniform float edge_width : hint_range(0.001, 0.04) = 0.014;
uniform float opacity : hint_range(0.0, 1.0) = 0.96;

void fragment() {
    vec2 p = abs(UV - vec2(0.5)) - vec2(0.5 - corner_radius);
    float signed_distance = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - corner_radius;
    float body = 1.0 - smoothstep(-0.003, 0.003, signed_distance);
    float edge = body * (1.0 - smoothstep(0.0, edge_width, -signed_distance));
    vec3 backdrop = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
    vec3 glass = mix(backdrop, glass_tint.rgb, glass_tint.a);
    float top_sheen = pow(max(0.0, 1.0 - UV.y), 5.0) * 0.16;
    glass += vec3(top_sheen);
    vec3 final_color = mix(glass, neon_edge.rgb, edge * neon_edge.a);
    COLOR = vec4(final_color, body * opacity);
}
