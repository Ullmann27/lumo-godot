extends RefCounted
## Fahren im Abenteuer-Parcours mit der Fahrphysik von LUMO Kart.
##
## Die ebene Fahrdynamik (Gas, Bremse, Rückwärts, Lenkrate, Haftung, Drift, Turbo)
## übernimmt Wort für Wort die Formeln aus kart_island.gd `_drive_player` und nutzt
## dieselben Quellen: POWERTRAIN (Höchsttempo, Beschleunigung), die Werkstatt-Faktoren
## des gewählten Karts und RACE_RULES (Driftstufen). parcours_drive_parity_regression.gd
## fährt beide mit denselben Eingaben und vergleicht Tempo und Richtung Bild für Bild.
## Neu ist nur der Boden: statt des Streckenbands fragt das Kart parcours_course.gd
## nach Platten, Geländern, Hindernissen und beweglichen Teilen.

const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const RACE_RULES = preload("res://scripts/games/kart_items/kart_race_rules.gd")
const COURSE = preload("res://scripts/games/parcours/parcours_course.gd")
## Wie kart_island.gd (JUMP_GRAVITY, BOOST_ACCELERATION_MULTIPLIER, REVERSE_*).
const GRAVITY: float = 30.0
const BOOST_ACCELERATION_MULTIPLIER: float = 2.0
const REVERSE_ENGAGE_SECONDS: float = 0.28
const REVERSE_SPEED: float = 5.0
## Bis zu dieser Stufe folgt das Kart einer abfallenden Fläche statt abzuheben.
const SNAP_DOWN: float = 0.65
## So tief unter der letzten Fahrbahn gilt ein Sturz als Sturz (dann Rettung).
const FALL_DEPTH: float = 7.0

var position: Vector3 = Vector3.ZERO
var heading: float = 0.0
var speed: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var vertical_speed: float = 0.0
var airborne: bool = false
var air_time: float = 0.0
var drifting: bool = false
var drift_charge: float = 0.0
var boost_time: float = 0.0
var boosts: int = 1
var landing_settle: float = 0.0
var reverse_hold_time: float = 0.0
var bump_time: float = 0.0
var hit: Dictionary = {}
var last_ground_y: float = 0.0
var fallen: bool = false
var basis: Basis = Basis.IDENTITY
var rail_hits: int = 0
var bumps: int = 0
var jumps: int = 0
var landings: int = 0
var drift_tier_count: Array[int] = [0, 0, 0]
## Werkstatt-Faktoren des gewählten Karts (TUNING.multipliers).
var factors: Dictionary = {}
var difficulty: String = "gemuetlich"
## Parcours-Tempo relativ zum Renntempo (siehe parcours_course.gd `pace`).
var pace: float = 0.42
## Letzte Ereignisse dieses Schritts: land, jump, rail, bump, fall, drift_turbo.
var events: PackedStringArray = []
## Wahr, solange eine Warteplatte das Kart anhält.
var holding: bool = false
var _ground_vy: float = 0.0


func factor(name: String, fallback: float = 1.0) -> float:
	return float(factors.get(name, fallback))


func place(at: Vector3, facing: float) -> void:
	position = at
	heading = facing
	speed = 0.0
	velocity = Vector3.ZERO
	vertical_speed = 0.0
	airborne = false
	air_time = 0.0
	drifting = false
	drift_charge = 0.0
	fallen = false
	bump_time = 0.0
	landing_settle = 0.0
	_ground_vy = 0.0
	last_ground_y = at.y
	hit = {}


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


func top_speed() -> float:
	var rules: Dictionary = CATALOG.entry(CATALOG.DIFFICULTIES, difficulty)
	return POWERTRAIN.top_speed(factors, float(rules.speed)) * pace


func press_drift() -> void:
	drifting = true


## Driftturbo wie kart_island.gd `_release_drift`. Liefert die Stufe oder -1.
func release_drift() -> int:
	drifting = false
	var tier: int = -1
	if drift_charge >= RACE_RULES.DRIFT_TIERS[0]:
		tier = RACE_RULES.drift_tier(drift_charge)
		drift_tier_count[tier] += 1
		boost_time = maxf(boost_time, RACE_RULES.DRIFT_BOOST_SECONDS[tier] * factor("boost_time"))
		events.append("drift_turbo")
	drift_charge = 0.0
	return tier


## Lumo-Boost wie kart_island.gd `_boost` (3,2 s mal Turbo-Faktor).
func use_boost() -> bool:
	if boosts <= 0:
		return false
	boosts -= 1
	boost_time = 3.2 * factor("boost_time")
	return true


## Ebene Fahrdynamik eines Schritts. `target_scale` entspricht dem Arena-Faktor in
## kart_island.gd (dort 0,68), `cap` ist ein Tempodeckel der Fahrbahn (0 = keiner).
func planar_step(
	delta: float,
	axis: float,
	braking: float,
	throttle: float,
	manual_gas: bool,
	target_scale: float,
	cap: float = 0.0,
	hold_still: bool = false
) -> void:
	var rules: Dictionary = CATALOG.entry(CATALOG.DIFFICULTIES, difficulty)
	var target: float = POWERTRAIN.top_speed(factors, float(rules.speed)) * target_scale
	if cap > 0.0:
		target = minf(target, cap)
	var boost_active: bool = boost_time > 0.0
	if boost_active:
		target *= 1.0 + 0.42 * factor("boost_power")
	if braking > 0.5 and not airborne and not manual_gas:
		if speed <= 0.9:
			reverse_hold_time += delta
		else:
			reverse_hold_time = 0.0
		if speed < -0.1 or (reverse_hold_time >= REVERSE_ENGAGE_SECONDS and not hold_still):
			target = -REVERSE_SPEED
		else:
			target = 0.0
	else:
		reverse_hold_time = 0.0
		target *= throttle
		target *= 1.0 - braking * 0.94
	if bump_time > 0.0:
		target *= factor("stability", 0.45)
	var acceleration: float = POWERTRAIN.acceleration(factors, braking > 0.1)
	if boost_active and target > speed:
		acceleration *= BOOST_ACCELERATION_MULTIPLIER
	if not airborne or boost_active:
		speed = move_toward(speed, target, delta * acceleration)
	var grip_turn: float = clampf(absf(speed) / (8.0 * POWERTRAIN.PACE_SCALE), 0, 1)
	var turn_rate: float = (
		(1.42 + (0.35 if drifting else 0.0)) * factor("turn") * grip_turn * POWERTRAIN.PACE_SCALE
	)
	if speed < 0.0:
		turn_rate = -turn_rate
	if airborne:
		turn_rate *= 0.35
	if landing_settle > 0.0:
		turn_rate *= lerpf(1.0, 0.62, clampf(landing_settle / 0.32, 0.0, 1.0))
		landing_settle = maxf(0.0, landing_settle - delta)
	heading -= axis * turn_rate * delta
	var ahead: Vector3 = forward()
	var grip: float = (3.1 if drifting else 9.0 * factor("grip")) * POWERTRAIN.PACE_SCALE
	velocity = velocity.lerp(ahead * speed, minf(1, delta * grip))
	if drifting and speed > 6 and not airborne:
		drift_charge = minf(3, drift_charge + delta * absf(axis) * POWERTRAIN.PACE_SCALE)


## Lenkhilfe auf „Entdecken“ wie kart_island.gd am Fahrbahnrand: nur an offenen Kanten.
func assisted_axis(axis: float, course) -> float:
	if difficulty != "gemuetlich" or hit.is_empty() or airborne:
		return axis
	var slab: Dictionary = course.slabs[int(hit.slab)]
	var lateral: float = float(hit.lateral)
	var open_side: bool = not bool(slab.rail_right if lateral > 0.0 else slab.rail_left)
	if not open_side or absf(lateral) <= float(hit.width) * 0.31:
		return axis
	var f: Vector3 = hit.forward
	var along: float = atan2(-f.x, -f.z)
	if speed < 0.0:
		return axis
	var correction: float = angle_difference(heading, along)
	return clampf(axis - correction * 0.5 - signf(lateral) * 0.30, -1.0, 1.0)


## Ein ganzer Fahrschritt im Parcours. `t0`→`t1` ist die Kurszeit dieses Schritts.
func step(
	delta: float,
	axis: float,
	braking: float,
	throttle: float,
	manual_gas: bool,
	course,
	t0: float,
	t1: float,
	state: Dictionary
) -> void:
	events = PackedStringArray()
	boost_time = maxf(0.0, boost_time - delta)
	bump_time = maxf(0.0, bump_time - delta)
	_carry(course, t0, t1, state)
	axis = assisted_axis(axis, course)
	var cap: float = 0.0
	holding = false
	if not hit.is_empty() and not airborne:
		var slab: Dictionary = course.slabs[int(hit.slab)]
		cap = float(slab.get("cap", 0.0))
		var hold: String = str(slab.get("hold_unless", ""))
		var hold_from: float = float(slab.get("hold_from", 0.0))
		if (
			not hold.is_empty()
			and not bool(state.get(hold, false))
			and float(hit.along) >= hold_from
		):
			# Lumo wartet hier von selbst (Ampel rot): Aufzug kommt bzw. fährt gerade.
			cap = 0.001
			holding = true
		var push: float = float(slab.get("boost_to", 0.0))
		if push > 0.0 and speed > 0.5 and speed < push:
			# Schwungband vor einer Schanze: hebt das Tempo auf das sichere Maß.
			speed = move_toward(speed, push, delta * 60.0)
	planar_step(delta, axis, braking, throttle, manual_gas, pace, cap, true)
	position += velocity * delta
	_blockers(course, t1, state)
	_vertical(delta, course, t1, state)
	if not airborne:
		_rails(course, t1, state)
	_orient()


## Auf beweglichen Platten fährt das Kart mit (Aufzug hebt, Drehscheibe dreht mit).
func _carry(course, t0: float, t1: float, state: Dictionary) -> void:
	if airborne or hit.is_empty():
		return
	var index: int = int(hit.slab)
	if (course.slabs[index].get("motion", {}) as Dictionary).is_empty():
		return
	var before: Transform3D = course.slab_transform(index, t0, state)
	var after: Transform3D = course.slab_transform(index, t1, state)
	var moved: Transform3D = after * before.affine_inverse()
	position = moved * position
	var yaw: float = moved.basis.get_euler().y
	heading += yaw
	velocity = Basis(Vector3.UP, yaw) * velocity


func _blockers(course, t: float, state: Dictionary) -> void:
	var contact: Dictionary = course.blocker_contact(position + Vector3.UP * 0.5, t, state)
	if contact.is_empty():
		return
	position += contact.push as Vector3
	var normal: Vector3 = contact.normal
	var into: float = -velocity.dot(normal)
	if into > 0.0:
		velocity += normal * into * 1.25
		speed *= clampf(1.0 - into * 0.03, 0.55, 0.95)
		if into > 3.0 and bump_time <= 0.0:
			bump_time = 0.6
			bumps += 1
			events.append("bump")


func _vertical(delta: float, course, t: float, state: Dictionary) -> void:
	var probe: Dictionary = course.ground(position, t, state)
	if not airborne:
		var before_y: float = position.y
		if not probe.is_empty() and float(probe.height) >= position.y - SNAP_DOWN:
			position.y = float(probe.height)
			_ground_vy = (position.y - before_y) / maxf(delta, 0.0001)
			hit = probe
			last_ground_y = position.y
			return
		airborne = true
		air_time = 0.0
		vertical_speed = clampf(_ground_vy, -4.0, 14.0)
		hit = {}
		jumps += 1
		events.append("jump")
	air_time += delta
	vertical_speed -= GRAVITY * delta
	position.y += vertical_speed * delta
	if not probe.is_empty() and vertical_speed <= 0.0 and position.y <= float(probe.height) + 0.02:
		position.y = float(probe.height)
		airborne = false
		landing_settle = 0.32
		vertical_speed = 0.0
		_ground_vy = 0.0
		hit = probe
		last_ground_y = position.y
		landings += 1
		events.append("land")
		return
	if position.y < last_ground_y - FALL_DEPTH or position.y < float(course.kill_y):
		fallen = true
		events.append("fall")


func _rails(course, t: float, state: Dictionary) -> void:
	var contact: Dictionary = course.rail_contact(hit, position, t, state)
	if contact.is_empty():
		return
	position += contact.push as Vector3
	var normal: Vector3 = contact.normal
	var into: float = -velocity.dot(normal)
	if into <= 0.0:
		return
	rail_hits += 1
	velocity += normal * into * 1.08
	speed *= clampf(1.0 - into * 0.022, 0.80, 0.99)
	var f: Vector3 = hit.forward
	var along: float = atan2(-f.x, -f.z)
	if absf(angle_difference(heading, along)) > PI / 2:
		along += PI
	heading = lerp_angle(heading, along, minf(1.0, 0.38 + into * 0.05))
	if into > 2.0:
		events.append("rail")


func _orient() -> void:
	var normal: Vector3 = Vector3.UP
	if not hit.is_empty() and not airborne:
		normal = hit.normal
	var ahead: Vector3 = forward()
	var right: Vector3 = ahead.cross(normal).normalized()
	var ground_forward: Vector3 = normal.cross(right).normalized()
	basis = Basis(right, normal, -ground_forward).orthonormalized()
	if airborne:
		basis = basis.rotated(right, clampf(vertical_speed * 0.05, -0.32, 0.32)).orthonormalized()


func snapshot() -> Dictionary:
	return {
		"position": position,
		"heading": heading,
		"boosts": boosts,
		"drift_tier_count": drift_tier_count.duplicate()
	}
