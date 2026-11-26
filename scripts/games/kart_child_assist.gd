extends RefCounted
## Driving help for the child's own kart on Entdecken (the beginner level that
## promises "sanfte Lenkhilfe am Fahrbahnrand"). Pure function of the real
## driving state; movement itself stays physical.


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
