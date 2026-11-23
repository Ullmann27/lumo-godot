extends RefCounted
## Additional driveable sequences and themed scenery for every production circuit.
## Action plans are deterministic and independent of the visual quality profile.
## Static props reuse KartWorld's spatial batches; animated accents use one GPU batch.
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const PIECES = preload("res://scripts/games/track_pieces/kart_track_pieces.gd")
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const THRILLS = preload("res://scripts/games/kart_track_thrills.gd")
const TUNNELS = preload("res://scripts/games/kart_production_tunnel_layout.gd")
const FLOW = preload("res://assets/shaders/kart_spectacle_flow.gdshader")
const META: StringName = &"kart_spectacle"
const OFF_META: StringName = &"spectacle_off"
const THEMES: Dictionary = {
	"sonnenhafen": ["coast", Color("ded5b7"), Color("35d5e8"), Color("4d9665"), "Küsten-Sprint"],
	"zauberwald": ["forest", Color("50635d"), Color("b1f7bb"), Color("327554"), "Wurzel-Rallye"],
	"bergwelt": ["sky", Color("727aa6"), Color("73efff"), Color("93c56e"), "Wolken-Sprint"],
	"holo_city": ["neon", Color("1d304e"), Color("ff6fdb"), Color("38d9ec"), "Neon-Sprint"],
	"crystal_canyon": ["crystal", Color("665384"), Color("b8a0ff"), Color("5adaea"), "Kristall-Rallye"],
	"jungle_temple": ["forest", Color("a9a575"), Color("ffe29a"), Color("267649"), "Tempel-Sprint"],
	"candy_cloud": ["candy", Color("f1c7de"), Color("a3eaff"), Color("e7a4ca"), "Zucker-Sprint"],
	"volcano_night": ["volcano", Color("333248"), Color("ff803f"), Color("9e5c44"), "Glut-Rallye"],
	"winter_sprint": ["alpine", Color("c3d7df"), Color("74cfff"), Color("537d83"), "Eis-Sprint"],
	"galaxy_ringway": ["cosmos", Color("383362"), Color("bfa1ff"), Color("4d8bd5"), "Kometen-Sprint"],
	"desert_drift": ["desert", Color("cd9c6f"), Color("6ee8ce"), Color("8ea86d"), "Dünen-Rallye"],
	"learning_lab": ["neon", Color("254955"), Color("79f1bc"), Color("9ca4ef"), "Funken-Sprint"],
	"jungle_emerald_3600": ["forest", Color("a5ab75"), Color("7ee8bc"), Color("24713f"), "Smaragd-Rallye"],
	"riesengarten_2400": ["garden", Color("aa7255"), Color("ffdd59"), Color("659b49"), "Blüten-Sprint"],
	"windwerk_3000": ["wind", Color("d4d4c1"), Color("54e4cb"), Color("6a9f7f"), "Wind-Sprint"],
}


static func of(world) -> Dictionary:
	return world.get_meta(META, {})


static func _busy(world) -> Array:
	var result: Array = PIECES.blocked_ranges(world)
	var authored: Array = world._piece_markers.duplicate()
	authored.append_array(world.definition.get("track_pieces", []))
	authored.append_array(world.get_meta(PIECES.META_KEY, []))
	for marker in authored:
		var piece: Dictionary = PIECES.resolve(world, marker)
		if not piece.is_empty():
			result.append(Vector2(float(piece.start) - 34.0, float(piece.end) + 10.0))
	result.append(Vector2(0.0, 80.0))
	result.append(Vector2(float(world.length) - 80.0, float(world.length)))
	for kicker in world.action.get("kickers", []):
		result.append(Vector2(float(kicker.start) - 28.0, float(kicker.get("landing_road_end", float(kicker.take_off) + 75.0))))
	for trial in world.action.get("trials", []):
		result.append(Vector2(float(trial.start) - 30.0, float(trial.end) + 30.0))
	for zone in world.get_meta("item_zone_hazards", {}).get(str(world.track_id), []):
		if zone is Dictionary and zone.has("start") and zone.has("end"):
			result.append(Vector2(float(zone.start) - 30.0, float(zone.end) + 30.0))
	var preferred: float = float(TUNNELS.PREFERRED.get(str(world.track_id), -1.0))
	if preferred > 0.0:
		result.append(Vector2(preferred * float(world.length) - 130.0, preferred * float(world.length) + 90.0))
	# Keep complete signature experiences and their merge/landing corridors.
	if str(world.track_id) == "riesengarten_2400":
		for zone in [Vector2(325, 605), Vector2(730, 1240), Vector2(1280, 1400), Vector2(1510, 1700), Vector2(1740, 1900), Vector2(1940, 2330)]:
			result.append(zone)
	return result


static func _free(start: float, span: float, busy: Array, lead: float = 34.0) -> bool:
	for zone in busy:
		if start - lead < float(zone.y) + 6.0 and start + span > float(zone.x) - 6.0:
			return false
	return true


static func _choose(world, wish: float, span: float, busy: Array, jump: bool, lead: float = 34.0) -> float:
	var length: float = float(world.length)
	# Compact flat turbo lines need no jump/bottleneck warning run-up. A 2 m
	# search finds narrow free intervals without changing any protected corridor.
	var stride: float = 2.0 if lead < 12.0 else 6.0
	for i in range(ceili(length / stride) * 2):
		var step: float = floorf(float(i + 1) / 2.0) * stride * (1.0 if i % 2 == 0 else -1.0)
		var at: float = wish + step
		if at < 95.0 or at + span > length - 85.0 or not _free(at, span, busy, lead):
			continue
		if jump:
			var direction: Vector3 = world.forward(at + 14.0)
			var straight: bool = true
			for advance in [0.0, 20.0, 40.0, 65.0]:
				if direction.dot(world.forward(at + advance)) < 0.975:
					straight = false
			if not straight:
				continue
			# A ramp may not send a kart into an upper road deck.
			var p: Vector3 = world.position_at(at + 35.0)
			var samples: PackedVector3Array = world._road_samples
			var distances: PackedFloat32Array = world._road_distances
			for sample_index in range(samples.size()):
				if absf(float(distances[sample_index]) - at) < 100.0:
					continue
				var delta: Vector3 = samples[sample_index] - p
				if Vector2(delta.x, delta.z).length() < 20.0 and delta.y > -1.0 and delta.y < 9.0:
					straight = false
					break
			if not straight:
				continue
		return at
	return -1.0


## New action sequences are real ramp/pad/wall data consumed by the existing race
## solvers. If a circuit is tightly authored, compact split turbo choices fit its
## free intervals instead of silently overlapping a tunnel or existing jump.
static func plan(world) -> void:
	var report: Dictionary = {"actions": [], "markers": [], "sites": [], "built": false}
	world.set_meta(META, report)
	if bool(world.get_meta(OFF_META, false)) or not THEMES.has(str(world.track_id)):
		return
	var busy: Array = _busy(world)
	report.base_blocked = busy.duplicate()
	var target: int = clampi(ceili(float(world.length) / 650.0), 3, 6)
	for i in range(target):
		var wish: float = float(world.length) * (float(i) + 0.7) / float(target)
		var kind: String = "crest" if i % 3 == 0 else ("narrow" if i % 3 == 1 else "turbo")
		if str(world.track_id) == "riesengarten_2400":
			kind = "turbo"
		var span: float = 88.0 if kind == "crest" else (28.0 if kind == "narrow" else 32.0)
		var lead: float = 18.0 if kind == "turbo" else 34.0
		var chosen: float = _choose(world, wish, span, busy, kind == "crest", lead)
		if chosen < 0.0:
			kind = "turbo"
			span = 16.0
			lead = 6.0
			chosen = _choose(world, wish, span, busy, false, lead)
		if chosen < 0.0:
			continue
		var entry: Dictionary = {"kind": kind, "start": chosen, "end": chosen + span, "index": i, "lead_m": lead}
		if kind == "crest":
			world.action.kickers.append({
				"start": chosen, "take_off": chosen + 14.0, "length": 14.0,
				"height": 2.0, "angle": atan2(4.0, 14.0), "profile": "ease_in",
				"flight_gravity": 22.0, "lift_bonus": 2.6, "max_lift": 7.0,
				"landing_road_end": chosen + span, "spectacle": true,
			})
		elif kind == "narrow":
			report.markers.append({"type": "narrow", "distance": chosen,
				"params": {"length": 28.0, "open_width": 6.8, "taper": 9.0}})
		else:
			# Alternating optional lines create an actual steering decision.
			var count: int = 2 if span < 20.0 else 3
			for pad_index in range(count):
				var d: float = chosen + float(pad_index) * (8.0 if count == 2 else 11.0)
				world.action.pads.append({"start": d, "end": d + 6.0,
					"lateral": -2.2 if pad_index % 2 == 0 else 2.2, "spectacle": true})
		report.actions.append(entry)
		busy.append(Vector2(chosen - lead, chosen + span + 12.0))
	report.sites = _sites(world)
	world.set_meta(META, report)


static func markers(world) -> Array:
	return of(world).get("markers", [])


static func _away_from_loop(world, at: Vector3, radius: float) -> bool:
	if world.loop_layout.is_empty():
		return true
	for i in range(33):
		var p: Vector3 = world.STUNT.LOOP.point(world, world.loop_layout, float(i) / 32.0)
		if Vector2(p.x - at.x, p.z - at.z).length() < radius + 3.0:
			return false
	return true


## Every landmark's full footprint is tested against the entire circuit, not
## only its nearest local lane. Quality changes placement density, never physics.
static func _sites(world) -> Array:
	var result: Array = []
	var count: int = clampi(ceili(float(world.length) / (150.0 if world.low_detail else 85.0)), 12, 42)
	for i in range(count):
		var d: float = (float(i) + 0.37) * float(world.length) / float(count)
		if world.ADVENTURE_TUNNELS.contains(world, d, 15.0):
			continue
		var sign_side: float = -1.0 if i % 2 == 0 else 1.0
		var found: bool = false
		for extra in [0.0, 9.0, 18.0, 30.0]:
			var at: Vector3 = world.position_at(d, sign_side * (24.0 + extra))
			var radius: float = 8.0
			if world._near_road(at, float(world.road_width_at(d)) * 0.5 + radius + 4.0):
				continue
			if PASSAGES.in_view_corridor(world, at) or not _away_from_loop(world, at, radius):
				continue
			at.y -= 5.0
			var ahead: Vector3 = world.forward(d)
			ahead.y = 0.0
			var basis: Basis = Basis.looking_at(ahead.normalized(), Vector3.UP)
			result.append({"distance": d, "position": at, "basis": basis, "radius": radius, "index": i})
			found = true
			break
		if not found:
			continue
	return result


static func build(world) -> void:
	var report: Dictionary = of(world)
	if report.is_empty() or bool(report.get("built", false)):
		return
	report.built = true
	var theme: Array = THEMES.get(str(world.track_id), [])
	if theme.is_empty():
		return
	var before: int = world.decoration_count
	for entry in report.actions:
		_action_gate(world, entry, theme)
	for site in report.sites:
		_landmark(world, site, theme)
	report.added_instances = world.decoration_count - before
	world.set_meta(META, report)
	if not world._only_geometry:
		_motes(world, report.sites, theme)
		_flows(world, report.sites, theme)


static func _put(world, site: Dictionary, shape: String, local: Vector3, size: Vector3, color: Color, glow: bool = false) -> void:
	world._prop(shape, site.position + site.basis * local, size, color, site.basis, glow)


static func _action_gate(world, entry: Dictionary, theme: Array) -> void:
	var lead: float = float(entry.get("lead_m", 34.0))
	var at: float = float(entry.start) - minf(10.0, lead - 2.0)
	var basis: Basis = world.frame(at)
	var half: float = float(world.road_width_at(at)) * 0.5 + 1.5
	var accent: Color = theme[2]
	for side in [-1.0, 1.0]:
		var foot: Vector3 = world.position_at(at, side * half)
		world._prop("box", foot + basis.y * 3.6, Vector3(0.5, 7.2, 0.7), theme[1], basis)
		world._prop("box", foot + basis.y * 3.6 + basis.z * 0.39, Vector3(0.15, 5.9, 0.07), accent, basis, true)
	# Arch starts before the lip; never low over the airborne part of the sequence.
	world._prop("box", world.position_at(at) + basis.y * 7.2, Vector3(half * 2.0 + 0.6, 0.55, 0.7), theme[1], basis)
	var label: String = "PANORAMA-SPRUNG" if entry.kind == "crest" else ("SCHMALE LINIE" if entry.kind == "narrow" else str(theme[4]))
	world._sign(world.position_at(at) + basis.y * 7.2 + basis.z * 0.4, basis, label, 0.014)
	var count: int = 3 if lead < 12.0 else 6
	for n in range(count):
		var d: float = lerpf(float(entry.start) - lead + 1.0, float(entry.start) - 1.0, float(n) / float(count - 1))
		for side in [-1.0, 1.0]:
			world._prop("box", world.position_at(d, side * (half - 0.8)) + world.frame(d).y * 0.12,
				Vector3(0.25, 0.06, 1.8), accent, world.frame(d), true)


static func _landmark(world, site: Dictionary, theme: Array) -> void:
	var style: String = str(theme[0])
	var stone: Color = theme[1]
	var glow: Color = theme[2]
	var leaf: Color = theme[3]
	var index: int = int(site.index)
	# An actual terraced support mass makes distant structures read as places.
	_put(world, site, "rock", Vector3(0, -6.5, 0), Vector3(6.2, 8.0, 6.1), stone.darkened(0.25))
	_put(world, site, "box", Vector3(0, 0.1, 0), Vector3(9.2, 0.7, 8.5), stone)
	match style:
		"forest", "garden":
			for side in [-1.0, 1.0]:
				_put(world, site, "cylinder", Vector3(side * 3.2, 5.1, 0), Vector3(0.9, 10.2, 0.9), stone.darkened(0.35))
				for layer in range(3):
					_put(world, site, "crown", Vector3(side * 3.2, 9.0 + layer * 1.7, 0), Vector3(3.0 - layer * 0.45, 2.5, 3.0 - layer * 0.45), leaf.lightened(layer * 0.04))
			_put(world, site, "box", Vector3(0, 7.0, 0), Vector3(7.5, 0.45, 1.5), stone)
			for n in range(7):
				_put(world, site, "ball", Vector3(-3.0 + n, 6.65 - sin(float(n) * 0.52) * 1.1, 0.25), Vector3.ONE * 0.3, glow, true)
			if style == "garden":
				for petal in range(8):
					var angle: float = TAU * float(petal) / 8.0
					_put(world, site, "ball", Vector3(cos(angle) * 2.2, 5.2 + sin(angle) * 2.2, -2.0), Vector3(1.7, 1.7, 0.45), glow)
				_put(world, site, "ball", Vector3(0, 5.2, -2.0), Vector3(2.0, 2.0, 0.8), Color("8d572e"))
		"crystal", "volcano", "alpine":
			for n in range(5):
				var height: float = 7.0 + float((index + n * 3) % 7)
				var x: float = (n - 2) * 1.8
				_put(world, site, "crystal" if style != "volcano" else "rock", Vector3(x, height * 0.5, (n % 2) * 2.2 - 1.0),
					Vector3(1.5, height, 1.7), glow if n % 2 == 0 else stone, style != "alpine")
			for n in range(4):
				_put(world, site, "box", Vector3(-3.3 + n * 2.2, 0.6, 3.0), Vector3(1.5, 0.12, 1.8), glow, true)
		"neon", "cosmos":
			for side in [-1.0, 1.0]:
				_put(world, site, "box", Vector3(side * 3.4, 6.5, 0), Vector3(1.8, 13.0, 3.5), stone.darkened(0.25))
				for floor_index in range(7):
					_put(world, site, "box", Vector3(side * 3.4, 1.0 + floor_index * 1.7, 1.82), Vector3(1.5, 0.45, 0.08), glow, true)
			_put(world, site, "box", Vector3(0, 9.0, 0), Vector3(8.5, 0.75, 3.8), stone)
			_put(world, site, "ball", Vector3(0, 12.1, 0), Vector3.ONE * 2.2, glow, true)
			for n in range(3):
				_put(world, site, "box", Vector3(0, 3.0 + n * 1.5, 1.6), Vector3(3.8 - n * 0.5, 0.18, 0.2), leaf, true)
		"wind", "sky":
			_put(world, site, "cylinder", Vector3(0, 5.8, 0), Vector3(1.8, 11.6, 1.8), stone)
			_put(world, site, "ball", Vector3(0, 11.2, 0.95), Vector3.ONE * 0.9, glow, true)
			for arm in range(4):
				var angle: float = TAU * float(arm) / 4.0 + float(index) * 0.33
				var offset: Vector3 = Vector3(cos(angle), sin(angle), 0.0) * 2.0
				var basis: Basis = site.basis.rotated(site.basis.z, angle)
				world._prop("box", site.position + site.basis * (Vector3(0, 11.2, 1.0) + offset),
					Vector3(3.8, 0.7, 0.16), leaf, basis)
			for n in range(4):
				_put(world, site, "crown", Vector3(-3.0 + n * 2.0, -0.5, 2.6), Vector3(2.0, 1.0, 2.0), Color("e5eef0"))
		"desert":
			for level in range(5):
				_put(world, site, "box", Vector3(0, 0.7 + level * 1.2, 0), Vector3(8.4 - level * 1.45, 1.2, 7.4 - level * 1.25), stone.lightened(level * 0.035))
			for side in [-1.0, 1.0]:
				_put(world, site, "cylinder", Vector3(side * 3.7, 3.4, 2.6), Vector3(0.45, 6.8, 0.45), Color("695840"))
				_put(world, site, "crown", Vector3(side * 3.7, 6.7, 2.6), Vector3(2.6, 0.9, 2.6), leaf)
			_put(world, site, "ball", Vector3(0, 7.0, 0), Vector3.ONE * 0.6, glow, true)
		"candy":
			for side in [-1.0, 1.0]:
				_put(world, site, "cylinder", Vector3(side * 2.6, 4.0, 0), Vector3(1.3, 8.0, 1.3), stone)
				_put(world, site, "ball", Vector3(side * 2.6, 8.2, 0), Vector3.ONE * 2.7, glow if side < 0 else leaf)
				for n in range(5):
					_put(world, site, "box", Vector3(side * 2.6, 1.0 + n * 1.4, 0.73), Vector3(1.35, 0.3, 0.08), glow, true)
			_put(world, site, "roof", Vector3(0, 5.8, 0), Vector3(8.1, 2.0, 5.0), leaf)
		_:
			_put(world, site, "cylinder", Vector3(0, 6.3, 0), Vector3(3.0, 12.6, 3.0), stone)
			for n in range(3):
				_put(world, site, "cylinder", Vector3(0, 3.0 + n * 3.1, 0), Vector3(3.1, 0.7, 3.1), leaf)
			_put(world, site, "ball", Vector3(0, 12.7, 0), Vector3.ONE * 1.5, glow, true)
			_put(world, site, "roof", Vector3(0, 14.0, 0), Vector3(4.0, 1.0, 4.0), stone.darkened(0.35))


static func _motes(world, sites: Array, theme: Array) -> void:
	if sites.is_empty():
		return
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.use_custom_data = true
	var mote := SphereMesh.new()
	mote.radius = 0.12
	mote.height = 0.24
	mote.radial_segments = 6
	mote.rings = 3
	batch.mesh = mote
	var per_site: int = 4 if world.low_detail else 10
	batch.instance_count = sites.size() * per_site
	for i in range(batch.instance_count):
		var site: Dictionary = sites[floori(float(i) / float(per_site))]
		var phase: float = fposmod(float(i) * 0.6180339, 1.0)
		var offset := Vector3(sin(float(i) * 2.4) * 4.0, 3.0 + float(i % 7), cos(float(i) * 1.7) * 4.0)
		batch.set_instance_transform(i, Transform3D(Basis.IDENTITY, site.position + offset))
		batch.set_instance_color(i, theme[2])
		batch.set_instance_custom_data(i, Color(phase, float(i % 5) / 5.0, 0.0, 1.0))
	var node := MultiMeshInstance3D.new()
	node.name = "CourseSpectacleMotes"
	node.multimesh = batch
	var material := ShaderMaterial.new()
	material.shader = FLOW
	material.set_shader_parameter("motes", true)
	material.set_shader_parameter("motion_gain", 0.0 if bool(world.get_meta("reduce_motion", false)) else 1.0)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)


static func _flows(world, sites: Array, theme: Array) -> void:
	var style: String = str(theme[0])
	if not style in ["coast", "forest", "crystal", "volcano", "neon", "cosmos", "alpine"]:
		return
	var material := ShaderMaterial.new()
	material.shader = FLOW
	material.set_shader_parameter("flow_color", theme[2])
	material.set_shader_parameter("motion_gain", 0.0 if bool(world.get_meta("reduce_motion", false)) else 1.0)
	for i in range(0, sites.size(), 4 if world.low_detail else 3):
		var site: Dictionary = sites[i]
		var panel := MeshInstance3D.new()
		panel.name = "CourseSpectacleCascade%d" % i
		var mesh := QuadMesh.new()
		mesh.size = Vector2(3.2, 10.0)
		panel.mesh = mesh
		panel.material_override = material
		panel.transform = Transform3D(site.basis, site.position + site.basis * Vector3(0, 5.0, 2.8))
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		panel.visibility_range_end = 150.0 if world.low_detail else 220.0
		panel.visibility_range_end_margin = 15.0
		world.add_child(panel)


static func set_reduced_motion(world, reduced: bool) -> void:
	world.set_meta("reduce_motion", reduced)
	for child in world.get_children():
		if not str(child.name).begins_with("CourseSpectacle"):
			continue
		if child is GeometryInstance3D and child.material_override is ShaderMaterial:
			child.material_override.set_shader_parameter("motion_gain", 0.0 if reduced else 1.0)

## The garden renders its signature pads in its own environment. Add only the
## new sequence visuals there, leaving its watering-can and leaf geometry intact.
static func build_new_action(world) -> void:
	for pad in world.action.get("pads", []):
		if bool(pad.get("spectacle", false)):
			ACTION._build_pad(world, pad, world.definition.accent)
	for kicker in world.action.get("kickers", []):
		if bool(kicker.get("spectacle", false)):
			ACTION._build_kicker(world, kicker, world.definition.accent)
