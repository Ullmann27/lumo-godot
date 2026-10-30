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
var active: bool = false
var progress: float = 0.0
var speed: float = 0.0
var lateral: float = 0.0
var entry_progress: float = 0.0
var layout: Dictionary = {}
var failed: bool = false


static func radius_of(data: Dictionary) -> float:
	return float(data.get("radius", RADIUS))


## Length of the riding line through the loop for this layout.
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


func enter(data: Dictionary, momentum: float, cumulative: float) -> void:
	layout = data.duplicate()
	progress = 0
	speed = momentum
	entry_progress = cumulative
	lateral = 0
	failed = false
	active = true


func advance(world, delta: float, steering: float, braking: float, throttle: bool) -> Transform3D:
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
	progress = minf(1, progress + speed * delta / path_length(layout))
	basis = frame_at(world, layout, progress)
	if progress >= 1:
		active = false
	return Transform3D(basis, point(world, layout, progress, lateral) + basis.y * 0.045)


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
