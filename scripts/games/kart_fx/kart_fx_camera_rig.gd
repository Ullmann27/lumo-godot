extends RefCounted
## Body language of the chase camera, laid on top of the race camera at render
## time by kart_drive_fx (and taken off again before the next race tick, so the
## race camera's own smoothing never sees it):
##   surge   the camera sinks back on hard acceleration and leans in on braking
##   heave   a soft, spring-damped dip when the kart lands (no shaking), a little
##           lift while it flies
##   sway    a gentle sideways lag while drifting
##   rumble  a fine, rhythmic tremor while the tyres run over a kerb or verge
##   fov     up to +2.5 degrees while the kart pulls hard
## Springs are integrated in fixed substeps, so the motion is the same at every
## frame rate. Reduced motion: everything stays at zero.

## Camera-local metres (+z is behind the camera's view direction).
const SURGE_BACK := 0.38
const SURGE_FORWARD := 0.26
const HEAVE_DOWN := 0.34
const AIR_LIFT := 0.14
const SWAY := 0.16
const RUMBLE := 0.022
const FOV_MAX := 2.5
## Accelerations of the arcade drivetrain (kart_powertrain: 40 m/s² thrust,
## 80 m/s² brake) that give the full pull.
const FULL_THRUST := 40.0
const FULL_BRAKE := 60.0
const SUBSTEP := 1.0 / 120.0

var surge: float = 0.0
var heave: float = 0.0
var sway: float = 0.0
var rumble: float = 0.0
var fov: float = 0.0
var landings: int = 0
var peak_dip: float = 0.0
var _surge_v: float = 0.0
var _heave_v: float = 0.0
var _sway_v: float = 0.0
var _phase: float = 0.0
var _flying: bool = false


func reset() -> void:
	surge = 0.0
	heave = 0.0
	sway = 0.0
	rumble = 0.0
	fov = 0.0
	_surge_v = 0.0
	_heave_v = 0.0
	_sway_v = 0.0
	_phase = 0.0
	_flying = false


## [param accel] smoothed longitudinal acceleration (m/s²), [param slide]
## -1..1 drift side, [param ground_rumble] 0..1 kerb/verge contact.
func advance(
	step: float, accel: float, airborne: bool, slide: float, ground_rumble: float, speed: float
) -> void:
	if step <= 0.0:
		return
	var target_surge: float = 0.0
	if accel > 0.0:
		target_surge = clampf(accel / FULL_THRUST, 0.0, 1.0) * SURGE_BACK
	else:
		target_surge = -clampf(-accel / FULL_BRAKE, 0.0, 1.0) * SURGE_FORWARD
	var target_heave: float = AIR_LIFT if airborne else 0.0
	_flying = airborne
	var target_sway: float = clampf(slide, -1.0, 1.0) * SWAY
	var steps: int = maxi(1, ceili(step / SUBSTEP))
	var h: float = step / float(steps)
	for _i in range(steps):
		# Surge: critically damped, a little slower than the drivetrain.
		_surge_v += (-(6.0 * 6.0) * (surge - target_surge) - 2.0 * 6.0 * _surge_v) * h
		surge += _surge_v * h
		# Heave: slightly under-damped, one soft rebound after a landing.
		_heave_v += (-(7.5 * 7.5) * (heave - target_heave) - 2.0 * 0.62 * 7.5 * _heave_v) * h
		heave = clampf(heave + _heave_v * h, -HEAVE_DOWN, AIR_LIFT * 1.6)
		_sway_v += (-(5.0 * 5.0) * (sway - target_sway) - 2.0 * 5.0 * _sway_v) * h
		sway += _sway_v * h
	peak_dip = minf(peak_dip, heave)
	rumble = move_toward(rumble, clampf(ground_rumble, 0.0, 1.0), step * 9.0)
	# One tremor per kerb ridge (about every 0.7 m of road).
	_phase = fposmod(_phase + step * absf(speed) / 0.7 * TAU, TAU * 64.0)
	var target_fov: float = clampf(accel / FULL_THRUST, 0.0, 1.0) * FOV_MAX
	fov = move_toward(fov, target_fov, step * (6.0 if target_fov > fov else 3.0))


## The kart touched down with [param strength] 0..1 (sink speed mapped by the caller).
func land(strength: float) -> void:
	landings += 1
	_heave_v -= 1.4 + 3.2 * clampf(strength, 0.0, 1.0)


## Camera-local offset for this frame.
func offset() -> Vector3:
	var tremor: float = (sin(_phase) + 0.45 * sin(_phase * 2.3 + 0.7)) * RUMBLE * rumble
	return Vector3(sway, heave + tremor, surge)


func is_active() -> bool:
	return offset().length_squared() > 1.0e-8 or absf(fov) > 0.001
