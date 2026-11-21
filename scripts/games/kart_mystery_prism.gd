class_name LumoMysteryPrism
extends RefCounted
## LUMO Energieprisma (Zufallsprisma für den Sternenkompass), eigenes Design:
##  - äußere facettierte Hülle aus violettem Glas mit goldenen Kanten,
##  - innere, gegenläufig drehende Cyan-Hülle (um 45° versetzt),
##  - leuchtender Sternenkern (der Stern der Item-Box sitzt in der Mitte),
##  - zwei schräg stehende Lichtbahnen (Cyan, Gold), die um das Prisma kreisen,
##  - ein schwacher Lichtschein nach oben, damit man das Prisma von weitem sieht.
## Alle Netze und Materialien werden einmal gebaut und geteilt; ferne Teile werden ab
## FAR_M ausgeblendet. Resonanzringe (Könnerringe) bleiben Ringe – das Prisma ist klar
## ein Kristall mit Stern.

const POINTS: Array[Vector3] = [
	Vector3(0, 0.68, 0),
	Vector3(0, -0.68, 0),
	Vector3(0.54, 0, 0),
	Vector3(0, 0, 0.54),
	Vector3(-0.54, 0, 0),
	Vector3(0, 0, -0.54),
]
const VIOLET := Color("6442b9")
const CYAN := Color("5ff2ff")
const GOLD := Color("ffcb58")
const FAR_M: float = 150.0
const RAIL_TILT: float = 0.62
## Sichtbare Größe auf dem Handy: 1,3-fach (Prisma ~1,8 m hoch, Kart-Höhe erreichbar).
const SIZE: float = 1.3
static var core_mesh: ArrayMesh
static var edge_mesh: ArrayMesh
static var rail_mesh: TorusMesh
static var beacon_mesh: CylinderMesh
static var shard_mesh: ArrayMesh
static var violet: StandardMaterial3D
static var gold: StandardMaterial3D
static var inner: StandardMaterial3D
static var rail_cyan: StandardMaterial3D
static var rail_gold: StandardMaterial3D
static var beacon: StandardMaterial3D
static var shard: StandardMaterial3D


static func build(parent: Node3D) -> void:
	if core_mesh == null:
		_make_shared_geometry()
	var core := MeshInstance3D.new()
	core.name = "MysteryPrismCore"
	core.mesh = core_mesh
	core.material_override = violet
	core.scale = Vector3.ONE * SIZE
	parent.add_child(core)
	var edges := MeshInstance3D.new()
	edges.name = "MysteryPrismEdges"
	edges.mesh = edge_mesh
	edges.material_override = gold
	edges.scale = Vector3.ONE * SIZE
	parent.add_child(edges)
	var shell := MeshInstance3D.new()
	shell.name = "MysteryPrismInner"
	shell.mesh = core_mesh
	shell.material_override = inner
	shell.scale = Vector3.ONE * 0.6 * SIZE
	shell.rotation.y = PI * 0.25
	shell.visibility_range_end = FAR_M
	parent.add_child(shell)
	for k in range(2):
		var pivot := Node3D.new()
		pivot.name = "PrismRail%d" % k
		pivot.rotation = Vector3(
			RAIL_TILT if k == 0 else -RAIL_TILT, 0.0, 0.45 if k == 0 else -0.45
		)
		pivot.scale = Vector3.ONE * SIZE
		parent.add_child(pivot)
		var rail := MeshInstance3D.new()
		rail.name = "Rail"
		rail.mesh = rail_mesh
		rail.material_override = rail_cyan if k == 0 else rail_gold
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rail.visibility_range_end = FAR_M
		pivot.add_child(rail)
	var glow := MeshInstance3D.new()
	glow.name = "PrismBeacon"
	glow.mesh = beacon_mesh
	glow.material_override = beacon
	glow.position = Vector3(0, 2.2, 0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(glow)
	parent.set_meta("mystery_visual", "lumo_star_prism")


## Ruhige Bewegung je Bild: Hülle und Kern gegenläufig, Lichtbahnen kreisen um ihre Achse,
## Sternenkern atmet sanft (keine harten Helligkeitssprünge). Reduzierte Bewegung: still.
static func animate(
	parent: Node3D, delta: float, age: float, spin_speed: float, reduced: bool
) -> void:
	if reduced:
		return
	for child_name in ["MysteryPrismCore", "MysteryPrismEdges"]:
		var node := parent.get_node_or_null(child_name) as Node3D
		if node != null:
			node.rotation.y += delta * spin_speed
	var shell := parent.get_node_or_null("MysteryPrismInner") as Node3D
	if shell != null:
		shell.rotation.y -= delta * spin_speed * 1.7
	for k in range(2):
		var rail := parent.get_node_or_null("PrismRail%d/Rail" % k) as Node3D
		if rail != null:
			rail.rotation.y += delta * (2.4 if k == 0 else -1.9)
	var star := parent.get_node_or_null("SurpriseStar") as Node3D
	if star != null:
		star.position.y = sin(age * 2.4) * 0.06
		star.scale = Vector3.ONE * (1.0 + sin(age * 3.1) * 0.08)


## Zerlegung beim Durchfahren: Splitter in Violett/Cyan/Gold fliegen auseinander und
## verglühen (einmaliger Ausbruch, ~0,8 s). Reduzierte Bewegung: wenige, langsame Splitter.
static func shatter(parent: Node3D, at: Vector3, reduced: bool) -> CPUParticles3D:
	if not is_instance_valid(parent):
		return null
	if core_mesh == null:
		_make_shared_geometry()
	var burst := CPUParticles3D.new()
	burst.name = "PrismShatter"
	burst.mesh = shard_mesh
	burst.material_override = shard
	burst.amount = 14 if reduced else 42
	burst.lifetime = 0.8
	burst.one_shot = true
	burst.explosiveness = 0.92
	burst.direction = Vector3.UP
	burst.spread = 180.0
	burst.initial_velocity_min = 1.2 if reduced else 2.5
	burst.initial_velocity_max = 2.2 if reduced else 5.0
	burst.gravity = Vector3(0, -4.0, 0)
	burst.damping_min = 2.0
	burst.damping_max = 4.0
	burst.angular_velocity_min = -400.0
	burst.angular_velocity_max = 400.0
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.3
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(0.7, 0.8))
	fade.add_point(Vector2(1.0, 0.0))
	burst.scale_amount_curve = fade
	var colours := Gradient.new()
	colours.set_color(0, Color(VIOLET, 1.0).lightened(0.25))
	colours.set_color(1, Color(GOLD, 0.0))
	colours.add_point(0.45, CYAN)
	burst.color_ramp = colours
	burst.position = at
	parent.add_child(burst)
	burst.emitting = true
	if parent.is_inside_tree():
		parent.get_tree().create_timer(1.4, false).timeout.connect(burst.queue_free)
	return burst


static func _finish(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.32
	material.roughness = 0.28
	material.clearcoat_enabled = true
	material.clearcoat = 0.7
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission
	return material


static func _light(color: Color, alpha: float, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Normale Mischung statt Addition: vor hellem Himmel bleibt Cyan/Gold/Violett farbig.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, alpha)
	material.vertex_color_use_as_albedo = false
	return material


static func _make_shared_geometry() -> void:
	var core := SurfaceTool.new()
	core.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pairs: Array[Vector2i] = []
	for ring in range(4):
		var a: int = 2 + ring
		var b: int = 2 + (ring + 1) % 4
		for index in [0, b, a, 1, a, b]:
			core.add_vertex(POINTS[index])
		pairs.append_array([Vector2i(0, a), Vector2i(1, a), Vector2i(a, b)])
	core.generate_normals()
	core_mesh = core.commit()
	var edges := SurfaceTool.new()
	edges.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pair in pairs:
		_edge(edges, POINTS[pair.x], POINTS[pair.y])
	edges.generate_normals()
	edge_mesh = edges.commit()
	violet = _finish(VIOLET, 0.55)
	violet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	violet.albedo_color = Color(VIOLET, 0.88)
	gold = _finish(GOLD, 0.6)
	inner = _finish(CYAN, 1.1)
	inner.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rail_mesh = TorusMesh.new()
	rail_mesh.inner_radius = 0.8
	rail_mesh.outer_radius = 0.86
	rail_mesh.rings = 32
	rail_mesh.ring_segments = 6
	rail_cyan = _light(CYAN, 0.95, 1.0)
	rail_gold = _light(GOLD, 0.95, 1.0)
	beacon_mesh = CylinderMesh.new()
	beacon_mesh.top_radius = 0.04
	beacon_mesh.bottom_radius = 0.32
	beacon_mesh.height = 2.6
	beacon_mesh.radial_segments = 10
	beacon_mesh.rings = 1
	beacon_mesh.cap_top = false
	beacon_mesh.cap_bottom = false
	beacon = _light(Color("9a6bff"), 0.38, 1.0)
	var piece := SurfaceTool.new()
	piece.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(4):
		var a: int = 2 + ring
		var b: int = 2 + (ring + 1) % 4
		for index in [0, b, a, 1, a, b]:
			piece.add_vertex(POINTS[index] * 0.08)
	piece.generate_normals()
	shard_mesh = piece.commit()
	shard = StandardMaterial3D.new()
	shard.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shard.vertex_color_use_as_albedo = true
	# Gemischt statt additiv: Splitter bleiben violett/cyan/gold, auch nah an der Kamera.
	shard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


static func _edge(tool: SurfaceTool, start: Vector3, end: Vector3) -> void:
	var direction := (end - start).normalized()
	var reference := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var u := direction.cross(reference).normalized() * 0.022
	var v := direction.cross(u).normalized() * 0.022
	for segment in range(8):
		var angle_a: float = float(segment) * TAU / 8.0
		var angle_b: float = float(segment + 1) * TAU / 8.0
		var offset_a := u * cos(angle_a) + v * sin(angle_a)
		var offset_b := u * cos(angle_b) + v * sin(angle_b)
		for point in [
			start + offset_a,
			end + offset_b,
			end + offset_a,
			start + offset_a,
			start + offset_b,
			end + offset_b,
		]:
			tool.add_vertex(point)
