extends RefCounted
## Smooth, closed jump ramp swept along the road: one mesh, one draw call.
## The deck follows world.frame() (curve and banking) and uses the authored linear or ease-in rise, the
## same profile kart_action_course.kicker_height() uses for contact, so what
## is drawn is what is driven. The foot lies flush on the asphalt (DECK_LIFT),
## there is no stair-stepping and no seam between segments.

const DECK_LIFT: float = 0.012
const SEGMENTS_PER_METRE: float = 2.0
const DECK_SHADER = preload("res://assets/shaders/kart_ramp_surface.gdshader")
const BODY_COLOR: Color = Color("424951")


## Builds the ramp and returns its MeshInstance3D (already added to world).
## finish: {"deck", "side", "paint", "profile"} (all optional).
static func build(
	world, start: float, length: float, height: float, half_width: float, finish: Dictionary = {}
) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = maxi(4, ceili(length * SEGMENTS_PER_METRE))
	var rows: Array = []
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var d: float = start + length * t
		var basis: Basis = world.frame(d)
		var rise: float = t * t if str(finish.get("profile", "linear")) == "ease_in" else t
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
		var next: float = float(b.d) - start
		# Deck normal from the actual slope, so lighting reads the incline.
		var slope_normal: Vector3 = (b.right - a.left).cross(a.right - a.left).normalized()
		if slope_normal.dot(a.up) < 0.0:
			slope_normal = -slope_normal
		_quad(tool, a.left, a.right, b.right, b.left, slope_normal, [
			Vector2(-half_width, along), Vector2(half_width, along),
			Vector2(half_width, next), Vector2(-half_width, next),
		])
		_quad(tool, a.left_foot, a.left, b.left, b.left_foot, -a.side)
		_quad(tool, a.right, a.right_foot, b.right_foot, b.right, a.side)
	var last: Dictionary = rows[steps]
	_quad(
		tool,
		last.left_foot,
		last.right_foot,
		last.right,
		last.left,
		-world.forward(float(last.d))
	)
	var material := ShaderMaterial.new()
	material.shader = DECK_SHADER
	material.set_shader_parameter("half_width", half_width)
	material.set_shader_parameter("deck_length", length)
	material.set_shader_parameter("deck_tint", finish.get("deck", Color("494e52")))
	material.set_shader_parameter("side_tint", finish.get("side", BODY_COLOR))
	material.set_shader_parameter("paint_tint", finish.get("paint", Color("dec898")))
	var node := MeshInstance3D.new()
	node.name = "TrackRamp_%d" % int(start)
	node.mesh = tool.commit()
	node.material_override = material
	world.add_child(node)
	return node


static func _quad(
	tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3,
	coordinates: Array[Vector2] = []
) -> void:
	var corners := [a, b, c, d]
	for index: int in [0, 1, 2, 0, 2, 3]:
		tool.set_uv(Vector2(0, -1) if coordinates.is_empty() else coordinates[index])
		tool.set_normal(normal)
		tool.add_vertex(corners[index])
