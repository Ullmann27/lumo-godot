shader_type canvas_item;
render_mode unshaded;

// No screen reads, postprocess dependency or blur textures (GL Compatibility).
uniform vec4 glass_tint : source_color = vec4(0.025, 0.085, 0.22, 0.91);
uniform vec4 neon_edge : source_color = vec4(0.20, 0.86, 1.0, 0.80);
uniform float corner_radius : hint_range(0.01, 0.20) = 0.070;
uniform float edge_width : hint_range(0.001, 0.04) = 0.014;

void fragment() {
    vec2 p = abs(UV - vec2(0.5)) - vec2(0.5 - corner_radius);
    float d = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - corner_radius;
    float body = 1.0 - smoothstep(-0.003, 0.003, d);
    float edge = body * (1.0 - smoothstep(0.0, edge_width, -d));
    vec3 color = glass_tint.rgb + vec3(0.035) * pow(1.0 - UV.y, 5.0);
    COLOR = vec4(mix(color, neon_edge.rgb, edge * neon_edge.a),
                 body * max(glass_tint.a, edge));
}
