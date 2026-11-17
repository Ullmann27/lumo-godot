class_name LumoKartRivalItemFx
extends Node3D
## World-space feedback for the existing Lumo rival items. The held ability
## uses the same solid emblem as its skill-gate outcome. Racing owns the clock.

const SYMBOLS = preload("res://scripts/games/kart_item_symbols.gd")

const ITEM_COLORS := {
	"boost": Color("ffd166"),
	"shield": Color("66e8ff"),
	"pulse": Color("c58cff"),
}

var held_item: String = ""
var reduced_motion: bool = false
var pulse_age: float = 1.0
var elapsed: float = 0.0

## Historical public name retained for capture/inspection compatibility.
var item_orb: Node3D
var item_ring: MeshInstance3D
var shield_bubble: MeshInstance3D
var shield_ring: MeshInstance3D
var warning_ring: MeshInstance3D
var pulse_ring: MeshInstance3D
var stun_ring: MeshInstance3D
var _held_symbols: Dictionary = {}
var _held_ring_materials: Dictionary = {}
var _rendered_item: String = "__unbuilt__"
var _pulse_material: StandardMaterial3D


func _ready() -> void:
	_build()
	set_process(false)
	set_item(held_item)


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
	item_orb = Node3D.new()
	item_orb.name = "HeldItemSymbol"
	# The tallest current driver (rabbit) reaches 2.492 m; the lowest shield
	# tip and hover rail retain clearance even at the bottom of the small bob.
	item_orb.position = Vector3(0.0, 3.20, 0.0)
	item_orb.scale = Vector3.ONE * 0.70
	item_orb.visible = false
	add_child(item_orb)
	for kind in SYMBOLS.KINDS:
		var symbol: Node3D = SYMBOLS.build(kind)
		symbol.visible = false
		item_orb.add_child(symbol)
		_held_symbols[kind] = symbol
		_held_ring_materials[kind] = _material(ITEM_COLORS[kind], 0.85, 1.1)

	item_ring = _ring(0.34, 0.06, Color("ffffff"), 0.85)
	item_ring.name = "HeldItemHoverRail"
	item_ring.position = Vector3(0.0, 2.68, 0.0)
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
	shield_bubble.material_override = _material(Color("66e8ff"), 0.32, 1.55)
	shield_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield_bubble.visible = false
	add_child(shield_bubble)

	shield_ring = _ring(1.48, 0.11, Color("9af4ff"), 0.88)
	shield_ring.position.y = 0.20
	shield_ring.visible = false
	add_child(shield_ring)

	warning_ring = _ring(1.55, 0.26, Color("f0b8ff"), 0.95)
	warning_ring.position.y = 0.10
	warning_ring.visible = false
	add_child(warning_ring)

	pulse_ring = _ring(1.38, 0.20, Color("b5efff"), 0.88)
	pulse_ring.position.y = 0.12
	_pulse_material = _material(Color("c58cff"), 0.88, 1.8)
	pulse_ring.material_override = _pulse_material
	pulse_ring.visible = false
	add_child(pulse_ring)

	stun_ring = _ring(0.72, 0.09, Color("ffd166"), 0.70)
	stun_ring.position.y = 2.0
	stun_ring.rotation.x = PI * 0.5
	stun_ring.visible = false
	add_child(stun_ring)


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_apply_motion()


func set_item(value: String) -> void:
	held_item = value
	if not is_instance_valid(item_orb):
		return
	if value == _rendered_item:
		return
	_rendered_item = value
	var visible_item: bool = ITEM_COLORS.has(value)
	item_orb.visible = visible_item
	item_ring.visible = visible_item
	for kind in _held_symbols:
		(_held_symbols[kind] as Node3D).visible = kind == value
	if visible_item:
		item_ring.material_override = _held_ring_materials[value]
		SYMBOLS.advance(_held_symbols[value], elapsed, reduced_motion)


func set_shield(seconds: float) -> void:
	var visible_shield: bool = seconds > 0.0
	if is_instance_valid(shield_bubble):
		shield_bubble.visible = visible_shield
	if is_instance_valid(shield_ring):
		shield_ring.visible = visible_shield
	if visible_shield:
		var scale_value: float = 1.0 if reduced_motion else 1.0 + sin(elapsed * 4.0) * 0.035
		shield_bubble.scale = Vector3.ONE * scale_value
		shield_ring.scale = Vector3.ONE * scale_value


func set_pulse_warning(remaining: float, duration: float) -> void:
	if not is_instance_valid(warning_ring):
		return
	warning_ring.visible = remaining > 0.0
	if not warning_ring.visible:
		return
	var progress: float = 1.0 - clampf(remaining / maxf(duration, 0.001), 0.0, 1.0)
	var beat: float = sin(progress * TAU * 3.0) * 0.08
	warning_ring.scale = Vector3.ONE if reduced_motion else Vector3.ONE * (0.88 + progress * 0.28 + beat)


func fire_pulse() -> void:
	pulse_age = 0.0
	if is_instance_valid(pulse_ring):
		pulse_ring.visible = true
		pulse_ring.scale = Vector3.ONE * (2.4 if reduced_motion else 1.0)
		_pulse_material.albedo_color.a = 0.88


func set_stunned(seconds: float) -> void:
	if is_instance_valid(stun_ring):
		stun_ring.visible = seconds > 0.0


func advance(delta: float, paused: bool = false, reduce_motion: bool = false) -> void:
	# No autonomous process callback: preview, finish and menus cannot keep a
	# separate effects clock running after the actual race has stopped.
	if paused or not is_finite(delta) or delta < 0.0:
		return
	reduced_motion = reduce_motion
	elapsed += delta
	_apply_motion()
	if pulse_age < 0.72 and is_instance_valid(pulse_ring):
		pulse_age = minf(0.72, pulse_age + delta)
		var progress: float = clampf(pulse_age / 0.72, 0.0, 1.0)
		pulse_ring.visible = progress < 1.0
		pulse_ring.scale = Vector3.ONE * (2.4 if reduced_motion else 1.0 + progress * 8.5)
		_pulse_material.albedo_color.a = 0.75 * (1.0 - progress)


func _apply_motion() -> void:
	if _held_symbols.has(held_item):
		SYMBOLS.advance(_held_symbols[held_item], elapsed, reduced_motion)
	if is_instance_valid(stun_ring):
		stun_ring.rotation.y = 0.0 if reduced_motion else elapsed * 3.0
	if is_instance_valid(shield_bubble):
		var scale_value: float = 1.0 if reduced_motion else 1.0 + sin(elapsed * 4.0) * 0.035
		shield_bubble.scale = Vector3.ONE * scale_value
		shield_ring.scale = Vector3.ONE * scale_value
	if reduced_motion:
		if is_instance_valid(warning_ring):
			warning_ring.scale = Vector3.ONE
		if is_instance_valid(pulse_ring):
			pulse_ring.scale = Vector3.ONE * 2.4


func visual_state() -> Dictionary:
	return {
		"held_item": held_item,
		"symbol_kind": held_item if _held_symbols.has(held_item) else "",
		"clock": elapsed,
		"pulse_age": pulse_age,
		"item_visible": is_instance_valid(item_orb) and item_orb.visible,
		"shield_visible": is_instance_valid(shield_bubble) and shield_bubble.visible,
		"shield_ring_visible": is_instance_valid(shield_ring) and shield_ring.visible,
		"warning_visible": is_instance_valid(warning_ring) and warning_ring.visible,
		"pulse_visible": is_instance_valid(pulse_ring) and pulse_ring.visible,
		"stun_visible": is_instance_valid(stun_ring) and stun_ring.visible,
	}
