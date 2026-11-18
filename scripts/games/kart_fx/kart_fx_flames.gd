extends MultiMeshInstance3D
## Turbo flames as real flame bodies (one draw call for every kart): teardrop
## per exhaust, a warm glow patch on the road and the pipes' afterglow once the
## turbo ends. On HIGH a short-lived OmniLight lights road and tail; lower
## profiles rely on the glow patch only. Rewritten each tick (few instances).

const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
const CAPACITY := 24

var fx_time: float = 0.0
var used: int = 0
## CPU copy of the instance data written this tick (tests; headless keeps none).
var data: Array[Color] = []
var light: OmniLight3D
var light_enabled: bool = false
var _material: ShaderMaterial
var _light_energy: float = 0.0


func setup(shader: Shader) -> void:
	name = "KartFxFlames"
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.render_priority = 2
	material_override = _material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = _teardrop()
	multimesh.instance_count = CAPACITY
	light = OmniLight3D.new()
	light.name = "KartFxTurboLight"
	light.omni_range = 4.5
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.visible = false
	add_child(light)
	clear()


func clear() -> void:
	for index in range(CAPACITY):
		multimesh.set_instance_transform(index, HIDDEN)
	used = 0
	data.clear()
	visible = false
	light.visible = false
	_light_energy = 0.0


## Start a frame: everything written last tick is dropped.
func begin(delta: float, focus: Vector3) -> void:
	fx_time += maxf(0.0, delta)
	_material.set_shader_parameter("fx_time", fx_time)
	for index in range(used):
		multimesh.set_instance_transform(index, HIDDEN)
	used = 0
	data.clear()
	multimesh.custom_aabb = AABB(focus - Vector3.ONE * 60.0, Vector3.ONE * 120.0)
	_light_energy = 0.0


func flame(at: Vector3, back: Vector3, up: Vector3, length: float, width: float, intensity: float, mach: float, color: Color, seed: float) -> void:
	var z := back.normalized()
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	_add(Transform3D(Basis(x * width, y * width, z * length), at), color, Color(intensity, mach, 0.0, seed))


func ground_glow(at: Vector3, back: Vector3, up: Vector3, size: float, intensity: float, color: Color) -> void:
	var z := back.normalized()
	var x := up.cross(z).normalized()
	_add(Transform3D(Basis(x * size, up * 0.01, z * size * 1.6), at), color, Color(intensity, 0.0, 1.0, 0.0))


func afterglow(at: Vector3, back: Vector3, up: Vector3, size: float, intensity: float, color: Color) -> void:
	var z := back.normalized()
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	_add(Transform3D(Basis(x * size, y * size, z * size * 0.6), at - z * size * 0.1), color, Color(intensity, 0.0, 2.0, 0.0))


func light_at(at: Vector3, energy: float, color: Color) -> void:
	if not light_enabled or energy <= _light_energy:
		return
	_light_energy = energy
	light.global_position = at
	light.light_color = color
	light.light_energy = energy


func finish() -> void:
	visible = used > 0
	light.visible = light_enabled and _light_energy > 0.02
	if not light.visible:
		light.light_energy = 0.0


func _add(transform: Transform3D, color: Color, custom: Color) -> void:
	if used >= CAPACITY:
		return
	multimesh.set_instance_transform(used, transform)
	multimesh.set_instance_color(used, color)
	multimesh.set_instance_custom_data(used, custom)
	data.append(custom)
	used += 1


## Revolved teardrop along +Z (0 = nozzle, 1 = tip), radius from the shader's profile().
static func _teardrop() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 12
	var sides := 12
	var points: Array[PackedVector3Array] = []
	for ring in range(rings + 1):
		var t := float(ring) / float(rings)
		var radius := 0.5 * pow(maxf(1.0 - t, 0.0), 0.6) * (0.6 + 0.4 * smoothstep(0.0, 0.25, t))
		var row := PackedVector3Array()
		for side in range(sides):
			var angle := TAU * float(side) / float(sides)
			row.append(Vector3(cos(angle) * radius, sin(angle) * radius, t))
		points.append(row)
	for ring in range(rings):
		for side in range(sides):
			var next := (side + 1) % sides
			var a := points[ring][side]
			var b := points[ring][next]
			var c := points[ring + 1][side]
			var d := points[ring + 1][next]
			for vertex in [a, c, b, b, c, d]:
				var normal := Vector3(vertex.x, vertex.y, 0.15)
				surface.set_normal(normal.normalized() if normal.length() > 0.01 else Vector3.BACK)
				surface.add_vertex(vertex)
	# Nozzle cap so the flame base is closed from behind.
	for side in range(sides):
		surface.set_normal(Vector3.FORWARD)
		surface.add_vertex(Vector3.ZERO)
		surface.set_normal(Vector3.FORWARD)
		surface.add_vertex(points[0][(side + 1) % sides])
		surface.set_normal(Vector3.FORWARD)
		surface.add_vertex(points[0][side])
	return surface.commit()
