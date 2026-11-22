extends RefCounted
## Shared numbers of Lumo Lauf: one place for the feel, used by the motion model,
## by the content plan (star arcs follow the real flight) and by the tests.

## Forward speed in m/s. Lumo is drawn at hero scale so the kart worlds fit him.
const CRUISE: float = 13.0
const START_SPEED: float = 7.0
const START_COUNTDOWN_SECONDS: float = 1.0
## Advance the whole road course together so jump arcs and obstacle positions stay matched.
## Zauberwald and Sonnenhafen run 19.5 m/s on screen;
## coyote time and jump buffer scale with it (same windows on screen).
const ROAD_TIME_SCALE: float = 1.5
const MIN_SPEED: float = 5.0
const SLOW_FACTOR: float = 0.62
const ACCELERATION: float = 9.5
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
const MEDAL_NAMES: Array[String] = ["Bronze", "Silber", "Gold"]
const MEDAL_COLOURS: Array[Color] = [Color("e9a271"), Color("deedfa"), Color("ffd46b")]


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


# ------------------------------------------------------------------ adventure path (Dschungelherz)

## Lumo's pace on the narrow path as the level was laid out; pulling back stops
## him completely. Every jump, mushroom, platform and creature is built for this.
const PATH_CRUISE: float = 8.5
## The whole path plays this much faster than it was
## laid out - Lumo, creatures, platforms, vines and jumps alike. On screen Lumo
## runs PATH_CRUISE * PATH_TIME_SCALE (15.7 m/s) and every jump still lands
## where it was built to land;
## the jump windows below are given in screen time and scale with it.
const PATH_TIME_SCALE: float = 1.85
## Sonic-like momentum: running on without braking or bumping builds "flow"
## over PATH_FLOW_SECONDS, which adds up to PATH_FLOW_BONUS m/s (sprint).
const PATH_FLOW_BONUS: float = 3.0
const PATH_FLOW_SECONDS: float = 2.2
## Flow stage 2: who keeps running cleanly for PATH_FLOW2_SECONDS more after the
## sprint has built reaches the top pace (PATH_FLOW2_BONUS on top of stage 1).
## Braking, a bump or a fall end both stages. Before stepping stones, drifting
## or crumbling platforms the second stage pauses (see run_track.flow_cap), so
## every precise jump is still made at the speeds the path was tested with.
const PATH_FLOW2_BONUS: float = 1.8
const PATH_FLOW2_SECONDS: float = 3.0
## Metres before a precise spot (small, moving or crumbling platform) from which
## the second flow stage pauses, and how much of it fades per second meanwhile.
const PATH_PRECISE_LEAD: float = 24.0
## Obstacles closer together than this (metres) make a dense stretch: there the
## top stage pauses too, so it never shortens the time a child has to react.
const PATH_DENSE_SPACING: float = 25.0
## Faster pick-up on the path, with 160 ms coyote time and a 220 ms input
## buffer on screen at any tempo. The values below are in simulation time.
const PATH_ACCELERATION: float = 13.5
const PATH_COYOTE_SECONDS: float = 0.16 * PATH_TIME_SCALE
const PATH_JUMP_BUFFER_SECONDS: float = 0.22 * PATH_TIME_SCALE
## Speed pads on the long safe stretches of the path. The path is dense, so a
## pad's push is short: Lumo is back at his own pace before the next thing to
## jump or dodge (PATH_PAD_CLEAR metres are free).
const PATH_PAD_LENGTH: float = 5.0
const PATH_PAD_CLEAR: float = 22.0
const PATH_PAD_SPACING: float = 56.0
const PATH_PAD_SECONDS: float = 1.0
## Camera on the path: metres per second above Lumo's own pace that count as
## "full speed" for the pull-back, and the widening of the view in degrees.
const PATH_PACE_RANGE: float = 8.0
const PATH_FOV_KICK: float = 16.0
## How much lower the camera rides at full pace (closer to the ground = faster feel).
const PATH_LOW_CAMERA: float = 0.45
const PATH_LATERAL_SPEED: float = 6.0
const PATH_SLOW_FACTOR: float = 0.0
## Second, smaller push in the air (FLITZEN while jumping), once per jump.
const AIR_DASH_LIFT: float = 3.2
const CART_SPEED: float = 13.0
const STOMP_SPEED: float = 11.5
const TUMBLE_SECONDS: float = 0.7
## Metres below the path at which a fall into a hole is caught.
const FALL_DEPTH: float = 4.0
## Falls at the same spot before Lumo is carried to the next rescue point.
const PATH_HELP_AFTER_FALLS: int = 2
## Hits by the same enemy before it scuttles off for good.
const ENEMY_HELP_AFTER_HITS: int = 3
## Catches by the rolling stone before it gets stuck for good.
const CHASE_HELP_AFTER_CATCHES: int = 3
const RIDE_GRAB_RADIUS: float = 1.35
## A vine handle this high is caught only with a jump (the first highlight of
## Dschungelherz); handles at 1.9 m are caught running.
const VINE_HIGH_HANDLE: float = 2.8
## Push forward (seconds of a speed pad) after a highlight was mastered.
const MOMENT_BOOST_SECONDS: float = 0.8
## A finale launch still takes Lumo when he jumped early and is at most this
## high above it (metres; a tapped jump peaks at about 1.7 m).
const FINALE_CATCH_HEIGHT: float = 2.6
## Seconds of turbo a finale launch gives along the way (it throws forward).
const FINALE_CARRY_SECONDS: float = 1.2
