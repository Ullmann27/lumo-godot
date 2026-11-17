shader_type spatial;
render_mode unshaded;
varying vec3 stone_position;
varying vec3 stone_normal;
void vertex() {
    stone_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    stone_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    float strata = 0.5 + 0.5 * sin(stone_position.y * 14.0 + sin(stone_position.x * 1.7) * 2.0);
    float grit = fract(sin(dot(floor(stone_position * 24.0), vec3(12.9898,78.233,37.719))) * 43758.5453);
    float light = 0.6 + 0.4 * max(dot(normalize(stone_normal), normalize(vec3(-0.4,0.8,0.3))), 0.0);
    ALBEDO = COLOR.rgb * light * (0.65 + 0.23 * strata + 0.12 * grit);
    EMISSION = vec3(0.035, 0.11, 0.15) * (0.4 + 0.6 * strata);
    ROUGHNESS = 0.92;
}
