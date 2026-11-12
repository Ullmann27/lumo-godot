extends SceneTree
## Same production rules at 30/60/120 Hz and 10 Hz: warnings, physical lane
## crossings, counterplay, finite recovery and lap-safe bounded state.
const RULES = preload("res://scripts/games/kart_lasso_rules.gd")
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[KartLasso] " + label)


func _model(two: bool = false):
	var model = RULES.new()
	var entries: Array[Dictionary] = [{"distance": 180.0, "lateral": 2.8}]
	if two:
		entries.append({"distance": 215.0, "lateral": 2.8})
	model.configure(400.0, entries)
	return model


func _drive(model, id: String, lane: float, protected: bool, airborne: bool, step: float) -> Dictionary:
	var at: float = 35.0
	var hits: int = 0
	var warnings: int = 0
	var factor: float = 1.0
	while at < 280.0:
		at += 70.0 * step
		var result: Dictionary = model.advance(id, at, lane, 70.0, step, protected, airborne)
		if result.event == "caught":
			hits += 1
		if int(result.warning) >= 0:
			warnings += 1
		factor = minf(factor, float(result.speed_factor))
	return {"hits": hits, "warnings": warnings, "minimum_factor": factor}


func _run() -> void:
	for step in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0, 0.1]:
		var model = _model()
		var result: Dictionary = _drive(model, "player", 2.8, false, false, step)
		_check(int(result.hits) == 1, "Exactly one 70 m/s crossing is caught at step %s" % step)
		_check(int(result.warnings) > 0, "A readable warning precedes every catch")
		_check(is_equal_approx(float(result.minimum_factor), RULES.SPEED_FACTOR), "Catch uses the authored speed factor")
		_check(float(model.racers.player.remaining) == 0.0, "The lasso releases without input")
		_check(float(model.racers.player.immunity) > 0.0, "Recovery immunity outlasts the short hold")
	for lane in [-2.8, 0.0, 4.5]:
		_check(int(_drive(_model(), "player", lane, false, false, 1.0 / 60.0).hits) == 0, "Safe lane %s avoids the lasso" % lane)
	_check(int(_drive(_model(), "player", 2.8, true, false, 1.0 / 60.0).hits) == 0, "Shield or boost blocks the throw")
	_check(int(_drive(_model(), "player", 2.8, false, true, 1.0 / 60.0).hits) == 0, "Airborne racers are not pulled out of a jump")
	_check(int(_drive(_model(true), "player", 2.8, false, false, 1.0 / 60.0).hits) == 1, "A second crew cannot chain-stun the racer")
	var model = _model()
	var at: float = 40.0
	while at < 173.0:
		at = minf(173.0, at + 70.0 / 60.0)
		model.advance("swept", at, 4.8, 70.0, 1.0 / 60.0)
	var swept: Dictionary = model.advance("swept", 187.0, 0.8, 70.0, 0.2)
	_check(swept.event == "caught", "Lane is interpolated at the crossing, not sampled only at the end")
	var paused_clock: float = float(model.racers.swept.clock)
	var paused_remaining: float = float(model.racers.swept.remaining)
	model.advance("swept", 187.0, 0.8, 70.0, 0.0)
	_check(float(model.racers.swept.clock) == paused_clock and float(model.racers.swept.remaining) == paused_remaining, "Paused time does not consume the catch or immunity")
	var released: Dictionary = model.advance("swept", 188.0, 0.8, 70.0, 1.0 / 60.0, true)
	_check(released.event == "released" and float(released.speed_factor) == 1.0, "Activating counterplay immediately releases an existing catch")
	model = _model()
	model.advance("spawn", 178.0, 2.8, 70.0, 1.0 / 60.0)
	var spawn: Dictionary = model.advance("spawn", 182.0, 2.8, 70.0, 4.0 / 70.0)
	_check(spawn.event != "caught", "A restored or rescued racer cannot be hit without a full warning")
	model = _model()
	model.advance("rescue", 100.0, 2.8, 70.0, 1.0 / 60.0)
	model.advance("rescue", 100.0, 2.8, 70.0, 2.0)
	_check(model.advance("rescue", 300.0, 2.8, 70.0, 1.0 / 60.0).event != "caught", "A teleport does not sweep through intervening hazards")
	model = _model()
	var player: Dictionary = _drive(model, "player", 2.8, false, false, 1.0 / 60.0)
	var rival: Dictionary = _drive(model, "rival_0", 2.8, false, false, 1.0 / 60.0)
	_check(player == rival, "Player and rivals use exactly the same encounter rules")
	model = _model()
	var catches: int = 0
	at = 0.0
	while at < 400.0 * 20.0:
		at += 7.0
		if model.advance("endless", at, 2.8, 70.0, 0.1).event == "caught":
			catches += 1
	_check(catches == 20, "Continuous training remains lap-aware over twenty laps")
	_check(model.racers.endless.used.size() <= 2 and model.racers.endless.armed.size() <= 1, "Training state remains bounded")
	if failures == 0:
		print("[KartLasso] PASS: %d assertions; 70 m/s sweeps, counterplay, bounded hold, equal rival rules" % checks)
	quit(0 if failures == 0 else 1)
