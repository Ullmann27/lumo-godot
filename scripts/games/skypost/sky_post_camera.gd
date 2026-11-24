extends Camera3D
## Soft chase camera behind the glider: follows heading and height with springs,
## leans a little into turns, widens its view when the glider is fast and looks
## down at the address boards while a letter is on board near its district.

var reduced_motion: bool = false
var look_down: float = 0.0
var _position := Vector3.ZERO
var _look := Vector3.ZERO
var _roll: float = 0.0
var _kick: float = 0.0
var _fov_base: float = 64.0


func _ready() -> void:
	fov = _fov_base
	near = 0.25
	far = 1400.0


## [param flight]: sky_post_flight.gd state. [param snap] jumps without smoothing.
func follow(flight, delta: float, snap: bool = false) -> void:
	clear_offsets()
	var heading: Vector3 = flight.flat_forward()
	var climb: float = clampf(flight.pitch, -0.5, 0.5)
	var distance: float = 9.6 + clampf((flight.speed - 14.0) * 0.12, -0.6, 1.8)
	var height: float = 3.1 - climb * 2.2 + look_down * 3.5
	var wanted: Vector3 = flight.pos - heading * distance + Vector3(0, height, 0)
	var focus: Vector3 = (
		flight.pos + heading * 7.0 + Vector3(0, 1.1 + climb * 3.0 - look_down * 4.0, 0)
	)
	if snap:
		_position = wanted
		_look = focus
		_roll = 0.0
	else:
		var lag: float = 1.0 - exp(-(5.0 if not reduced_motion else 3.0) * delta)
		_position = _position.lerp(wanted, lag)
		_look = _look.lerp(focus, 1.0 - exp(-8.0 * delta))
		var lean: float = -flight.bank * (0.0 if reduced_motion else 0.28)
		_roll = lerpf(_roll, lean, 1.0 - exp(-4.0 * delta))
	var shake := Vector3.ZERO
	if _kick > 0.0:
		_kick = maxf(0.0, _kick - delta * 2.5)
		if not reduced_motion:
			shake = Vector3(sin(_kick * 70.0), cos(_kick * 53.0), 0) * _kick * 0.12
	var basis := Basis.looking_at((_look - _position).normalized(), Vector3.UP)
	basis = basis * Basis(Vector3.BACK, _roll)
	global_transform = Transform3D(basis, _position + shake)
	var fast: float = clampf((flight.speed - 14.0) / 12.0, 0.0, 1.0)
	var target_fov: float = _fov_base + (0.0 if reduced_motion else fast * 12.0)
	fov = lerpf(fov, target_fov, 1.0 - exp(-3.0 * delta)) if not snap else target_fov


func kick(amount: float) -> void:
	_kick = maxf(_kick, amount)


## Framing for the menu stage and the result: the glider seen from the side front.
func show_glider(
	glider: Node3D, side: float, distance: float, height: float, aim_height: float = 1.1
) -> void:
	var origin: Vector3 = glider.global_position
	var forward: Vector3 = -glider.global_transform.basis.z
	var right: Vector3 = glider.global_transform.basis.x
	var at: Vector3 = (
		origin + forward * distance * 0.75 + right * side * distance + Vector3(0, height, 0)
	)
	look_at_from_position(at, origin + Vector3(0, aim_height, 0), Vector3.UP)
	_position = at
	_look = origin + Vector3(0, aim_height, 0)
	_roll = 0.0


## Menu stage: the glider seen from the front left, placed inside [param rect]
## (viewport units) by shifting the lens, so the menu panels never cover it.
func frame_glider(glider: Node3D, rect: Rect2, view: Vector2, radius: float = 4.4) -> void:
	if rect.size.x < 8.0 or rect.size.y < 8.0 or view.y <= 0.0:
		return
	var centre: Vector3 = glider.global_position + Vector3(0, 1.1, 0)
	var forward: Vector3 = -glider.global_transform.basis.z
	var right: Vector3 = glider.global_transform.basis.x
	var direction: Vector3 = (forward * 0.9 - right * 0.62 + Vector3(0, 0.34, 0)).normalized()
	var half: float = tan(deg_to_rad(_fov_base) * 0.5)
	var tan_v: float = half * rect.size.y / view.y
	var tan_h: float = half * rect.size.x / view.y
	var distance: float = radius / maxf(0.05, minf(tan_v, tan_h))
	fov = _fov_base
	look_at_from_position(centre + direction * distance, centre, Vector3.UP)
	var per_unit: float = 2.0 * distance * half / view.y
	var shift: Vector2 = rect.get_center() - view * 0.5
	h_offset = -shift.x * per_unit
	v_offset = shift.y * per_unit
	_position = global_position
	_look = centre
	_roll = 0.0


func clear_offsets() -> void:
	h_offset = 0.0
	v_offset = 0.0
