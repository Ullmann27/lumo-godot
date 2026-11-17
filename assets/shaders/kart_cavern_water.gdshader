shader_type spatial;
render_mode unshaded;
uniform float light_intensity = 1.1;
uniform float animation_time = 0.0;
varying vec3 water_position;
void vertex() { water_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float ripple = sin(water_position.x * 5.2 + water_position.z * 2.7 + animation_time * 1.4)
        * sin(water_position.z * 7.0 - animation_time * 0.8);
    float caustic = smoothstep(0.78, 0.98, ripple);
    ALBEDO = mix(vec3(0.015, 0.08, 0.13), vec3(0.07, 0.24, 0.30), ripple * 0.5 + 0.5);
    EMISSION = vec3(0.10, 0.72, 0.80) * caustic * 0.45 * light_intensity;
    ROUGHNESS = 0.18;
}
