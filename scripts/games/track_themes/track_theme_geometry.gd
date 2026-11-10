extends RefCounted
## Local assemblies use the existing world batching path; no nodes or per-frame work.


static func put(
	world,
	shape: String,
	at: Vector3,
	basis: Basis,
	local: Vector3,
	size: Vector3,
	color: Color,
	glow: bool = false,
	rotation: Quaternion = Quaternion.IDENTITY
) -> void:
	world._prop(shape, at + basis * local, size, color, basis * Basis(rotation), glow)


static func beam(
	world,
	at: Vector3,
	basis: Basis,
	start: Vector3,
	end: Vector3,
	radius: float,
	color: Color,
	glow: bool = false
) -> void:
	var delta := end - start
	var span := delta.length()
	if span <= 0.0001:
		return
	put(
		world,
		"cylinder",
		at,
		basis,
		(start + end) * 0.5,
		Vector3(radius, span, radius),
		color,
		glow,
		Quaternion(Vector3.UP, delta / span)
	)
