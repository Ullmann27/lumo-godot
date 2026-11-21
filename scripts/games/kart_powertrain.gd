extends RefCounted
## Shared straight-line drivetrain used by the race and the workshop simulation.
## Workshop figures use the race pace (identical on every difficulty since
## 18.11.2026), level asphalt, no items or rivals.
## A single pace scale is shared by the physical drive and the workshop. Lateral
## response scales linearly; acceleration/braking scale quadratically so doubling
## road speed does not double turning radius or quadruple the braking distance.
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const PACE_SCALE: float = 2.0
const DYNAMICS_SCALE: float = PACE_SCALE * PACE_SCALE
## Lenkrate in der Luft (Anteil der Bodenlenkung) und Seitenhaftung im Drift.
const AIR_TURN: float = 0.35
const DRIFT_GRIP: float = 3.1
## Beschleunigung während eines Turbos (Vielfaches der normalen).
const BOOST_ACCELERATION: float = 2.0


static func top_speed(factors: Dictionary, difficulty_speed: float = 1.0) -> float:
	return 20.5 * PACE_SCALE * float(factors.get("speed", 1.0)) * difficulty_speed


## Eigentempo-Faktor im Rennen. Alle Stufen fahren gleich schnell; Werkstatt und
## Prüfstand zeigen deshalb genau dieses Tempo.
static func race_pace() -> float:
	return float(CATALOG.entry(CATALOG.DIFFICULTIES, "flott").speed)


static func acceleration(factors: Dictionary, braking: bool) -> float:
	return (
		20.0 * DYNAMICS_SCALE * float(factors.get("brake", 1.0))
		if braking
		else 10.0 * DYNAMICS_SCALE * float(factors.get("accel", 1.0))
	)


## Straight asphalt stop using the same 60 Hz velocity response as _drive_player.
## The old workshop added a fixed 1.5 m lag, which became wrong at the new pace.
static func stopping_distance(factors: Dictionary, initial_speed: float = 20.0) -> float:
	if initial_speed <= 0.0:
		return 0.0
	var step: float = 1.0 / 60.0
	var brake: float = acceleration(factors, true)
	if brake <= 0.0:
		return INF
	var grip: float = clampf(9.0 * float(factors.get("grip", 1.0)) * PACE_SCALE * step, 0.0, 1.0)
	var scalar_speed: float = initial_speed
	var velocity: float = initial_speed
	var distance: float = 0.0
	while scalar_speed >= 0.5:
		scalar_speed = move_toward(scalar_speed, 0.0, brake * step)
		velocity = lerpf(velocity, scalar_speed, grip)
		distance += velocity * step
	return distance


static func report(factors: Dictionary) -> Dictionary:
	var maximum: float = top_speed(factors, race_pace())
	var target: float = 50.0 / 3.6
	var thrust: float = acceleration(factors, false)
	# The race integrates speed with move_toward, i.e. a constant acceleration ramp.
	return {
		"top_kmh": maximum * 3.6,
		"zero_fifty": target / thrust if maximum >= target else -1.0,
		"brake_metres": stopping_distance(factors, target),
		"boost_seconds": 3.2 * float(factors.get("boost_time", 1.0)),
	}


# ------------------------------------------------------------------ geteilte Fahrformeln
## Diese Formeln liest das Rennen (kart_island._drive_player) UND der Prüfstand
## (kart_dyno.gd). Ohne Leistungsteile sind alle zusätzlichen Faktoren 1,0 und die Werte
## genau wie vor den Teilen. Faktoren: drift_charge, drift_grip, air_turn, landing.


## Tempo-Aufschlag während eines Turbos (Faktor auf das Endtempo).
static func boost_scale(factors: Dictionary) -> float:
	return 1.0 + 0.42 * float(factors.get("boost_power", 1.0))


## Lenkrate in rad/s bei voller Lenkung.
static func turn_rate(factors: Dictionary, speed: float, drifting: bool, airborne: bool) -> float:
	var grip_turn: float = clampf(absf(speed) / (8.0 * PACE_SCALE), 0, 1)
	var rate: float = (
		(1.42 + (0.35 if drifting else 0.0))
		* float(factors.get("turn", 1.0))
		* grip_turn
		* PACE_SCALE
	)
	if speed < 0.0:
		rate = -rate
	if airborne:
		rate *= AIR_TURN * float(factors.get("air_turn", 1.0))
	return rate


## Wie schnell die Fahrtrichtung der Nase folgt (1/s); klein = rutscht mehr.
static func grip_rate(factors: Dictionary, drifting: bool) -> float:
	if drifting:
		return DRIFT_GRIP * float(factors.get("drift_grip", 1.0)) * PACE_SCALE
	return 9.0 * float(factors.get("grip", 1.0)) * PACE_SCALE


## Drift-Ladung pro Sekunde bei Lenkausschlag axis.
static func drift_charge_rate(factors: Dictionary, axis: float) -> float:
	return absf(axis) * PACE_SCALE * float(factors.get("drift_charge", 1.0))


## Dauer der Lenkberuhigung nach einer harten Landung (s) beim Aufprall impact (m/s).
static func landing_settle(factors: Dictionary, impact: float) -> float:
	return clampf((impact - 4.5) * 0.05, 0.10, 0.32) * float(factors.get("landing", 1.0))
