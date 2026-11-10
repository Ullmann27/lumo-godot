extends RefCounted
## Mid-air stunts on jump ramps. The spin is visual only: flight speed,
## gravity and landing distances stay exactly as kart_precision_jump models
## them. A finished trick adds a landing boost. Original LUMO moves, no
## borrowed character animations.
##
## kind "salto" = forward/back flip (neutral steer), "rolle" = barrel roll.

const KIND_FLIP := "salto"
const KIND_ROLL := "rolle"
const STATE_IDLE := "idle"
const STATE_ACTIVE := "active"
const STATE_DONE := "done"
const SPIN_RATE := 7.6
const LANDING_BONUS_SECONDS := 0.9


static func start(steer: float) -> Dictionary:
	var rolling: bool = absf(steer) > 0.35
	return {
		"state": STATE_ACTIVE,
		"kind": KIND_ROLL if rolling else KIND_FLIP,
		"sign": -1.0 if steer < 0.0 else 1.0,
		"spun": 0.0,
		"duration": 0.0,
		"completed": false,
	}


static func advance(trick: Dictionary, delta: float, rate: float = SPIN_RATE) -> Dictionary:
	if trick.is_empty() or str(trick.get("state", "")) != STATE_ACTIVE:
		return trick
	var next: Dictionary = trick.duplicate(true)
	next["duration"] = float(next.get("duration", 0.0)) + delta
	var spun: float = float(next.get("spun", 0.0)) + rate * delta
	if spun >= TAU:
		next["spun"] = TAU
		next["state"] = STATE_DONE
		next["completed"] = true
	else:
		next["spun"] = spun
	return next


static func visual_euler(trick: Dictionary) -> Vector3:
	if trick.is_empty():
		return Vector3.ZERO
	var spun: float = float(trick.get("spun", 0.0))
	if str(trick.get("kind", "")) == KIND_ROLL:
		return Vector3(0.0, 0.0, spun * float(trick.get("sign", 1.0)))
	return Vector3(spun * float(trick.get("sign", 1.0)), 0.0, 0.0)


static func landing_bonus(trick: Dictionary, precision_result: String) -> Dictionary:
	# Failed landings keep their existing penalty and get no extra turbo.
	if trick.is_empty() or not bool(trick.get("completed", false)):
		return {"boost": 0.0, "label": "", "rewarded": false}
	if precision_result == "zu_weit" or precision_result == "zu_kurz":
		return {"boost": 0.0, "label": "", "rewarded": false}
	var kind: String = str(trick.get("kind", KIND_FLIP))
	var label: String = "Rolle gelandet! Extra-Turbo!" if kind == KIND_ROLL else "Salto gelandet! Extra-Turbo!"
	return {
		"boost": LANDING_BONUS_SECONDS,
		"label": label,
		"rewarded": true,
		"kind": kind,
	}
