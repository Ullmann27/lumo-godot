extends RefCounted
## Rules of the cloud race for Lumo: the ring gates must be flown in order;
## a gate counts when the glider crosses its plane inside the (kind, wide)
## gate zone, flying right through the ring ("mitten durch") gives a ring boost
## and counts for the seal. The first crossing of gate 0 is the start line, the
## race ends at gate 0 after the last lap. Lumo's course distance is measured on
## the same scale as the rivals' (sky_post_rivals.gd) for the placings.

const TUNING = preload("res://scripts/games/skypost/sky_post_tuning.gd")

var layout
var stage: String = "entdecken"
var laps: int = 2
var count: int = 12
## Gate crossings so far (the start line is the first one).
var passed: int = 0
var hits: int = 0
var finished: bool = false
var finish_time: float = 0.0
var events: Array[Dictionary] = []
var _frames: Array[Transform3D] = []
var _inverse: Array[Transform3D] = []


func setup(world_layout, stage_id: String, lap_count: int) -> void:
	layout = world_layout
	stage = stage_id
	laps = lap_count
	count = world_layout.GATES.size()
	passed = 0
	hits = 0
	finished = false
	events.clear()
	_frames.clear()
	_inverse.clear()
	for index in range(count):
		var frame: Transform3D = world_layout.gate_frame(index)
		_frames.append(frame)
		_inverse.append(frame.affine_inverse())


## Crossings needed: every gate of every lap plus the start line.
func total() -> int:
	return laps * count + 1


func next_gate() -> int:
	return passed % count


func lap() -> int:
	return clampi((maxi(passed, 1) - 1) / count + 1, 1, laps)


## Ring number within the lap (1..count) of the next gate; 0 = start line.
func ring_in_lap() -> int:
	if passed == 0:
		return 0
	var index: int = next_gate()
	return count if index == 0 else index


func zone() -> float:
	return float(TUNING.GATE_ZONE.get(stage, 13.0))


## Checks the step from [param before] to [param now]; [param clock] is the race time.
func step(before: Vector3, now: Vector3, clock: float) -> void:
	if finished:
		return
	var gate: int = next_gate()
	var a: Vector3 = _inverse[gate] * before
	var b: Vector3 = _inverse[gate] * now
	# The gate looks along -Z: a crossing goes from +Z to -Z.
	if not (a.z > 0.0 and b.z <= 0.0):
		return
	var t: float = a.z / maxf(a.z - b.z, 0.0001)
	var cross: Vector3 = a.lerp(b, t)
	var off: float = Vector2(cross.x, cross.y).length()
	if off > zone():
		return
	var hit: bool = off <= TUNING.GATE_RADIUS
	passed += 1
	if hit:
		hits += 1
	var done: bool = passed >= total()
	if done:
		finished = true
		finish_time = clock
	(
		events
		. append(
			{
				"type": "gate",
				"gate": gate,
				"hit": hit,
				"start": passed == 1,
				"finish": done,
				"lap_done": gate == 0 and passed > 1 and not done,
				"at": _frames[gate].origin,
			}
		)
	)


func gate_position(index: int) -> Vector3:
	return _frames[index % count].origin


## Lumo's course distance on the rivals' scale (see sky_post_rivals.gd).
func distance(pos: Vector3, rivals) -> float:
	if finished:
		return rivals.finish_distance() + 1.0
	var next_d: float = rivals.gate_distance(passed)
	var gate: Vector3 = gate_position(next_gate())
	var previous: Vector3
	var previous_d: float
	if passed == 0:
		previous = layout.start_at
		previous_d = next_d - previous.distance_to(gate)
	else:
		previous = gate_position(passed - 1)
		previous_d = rivals.gate_distance(passed - 1)
	var span: float = maxf(previous.distance_to(gate), 1.0)
	var share: float = clampf(1.0 - pos.distance_to(gate) / span, 0.0, 1.0)
	return lerpf(previous_d, next_d, share)


## Lumo's place (1..4) from the rivals' standings.
func place(pos: Vector3, rivals) -> int:
	var mine: float = distance(pos, rivals)
	var ahead: int = 0
	for rival in rivals.standings():
		if bool(rival.finished):
			if not finished or float(rival.finish_time) < finish_time:
				ahead += 1
		elif float(rival.d) > mine:
			ahead += 1
	return ahead + 1
