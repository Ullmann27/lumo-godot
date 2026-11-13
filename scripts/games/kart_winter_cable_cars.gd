extends MultiMeshInstance3D
## Four upright moving cabins in one instanced draw, sharing one immutable mesh.

const FRAME := Color("293d51")
const BODY := Color("c95c55")
const GLASS := Color("6399bc")
const SNOW := Color("e2eff6")
const PHASES: Array[float] = [0.15, 0.65, 0.40, 0.90]
const SPEED := 2.8
static var _shared_mesh: ArrayMesh
var cabin_transforms: Array[Transform3D] = []
var _low := Vector3.ZERO
var _high := Vector3.ZERO
var _cross := Vector3.RIGHT
var _orientation := Basis.IDENTITY
var _phase := 0.0
var _span := 1.0
var _owner_ref: WeakRef
var _has_pause := false
var _has_reduced_motion := false


func configure(low: Vector3, high: Vector3, world: Node3D) -> void:
	name = "WinterCableCars"
	_low = low
	_high = high
	_span = maxf(low.distance_to(high), 1.0)
	var direction := (high - low).normalized()
	_cross = direction.cross(Vector3.UP).normalized()
	_orientation = Basis.looking_at(Vector3(direction.x, 0, direction.z).normalized())
	var host := world.get_parent()
	if host != null:
		_owner_ref = weakref(host)
		for property in host.get_property_list():
			_has_pause = _has_pause or property.name == "paused"
			_has_reduced_motion = _has_reduced_motion or property.name == "reduced_motion"
	if _shared_mesh == null:
		_shared_mesh = _create_mesh()
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = _shared_mesh
	instances.instance_count = 4
	multimesh = instances
	cabin_transforms.resize(instances.instance_count)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.48
	material.metallic = 0.08
	material_override = material
	custom_aabb = AABB(low, Vector3.ZERO).expand(high).grow(7.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_update_transforms()


func _process(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta) or not is_visible_in_tree():
		return
	if _owner_ref != null:
		var host: Object = _owner_ref.get_ref()
		if (
			host != null
			and (
				(_has_pause and bool(host.get("paused")))
				or (_has_reduced_motion and bool(host.get("reduced_motion")))
			)
		):
			return
	_phase = fposmod(_phase + delta * SPEED / _span, 1.0)
	_update_transforms()


func _update_transforms() -> void:
	for index in range(PHASES.size()):
		var along := fposmod(_phase + PHASES[index], 1.0)
		var outbound := index < 2
		var t := along if outbound else 1.0 - along
		var side := -1.0 if outbound else 1.0
		var at := _low.lerp(_high, t) - Vector3.UP * sin(t * PI) * 2.2
		at += _cross * side * 1.9
		cabin_transforms[index] = Transform3D(_orientation, at)
		multimesh.set_instance_transform(index, cabin_transforms[index])


static func _create_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(surface, Vector3(0, -0.7, 0), Vector3(0.10, 1.4, 0.10), FRAME)
	_box(surface, Vector3(0, -2.6, 0), Vector3(2.0, 2.05, 2.7), FRAME)
	_box(surface, Vector3(0, -3.15, 0), Vector3(2.13, 0.95, 2.83), BODY)
	_box(surface, Vector3(0, -1.51, 0), Vector3(2.20, 0.16, 2.95), SNOW)
	for side in [-1.0, 1.0]:
		_box(surface, Vector3(side * 1.015, -2.2, 0), Vector3(0.04, 0.93, 2.30), GLASS)
		_box(surface, Vector3(0, -2.2, side * 1.37), Vector3(1.61, 0.93, 0.04), GLASS)
	return surface.commit()


static func _box(surface: SurfaceTool, at: Vector3, size: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		surface.set_color(color)
		surface.set_normal(normals[index])
		surface.add_vertex(at + vertices[index])
