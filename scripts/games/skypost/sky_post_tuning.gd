extends RefCounted
## Numbers of Lumos Sternenpost in one place: flight feel, the three stages,
## rings, deliveries, the cloud race and how stars are earned.

const MODES: Array[String] = ["delivery", "race", "free"]
const MODE_NAMES := {"delivery": "Lieferflug", "race": "Wolkenrennen", "free": "Freiflug"}
const STAGES: Array[String] = ["entdecken", "abenteuer", "extrem"]
const STAGE_NAMES := {"entdecken": "Entdecken", "abenteuer": "Abenteuer", "extrem": "Extrem"}

## Flight (m, s, rad).
const CRUISE := {"entdecken": 14.0, "abenteuer": 15.5, "extrem": 17.0}
const MIN_SPEED: float = 8.5
const MAX_SPEED: float = 31.0
const TURN_RATE: float = 1.2
const CLIMB_ANGLE: float = 0.44
const BANK_ANGLE: float = 0.62
const GRAVITY_PULL: float = 5.4
const SPEED_RETURN: float = 0.38
const BOOST_SECONDS: float = 1.2
const BOOST_SPEED: float = 9.0
const BOOST_COOLDOWN: float = 3.2
const RING_BOOST_SECONDS: float = 0.9
const UPDRAFT_RISE: float = 9.0
const LAUNCH_SECONDS: float = 1.7
## Crosswind gusts (m/s) per stage.
const GUST := {"entdecken": 0.0, "abenteuer": 1.2, "extrem": 2.6}
## Entdecken gently turns the glider towards the current goal when the stick rests.
const ASSIST := {"entdecken": 0.45, "abenteuer": 0.0, "extrem": 0.0}

## Pick-up radius of a star spark around the glider centre.
const SPARK_RADIUS: float = 2.6

## Delivery.
const DELIVERIES := {"entdecken": 5, "abenteuer": 6, "extrem": 6}
## Radius around the mailbox in which a dropped letter counts, and the extra
## radius per missed try of the same letter ("help after a miss").
const CATCH_RADIUS := {"entdecken": 4.2, "abenteuer": 3.4, "extrem": 2.8}
const CATCH_HELP: float = 1.0
const CATCH_HELP_MAX: float = 2.0
## Distance to the district centre from which the address boards light up and
## the drop button works.
const DISTRICT_RADIUS: float = 58.0
const CHUTE_DELAY: float = 0.35
const CHUTE_FALL: float = 3.3
const CHUTE_DRAG: float = 1.55
const PARCEL_DRAG: float = 0.45
const LETTER_GRAVITY: float = 9.8

## Race.
const LAPS := {"entdecken": 2, "abenteuer": 2, "extrem": 3}
## Rival pace relative to the stage cruise speed.
const RIVAL_PACE := {"entdecken": 0.84, "abenteuer": 0.93, "extrem": 1.0}
## Pace of a rival far ahead of Lumo (it waits a little, so races stay close).
const RIVAL_EASE := {"entdecken": 0.74, "abenteuer": 0.84, "extrem": 0.93}
const RIVAL_SPREAD: Array[float] = [0.97, 1.0, 1.03]
const GATE_ZONE := {"entdecken": 16.0, "abenteuer": 13.0, "extrem": 10.5}
const GATE_RADIUS: float = 4.6

## Free flight.
const FREE_MIN_SECONDS: float = 20.0

## Stars for the child (booked once per result).
const MEDAL_NAMES: Array[String] = ["Bronze-Siegel", "Silber-Siegel", "Gold-Siegel"]
const MEDAL_COLOURS: Array[Color] = [Color("e0a06a"), Color("dfe8f2"), Color("ffd75e")]
const START_COUNTDOWN: float = 3.0


static func delivery_rating(first_try: int, deliveries: int, sparks: int, spark_total: int) -> int:
	var accuracy: float = float(first_try) / float(maxi(1, deliveries))
	var collected: float = float(sparks) / float(maxi(1, spark_total))
	var score: float = accuracy * 0.6 + collected * 0.4
	if score >= 0.8:
		return 3
	return 2 if score >= 0.5 else 1


static func delivery_reward(first_try: int, rating: int) -> int:
	return 3 + 2 * clampi(first_try, 0, 3) + 3 * (clampi(rating, 1, 3) - 1)


static func race_rating(hits: int, gates: int) -> int:
	var share: float = float(hits) / float(maxi(1, gates))
	if share >= 0.7:
		return 3
	return 2 if share >= 0.4 else 1


static func race_reward(place: int, rating: int) -> int:
	var by_place: Array[int] = [6, 4, 2, 1]
	return 3 + by_place[clampi(place, 1, 4) - 1] + 3 * (clampi(rating, 1, 3) - 1)


## Free flight pays for what was found for the first time, never for repeating.
static func free_reward(new_secrets: int, new_photos: int, sparks: int) -> int:
	return clampi(1 + new_secrets / 2 + new_photos * 2 + sparks / 12, 1, 12)


static func free_rating(
	found_secrets: int, secret_total: int, photos: int, photo_total: int
) -> int:
	var share: float = (
		float(found_secrets) / float(maxi(1, secret_total)) * 0.5
		+ float(photos) / float(maxi(1, photo_total)) * 0.5
	)
	if share >= 0.8:
		return 3
	return 2 if share >= 0.4 else 1
