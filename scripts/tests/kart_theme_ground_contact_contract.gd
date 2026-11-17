extends SceneTree
## Calibrate the contact oracle using real production mesh geometry.

const CONTACT = preload("res://scripts/tests/helpers/kart_theme_ground_contact.gd")
const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")

var _cases: int = 0
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(20, 20)
	var floor_surfaces: Array[Dictionary] = []
	floor_surfaces.append(CONTACT.surface(plane))
	var rock: ArrayMesh = SHAPES.rock()
	var rock_pose: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0))
	var result: Dictionary = _case(
		"production rock on plane", rock, rock_pose, floor_surfaces, true, "planar_lower_vertices"
	)
	_check_gaps(result, 0.0, "production rock on plane")
	rock_pose.origin.y = 1.5
	result = _case(
		"production rock raised 1m", rock, rock_pose, floor_surfaces, false, "planar_lower_vertices"
	)
	_check_gaps(result, 1.0, "production rock raised 1m")
	rock_pose.origin.y = 0.5
	var no_surfaces: Array[Dictionary] = []
	result = _case(
		"production rock without surface",
		rock,
		rock_pose,
		no_surfaces,
		false,
		"planar_lower_vertices"
	)
	for gap in result.gaps:
		_check(not is_finite(float(gap)), "missing surface has no invented gap")
	var overhead: BoxMesh = BoxMesh.new()
	overhead.size = Vector3(5, 2, 5)
	var overhead_surfaces: Array[Dictionary] = []
	overhead_surfaces.append(
		CONTACT.surface(overhead, Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)))
	)
	result = _case(
		"overhead box underside is not support",
		rock,
		rock_pose,
		overhead_surfaces,
		false,
		"planar_lower_vertices"
	)
	_check_gaps(result, -2.0, "overhead box uses top at y=2")
	var scaled_pose: Transform3D = Transform3D(
		Basis(Vector3.UP, 0.41).scaled_local(Vector3(0.7, 0.4, 1.1)), Vector3(0, 0.2, 0)
	)
	result = _case(
		"production rock rotated and scaled",
		rock,
		scaled_pose,
		floor_surfaces,
		true,
		"planar_lower_vertices"
	)
	_check_gaps(result, 0.0, "rotated and scaled rock")
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(2, 0.4, 2)
	_case(
		"closed box on plane",
		box,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)),
		floor_surfaces,
		true,
		"planar_lower_vertices"
	)
	_case(
		"closed box raised 1m",
		box,
		Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 0)),
		floor_surfaces,
		false,
		"planar_lower_vertices"
	)
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.8
	cylinder.bottom_radius = 0.8
	cylinder.height = 0.4
	cylinder.radial_segments = 16
	_case(
		"closed cylinder on plane",
		cylinder,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)),
		floor_surfaces,
		true,
		"planar_lower_vertices"
	)
	_case(
		"closed cylinder raised 1m",
		cylinder,
		Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 0)),
		floor_surfaces,
		false,
		"planar_lower_vertices"
	)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	sphere.radial_segments = 16
	sphere.rings = 12
	_case(
		"curved closed sphere on plane",
		sphere,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)),
		floor_surfaces,
		true,
		"underside_rays"
	)
	_case(
		"curved closed sphere raised 1m",
		sphere,
		Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0)),
		floor_surfaces,
		false,
		"underside_rays"
	)
	_cases += 1
	result = CONTACT.assess(
		rock, Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 0.7, 0)), floor_surfaces
	)
	_check(
		result.coverage == "incomplete" and not result.supported,
		"tilted open rock must not use closed-body underside rays"
	)
	_check(
		result.reason == "open_mesh_without_planar_lower_contact",
		"tilted open rock coverage reason"
	)
	if _failures == 0:
		print("[ThemeGroundContact] PASS cases=%d checks=%d" % [_cases, _checks])
	else:
		push_error(
			"[ThemeGroundContact] FAIL cases=%d failed_checks=%d/%d" % [_cases, _failures, _checks]
		)
	quit(0 if _failures == 0 else 1)


func _case(
	label: String,
	mesh: Mesh,
	transform: Transform3D,
	supports: Array[Dictionary],
	expected_supported: bool,
	expected_method: String
) -> Dictionary:
	_cases += 1
	var result: Dictionary = CONTACT.assess(mesh, transform, supports)
	_check(result.coverage == "complete", label + ": coverage; reason=" + str(result.reason))
	_check(result.supported == expected_supported, label + ": expected contact classification")
	_check(result.method == expected_method, label + ": observation method")
	_check(int(result.probe_count) >= 3, label + ": at least three observed points")
	_check(
		(
			result.points.size() == result.gaps.size()
			and result.points.size() == result.support_heights.size()
		),
		label + ": structured observations align"
	)
	return result


func _check_gaps(result: Dictionary, expected: float, label: String) -> void:
	for gap in result.gaps:
		_check(
			is_finite(float(gap)) and absf(float(gap) - expected) < 0.001,
			label + ": signed measured gap"
		)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[ThemeGroundContact] " + message)
