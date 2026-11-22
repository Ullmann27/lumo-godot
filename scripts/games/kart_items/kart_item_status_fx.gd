extends Node3D
## Sternmagnet mit zwei Polschuhen, Feldlinien und den tatsächlich eingesammelten
## Streckensternen. Der Nordlicht-Ring zeigt die verbleibende Schutzzeit.

const FIELD = preload("res://scripts/games/kart_items/kart_magnet_field.gd")
const FLIGHT_TIME := 0.36
const MAX_PULLS := 6
const AURORA_COLOR := Color("8affd8")

var reduced_motion: bool = false
var magnet_ring: MeshInstance3D
var aurora_ring: MeshInstance3D
var _time: float = 0.0
var low_detail := false
var rival_seconds := 0.0
var _pulls: Array[Dictionary] = []
var _stars: MultiMeshInstance3D


static func show_rival_magnet(kart: Node3D, quality: String, seconds: float) -> void:
	var field = kart.get_node_or_null("KartItemStatusFx")
	if field == null:
		field = new()
		field.low_detail = quality == "low"
		kart.add_child(field)
	field.rival_seconds = seconds


func _ready() -> void:
	name = "KartItemStatusFx"
	position = Vector3(0, 0.45, 0)
	magnet_ring = MeshInstance3D.new()
	magnet_ring.name = "MagnetRing"
	magnet_ring.mesh = FIELD.mesh(low_detail)
	magnet_ring.visible = false
	magnet_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(magnet_ring)
	aurora_ring = _ring("AuroraRing", AURORA_COLOR, 1.75, 0.11)


func _ring(
	node_name: String, color: Color, radius: float, thickness: float
) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = node_name
	var torus := TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + thickness
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color, 0.8)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false
	add_child(ring)
	return ring


## Pro Physiktakt vom Rennen: verbleibende und gesamte Sekunden je Item.
func advance(
	delta: float, magnet_left: float, magnet_total: float, aurora_left: float, aurora_total: float
) -> void:
	_time += delta
	magnet_ring.visible = magnet_left > 0.0
	if magnet_ring.visible:
		var growth := 1.0 if reduced_motion else 0.84 + 0.16 * smoothstep(0.0, 0.28, magnet_total-magnet_left)
		magnet_ring.scale = Vector3.ONE * growth
	_update_pulls(delta)
	_show(aurora_ring, aurora_left, aurora_total, -1.3, 0.35)


func _show(ring: MeshInstance3D, left: float, total: float, spin: float, bob: float) -> void:
	ring.visible = left > 0.0
	if not ring.visible:
		return
	var fade: float = clampf(left / 1.0, 0.25, 1.0)
	var grow: float = clampf((total - left) / 0.25, 0.0, 1.0)
	var material := ring.material_override as StandardMaterial3D
	material.albedo_color.a = 0.8 * fade
	if reduced_motion:
		ring.rotation = Vector3.ZERO
		ring.scale = Vector3.ONE
		ring.position.y = 0.0
		return
	ring.rotation.y = _time * spin
	ring.scale = Vector3.ONE * (0.6 + 0.4 * grow)
	ring.position.y = sin(_time * 2.2) * bob * 0.5


## A collected course star keeps its real mesh, color and world-space departure point.
## The race awards the pickup immediately; this short arc is presentation only.
func pull_star(star: MeshInstance3D) -> void:
	if not is_instance_valid(star) or star.mesh == null:
		return
	if not is_instance_valid(_stars):
		_stars = MultiMeshInstance3D.new()
		_stars.name = "CollectedStars"
		_stars.multimesh = MultiMesh.new()
		_stars.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		_stars.multimesh.mesh = star.mesh
		_stars.multimesh.instance_count = MAX_PULLS
		_stars.multimesh.visible_instance_count = 0
		_stars.material_override = star.material_override
		_stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_stars)
	if _pulls.size() >= (2 if low_detail else MAX_PULLS):
		_pulls.pop_front()
	_pulls.append({"from": star.global_position, "basis": star.global_basis, "age": 0.0})


func _update_pulls(delta: float) -> void:
	if _pulls.is_empty():
		return
	for i in range(_pulls.size()-1, -1, -1):
		_pulls[i].age += delta
		if float(_pulls[i].age) >= FLIGHT_TIME:
			_pulls.remove_at(i)
	_stars.multimesh.visible_instance_count = _pulls.size()
	for i in range(_pulls.size()):
		var flight := _pulls[i]
		var t := smoothstep(0.0, 1.0, float(flight.age) / FLIGHT_TIME)
		var arc := Vector3.UP * sin(PI*t) * (0.12 if reduced_motion else 0.85)
		var target := to_global(Vector3(0, 1.22, 1.35))
		var position_now := (flight.from as Vector3).lerp(target, t) + arc
		var basis_now := (flight.basis as Basis).scaled(Vector3.ONE * (1.0 - 0.55*t))
		_stars.multimesh.set_instance_transform(i, global_transform.affine_inverse() * Transform3D(basis_now, position_now))
