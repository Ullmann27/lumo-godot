extends Node3D
## Three-input stunt lines laid over real features, without adding or renumbering
## collectible slots in saved courses. A missed cue breaks only the local chain.
const RING := preload("res://assets/games/jump/sun_ring.glb")
const PAD := preload("res://assets/games/jump/wind_pad.glb")
const COMET := preload("res://assets/games/jump/comet_bar.glb")
const HINT := {"dash": "Am Pfeilbrett FLITZEN!", "vault": "Über den Kometen SPRINGEN!",
	"ring": "Mitten durch den Sonnenring!", "steer": "Lenke durch den Flügelring!"}
var marks: Array[Dictionary] = []
var cursor := 0
var chain := 0
var announced := false
signal feedback(kind: String, text: String)


func build(world, plan, from_s: float) -> void:
	var start: float = plan.start_s
	match str(plan.course.theme):
		"jungle":
			# Stream, then mushroom flight. The speed board teaches the dash before either.
			_line(world, [["dash", start + 11, 0, 0], ["ring", 29.5, 0, 2.35], ["ring", 61.0, 0, 4.1]])
			for branch in plan.branches:
				if str(branch.name) not in ["Wurzelkrone", "Kristallsims"]:
					continue
				var begin: float = branch.s0
				var side: float = branch.upper_lat
				_line(world, [["steer", begin + 2, side, .95], ["ring", begin + 15, side, 4.75],
					["ring", begin + 39, side, 4.65]])
		"forest":
			# Cross the floor, take the opposite low lane, then return to the mushroom canopy.
			_line(world, [["dash", start + 14, 0, 0], ["steer", start + 39, -1.9, 1.1],
				["ring", start + 76, 2.1, 3.95]])
		"harbour":
			_line(world, [["vault", start + 20, 0, .83], ["dash", start + 41, 2.0, 0],
				["ring", start + 97, 0, 2.45]])
	if not plan.adventure:
		# Later lines use the actual generated obstacle/pickup layout of this seed.
		var last := start + 175
		for beat in plan.beats:
			if float(beat.s) < last + 190 or str(beat.kind) != "trail":
				continue
			var begin: float = beat.s
			_line(world, [["steer", begin + 3, -2.3, 1.05], ["vault", begin + 14, 0, .85],
				["dash", begin + 28, 2.3, 0]])
			last = begin
	marks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.s) < float(b.s))
	while cursor < marks.size() and float(marks[cursor].s) < from_s:
		marks[cursor].node.hide()
		cursor += 1


func upcoming_hint() -> String:
	if cursor >= marks.size():
		return ""
	return str(HINT[marks[cursor].kind])


func _line(world, spec: Array) -> void:
	for i in range(spec.size()):
		var mark: Array = spec[i]
		var kind: String = mark[0]
		var s: float = mark[1]
		var lat: float = mark[2]
		var h: float = mark[3]
		var asset: PackedScene = PAD if kind == "dash" else (COMET if kind == "vault" else RING)
		var node: Node3D = asset.instantiate()
		node.transform = Transform3D(world.frame(s), world.position_at(s, lat) + Vector3.UP * (h + .07))
		if kind == "dash":
			node.scale = Vector3(1.5, 1, 2.0)
		add_child(node)
		marks.append({"kind": kind, "s": s, "lat": lat, "h": h, "node": node, "leg": i})


func advance(player) -> void:
	while cursor < marks.size():
		var mark := marks[cursor]
		var d: float = float(mark.s) - player.s
		if float(mark.s) < player.previous_s - 2.0:
			# Intro skip, barrel warp or checkpoint restore bypassed this line.
			mark.node.hide()
			chain = 0
			announced = false
			cursor += 1
			continue
		if d > 19.0:
			return
		if not announced:
			announced = true
			if int(mark.leg) == 0:
				chain = 0
			feedback.emit("cue", str(HINT[mark.kind]))
		if d > 0:
			return
		var clean: bool = player.previous_s <= float(mark.s) and _hit(mark, player)
		chain = chain + 1 if clean else 0
		mark.node.hide()
		cursor += 1
		announced = false
		if clean and chain == 3:
			player.boost(1.35)
			feedback.emit("triple", "Dreier-Stunt! Rückenwind!")
		elif clean:
			feedback.emit("hit", "Treffer · %d/3" % chain)
		elif int(mark.leg) == 2:
			feedback.emit("miss", "Weiter geht’s!")


func _hit(mark: Dictionary, player) -> bool:
	var dx: float = absf(player.lat - float(mark.lat))
	match str(mark.kind):
		"dash":
			return dx <= 1.6 and player.dash_time > 0 and player.h < 1.1
		"vault":
			return dx <= 1.9 and player.h > float(mark.h) + .13
		"ring", "steer":
			return Vector2(dx, player.h + .85 - float(mark.h)).length() <= 1.28
	return false
