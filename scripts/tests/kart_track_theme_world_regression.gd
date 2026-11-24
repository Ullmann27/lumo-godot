extends SceneTree
## Bounded real-world geometry inspection; coordinate shared engine resources.
## Default: learning_lab/light. Camera appearance and Android remain separate gates.

const THEMES = preload("res://scripts/games/track_themes/track_theme_registry.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const CONTACT = preload("res://scripts/tests/helpers/kart_theme_ground_contact.gd")
const TRACK_IDS: Array[String] = [
	"zauberwald",
	"bergwelt",
	"holo_city",
	"crystal_canyon",
	"jungle_temple",
	"candy_cloud",
	"volcano_night",
	"winter_sprint",
	"galaxy_ringway",
	"desert_drift",
	"learning_lab",
]
# These five expansion worlds have an ordinary ground plane in production.
# Lava, floating worlds and sculpted terrain need different support semantics.
const GROUND_TRACKS: Array[String] = [
	"crystal_canyon",
	"jungle_temple",
	"winter_sprint",
	"desert_drift",
	"learning_lab",
]
const MAX_RECORDED_PARTS := 60000
const MAX_SUPPORT_TRIANGLES := 250000
const CONTACT_TOLERANCE := 0.35
const ROAD_CLEARANCE := 8.5
const GEOMETRY_TOLERANCE := 0.15


class ObservedWorld:
	extends "res://scripts/games/kart_world.gd"
	var recorded: Array[Dictionary] = []
	var flushed_records: Array[Dictionary] = []
	var detail_begin := -1
	var detail_flushes := 0

	func _prop(
		kind: String,
		at: Vector3,
		size: Vector3,
		color: Color,
		basis: Basis = Basis.IDENTITY,
		glow: bool = false
	) -> void:
		super._prop(kind, at, size, color, basis, glow)
		recorded.append(
			{
				"kind": kind,
				"transform": Transform3D(basis.scaled_local(size), at),
				"color": color,
				"glow": glow
			}
		)

	func _flush_instances() -> void:
		if has_meta("reference_detail_sites"):
			detail_flushes += 1
			flushed_records = recorded.duplicate()
			detail_begin = recorded.size() - int(get_meta("reference_detail_count", 0))
		super._flush_instances()


var _failures := 0
var _checks := 0
var _cases := 0
var _support_probes := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var selected := "learning_lab"
	var quality := "light"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--track="):
			selected = argument.trim_prefix("--track=")
		elif argument.begins_with("--quality="):
			quality = argument.trim_prefix("--quality=")
		else:
			push_error("[ThemeWorld] Unknown argument: " + argument)
			quit(2)
			return
	if (
		(selected != "all" and selected not in TRACK_IDS)
		or quality not in ["light", "full", "both"]
	):
		push_error("[ThemeWorld] Use --track=<one theme ID|all> --quality=<light|full|both>")
		quit(2)
		return
	_check(THEMES.IDS.size() == TRACK_IDS.size(), "registry contains exactly eleven themes")
	for track_id in TRACK_IDS:
		_check(track_id in THEMES.IDS and track_id in TRACKS.IDS, "catalog/registry: " + track_id)
	_check_harbour_dispatch()
	var selections: Array[String] = []
	for track_id in TRACK_IDS:
		if selected == "all" or selected == track_id:
			selections.append(track_id)
	var qualities: Array[bool] = []
	if quality in ["light", "both"]:
		qualities.append(true)
	if quality in ["full", "both"]:
		qualities.append(false)
	for track_id in selections:
		for light in qualities:
			_run_world(track_id, light)
	if _failures == 0:
		print(
			(
				"[ThemeWorld] PASS cases=%d checks=%d support_probes=%d; camera/device performance not assessed"
				% [_cases, _checks, _support_probes]
			)
		)
	else:
		push_error(
			(
				"[ThemeWorld] FAIL cases=%d failed_checks=%d/%d support_probes=%d"
				% [_cases, _failures, _checks, _support_probes]
			)
		)
	quit(0 if _failures == 0 else 1)


func _check_harbour_dispatch() -> void:
	var world := ObservedWorld.new()
	world.track_id = "sonnenhafen"
	_check(not THEMES.supports("sonnenhafen"), "Sonnenhafen remains outside theme registry")
	var handled: bool = THEMES.build(world, Vector3.ZERO, Basis.IDENTITY, true, false)
	_check(
		not handled and world.recorded.is_empty() and world.decoration_count == 0,
		"Sonnenhafen theme dispatch produces no replacement geometry"
	)
	world.free()


func _run_world(track_id: String, light: bool) -> void:
	_cases += 1
	var label := "%s/%s" % [track_id, "light" if light else "full"]
	var failures_before := _failures
	var probes_before := _support_probes
	var world := ObservedWorld.new()
	root.add_child(world)
	# geometry_only=false is essential: the production ground plane is otherwise omitted.
	world.build(light, track_id, false)
	_check(
		world.track_id == track_id and world.definition.get("id", "") == track_id,
		label + ": real catalog definition selected"
	)
	_check(world.length > 0.0 and world.curve != null, label + ": real course exists")
	_check(world.get_meta("reference_detail_theme", "") == track_id, label + ": theme metadata")
	var sites: Array = world.get_meta("reference_detail_sites", [])
	var detail_count := int(world.get_meta("reference_detail_count", 0))
	var slot_count := 8 if light else 20
	_check(sites.size() > 0 and sites.size() <= slot_count, label + ": accepted site population")
	_check(detail_count > 0 and detail_count <= sites.size() * 80, label + ": bounded detail count")
	_check(world.groups.is_empty(), label + ": instance groups flushed")
	_check(
		world.detail_flushes == 1 and world.detail_begin >= 0,
		label + ": exactly one observable detail batch"
	)
	_check(world.flushed_records.size() <= MAX_RECORDED_PARTS, label + ": recording budget")
	if (
		world.detail_begin < 0
		or world.flushed_records.size() > MAX_RECORDED_PARTS
		or sites.is_empty()
	):
		world.free()
		return
	var parts_by_site: Array = []
	for _site in sites:
		parts_by_site.append([])
	var details: Array[Dictionary] = world.flushed_records.slice(world.detail_begin)
	_check(details.size() == detail_count, label + ": emitted parts match metadata")
	for part in details:
		var closest := -1
		var distance_squared := INF
		var transform: Transform3D = part.transform
		for index in range(sites.size()):
			var delta := _xz(transform.origin - Vector3(sites[index].position)).length_squared()
			if delta < distance_squared:
				closest = index
				distance_squared = delta
		parts_by_site[closest].append(part)
	var road_points: PackedVector3Array = world.curve.get_baked_points()
	_check(road_points.size() > 2, label + ": independent road polyline available")
	var support: Array[Dictionary] = []
	if track_id in GROUND_TRACKS:
		support = _support_geometry(world, label)
	for index in range(sites.size()):
		var site: Dictionary = sites[index]
		var at: Vector3 = site.position
		var radius := float(site.radius)
		var distance := float(site.distance)
		var site_label := "%s site=%d d=%.2f" % [label, index, distance]
		var parts: Array = parts_by_site[index]
		_check(
			parts.size() > 0 and parts.size() <= (80 if radius > 2.0 else 32),
			site_label + ": assembly part budget"
		)
		_check(
			not world.in_gap(distance) and world.ramp_height(distance) <= 0.0,
			site_label + ": outside jump gap and ramp"
		)
		if track_id in ["zauberwald", "bergwelt"]:
			_check(not world._is_bridge(distance), site_label + ": restricted bridge excluded")
		var actual_radius := 0.0
		var foundation: Dictionary = {}
		var minimum_y := INF
		for part in parts:
			var mesh: Mesh = world._shape(str(part.kind))
			var bounds: AABB = mesh.get_aabb()
			var transform: Transform3D = part.transform
			for corner in _corners(bounds):
				var point: Vector3 = transform * corner
				actual_radius = maxf(actual_radius, _xz(point - at).length())
				if point.y < minimum_y:
					minimum_y = point.y
					foundation = {"mesh": mesh, "transform": transform, "bounds": bounds}
		_check(
			actual_radius <= radius + 0.02, site_label + ": transformed mesh footprint fits site"
		)
		if road_points.size() > 2:
			var clearance := _road_distance(at, road_points) - actual_radius
			_check(
				clearance >= ROAD_CLEARANCE - GEOMETRY_TOLERANCE,
				"%s: mesh envelope road clearance %.3f" % [site_label, clearance]
			)
		if track_id in GROUND_TRACKS:
			_check(not foundation.is_empty(), site_label + ": observable foundation")
			if not foundation.is_empty():
				_check_foundation(foundation, support, site_label)
	var case_probes := _support_probes - probes_before
	if track_id in GROUND_TRACKS:
		_check(case_probes >= sites.size() * 3, label + ": contact coverage for accepted sites")
	print(
		(
			(
				"[ThemeWorld] CASE %s accepted=%d unaccepted_slots=%d parts=%d "
				+ "support=%s support_probes=%d failures=%d"
			)
			% [
				label,
				sites.size(),
				slot_count - sites.size(),
				detail_count,
				"geometry_probed" if track_id in GROUND_TRACKS else "NOT_ASSESSED",
				case_probes,
				_failures - failures_before
			]
		)
	)
	world.free()


func _support_geometry(world: ObservedWorld, label: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var triangles := 0
	var plane_count := 0
	# The five ordinary expansion worlds create their large floor as a direct child.
	# Read its generated mesh and transform; do not assume a floor height.
	for child in world.get_children():
		if child is MeshInstance3D and child.mesh is PlaneMesh:
			var plane: PlaneMesh = child.mesh
			if plane.size.x >= 500.0 and plane.size.y >= 500.0:
				var surface: Dictionary = CONTACT.surface(plane, child.transform)
				result.append(surface)
				triangles += int(surface.faces.size() / 3)
				plane_count += 1
	_check(plane_count == 1, label + ": exactly one observable production ground plane")
	# Include existing opaque structural props, but never let the new assembly support itself.
	# This also allows a real platform/bridge beneath a site to satisfy contact.
	var face_cache: Dictionary = {}
	for index in range(world.detail_begin):
		var part: Dictionary = world.flushed_records[index]
		if bool(part.glow) or Color(part.color).a < 0.95:
			continue
		if str(part.kind) not in ["box", "cylinder", "rock", "roof"]:
			continue
		var kind := str(part.kind)
		var mesh: Mesh = world._shape(kind)
		if not face_cache.has(kind):
			face_cache[kind] = mesh.get_faces()
		var faces: PackedVector3Array = face_cache[kind]
		triangles += int(faces.size() / 3)
		if triangles > MAX_SUPPORT_TRIANGLES:
			_check(false, label + ": support triangle budget exceeded; coverage incomplete")
			return result
		var transform: Transform3D = part.transform
		result.append(
			{"faces": faces, "transform": transform, "bounds": transform * mesh.get_aabb()}
		)
	return result


func _check_foundation(foundation: Dictionary, surfaces: Array[Dictionary], label: String) -> void:
	var mesh: Mesh = foundation.mesh
	var transform: Transform3D = foundation.transform
	var result: Dictionary = CONTACT.assess(mesh, transform, surfaces, CONTACT_TOLERANCE)
	_support_probes += int(result.probe_count)
	_check(result.coverage == "complete", label + ": contact coverage " + str(result.reason))
	if result.coverage != "complete":
		return
	var points: Array = result.points
	var gaps: Array = result.gaps
	for index in range(points.size()):
		var point: Vector3 = points[index]
		var gap: float = float(gaps[index])
		_check(
			is_finite(gap) and absf(gap) <= CONTACT_TOLERANCE,
			(
				"%s: %s underside y=%.3f at (%.2f, %.2f) has support gap %.3fm"
				% [label, str(result.method), point.y, point.x, point.z, gap]
			)
		)
	_check(int(result.probe_count) >= 3, label + ": at least three actual foundation probes")


func _road_distance(at: Vector3, points: PackedVector3Array) -> float:
	var nearest := INF
	var target := _xz(at)
	for index in range(points.size()):
		var a := _xz(points[index])
		var delta := _xz(points[(index + 1) % points.size()]) - a
		var fraction := clampf(
			(target - a).dot(delta) / maxf(delta.length_squared(), 0.000001), 0.0, 1.0
		)
		nearest = minf(nearest, target.distance_to(a + delta * fraction))
	return nearest


func _corners(bounds: AABB) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for index in range(8):
		result.append(
			(
				bounds.position
				+ (
					bounds.size
					* Vector3(float(index & 1), float((index >> 1) & 1), float((index >> 2) & 1))
				)
			)
		)
	return result


func _xz(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[ThemeWorld] " + message)
