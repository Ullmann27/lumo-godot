shader_type spatial;
varying vec3 world_pos;
float hash(vec3 p) { p = fract(p*0.3183099+vec3(0.13,0.37,0.71)); p*=17.0; return fract(p.x*p.y*p.z*(p.x+p.y+p.z)); }
void vertex() { world_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float grain = hash(floor(world_pos*3.0));
	float ridge = sin(world_pos.x*0.41+sin(world_pos.z*0.29))*sin(world_pos.y*0.28+world_pos.z*0.21);
	ALBEDO = COLOR.rgb * (0.64+grain*0.17+ridge*0.09);
	ROUGHNESS = 0.93;
	SPECULAR = 0.3;
}
