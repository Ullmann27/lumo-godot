shader_type spatial;
render_mode cull_disabled;

// Decorative progress only. The original lesson is the single state authority.
// No TIME: quiet mode and pause never keep moving through a global shader clock.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 warm_color : source_color = vec4(0.93, 0.72, 0.42, 1.0);
uniform vec4 cool_color : source_color = vec4(0.38, 0.76, 0.76, 1.0);
varying float flower_color;
varying float opening;

void vertex() {
    opening = smoothstep(0.0, 1.0, clamp(progress * 5.0 - INSTANCE_CUSTOM.r, 0.0, 1.0));
    float hinge = mix(1.22, 0.12, opening);
    float angle = INSTANCE_CUSTOM.g * 6.28318530718;
    mat3 lift = mat3(vec3(cos(hinge), sin(hinge), 0.0),
                     vec3(-sin(hinge), cos(hinge), 0.0),
                     vec3(0.0, 0.0, 1.0));
    mat3 turn = mat3(vec3(cos(angle), 0.0, sin(angle)),
                     vec3(0.0, 1.0, 0.0),
                     vec3(-sin(angle), 0.0, cos(angle)));
    VERTEX = turn * lift * VERTEX;
    NORMAL = normalize(turn * lift * NORMAL);
    flower_color = INSTANCE_CUSTOM.b;
}

void fragment() {
    vec3 color = mix(warm_color.rgb, cool_color.rgb, flower_color);
    ALBEDO = color;
    EMISSION = color * (0.025 + 0.055 * opening);
    ROUGHNESS = 0.72;
    METALLIC = 0.0;
    SPECULAR = 0.18;
}
