extends SceneTree
## Surface projection, seam and geometry contracts required by free driving.
const SKY_ISLANDS=preload("res://scripts/games/kart_sky_islands.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var script=load("res://scripts/games/kart_world.gd")
	var definitions=load("res://scripts/games/kart_tracks.gd")
	for id in definitions.IDS:
		var world=script.new()
		world.definition=definitions.definition(id)
		world._make_curve()
		assert(world.length>340.0)
		if id=="bergwelt":
			assert(world.length>400.0, "Himmelsinseln must remain a long-form course")
			world.jump=SKY_ISLANDS.jump_layout(world.length)
			var inside_gap: float=(float(world.jump.take_off)+float(world.jump.gap_end))*0.5
			var safe_reset: float=world.safe_respawn_distance(
				inside_gap,
				0.0,
				world.length/8.0*5.0
			)
			assert(not world.in_gap(safe_reset), "Reset must never place the kart inside the sky gap")
			assert(safe_reset<float(world.jump.ramp_start), "Reset returns before the jump danger zone")
			var lap2_gap: float=world.length+inside_gap
			var lap2_reset: float=world.safe_respawn_distance(lap2_gap,world.length+world.length*3.0/8.0,world.length+world.length*4.0/8.0-1.0)
			assert(lap2_reset>world.length)
			assert(not world.in_gap(lap2_reset))
		assert(world.position_at(0).distance_to(world.position_at(world.length))<0.001)
		assert(world.checkpoint_positions.size()==8)
		var min_radius: float=INF
		for i in range(300):
			var d: float=float(i)*world.length/300.0
			var bend: float=world.forward(d).angle_to(world.forward(d+2.0))
			if bend>0.001: min_radius=minf(min_radius,2.0/bend)
			for lateral in [-4.0,0.0,4.0]:
				var p: Vector3=world.position_at(d,lateral)
				var sample: Dictionary=world.sample_road(p,d)
				assert(absf(sample.lateral-lateral)<0.12)
				assert(absf(sample.height-p.y)<0.08)
				assert(sample.on_road)
				assert(sample.basis.y.y>0.9)
				assert(sample.distance>=0.0 and sample.distance<world.length)
		var clearance: float=INF
		for a in range(100):
			for b in range(a+1,100):
				var separation: float=minf(float(b-a),float(100-b+a))*world.length/100.0
				if separation<25.0: continue
				var pa: Vector3=world.position_at(float(a)*world.length/100.0)
				var pb: Vector3=world.position_at(float(b)*world.length/100.0)
				clearance=minf(clearance,Vector2(pa.x-pb.x,pa.z-pb.z).length())
		assert(clearance>world.WIDTH+2.0)
		assert(min_radius>18.0)
		print("[TrackContract] ",id," length=",snappedf(world.length,0.1)," minimum_curve_radius=",snappedf(min_radius,0.1)," PASS")
		world.free()
	quit(0)
