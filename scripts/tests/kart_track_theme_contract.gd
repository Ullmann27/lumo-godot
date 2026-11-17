extends SceneTree
## Run through tools/test_track_theme_contract.py; no game scene or autoloads.
const THEMES = preload("res://scripts/games/track_themes/track_theme_registry.gd")
const DETAIL = preload("res://scripts/games/kart_track_detail.gd")
const CATALOG = preload("res://scripts/games/kart_tracks.gd")

const IDS: Array[String] = [
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
	"learning_lab"
]


class RecordingWorld:
	extends RefCounted
	var track_id: String = ""
	var low_detail: bool = false
	var length: float = TAU * 1000.0
	var decoration_count: int = 0
	var records: Array[Dictionary] = []
	var block_reason: String = ""

	func _prop(
		kind: String,
		at: Vector3,
		size: Vector3,
		color: Color,
		basis: Basis = Basis.IDENTITY,
		glow: bool = false
	) -> void:
		records.append(
			{"kind": kind, "at": at, "size": size, "color": color, "basis": basis, "glow": glow}
		)
		decoration_count += 1

	func position_at(distance: float, lateral: float = 0.0) -> Vector3:
		var angle := distance / length * TAU
		return Vector3(cos(angle), 0.0, sin(angle)) * (1000.0 + lateral)

	func frame(distance: float) -> Basis:
		return Basis(Vector3.UP, distance / length * TAU)

	func in_gap(_distance: float) -> bool:
		return block_reason == "gap"

	func ramp_height(_distance: float) -> float:
		return 1.0 if block_reason == "ramp" else 0.0

	func _is_bridge(_distance: float) -> bool:
		return block_reason == "bridge"

	func _near_road(at: Vector3, radius: float) -> bool:
		return block_reason == "occupied" or absf(Vector2(at.x, at.z).length() - 1000.0) < radius

	func _ground_height(_x: float, _z: float) -> float:
		return -2.0 if block_reason == "submerged" else 0.0


var failures: Array[String] = []
var assembly_cases: int = 0
var placement_cases: int = 0
var placement_guards: int = 0
var widest: float = 0.0
var legacy_script: GDScript
var factory_script: GDScript


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _geometry_key(records: Array[Dictionary]) -> int:
	var geometry: Array = []
	for record in records:
		geometry.append([record.kind, record.at, record.size, record.basis])
	return hash(geometry)


func _check_blocked(track: String, reason: String, light: bool = false) -> void:
	var blocked := RecordingWorld.new()
	blocked.track_id = track
	blocked.low_detail = light
	blocked.block_reason = reason
	DETAIL.build(blocked)
	var label := "%s track=%s low=%s" % [reason, track, light]
	_check(blocked.records.is_empty(), "Placement guard ignored: " + label)
	_check(
		blocked.get_meta("reference_detail_sites", []).is_empty(),
		"Blocked sites retained: " + label
	)
	_check(blocked.get_meta("reference_detail_count", -1) == 0, "Blocked detail count: " + label)
	placement_guards += 1


func _run() -> void:
	# The runner supplies these fixtures inside its temporary project. Loading
	# them only here keeps normal project import independent of test fixtures.
	legacy_script = load("res://scripts/tests/legacy_track_detail.gd")
	factory_script = load("res://scripts/tests/runtime_mesh_factory.gd")
	if legacy_script == null or factory_script == null:
		printerr("Run this contract through tools/test_track_theme_contract.py")
		quit(2)
		return
	var high_counts: Dictionary = {}
	var low_counts: Dictionary = {}
	var hero_geometry: Dictionary = {}
	var catalog_ids: Array[String] = CATALOG.IDS.duplicate()
	catalog_ids.erase("sonnenhafen")
	var expected_ids: Array[String] = IDS.duplicate()
	var registered_ids: Array[String] = THEMES.IDS.duplicate()
	catalog_ids.sort()
	expected_ids.sort()
	registered_ids.sort()
	_check(
		catalog_ids == expected_ids and registered_ids == expected_ids,
		"Theme registry must cover exactly the eleven existing non-Sonnenhafen tracks"
	)
	for track: String in IDS:
		_check(THEMES.supports(track), "Missing track: " + track)
		for light: bool in [false, true]:
			var factory = factory_script.new()
			factory.low_detail = light
			for variant in range(3):
				var large := variant == 0
				var marker := variant == 1
				var radius := 4.3 if large else 1.8
				var budget := 80 if large else 32
				for yaw: float in [0.0, 0.73, 1.57, 3.14]:
					var at := Vector3(13.0, 7.0, -21.0)
					var basis := Basis(Vector3.UP, yaw)
					var world := RecordingWorld.new()
					world.track_id = track
					world.low_detail = light
					_check(THEMES.build(world, at, basis, large, marker), "Not handled: " + track)
					var label := "%s low=%s variant=%d yaw=%.2f" % [track, light, variant, yaw]
					_check(world.records.size() >= 3, "Missing visible structure: " + label)
					_check(world.records.size() <= budget, "Instance budget exceeded: " + label)
					for record: Dictionary in world.records:
						_check(
							(
								record.size.is_finite()
								and record.size.x > 0.0
								and record.size.y > 0.0
								and record.size.z > 0.0
							),
							"Invalid scale: " + label
						)
						_check(
							record.at.is_finite() and record.basis.is_finite(),
							"Invalid transform: " + label
						)
						_check(
							record.size.length() <= 32.0,
							"Unexpected background-size prop: " + label
						)
						_check(
							absf(record.basis.determinant() - 1.0) < 0.001,
							"Non-unit orientation: " + label
						)
						var mesh: Mesh = factory._shape(record.kind)
						var bounds: AABB = mesh.get_aabb()
						_check(
							(
								bounds.position.is_finite()
								and bounds.size.is_finite()
								and bounds.size.x > 0.0001
								and bounds.size.z > 0.0001
							),
							"Missing real mesh bounds for " + str(record.kind) + ": " + label
						)
						var transform: Transform3D = Transform3D(
							record.basis.scaled_local(record.size), record.at
						)
						for corner in range(8):
							var local: Vector3 = (
								basis.inverse() * (transform * bounds.get_endpoint(corner) - at)
							)
							var extent := Vector2(local.x, local.z).length()
							widest = maxf(widest, extent)
							_check(
								extent <= radius + 0.001,
								"Footprint %.3f exceeds %.1f: %s" % [extent, radius, label]
							)
					var repeat := RecordingWorld.new()
					repeat.track_id = track
					repeat.low_detail = light
					THEMES.build(repeat, at, basis, large, marker)
					_check(world.records == repeat.records, "Non-deterministic assembly: " + label)
					if yaw == 0.0:
						var key := track + ":" + str(variant)
						if not light:
							high_counts[key] = world.records.size()
							if large:
								var signature := _geometry_key(world.records)
								_check(
									not hero_geometry.has(signature),
									"Only recolored hero architecture: " + track
								)
								hero_geometry[signature] = track
						else:
							low_counts[key] = world.records.size()
							_check(
								world.records.size() <= int(high_counts[key]),
								"Low detail adds geometry: " + label
							)
					assembly_cases += 1
			var placed := RecordingWorld.new()
			placed.track_id = track
			placed.low_detail = light
			DETAIL.build(placed)
			_check(
				placed.get_meta("reference_detail_count", 0) > 20, "No detail integration: " + track
			)
			_check(
				placed.get_meta("reference_detail_count", 0) < 1800,
				"World detail budget exceeded: " + track
			)
			_check(
				placed.get_meta("reference_detail_theme", "") == track,
				"Missing theme metadata: " + track
			)
			for site: Dictionary in placed.get_meta("reference_detail_sites", []):
				_check(
					not placed._near_road(site.position, 8.5 + float(site.radius)),
					"Unsafe accepted site: " + track
				)
			placement_cases += 1
		print(
			"[TrackThemeContract] DATA ",
			JSON.stringify(
				{
					"track": track,
					"full_parts":
					[
						high_counts[track + ":0"],
						high_counts[track + ":1"],
						high_counts[track + ":2"]
					],
					"low_parts":
					[low_counts[track + ":0"], low_counts[track + ":1"], low_counts[track + ":2"]]
				}
			)
		)
	for track: String in ["sonnenhafen", "unregistered_track"]:
		_check(not THEMES.supports(track), "Unexpected theme override: " + track)
		var untouched := RecordingWorld.new()
		untouched.track_id = track
		_check(
			not THEMES.build(untouched, Vector3.ZERO, Basis.IDENTITY, true, false),
			"Unexpected build: " + track
		)
		_check(untouched.records.is_empty(), "Unsupported track emits geometry: " + track)
		for light: bool in [false, true]:
			var previous := RecordingWorld.new()
			previous.track_id = track
			previous.low_detail = light
			legacy_script.build(previous)
			var current := RecordingWorld.new()
			current.track_id = track
			current.low_detail = light
			current.set_meta("reference_detail_theme", "zauberwald")
			DETAIL.build(current)
			_check(previous.records == current.records, "Legacy geometry changed: " + track)
			_check(
				not current.has_meta("reference_detail_theme"),
				"Stale theme after track switch: " + track
			)
	for reason: String in ["gap", "ramp", "occupied"]:
		_check_blocked("zauberwald", reason)
	for light: bool in [false, true]:
		for track: String in ["sonnenhafen", "zauberwald", "bergwelt"]:
			_check_blocked(track, "bridge", light)
		for track: String in ["sonnenhafen", "zauberwald", "holo_city"]:
			_check_blocked(track, "submerged", light)
	if not failures.is_empty():
		for failure in failures.slice(0, 40):
			printerr("[TrackThemeContract] FAIL ", failure)
		printerr("[TrackThemeContract] failures=", failures.size())
		quit(1)
		return
	print(
		"[TrackThemeContract] PASS assemblies=",
		assembly_cases,
		" placement_cases=",
		placement_cases,
		" distinct_hero_geometries=",
		hero_geometry.size(),
		" legacy_cases=4 placement_guards=",
		placement_guards,
		" widest_aabb_radius=",
		snappedf(widest, 0.001)
	)
	quit(0)
