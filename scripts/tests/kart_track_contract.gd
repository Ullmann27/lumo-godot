extends SceneTree
## Surface projection, seam and geometry contracts required by free driving.
const SKY_ISLANDS=preload("res://scripts/games/kart_sky_islands.gd")
const GARDEN = preload("res://scripts/games/garden/kart_garden_course.gd")

func _check_garden_wall(world) -> void:
	for apex in GARDEN.HOSE_APEXES:
		var basis: Basis = world.frame(apex)
		var pad := GARDEN.hose_wall_pads(world).filter(func(p): return p.start < apex and p.end > apex)
		assert(pad.size() == 1, "Eine Turbolinie pro Steilkurve")
		var lateral: float = pad[0].lateral
		assert(basis.x.y * lateral > 1.5, "Außenlinie liegt über der Innenbahn")
		var road: Dictionary = world.sample_road(world.position_at(apex), apex)
		var slow := GARDEN.wall_velocity(world, road, -basis.z, 2.0)
		var fast := GARDEN.wall_velocity(world, road, -basis.z, 45.0)
		assert(slow.dot(basis.x) * lateral < 0.0, "Langsam geht es hangabwärts")
		assert(fast.dot(basis.x) * lateral > 0.0, "Bei Tempo trägt es das Kart an die Außenwand")
		assert(absf(fast.dot(basis.y)) < 0.02, "Kontakt hält das Kart in der Wandebene")
	for metre in range(int(GARDEN.HOSE.x), int(GARDEN.HOSE.y)):
		assert(world.frame(metre).y.y > 0.69, "Höchstens 45 Grad Überhöhung plus Längsneigung")

func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var script=load("res://scripts/games/kart_world.gd")
	var definitions=load("res://scripts/games/kart_tracks.gd")
	for id in definitions.IDS:
		var world=script.new()
		world.definition=definitions.definition(id)
		# _make_curve() contains track-specific authoring scale. Mirror build() by setting
		# track_id before invoking the geometry contract directly.
		world.track_id=id
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
			var split: Dictionary=SKY_ISLANDS.split_route_layout(world.length)
			assert(float(split.start)>float(world.jump.gap_end)+20.0)
			assert(float(split.end)<SKY_ISLANDS.STAR_GATE*world.length-17.0, "Wolkenweg rejoins before Sternentor")
			var split_mid: float=(float(split.start)+float(split.end))*0.5
			assert(world.alternate_route_height(split_mid,-3.0)>1.5, "Wolkenweg left lane is physically raised")
			assert(world.alternate_route_height(split_mid,3.0)<0.01, "Main lane remains on the original road surface")
			assert(absf(world.alternate_route_height(float(split.start)-0.5,-3.0))<0.01)
			assert(absf(world.alternate_route_height(float(split.end)+0.5,-3.0))<0.01)
			assert(world.alternate_route_pitch(float(split.start)+2.0,-3.0)>0.0)
			assert(world.alternate_route_pitch(float(split.end)-2.0,-3.0)<0.0)
		if id == GARDEN.ID:
			_check_garden_wall(world)
		assert(world.position_at(0).distance_to(world.position_at(world.length))<0.001)
		assert(world.checkpoint_positions.size()==8)
		var min_radius: float=INF
		for i in range(300):
			var d: float=float(i)*world.length/300.0
			var bend: float=world.forward(d).angle_to(world.forward(d+2.0))
			if bend>0.001: min_radius=minf(min_radius,2.0/bend)
			# +/-4 m lanes, or the outer lanes of a narrower passage deck (Kronenbrücke
			# in Dschungelherz: 3.6 m); just beyond such a deck edge is not road.
			var half: float=world.road_width_at(d)*0.5
			var lane: float=minf(4.0,half-0.3)
			assert(lane>0.5, "%s: road narrower than one kart at %.0f m" % [id,d])
			if half<4.3:
				assert(not world.sample_road(world.position_at(d,half+0.5),d).on_road,
					"%s: narrow deck accepts a lane beyond its edge at %.0f m" % [id,d])
			for lateral in [-lane,0.0,lane]:
				var p: Vector3=world.position_at(d,lateral)
				var sample: Dictionary=world.sample_road(p,d)
				assert(absf(sample.lateral-lateral)<0.12)
				assert(absf(sample.height-p.y)<0.08)
				assert(sample.on_road, "%s: valid lane %.1f m rejected at %.0f m" % [id,lateral,d])
				var in_wall: bool = id == GARDEN.ID and d >= GARDEN.HOSE.x and d <= GARDEN.HOSE.y
				assert(sample.basis.y.y > (0.69 if in_wall else 0.9), "%s: road tilt %.2f at %.0f m lane %.1f" % [id,sample.basis.y.y,d,lateral])
				assert(sample.distance>=0.0 and sample.distance<world.length)
		var clearance: float=INF
		for a in range(100):
			for b in range(a+1,100):
				var separation: float=minf(float(b-a),float(100-b+a))*world.length/100.0
				if separation<25.0: continue
				var pa: Vector3=world.position_at(float(a)*world.length/100.0)
				var pb: Vector3=world.position_at(float(b)*world.length/100.0)
				# Gewollte Überführungen (z. B. Blumentopf-Spirale im Riesengarten) liegen
				# mindestens 6 m übereinander und berühren sich nicht.
				if absf(pa.y-pb.y)>6.0: continue
				clearance=minf(clearance,Vector2(pa.x-pb.x,pa.z-pb.z).length())
		assert(clearance>world.WIDTH+2.0, "%s: track crosses itself (clearance %.1f m)" % [id,clearance])
		assert(min_radius>18.0)
		print("[TrackContract] ",id," length=",snappedf(world.length,0.1)," minimum_curve_radius=",snappedf(min_radius,0.1)," PASS")
		world.free()
	quit(0)
