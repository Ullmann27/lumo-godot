extends RefCounted
## Small real manufactured details shared by every existing fleet chassis.
## These additions fit within the existing contact envelope and LOD budgets.


static func rounded_box(kart, parent: Node3D, at: Vector3, size: Vector3, color: Color, metal: float = 0.35, rough: float = 0.56) -> MeshInstance3D:
	var key: String = "craft_bevel:" + str(size)
	if not kart.geometries.has(key):
		var half: Vector3 = size * 0.5
		var bevel: float = minf(size.x, minf(size.y, size.z)) * 0.22
		var inner: Vector3 = half - Vector3.ONE * bevel
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for axis in range(3):
			var u: int = (axis + 1) % 3
			var v: int = (axis + 2) % 3
			for side in [-1.0, 1.0]:
				var vertices: Array[Vector3] = []
				var normals: Array[Vector3] = []
				var us: Array[float] = [-half[u], -inner[u], inner[u], half[u]]
				var vs: Array[float] = [-half[v], -inner[v], inner[v], half[v]]
				for row in range(4):
					for column in range(4):
						var p := Vector3.ZERO
						p[axis] = side * half[axis]
						p[u] = us[column]
						p[v] = vs[row]
						var c: Vector3 = p.clamp(-inner, inner)
						var normal: Vector3 = (p - c).normalized()
						vertices.append(c + normal * bevel)
						normals.append(normal)
				for row in range(3):
					for column in range(3):
						var a: int = row * 4 + column
						for tri in [[a, a + 1, a + 5], [a, a + 5, a + 4]]:
							# Godot front faces are clockwise when viewed from outside.
							if side > 0:
								tri.reverse()
							for index: int in tri:
								surface.set_normal(normals[index])
								surface.add_vertex(vertices[index])
		var result: ArrayMesh = surface.commit()
		result.set_meta("far_skip", true)
		kart.geometries[key] = result
	return kart._mesh(parent, kart.geometries[key], at, color, metal, rough)


static func decorate(kart, body: Node3D, spec: Dictionary) -> void:
	body.set_meta("craftsmanship_revision", 1)
	var paint: Color = spec.paint
	if str(spec.body) == "loft":
		for child in body.get_children():
			if child is MeshInstance3D:
				paint = child.material_override.albedo_color
				break
	var metal := Color("a5afb1")
	var rubber := Color("24292f")
	# Upholstery channels and piping belong to the rear of the existing seat.
	for index in range(5):
		var pad: MeshInstance3D = rounded_box(kart, body, Vector3(-0.16 + index * 0.08, 0.91, 0.458), Vector3(0.062, 0.24, 0.024), Color("283441"), 0.0, 0.82)
		pad.name = "QuiltedSeatChannel"
	for side in [-1.0, 1.0]:
		var heel: MeshInstance3D = rounded_box(kart, body, Vector3(side * 0.34, 0.675, 0.065), Vector3(0.048, 0.045, 0.50), rubber, 0.0, 0.82)
		heel.name = "PaddedCockpitSill"
		# Finished inset intake: framed surround, dark well and real depth slats.
		var frame: MeshInstance3D = rounded_box(kart, body, Vector3(side * 0.585, 0.545, 0.17), Vector3(0.032, 0.125, 0.30), paint.darkened(0.15), 0.35, 0.26)
		frame.name = "SculptedIntakeFrame"
		rounded_box(kart, body, Vector3(side * 0.606, 0.545, 0.17), Vector3(0.012, 0.089, 0.252), Color("111b24"), 0.0, 0.82)
		for vent in range(5):
			var blade: MeshInstance3D = rounded_box(kart, body, Vector3(side * 0.615, 0.55, 0.075 + vent * 0.047), Vector3(0.014, 0.075, 0.010), metal, 0.7, 0.56)
			blade.rotation.z = side * -0.16
		for z in [-0.26, 0.42]:
			var fastener: MeshInstance3D = rounded_box(kart, body, Vector3(side * 0.47, 0.672, z), Vector3(0.035, 0.010, 0.035), metal, 0.7, 0.56)
			fastener.name = "RecessedCoachworkFastener"
	# A distinct brushed lower splitter connects the body across the front.
	if str(spec.body) == "loft":
		var splitter: MeshInstance3D = rounded_box(kart, body, Vector3(0, 0.366, -1.068), Vector3(0.68, 0.034, 0.075), rubber, 0.0, 0.82)
		splitter.name = "RoundedNoseSplitter"


static func wheel_details(kart, rotor: Node3D, side: float, radius: float, half: float) -> void:
	var outside: float = -side * half
	var bead: MeshInstance3D = kart._ring(rotor, Vector3(0, outside + side * 0.006, 0), radius * 0.81, radius * 0.832, Color("303740"), 0.0)
	bead.name = "MouldedTyreBead"
	bead.set_meta("near_only", true)
	bead.material_override = kart._mat(Color("303740"), 0.0, 0.82)
	var lip: MeshInstance3D = kart._ring(rotor, Vector3(0, outside - side * 0.012, 0), radius * 0.665, radius * 0.685, Color("a5afb1"), 0.7)
	lip.name = "MachinedWheelLip"
	lip.set_meta("near_only", true)
	# Tiny manufactured lips need fewer sides than the existing tyre itself.
	# Cache reduced geometry without changing any shared original rim mesh.
	for detail in [bead, lip]:
		var ring_key: String = "craft_ring:" + str(detail.mesh.inner_radius) + ":" + str(detail.mesh.outer_radius)
		if not kart.geometries.has(ring_key):
			var ring: TorusMesh = detail.mesh.duplicate()
			ring.rings = 20
			ring.ring_segments = 4
			kart.geometries[ring_key] = ring
		detail.mesh = kart.geometries[ring_key]
	if not kart.geometries.has("craft_disc_vent"):
		var vent := CylinderMesh.new()
		vent.top_radius = 1.0
		vent.bottom_radius = 1.0
		vent.height = 2.0
		vent.radial_segments = 10
		kart.geometries["craft_disc_vent"] = vent
	for index in range(10):
		var angle: float = index * TAU / 10.0 + 0.12
		var point := Vector3(cos(angle) * radius * 0.47, outside - side * 0.008, sin(angle) * radius * 0.47)
		var slot: MeshInstance3D = kart._mesh(rotor, kart.geometries["craft_disc_vent"], point, Color("131c25"), 0.0, 0.82)
		slot.scale = Vector3(0.012, 0.0025, 0.025)
		slot.name = "BrakeDiscVent"
		slot.set_meta("near_only", true)
		slot.rotation.y = -angle
