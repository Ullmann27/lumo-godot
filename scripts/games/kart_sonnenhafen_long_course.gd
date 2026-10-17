extends RefCounted
## MEILENSTEIN B2 – original long-form Sonnenhafen Grand Prix route.
## 23 intentionally authored control points, not a globally stretched copy.
## Targets ~1.85 km after the unchanged Catmull-style Bezier smoothing.
## Scenic, terrain and user-facing approval remain separate test gates.
static func points() -> PackedVector3Array:
	return PackedVector3Array([
		# 1 – Start / inner harbour, retained near the original racing venue.
		Vector3(0.0, 2.0, 72.0),
		Vector3(63.8, 3.0, 98.7),
		Vector3(118.3, 6.0, 139.3),
		# 2 – Dawn Cliffs: long ascending sweeps to the outer coast.
		Vector3(192.6, 9.0, 191.5),
		Vector3(261.0, 14.0, 174.1),
		Vector3(312.0, 16.0, 118.4),
		# 3 – Lighthouse approach and east viaduct.
		Vector3(301.6, 20.0, 30.2),
		Vector3(297.0, 19.0, -57.9),
		Vector3(266.8, 17.0, -156.5),
		# 4 – Sheltered open-water bends; broad radius, no 180-degree corner.
		Vector3(213.4, 15.0, -225.0),
		Vector3(125.3, 12.0, -257.4),
		Vector3(26.7, 8.0, -266.7),
		# 5 – Southern headland and cliff ascent.
		Vector3(-65.0, 6.0, -284.1),
		Vector3(-161.2, 10.0, -257.4),
		Vector3(-232.0, 15.0, -213.4),
		# 6 – West mountain viaduct and scenic overlook.
		Vector3(-294.6, 18.0, -132.2),
		Vector3(-330.6, 18.0, -27.8),
		Vector3(-303.9, 14.0, 73.2),
		# 7 – Forest shoulder: descending S-curves.
		Vector3(-251.7, 13.0, 149.7),
		Vector3(-176.3, 10.0, 193.8),
		Vector3(-111.4, 7.0, 169.4),
		# 8 – Back to the Grand Prix boulevard for the finish.
		Vector3(-67.3, 4.0, 124.2),
		Vector3(-23.2, 2.0, 80.1)
	])

static func target_length() -> float:
	return 1850.0
