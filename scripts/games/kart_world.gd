class_name LumoRaceWorld
extends Node3D
## Four original banked courses. Spatial GPU batches preserve Android performance.
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")
const SKY_ISLANDS = preload("res://scripts/games/kart_sky_islands.gd")
const WIDTH: float = 10.8
## Continuous guardrails: the drawn rail and the collision wall are the same line.
const RAIL_LATERAL: float = 6.05
## Furthest a kart centre may go; its wheels then touch the rail face.
const WALL_LATERAL: float = 5.0
const DECORATION_CELL: float = 48.0
var curve: Curve3D
var length: float = 0.0
var road: MeshInstance3D
var low_detail: bool = false
var groups: Dictionary = {}
var meshes: Dictionary = {}
var materials: Dictionary = {}
var decoration_count: int = 0
var track_id: String = "sonnenhafen"
var track_name: String = "Sonnenhafen"
var road_width: float = WIDTH
var definition: Dictionary = {}
var checkpoint_positions := PackedVector3Array()
## Jump layout (ramp, take-off, gap end) on courses that have one; empty elsewhere.
var jump: Dictionary = {}
var _road_samples := PackedVector3Array()
var _road_distances := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()

func build(lightweight: bool, selected_track: String = "sonnenhafen") -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	groups.clear()
	decoration_count = 0
	low_detail = lightweight
	definition = TRACKS.definition(selected_track)
	track_id = definition.id
	track_name = definition.name
	_rng.seed = definition.seed
	_make_curve()
	jump={}
	if track_id=="bergwelt":
		# Himmelsinseln Sprint (reference k07): the road is carried by floating islands.
		jump=SKY_ISLANDS.jump_layout(length)
		SKY_ISLANDS.environment(self)
		_road()
		SKY_ISLANDS.build(self)
		SKY_ISLANDS.jump_dressing(self)
		SKY_ISLANDS.chevrons(self)
		_flush_instances()
		return
	_lighting()
	_terrain()
	_road()
	match track_id:
		"zauberwald": _forest()
		"holo_city": _city()
		_: _harbour()
	_navigation()
	_flush_instances()

func _make_curve() -> void:
	var original_points: PackedVector3Array = definition.points
	var points:=PackedVector3Array()
	for i in range(original_points.size()):
		points.append(original_points[i]*0.5+(original_points[posmod(i-1,original_points.size())]+original_points[(i+1)%original_points.size()])*0.25)
	curve = Curve3D.new()
	curve.bake_interval = 0.35
	for i in range(points.size() + 1):
		var index: int = i % points.size()
		var tangent: Vector3 = (points[(index+1)%points.size()] - points[posmod(index-1,points.size())]) * 0.22
		curve.add_point(points[index], -tangent, tangent)
	length = curve.get_baked_length()
	_road_samples.clear()
	_road_distances.clear()
	var count: int = ceili(length / 5.0)
	for i in range(count):
		var d: float = float(i) * length / count
		_road_samples.append(curve.sample_baked(d, true))
		_road_distances.append(d)
	checkpoint_positions.clear()
	for i in range(8):
		checkpoint_positions.append(position_at(float(i) * length / 8.0))

func forward(distance: float) -> Vector3:
	return (curve.sample_baked(fposmod(distance + 0.5, length), true) - curve.sample_baked(fposmod(distance, length), true)).normalized()

func frame(distance: float) -> Basis:
	var ahead: Vector3 = forward(distance)
	var right: Vector3 = ahead.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(ahead).normalized()
	var bend: float = right.dot(forward(distance + 5.0) - ahead)
	return Basis(right, up, -ahead).rotated(ahead, clampf(-bend * 0.68, -0.14, 0.14))

func position_at(distance: float, lateral: float = 0.0) -> Vector3:
	return curve.sample_baked(fposmod(distance, length), true) + frame(distance).x * lateral

func sample_road(world_position: Vector3, hint_distance: float = -1.0) -> Dictionary:
	var best_distance: float = 0.0
	var best_square: float = INF
	if hint_distance >= 0.0:
		for i in range(-9, 10):
			var d: float = fposmod(hint_distance + float(i)*5.0, length)
			var p: Vector3 = curve.sample_baked(d, true)
			var square: float = Vector2(p.x-world_position.x,p.z-world_position.z).length_squared()
			if square < best_square:
				best_square = square
				best_distance = d
	if hint_distance < 0.0 or best_square > 625.0:
		for i in range(_road_samples.size()):
			var p: Vector3 = _road_samples[i]
			var square: float = Vector2(p.x-world_position.x,p.z-world_position.z).length_squared()
			if square < best_square:
				best_square = square
				best_distance = _road_distances[i]
	var estimate: float = best_distance
	for i in range(-10, 11):
		var d: float = fposmod(estimate + float(i)*0.5, length)
		var p: Vector3 = curve.sample_baked(d, true)
		var square: float = Vector2(p.x-world_position.x,p.z-world_position.z).length_squared()
		if square < best_square:
			best_square = square
			best_distance = d
	var basis: Basis = frame(best_distance)
	var centre: Vector3 = curve.sample_baked(best_distance, true)
	best_distance = fposmod(best_distance + clampf((world_position-centre).dot(-basis.z),-0.6,0.6), length)
	basis = frame(best_distance)
	centre = curve.sample_baked(best_distance,true)
	var lateral: float = (world_position-centre).dot(basis.x)
	var surface_position: Vector3 = centre+basis.x*lateral
	return {"distance":best_distance,"lateral":lateral,"height":surface_position.y,"position":surface_position,"basis":basis,"on_road":absf(lateral)<=WIDTH*0.5,"width":WIDTH,"forward":-basis.z}

func in_gap(distance: float) -> bool:
	return SKY_ISLANDS.in_gap(jump,fposmod(distance,length))

## Height of the ramp surface above the road at this distance (0 without a ramp).
func ramp_height(distance: float) -> float:
	if jump.is_empty(): return 0.0
	var d: float=fposmod(distance,length)
	if d<jump.ramp_start or d>=jump.take_off: return 0.0
	return (d-jump.ramp_start)/(jump.take_off-jump.ramp_start)*jump.height

## Visual jump arc for computer rivals: they follow the ramp and fly a fixed arc over the gap.
func rival_arc(distance: float) -> float:
	var d: float=fposmod(distance,length)
	if jump.is_empty() or d<jump.ramp_start or d>=jump.gap_end: return 0.0
	if d<jump.take_off: return ramp_height(d)
	var u: float=(d-jump.take_off)/(jump.gap_end-jump.take_off)
	return jump.height*(1.0-u)+6.0*u*(1.0-u)

func reset_transform(distance: float, lateral: float = 0.0) -> Transform3D:
	var basis: Basis = frame(distance)
	return Transform3D(basis,position_at(distance,clampf(lateral,-3.5,3.5))+basis.y*0.08)

func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key: String = color.to_html()+("_glow" if glow else "")
	if materials.has(key): return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.77
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.2
	materials[key] = material
	return material

func _shape(kind: String) -> Mesh:
	if meshes.has(kind): return meshes[kind]
	var mesh: Mesh
	match kind:
		"crown": mesh = SHAPES.crown()
		"fir": mesh = SHAPES.fir()
		"rock": mesh = SHAPES.rock()
		"mountain": mesh = SHAPES.mountain()
		"hull": mesh = SHAPES.boat_hull()
		"sail": mesh = SHAPES.sail()
		"flower": mesh = SHAPES.flower()
		"crystal": mesh = SHAPES.crystal()
		"star": mesh = SHAPES.star()
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius=0.0
			cone.bottom_radius=1.0
			cone.height=1.0
			cone.radial_segments=16
			mesh=cone
		"glass_tower": mesh = SHAPES.glass_tower()
		"ball":
			var sphere := SphereMesh.new()
			sphere.radius=1.0
			sphere.height=2.0
			sphere.radial_segments=16
			sphere.rings=8
			mesh=sphere
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius=1.0
			cylinder.bottom_radius=1.0
			cylinder.height=1.0
			cylinder.radial_segments=16
			mesh=cylinder
		"roof":
			var roof := PrismMesh.new()
			roof.size=Vector3.ONE
			mesh=roof
		_:
			var box := BoxMesh.new()
			box.size=Vector3.ONE
			mesh=box
	meshes[kind]=mesh
	return mesh

func _prop(kind: String, at: Vector3, size: Vector3, color: Color, basis: Basis = Basis.IDENTITY, glow: bool = false) -> void:
	var backdrop: bool = size.length()>32.0 or at.y>45.0
	var cell := Vector2i(floori(at.x/DECORATION_CELL),floori(at.z/DECORATION_CELL))
	var key: String = kind+("_background" if backdrop else "_"+str(cell))+("_light" if glow else "")
	if not groups.has(key): groups[key]={"kind":kind,"backdrop":backdrop,"glow":glow,"transforms":[],"colors":[]}
	groups[key].transforms.append(Transform3D(basis.scaled_local(size),at))
	groups[key].colors.append(color)
	decoration_count+=1

func _flush_instances() -> void:
	for key in groups:
		var group: Dictionary=groups[key]
		var instances := MultiMesh.new()
		instances.transform_format=MultiMesh.TRANSFORM_3D
		instances.use_colors=true
		instances.mesh=_shape(group.kind)
		instances.instance_count=group.transforms.size()
		for i in range(instances.instance_count):
			instances.set_instance_transform(i,group.transforms[i])
			instances.set_instance_color(i,group.colors[i])
		var node := MultiMeshInstance3D.new()
		node.name="Decor_"+key
		node.multimesh=instances
		var material: StandardMaterial3D=_material(Color.WHITE,group.get("glow",false))
		material.vertex_color_use_as_albedo=true
		material.vertex_color_is_srgb=true
		node.material_override=material
		if group.kind=="glass_tower":
			var glass:=ShaderMaterial.new()
			glass.shader=preload("res://assets/shaders/kart_city_glass.gdshader")
			node.material_override=glass
		if low_detail or group.backdrop or group.get("glow",false): node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not group.backdrop:
			node.visibility_range_end=175.0 if low_detail else 230.0
			node.visibility_range_end_margin=15.0
		add_child(node)
	groups.clear()

func _lighting() -> void:
	var environment := Environment.new()
	environment.background_mode=Environment.BG_SKY
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color=definition.sky
	atmosphere.sky_horizon_color=definition.horizon
	atmosphere.ground_bottom_color=definition.ground
	atmosphere.ground_horizon_color=definition.horizon
	atmosphere.sky_curve=0.44
	atmosphere.sun_angle_max=5.0
	sky.sky_material=atmosphere
	environment.sky=sky
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("bfd9f2") if track_id!="zauberwald" else Color("a8d4d0")
	environment.ambient_light_energy=0.22 if track_id!="holo_city" else 0.40
	environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure=0.9
	environment.fog_enabled=true
	environment.fog_light_color=definition.fog
	environment.fog_density=0.0010 if track_id!="zauberwald" else 0.003
	environment.fog_aerial_perspective=0.22
	var world_environment := WorldEnvironment.new()
	world_environment.environment=environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-39,-36,0) if track_id!="zauberwald" else Vector3(-58,25,0)
	sun.light_color=definition.sun
	sun.light_energy=0.70 if track_id!="holo_city" else 0.42
	sun.shadow_enabled=not low_detail
	sun.directional_shadow_max_distance=85.0
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias=0.13
	sun.shadow_normal_bias=1.3
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-28,145,0)
	fill.light_color=Color("9bccea")
	fill.light_energy=0.10
	fill.shadow_enabled=false
	add_child(fill)

func _is_bridge(distance: float) -> bool:
	var t: float=fposmod(distance,length)/length
	match track_id:
		"holo_city": return true
		"bergwelt": return SKY_ISLANDS.is_bridge(t)
		"zauberwald": return t>0.15 and t<0.33
		_: return t>0.20 and t<0.45

func _nearest_horizontal(at: Vector3) -> Vector2:
	var best_square: float=INF
	var best_index: int=0
	for i in range(_road_samples.size()):
		var delta := Vector2(_road_samples[i].x-at.x,_road_samples[i].z-at.z)
		var square: float=delta.length_squared()
		if square<best_square:
			best_square=square
			best_index=i
	return Vector2(sqrt(best_square),best_index)

func _ground_height(x: float, z: float) -> float:
	var angle: float=atan2(z,x)
	var radius: float=Vector2(x/101.0,z/91.0).length()
	var shore: float=1.0+sin(angle*5.0+0.6)*0.035+sin(angle*9.0)*0.018
	if radius>shore: return -3.8-(radius-shore)*8.0
	if track_id=="holo_city": return -1.2
	var base: float=0.35+sin(x*0.067)*cos(z*0.071)*1.6
	if track_id=="bergwelt": base=1.7+sin(x*0.045+0.4)*cos(z*0.048)*5.0
	var nearest: Vector2=_nearest_horizontal(Vector3(x,0,z))
	var index: int=int(nearest.y)
	if not _is_bridge(_road_distances[index]):
		base=lerpf(base,_road_samples[index].y-0.85,1.0-smoothstep(5.0,23.0,nearest.x))
	return lerpf(-2.4,base,smoothstep(0.0,0.075,shore-radius))

func _terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int=72 if not low_detail else 48
	var grid: Array[PackedVector3Array]=[]
	for z in range(count+1):
		var row := PackedVector3Array()
		for x in range(count+1):
			var px: float=-114.0+float(x)*228.0/count
			var pz: float=-104.0+float(z)*208.0/count
			row.append(Vector3(px,_ground_height(px,pz),pz))
		grid.append(row)
	for z in range(count):
		for x in range(count):
			for coordinate in [Vector2i(x,z),Vector2i(x+1,z),Vector2i(x,z+1),Vector2i(x+1,z),Vector2i(x+1,z+1),Vector2i(x,z+1)]:
				var p: Vector3=grid[coordinate.y][coordinate.x]
				var tint: Color=definition.ground
				if p.y< -0.3: tint=Color("d6c496") if track_id=="sonnenhafen" else Color("506b69")
				elif track_id=="bergwelt" and p.y>10.0: tint=Color("a3b1ac")
				surface.set_color(tint.lightened(sin(p.x*0.07+p.z*0.09)*0.05))
				surface.add_vertex(p)
	surface.generate_normals()
	var land := MeshInstance3D.new()
	land.name="SculptedIslandTerrain"
	land.mesh=surface.commit()
	var material := _material(Color.WHITE).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=true
	land.material_override=material
	add_child(land)
	var water := MeshInstance3D.new()
	water.name="AnimatedCoastalWater"
	var plane := PlaneMesh.new()
	plane.size=Vector2(1300,1300)
	water.mesh=plane
	water.position.y= -2.35
	var water_material := ShaderMaterial.new()
	water_material.shader=preload("res://assets/shaders/kart_water.gdshader")
	if track_id=="holo_city":
		water_material.set_shader_parameter("deep_water",Color("0d1934"))
		water_material.set_shader_parameter("shallow_water",Color("174970"))
	water.material_override=water_material
	water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	for i in range(12):
		var angle: float=float(i)*TAU/12.0+_rng.randf_range(-0.08,0.08)
		var at := Vector3(cos(angle)*245.0,-5.0,sin(angle)*220.0)
		var h: float=_rng.randf_range(28,56) if track_id!="bergwelt" else _rng.randf_range(62,105)
		if track_id!="holo_city":
			_prop("mountain",at,Vector3(_rng.randf_range(45,85),h,_rng.randf_range(34,65)),Color("72a3ad") if track_id!="bergwelt" else Color("7d99ae"))
			if track_id=="bergwelt": _prop("mountain",at+Vector3.UP*h*0.58,Vector3(16,h*0.43,15),Color("eaf4f4"))
	if track_id!="holo_city":
		for i in range(13):
			var angle: float=float(i)*TAU/13.0
			var at := Vector3(cos(angle)*180.0,58.0+(i%3)*5.0,sin(angle)*160.0)
			for part in range(4): _prop("crown",at+Vector3(part*7.0,sin(float(part))*2.2,0),Vector3(10,3.5,5.8),Color("f2f8f6"))

func _ribbon(mesh_name: String, left: float, right: float, height: float, material: Material, down: float=0.0) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int=ceili(length/0.9)
	for i in range(count):
		var d: float=float(i)*length/count
		var next: float=float(i+1)*length/count
		if in_gap((d+next)*0.5): continue
		var vertices: Array[Vector3]=[position_at(d,left)+frame(d).y*height,position_at(d,right)+frame(d).y*(height-down),position_at(next,left)+frame(next).y*height,position_at(next,right)+frame(next).y*(height-down)]
		for index in ([0,2,1,1,2,3] if left < right else [0,1,2,1,3,2]):
			surface.set_uv(Vector2(left if index%2==0 else right,d if index<2 else next))
			surface.add_vertex(vertices[index])
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.name=mesh_name
	node.mesh=surface.commit()
	node.material_override=material
	add_child(node)
	return node

func _road() -> void:
	var asphalt := ShaderMaterial.new()
	asphalt.shader=preload("res://assets/shaders/kart_asphalt.gdshader")
	asphalt.set_shader_parameter("road_tint",definition.asphalt)
	var night: float={"holo_city":1.0,"bergwelt":0.15}.get(track_id,0.0)
	asphalt.set_shader_parameter("night_course",night)
	road=_ribbon("BankedRoad",-WIDTH*0.5,WIDTH*0.5,0.0,asphalt)
	var shoulder_color := Color("d9d9c5") if track_id=="sonnenhafen" else Color("90b4bd")
	if track_id=="bergwelt": shoulder_color=Color("2a3f8f")
	var edge_color: Color=definition.accent
	for side in [-1.0,1.0]:
		_ribbon("RaisedShoulder",side*5.42,side*6.10,-0.06,_material(shoulder_color))
		_ribbon("RoadFoundation",side*6.1,side*6.13,-0.06,_material(Color("566b74")),0.70)
		_ribbon("EdgePaint",side*5.1,side*5.24,0.015,_material(Color("f5f7e9")))
		if track_id=="holo_city": _ribbon("ContinuousLightEdge",side*5.83,side*5.94,0.045,_material(edge_color,true))
	var count: int=ceili(length/1.4)
	var step: float=length/count
	for i in range(count):
		var d: float=i*step+step*0.5
		if in_gap(d): continue
		var p: Vector3=position_at(d)
		var basis: Basis=frame(d)
		var bridge: bool=_is_bridge(d)
		for side in [-1.0,1.0]:
			var curb: Color=Color("eff3e5") if i%4<2 else edge_color.darkened(0.16)
			if track_id!="bergwelt":
				_prop("box",position_at(d,side*5.5)+basis.y*0.02,Vector3(0.48,0.12,step+0.03),curb,basis)
			# The rail is continuous because it is also the wall the kart collides with.
			var rail_at: Vector3=position_at(d,side*RAIL_LATERAL)
			var rail_color: Color=Color("edf3df") if track_id!="holo_city" else Color("6bc9e5")
			var lower_color: Color=Color("7d9aa4")
			if track_id=="bergwelt":
				# Reference guardrail: blue and white bands with gold caps.
				rail_color=SKY_ISLANDS.RAIL_BLUE if i%6<3 else Color("f1f4ff")
				lower_color=Color("1d3a9a")
			_prop("box",rail_at+Vector3.UP*0.97,Vector3(0.16,0.2,step+0.05),rail_color,basis)
			_prop("box",rail_at+Vector3.UP*0.54,Vector3(0.11,0.14,step+0.05),lower_color,basis)
			if i%3==0:
				_prop("box",rail_at+Vector3.UP*0.52,Vector3(0.14,1.10,0.17),Color("647e91"),basis)
				if track_id=="bergwelt":
					_prop("ball",rail_at+Vector3.UP*1.12,Vector3.ONE*0.13,SKY_ISLANDS.GOLD,basis,true)
		if i%8<3: _prop("box",p+basis.y*0.02,Vector3(0.13,0.018,step+0.02),Color("e6ead9"),basis)
		if bridge and i%13==0 and track_id!="bergwelt":
			var base_y: float=maxf(-2.3,_ground_height(p.x,p.z))
			var pillar_height: float=maxf(0.3,p.y-base_y-0.4)
			_prop("box",p-Vector3.UP*0.48,Vector3(12.4,0.56,0.90),Color("526f84"),basis)
			for side in [-1.0,1.0]:
				var leg: Vector3=position_at(d,side*4.4)
				leg.y=base_y+pillar_height*0.5
				_prop("box",leg,Vector3(0.75,pillar_height,0.9),Color("849596"),basis)
	for row in range(2):
		for column in range(16):
			_prop("box",position_at(row*0.64+1.0,(column-7.5)*0.65)+frame(0).y*0.035,Vector3(0.65,0.035,0.64),Color("f6fbfa") if (row+column)%2==0 else Color("162940"),frame(0))
	if track_id=="bergwelt":
		SKY_ISLANDS.start_gate(self)
		SKY_ISLANDS.road_lights(self)
	else:
		_arch(0.0,track_name.to_upper(),definition.accent)
	match track_id:
		"sonnenhafen": _suspension_bridge(length*0.295,37.0)
		"zauberwald": _tree_tunnel(length*0.51)
		"bergwelt":
			_snow_tunnel(length*SKY_ISLANDS.CAVE,SKY_ISLANDS.CAVE_PALETTE)
			SKY_ISLANDS.cave_crystals(self,length*SKY_ISLANDS.CAVE)
		"holo_city":
			for fraction in [0.21,0.45,0.69]: _holo_gate(length*fraction)

func _beam(a: Vector3, b: Vector3, width: float, color: Color, glow: bool=false) -> void:
	var delta: Vector3=b-a
	var up: Vector3=Vector3.RIGHT if absf(delta.normalized().dot(Vector3.UP))>0.99 else Vector3.UP
	var basis: Basis=Basis.looking_at(delta.normalized(),up)
	_prop("box",(a+b)*0.5,Vector3(width,width,delta.length()),color,basis,glow)

func _suspension_bridge(distance: float, span: float, palette: Dictionary={}) -> void:
	var tower: Color=palette.get("tower",Color("e7e1c7"))
	var cap: Color=palette.get("cap",Color("446b85"))
	var crossbeam: Color=palette.get("crossbeam",Color("dfe2d0"))
	var cable: Color=palette.get("cable",Color("48697e"))
	var hanger: Color=palette.get("hanger",Color("dce5de"))
	for end in [-1.0,1.0]:
		var d: float=distance+end*span*0.5
		var basis: Basis=frame(d)
		for side in [-1.0,1.0]:
			var foot: Vector3=position_at(d,side*6.55)
			_prop("box",foot+Vector3.UP*5.4,Vector3(1.05,12.0,1.0),tower,basis)
			_prop("box",foot+Vector3.UP*11.6,Vector3(1.5,0.35,1.3),cap,basis)
		_prop("box",position_at(d)+Vector3.UP*10.6,Vector3(14.0,0.75,1.0),crossbeam,basis)
	for side in [-1.0,1.0]:
		for i in range(19):
			var t: float=float(i)/19.0
			var next_t: float=float(i+1)/19.0
			var d: float=distance-span*0.5+t*span
			var next_d: float=distance-span*0.5+next_t*span
			var p: Vector3=position_at(d,side*6.55)+Vector3.UP*(3.0+pow(t*2.0-1.0,2.0)*8.0)
			var q: Vector3=position_at(next_d,side*6.55)+Vector3.UP*(3.0+pow(next_t*2.0-1.0,2.0)*8.0)
			_beam(p,q,0.14,cable)
			_beam(position_at(d,side*6.55)+Vector3.UP*1.05,p,0.055,hanger)

func _navigation() -> void:
	for gate in range(1,8):
		var d: float=length*float(gate)/8.0
		var basis: Basis=frame(d)
		for side in [-1.0,1.0]:
			var at: Vector3=position_at(d,side*6.5)
			_prop("cylinder",at+Vector3.UP*2.1,Vector3(0.07,4.2,0.07),Color("eaf0e5"))
			_prop("box",at+Vector3.UP*3.5+basis.x*side*0.48,Vector3(0.95,1.1,0.035),definition.accent,basis)
	for i in range(24):
		var d: float=float(i)*length/24.0+6.0
		var at: Vector3=position_at(d,-6.65)
		var basis: Basis=frame(d)
		_prop("cylinder",at+Vector3.UP*2.55,Vector3(0.07,5.1,0.07),Color("39566e"))
		_prop("box",at+Vector3.UP*4.95+basis.x*0.4,Vector3(1.0,0.12,0.28),Color("d9e9e3"),basis)
		_prop("box",at+Vector3.UP*4.87+basis.x*0.5,Vector3(0.6,0.035,0.22),Color("dcf9fc"),basis,true)
	for fraction in [0.10,0.22,0.36,0.53,0.67,0.81,0.93]:
		var d: float=fraction*length
		var p: Vector3=position_at(d,6.65)
		var basis: Basis=frame(d)
		var turn: float=1.0 if basis.x.dot(forward(d+12))>=0 else -1.0
		_prop("box",p+Vector3.UP*1.9,Vector3(2.3,1.4,0.13),Color("19354c"),basis)
		for offset in [-0.55,0.45]:
			_prop("box",p+Vector3.UP*2.1+basis.x*offset+basis.z*0.09,Vector3(0.64,0.14,0.05),Color("cdf8f3"),basis.rotated(basis.z,-0.5*turn),true)
			_prop("box",p+Vector3.UP*1.8+basis.x*offset+basis.z*0.09,Vector3(0.64,0.14,0.05),Color("cdf8f3"),basis.rotated(basis.z,0.5*turn),true)

func _sign(at: Vector3, basis: Basis, text: String, pixel_size: float=0.026) -> void:
	var label := Label3D.new()
	label.text=text
	label.font_size=44
	label.pixel_size=pixel_size
	label.outline_size=3
	label.modulate=Color("f2ffff")
	label.position=at
	label.basis=basis
	label.no_depth_test=false
	add_child(label)

func _arch(distance: float, text: String, color: Color) -> void:
	var basis: Basis=frame(distance)
	var at: Vector3=position_at(distance)
	for side in [-1.0,1.0]:
		_prop("box",at+basis.x*side*6.5+Vector3.UP*3.5,Vector3(0.75,7,0.85),Color("18334f"),basis)
		_prop("box",at+basis.x*side*6.48+Vector3.UP*3.9+basis.z*0.46,Vector3(0.12,5.2,0.05),color,basis,true)
	_prop("box",at+Vector3.UP*6.9,Vector3(13.7,1.35,0.85),Color("142d48"),basis)
	_prop("box",at+Vector3.UP*7.65,Vector3(14.05,0.13,1.0),color,basis,true)
	_sign(at+Vector3.UP*6.95+basis.z*0.46,basis,text,0.025)
	_sign(at+Vector3.UP*6.95-basis.z*0.46,basis.rotated(Vector3.UP,PI),text,0.025)

func _near_road(at: Vector3, radius: float) -> bool:
	return _nearest_horizontal(at).x<radius

func _tree(at: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var trunk := Color("73553f")
	_prop("cylinder",at+Vector3.UP*size*2.0,Vector3(0.23,4.0,0.23)*size,trunk)
	var branch_basis := Basis(Vector3.UP,rng.randf_range(-PI,PI))
	for side in [-1.0,1.0]: _beam(at+Vector3.UP*size*2.0,at+branch_basis.x*side*size+Vector3.UP*size*3.55,0.18*size,trunk)
	var tint := Color("367969") if rng.randf()>0.5 else Color("4c956b")
	if track_id=="zauberwald": tint=Color("428978") if rng.randf()>0.35 else Color("7688b7")
	_prop("crown",at+Vector3.UP*size*4.1,Vector3(2.1,1.75,1.85)*size,tint,branch_basis)
	_prop("crown",at+branch_basis.x*size*1.0+Vector3.UP*size*3.55,Vector3(1.45,1.1,1.35)*size,tint.lightened(0.055),branch_basis)
	if not low_detail: _prop("crown",at-branch_basis.x*size*0.95+Vector3.UP*size*3.65,Vector3(1.25,1.2,1.35)*size,tint.darkened(0.06),branch_basis)

func _flower_patch(at: Vector3, color: Color, count: int=8) -> void:
	for i in range(count):
		var p: Vector3=at+Vector3(_rng.randf_range(-1.5,1.5),0,_rng.randf_range(-1.5,1.5))
		p.y=_ground_height(p.x,p.z)+0.10
		_prop("flower",p,Vector3.ONE*_rng.randf_range(0.75,1.3),color)

func _harbour() -> void:
	var palette: Array[Color]=[Color("efe5c4"),Color("94c7c3"),Color("bfc7db"),Color("e8c2a1"),Color("c8d7b0")]
	for i in range(22):
		var d: float=float(i)*length/22.0+12.0
		if _is_bridge(d): continue
		var side: float=1.0 if i%2==0 else -1.0
		var p: Vector3=position_at(d,side*13.5)
		p.y=_ground_height(p.x,p.z)
		var basis := Basis(Vector3.UP,atan2(-forward(d).x,-forward(d).z)+(PI if side>0 else 0.0))
		_house(p,basis,palette[i%palette.size()],i)
	for i in range(155 if not low_detail else 95):
		var p := Vector3(_rng.randf_range(-88,88),0,_rng.randf_range(-78,78))
		if Vector2(p.x/88.0,p.z/78.0).length()>1.0 or _near_road(p,13.0): continue
		p.y=_ground_height(p.x,p.z)
		_tree(p,_rng.randf_range(0.8,1.35),_rng)
		if i%3==0: _flower_patch(p+Vector3(2,0,1),Color("eef0b1"),5)
	for pier in range(3):
		var at := Vector3(96.0,-1.9,31.0-pier*15.0)
		_prop("box",at,Vector3(21,0.45,2.0),Color("aa8964"))
		for board in range(30): _prop("box",at+Vector3(-10.0+board*0.68,0.24,0),Vector3(0.025,0.035,1.95),Color("796e59"))
		for i in range(3): _boat(at+Vector3(-7+i*6.3,-0.35,4.3),palette[(i+pier)%palette.size()],i%2==0)
	_lighthouse(Vector3(88,_ground_height(88,-34),-34))
	_windmill(Vector3(-17,_ground_height(-17,12),12))
	for i in range(30):
		var angle: float=float(i)*TAU/30.0
		_prop("rock",Vector3(cos(angle)*98,-1.5,sin(angle)*88),Vector3(_rng.randf_range(2,4),_rng.randf_range(1.2,3.6),_rng.randf_range(2,4)),Color("b8b6a0"),Basis(Vector3.UP,angle))

func _house(at: Vector3, basis: Basis, color: Color, index: int) -> void:
	var height: float=5.1+float(index%3)*1.3
	_prop("box",at+Vector3.UP*height*0.5,Vector3(5.7,height,4.9),color,basis)
	_prop("box",at+Vector3.UP*0.23,Vector3(5.95,0.46,5.2),Color("acb2a2"),basis)
	var roof_color := Color("466c89") if index%2==0 else Color("846f85")
	_prop("roof",at+Vector3.UP*(height+1.0),Vector3(6.5,2.6,5.8),roof_color,basis)
	_prop("box",at+Vector3.UP*(height-0.05),Vector3(6.4,0.18,5.7),Color("f3e8d1"),basis)
	for floor_index in range(2 if height<6 else 3):
		for side in [-1.0,1.0]:
			var p: Vector3=at+basis*Vector3(side*1.5,1.6+floor_index*1.9,2.48)
			_prop("box",p,Vector3(1.18,1.36,0.16),Color("f7f0da"),basis)
			_prop("box",p+basis.z*0.1,Vector3(0.94,1.13,0.06),Color("427e98"),basis)
			_prop("box",p+basis.z*0.15,Vector3(0.055,1.14,0.05),Color("eff0df"),basis)
			_prop("box",p+basis.z*0.15,Vector3(0.94,0.055,0.05),Color("eff0df"),basis)
			for shutter in [-1.0,1.0]: _prop("box",p+basis.x*shutter*0.78,Vector3(0.31,1.25,0.14),roof_color.lightened(0.1),basis)
			if floor_index==1:
				_prop("box",p+basis*Vector3(0,-0.78,0.22),Vector3(1.4,0.33,0.48),Color("6a7d83"),basis)
				for blossom in range(4): _prop("crown",p+basis*Vector3(-0.48+blossom*0.32,-0.55,0.23),Vector3(0.22,0.16,0.20),Color("c489bf") if index%2==0 else Color("e4da9a"))
	for wall in range(3):
		var wall_basis: Basis=basis.rotated(Vector3.UP,float(wall+1)*PI/2.0)
		var facade_depth: float=2.88 if wall%2==0 else 2.48
		for floor_index in range(2 if height<6 else 3):
			for side in [-1.0,1.0]:
				var p: Vector3=at+wall_basis*Vector3(side*1.25,1.6+floor_index*1.9,facade_depth)
				_prop("box",p,Vector3(1.10,1.30,0.14),Color("f0e9d7"),wall_basis)
				_prop("box",p+wall_basis.z*0.085,Vector3(0.87,1.08,0.055),Color("4c819b"),wall_basis)
				_prop("box",p+wall_basis.z*0.12,Vector3(0.06,1.10,0.035),Color("f0e9d7"),wall_basis)
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			_prop("box",at+basis*Vector3(x*2.81,height*0.5,z*2.43),Vector3(0.19,height,0.19),color.lightened(0.14),basis)
	_prop("box",at+basis*Vector3(0,1.0,2.5),Vector3(1.2,2.05,0.18),Color("385b70"),basis)
	_prop("box",at+basis*Vector3(0,2.5,2.98),Vector3(5.8,0.16,1.35),Color("ece3c7"),basis.rotated(basis.x,-0.17))
	for stripe in range(6): _prop("box",at+basis*Vector3(-2.5+stripe*1.0,2.38,3.47),Vector3(0.46,0.30,0.08),Color("6da3b0"),basis)
	_prop("box",at+basis*Vector3(1.5,height+1.0,-0.9),Vector3(0.65,2.0,0.65),Color("d4c7b2"),basis)
	if index%3==0:
		_prop("box",at+basis*Vector3(0,3.45,2.65),Vector3(3.9,0.68,0.13),Color("23445b"),basis)
		_sign(at+basis*Vector3(0,3.48,2.75),basis,["LUMO WERFT","WOLKENCAFÉ","HAFENMARKT","STERNENPOST"][index/3%4],0.015)

func _boat(at: Vector3, color: Color, sailing: bool) -> void:
	_prop("hull",at,Vector3(1.15,0.8,1.15),color)
	_prop("box",at+Vector3(0,0.4,0.45),Vector3(1.65,0.18,2.8),Color("eadaba"))
	if sailing:
		_prop("cylinder",at+Vector3(0,3.1,-0.5),Vector3(0.065,5.8,0.065),Color("e5d7b8"))
		_prop("sail",at+Vector3(0,0.8,-0.5),Vector3.ONE,Color("f7efdc"))
		_prop("sail",at+Vector3(0.03,0.9,-0.7),Vector3(1,0.75,-0.65),color.lightened(0.35))
	else:
		_prop("box",at+Vector3(0,1.1,0.2),Vector3(1.6,1.3,1.7),Color("f0ead8"))
		_prop("box",at+Vector3(0,1.35,-0.69),Vector3(1.35,0.65,0.06),Color("3a8199"))
		_prop("box",at+Vector3(0,1.85,0.2),Vector3(1.95,0.18,2.1),color)

func _lighthouse(at: Vector3) -> void:
	_prop("cylinder",at+Vector3.UP*0.5,Vector3(4.0,1.0,4.0),Color("b7c4b3"))
	for i in range(9): _prop("cylinder",at+Vector3.UP*(i*1.5+1.5),Vector3(2.4-i*0.10,1.5,2.4-i*0.10),Color("f2ebd4") if i%3!=1 else Color("5b92ac"))
	_prop("cylinder",at+Vector3.UP*14.5,Vector3(2.5,0.38,2.5),Color("385c78"))
	_prop("cylinder",at+Vector3.UP*15.6,Vector3(1.55,1.85,1.55),Color("e8e0ac"))
	for i in range(8):
		var angle: float=float(i)*TAU/8.0
		_prop("box",at+Vector3(cos(angle)*1.55,15.6,sin(angle)*1.55),Vector3(0.12,2.0,0.12),Color("36576c"))
	_prop("cylinder",at+Vector3.UP*16.7,Vector3(2.2,0.3,2.2),Color("36576c"))
	_prop("roof",at+Vector3.UP*17.55,Vector3(4.0,1.6,4.0),Color("466c89"))

func _windmill(at: Vector3) -> void:
	_prop("cylinder",at+Vector3.UP*5.0,Vector3(2.6,10.0,2.6),Color("e6dfbf"))
	_prop("roof",at+Vector3.UP*10.3,Vector3(6.1,3.3,6.1),Color("627e98"))
	var hub: Vector3=at+Vector3(0,8.9,2.8)
	_prop("cylinder",hub,Vector3(0.55,0.55,0.55),Color("3d596c"),Basis(Vector3.RIGHT,PI/2))
	for i in range(4):
		var basis := Basis(Vector3.FORWARD,PI/4+i*PI/2)
		_prop("box",hub+basis.y*2.5,Vector3(0.22,5.4,0.2),Color("5f6d76"),basis)
		for slat in range(6): _prop("box",hub+basis.y*(1.2+slat*0.65)+basis.x*0.42,Vector3(1.05,0.36,0.09),Color("f1e4c9"),basis)

func _forest() -> void:
	for i in range(250 if not low_detail else 145):
		var p := Vector3(_rng.randf_range(-93,93),0,_rng.randf_range(-84,84))
		if Vector2(p.x/94.0,p.z/85.0).length()>1.0 or _near_road(p,9.8): continue
		p.y=_ground_height(p.x,p.z)
		_tree(p,_rng.randf_range(1.4,2.8),_rng)
		if i%4==0: _mushroom(p+Vector3(2,0,1),_rng.randf_range(0.9,1.8))
		if i%2==0:
			_prop("crown",p+Vector3(1,0.25,1),Vector3(1.5,0.6,1.3),Color("397964"))
			_prop("fir",p+Vector3(-1,0.05,-1),Vector3(0.8,0.5,0.8),Color("75a783"))
		if i%6==0: _flower_patch(p+Vector3(-2,0,1),Color("aac8ec"),6)
	for i in range(28):
		var d: float=float(i)*length/28.0
		var p: Vector3=position_at(d,8.0 if i%2==0 else -8.0)
		p.y=_ground_height(p.x,p.z)
		_mushroom(p,0.65+float(i%3)*0.20)
		_prop("crystal",p+Vector3(1,0,1),Vector3(0.4,0.6,0.4),Color("83d4d7"),Basis.IDENTITY,true)
	for i in range(40):
		var d: float=_rng.randf_range(0,length)
		var p: Vector3=position_at(d,_rng.randf_range(-14,14))+Vector3.UP*_rng.randf_range(2.5,6.0)
		_prop("ball",p,Vector3.ONE*0.065,Color("e1f0a3"),Basis.IDENTITY,true)
	_arch(length*0.63,"LICHTERHAIN",Color("b2dcdf"))

func _mushroom(at: Vector3, size: float) -> void:
	_prop("cylinder",at+Vector3.UP*size*0.70,Vector3(0.15,1.4,0.15)*size,Color("c5d2bb"))
	_prop("crown",at+Vector3.UP*size*1.45,Vector3(0.94,0.32,0.94)*size,Color("9b8bd1"))
	for dot in range(6):
		var angle: float=float(dot)*TAU/6.0
		_prop("ball",at+Vector3(cos(angle)*0.52,1.67,sin(angle)*0.52)*size,Vector3(0.13,0.06,0.13)*size,Color("d8f4ef"),Basis.IDENTITY,true)
	_prop("cylinder",at+Vector3.UP*size*1.22,Vector3(0.65,0.08,0.65)*size,Color("b4dcde"),Basis.IDENTITY,true)

func _tree_tunnel(distance: float) -> void:
	for i in range(4):
		var d: float=distance+(i-1.5)*7.0
		var basis: Basis=frame(d)
		for side in [-1.0,1.0]:
			var base: Vector3=position_at(d,side*(7.5+sin(float(i))*0.6))
			var split: Vector3=base-basis.x*side*0.8+Vector3.UP*5.0
			_branch(base,split,0.62,Color("635c48"))
			_branch(split,position_at(d,side*2.8)+Vector3.UP*9.6,0.34,Color("76634d"))
			_branch(split,base+basis.z*2.5+basis.x*side+Vector3.UP*8.0,0.26,Color("76634d"))
			_prop("crown",position_at(d,side*3.4)+Vector3.UP*9.4,Vector3(4.8,2.6,4.0),Color("428575"))
			_prop("crown",base+basis.z*1.8+Vector3.UP*8.5,Vector3(3.0,2.0,2.8),Color("539b78"))
			_prop("crystal",base+Vector3.UP*3.2-basis.x*side,Vector3(0.24,0.65,0.24),Color("b9eafa"),Basis.IDENTITY,true)
			_mushroom(base+basis.z*2.2-basis.x*side,1.5)

func _branch(a: Vector3,b: Vector3,radius: float,color: Color) -> void:
	var direction: Vector3=(b-a).normalized()
	var up: Vector3=Vector3.RIGHT if absf(direction.dot(Vector3.UP))>0.99 else Vector3.UP
	var basis: Basis=Basis.looking_at(direction,up)*Basis(Vector3.RIGHT,PI/2)
	_prop("cylinder",(a+b)*0.5,Vector3(radius,(b-a).length(),radius),color,basis)

func _snow_tunnel(distance: float, palette: Dictionary={}) -> void:
	var inner: Color=palette.get("inner",Color("819da6"))
	var outer: Color=palette.get("outer",Color("dce9e5"))
	var stripes: Array=palette.get("stripes",[Color("b5c6c6"),Color("9aafb5")])
	var boulder: Color=palette.get("boulder",Color("91a7ac"))
	var lamp: Color=palette.get("lamp",Color("d8f0f4"))
	# A continuous curved stone vault: joined inner/outer surfaces, no box roof.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: int=24
	var sides: int=20
	for layer in range(2):
		for segment in range(rings):
			var d: float=distance-12.0+float(segment)
			for side in range(sides):
				var vertices: Array[Vector3]=[]
				for corner in [Vector2i(0,side),Vector2i(1,side),Vector2i(0,side+1),Vector2i(1,side+1)]:
					var angle: float=float(corner.y)*PI/sides
					var station: float=d+corner.x
					vertices.append(position_at(station)+frame(station).x*cos(angle)*(6.7+layer*1.25)+Vector3.UP*sin(angle)*(6.6+layer*1.05))
				for index in ([0,2,1,1,2,3] if layer==0 else [0,1,2,1,3,2]):
					surface.set_color(inner if layer==0 else outer)
					surface.add_vertex(vertices[index])
	surface.generate_normals()
	var vault := MeshInstance3D.new()
	vault.name="ContinuousAlpineStoneTunnel"
	vault.mesh=surface.commit()
	var material := _material(Color.WHITE).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	vault.material_override=material
	add_child(vault)
	for end in [-12.0,12.0]:
		var d: float=distance+end
		var basis: Basis=frame(d)
		for segment in range(20):
			var a: float=float(segment)*PI/20.0
			var b: float=float(segment+1)*PI/20.0
			var p: Vector3=position_at(d)+basis.x*cos(a)*7.28+Vector3.UP*sin(a)*7.1
			var q: Vector3=position_at(d)+basis.x*cos(b)*7.28+Vector3.UP*sin(b)*7.1
			_beam(p,q,1.1,stripes[segment%2])
		for side in [-1.0,1.0]:
			_prop("rock",position_at(d,side*9.1)+Vector3.UP*1.8,Vector3(3.7,4.8,4.5),boulder,basis)
	for i in range(7):
		var d: float=distance-10.0+i*3.3
		_prop("box",position_at(d)+Vector3.UP*6.28,Vector3(1.2,0.07,0.25),lamp,frame(d),true)

func _city() -> void:
	for x in range(-4,5):
		for z in range(-4,5):
			var p := Vector3(x*19.0+_rng.randf_range(-2,2),-1.1,z*17.0+_rng.randf_range(-2,2))
			if _near_road(p,11.0): continue
			_city_tower(p,_rng.randf_range(6,10),_rng.randf_range(12,38),x+z)
	for i in range(20):
		var angle: float=float(i)*TAU/20.0
		_city_tower(Vector3(cos(angle)*160,-3,sin(angle)*145),_rng.randf_range(10,17),_rng.randf_range(35,75),i)
	for i in range(11):
		var d: float=float(i)*length/11.0+8.0
		var basis: Basis=frame(d)
		var p: Vector3=position_at(d,8.5)+Vector3.UP*3.0
		_prop("box",p,Vector3(3.8,2.4,0.16),Color("153652"),basis)
		_prop("box",p+basis.z*0.09,Vector3(3.45,2.07,0.03),Color("376b87"),basis,true)
		_sign(p+basis.z*0.12,basis,["LUMO","NOVA","HORIZON"][i%3],0.016)
	for i in range(48):
		var a: float=float(i)*TAU/48.0
		var b: float=float(i+1)*TAU/48.0
		_beam(Vector3(cos(a)*13,26+sin(a)*7,0),Vector3(cos(b)*13,26+sin(b)*7,0),0.32,Color("67d9ed"),true)
	_prop("crystal",Vector3(0,17,0),Vector3(3,7,3),Color("a0caec"))

func _city_tower(at: Vector3, width: float, height: float, index: int) -> void:
	var base := Color("29435e") if posmod(index,2)==0 else Color("344a69")
	_prop("glass_tower",at+Vector3.UP*height*0.5,Vector3(width,height,width*0.8),base.lightened(0.18))
	_prop("box",at+Vector3.UP*(height+0.3),Vector3(width+0.4,0.6,width*0.8+0.4),Color("657f9b"))
	var accent := Color("6fcddd") if posmod(index,3)!=0 else Color("aeabed")
	for floor_index in range(2,int(height/3.2),3):
		var y: float=floor_index*3.2
		for side in [-1.0,1.0]:
			_prop("box",at+Vector3(0,y,side*(width*0.4+0.03)),Vector3(width*0.84,0.12,0.08),Color("627f98"))
	for column in range(1,4):
		var x: float=-width*0.5+float(column)*width/4.0
		for side in [-1.0,1.0]:
			_prop("box",at+Vector3(x,height*0.5,side*(width*0.4+0.04)),Vector3(0.075,height,0.07),Color("405d7a"))
	for side in [-1.0,1.0]: _prop("box",at+Vector3(side*width*0.48,height*0.5,width*0.405),Vector3(0.09,height,0.06),accent,Basis.IDENTITY,true)
	_prop("box",at+Vector3.UP*(height+2),Vector3(width*0.48,3.0,width*0.4),base.lightened(0.08))

func _holo_gate(distance: float) -> void:
	var basis: Basis=frame(distance)
	var at: Vector3=position_at(distance)
	for side in [-1.0,1.0]:
		_prop("box",at+basis.x*side*6.7+Vector3.UP*4.2,Vector3(0.32,8.4,0.42),Color("78deef"),basis,true)
		_prop("box",at+basis.x*side*5.6+Vector3.UP*8.2,Vector3(2.7,0.32,0.42),Color("78deef"),basis.rotated(basis.z,side*0.5),true)
	_prop("box",at+Vector3.UP*8.8,Vector3(9.0,0.32,0.42),Color("91dce9"),basis,true)
