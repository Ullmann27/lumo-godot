extends RefCounted
## Pure arcade-racing rules for Lumo Kart: catch-up help, slipstream, drift tiers,
## jump tricks, boost combos and rival item decisions. No nodes, fully testable.

## Drift turbo tiers (seconds of charged steering): blau, orange, lila.
const DRIFT_TIERS: Array[float] = [0.8, 1.8, 2.7]
const DRIFT_BOOST_SECONDS: Array[float] = [1.0, 1.8, 2.5]
const DRIFT_TIER_NAMES: Array[String] = ["BLAU!", "ORANGE!", "LILA!"]
const DRIFT_TIER_COLORS: Array[Color] = [Color("4fb8ff"), Color("ff9a3c"), Color("c77dff")]

## Slipstream: stay close behind another kart to charge a short tow boost.
const SLIPSTREAM_MIN_GAP: float = 1.6
const SLIPSTREAM_MAX_GAP: float = 10.0
const SLIPSTREAM_LATERAL: float = 1.5
const SLIPSTREAM_MIN_SPEED: float = 10.0
const SLIPSTREAM_CHARGE_SECONDS: float = 1.1
const SLIPSTREAM_BOOST_SECONDS: float = 1.3

## Jump tricks: one trick per flight, landing turns it into a longer turbo.
const TRICK_SECONDS: float = 0.45
const TRICK_MIN_AIR_TIME: float = 0.08
const TRICK_LANDING_BOOST: float = 1.7
const PLAIN_LANDING_BOOST: float = 1.2

## Boost chain: drift/ring/pad/slipstream/trick boosts within this window grow a combo.
const COMBO_WINDOW: float = 2.6
const COMBO_BONUS_PER_STEP: float = 0.25
const COMBO_MAX: int = 6

## Catch-up limits (fractions of top speed).
const PLAYER_CATCH_UP_MAX := {"gemuetlich": 0.10, "normal": 0.07, "profi": 0.04}
const RIVAL_SLOW_MAX: float = 0.12
const RIVAL_PUSH_MAX: float = 0.10
const CATCH_UP_START_GAP: float = 18.0
const CATCH_UP_FULL_GAP: float = 90.0


static func drift_tier(charge: float) -> int:
	var tier: int = -1
	for index in range(DRIFT_TIERS.size()):
		if charge >= DRIFT_TIERS[index]:
			tier = index
	return tier


static func drift_label(charge: float) -> String:
	var tier: int = drift_tier(charge)
	return "HALTEN" if tier < 0 else DRIFT_TIER_NAMES[tier]


## 0..1 how far behind (in metres of race progress) a racer is.
static func gap_ratio(gap: float) -> float:
	return clampf((gap - CATCH_UP_START_GAP) / (CATCH_UP_FULL_GAP - CATCH_UP_START_GAP), 0.0, 1.0)


## Player top-speed multiplier: only helps when clearly behind the leader, never hinders.
static func player_catch_up(gap_to_leader: float, difficulty: String) -> float:
	var limit: float = float(PLAYER_CATCH_UP_MAX.get(difficulty, 0.07))
	return 1.0 + limit * gap_ratio(gap_to_leader)


## Rival speed multiplier relative to the player (positive = rival ahead).
## Far-ahead rivals ease off, far-behind rivals push; close racing is untouched.
static func rival_rubber_band(rival_lead: float, difficulty: String) -> float:
	var strength: float = 1.0 if difficulty == "gemuetlich" else (0.75 if difficulty == "normal" else 0.5)
	if rival_lead > 0.0:
		return 1.0 - RIVAL_SLOW_MAX * strength * gap_ratio(rival_lead)
	return 1.0 + RIVAL_PUSH_MAX * strength * gap_ratio(-rival_lead)


## Is `follower` in the wake of `leader`? Positions are world space, forward is the
## follower's driving direction.
static func in_slipstream(follower: Vector3, forward: Vector3, leader: Vector3, speed: float) -> bool:
	if speed < SLIPSTREAM_MIN_SPEED:
		return false
	var gap: Vector3 = leader - follower
	gap.y = 0.0
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	var ahead: float = gap.dot(flat_forward)
	if ahead < SLIPSTREAM_MIN_GAP or ahead > SLIPSTREAM_MAX_GAP:
		return false
	var side: float = (gap - flat_forward * ahead).length()
	return side <= SLIPSTREAM_LATERAL


## Combo step after a boost source fired `since_last` seconds after the previous one.
static func next_combo(current: int, since_last: float) -> int:
	if since_last <= COMBO_WINDOW:
		return mini(COMBO_MAX, current + 1)
	return 1


static func combo_bonus(combo: int) -> float:
	return COMBO_BONUS_PER_STEP * float(maxi(0, combo - 1))


## Rival item decision. `context` keys: ahead_gap (m to next racer ahead, INF if none),
## ahead_lateral (lateral offset to that racer), behind_gap (m to next racer behind),
## threatened (projectile incoming), player_near (m to player), place (1..6).
## Returns true when the rival should fire/use the item this frame.
static func rival_should_use(item: String, behaviour: String, context: Dictionary) -> bool:
	var ahead: float = float(context.get("ahead_gap", INF))
	var behind: float = float(context.get("behind_gap", INF))
	var threatened: bool = bool(context.get("threatened", false))
	match behaviour:
		"boost":
			return ahead > 1.0 and ahead < 30.0 or int(context.get("place", 1)) >= 4
		"shield":
			return threatened or float(context.get("player_near", INF)) < 7.0
		"pulse":
			return float(context.get("player_near", INF)) < 11.0
		"homing_projectile":
			return ahead > 3.0 and ahead < 60.0
		"bouncing_projectile":
			return ahead > 2.0 and ahead < 26.0 and absf(float(context.get("ahead_lateral", 9.0))) < 2.6
		"dropped_trap":
			return behind > 1.5 and behind < 12.0
		"magnet", "aurora":
			return true
	return false
