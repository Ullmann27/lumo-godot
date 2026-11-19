extends Node3D
## The Dschungelherz adventure path as a "world" for Lumo Lauf. It answers the
## same questions as a kart world (position and frame along the path, side
## limits, holes) so motion, camera and props work in road space unchanged, but
## the path is narrow, climbs and falls, has holes, a cave and a bonus hall.
## The look of the world is built by run_jungle_scenery.gd.

const LEVEL = preload("res://scripts/games/run/jungle/run_jungle_level.gd")
const SCENERY = preload("res://scripts/games/run/jungle/run_jungle_scenery.gd")
const STEP: float = 0.5
const BONUS_ORIGIN := Vector3(0.0, -180.0, 0.0)

var track_id: String = "dschungelherz_pfad"
var length: float = 0.0
var low_detail: bool = false
var level
var scenery
## Interface parts of the kart worlds that this path does not have.
var action: Dictionary = {}
var adventure_tunnel: Dictionary = {}
var production_tunnel_layout: Dictionary = {}
var action_obstacles: Array = []
var loop_layout: Dictionary = {}
var s_min: float = 0.0
var _points := PackedVector3Array()
var _half := PackedFloat32Array()
var _ground := PackedFloat32Array()
var _gaps: Array[Vector2] = []


func build(lightweight: bool, _track: String = "", spread_frames: bool = false) -> void:
	low_detail = lightweight
	level = LEVEL.make()
	length = float(level.length)
	s_min = LEVEL.BONUS_S0
	_sample()
	_gaps = level.gaps.duplicate()
	_gaps.append(Vector2(float(level.bonus.s1), 0.0))
	scenery = SCENERY.new()
	scenery.name = "JungleScenery"
	add_child(scenery)
	await scenery.build(self, level, lightweight, spread_frames)


## The kart worlds light themselves here; the scenery has already done it.
func _lighting() -> void:
	pass


func _sample() -> void:
	var count: int = int(ceil((length - s_min) / STEP)) + 2
	_points.resize(count)
	_half.resize(count)
	_ground.resize(count)
	_half.fill(2.2)
	_ground.fill(0.0)
	var bonus_end: int = _integrate(level.bonus_legs, BONUS_ORIGIN, 0.0)
	var start: int = _index(0.0)
	_integrate(level.legs, Vector3.ZERO, 0.0)
	# The unused stretch between the hall and the start: a straight connection.
	for index in range(bonus_end + 1, start):
		var u: float = float(index - bonus_end) / float(maxi(1, start - bonus_end))
		_points[index] = _points[bonus_end].lerp(_points[start], u)


func _index(at: float) -> int:
	return clampi(roundi((at - s_min) / STEP), 0, _points.size() - 1)


func _integrate(legs: Array, origin: Vector3, heading: float) -> int:
	var position: Vector3 = origin
	var last: int = 0
	for leg in legs:
		var from: float = float(leg.s0)
		var span: float = float(leg.length)
		var base_y: float = position.y
		var steps: int = maxi(1, roundi(span / STEP))
		var first: int = _index(from)
		for step in range(steps + 1):
			var u: float = float(step) / float(steps)
			if step > 0:
				var turn: float = deg_to_rad(float(leg.turn)) / float(steps)
				heading += turn
				position += Vector3(sin(heading), 0.0, -cos(heading)) * (span / float(steps))
				position.y = base_y + float(leg.rise) * (1.0 - cos(PI * u)) * 0.5
			var index: int = first + step
			if index >= _points.size():
				break
			_points[index] = position
			_half[index] = float(leg.half)
			_ground[index] = float(leg.ground)
			last = index
	return last


# ------------------------------------------------------------------ world interface

func _sample_point(at: float) -> Vector3:
	var x: float = clampf((at - s_min) / STEP, 0.0, float(_points.size() - 1))
	var index: int = mini(int(x), _points.size() - 2)
	return _points[index].lerp(_points[index + 1], x - float(index))


func forward(at: float) -> Vector3:
	var ahead: Vector3 = _sample_point(at + 0.75) - _sample_point(at - 0.75)
	if ahead.length_squared() < 0.0001:
		return Vector3.FORWARD
	return ahead.normalized()


func frame(at: float) -> Basis:
	var ahead: Vector3 = forward(at)
	var right: Vector3 = ahead.cross(Vector3.UP)
	if right.length_squared() < 0.000001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up: Vector3 = right.cross(ahead).normalized()
	return Basis(right, up, -ahead)


func position_at(at: float, lateral: float = 0.0) -> Vector3:
	return _sample_point(at) + frame(at).x * lateral


func half_width_at(at: float) -> float:
	return _half[_index(at)]


## Height of the forest floor relative to the path (negative when the path is high up).
func ground_offset_at(at: float) -> float:
	return _ground[_index(at)]


## How far Lumo falls into a hole here before he is caught: shallow streams
## catch him at the water, deep holes after a few metres.
func fall_depth_at(at: float) -> float:
	return clampf(-ground_offset_at(at) - 0.4, 1.8, 4.0)


func wall_lateral_at(at: float) -> float:
	return half_width_at(at) - 0.35


func in_gap(at: float) -> bool:
	for gap in _gaps:
		if at > gap.x and at < gap.y:
			return true
	return false


func ramp_height(_at: float) -> float:
	return 0.0


func is_bonus(at: float) -> bool:
	return at < float(level.bonus.s1) + 0.5


## Cave roof height above the path, INF in the open.
func ceiling_at(at: float) -> float:
	for roof in level.ceilings:
		if at >= roof.x and at <= roof.y:
			return roof.z
	if is_bonus(at):
		return 7.5
	return INF


func surface_at(at: float) -> String:
	for surface in level.surfaces:
		if at >= float(surface.s0) and at < float(surface.s1):
			return str(surface.kind)
	return "dirt"


func section_at(at: float) -> int:
	for section in level.sections:
		if at < float(section.s1):
			return int(section.index)
	return level.sections.size() - 1


func sample_road(world_position: Vector3, hint_distance: float = -1.0) -> Dictionary:
	var from: float = s_min
	var to: float = length
	if hint_distance > -9000.0:
		from = hint_distance - 25.0
		to = hint_distance + 25.0
	var best: float = from
	var best_square: float = INF
	var at: float = from
	while at <= to:
		var square: float = _sample_point(at).distance_squared_to(world_position)
		if square < best_square:
			best_square = square
			best = at
		at += STEP
	var basis: Basis = frame(best)
	var offset: Vector3 = world_position - _sample_point(best)
	return {"distance": best, "lateral": offset.dot(basis.x), "width": half_width_at(best) * 2.0}


func clip_tunnel_camera(_anchor: Vector3, desired: Vector3) -> Vector3:
	return desired
