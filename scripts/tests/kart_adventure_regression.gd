extends SceneTree
## Actual production builds: authored descents, complete cover, unobstructed racing
## envelope, action separation and mobile/high-detail tunnel geometry on all 11 routes.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const EXPANSION = preload("res://scripts/games/kart_expansion_tracks.gd")
const ROUTES = preload("res://scripts/games/kart_adventure_routes.gd")
const TUNNELS = preload("res://scripts/games/kart_adventure_tunnels.gd")
const THRILLS = preload("res://scripts/games/kart_track_thrills.gd")


func _initialize() -> void:
	call_deferred("_run")


func _overlaps(a: Vector2, b: Vector2) -> bool:
	return a.x < b.y and a.y > b.x


func _check_actions(world, tunnel: Vector2) -> void:
	if not world.jump.is_empty():
		assert(not _overlaps(tunnel, Vector2(world.jump.ramp_start, world.jump.gap_end)), "Tunnel crosses a physical jump")
	if not world.loop_layout.is_empty():
		assert(not _overlaps(tunnel, Vector2(world.loop_layout.start, world.loop_layout.start + 70.0)), "Tunnel crosses the loop")
	for pad in world.action.pads:
		assert(not _overlaps(tunnel, Vector2(pad.start, pad.end)), "Reserved tunnel contains a pad")
	for gate in world.action.gates:
		assert(not _overlaps(tunnel, Vector2(gate.distance - 6.0, gate.distance + 6.0)), "Reserved tunnel contains slalom")
	for kicker in world.action.kickers:
		assert(not _overlaps(tunnel, Vector2(kicker.start, kicker.take_off + 10.0)), "Tunnel blocks a kicker landing")
	for dive in world.action.dives:
		assert(not _overlaps(tunnel, Vector2(dive.start, dive.end)), "Two roofs occupy the same passage")
	for edge in world.action.edges:
		assert(not _overlaps(tunnel, Vector2(edge.start, edge.end)), "Tunnel crosses an open edge")


func _check_winding(mesh: Mesh) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index in range(0, vertices.size(), 3):
		var cross: Vector3 = (vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index])
		assert(cross.dot(normals[index]) < -0.000001,
			"Godot clockwise front-face winding disagrees with the authored surface normal")


func _check_geometry(world) -> void:
	var passage: Node3D = world.get_node("AdventureTunnel")
	var metrics: Dictionary = passage.get_meta("adventure_tunnel")
	assert(metrics == world.get_meta("adventure_tunnel"), "Capture metadata differs from production geometry")
	assert(float(metrics.length_m) > 150.0, "Passage is too short to be an experience")
	assert(float(metrics.clearance_m) >= 9.0, "Headroom lost")
	assert(int(metrics.detail_instances) > 120, "Themed interior is missing")
	assert(passage.get_child_count() <= 40, "Tunnel draw batches exceed the bounded budget")
	for mesh_name in ["ContinuousInnerVault", "SolidHillsideCover" if bool(metrics.hillside_cover) else "GalleryOuterHull", "CarvedEntranceAndExit"]:
		_check_winding(passage.get_node(mesh_name).mesh)
	var shell: MeshInstance3D = passage.get_node("ContinuousInnerVault")
	var arrays: Array = shell.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert(vertices.size() == int(metrics.sections) * (int(metrics.ring_segments) + 2) * 6)
	assert(vertices.size() == normals.size())
	for index in range(vertices.size()):
		assert(vertices[index].is_finite() and normals[index].is_finite(), "Invalid shell geometry")
		assert(normals[index].length_squared() > 0.9, "Degenerate shell triangle")
	for index in range(33):
		var d: float = lerpf(float(metrics.start_m), float(metrics.end_m), float(index) / 32.0)
		var basis: Basis = world.frame(d)
		var center: Vector3 = world.position_at(d)
		var ring: PackedVector3Array = TUNNELS.cross_section(world, d, int(metrics.ring_segments))
		for vertex in ring:
			var local: Vector3 = basis.inverse() * (vertex - center)
			assert(absf(local.x) > 6.3 or local.y > 6.5, "Tunnel intersects the clear racing/camera corridor")
		if bool(metrics.hillside_cover):
			var hill: PackedVector3Array = TUNNELS._cover_row(world, d, float(metrics.start_m), float(metrics.end_m))
			var middle: int = hill.size() / 2
			assert(hill[middle].y > ring[middle].y + 2.0, "Road roof is exposed above its hillside")
	var stack: Array[Node] = [passage]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		assert(not node is CollisionObject3D, "A scenery collider changed the driving authority")
		for child in node.get_children():
			stack.append(child)


func _baseline_length(track_id: String) -> float:
	var previous = WORLD.new()
	previous.track_id = track_id
	previous.definition = EXPANSION._original_definition(track_id) if track_id in EXPANSION.IDS else TRACKS._original_definition(track_id)
	previous._make_curve()
	var result: float = previous.length
	previous.free()
	return result


func _check_world_extent(world) -> void:
	for index in range(256):
		var at: Vector3 = world.position_at(world.length * float(index) / 256.0)
		if str(world.track_id) in EXPANSION.IDS:
			assert(absf(at.x) + TUNNELS.COVER_WIDTH < 450.0 and absf(at.z) + TUNNELS.COVER_WIDTH < 450.0,
				"Extended road or hillside exceeds the 900 m themed ground plane")
		elif str(world.track_id) in ["zauberwald", "holo_city"]:
			assert(absf(at.x) + TUNNELS.COVER_WIDTH < world.world_extent.x + 13.0)
			assert(absf(at.z) + TUNNELS.COVER_WIDTH < world.world_extent.y + 13.0)


func _check_scenery(world) -> void:
	var details: Array = world.get_meta("reference_detail_sites", [])
	for site: Dictionary in details:
		assert(not TUNNELS.contains(world, float(site.distance), 12.0), "Outdoor assembly intersects the reserved passage")
	if str(world.track_id) != "zauberwald":
		return
	var clusters: Array = world.get_meta("forest_library_retained_clusters", [])
	assert(clusters.size() >= 80, "Extended forest lost its roadside population")
	var occupied_eighths: Dictionary = {}
	for cluster: Dictionary in clusters:
		var at: Vector3 = cluster.position
		var radius: float = float(cluster.radius)
		assert(not world._near_road(at, 8.5 + radius), "Forest crown envelope obstructs the road")
		var near: Vector2 = world._nearest_horizontal(at)
		var distance: float = world._road_distances[int(near.y)]
		occupied_eighths[int(distance / world.length * 8.0)] = true
		for site: Dictionary in details:
			var other: Vector3 = site.position
			assert(Vector2(at.x - other.x, at.z - other.z).length() >= radius + float(site.radius) or float(site.radius) < 4.0,
				"Tree canopy enters the library footprint")
	assert(occupied_eighths.size() == 8, "Forest scenery is confined to the old world footprint")


func _write_report(records: Array[Dictionary]) -> void:
	var path: String = "user://kart_adventure_report.json"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--report="):
			path = str(arg).trim_prefix("--report=")
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null, "Could not write the measured route report")
	output.store_string(JSON.stringify({"schema_version": 1, "baseline_commit": "9f8341494ea316c9e36ed6722915ab34b22e67bd", "units": "meters", "routes": records}, "\t"))
	output.close()
	print("[KartAdventure] report=", ProjectSettings.globalize_path(path))


func _run() -> void:
	# Die elf Abenteuerrouten und Sonnenhafen bleiben im Katalog. Spätere Strecken
	# (Windwerk, Riesengarten, Signatur-Strecken) erweitern ihn, ohne diese Prüfung
	# zu berühren; früher stand hier die Gesamtzahl 12.
	assert(ROUTES.IDS.size() == 11, "Adventure route set changed")
	assert("sonnenhafen" in TRACKS.IDS, "Sonnenhafen left the catalog")
	for route_id in ROUTES.IDS:
		assert(route_id in TRACKS.IDS, "Adventure route missing from the catalog: %s" % route_id)
	var signatures: Dictionary = {}
	var records: Array[Dictionary] = []
	var reference_length: float = _baseline_length("sonnenhafen")
	records.append({"track_id": "sonnenhafen", "before_length_m": reference_length, "after_length_m": reference_length, "new_tunnel": false, "unchanged": true})
	for track_id in ROUTES.IDS:
		var world = WORLD.new()
		root.add_child(world)
		world.build(true, track_id)
		assert(world.length >= reference_length, "An adventure route is shorter than Sonnenhafen")
		assert(world.length >= 1900.0 and world.length <= 2050.0, "Authored route is outside the intended 1.9–2.05 km scope")
		_check_world_extent(world)
		_check_scenery(world)
		assert(world.checkpoint_positions.size() == 8)
		var span: Dictionary = world.adventure_tunnel
		assert(not span.is_empty())
		assert(float(span.start) > 35.0 and float(span.end) < world.length - 30.0)
		assert(float(span.descent_m) >= 6.0 and float(span.ascent_m) >= 6.0, "Authored descent/climb is absent")
		var signature: String = str(ROUTES.points(track_id))
		assert(not signatures.has(signature), "Two themes share an identical track")
		signatures[signature] = true
		var tunnel := Vector2(span.start, span.end)
		var production: Dictionary = world.production_tunnel_layout
		assert(not production.is_empty(), "Production tunnel was lost")
		var modules := Vector2(production.start, production.end)
		assert(not _overlaps(Vector2(tunnel.x - 20.0, tunnel.y + 20.0), modules), "The two tunnel roofs overlap")
		_check_actions(world, tunnel)
		_check_actions(world, modules)
		for spec in THRILLS.specs_for(track_id):
			if spec.kind == "turbo":
				var count: int = world.action.pads.filter(func(pad): return pad.get("thrill") == spec.id).size()
				assert(count == 3, "Moving the turbo section lost a field")
		_check_geometry(world)
		var old: Node3D = world.get_node("AdventureTunnel")
		world.remove_child(old)
		old.free()
		world.low_detail = false
		TUNNELS.build(world)
		_check_geometry(world)
		print("[KartAdventure] ", track_id, " length=", snappedf(world.length, 0.1),
			" tunnel=", snappedf(float(span.length_m), 0.1), " descent=", snappedf(float(span.descent_m), 0.1),
			" cover=", span.covered_type, " PASS")
		records.append({"track_id": track_id, "before_length_m": _baseline_length(track_id), "after_length_m": world.length,
			"new_tunnel": true, "tunnel_name": span.name, "tunnel_start_m": span.start_m, "tunnel_end_m": span.end_m,
			"tunnel_length_m": span.length_m, "descent_m": span.descent_m, "ascent_m": span.ascent_m,
			"production_tunnel_start_m": modules.x, "production_tunnel_end_m": modules.y, "pad_count": world.action.pads.size(),
			"covered_type": span.covered_type, "clearance_m": span.clearance_m, "actions_clear": true, "low_and_high_geometry_pass": true})
		world.free()
	var original = WORLD.new()
	original.track_id = "sonnenhafen"
	original.definition = TRACKS.definition("sonnenhafen")
	original._make_curve()
	assert(original.adventure_tunnel.is_empty(), "Sonnenhafen received the new tunnel")
	assert(absf(original.length - reference_length) < 0.001, "Sonnenhafen geometry changed")
	assert(TRACKS.definition("sonnenhafen").points == TRACKS._original_definition("sonnenhafen").points)
	original.free()
	_write_report(records)
	print("[KartAdventure] PASS: eleven routes, separate tunnel roofs, retained boost fields, two tunnel LODs, untouched Sonnenhafen")
	quit(0)
