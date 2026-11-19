extends SceneTree
## Every Lumo-Lauf course the way a child starts it on the phone: the boot scene
## with `--scene=run`, a real tap on the course card's "Los!" button, the
## loading card, the real countdown and the run itself with the scripted
## player, up to the finish, the result card (booked once) and a real tap on
## "Zur Spieleauswahl". Prints an event list of the first 30 seconds.
## Meant for a real renderer (xvfb + gl_compatibility); works headless as well.
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://scripts/tests/lumo_run_menu_probe.gd -- --scene=run --course=zauberwald
##
## Options after `--`: --course=<id>, --profile=low|medium|high, --run-seconds=<s>
## (course time; default: to the finish), --substeps=<n> extra simulation steps
## per drawn frame (the container draws in software, seconds per frame),
## --shots=<dir> pictures at --shot-times=<s,s,...> (course seconds),
## --seed=<n> the scripted player's seed, --react=<s> reaction delay of the
## scripted player on road courses (0.25-0.4 s like a child).

const CHILD_PLAYER = preload("res://scripts/tests/helpers/lumo_run_child.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")
const STEP: float = 1.0 / 60.0
## Course seconds of the event list.
const EVENT_WINDOW: float = 30.0
## Player and track events that count as something happening on screen.
const VISIBLE: Array[String] = [
	"jump",
	"dash",
	"air_dash",
	"shoot",
	"tumble",
	"loop_start",
	"letter",
	"ride",
	"stomp",
	"hit",
	"rescue",
	"bonus",
	"chase_start",
	"cart_on",
	"stumble",
	"splash",
	"fall",
	"bounce",
	"boost",
	"crate",
	"checkpoint",
	"moment_cue",
	"moment_done",
	"moment_missed",
]

var options: Dictionary = {}
var frame_log: Array = []
var events: Array[String] = []
var event_count: int = 0
var star_count: int = 0
var first_decision: float = -1.0
var game: Node = null
var rewards: Array[Dictionary] = []
## Pictures of the highlight: [name, course second] still to take.
var pending: Array = []
var acted: Dictionary = {}
var moment_shots: String = ""
## Seen from the outside (the same for every version of the game): what
## changes on screen, counted from Lumo's and the course's state.
var seen: Array[String] = []
var _was: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[pair[0]] = pair[1]
	var profile: String = str(options.get("profile", "medium"))
	var course_id: String = str(options.get("course", "dschungelherz"))
	var run_seconds: float = float(options.get("run-seconds", "900"))
	var substeps: int = int(options.get("substeps", "12"))
	var index: int = COURSES.index_of(course_id)
	root.get_node("SettingsStore").set_profile(profile)
	root.get_node("PerformanceManager").set_profile(
		{"low": 0, "medium": 1, "high": 2}.get(profile, 1), false
	)
	root.get_node("HostBridge").reward_reported.connect(
		func(payload: Dictionary) -> void: rewards.append(payload)
	)
	print(
		(
			"[RunMenuProbe] course=%s renderer=%s profile=%s window=%s"
			% [
				course_id,
				RenderingServer.get_current_rendering_method(),
				profile,
				str(root.get_visible_rect().size)
			]
		)
	)
	var started: int = Time.get_ticks_msec()
	change_scene_to_file("res://scenes/app/boot.tscn")
	var last: int = Time.get_ticks_usec()
	while game == null and Time.get_ticks_msec() - started < 60000:
		await process_frame
		last = _frame(last, "boot")
		var scene: Node = current_scene
		if scene != null and scene.has_method("start_course"):
			game = scene
	if game == null or index < 0:
		print("[RunMenuProbe] FAIL: run scene never opened (course index %d)" % index)
		quit(1)
		return
	print("[RunMenuProbe] run scene open after %d ms" % (Time.get_ticks_msec() - started))
	if DisplayServer.get_name() == "headless":
		# Without a window the first menu is laid out for a size nobody has.
		root.size = Vector2i(906, 1088)
	var button: Button = await _find_button("Course%d" % index, "Start", 60)
	if button == null:
		print("[RunMenuProbe] FAIL: no Los! button on card %d" % index)
		quit(1)
		return
	if game.has_signal("moment"):
		game.moment.connect(_on_moment)
	var tapped: int = Time.get_ticks_msec()
	print("[RunMenuProbe] tap %s at %s" % [str(button.get_path()), str(button.get_global_rect())])
	await _tap(button)
	var phases: Array[String] = []
	var seed: int = int(options.get("seed", "2"))
	var path: bool = bool(COURSES.course(index).get("path", false))
	var bot = CHILD_PLAYER.new(path, seed)
	bot.reaction = float(options.get("react", "0.3"))
	var tuning = load("res://scripts/games/run/run_tuning.gd")
	var pace: float = tuning.PATH_TIME_SCALE if path else tuning.ROAD_TIME_SCALE
	var running_since: int = -1
	var start_s: float = 0.0
	var max_speed: float = 0.0
	var shots: String = str(options.get("shots", ""))
	moment_shots = str(options.get("moment-shots", ""))
	var shot_times: Array[float] = []
	for part in str(options.get("shot-times", "0.3,8,20")).split(","):
		shot_times.append(float(part))
	var shot_index: int = 0
	var said: String = ""
	var banner: String = ""
	var kept: int = 0
	var decision_s: float = -1.0
	while Time.get_ticks_msec() - tapped < 1500000:
		await process_frame
		var name: String = str(game.Phase.keys()[game.phase])
		last = _frame(last, name)
		if phases.is_empty() or phases[-1] != name:
			phases.append(name)
			print("[RunMenuProbe] phase %s at +%d ms" % [name, Time.get_ticks_msec() - tapped])
		if game.phase == game.Phase.MENU and Time.get_ticks_msec() - tapped > 20000:
			print("[RunMenuProbe] FAIL: the tap did not open the course")
			break
		if game.phase == game.Phase.LOADING and Time.get_ticks_msec() - tapped > 120000:
			print("[RunMenuProbe] FAIL: still loading after 120 s")
			break
		if game.phase == game.Phase.FINISHED:
			break
		if game.phase != game.Phase.RUNNING:
			continue
		if running_since < 0:
			running_since = Time.get_ticks_msec()
			start_s = float(game.player.s)
			decision_s = _first_decision(game.plan)
			print(
				(
					(
						"[RunMenuProbe] first input possible %d ms after the tap "
						+ "(world build %d ms, countdown included)"
					)
					% [running_since - tapped, int(game.load_ms)]
				)
			)
			game.set_process(false)
		var steps_now: int = substeps
		if not moment_shots.is_empty() and (not pending.is_empty() or _moment_near()):
			steps_now = mini(substeps, 3)
		for _sub in range(maxi(1, steps_now)):
			if game.question_open:
				_log("Lernfrage beantwortet")
				game.answer(str(game.active_question.answer))
			else:
				bot.drive(game, STEP)
			game.advance(STEP)
			max_speed = maxf(max_speed, float(game.player.speed) * pace)
			if first_decision < 0.0 and decision_s > 0.0 and game.player.s >= decision_s:
				first_decision = float(game.elapsed)
				_log("erste Entscheidung (Hindernis/Weggabel bei %.0f m)" % (decision_s - start_s))
			var text: String = str(game.hud._toast_text)
			if text != said:
				said = text
				if not text.is_empty():
					_log("Ansage: " + text)
			var title: String = (
				str(game.hud.banner_label.text) if game.hud.banner_label.visible else ""
			)
			if title != banner:
				banner = title
				if not title.is_empty():
					_log("Titel: " + title)
			_watch_action()
			_watch_state()
			if int(game.track.kept) > kept and game.elapsed <= EVENT_WINDOW:
				star_count += int(game.track.kept) - kept
			kept = int(game.track.kept)
			if game.phase != game.Phase.RUNNING or game.elapsed > run_seconds:
				break
		if game.elapsed > run_seconds:
			break
		if (
			not shots.is_empty()
			and shot_index < shot_times.size()
			and game.elapsed >= shot_times[shot_index]
		):
			await _shot(shots, "%s_%s_%02d" % [course_id, profile, shot_index])
			shot_index += 1
		if (
			not moment_shots.is_empty()
			and not pending.is_empty()
			and game.elapsed >= float(pending[0][1])
		):
			var label: String = str(pending.pop_front()[0])
			var size: Vector2i = DisplayServer.window_get_size()
			await _shot(moment_shots, "%s_%s_%dx%d" % [course_id, label, size.x, size.y])
		if int(game.elapsed / 15.0) != int((game.elapsed - STEP * substeps) / 15.0):
			print(
				(
					"[RunMenuProbe] at %.0f s: s=%.0f of %.0f, speed %.1f"
					% [game.elapsed, game.player.s, game.plan.finish_s, game.player.speed]
				)
			)
	var finished: bool = game.phase == game.Phase.FINISHED
	var plan = game.plan
	var distance: float = float(game.player.s) - start_s
	var seconds: float = maxf(0.001, float(game.elapsed))
	print("[RunMenuProbe] seen in the first %.0f s (course time, from the state):" % EVENT_WINDOW)
	for line in seen:
		print("[RunMenuProbe]   " + line)
	print("[RunMenuProbe] %s seen_30s=%d" % [course_id, seen.size()])
	print("[RunMenuProbe] events of the first %.0f s (course time):" % EVENT_WINDOW)
	for line in events:
		print("[RunMenuProbe]   " + line)
	print(
		(
			"[RunMenuProbe] %s first_decision=%.1f s events_30s=%d stars_30s=%d"
			% [course_id, first_decision, event_count, star_count]
		)
	)
	print(
		(
			(
				"[RunMenuProbe] %s phases=%s build=%d ms finished=%s run=%.1f s distance=%.0f m "
				+ "screen_speed=%.1f m/s top=%.1f m/s stars=%d/%d stumbles=%d"
			)
			% [
				course_id,
				str(phases),
				int(game.load_ms),
				str(finished),
				seconds,
				distance,
				distance / seconds,
				max_speed,
				int(game.track.kept),
				int(plan.star_total),
				int(game.track.stumbles)
			]
		)
	)
	var ok: bool = (
		running_since >= 0 and distance > 20.0 and (finished or game.elapsed > run_seconds)
	)
	if finished:
		ok = await _check_result_and_leave() and ok
	frame_log.sort_custom(func(a, b): return a[0] > b[0])
	print(
		(
			"[RunMenuProbe] worst frames: %s"
			% str(frame_log.slice(0, 5).map(func(e): return "%s:%d ms" % [e[1], e[0]]))
		)
	)
	print("[RunMenuProbe] %s course=%s profile=%s" % ["PASS" if ok else "FAIL", course_id, profile])
	var sound: Node = root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	# The app-wide effects of the road courses: let go of the cached samples.
	var effects: Node = root.get_node_or_null("AudioManager")
	if effects != null and effects.get("_pool") != null:
		for voice in effects._pool:
			voice.stop()
			voice.stream = null
		effects._samples.clear()
	await create_timer(0.4).timeout
	quit(0 if ok else 1)


## Result card: the reward is booked exactly once, then a real tap on
## "Zur Spieleauswahl" leaves for the game hub.
func _check_result_and_leave() -> bool:
	var leave: Button = null
	for _i in range(240):
		await process_frame
		if str(game.menus.screen) == "result":
			leave = game.menus.find_child("LeaveGames", true, false)
			if leave != null and leave.is_visible_in_tree():
				break
	if leave == null:
		print("[RunMenuProbe] FAIL: no result card with a way back")
		return false
	var booked_on_finish: int = rewards.size()
	await _tap(leave)
	var arrived: String = ""
	for _i in range(240):
		await process_frame
		if current_scene != null and current_scene != game and is_instance_valid(current_scene):
			arrived = str(current_scene.scene_file_path)
			break
	var ids: Dictionary = {}
	for payload in rewards:
		ids[str(payload.get("resultId", ""))] = true
	print(
		(
			"[RunMenuProbe] result: rewards on finish %d, after leaving %d (distinct results %d), back to %s"
			% [booked_on_finish, rewards.size(), ids.size(), arrived]
		)
	)
	return ids.size() == 1 and arrived.ends_with("game_hub.tscn")


func _find_button(card_name: String, button_name: String, frames: int) -> Button:
	for i in range(frames):
		await process_frame
		if i < 20:
			continue
		var card: Node = game.menus.find_child(card_name, true, false)
		var button: Button = card.find_child(button_name, true, false) if card != null else null
		if (
			button != null
			and button.is_visible_in_tree()
			and root.get_visible_rect().encloses(button.get_global_rect())
		):
			return button
	return null


func _on_moment(kind: String, _detail: Dictionary) -> void:
	if kind == "moment_cue" and pending.size() < 3:
		pending.append(["1_ankuendigung", float(game.elapsed) + 0.7])
	elif kind == "moment_done":
		pending.append(["3_reaktion", float(game.elapsed) + 0.25])
	if not VISIBLE.has(kind) or game.elapsed > EVENT_WINDOW:
		return
	if kind == "jump" and not events.is_empty() and events[-1].ends_with(" jump"):
		return
	_log(kind)


## The action picture: Lumo in the air (or on the vine) over the highlight.
func _watch_action() -> void:
	if moment_shots.is_empty() or game.plan.get("moments") == null:
		return
	var player = game.player
	for index in range(game.plan.moments.size()):
		var spot: Dictionary = game.plan.moments[index]
		if acted.has(index) or not game.moments.calling(index):
			continue
		var over: bool = player.s >= float(spot.s0) + 1.0 and player.s <= float(spot.s1)
		if over and (not player.grounded or player.is_riding()):
			acted[index] = true
			pending.append(["2_aktion", float(game.elapsed) + 0.15])


func _watch_state() -> void:
	if game.elapsed > EVENT_WINDOW:
		return
	var player = game.player
	var track = game.track
	var now: Dictionary = {
		"jump": player.jumping and not player.grounded,
		"boost": player.boost_time > 0.05,
		"ride": player.is_riding(),
		"checkpoint": int(track.checkpoint),
		"stumbles": int(track.stumbles),
		"rescues": int(track.get("rescues") if track.get("rescues") != null else 0),
		"vy": float(player.vy),
		"s": float(player.s),
	}
	if not _was.is_empty():
		if now.jump and not _was.jump:
			_see("Sprung")
		if float(now.vy) > 11.0 and float(_was.vy) < 6.0 and not now.jump:
			_see("Pilz/Trampolin/Stampfer")
		if now.boost and not _was.boost:
			_see("Turbo")
		if now.ride and not _was.ride:
			_see("Fahrt (Liane/Fass/Seil)")
		if int(now.checkpoint) > int(_was.checkpoint):
			_see("Kontrollpunkt")
		if int(now.stumbles) > int(_was.stumbles):
			_see("Stolpern/Sturz")
		var from: float = float(_was.s)
		var to: float = float(now.s)
		if to > from and to - from < 5.0:
			var plan = game.plan
			for list in [plan.hurdles, plan.blockers, plan.enemies]:
				for item in list:
					if float(item.s) > from and float(item.s) <= to:
						_see("Hindernis passiert (%s)" % str(item.get("kind", "Hürde")))
			for list in [plan.channels, plan.platforms]:
				for item in list:
					if float(item.s0) > from and float(item.s0) <= to:
						_see("Graben/Plattform")
	_was = now


func _see(text: String) -> void:
	seen.append("%5.1f s  %s" % [float(game.elapsed), text])


func _moment_near() -> bool:
	if game.plan.get("moments") == null:
		return false
	for index in range(game.plan.moments.size()):
		var spot: Dictionary = game.plan.moments[index]
		if game.player.s >= float(spot.cue) - 2.0 and game.player.s <= float(spot.s1) + 30.0:
			return true
	return false


func _log(text: String) -> void:
	if game == null or game.elapsed > EVENT_WINDOW:
		return
	event_count += 1
	events.append("%5.1f s  %s" % [float(game.elapsed), text])


## A real tap on the button (touch reaches the app as a click, like on the device).
func _tap(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	point = point * Vector2(root.size) / root.get_visible_rect().size
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame


func _shot(folder: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(folder)
	image.save_png(folder.path_join(name + ".png"))
	print("[RunMenuProbe] picture %s" % folder.path_join(name + ".png"))


## Where the child first has to do something: jump, dodge, stomp, bounce or
## choose a way (metres along the course).
static func _first_decision(plan) -> float:
	var first: float = INF
	for list in [plan.hurdles, plan.blockers, plan.bounces, plan.enemies, plan.waits]:
		for item in list:
			if float(item.s) > plan.start_s:
				first = minf(first, float(item.s) - 1.5)
	for list in [plan.channels, plan.platforms, plan.branches]:
		for item in list:
			if float(item.s0) > plan.start_s:
				first = minf(first, float(item.s0) - 1.5)
	return first


func _frame(last: int, label: String) -> int:
	var now: int = Time.get_ticks_usec()
	frame_log.append([int((now - last) / 1000), label])
	return now
