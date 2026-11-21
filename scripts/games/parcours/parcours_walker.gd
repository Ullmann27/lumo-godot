extends RefCounted
## Lumo zu Fuß im Parcours: freies Laufen auf denselben Platten wie das Kart, Sprung
## mit den Zahlen aus Lumo Lauf (run_tuning.gd: Sprungtempo, Schwerkraft, Koyotenzeit,
## Sprungpuffer). Die Felder heißen wie in run_player.gd, damit run_actor.gd – der echte
## geriggte Lumo – unverändert die Pose aus diesem Modell liest.

const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const WALK_SPEED: float = 6.2
const TURN_RATE: float = 11.0
const RADIUS: float = 0.45
const FALL_DEPTH: float = 6.0

var position: Vector3 = Vector3.ZERO
var heading: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var fallen: bool = false
var hit: Dictionary = {}
var last_ground_y: float = 0.0
# Felder für run_actor.gd
var speed: float = 0.0
var lat_v: float = 0.0
var vy: float = 0.0
var grounded: bool = true
var land_impact: float = 0.0
var dash_time: float = 0.0
var stumble_time: float = 0.0
var tumble_time: float = 0.0
var invulnerable: float = 0.0
var in_cart: bool = false
var loop_u: float = -1.0
var ride: Dictionary = {}
var jumps: int = 0
var _coyote: float = 0.0
var _buffer: float = 0.0
var _held: bool = false
var _hold: float = 0.0


func is_riding() -> bool:
	return false


func place(at: Vector3, facing: float) -> void:
	position = at
	heading = facing
	velocity = Vector3.ZERO
	vy = 0.0
	grounded = true
	fallen = false
	speed = 0.0
	last_ground_y = at.y
	hit = {}


func press_jump() -> void:
	_buffer = TUNING.JUMP_BUFFER_SECONDS
	_held = true


func release_jump() -> void:
	_held = false


## `move` ist die gewünschte Laufrichtung in Weltkoordinaten (x, z), Länge 0..1.
func step(delta: float, move: Vector2, course, t0: float, t1: float, state: Dictionary) -> void:
	land_impact = 0.0
	_carry(course, t0, t1, state)
	var wish := Vector3(move.x, 0.0, move.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	if wish.length() > 0.08:
		var target: float = atan2(-wish.x, -wish.z)
		heading = lerp_angle(heading, target, minf(1.0, TURN_RATE * delta))
	var accel: float = 40.0 if grounded else 18.0
	velocity = velocity.move_toward(wish * WALK_SPEED, accel * delta)
	speed = velocity.length()
	var right := Vector3(cos(heading), 0.0, -sin(heading))
	lat_v = velocity.dot(right)
	position += velocity * delta
	var contact: Dictionary = course.blocker_contact(position + Vector3.UP * 0.5, t1, state, RADIUS)
	if not contact.is_empty():
		position += contact.push as Vector3
		var n: Vector3 = contact.normal
		velocity -= n * minf(0.0, velocity.dot(n))
	_buffer = maxf(0.0, _buffer - delta)
	_coyote = maxf(0.0, _coyote - delta)
	var probe: Dictionary = course.ground(position, t1, state, 0.05)
	if grounded:
		if not probe.is_empty() and float(probe.height) >= position.y - 0.45:
			position.y = float(probe.height)
			hit = probe
			last_ground_y = position.y
			_coyote = TUNING.COYOTE_SECONDS
		else:
			grounded = false
			hit = {}
			vy = 0.0
	if _buffer > 0.0 and (grounded or _coyote > 0.0):
		grounded = false
		hit = {}
		vy = TUNING.JUMP_SPEED
		_hold = TUNING.JUMP_HOLD_SECONDS
		_buffer = 0.0
		_coyote = 0.0
		jumps += 1
	if not grounded:
		var gravity: float = TUNING.GRAVITY_FALL
		if vy > 0.0:
			gravity = TUNING.GRAVITY_HOLD if _held and _hold > 0.0 else TUNING.GRAVITY_RISE
		_hold = maxf(0.0, _hold - delta)
		vy -= gravity * delta
		position.y += vy * delta
		if not probe.is_empty() and vy <= 0.0 and position.y <= float(probe.height) + 0.02:
			land_impact = -vy
			position.y = float(probe.height)
			vy = 0.0
			grounded = true
			hit = probe
			last_ground_y = position.y
		elif position.y < last_ground_y - FALL_DEPTH or position.y < float(course.kill_y):
			fallen = true
	if grounded:
		var rail: Dictionary = course.rail_contact(hit, position, t1, state)
		if not rail.is_empty():
			position += rail.push as Vector3


func _carry(course, t0: float, t1: float, state: Dictionary) -> void:
	if not grounded or hit.is_empty():
		return
	var index: int = int(hit.slab)
	if (course.slabs[index].get("motion", {}) as Dictionary).is_empty():
		return
	var moved: Transform3D = (
		course.slab_transform(index, t1, state)
		* course.slab_transform(index, t0, state).affine_inverse()
	)
	position = moved * position
	heading += moved.basis.get_euler().y
