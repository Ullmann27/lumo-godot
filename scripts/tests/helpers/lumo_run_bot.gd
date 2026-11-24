extends RefCounted
## A deliberately simple scripted player for Lumo Lauf tests and captures:
## it steers towards the next star, sidesteps rocks, taps JUMP in front of
## hurdles and gaps and dashes into crates. It only uses the game's own inputs.

var hold_left: float = 0.0
var jumps: int = 0
var dashes: int = 0


func drive(game, delta: float) -> void:
	var player = game.player
	var plan = game.plan
	if player.loop_u >= 0.0:
		game.touch_steer = Vector2.ZERO
		return
	var target: float = player.lat
	for index in range(plan.star_s.size()):
		var along: float = plan.star_s[index]
		if along < player.s + 2.5:
			continue
		if along > player.s + 18.0:
			break
		if game.track.taken[index] == 0 and plan.star_h[index] < 2.4:
			target = plan.star_lat[index]
			break
	var want_dash: bool = false
	for index in range(plan.blockers.size()):
		var blocker: Dictionary = plan.blockers[index]
		var ahead: float = float(blocker.s) - player.s
		if ahead < -1.0:
			continue
		if ahead > 13.0:
			break
		if game.track.broken.has(index):
			continue
		var centre: float = game.track.blocker_lateral(blocker, game.run_clock)
		var reach: float = float(blocker.radius) + 1.0
		if absf(centre - target) >= reach:
			continue
		if str(blocker.kind) == "crate":
			want_dash = want_dash or ahead < 5.0
		else:
			target = centre + reach * (1.0 if target >= centre else -1.0)
	game.touch_steer = Vector2(clampf((target - player.lat) * 1.4, -1.0, 1.0), 0.0)
	if want_dash and player.dash_cooldown <= 0.0:
		if player.press_dash():
			dashes += 1
	var reach_ahead: float = player.speed * 0.14 + 1.0
	var want_jump: bool = false
	for hurdle in plan.hurdles:
		var ahead: float = float(hurdle.s) - player.s
		if ahead < 0.0:
			continue
		if ahead > reach_ahead:
			break
		if absf(player.lat - float(hurdle.lat)) <= float(hurdle.half) + 0.5:
			want_jump = true
	for gap in plan.channels:
		if bool(gap.real):
			continue
		var ahead: float = float(gap.s0) - player.s
		if ahead >= 0.0 and ahead <= reach_ahead:
			want_jump = true
			hold_left = maxf(hold_left, 0.3)
	if want_jump and player.grounded:
		player.press_jump()
		hold_left = maxf(hold_left, 0.16)
		jumps += 1
	if hold_left > 0.0:
		hold_left -= delta
		if hold_left <= 0.0:
			player.release_jump()
