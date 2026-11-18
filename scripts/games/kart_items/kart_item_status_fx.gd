extends Node3D
## Sichtbare Laufzeit der Items ohne eigenes Bild am Kart (nur Darstellung):
##  - Sternmagnet: goldener Ring mit kreisenden Sternpunkten, solange er zieht
##  - Nordlicht-Lauf: grün-türkiser Lichtring um das Kart
## In der letzten Sekunde wird der Ring langsam schwächer („gleich vorbei“), ohne Blinken.
## Ruhige Bewegung: Ring steht still. Ein Draw-Call je Ring, gl_compatibility-tauglich.

const MAGNET_COLOR := Color("ffe066")
const AURORA_COLOR := Color("8affd8")

var reduced_motion: bool = false
var magnet_ring: MeshInstance3D
var aurora_ring: MeshInstance3D
var _time: float = 0.0


func _ready() -> void:
	name = "KartItemStatusFx"
	position = Vector3(0, 0.45, 0)
	magnet_ring = _ring("MagnetRing", MAGNET_COLOR, 1.55, 0.07, true)
	aurora_ring = _ring("AuroraRing", AURORA_COLOR, 1.75, 0.11, false)


func _ring(
	node_name: String, color: Color, radius: float, thickness: float, dotted: bool
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
	if dotted:
		# Sechs kleine Sternpunkte kreisen mit: „hier wird angezogen“.
		var dot := SphereMesh.new()
		dot.radius = 0.12
		dot.height = 0.24
		dot.radial_segments = 8
		dot.rings = 4
		for i in range(6):
			var star := MeshInstance3D.new()
			star.name = "Pull%d" % i
			star.mesh = dot
			star.material_override = material
			star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var angle: float = TAU * i / 6.0
			star.position = Vector3(cos(angle), 0.0, sin(angle)) * (radius + 0.45)
			ring.add_child(star)
	return ring


## Pro Physiktakt vom Rennen: verbleibende und gesamte Sekunden je Item.
func advance(
	delta: float, magnet_left: float, magnet_total: float, aurora_left: float, aurora_total: float
) -> void:
	_time += delta
	_show(magnet_ring, magnet_left, magnet_total, 2.4, 0.22)
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
