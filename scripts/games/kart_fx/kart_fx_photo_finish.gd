extends Node
## Fotofinish: when the player crosses the line less than [constant GAP_SECONDS]
## ahead of or behind the nearest rival, the finish moment plays in slow motion
## for [constant REAL_SECONDS] of real time and the camera zooms in a little.
##
## The race fixes time, place, result and reward at the line (kart_island
## _finish) before this starts, so the slow motion only stretches the picture.
## Off with reduced motion, outside ranked races, and the instant the race is
## paused, left or freed: Engine.time_scale always returns to 1.

const GAP_SECONDS := 0.35
const REAL_SECONDS := 0.8
const SLOW := 0.3
const ZOOM_DEGREES := 9.0

var active: bool = false
var triggered: int = 0
var last_gap: float = INF
var _started_msec: int = 0
var _seen_finish: bool = false
var _restore_scale: float = 1.0


func _ready() -> void:
	name = "KartFxPhotoFinish"
	process_mode = Node.PROCESS_MODE_ALWAYS


## Called every frame by the effects node with the race and the last racing speed.
func watch(race: Node, finish_speed: float) -> void:
	if not is_instance_valid(race):
		stop()
		return
	var finished: bool = bool(race.finished)
	if not finished:
		_seen_finish = false
		stop()
		return
	if not _seen_finish:
		_seen_finish = true
		last_gap = gap_seconds(race, finish_speed)
		if last_gap < GAP_SECONDS and _allowed(race):
			start()
	if active:
		if bool(race.paused) or bool(race.menu_active) or bool(race.reduced_motion):
			stop()
		elif Time.get_ticks_msec() - _started_msec >= int(REAL_SECONDS * 1000.0):
			stop()


## Seconds between the player and the nearest rival at the finish line.
static func gap_seconds(race: Node, finish_speed: float) -> float:
	var distances = race.get("opponent_distances")
	if distances == null or distances.is_empty():
		return INF
	var nearest := INF
	for value in distances:
		nearest = minf(nearest, absf(float(value) - float(race.distance)))
	return nearest / maxf(absf(finish_speed), 5.0)


func _allowed(race: Node) -> bool:
	if bool(race.reduced_motion):
		return false
	return str(race.mode) not in ["training", "time_trial", "arena"]


func start() -> void:
	if active:
		return
	active = true
	triggered += 1
	_started_msec = Time.get_ticks_msec()
	_restore_scale = 1.0
	Engine.time_scale = SLOW


func stop() -> void:
	if not active:
		return
	active = false
	Engine.time_scale = _restore_scale


## Extra zoom (negative FOV degrees) while the slow motion runs; eases out.
func zoom() -> float:
	if not active:
		return 0.0
	var t := clampf(float(Time.get_ticks_msec() - _started_msec) / (REAL_SECONDS * 1000.0), 0.0, 1.0)
	return -ZOOM_DEGREES * sin(t * PI) * 0.5 - ZOOM_DEGREES * 0.5 * (1.0 - t)


func _exit_tree() -> void:
	stop()
