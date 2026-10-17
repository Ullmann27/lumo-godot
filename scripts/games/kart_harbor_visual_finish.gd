extends RefCounted
## Strictly visual Sonnenhafen berth finish. Reuses the original MultiMesh
## prop batches: no CollisionObject3D, translucent decals, custom shaders,
## lights, per-frame updates or changes to crane/trolley node hierarchy.
## Coordinates are the same local berth frame used by kart_harbor_crane.gd.
const SHADOW := Color("53616c")
const JOINT := Color("8f9290")
const RIBS_PER_FACE: int = 6


static func _p(frame: Transform3D, f: float, y: float, s: float) -> Vector3:
	return frame.origin + frame.basis.z * f + Vector3.UP * y + frame.basis.x * s


static func decorate(world, frame: Transform3D, detail: bool, palette: Array[Color]) -> Dictionary:
	var contacts: int = 0
	var seams: int = 0
	var ribs: int = 0

	# Pier top is y=0.05 in the crane's local berth coordinates.
	# Opaque plates only extend 0.2m outside each foundation and container
	# footprint; their centers stay 0.068m above that deck. No transparency
	# sorting, stencil decals or expensive screen-space AO on Android.
	for f in [-4.0, 6.0]:
		for s in [-6.0, 6.0]:
			world._prop("box", _p(frame, f, 0.068, s),
				Vector3(4.05, 0.020, 1.85), SHADOW, frame.basis)
			contacts += 1

	var heights: Array[int] = [3, 2, 1, 2, 3, 1] if detail else [2, 1, 1, 1, 2, 1]
	var index: int = 0
	for f in [-8.2, -10.75]:
		for s in [-7.0, 0.0, 7.0]:
			world._prop("box", _p(frame, f, 0.068, s),
				Vector3(6.47, 0.020, 2.75), SHADOW, frame.basis)
			contacts += 1
			if detail:
				for tier in range(heights[index]):
					var tint: Color = palette[(index * 2 + tier) % palette.size()]
					var at: Vector3 = _p(frame, f, 1.3 + float(tier) * 2.62, s)
					ribs += _container_ribs(world, frame, at, tint)
			index += 1

	# The same corrugated finish on the freighter's full-detail containers.
	# Mirrors the existing bay order; does not touch ship or hoist kinematics.
	if detail:
		var bay: int = 0
		var water: float = -2.9 # overwritten below from the actual waterline
		water = float(world.get_meta("harbor_water_height", -2.9)) - frame.origin.y
		for s in [-3.4, 2.75, 8.9]:
			for f_offset in [-1.3, 1.3]:
				for tier in range(2):
					var tint: Color = palette[(bay + tier * 2) % palette.size()]
					var at: Vector3 = _p(frame, 15.0 + f_offset,
						water + 4.1 + float(tier) * 2.62, s)
					ribs += _container_ribs(world, frame, at, tint)
				bay += 1

	# Concrete expansion seams: just four narrow, opaque geometry strips
	# in the existing box MultiMesh; unaffected by platform/road physics.
	for f in [-7.1, -2.7, 1.7, 6.0]:
		world._prop("box", _p(frame, f, 0.075, 0.0),
			Vector3(23.0, 0.013, 0.065), JOINT, frame.basis)
		seams += 1

	var evidence := {"contacts": contacts, "seams": seams, "ribs": ribs, "high_detail": detail}
	world.set_meta("sonnenhafen_visual_finish", evidence)
	return evidence


static func _container_ribs(world, frame: Transform3D, at: Vector3, tint: Color) -> int:
	# Six narrow vertical folds on each long wall. Shared opaque box mesh,
	# shared material and vertex colors preserve original instancing.
	var fold: Color = tint.lightened(0.16)
	for side in [-1.0, 1.0]:
		for i in range(RIBS_PER_FACE):
			var x: float = -2.42 + float(i) * 0.97
			var point: Vector3 = at + frame.basis.x * x + frame.basis.z * side * 1.255
			world._prop("box", point, Vector3(0.07, 2.22, 0.075), fold, frame.basis)
	return RIBS_PER_FACE * 2
