shader_type spatial;
render_mode cull_disabled;
// World metres: plank seams, brass rail inlays and bolted bridge panels.
void fragment() {
	float x = abs(UV.x);
	float d = UV.y;
	float bridge = step(1265.0,d) * (1.0-step(1460.0,d));
	float station = max(1.0-step(185.0,d),step(2720.0,d));
	vec3 slate = mix(vec3(.105,.178,.20), vec3(.20,.123,.073), station);
	float row = floor(d / 3.6);
	float stain = fract(sin(row * 54.67 + floor((UV.x+8.0)/2.4)*15.7)*1432.58);
	slate *= .93 + stain*.13;
	float joint = 1.0 - smoothstep(.012,.055,abs(mod(d+.02,3.6)-.05));
	slate = mix(slate, slate*.67, joint);
	slate = mix(slate, vec3(.13,.24,.25),bridge*.45);
	float stripe = 1.0 - smoothstep(.07,.11,abs(x - 6.65));
	float inlay = 1.0 - smoothstep(.025,.065,abs(x - 4.95));
	float verge = smoothstep(6.92,7.08,x);
	slate = mix(slate,vec3(.83,.69,.29),stripe);
	slate = mix(slate,vec3(.45,.55,.53),inlay*.8);
	slate = mix(slate,mix(vec3(.15,.45,.40),vec3(.90,.79,.52),step(3.0,mod(d,6.0))),verge);
	float rivet = 1.0-smoothstep(.05,.095,length(vec2(x-6.33,mod(d+.25,1.8)-.25)));
	ALBEDO = mix(slate, vec3(.71,.63,.39), rivet);
	ROUGHNESS = mix(.88,.54,max(inlay,rivet));
}
