extends RefCounted
## Optional arcade loop. Rendering and contact use the same continuous 3D path.
## Gravity slows the ascent; low momentum or heavy braking returns to the entry road.
## A layout may set "radius", "lateral_limit", "fail_lane" (see Sonnenhafen stunt
## sequence); without them every track keeps the original 6.5 m side loop.
const RADIUS: float = 6.5
const ADVANCE: float = 7.0
const LENGTH: float = TAU * RADIUS + ADVANCE * 0.2
const GRAVITY: float = 6.0
const LATERAL_LIMIT: float = 0.7
const ARC_SEGMENTS: int = 256
var active: bool = false
var progress: float = 0.0
var speed: float = 0.0
var lateral: float = 0.0
var entry_progress: float = 0.0
var layout: Dictionary = {}
var failed: bool = false
var _arc_lengths: PackedFloat32Array = PackedFloat32Array()
var _distance_along: float = 0.0


static func radius_of(data: Dictionary) -> float:
	return float(data.get("radius", RADIUS))


## Approximate design length only; driving uses the measured distance table.
static func path_length(data: Dictionary) -> float:
	return TAU * radius_of(data) + ADVANCE * 0.2


static func point(world, data: Dictionary, u: float, offset: float = 0.0) -> Vector3:
	var basis: Basis = world.frame(float(data.start))
	var advance: float = u * ADVANCE
	var base: Vector3 = world.position_at(float(data.start) + advance, float(data.lane) + offset)
	var theta: float = clampf(u, 0, 1) * TAU
	var radius: float = radius_of(data)
	return base + basis.y * radius * (1.0 - cos(theta)) - basis.z * radius * sin(theta)


static func frame_at(world, data: Dictionary, u: float) -> Basis:
	var a: float = maxf(0, u - 0.001)
	var b: float = minf(1, u + 0.001)
	var forward: Vector3 = (point(world, data, b) - point(world, data, a)).normalized()
	var right: Vector3 = world.frame(float(data.start)).x
	var up: Vector3 = right.cross(forward).normalized()
	right = forward.cross(up).normalized()
	return Basis(right, up, -forward).orthonormalized()


func enter(
	data: Dictionary,
	momentum: float,
	cumulative: float,
	lane_offset: float = 0.0,
	entry_offset: float = 0.0
) -> void:
	layout = data.duplicate()
	progress = 0
	speed = momentum
	entry_progress = cumulative
	lateral = clampf(
		lane_offset,
		-float(data.get("lateral_limit", LATERAL_LIMIT)),
		float(data.get("lateral_limit", LATERAL_LIMIT))
	)
	_arc_lengths = PackedFloat32Array()
	_distance_along = maxf(0.0, entry_offset)
	failed = false
	active = true


func advance(world, delta: float, steering: float, braking: float, throttle: bool) -> Transform3D:
	# The circle advances along a curved road as well. Uniform angle steps are
	# therefore not uniform metres (the previous approximation varied by 20%).
	# Build one distance table at entry and invert it without allocations per tick.
	if _arc_lengths.is_empty():
		_arc_lengths.resize(ARC_SEGMENTS + 1)
		_arc_lengths[0] = 0.0
		var previous: Vector3 = point(world, layout, 0.0)
		for index in range(1, ARC_SEGMENTS + 1):
			var current: Vector3 = point(world, layout, float(index) / ARC_SEGMENTS)
			_arc_lengths[index] = _arc_lengths[index - 1] + previous.distance_to(current)
			previous = current
		progress = _progress_at_distance(_distance_along)
	var basis := frame_at(world, layout, progress)
	var slope: float = (-basis.z).y
	speed += (-GRAVITY * slope - braking * 13.0 + (0.9 if throttle else -0.2)) * delta
	var limit: float = float(layout.get("lateral_limit", LATERAL_LIMIT))
	lateral = clampf(lateral + steering * delta * 1.5, -limit, limit)
	if speed < 4:
		failed = true
		active = false
		return world.reset_transform(
			float(layout.start), float(layout.get("fail_lane", layout.lane))
		)
	_distance_along = minf(_arc_lengths[ARC_SEGMENTS], _distance_along + speed * delta)
	progress = _progress_at_distance(_distance_along)
	basis = frame_at(world, layout, progress)
	if progress >= 1:
		active = false
	return Transform3D(basis, point(world, layout, progress, lateral) + basis.y * 0.045)


func _progress_at_distance(metres: float) -> float:
	if metres >= _arc_lengths[ARC_SEGMENTS]:
		return 1.0
	var low: int = 0
	var high: int = ARC_SEGMENTS
	while high - low > 1:
		var middle: int = (low + high) / 2
		if _arc_lengths[middle] <= metres:
			low = middle
		else:
			high = middle
	var span: float = _arc_lengths[high] - _arc_lengths[low]
	return (float(low) + (metres - _arc_lengths[low]) / maxf(span, 0.0001)) / ARC_SEGMENTS


static func build(world, data: Dictionary, color: Color) -> void:
	for i in range(96):
		var u: float = (i + 0.5) / 96.0
		var basis := frame_at(world, data, u)
		var center := point(world, data, u)
		var a := point(world, data, float(i) / 96)
		var b := point(world, data, float(i + 1) / 96)
		world._prop(
			"box",
			center - basis.y * 0.12,
			Vector3(2.6, 0.24, a.distance_to(b) + 0.07),
			Color("33466c"),
			basis
		)
		for side in [-1.0, 1.0]:
			world._prop(
				"box",
				center + basis.x * side * 1.35 + basis.y * 0.12,
				Vector3(0.14, 0.32, a.distance_to(b) + 0.08),
				color,
				basis,
				true
			)
	var at: Vector3 = world.position_at(float(data.start) - 7, 7.2)
	var basis: Basis = world.frame(float(data.start))
	world._prop("box", at + Vector3.UP * 2.2, Vector3(3.1, 1.4, 0.1), Color("17354e"), basis)
	world._sign(at + Vector3.UP * 2.2 + basis.z * 0.1, basis, "LOOP RECHTS\nSchwung holen!", 0.012)
