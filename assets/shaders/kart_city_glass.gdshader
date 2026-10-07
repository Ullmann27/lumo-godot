shader_type spatial;
render_mode cull_back;
varying vec3 world_pos;
varying vec3 facade_normal;
void vertex() {
	world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	facade_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
}
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	float u=abs(facade_normal.x)>0.65?world_pos.z:world_pos.x;
	vec2 grid=vec2(u/1.6,world_pos.y/2.5);
	vec2 tile=fract(grid);
	vec2 aa=max(fwidth(grid)*1.2,vec2(0.003));
	float window=smoothstep(0.09-aa.x,0.09+aa.x,tile.x)*(1.0-smoothstep(0.91-aa.x,0.91+aa.x,tile.x));
	window*=smoothstep(0.15-aa.y,0.15+aa.y,tile.y)*(1.0-smoothstep(0.84-aa.y,0.84+aa.y,tile.y));
	float lit=step(0.69,hash21(floor(grid)));
	float fresnel=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
	vec3 tint=mix(COLOR.rgb*0.33,COLOR.rgb*(0.67+fresnel*0.4),window);
	ALBEDO=tint+vec3(0.015,0.035,0.06)*fresnel;
	METALLIC=0.48;
	ROUGHNESS=0.17;
	SPECULAR=0.65;
	EMISSION=vec3(0.22,0.59,0.72)*lit*window*0.40;
}
