extends RefCounted
## The building block of every early highlight in Lumo Lauf:
## ANKÜNDIGUNG (a beacon starts to pulse in the world colour, a sound, one short
## sentence) → AKTION (one clear input in a fair window: SPRINGEN, a mushroom,
## a vine, the upper way) → REAKTION (a push forward, a camera kick, a sound,
## a burst of sparkles and a word of praise).
##
## The moments are data: the course plan (road courses) or the hand-built level
## (Dschungelherz) lists them in `plan.moments`, each a Dictionary:
##   id, name           short id and the name the child hears
##   cue                metres: from here the beacon pulses and the sentence shows
##   go                 metres: from here the coach icon says what to press
##   s0, s1             metres: the stretch where the action counts
##   need               "bounce" (count mushrooms), "ride" (catch a vine),
##                      "clear" (over the stretch without a splash),
##                      "upper" (reach the upper way: height above `height`)
##   count, height      for "bounce" and "upper"
##   lat                lateral position of the beacon (and the upper way)
##   land_s, land_lat   optional landing target (bullseye after a jump)
##   say, done_say, miss_say, coach, look, boost (seconds of push on success)
## A miss never ends the run: it only costs the push and the praise (the
## course itself catches falls at its rescue points as before).

enum State { WAITING, CUED, DONE, MISSED }

const TUNING = preload("res://scripts/games/run/run_tuning.gd")

var list: Array[Dictionary] = []
var states: Array[int] = []
var counts: Array[int] = []
var failed: Array[bool] = []
var bullseye: Array[bool] = []


func setup(moments: Array[Dictionary], from_s: float) -> void:
	list = moments
	states.clear()
	counts.clear()
	failed.clear()
	bullseye.clear()
	for moment in list:
		# A run resumed after a moment does not replay it.
		states.append(State.DONE if from_s > float(moment.s0) else State.WAITING)
		counts.append(0)
		failed.append(false)
		bullseye.append(false)


func index_of(id: String) -> int:
	for index in range(list.size()):
		if str(list[index].id) == id:
			return index
	return -1


## The coach icon for the stretch Lumo is on ("" = none).
func coach_at(s: float) -> String:
	for index in range(list.size()):
		var moment: Dictionary = list[index]
		if states[index] == State.CUED and s >= float(moment.go) and s <= float(moment.s1):
			return str(moment.get("coach", "jump"))
	return ""


## Pulse of a moment's beacon 0..1 (0 = quiet, 1 = calling).
func calling(index: int) -> bool:
	return index >= 0 and index < states.size() and states[index] == State.CUED


## Feeds the game events of one step (track events plus the player's own) and
## returns what the game should show: {"type": "cue"|"done"|"missed", "index"}.
func step(player, events: Array[Dictionary], player_events: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in range(list.size()):
		var moment: Dictionary = list[index]
		var state: int = states[index]
		if state == State.DONE or state == State.MISSED:
			continue
		if state == State.WAITING:
			if player.s >= float(moment.cue):
				states[index] = State.CUED
				out.append({"type": "cue", "index": index})
			continue
		var inside: bool = player.s >= float(moment.s0) - 1.0 and player.s <= float(moment.s1) + 1.0
		var splashed: bool = false
		for event in events:
			var kind: String = str(event.type)
			if inside and kind == "bounce":
				counts[index] += 1
			elif inside and kind == "ride":
				counts[index] += 1
			elif (
				kind in ["fall", "splash", "rescue"]
				and player.s <= float(moment.s1) + 1.0
				and player.s >= float(moment.cue)
			):
				# One fall can report a splash and then the rescue: count it once.
				splashed = splashed or not (kind == "rescue" and failed[index])
		if failed[index] and not splashed and player.s < float(moment.s0) - 1.0:
			failed[index] = false
		if splashed:
			# A miss costs a short way back, never the moment: it stays armed for
			# the next try (the course carries Lumo across after the third miss).
			counts[index] = 0
			failed[index] = true
			out.append({"type": "missed", "index": index, "again": true})
			continue
		var on_way: bool = absf(player.lat - float(moment.get("lat", 0.0))) <= 2.0
		if (
			inside
			and on_way
			and str(moment.need) == "upper"
			and player.h >= float(moment.get("height", 1.8))
		):
			counts[index] = maxi(counts[index], 1)
		if (
			moment.has("land_s")
			and player_events.has(&"land")
			and absf(player.s - float(moment.land_s)) <= 2.6
		):
			bullseye[index] = absf(player.lat - float(moment.get("land_lat", 0.0))) <= 2.0
		if player.s > float(moment.s1) + 1.0 and player.grounded:
			var done: bool = _succeeded(index)
			states[index] = State.DONE if done else State.MISSED
			out.append({"type": "done" if done else "missed", "index": index})
	return out


func _succeeded(index: int) -> bool:
	var moment: Dictionary = list[index]
	match str(moment.need):
		"bounce":
			return counts[index] >= int(moment.get("count", 1))
		"ride", "upper":
			return counts[index] >= 1
		"clear":
			return true
	return false


## Push forward on success (course seconds of a speed pad).
static func boost_seconds(moment: Dictionary) -> float:
	return float(moment.get("boost", TUNING.MOMENT_BOOST_SECONDS))
