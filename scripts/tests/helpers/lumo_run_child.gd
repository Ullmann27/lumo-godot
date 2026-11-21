extends RefCounted
## A player for Lumo Lauf that acts like a child at the early highlights
## (run_moments.gd): it waits for the coach icon of the moment, reacts after
## `reaction` seconds with one press of SPRINGEN (held `hold` seconds) or steers
## to the announced way. Everywhere else the course's own scripted player
## drives (lumo_jungle_bot.gd on the path, lumo_run_bot.gd on the road).
## `refuse` = the child does nothing at the highlight; `lane` = steer there.
## Used by lumo_run_moments_regression.gd and lumo_run_menu_probe.gd.

const BOT = preload("res://scripts/tests/helpers/lumo_run_bot.gd")
const JUNGLE_BOT = preload("res://scripts/tests/helpers/lumo_jungle_bot.gd")

var base
var reaction: float = 0.3
var hold: float = 0.22
var refuse: bool = false
var lane: float = INF
var presses: int = 0
var _seen: float = -1.0
var _held: float = -1.0
var _pressed_at: float = -1.0


func _init(path: bool, seed: int) -> void:
	base = JUNGLE_BOT.new(seed) if path else BOT.new()


func drive(game, delta: float) -> void:
	var player = game.player
	var index: int = _active(game)
	if index < 0:
		_seen = -1.0
		if _held >= 0.0:
			player.release_jump()
			_held = -1.0
		base.drive(game, delta)
		return
	var spot: Dictionary = game.plan.moments[index]
	var target: float = lane if lane != INF else float(spot.get("lat", 0.0))
	if str(spot.need) == "upper":
		# A choice of ways: the scripted player keeps jumping logs, the child steers.
		base.drive(game, delta)
		if not refuse or lane != INF:
			game.touch_steer.x = clampf((target - player.lat) * 1.5, -1.0, 1.0)
		return
	game.touch_steer = Vector2(clampf((target - player.lat) * 1.5, -1.0, 1.0), 0.0)
	if refuse or player.is_riding():
		return
	if str(spot.get("coach", "")) == "bounce":
		# "Lauf drauf": a mushroom or launch band does the jump by itself.
		return
	if _held >= 0.0:
		_held += delta
		if _held >= hold:
			player.release_jump()
			_held = -1.0
		return
	if game.moments.coach_at(player.s).is_empty() or not player.grounded:
		return
	if _seen < 0.0:
		_seen = 0.0
		return
	_seen += delta
	if _seen >= reaction:
		player.press_jump()
		presses += 1
		_pressed_at = float(game.elapsed)
		_held = 0.0
		_seen = -1.0


## The moment the child is busy with: announced and not yet behind Lumo.
func _active(game) -> int:
	if game.get("moments") == null or game.plan.get("moments") == null:
		return -1
	for index in range(game.plan.moments.size()):
		var spot: Dictionary = game.plan.moments[index]
		if not game.moments.calling(index):
			continue
		if game.player.s >= float(spot.go) - 6.0 and game.player.s <= float(spot.s1) + 2.0:
			return index
	return -1
