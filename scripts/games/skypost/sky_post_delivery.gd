extends RefCounted
## Rules of the delivery flight: the tour (which district, letter or parcel,
## recipient and riddle address), the falling item under its star chute, where
## it lands and whether that is the right mailbox. A miss or a wrong house costs
## nothing but time; the catch circle grows a little after each miss of the same
## letter ("help after a miss"). Pure data and motion, no nodes: sky_post.gd
## draws everything and the flight bot of the tests uses the same prediction.

const TUNING = preload("res://scripts/games/skypost/sky_post_tuning.gd")
const ADDRESSES = preload("res://scripts/games/skypost/sky_post_addresses.gd")

const PREDICT_STEP: float = 0.05
const PREDICT_SECONDS: float = 14.0

var layout
var stage: String = "entdecken"
var jobs: Array = []
var done: int = 0
## Misses and wrong houses per job.
var tries := PackedInt32Array()
## The falling item: {pos, vel, t, item} or {} when none.
var drop: Dictionary = {}
var events: Array[Dictionary] = []


## The tour for [param stage]: one job per district in tour order.
static func plan(
	world_layout, stage_id: String, grade: int, subject: String, riddles: bool, seed_value: int
) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = mini(int(TUNING.DELIVERIES.get(stage_id, 5)), world_layout.DISTRICTS.size())
	var recipients: Array[String] = ADDRESSES.RECIPIENTS.duplicate()
	for index in range(recipients.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var keep: String = recipients[index]
		recipients[index] = recipients[other]
		recipients[other] = keep
	var result: Array = []
	for index in range(count):
		var kind: String = ADDRESSES.kind_for(subject, grade, index) if riddles else "math"
		var riddle: Dictionary = ADDRESSES.make(kind, grade, rng, not riddles)
		var parcel: bool = stage_id != "entdecken" and index % 3 == 2
		(
			result
			. append(
				{
					"district": index,
					"item": "Paket" if parcel else "Brief",
					"recipient": recipients[index % recipients.size()],
					"riddle": riddle,
				}
			)
		)
	return result


func setup(world_layout, stage_id: String, tour: Array, done_count: int, misses) -> void:
	layout = world_layout
	stage = stage_id
	jobs = tour
	done = clampi(done_count, 0, tour.size())
	tries = PackedInt32Array(misses) if misses != null else PackedInt32Array()
	if tries.size() != jobs.size():
		tries.resize(jobs.size())
		tries.fill(0)
	drop = {}
	events.clear()


func finished() -> bool:
	return done >= jobs.size()


func current() -> Dictionary:
	return {} if finished() else jobs[done]


func district() -> int:
	return -1 if finished() else int(jobs[done].district)


## Index into layout.houses of house [param slot] in the current district.
func house_of(slot: int) -> int:
	var wanted: int = district()
	for index in range(layout.houses.size()):
		var house: Dictionary = layout.houses[index]
		if int(house.district) == wanted and int(house.slot) == slot:
			return index
	return -1


func target_house() -> int:
	return -1 if finished() else house_of(int(jobs[done].riddle.answer))


func district_houses() -> Array[int]:
	var result: Array[int] = []
	for slot in range(3):
		result.append(house_of(slot))
	return result


func centre() -> Vector3:
	return layout.district_centre(district()) if not finished() else Vector3.ZERO


func in_district(pos: Vector3) -> bool:
	if finished():
		return false
	var c: Vector3 = centre()
	return Vector2(pos.x - c.x, pos.z - c.z).length() < TUNING.DISTRICT_RADIUS


func catch_radius() -> float:
	var misses: int = tries[done] if not finished() else 0
	return (
		float(TUNING.CATCH_RADIUS.get(stage, 3.4))
		+ minf(float(misses) * TUNING.CATCH_HELP, TUNING.CATCH_HELP_MAX)
	)


func can_drop(pos: Vector3) -> bool:
	return not finished() and drop.is_empty() and in_district(pos)


## Lets the item go at [param pos] with the glider's [param velocity].
func release(pos: Vector3, velocity: Vector3) -> bool:
	if not can_drop(pos):
		return false
	drop = {
		"pos": pos + Vector3(0, -0.6, 0),
		"vel": velocity * 0.92,
		"t": 0.0,
		"item": str(jobs[done].item),
		"chute": false,
	}
	events.append({"type": "release", "item": drop.item})
	return true


func _drag() -> float:
	return TUNING.PARCEL_DRAG if str(jobs[done].item) == "Paket" else TUNING.CHUTE_DRAG


func _fall() -> float:
	return TUNING.CHUTE_FALL * (1.35 if str(jobs[done].item) == "Paket" else 1.0)


## One motion step of a falling item (shared by the live drop and the prediction).
func _move(state: Dictionary, delta: float) -> void:
	var vel: Vector3 = state.vel
	var t: float = float(state.t) + delta
	if t < TUNING.CHUTE_DELAY:
		vel.y -= TUNING.LETTER_GRAVITY * delta
	else:
		var keep: float = exp(-_drag() * delta)
		vel.x *= keep
		vel.z *= keep
		vel.y = lerpf(vel.y, -_fall(), 1.0 - exp(-3.2 * delta))
	state.vel = vel
	state.t = t
	state.pos = (state.pos as Vector3) + vel * delta


## Height of the meadow of the current district's island below [param p], or
## NAN outside the island (the item then falls into the clouds).
func ground(p: Vector3) -> float:
	var island_index: int = int(layout.DISTRICTS[district()].island)
	var island: Dictionary = layout.islands[island_index]
	var at: Vector3 = island.at
	if Vector2(p.x - at.x, p.z - at.z).length() > float(island.radius) * 0.97:
		return NAN
	return layout.ground_estimate(island_index, Vector2(p.x, p.z))


func _landed(state: Dictionary) -> int:
	var p: Vector3 = state.pos
	var floor_y: float = ground(p)
	if not is_nan(floor_y) and p.y <= floor_y + 0.15:
		return 1
	var island: Dictionary = layout.islands[int(layout.DISTRICTS[district()].island)]
	if p.y < float((island.at as Vector3).y) - 14.0:
		return 2
	return 0


## Where an item released now would come down (Entdecken shows it as a ring).
func predict(pos: Vector3, velocity: Vector3) -> Variant:
	if finished():
		return null
	var state: Dictionary = {"pos": pos + Vector3(0, -0.6, 0), "vel": velocity * 0.92, "t": 0.0}
	var steps: int = int(PREDICT_SECONDS / PREDICT_STEP)
	for _i in range(steps):
		_move(state, PREDICT_STEP)
		var landed: int = _landed(state)
		if landed == 1:
			var p: Vector3 = state.pos
			p.y = ground(p)
			return p
		if landed == 2:
			return null
	return null


## The mailbox (house index) whose catch circle contains [param at], or -1.
func house_at(at: Vector3) -> int:
	var best: int = -1
	var best_d: float = catch_radius()
	for house_index in district_houses():
		if house_index < 0:
			continue
		var box: Vector3 = layout.houses[house_index].mailbox
		var d: float = Vector2(at.x - box.x, at.z - box.z).length()
		if d <= best_d:
			best_d = d
			best = house_index
	return best


func step(delta: float) -> void:
	if drop.is_empty() or finished():
		return
	_move(drop, delta)
	if not bool(drop.chute) and float(drop.t) >= TUNING.CHUTE_DELAY:
		drop.chute = true
		events.append({"type": "chute"})
	var landed: int = _landed(drop)
	if landed == 0:
		return
	var at: Vector3 = drop.pos
	drop = {}
	if landed == 2:
		_miss(at, "clouds")
		return
	at.y = ground(at)
	var house: int = house_at(at)
	if house < 0:
		_miss(at, "meadow")
	elif house == target_house():
		var first: bool = tries[done] == 0
		events.append({"type": "delivered", "house": house, "job": done, "first": first, "at": at})
		done += 1
	else:
		tries[done] += 1
		var slot: int = int(layout.houses[house].slot)
		(
			events
			. append(
				{
					"type": "wrong",
					"house": house,
					"text": str(jobs[done].riddle.answers[slot]),
					"at": at,
				}
			)
		)


func _miss(at: Vector3, where: String) -> void:
	tries[done] += 1
	events.append({"type": "miss", "at": at, "where": where})


func first_try_count() -> int:
	var count: int = 0
	for index in range(mini(done, tries.size())):
		if tries[index] == 0:
			count += 1
	return count


## Save fields (sky_post_session.gd checks them on load).
func state() -> Dictionary:
	return {"jobs": jobs, "done": done, "tries": tries}
