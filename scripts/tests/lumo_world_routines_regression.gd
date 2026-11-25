extends SceneTree
## Behavior tests: authored animation requirement, bounded simulation,
## proximity/pause/accessibility, individual routines and dialog reachability.
const ROUTINES = preload("res://scripts/creative/lumo_world_routines.gd")
const DIALOG = preload("res://scripts/creative/lumo_world_dialog.gd")
const LAYER = preload("res://scripts/creative/lumo_world_open_world.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("[WorldRoutines] " + label)


func _run() -> void:
	var routine = ROUTINES.new()
	_check(routine.phase_index() == 0, "a visit starts in the morning")
	var home := Vector3(96, 0, 58.5)
	var far := Vector3(110, 0, 58.5)
	routine.elapsed = 40.0
	var next: Vector3 = routine.candidate("owl", home, home, far, 0.1, true)
	_check(next.distance_to(home) > 0.0 and next.distance_to(home) <= ROUTINES.WALK_SPEED * 0.1 + 0.00001, "a supported walk makes a small speed-limited step")
	_check(routine.candidate("owl", home, home, far, 0.1, false) == home, "a seated rig without walking cannot glide")
	_check(routine.candidate("owl", home, home, home + Vector3.RIGHT * 4.0, 0.1, true) == home, "NPC waits when a child approaches")
	_check(routine.candidate("owl", home, home, home + Vector3.RIGHT * 6.0, 0.1, true, true) == home, "driving has a wider stop distance")
	_check(routine.candidate("owl", home, home, far, 0.1, true, false, true) == home, "reduced motion suppresses travel")
	_check(routine.candidate("owl", home, home, far, 0.1, true, false, false, true) == home, "dialog/pause suppresses travel")
	_check(routine.candidate("owl", home, home, far, NAN, true) == home, "invalid delta cannot move an NPC")
	_check(routine.candidate("owl", home, home, Vector3.INF, 0.1, true) == home, "invalid observer cannot move an NPC")
	_check(routine.candidate("missing", home, home, far, 0.1, true) == home, "unknown identities stay in place")
	var before: float = routine.elapsed
	routine.advance(0.1, true)
	_check(routine.elapsed == before, "pause freezes the simulated day")
	routine.advance(INF)
	routine.advance(-1.0)
	_check(routine.elapsed == before, "invalid and negative time are ignored")
	routine.advance(60.0)
	_check(is_equal_approx(routine.elapsed - before, ROUTINES.MAX_STEP), "resume after a long frame has no large time jump")
	routine.elapsed = ROUTINES.PHASE_SECONDS - 0.05
	routine.advance(0.1)
	_check(routine.phase_index() == 1, "active time reaches the next activity")
	routine.elapsed = ROUTINES.PHASE_SECONDS * 4.0 - 0.05
	routine.advance(0.1)
	_check(routine.phase_index() == 0, "the simulated day wraps without losing tasks")

	var actor := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = 1.0
	library.add_animation("idle", idle)
	library.add_animation("kart_seated", idle.duplicate())
	actor.add_animation_library("", library)
	_check(ROUTINES.walk_clip(actor).is_empty(), "seated/idle clips do not masquerade as walking")
	var walk := Animation.new()
	walk.length = 1.0
	library.add_animation("walk", walk)
	_check(ROUTINES.walk_clip(actor) == "walk", "a real walking clip is recognized")
	actor.free()

	var layer = LAYER.new()
	_check(layer.model.ready(), "production quest content loads")
	_check(ROUTINES.PROFILES.size() == 9, "all nine existing NPCs have a routine")
	var interests: Dictionary = {}
	for entry in layer.model.content.figures:
		var id := str(entry.id)
		var profile: Dictionary = ROUTINES.PROFILES.get(id, {})
		_check(not profile.is_empty(), "existing figure has a routine: " + id)
		if profile.is_empty():
			continue
		interests[str(profile.interest)] = true
		var titles: Dictionary = {}
		for phase in range(4):
			routine.elapsed = phase * ROUTINES.PHASE_SECONDS
			var activity: Dictionary = routine.activity(id)
			titles[str(activity.title)] = true
			_check(not str(activity.detail).is_empty(), "activity has an individual explanation: " + id)
		_check(titles.size() == 4, "four distinct daily activities: " + id)
		var tree: Dictionary = layer.smalltalk_tree(id)
		_check(DIALOG.validate(tree, false).is_empty(), "routine dialog is structurally valid: " + id)
		var runner = DIALOG.new(tree, 2)
		runner.choose(2)
		_check(str(runner.view().get("id", "")) == "routine", "daily activity is reachable through real choice: " + id)
		runner.choose(2)
		_check(str(runner.view().get("id", "")) == "routine_learning", "learning connection is reachable: " + id)
		var source := layer.model.card_source(str(entry.card))
		_check(str(runner.view().get("text", "")).contains(str(layer.model.mission(source).title)), "learning dialog points to an existing task: " + id)
		var position: Vector3 = entry.position
		routine.elapsed = 0.0
		for frame in range(2400):
			routine.advance(0.1)
			position = routine.candidate(id, entry.position, position, entry.position + Vector3.RIGHT * 20.0, 0.1, true)
			if position.distance_to(entry.position) > ROUTINES.MAX_WANDER + 0.0001:
				_check(false, "routine never leaves local bounds: " + id)
				break
		_check(position.distance_to(entry.position) <= ROUTINES.MAX_WANDER + 0.0001, "local walking remains bounded: " + id)
	_check(interests.size() == 9, "interests differ between the nine figures")
	_check(layer.model.cards().is_empty(), "reading routine dialogs earns no cards")
	for value in layer.model.progress.values():
		_check(int(value) == 0, "routine conversations earn no mission progress")
	layer.free()
	print("[WorldRoutines] %s %d checks; %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
