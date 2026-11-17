extends RefCounted
## Shared numbers of Lumo Lauf: one place for the feel, used by the motion model,
## by the content plan (star arcs follow the real flight) and by the tests.

## Forward speed in m/s. Lumo is drawn at hero scale so the kart worlds fit him.
const CRUISE: float = 13.0
const START_SPEED: float = 4.0
const MIN_SPEED: float = 5.0
const SLOW_FACTOR: float = 0.62
const ACCELERATION: float = 6.5
const DECELERATION: float = 5.0
const BURST_ACCELERATION: float = 34.0
## Momentum from the terrain: uphill costs speed, downhill gives it back.
const GRADE_GAIN: float = 2.4
const GRADE_MIN: float = 0.78
const GRADE_MAX: float = 1.24
const BOOST_BONUS: float = 6.0
const BOOST_SECONDS: float = 1.7
const DASH_BONUS: float = 7.0
const DASH_SECONDS: float = 0.42
const DASH_COOLDOWN: float = 1.5
const ANSWER_BOOST_SECONDS: float = 1.2

const LATERAL_SPEED: float = 9.5
const LATERAL_ACCELERATION: float = 64.0
const AIR_LATERAL_ACCELERATION: float = 36.0

const JUMP_SPEED: float = 10.0
const JUMP_CUT_SPEED: float = 7.0
const JUMP_HOLD_SECONDS: float = 0.45
const GRAVITY_HOLD: float = 20.0
const GRAVITY_RISE: float = 30.0
const GRAVITY_FALL: float = 32.0
const COYOTE_SECONDS: float = 0.12
const JUMP_BUFFER_SECONDS: float = 0.18
const BOUNCE_SPEED: float = 15.5
const HIGH_PATH_BOUNCE_SPEED: float = 14.0
const LAUNCH_SPEED: float = 17.0

const STUMBLE_SECONDS: float = 0.55
const STUMBLE_SPEED_FACTOR: float = 0.55
const INVULNERABLE_SECONDS: float = 1.3
const STUMBLE_STAR_LOSS: int = 2
const RESPAWN_SPEED: float = 9.0
## Third miss at the same gap: Lumo is carried across. Nobody gets stuck.
const GAP_HELP_AFTER_MISSES: int = 2

const PICKUP_ALONG: float = 1.35
const PICKUP_ACROSS: float = 1.3
const PICKUP_HEIGHT: float = 1.6
const BODY_RADIUS: float = 0.42
const BODY_CENTRE: float = 0.85

const QUESTION_BONUS_STARS: int = 10
const GOLD_STAR_VALUE: int = 5
const CRATE_STARS: int = 2
## Rating thresholds on the share of all course stars that Lumo kept.
const RATING_TWO: float = 0.5
const RATING_THREE: float = 0.8


## Height above the take-off point after `t` seconds of an unheld flight.
static func flight_height(launch_speed: float, t: float) -> float:
	var rise: float = launch_speed / GRAVITY_RISE
	if t <= rise:
		return launch_speed * t - 0.5 * GRAVITY_RISE * t * t
	var peak: float = launch_speed * launch_speed / (2.0 * GRAVITY_RISE)
	return peak - 0.5 * GRAVITY_FALL * (t - rise) * (t - rise)


## Seconds until an unheld flight is `drop` metres below its take-off height.
static func flight_seconds(launch_speed: float, drop: float = 0.0) -> float:
	var rise: float = launch_speed / GRAVITY_RISE
	var peak: float = launch_speed * launch_speed / (2.0 * GRAVITY_RISE)
	return rise + sqrt(2.0 * maxf(0.0, peak + drop) / GRAVITY_FALL)


static func rating(kept: int, total: int) -> int:
	if total <= 0:
		return 1
	var share: float = float(kept) / float(total)
	if share >= RATING_THREE:
		return 3
	return 2 if share >= RATING_TWO else 1


## Stars booked to the child's collection for one finished run.
static func reward(solved: int, stars_rating: int) -> int:
	return 3 + 2 * clampi(solved, 0, 3) + 3 * (clampi(stars_rating, 1, 3) - 1)
