extends RefCounted
## Smooth, closed jump ramp swept along the road: one mesh, one draw call.
## The deck follows world.frame() (curve and banking) and uses the authored linear or ease-in rise, the
## same profile kart_action_course.kicker_height() uses for contact, so what
## is drawn is what is driven. The foot lies flush on the asphalt (DECK_LIFT),
## there is no stair-stepping and no seam between segments.

const DECK_LIFT: float = 0.012
const SEGMENTS_PER_METRE: float = 2.0
const STRIPE_METRES: float = 1.0
const BODY_COLOR: Color = Color("23324a")


## Builds the ramp and returns its MeshInstance3D (already added to world).
## colors: {"stripe_a", "stripe_b", "side", "lip", "profile"} (all optional).
static func build(
	world, start: float, length: float, height: float, half_width: float, colors: Dictionary = {}
) -> MeshInstance3D:
	var stripe_a: Color = colors.get("stripe_a", Color("f7c84a"))
	var stripe_b: Color = colors.get("stripe_b", Color("23324a"))
	var side_color: Color = colors.get("side", BODY_COLOR)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = maxi(4, ceili(length * SEGMENTS_PER_METRE))
	var rows: Array = []
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var d: float = start + length * t
		var basis: Basis = world.frame(d)
		var rise: float = t * t if str(colors.get("profile", "linear")) == "ease_in" else t
		var lift: Vector3 = basis.y * (rise * height + DECK_LIFT)
		rows.append(
			{
				"d": d,
				"left": world.position_at(d, -half_width) + lift,
				"right": world.position_at(d, half_width) + lift,
				"left_foot": world.position_at(d, -half_width) - basis.y * 0.05,
				"right_foot": world.position_at(d, half_width) - basis.y * 0.05,
				"up": basis.y,
				"side": basis.x,
			}
		)
	for i in range(steps):
		var a: Dictionary = rows[i]
		var b: Dictionary = rows[i + 1]
		var along: float = float(a.d) - start
		var color: Color = stripe_a if int(floor(along / STRIPE_METRES)) % 2 == 0 else stripe_b
		# Deck normal from the actual slope, so lighting reads the incline.
		var slope_normal: Vector3 = (b.right - a.left).cross(a.right - a.left).normalized()
		if slope_normal.dot(a.up) < 0.0:
			slope_normal = -slope_normal
		_quad(tool, a.left, a.right, b.right, b.left, slope_normal, color)
		_quad(tool, a.left_foot, a.left, b.left, b.left_foot, -a.side, side_color)
		_quad(tool, a.right, a.right_foot, b.right_foot, b.right, a.side, side_color)
	var last: Dictionary = rows[steps]
	_quad(
		tool,
		last.left_foot,
		last.right_foot,
		last.right,
		last.left,
		-world.forward(float(last.d)),
		side_color
	)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.55
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.name = "TrackRamp_%d" % int(start)
	node.mesh = tool.commit()
	node.material_override = material
	world.add_child(node)
	return node


static func _quad(
	tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color
) -> void:
	for corner in [a, b, c, a, c, d]:
		tool.set_color(color)
		tool.set_normal(normal)
		tool.add_vertex(corner)
