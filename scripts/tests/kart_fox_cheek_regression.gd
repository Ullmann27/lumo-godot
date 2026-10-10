extends SceneTree
## A cream lower face must stay continuous around each cheek, including the low-detail mesh.
## Sample the first visible opaque surface, not the presence of a particular helper or node.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const HEIGHTS := [-0.12, -0.16, -0.20, -0.24]
const ANGLES := [45.0, 60.0, 75.0, 90.0]

var failures: Array[String] = []
var checks: int = 0
var samples: Array[Dictionary] = []


class AuthoredDriver:
	extends LumoRaceKart

	func _make_far_mesh() -> void:
		pass

	func _merge_static(_parent: Node3D) -> void:
		pass


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("[FoxCheek] FAIL: ", label)


func _surfaces(node: Node3D, face: Node3D, low_detail: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child in node.get_children():
		if child.has_meta("near_only"):
			continue
		if child is MeshInstance3D:
			var geometry: Mesh = child.mesh
			if low_detail and geometry.has_meta("far_geometry"):
				geometry = geometry.get_meta("far_geometry") as Mesh
			var frame: Transform3D = face.global_transform.affine_inverse() * child.global_transform
			for surface in range(geometry.get_surface_count()):
				var arrays: Array = geometry.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var colors: PackedColorArray = (
					arrays[Mesh.ARRAY_COLOR]
					if arrays[Mesh.ARRAY_COLOR] != null
					else PackedColorArray()
				)
				var indices: PackedInt32Array = (
					arrays[Mesh.ARRAY_INDEX]
					if arrays[Mesh.ARRAY_INDEX] != null
					else PackedInt32Array()
				)
				if indices.is_empty():
					for index in range(points.size()):
						indices.append(index)
				var finish: StandardMaterial3D = child.material_override
				if colors.size() != points.size():
					colors.resize(points.size())
					colors.fill(Color.WHITE)
				for index in range(points.size()):
					points[index] = frame * points[index]
					colors[index] *= finish.albedo_color
				result.append({"vertices": points, "colors": colors, "indices": indices})
		elif child is Node3D:
			result.append_array(_surfaces(child, face, low_detail))
	return result


func _first_surface(surfaces: Array[Dictionary], origin: Vector3, direction: Vector3) -> Dictionary:
	var nearest: float = INF
	var result: Dictionary = {}
	for surface in surfaces:
		var points: PackedVector3Array = surface.vertices
		var colors: PackedColorArray = surface.colors
		var indices: PackedInt32Array = surface.indices
		for index in range(0, indices.size(), 3):
			var a: int = indices[index]
			var b: int = indices[index + 1]
			var c: int = indices[index + 2]
			var edge_a: Vector3 = points[b] - points[a]
			var edge_b: Vector3 = points[c] - points[a]
			var perpendicular: Vector3 = direction.cross(edge_b)
			var determinant: float = edge_a.dot(perpendicular)
			if absf(determinant) < 0.00000001:
				continue
			var inverse: float = 1.0 / determinant
			var offset: Vector3 = origin - points[a]
			var weight_b: float = offset.dot(perpendicular) * inverse
			if weight_b < 0.0 or weight_b > 1.0:
				continue
			var cross_offset: Vector3 = offset.cross(edge_a)
			var weight_c: float = direction.dot(cross_offset) * inverse
			if weight_c < 0.0 or weight_b + weight_c > 1.0:
				continue
			var distance: float = edge_b.dot(cross_offset) * inverse
			if distance <= 0.0 or distance >= nearest:
				continue
			nearest = distance
			var pigment: Color = colors[a] * (1.0 - weight_b - weight_c)
			pigment += colors[b] * weight_b + colors[c] * weight_c
			result = {"color": pigment, "distance": distance}
	return result


func _is_cream(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	var color: Color = hit.color
	return color.r > 0.72 and color.g > 0.72 and color.b > 0.65 and color.r / color.g < 1.15


func _is_orange(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	var color: Color = hit.color
	return color.r > color.g * 1.35 and color.g > color.b * 1.25


func _run() -> void:
	var fox := AuthoredDriver.new()
	fox.configure("fox", Color("1d4fa0"), "comet")
	root.add_child(fox)
	fox.set_process(false)
	for low_detail in [false, true]:
		var surfaces: Array[Dictionary] = _surfaces(fox.head, fox.head, low_detail)
		var detail: String = "far" if low_detail else "near"
		for height in HEIGHTS:
			for angle in ANGLES:
				for side in [-1.0, 1.0]:
					var yaw: float = deg_to_rad(angle * side)
					var outward := Vector3(sin(yaw), 0.0, -cos(yaw))
					var hit: Dictionary = _first_surface(
						surfaces, Vector3(0.0, height, 0.0) + outward * 1.5, -outward
					)
					var label := (
						"%s cheek y=%.2f yaw=%.0f has continuous cream fur"
						% [detail, height, angle * side]
					)
					_check(_is_cream(hit), label)
					(
						samples
						. append(
							{
								"detail": detail,
								"height": height,
								"yaw": angle * side,
								"color": str(hit.get("color", "missing")),
								"radius": 1.5 - float(hit.get("distance", 1.5)),
							}
						)
					)
		_check(
			_is_orange(_first_surface(surfaces, Vector3(0, 0.16, -1.5), Vector3.BACK)),
			detail + " forehead keeps the original orange identity"
		)
		_check(
			_is_orange(_first_surface(surfaces, Vector3(0, -0.16, 1.5), Vector3.FORWARD)),
			detail + " back of the head remains orange"
		)
	fox.free()
	var out_dir: String = "res://exports/fox-cheek-review"
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		out_dir = arguments[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open(out_dir.path_join("cheek-surface-evidence.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify({"checks": checks, "failures": failures, "samples": samples}, "  ")
	)
	file.close()
	print("[FoxCheek] checks=", checks, " failures=", failures.size())
	if failures.is_empty():
		print("[FoxCheek] PASS: continuous cream cheeks in both mesh detail levels")
	quit(0 if failures.is_empty() else 1)
