extends RefCounted
## Touch response for the child's kart and extra roadside assistance on Entdecken.
## Both only shape steering input; movement itself stays physical.


## Small thumb corrections on a touch display should not throw the kart into
## the rail at speed. Preserve full left/right travel and direct expert input.
static func touch_axis(axis: float, speed: float, difficulty: String) -> float:
	if difficulty == "pro":
		return axis
	var deflection: float = clampf(inverse_lerp(0.12, 1.0, absf(axis)), 0.0, 1.0)
	var pace: float = smoothstep(12.0, 35.0, absf(speed))
	var response: float
	if difficulty == "gemuetlich":
		response = lerpf(0.58, 0.30, pace)
	else:
		response = lerpf(0.82, 0.60, pace)
	return signf(axis) * lerpf(deflection * deflection, deflection, response)


## Steering help at the road edge, for the child's kart: it grows
## smoothly from 27 % to 43 % of the road width, turns the nose back along the
## road and pushes harder the faster the kart drifts towards the rail. A child
## already steering away from the edge is never overruled.
## [param correction] road heading minus kart heading (rad), [param sideways]
## lateral velocity in road-right direction (m/s).
static func edge_assist(
	axis: float, lane: float, road_width: float, correction: float, sideways: float
) -> float:
	var side: float = signf(lane)
	var weight: float = smoothstep(road_width * 0.27, road_width * 0.43, absf(lane))
	if weight <= 0.0 or side == 0.0:
		return axis
	var toward_rail: float = clampf(sideways * side / 6.0, 0.0, 1.0)
	var assisted: float = clampf(
		axis - correction * 0.8 - side * (0.30 + 0.6 * toward_rail), -1.0, 1.0
	)
	if axis * side < 0.0 and absf(axis) > absf(assisted):
		assisted = axis
	return lerpf(axis, assisted, weight)
