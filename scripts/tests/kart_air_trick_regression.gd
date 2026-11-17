extends SceneTree
## Air-trick scoring stays visual/additive: no change to flight math or saves.

const TRICK = preload("res://scripts/games/kart_air_trick.gd")
const PRECISION = preload("res://scripts/games/kart_precision_jump.gd")
const STUNT = preload("res://scripts/games/kart_sonnenhafen_stunt_sequence.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("[AirTrick] FAIL: ", label)


func _run() -> void:
	var flip: Dictionary = TRICK.start(0.0)
	_check(str(flip.kind) == TRICK.KIND_FLIP, "neutral steer starts a salto")
	var roll: Dictionary = TRICK.start(-0.8)
	_check(str(roll.kind) == TRICK.KIND_ROLL, "left steer starts a rolle")
	_check(float(roll.sign) < 0.0, "roll keeps steer sign")
	var mid: Dictionary = TRICK.advance(flip, 0.2)
	_check(str(mid.state) == TRICK.STATE_ACTIVE, "partial spin stays active")
	_check(not bool(mid.completed), "partial spin is not complete")
	_check(TRICK.visual_euler(mid) != Vector3.ZERO, "partial spin has visual rotation")
	var done: Dictionary = mid
	for _i in range(20):
		done = TRICK.advance(done, 0.1)
	_check(bool(done.completed), "full spin completes")
	_check(str(done.state) == TRICK.STATE_DONE, "completed state is done")
	_check(is_equal_approx(float(done.spun), TAU), "completed spin is one turn")
	var bonus: Dictionary = TRICK.landing_bonus(done, PRECISION.LANDING_ZONE)
	_check(bool(bonus.rewarded), "zone landing rewards a finished trick")
	_check(float(bonus.boost) == TRICK.LANDING_BONUS_SECONDS, "bonus seconds stay 0.9")
	_check(str(bonus.label).find("Turbo") >= 0, "reward message mentions turbo")
	_check(not bool(TRICK.landing_bonus(done, PRECISION.LANDING_SHORT).rewarded), "short landing has no trick bonus")
	_check(not bool(TRICK.landing_bonus(done, PRECISION.LANDING_LONG).rewarded), "long landing has no trick bonus")
	_check(not bool(TRICK.landing_bonus(mid, PRECISION.LANDING_ZONE).rewarded), "unfinished trick has no bonus")
	_check(not bool(TRICK.landing_bonus({}, PRECISION.LANDING_ZONE).rewarded), "no trick means no bonus")
	# Flight model of the Sonnenhafen precision ramp is unchanged.
	var kicker := {
		"angle": atan2(STUNT.JUMP_RAMP_HEIGHT, STUNT.JUMP_RAMP_LENGTH),
		"height": STUNT.JUMP_RAMP_HEIGHT,
		"flight_gravity": STUNT.PRECISION_GRAVITY,
		"lift_bonus": 0.0,
		"max_lift": 1000.0,
		"landing_min": STUNT.PRECISION_LANDING_START_M,
		"landing_max": STUNT.PRECISION_LANDING_END_M,
		"landing_slope": 0.0,
	}
	var at_20: float = PRECISION.landing_distance(20.5, kicker)
	_check(at_20 > STUNT.PRECISION_LANDING_START_M, "reference speed still reaches the zone")
	_check(at_20 < STUNT.PRECISION_LANDING_END_M + 20.0, "reference speed stays a readable arc")
	_check(STUNT.applies({"track_id": "sonnenhafen"}), "stunt sequence still targets Sonnenhafen")
	_check(not STUNT.applies({"track_id": "zauberwald"}), "other tracks stay unchanged")
	if failures.is_empty():
		print("[AirTrick] PASS: ", checks, " checks")
		quit(0)
	else:
		print("[AirTrick] FAIL: ", failures)
		quit(1)
