extends Node3D
## One place for "drive-through" juice: particle bursts, screen flash, camera push
## and sound hooks. Pooled CPU particles keep it cheap on mid-range Android phones;
## reduced motion keeps colour feedback but drops shake, FOV punch and big flashes.

signal sound_hook(event_id: String, fallback_effect: String)

const POOL_SIZE: int = 6
## Event id -> [colour, particle amount, flash strength, camera kick, fallback sound].
const EVENTS: Dictionary = {
	"item_box": [Color("ffe680"), 26, 0.22, 0.35, "item"],
	"boost_ring": [Color("66f7e8"), 34, 0.32, 1.0, "boost"],
	"boost_pad": [Color("4fe6ff"), 18, 0.12, 0.55, "boost"],
	"drift_blue": [Color("4fb8ff"), 18, 0.10, 0.45, "drift"],
	"drift_orange": [Color("ff9a3c"), 24, 0.14, 0.65, "drift"],
	"drift_purple": [Color("c77dff"), 32, 0.20, 0.85, "drift"],
	"slipstream": [Color("d6f6ff"), 16, 0.10, 0.55, "boost"],
	"trick": [Color("ffd166"), 22, 0.12, 0.25, "drift"],
	"trick_landing": [Color("ffd166"), 30, 0.20, 0.8, "boost"],
	"rocket_launch": [Color("ff6b8b"), 14, 0.0, 0.2, "item"],
	"hit_spin": [Color("ffffff"), 30, 0.30, 0.9, "collision"],
	"blocked": [Color("66e8ff"), 26, 0.22, 0.3, "item"],
	"combo": [Color("ff7ad9"), 28, 0.18, 0.6, "boost"],
	"aurora": [Color("8affd8"), 36, 0.30, 0.8, "boost"],
	"magnet": [Color("ffe066"), 20, 0.12, 0.2, "item"],
}

var reduced_motion: bool = false
var particle_scale: float = 1.0
var flash_rect: ColorRect
var flash_alpha: float = 0.0
var flash_color: Color = Color.WHITE
var kick: float = 0.0
var shake: float = 0.0
var _pool: Array[CPUParticles3D] = []
var _cursor: int = 0
var _time: float = 0.0
var fired: Dictionary = {}


func setup(overlay_parent: Node, quality: String, reduced: bool) -> void:
	reduced_motion = reduced
	particle_scale = 1.0 if quality == "high" else (0.65 if quality == "medium" else 0.4)
	if is_instance_valid(overlay_parent) and not is_instance_valid(flash_rect):
		flash_rect = ColorRect.new()
		flash_rect.name = "KartScreenFlash"
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash_rect.color = Color(1, 1, 1, 0)
		overlay_parent.add_child(flash_rect)
	if _pool.is_empty():
		var quad := QuadMesh.new()
		quad.size = Vector2(0.22, 0.22)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		quad.material = material
		for index in range(POOL_SIZE):
			var particles := CPUParticles3D.new()
			particles.name = "Burst%d" % index
			particles.emitting = false
			particles.one_shot = true
			particles.explosiveness = 0.92
			particles.lifetime = 0.7
			particles.mesh = quad
			particles.direction = Vector3.UP
			particles.spread = 75.0
			particles.initial_velocity_min = 3.5
			particles.initial_velocity_max = 8.0
			particles.gravity = Vector3(0, -9.0, 0)
			particles.scale_amount_min = 0.6
			particles.scale_amount_max = 1.4
			var ramp := Gradient.new()
			ramp.set_color(0, Color(1, 1, 1, 1))
			ramp.set_color(1, Color(1, 1, 1, 0))
			particles.color_ramp = ramp
			particles.local_coords = false
			add_child(particles)
			_pool.append(particles)


## Fire a named event at a world position. Unknown ids are ignored (returns false).
func trigger(event_id: String, at: Vector3, strength: float = 1.0) -> bool:
	if not EVENTS.has(event_id):
		return false
	var spec: Array = EVENTS[event_id]
	fired[event_id] = int(fired.get(event_id, 0)) + 1
	if not _pool.is_empty():
		var particles: CPUParticles3D = _pool[_cursor]
		_cursor = (_cursor + 1) % _pool.size()
		particles.amount = maxi(4, int(float(spec[1]) * particle_scale * (0.5 if reduced_motion else 1.0)))
		particles.color = spec[0]
		particles.global_position = at
		particles.restart()
		particles.emitting = true
	var flash: float = float(spec[2]) * strength * (0.35 if reduced_motion else 1.0)
	if flash > flash_alpha:
		flash_alpha = flash
		flash_color = spec[0]
	if not reduced_motion:
		kick = maxf(kick, float(spec[3]) * strength)
		if event_id == "hit_spin":
			shake = maxf(shake, 0.35 * strength)
	sound_hook.emit(event_id, str(spec[4]))
	return true


func _process(delta: float) -> void:
	_time += delta
	flash_alpha = move_toward(flash_alpha, 0.0, delta * 1.6)
	kick = move_toward(kick, 0.0, delta * 2.2)
	shake = move_toward(shake, 0.0, delta * 1.4)
	if is_instance_valid(flash_rect):
		flash_rect.color = Color(flash_color, flash_alpha)
		flash_rect.visible = flash_alpha > 0.005


## Camera push: extra FOV degrees and a small positional shake for this frame.
func camera_fov_kick() -> float:
	return 0.0 if reduced_motion else kick * 7.0


func camera_shake() -> Vector3:
	if reduced_motion or shake <= 0.0:
		return Vector3.ZERO
	return Vector3(sin(_time * 53.0), sin(_time * 41.0 + 1.3), 0.0) * shake * 0.18


func _exit_tree() -> void:
	if is_instance_valid(flash_rect):
		flash_rect.queue_free()
