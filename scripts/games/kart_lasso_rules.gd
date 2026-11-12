extends RefCounted
## Deterministic, swept roadside encounters. The same state machine is used for
## every racer; a warning, a physical crossing and a matching lane are required.

const WARNING_SECONDS: float = 1.05
const WARNING_LEAD_SECONDS: float = 1.65
const HOLD_SECONDS: float = 0.65
const IMMUNITY_SECONDS: float = 4.0
const SPEED_FACTOR: float = 0.68
const HALF_WIDTH: float = 1.45

var length: float = 0.0
var encounters: Array[Dictionary] = []
var racers: Dictionary = {}


func configure(track_length: float, layout: Array[Dictionary]) -> void:
	length = maxf(0.0, track_length)
	encounters = layout.duplicate(true)
	racers.clear()


func advance(
	racer_id: String, distance: float, lane: float, speed: float, delta: float,
	protected: bool = false, airborne: bool = false
) -> Dictionary:
	var result := {"event": "", "index": -1, "warning": -1, "warning_ratio": 0.0,
		"speed_factor": 1.0, "remaining": 0.0}
	if length <= 1.0 or not is_finite(distance) or not is_finite(lane) or not is_finite(speed):
		return result
	if not racers.has(racer_id):
		racers[racer_id] = {
			"distance": distance, "lane": lane, "speed": speed, "clock": 0.0,
			"armed": {}, "used": {}, "remaining": 0.0, "immunity": 0.0, "index": -1,
		}
	var state: Dictionary = racers[racer_id]
	if delta <= 0.0 or not is_finite(delta):
		return _effect(state, result)
	var previous: float = float(state.distance)
	var travel: float = distance - previous
	var old_clock: float = float(state.clock)
	state.clock = old_clock + delta
	state.remaining = maxf(0.0, float(state.remaining) - delta)
	state.immunity = maxf(0.0, float(state.immunity) - delta)
	if protected and float(state.remaining) > 0.0:
		state.remaining = 0.0
		result.event = "released"
		result.index = int(state.index)
	# A rescue, load or teleport never sweeps through hazards on the skipped road.
	var max_step: float = maxf(12.0, maxf(absf(speed), absf(float(state.speed))) * delta * 2.0 + 3.0)
	var continuous: bool = travel >= 0.0 and travel <= max_step
	if not continuous:
		state.armed.clear()
		state.remaining = 0.0
	else:
		var lap: int = floori(maxf(distance, 0.0) / length)
		var nearest: float = INF
		for index in range(encounters.size()):
			var encounter: Dictionary = encounters[index]
			for lap_index in range(maxi(0, lap - 1), lap + 2):
				var key: int = lap_index * encounters.size() + index
				if state.used.has(key):
					continue
				var line: float = float(lap_index) * length + float(encounter.distance)
				var ahead: float = line - distance
				var lead: float = maxf(35.0, maxf(speed, 0.0) * WARNING_LEAD_SECONDS + 8.0)
				if ahead >= 0.0 and ahead <= lead:
					if not state.armed.has(key):
						state.armed[key] = float(state.clock)
					if ahead < nearest:
						nearest = ahead
						result.warning = index
						result.warning_ratio = clampf(1.0 - ahead / lead, 0.0, 1.0)
				if previous < line and distance >= line:
					state.used[key] = true
					var t: float = clampf((line - previous) / maxf(travel, 0.0001), 0.0, 1.0)
					var crossing_clock: float = old_clock + delta * t
					var warned: bool = state.armed.has(key) and crossing_clock - float(state.armed[key]) >= WARNING_SECONDS
					var crossing_lane: float = lerpf(float(state.lane), lane, t)
					var in_lane: bool = absf(crossing_lane - float(encounter.lateral)) <= HALF_WIDTH
					if warned and in_lane and not airborne and float(state.immunity) <= 0.0:
						result.index = index
						if protected:
							result.event = "blocked"
						else:
							var after_crossing: float = delta * (1.0 - t)
							state.remaining = maxf(0.0, HOLD_SECONDS - after_crossing)
							state.immunity = maxf(0.0, IMMUNITY_SECONDS - after_crossing)
							state.index = index
							result.event = "caught"
					elif warned:
						result.event = "dodged"
						result.index = index
					state.armed.erase(key)
		# Bound memory independently of how long training mode runs.
		for key in state.used.keys():
			if int(key) < maxi(0, lap - 1) * encounters.size():
				state.used.erase(key)
		for key in state.armed.keys():
			if int(key) < maxi(0, lap - 1) * encounters.size():
				state.armed.erase(key)
	state.distance = distance
	state.lane = lane
	state.speed = speed
	return _effect(state, result)


func _effect(state: Dictionary, result: Dictionary) -> Dictionary:
	result.remaining = float(state.remaining)
	if float(state.remaining) > 0.0:
		result.speed_factor = SPEED_FACTOR
		result.index = int(state.index)
	return result
