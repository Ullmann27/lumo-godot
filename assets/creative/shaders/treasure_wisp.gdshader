shader_type spatial;
// Original LUMO star: a soft luminous core and four tapered rays.
// No point lights, textures, glow postprocess or framebuffer readbacks.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.88, 0.48, 0.92);

void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float radius = length(p);
    float core = exp(-28.0 * dot(p, p));
    float horizontal = exp(-35.0 * abs(p.y)) * pow(max(0.0, 1.0 - abs(p.x)), 2.0);
    float vertical = exp(-35.0 * abs(p.x)) * pow(max(0.0, 1.0 - abs(p.y)), 2.0);
    float vignette = 1.0 - smoothstep(0.65, 1.0, radius);
    float brightness = clamp(core + 0.43 * (horizontal + vertical), 0.0, 1.0) * vignette;
    ALBEDO = glow_color.rgb;
    EMISSION = glow_color.rgb * (1.1 + core);
    ALPHA = brightness * glow_color.a;
}
