class_name LumoKartRivalItemFx
extends Node3D
## Lightweight world-space feedback for the existing Lumo rival items.
## Five rivals share primitive meshes only; no external asset or gameplay rule lives here.

const ITEM_COLORS := {
	"boost": Color("ffd166"),
	"shield": Color("66e8ff"),
	"pulse": Color("c58cff"),
}

var held_item: String = ""
var reduced_motion: bool = false
var pulse_age: float = 1.0
var elapsed: float = 0.0

var item_orb: MeshInstance3D
var item_ring: MeshInstance3D
var shield_bubble: MeshInstance3D
var warning_ring: MeshInstance3D
var pulse_ring: MeshInstance3D
var stun_ring: MeshInstance3D


func _ready() -> void:
	_build()
	set_process(true)


func _material(color: Color, alpha: float = 1.0, glow: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = glow
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _ring(radius: float, thickness: float, color: Color, alpha: float) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius
	mesh.outer_radius = radius + thickness
	mesh.rings = 24
	mesh.ring_segments = 6
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color, alpha, 1.5)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _build() -> void:
	item_orb = MeshInstance3D.new()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.18
	orb_mesh.height = 0.36
	orb_mesh.radial_segments = 12
	orb_mesh.rings = 6
	item_orb.mesh = orb_mesh
	item_orb.position = Vector3(0.0, 2.05, 0.0)
	item_orb.visible = false
	item_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item_orb)

	item_ring = _ring(0.27, 0.055, Color("ffffff"), 0.85)
	item_ring.position = Vector3(0.0, 2.05, 0.0)
	item_ring.rotation.x = PI * 0.5
	item_ring.visible = false
	add_child(item_ring)

	shield_bubble = MeshInstance3D.new()
	var shield_mesh := SphereMesh.new()
	shield_mesh.radius = 1.55
	shield_mesh.height = 3.1
	shield_mesh.radial_segments = 18
	shield_mesh.rings = 9
	shield_bubble.mesh = shield_mesh
	shield_bubble.position.y = 0.95
	shield_bubble.material_override = _material(Color("66e8ff"), 0.12, 0.65)
	shield_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield_bubble.visible = false
	add_child(shield_bubble)

	warning_ring = _ring(1.18, 0.12, Color("d694ff"), 0.72)
	warning_ring.position.y = 0.10
	warning_ring.visible = false
	add_child(warning_ring)

	pulse_ring = _ring(1.05, 0.14, Color("b5efff"), 0.75)
	pulse_ring.position.y = 0.12
	pulse_ring.visible = false
	add_child(pulse_ring)

	stun_ring = _ring(0.72, 0.09, Color("ffd166"), 0.70)
	stun_ring.position.y = 2.0
	stun_ring.rotation.x = PI * 0.5
	stun_ring.visible = false
	add_child(stun_ring)


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value


func set_item(value: String) -> void:
	if value == held_item and is_instance_valid(item_orb):
		return
	held_item = value
	if not is_instance_valid(item_orb):
		return
	var visible_item: bool = ITEM_COLORS.has(value)
	item_orb.visible = visible_item
	item_ring.visible = visible_item
	if visible_item:
		var color: Color = ITEM_COLORS[value]
		item_orb.material_override = _material(color, 0.95, 1.7)
		item_ring.material_override = _material(color.lightened(0.16), 0.82, 1.4)


func set_shield(seconds: float) -> void:
	if is_instance_valid(shield_bubble):
		shield_bubble.visible = seconds > 0.0
		if shield_bubble.visible:
			shield_bubble.scale = Vector3.ONE * (1.0 if reduced_motion else 1.0 + sin(elapsed * 4.0) * 0.025)


func set_pulse_warning(remaining: float, duration: float) -> void:
	if not is_instance_valid(warning_ring):
		return
	warning_ring.visible = remaining > 0.0
	if not warning_ring.visible:
		return
	var progress: float = 1.0 - clampf(remaining / maxf(duration, 0.001), 0.0, 1.0)
	var beat: float = 0.0 if reduced_motion else sin(progress * TAU * 3.0) * 0.08
	warning_ring.scale = Vector3.ONE * (0.88 + progress * 0.28 + beat)


func fire_pulse() -> void:
	pulse_age = 0.0
	if is_instance_valid(pulse_ring):
		pulse_ring.visible = true
		pulse_ring.scale = Vector3.ONE
		pulse_ring.material_override = _material(Color("b5efff"), 0.75, 1.8)


func set_stunned(seconds: float) -> void:
	if is_instance_valid(stun_ring):
		stun_ring.visible = seconds > 0.0


func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(item_ring) and item_ring.visible and not reduced_motion:
		item_ring.rotation.y += delta * 2.4
	if is_instance_valid(stun_ring) and stun_ring.visible and not reduced_motion:
		stun_ring.rotation.y += delta * 3.0
	if pulse_age < 0.72 and is_instance_valid(pulse_ring):
		pulse_age += delta
		var progress: float = clampf(pulse_age / 0.72, 0.0, 1.0)
		pulse_ring.visible = progress < 1.0
		pulse_ring.scale = Vector3.ONE * (1.0 + progress * 6.0)
		var material := pulse_ring.material_override as StandardMaterial3D
		if material:
			material.albedo_color.a = 0.75 * (1.0 - progress)


func visual_state() -> Dictionary:
	return {
		"held_item": held_item,
		"item_visible": is_instance_valid(item_orb) and item_orb.visible,
		"shield_visible": is_instance_valid(shield_bubble) and shield_bubble.visible,
		"warning_visible": is_instance_valid(warning_ring) and warning_ring.visible,
		"pulse_visible": is_instance_valid(pulse_ring) and pulse_ring.visible,
		"stun_visible": is_instance_valid(stun_ring) and stun_ring.visible,
	}
