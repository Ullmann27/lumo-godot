extends Node3D
# gdlint: disable=max-file-lines
## Free steering arcade racing, original Lumo worlds, five complete modes and host-safe saves.
## Product rule (Heinz, 2026-10-04): no learning questions, learning cups or answer timers in Kart.

const UI = preload("res://scripts/games/kart_ui_theme.gd")
const KART_AUDIO = preload("res://scripts/games/kart_audio.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const GARAGE = preload("res://scripts/games/kart_garage_menu.gd")
const INTRO = preload("res://scripts/games/kart_intro.gd")
const RECORDS = preload("res://scripts/games/kart_records.gd")
const ARENA = preload("res://scripts/games/kart_arena.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const PHYSICAL_LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")
const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")
const MINIMAP = preload("res://scripts/games/kart_minimap.gd")
const TOUCH_ACTION = preload("res://scripts/games/kart_touch_action.gd")
const JOYSTICK = preload("res://scripts/games/kart_joystick.gd")
const RIVAL_ITEM_FX = preload("res://scripts/games/kart_rival_item_fx.gd")
const VISUAL_GRADE = preload("res://scripts/games/kart_visual_grade.gd")
const SPEED_FX = preload("res://scripts/games/kart_speed_fx.gd")
const MYSTERY_PRISM = preload("res://scripts/games/kart_mystery_prism.gd")
const TOTAL_LAPS: int = 2
const ROAD_WIDTH: float = 10.8
const SESSION: String = "user://kart_sonnenhafen_session.cfg"
const PREFERENCES: String = "user://kart_preferences.cfg"
const BOOST_ACCELERATION_MULTIPLIER: float = 2.0
const DESIGN_VIEWPORT := Vector2(1280.0, 720.0)
const PEDAL_PAD_BASE_SIZE := Vector2(440.0, 300.0)
## Version 4 drops the removed learning-question state; older saves still resume as plain races.
const SESSION_VERSION: int = 4
const SESSION_VERSIONS: Array[int] = [1, 2, 3, 4]
const MODE_IDS: Array[String] = ["race", "cup", "time_trial", "training", "arena"]
## Drift turbo tiers: blue after 0.8 s of full steering, orange after 1.8 s.
const DRIFT_TIERS: Array[float] = [0.8, 1.8]
const DRIFT_BOOST_SECONDS: Array[float] = [1.0, 1.8]
## Arcade jump: strong gravity and a capped take-off speed keep flights short and readable.
## Tuned on the Himmelsinseln gap: 17 m/s (Entdecken) clears it, a crawl below ~13 m/s falls,
## turbo speed lands before the crystal cave.
const JUMP_GRAVITY: float = 30.0
const JUMP_MAX_LIFT: float = 4.0
## AI pulse is deliberately telegraphed: children get a readable dodge/shield window.
const RIVAL_PULSE_WARNING_SECONDS: float = 0.65
const RIVAL_PULSE_RADIUS: float = 9.5
## Save only bounded gameplay durations; absent fields keep older sessions neutral.
const RIVAL_SESSION_TIMERS: Dictionary = {
	"opponent_stuns": 2.3,
	"opponent_item_cooldowns": 1.8,
	"opponent_boost_times": 2.2,
	"opponent_shield_times": 5.0,
	"opponent_pulse_warning_times": RIVAL_PULSE_WARNING_SECONDS,
}
## Streckenvorschau vor dem Countdown: Kameraflug über markante Abschnitte,
## jederzeit per Tippen/Taste überspringbar, entfällt bei reduzierten Animationen.
const PREVIEW_SECONDS: float = 5.0
const PREVIEW_BLEND_SECONDS: float = 1.1
var curve: Curve3D
var world: LumoRaceWorld
var track_length: float
var distance: float = 0.0
var lane: float = 0.0
var lateral_velocity: float = 0.0
var steering: float = 0.0
var brake: float = 0.0
var speed: float = 0.0
var countdown: float = 3.5
var preview_left: float = 0.0
var preview_total: float = 0.0
## Kart-Einstieg: "auto" zeigt das Intro beim ersten Menü (nicht bei reduzierter
## Bewegung und nicht in automatisierten --script-Prüfungen), "force"/"off" für Tests.
var music_volume: float = 1.0
var effects_volume: float = 1.0
var intro_mode: String = "auto"
var intro_done: bool = false
var intro: Control
## Startaufstellung: Die Karts rollen in den letzten Sekunden der Vorschau aus
## GRID_ROLL_DISTANCE Metern auf ihre Startplätze.
const GRID_ROLL_SECONDS: float = 2.0
const GRID_ROLL_DISTANCE: float = 9.0
var grid_from: Array[Transform3D] = []
var grid_to: Array[Transform3D] = []
## Zuletzt beim Einrollen gesetzte Lage je Kart (erkennt Karts, die von außen versetzt wurden).
var grid_last: Array[Transform3D] = []
## Startampel: drei rote Lampen im Takt des Countdowns, dann alle grün.
const START_GREEN_SECONDS: float = 0.9
var start_lights: PanelContainer
var start_lamps: Array[Panel] = []
var start_green_left: float = 0.0
var countdown_label: Label
## Titelkarte der Streckenvorschau (Name, Weltmotto, Überspringen-Hinweis).
var preview_card: PanelContainer
var preview_name: Label
var preview_tag: Label
var preview_skip: Label
## Zieleinlauf-Kamerafahrt: läuft nach dem Ziel, bevor das Ergebnis erscheint.
const FINISH_CINE_SECONDS: float = 3.2
const FINISH_CINE_REDUCED_SECONDS: float = 0.35
var finish_cine_left: float = 0.0
var finish_coast_speed: float = 0.0
var finish_place: int = 0
var finish_confetti: Node3D
var lap_times: Array[float] = []
var lap_started_at: float = 0.0
var elapsed: float = 0.0
var boost_time: float = 0.0
var boosts: int = 1
var drift_charge: float = 0.0
var drift_tier_count: Array[int] = [0, 0]
var wall_contacts: int = 0
var airborne: bool = false
var vertical_speed: float = 0.0
var air_time: float = 0.0
var jump_count: int = 0
var landing_count: int = 0
var gap_falls: int = 0
var wall_sound_timer: float = 0.0
var wrong_way: bool = false
var wrong_way_seconds: float = 0.0
var drifting: bool = false
var racing: bool = false
var finished: bool = false
var paused: bool = false
var abandoned: bool = false
var rng := RandomNumberGenerator.new()
var player: LumoRaceKart
var camera: Camera3D
var speed_fx: Node3D
var opponents: Array[LumoRaceKart] = []
var opponent_distances: Array[float] = [-4, -7, -10, -13, -16]
var opponent_lanes: Array[float] = [-3.2, -1.65, -0.1, 1.45, 3.0]
var rival_contact_timer: float = 0.0
var checkpoint_index: int = 0
var result_id: String = ""
var result_payload: Dictionary = {}
var gems: Array[Node3D] = []
var gem_distances: Array[float] = []
var collected: Dictionary = {}
var item_boxes: Array[Node3D] = []
var item_box_distances: Array[float] = []
var item_box_collected: Dictionary = {}
var hud: Label
var message: Label
var boost_button: Control
var drift_button: Control
var joystick: Control
var gas_button: Control
var brake_button: Control
## Right-thumb pedals. With "Auto-Gas" the kart accelerates by itself (keyboard, tests, younger
## children); otherwise GAS must be held, as on a handheld kart racer.
var gas_held: bool = false
var auto_gas: bool = true
var modal_backdrop: ColorRect
var modal: PanelContainer
var modal_column: VBoxContainer
var modal_scroll: ScrollContainer
var modal_padding: MarginContainer
var pause_navigation: HBoxContainer
var safe_ui: Control
var muted: bool = false
var host_sound_enabled: bool = true
var host_reduce_motion: bool = false
var preferred_reduced_motion: bool = false
var reduced_motion: bool = false
var lightweight: bool = false
var difficulty: String = "gemuetlich"
var save_timer: float = 0.0
var hit_timer: float = 0.0
var obstacle_distances: Array[float] = []
var kart_audio: Node
var last_countdown_tick: int = 4
var engine_player: AudioStreamPlayer
var engine_playback: AudioStreamGeneratorPlayback
var materials: Dictionary = {}
var boxes: Dictionary = {}
var sphere_mesh: SphereMesh
var crystal_mesh: ArrayMesh
var star_mesh: ArrayMesh
var race_root: Node3D
var garage: Control
var menu_active: bool = true
var mode: String = "race"
var track_id: String = "sonnenhafen"
var selected_driver: String = "fox"
var selected_kart: String = "comet"
var loop_state = PHYSICAL_LOOP.new()
var loop_count: int = 0
var player_heading: float = 0.0
var physical_velocity := Vector3.ZERO
var previous_road_distance: float = 0.0
var offroad_seconds: float = 0.0
var reset_count: int = 0
var shield_time: float = 0.0
var shield_visual: MeshInstance3D
var pulse_visual: MeshInstance3D
var pulse_age: float = 1.0
var item: String = ""
var item_button: Control
var opponent_headings: Array[float] = []
var opponent_stuns: Array[float] = []
var opponent_items: Array[String] = []
var opponent_item_cooldowns: Array[float] = []
var opponent_boost_times: Array[float] = []
var opponent_shield_times: Array[float] = []
var opponent_pulse_warning_times: Array[float] = []
var opponent_item_fx: Array = []
var opponent_scores: Array[int] = []
var opponent_targets: Array[int] = []
var arena: Node3D
var arena_scores: int = 0
var arena_pickup_timers: Array[float] = []
var cup_index: int = 0
var cup_points: Array[int] = [0, 0, 0, 0, 0, 0]
var cup_results: Array = []
var pending_cup_next: bool = false
var completed_race: bool = false
var records = RECORDS.new()
var ghost: LumoRaceKart
var ghost_valid: bool = true
var best_record: bool = false
var setup_snapshot: Dictionary = {}
var control_brake: float = 0.0
var map: Control
var map_panel: PanelContainer
var hud_content: MarginContainer
var controls_row: HBoxContainer
var controls_gap: Control
var pedal_pad: Control
var top_menu_button: Button
var top_reset_button: Button
var top_pause_button: Button
var saved_session_available: bool = false
var session_config := ConfigFile.new()
var graphics_profile: String = "high"
var previous_scale := Vector2i(720, 1280)
var previous_size := Vector2i(720, 1280)
var previous_orientation: int = DisplayServer.SCREEN_PORTRAIT
var previous_auto_accept_quit: bool = true
var previous_quit_on_go_back: bool = true


func _ready() -> void:
	set_physics_process(false)
	rng.randomize()
	result_id = HostBridge.new_result_id()
	previous_auto_accept_quit = get_tree().auto_accept_quit
	previous_quit_on_go_back = get_tree().quit_on_go_back
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	_load_preferences()
	previous_scale = get_window().content_scale_size
	previous_size = get_window().size
	previous_orientation = DisplayServer.screen_get_orientation()
	get_window().content_scale_size = Vector2i(1280, 720)
	if OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
		if not await _wait_for_landscape():
			push_warning(
				"[KartFold] Host surface stayed non-landscape; continuing with responsive layout. "
				+ "The Kart still requests sensor-landscape; host orientation and hinge geometry "
				+ "must be provided by the Android integration."
			)
	elif DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		get_window().size = Vector2i(1280, 720)
	_build_ui()
	_build_engine_sound()
	saved_session_available = (
		session_config.load(SESSION) == OK
		and int(session_config.get_value("race", "version", 0)) in SESSION_VERSIONS
	)
	_show_garage()
	set_physics_process(true)
	print("[Kart] Holographic garage ready: five modes, twelve worlds, free steering")


func _wait_for_landscape() -> bool:
	# Native rotation is asynchronous. Build the heavy scene after the surface resizes.
	var deadline: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		var pixels: Vector2i = DisplayServer.window_get_size()
		if pixels.x > pixels.y and get_window().size.x > get_window().size.y:
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			print(
				(
					"[KartViewport] landscape surface=%s logical=%s"
					% [pixels, get_viewport().get_visible_rect().size]
				)
			)
			return true
		await get_tree().process_frame
	return false


func _build_world() -> void:
	if is_instance_valid(race_root):
		remove_child(race_root)
		race_root.queue_free()
	race_root = Node3D.new()
	race_root.name = "ActiveRace"
	add_child(race_root)
	gems.clear()
	gem_distances.clear()
	item_boxes.clear()
	item_box_distances.clear()
	item_box_collected.clear()
	obstacle_distances.clear()
	opponents.clear()
	opponent_headings.clear()
	opponent_stuns.clear()
	opponent_items.clear()
	opponent_item_cooldowns.clear()
	opponent_boost_times.clear()
	opponent_shield_times.clear()
	opponent_pulse_warning_times.clear()
	opponent_item_fx.clear()
	opponent_scores.clear()
	opponent_targets.clear()
	arena_pickup_timers.clear()
	ghost = null
	world = null
	arena = null
	crystal_mesh = _gem_mesh()
	star_mesh = SHAPES.star()
	if mode == "arena":
		arena = ARENA.new()
		race_root.add_child(arena)
		arena.build(lightweight)
		track_length = 240
		for position in arena.pickups:
			gems.append(_mesh(race_root, crystal_mesh, position, Color("89f3ff")))
			arena_pickup_timers.append(0.0)
	else:
		world = WORLD.new()
		race_root.add_child(world)
		world.build(lightweight, track_id)
		curve = world.curve
		track_length = world.length
		for i in range(24):
			# Gold star tokens (reference k03) on the courses; the arena keeps its crystals.
			var d: float = (float(i) + 0.5) * track_length / 24
			var at: Vector3 = _track_position(d, float(i % 3 - 1) * 2.3) + Vector3.UP * 0.95
			var token: MeshInstance3D = _mesh(race_root, star_mesh, at, Color("ffc94a"))
			token.scale = Vector3.ONE * 0.55
			token.material_override = _glow_material(Color("ffc94a"), 0.6)
			gems.append(token)
			gem_distances.append(d)
		for fraction in [0.12, 0.42, 0.74]:
			_turbo_pad(fraction * track_length)
		var item_layout: Array = [
			[0.18, -2.7],
			[0.34, 2.7],
			[0.53, 0.0],
			[0.69, -2.7],
			[0.86, 2.7],
		]
		for entry in item_layout:
			_item_box(float(entry[0]) * track_length, float(entry[1]))
	player = VEHICLE.new()
	var driver: Dictionary = CATALOG.entry(CATALOG.DRIVERS, selected_driver)
	player.configure(selected_driver, driver.color, selected_kart)
	player.reduced_motion = reduced_motion
	player.set_graphics_quality(graphics_profile)
	race_root.add_child(player)
	shield_visual = MeshInstance3D.new()
	var bubble := SphereMesh.new()
	bubble.radius = 1.7
	bubble.height = 3.4
	bubble.radial_segments = 24
	bubble.rings = 12
	shield_visual.mesh = bubble
	shield_visual.position.y = 1.0
	var shield_material := StandardMaterial3D.new()
	shield_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_material.albedo_color = Color(0.45, 0.88, 1.0, 0.15)
	shield_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shield_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_visual.material_override = shield_material
	shield_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield_visual.visible = false
	player.add_child(shield_visual)
	pulse_visual = MeshInstance3D.new()
	var pulse_mesh := TorusMesh.new()
	pulse_mesh.inner_radius = 0.92
	pulse_mesh.outer_radius = 1.08
	pulse_mesh.rings = 48
	pulse_mesh.ring_segments = 8
	pulse_visual.mesh = pulse_mesh
	var pulse_material := StandardMaterial3D.new()
	pulse_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pulse_material.albedo_color = Color("a8eaff")
	pulse_visual.material_override = pulse_material
	pulse_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pulse_visual.visible = false
	race_root.add_child(pulse_visual)
	var animals: Array[String] = ["otter", "rabbit", "badger", "cat", "fox"]
	var colors: Array[Color] = [Color("75d7f1"), Color("a696ee"), Color("83dab9"), Color("c8d8ef"), Color("6987db")]
	var rival_count: int = 0 if mode in ["time_trial", "training"] else 5
	for i in range(rival_count):
		var opponent: LumoRaceKart = VEHICLE.new()
		var rival_karts: Array[String] = ["noa_tide", "iva_aurora", "boru_rally", "nala_comet", "zuri_volt"]
		opponent.configure(animals[i], colors[i], rival_karts[i])
		opponent.reduced_motion = reduced_motion
		opponent.set_graphics_quality(graphics_profile)
		race_root.add_child(opponent)
		opponents.append(opponent)
		opponent_stuns.append(0.0)
		opponent_items.append("")
		opponent_item_cooldowns.append(0.0)
		opponent_boost_times.append(0.0)
		opponent_shield_times.append(0.0)
		opponent_pulse_warning_times.append(0.0)
		var rival_fx = RIVAL_ITEM_FX.new()
		rival_fx.set_reduced_motion(reduced_motion)
		opponent.add_child(rival_fx)
		opponent_item_fx.append(rival_fx)
		opponent_scores.append(0)
		opponent_targets.append(i * 5)
		opponent_headings.append(0.0)
	camera = Camera3D.new()
	camera.fov = VISUAL_GRADE.BASE_FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = true
	camera.far = 450 if graphics_profile == "high" else (340 if graphics_profile == "medium" else 260)
	race_root.add_child(camera)
	speed_fx = SPEED_FX.new()
	speed_fx.name = "CameraSpeedFx"
	camera.add_child(speed_fx)
	speed_fx.set_motion(0.0, false, reduced_motion)
	if mode == "arena":
		player.position = Vector3(0, 0.04, 28)
		player_heading = 0
		for i in range(opponents.size()):
			var angle: float = TAU * float(i + 1) / 6.0
			opponents[i].position = Vector3(sin(angle) * 28, 0.04, cos(angle) * 28)
			opponent_headings[i] = angle
	else:
		player.transform = world.reset_transform(distance, lane)
		player.position.y += 0.035
		player_heading = _heading(distance)
		previous_road_distance = fposmod(distance, track_length)
		for i in range(opponents.size()):
			opponents[i].transform = world.reset_transform(opponent_distances[i], opponent_lanes[i])
			opponent_headings[i] = _heading(opponent_distances[i])
		_prepare_grid_roll()
		if mode == "time_trial":
			records.begin(track_id, selected_kart, difficulty)
			if not records.replay.is_empty():
				ghost = VEHICLE.new()
				ghost.configure(selected_driver, Color("d3faff"), selected_kart)
				ghost.reduced_motion = reduced_motion
				race_root.add_child(ghost)
				_set_ghost_materials(ghost)
	_update_vehicles(0)
	_update_camera(1.0, true)
	map.configure(self)
	map_panel.visible = mode != "arena"


func _set_ghost_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.4, 0.88, 1.0, 0.23)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_ghost_materials(child)


func _show_garage() -> void:
	menu_active = true
	_update_audio()
	if is_instance_valid(kart_audio):
		kart_audio.set_paused(false)
		kart_audio.play_menu()
	racing = false
	paused = false
	modal.hide()
	modal_backdrop.hide()
	hud_content.hide()
	map_panel.hide()
	if is_instance_valid(race_root):
		race_root.hide()
	records.update_unlocks(ProgressStore.total_stars(), CATALOG.DRIVERS, CATALOG.KARTS)
	if is_instance_valid(garage):
		garage.queue_free()
	garage = GARAGE.new()
	garage.stars = ProgressStore.total_stars()
	garage.unlocked_ids = records.earned_unlocks
	garage.has_saved_race = saved_session_available
	garage.reduced_motion = reduced_motion
	garage.graphics_profile = graphics_profile
	if not setup_snapshot.is_empty():
		var restored: Dictionary = setup_snapshot.duplicate(true)
		restored["mode"] = _known_mode(str(restored.get("mode", "race")))
		garage.setup = restored
	garage.start_requested.connect(_start_selected_race)
	garage.resume_requested.connect(_resume_saved_race)
	garage.exit_requested.connect(_return_to_app)
	safe_ui.add_child(garage)
	if not intro_done:
		intro_done = true
		if _intro_wanted():
			intro = INTRO.new()
			intro.audio = kart_audio
			intro.reduced_motion = reduced_motion
			intro.finished.connect(func(): intro = null)
			safe_ui.add_child(intro)


func _intro_wanted() -> bool:
	if intro_mode == "off" or reduced_motion:
		return false
	if intro_mode == "force":
		return true
	# Automatisierte Szenenprüfungen starten mit --script und erwarten das Menü sofort.
	return not OS.get_cmdline_args().has("--script")


func _start_selected_race(setup: Dictionary) -> void:
	setup_snapshot = setup.duplicate(true)
	mode = _known_mode(str(setup.get("mode", "race")))
	selected_driver = str(setup.get("driver", "fox"))
	selected_kart = str(setup.get("kart", "comet"))
	track_id = str(setup.get("track", "sonnenhafen"))
	difficulty = str(setup.get("difficulty", "gemuetlich"))
	cup_index = 0
	cup_points = [0, 0, 0, 0, 0, 0]
	cup_results.clear()
	if mode == "cup":
		track_id = str(CATALOG.TRACKS[0].id)
	_begin_race()


static func _known_mode(requested: String) -> String:
	# Saved setups from older builds may still name the removed learning cup.
	if requested == "learn_cup":
		return "cup"
	return requested if requested in MODE_IDS else "race"


func _begin_race() -> void:
	loop_state = PHYSICAL_LOOP.new()
	loop_count = 0
	if is_instance_valid(garage):
		garage.queue_free()
	menu_active = false
	hud_content.show()
	modal.hide()
	finished = false
	completed_race = false
	paused = false
	racing = false
	abandoned = false
	pending_cup_next = false
	distance = 0
	lane = 0
	elapsed = 0
	countdown = 3.5
	last_countdown_tick = 4
	preview_total = PREVIEW_SECONDS if mode != "arena" and not reduced_motion else 0.0
	preview_left = preview_total
	finish_cine_left = 0.0
	finish_place = 0
	lap_times.clear()
	lap_started_at = 0.0
	if is_instance_valid(finish_confetti):
		finish_confetti.queue_free()
	if is_instance_valid(controls_row):
		controls_row.show()
	start_green_left = 0.0
	if is_instance_valid(start_lights):
		start_lights.hide()
	speed = 0
	boost_time = 0
	boosts = 1
	steering = 0
	brake = 0
	control_brake = 0
	drift_charge = 0
	drift_tier_count = [0, 0]
	wall_contacts = 0
	airborne = false
	vertical_speed = 0
	air_time = 0
	jump_count = 0
	landing_count = 0
	gap_falls = 0
	wrong_way = false
	wrong_way_seconds = 0
	drifting = false
	shield_time = 0
	item = ""
	physical_velocity = Vector3.ZERO
	checkpoint_index = 0
	arena_scores = 0
	reset_count = 0
	offroad_seconds = 0
	ghost_valid = true
	best_record = false
	collected.clear()
	opponent_distances = [-4, -7, -10, -13, -16]
	opponent_lanes = [-3.2, -1.65, -0.1, 1.45, 3.0]
	result_id = HostBridge.new_result_id()
	result_payload = {}
	_build_world()
	if is_instance_valid(kart_audio):
		kart_audio.set_paused(false)
		kart_audio.play_track("arena" if mode == "arena" else track_id)
	message.text = (
		"Stick links lenkt · rechts GAS halten, BREMSE, DRIFT, SPEED, ITEM"
		if OS.has_feature("android") or OS.has_feature("ios")
		else "W: Gas · S: Bremse · A/D: lenken · Umschalt: Drift · Leertaste: Boost · E: Item"
	)
	_save_preferences()
	_save_session()
	# Showing the race after the garage changes container minimum sizes. The
	# world also changes minimap visibility; resolve both for the actual surface.
	_apply_responsive_layout()
	_apply_responsive_layout.call_deferred()


func _resume_saved_race() -> void:
	if session_config.load(SESSION) != OK:
		return
	mode = _known_mode(str(session_config.get_value("race", "mode", "race")))
	track_id = str(session_config.get_value("race", "track_id", "sonnenhafen"))
	selected_driver = str(session_config.get_value("race", "selected_driver", "fox"))
	selected_kart = str(session_config.get_value("race", "selected_kart", "comet"))
	if is_instance_valid(garage):
		garage.queue_free()
	menu_active = false
	hud_content.show()
	_build_world()
	_apply_responsive_layout()
	_apply_responsive_layout.call_deferred()
	if _restore_session():
		if completed_race and not finished:
			# A pre-version-4 learning cup could be saved after the finish line while its
			# question was open. The race is complete, so show and award the result now.
			_finish(false)
			return
		if is_instance_valid(kart_audio):
			kart_audio.play_track("arena" if mode == "arena" else track_id)
		_pause()
		message.text = "Deine Fahrt ist gespeichert. Fahre weiter, wenn du bereit bist."
	else:
		_begin_race()


func _forward(d: float) -> Vector3:
	return world.forward(d)


func _track_position(d: float, offset: float) -> Vector3:
	return world.position_at(d, offset)


func _heading(d: float) -> float:
	var ahead: Vector3 = _forward(d)
	return atan2(-ahead.x, -ahead.z)


func _style(color: Color, radius: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.10, 0.18, 0.96) if color.r > 0.75 and color.g > 0.65 else color
	style.border_color = Color(0.43, 0.77, 0.94, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0.07, 0.16, 0.24, 0.22)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	return style


func _label(text: String, size: int = 23) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_font_override("font", UI.HEADING)
	label.add_theme_color_override("font_color", Color("f4f8ff"))
	return label


func _button(text: String, callback: Callable, color: Color = Color("153757")) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(80, 58)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color("f4f8ff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("8ca8c7"))
	button.add_theme_stylebox_override("normal", _style(color))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.15)))
	button.add_theme_stylebox_override("disabled", _style(Color("708287")))
	button.pressed.connect(callback)
	return button


func _action(text: String, callback: Callable, color: Color, diameter: float) -> Control:
	var button: Control = TOUCH_ACTION.new()
	button.text = text
	button.accent = color
	button.custom_minimum_size = Vector2.ONE * diameter
	button.pressed.connect(callback)
	return button


## Right-hand cluster like a handheld kart racer: big GAS under the thumb, BREMSE beside it,
## DRIFT and BOOST above, ITEM to the left. Every button tracks its own finger.
func _build_pedal_pad() -> Control:
	var pad := Control.new()
	pad.name = "PedalPad"
	pad.custom_minimum_size = PEDAL_PAD_BASE_SIZE
	pad.size_flags_vertical = Control.SIZE_SHRINK_END
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pedal_pad = pad
	gas_button = _action("GAS", func(): pass, Color("7cf29c"), 156)
	gas_button.name = "GasPedal"
	gas_button.icon_id = "gas"
	gas_button.button_down.connect(func(): gas_held = true)
	gas_button.button_up.connect(func(): gas_held = false)
	brake_button = _action("BREMSE", func(): pass, Color("ff8a7a"), 116)
	brake_button.name = "BrakePedal"
	brake_button.icon_id = "brake"
	brake_button.button_down.connect(func(): control_brake = 1.0)
	brake_button.button_up.connect(func(): control_brake = 0.0)
	drift_button = _action("DRIFT\nHALTEN", func(): pass, Color("bc8eff"), 106)
	drift_button.name = "DriftAction"
	drift_button.icon_id = "drift"
	drift_button.button_down.connect(func(): drifting = racing and not paused)
	drift_button.button_up.connect(_release_drift)
	boost_button = _action("SPEED\n◆ 1", _boost, Color("66f7e8"), 112)
	boost_button.name = "BoostAction"
	boost_button.icon_id = "boost"
	item_button = _action("ITEM\n◇", _use_item, Color("a7c5ff"), 94)
	item_button.name = "ItemAction"
	item_button.icon_id = "item"
	var layout: Array = [
		[gas_button, Vector2(361, 222), 156],
		[brake_button, Vector2(222, 242), 116],
		[drift_button, Vector2(228, 108), 106],
		[boost_button, Vector2(370, 66), 112],
		[item_button, Vector2(98, 228), 94]
	]
	for entry in layout:
		var button: Control = entry[0]
		var centre: Vector2 = entry[1]
		button.set_meta("kart_base_centre", centre)
		button.set_meta("kart_base_diameter", entry[2])
		pad.add_child(button)
		button.size = button.custom_minimum_size
		button.position = centre - button.custom_minimum_size * 0.5
	return pad


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	safe_ui = Control.new()
	safe_ui.name = "RaceSafeArea"
	safe_ui.theme = UI.create()
	safe_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(safe_ui)
	var safe := MarginContainer.new()
	hud_content = safe
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		safe.add_theme_constant_override("margin_" + side, 22)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_ui.add_child(safe)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	safe.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	top_menu_button = _button("‹ Menü", _pause, Color(0.035, 0.085, 0.16, 0.82))
	top.add_child(top_menu_button)
	top_reset_button = _button("↺", _reset_kart, Color(0.035, 0.085, 0.16, 0.82))
	top.add_child(top_reset_button)
	var hud_panel := PanelContainer.new()
	hud_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.085, 0.16, 0.76)))
	top.add_child(hud_panel)
	hud = _label("SONNENHAFEN", 23)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.autowrap_mode = TextServer.AUTOWRAP_OFF
	hud.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud_panel.add_child(hud)
	top_pause_button = _button("Ⅱ Pause", _pause, Color(0.035, 0.085, 0.16, 0.82))
	top.add_child(top_pause_button)
	message = _label("", 21)
	message.add_theme_color_override("font_color", Color("f4f8ff"))
	message.add_theme_color_override("font_shadow_color", Color("203f58"))
	message.add_theme_constant_override("shadow_offset_x", 1)
	message.add_theme_constant_override("shadow_offset_y", 2)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(message)
	call_deferred("_build_start_lights")
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	controls_row = HBoxContainer.new()
	controls_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	controls_row.add_theme_constant_override("separation", 20)
	column.add_child(controls_row)
	joystick = JOYSTICK.new()
	joystick.custom_minimum_size = Vector2(200, 200)
	joystick.size_flags_vertical = Control.SIZE_SHRINK_END
	# The stick only steers; braking has its own pedal on the right.
	joystick.axis_changed.connect(func(value: Vector2): steering = value.x)
	controls_row.add_child(joystick)
	controls_gap = Control.new()
	controls_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_row.add_child(controls_gap)
	pedal_pad = _build_pedal_pad()
	controls_row.add_child(pedal_pad)
	map_panel = PanelContainer.new()
	# Top right, below the HUD bar, so it never covers the right-thumb pedal pad.
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map_panel.offset_left = -210
	map_panel.offset_right = -22
	map_panel.offset_top = 104
	map_panel.offset_bottom = 260
	map_panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.065, 0.13, 0.78)))
	map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_ui.add_child(map_panel)
	map = MINIMAP.new()
	map.custom_minimum_size = Vector2(160, 128)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(map)
	modal_backdrop = ColorRect.new()
	modal_backdrop.color = Color(0.015, 0.045, 0.09, 0.46)
	modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_backdrop.hide()
	safe_ui.add_child(modal_backdrop)
	modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -310
	modal.offset_right = 310
	modal.offset_top = -260
	modal.offset_bottom = 260
	modal.add_theme_stylebox_override("panel", _style(Color("0b1b32"), 24))
	safe_ui.add_child(modal)
	modal.visibility_changed.connect(func(): modal_backdrop.visible = modal.visible and not menu_active)
	modal_column = VBoxContainer.new()
	modal_column.add_theme_constant_override("separation", 10)
	var modal_body := VBoxContainer.new()
	modal_body.add_theme_constant_override("separation", 10)
	modal.add_child(modal_body)
	modal_scroll = ScrollContainer.new()
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_body.add_child(modal_scroll)
	modal_padding = MarginContainer.new()
	modal_padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		modal_padding.add_theme_constant_override("margin_" + side, 8)
	modal_scroll.add_child(modal_padding)
	modal_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_padding.add_child(modal_column)
	# Return actions stay outside the scrolling settings on compact landscapes.
	pause_navigation = HBoxContainer.new()
	pause_navigation.name = "PauseNavigation"
	pause_navigation.add_theme_constant_override("separation", 10)
	modal_body.add_child(pause_navigation)
	var games := _button("Zur Spieleauswahl", _return_to_world)
	games.name = "ReturnToGames"
	var learn := _button("Zum Lernen", func(): _return_to_app("learn"))
	learn.name = "ReturnToLearning"
	for button in [games, learn]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 76
		pause_navigation.add_child(button)
	pause_navigation.hide()
	modal.hide()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_safe_area()


static func _scaled_safe_insets(
	insets: Rect2, physical_size: Vector2, logical_size: Vector2
) -> Rect2:
	if physical_size.x <= 0 or physical_size.y <= 0:
		return Rect2()
	var scale: Vector2 = logical_size / physical_size
	return Rect2(
		Vector2(maxf(0, insets.position.x), maxf(0, insets.position.y)) * scale,
		Vector2(maxf(0, insets.size.x), maxf(0, insets.size.y)) * scale
	)


func _apply_safe_area(insets: Rect2, physical_size: Vector2) -> void:
	var logical_size: Vector2 = get_viewport().get_visible_rect().size
	var scaled: Rect2 = _scaled_safe_insets(insets, physical_size, logical_size)
	safe_ui.offset_left = scaled.position.x
	safe_ui.offset_top = scaled.position.y
	safe_ui.offset_right = -scaled.size.x
	safe_ui.offset_bottom = -scaled.size.y
	safe_ui.set_meta("kart_safe_insets_applied", true)
	call_deferred("_apply_responsive_layout")


func _on_viewport_size_changed() -> void:
	_update_safe_area()
	_apply_responsive_layout()


func _update_safe_area() -> void:
	if not is_instance_valid(safe_ui):
		return
	var insets := Rect2()
	if OS.has_feature("android") or OS.has_feature("ios"):
		insets = MobileRuntime.get_safe_area_insets()
		# Usable screen bounds alone can omit camera cutouts in immersive mode.
		var screen: Vector2i = DisplayServer.screen_get_size()
		var unobscured: Rect2i = DisplayServer.get_display_safe_area()
		if screen.x > 0 and screen.y > 0 and unobscured.has_area():
			insets.position.x = maxf(insets.position.x, unobscured.position.x)
			insets.position.y = maxf(insets.position.y, unobscured.position.y)
			insets.size.x = maxf(insets.size.x, screen.x - unobscured.end.x)
			insets.size.y = maxf(insets.size.y, screen.y - unobscured.end.y)
	_apply_safe_area(insets, Vector2(get_window().size))
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	if (
		not is_inside_tree()
		or not is_instance_valid(safe_ui)
		or not is_instance_valid(controls_row)
	):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size: Vector2 = Vector2(get_window().size)
	if (
		viewport_size.x <= 0.0
		or viewport_size.y <= 0.0
		or window_size.x <= 0.0
		or window_size.y <= 0.0
	):
		return
	var ui_scale: float = maxf(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
	var display_size: Vector2 = window_size
	var compact: bool = display_size.x < 900.0 or display_size.x < display_size.y
	var compact_portrait: bool = display_size.x < display_size.y
	var short_landscape: bool = not compact_portrait and safe_ui.size.y / ui_scale < 360.0
	var margin_dp: float = clampf(minf(display_size.x, display_size.y) * 0.025, 10.0, 22.0)
	if short_landscape:
		margin_dp = 8.0
	_apply_ui_scale(safe_ui, ui_scale)
	hud_content.get_child(0).add_theme_constant_override("separation", roundi(2.0 * ui_scale) if short_landscape else 12)
	message.autowrap_mode = TextServer.AUTOWRAP_OFF if short_landscape else TextServer.AUTOWRAP_WORD_SMART
	message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var message_font: int = roundi((14.0 if short_landscape else 21.0) * ui_scale)
	message.add_theme_font_size_override("font_size", message_font)
	# Mit Auslassungspunkten meldet ein Label nur 1 px Mindesthöhe; der Spalten-
	# Abstandshalter nahm ihm dann den ganzen Platz und Countdown, „LOS!“ und
	# Rennhinweise waren unsichtbar. Eine (schmal) bzw. zwei Zeilen reservieren.
	message.custom_minimum_size.y = ceilf(message_font * (1.4 if short_landscape else 2.8))
	for side in ["left", "right", "top", "bottom"]:
		hud_content.add_theme_constant_override("margin_" + side, roundi(margin_dp * ui_scale))
	var available_width: float = maxf(1.0, safe_ui.size.x / ui_scale - margin_dp * 2.0)
	# Near-square inner displays need a proper large control deck. Use the current
	# available surface, not a Samsung model name or the fixed 1280x720 canvas.
	var shortest: float = minf(display_size.x, display_size.y)
	var expanded_controls: bool = shortest >= 600.0 and maxf(display_size.x, display_size.y) / shortest <= 1.65
	if expanded_controls:
		# Leave the chase camera's central driver visible on inner Fold displays.
		# The right actions form a narrower two-column deck; touch targets still
		# grow with the short edge rather than filling the entire lower screen.
		var deck_scale: float = minf(shortest / 760.0, available_width / 596.0)
		deck_scale = clampf(deck_scale, 0.70, 2.65)
		joystick.custom_minimum_size = Vector2.ONE * 248.0 * deck_scale * ui_scale
		# Keep a real inset around every target, including scaled floating-point
		# bounds when a Fold display resizes and the safe area is reapplied.
		pedal_pad.custom_minimum_size = Vector2(328, 352) * deck_scale * ui_scale
		controls_row.add_theme_constant_override("separation", roundi(20.0 * deck_scale * ui_scale))
		controls_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls_gap.custom_minimum_size = Vector2.ZERO
		var fold_actions: Dictionary = {
			"DriftAction": [Vector2(62, 62), 116.0],
			"BoostAction": [Vector2(236, 70), 124.0],
			"ItemAction": [Vector2(62, 180), 100.0],
			"BrakePedal": [Vector2(62, 294), 108.0],
			"GasPedal": [Vector2(236, 254), 176.0]
		}
		for child in pedal_pad.get_children():
			if child is Control:
				var spec: Array = fold_actions[child.name]
				child.custom_minimum_size = Vector2.ONE * float(spec[1]) * deck_scale * ui_scale
				child.size = child.custom_minimum_size
				child.position = Vector2(spec[0]) * deck_scale * ui_scale - child.size * 0.5
	elif compact_portrait:
		var gap: float = 4.0
		var stick_size: float = clampf(available_width * 0.32, 88.0, 154.0)
		var pad_width: float = maxf(152.0, available_width - stick_size - gap)
		var pad_height: float = clampf(display_size.y * 0.24, 176.0, 240.0)
		joystick.custom_minimum_size = Vector2.ONE * stick_size * ui_scale
		pedal_pad.custom_minimum_size = Vector2(pad_width, pad_height) * ui_scale
		controls_row.add_theme_constant_override("separation", roundi(gap * ui_scale))
		controls_gap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		controls_gap.custom_minimum_size = Vector2(gap * ui_scale, 1.0)
		var diameter: float = maxf(44.0, minf(68.0, minf(pad_width * 0.28, pad_height * 0.26)))
		var compact_positions: Dictionary = {
			"DriftAction": Vector2(pad_width * 0.28, pad_height * 0.2),
			"BoostAction": Vector2(pad_width * 0.72, pad_height * 0.2),
			"ItemAction": Vector2(pad_width * 0.28, pad_height * 0.5),
			"BrakePedal": Vector2(pad_width * 0.72, pad_height * 0.5),
			"GasPedal": Vector2(pad_width * 0.5, pad_height * 0.82)
		}
		for child in pedal_pad.get_children():
			if not child is Control:
				continue
			var button: Control = child
			var button_size: float = diameter * (1.15 if button.name == "GasPedal" else 1.0)
			button.custom_minimum_size = Vector2.ONE * button_size * ui_scale
			button.size = button.custom_minimum_size
			button.position = compact_positions[button.name] * ui_scale - button.size * 0.5
	elif short_landscape:
		# A short landscape needs two rows of thumb actions, not a scaled-down
		# 300px-tall cluster. Every action remains at least 44 physical pixels.
		joystick.custom_minimum_size = Vector2.ONE * 96.0 * ui_scale
		pedal_pad.custom_minimum_size = Vector2(180, 100) * ui_scale
		controls_row.add_theme_constant_override("separation", roundi(8.0 * ui_scale))
		controls_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls_gap.custom_minimum_size = Vector2.ZERO
		var short_actions: Dictionary = {
			"DriftAction": [Vector2(84, 24), 48.0],
			"BoostAction": [Vector2(148, 24), 48.0],
			"ItemAction": [Vector2(24, 74), 44.0],
			"BrakePedal": [Vector2(84, 74), 48.0],
			"GasPedal": [Vector2(148, 74), 52.0]
		}
		for child in pedal_pad.get_children():
			if child is Control:
				var spec: Array = short_actions[child.name]
				child.custom_minimum_size = Vector2.ONE * float(spec[1]) * ui_scale
				child.size = child.custom_minimum_size
				child.position = Vector2(spec[0]) * ui_scale - child.size * 0.5
	else:
		var size_scale: float = clampf(
			minf(display_size.y / 720.0, available_width / 700.0), 0.64, 1.0
		)
		joystick.custom_minimum_size = Vector2.ONE * 200.0 * size_scale * ui_scale
		pedal_pad.custom_minimum_size = Vector2(440.0, 300.0) * size_scale * ui_scale
		controls_row.add_theme_constant_override("separation", roundi(20.0 * size_scale * ui_scale))
		controls_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls_gap.custom_minimum_size = Vector2.ZERO
		for child in pedal_pad.get_children():
			if not child is Control:
				continue
			var button: Control = child
			var base_centre: Vector2 = button.get_meta("kart_base_centre")
			var button_size: float = float(button.get_meta("kart_base_diameter")) * size_scale
			button.custom_minimum_size = Vector2.ONE * button_size * ui_scale
			button.size = button.custom_minimum_size
			button.position = base_centre * size_scale * ui_scale - button.size * 0.5
	for action in pedal_pad.get_children():
		if action.has_method("_apply_label_size"):
			action._apply_label_size()
	top_menu_button.visible = not compact
	top_reset_button.visible = not compact
	top_pause_button.visible = true
	var top_button_size: Vector2 = Vector2(112, 56) if compact else Vector2(80, 58)
	if short_landscape:
		top_button_size = Vector2(92, 44)
	hud.add_theme_font_size_override(
		"font_size", roundi((15.0 if compact_portrait or short_landscape else (18.0 if compact else 23.0)) * ui_scale)
	)
	var modal_width: float = minf(
		620.0 * ui_scale, maxf(1.0, safe_ui.size.x - margin_dp * 2.0 * ui_scale)
	)
	var modal_height: float = minf(
		520.0 * ui_scale, maxf(1.0, safe_ui.size.y - margin_dp * 2.0 * ui_scale)
	)
	for side in ["left", "right", "top", "bottom"]:
		modal_padding.add_theme_constant_override("margin_" + side, roundi(8.0 * ui_scale))
	for button in [top_menu_button, top_reset_button, top_pause_button]:
		button.custom_minimum_size = top_button_size * ui_scale
		button.add_theme_font_size_override("font_size", roundi((15.0 if short_landscape else 21.0) * ui_scale))
	for button in pause_navigation.get_children():
		if button is Button:
			button.custom_minimum_size.y = (44.0 if compact else 76.0) * ui_scale
			button.custom_minimum_size.x = maxf(
				44.0 * ui_scale, (modal_width - 24.0 * ui_scale) * 0.5
			)
			button.add_theme_font_size_override(
				"font_size", roundi((15.0 if compact else 18.0) * ui_scale)
			)
			if compact:
				button.text = "Spiele" if button.name == "ReturnToGames" else "Lernen"
			else:
				button.text = (
					"Zur Spieleauswahl"
					if button.name == "ReturnToGames"
					else "Zum Lernen"
				)
	map_panel.visible = mode != "arena" and not compact and not short_landscape
	modal.offset_left = -modal_width * 0.5
	modal.offset_right = modal_width * 0.5
	modal.offset_top = -modal_height * 0.5
	modal.offset_bottom = modal_height * 0.5
	# A Container can grow its offsets while an old minimum size is being
	# rescaled. Restore the anchored rectangle after all new minimums are set.
	hud_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _apply_ui_scale(control: Node, ui_scale: float) -> void:
	# The garage owns its responsive typography and preview sizing.
	if control == garage:
		return
	if control is Control:
		var ui_control: Control = control
		if not ui_control.has_meta("kart_base_minimum_size"):
			ui_control.set_meta("kart_base_minimum_size", ui_control.custom_minimum_size)
		ui_control.custom_minimum_size = (
			ui_control.get_meta("kart_base_minimum_size") * ui_scale
		)
		if ui_control is Label or ui_control is Button:
			if not ui_control.has_meta("kart_base_font_size"):
				ui_control.set_meta("kart_base_font_size", ui_control.get_theme_font_size("font_size"))
			ui_control.add_theme_font_size_override(
				"font_size", roundi(float(ui_control.get_meta("kart_base_font_size")) * ui_scale)
			)
	for child in control.get_children():
		_apply_ui_scale(child, ui_scale)


func _physics_process(delta: float) -> void:
	if menu_active or not is_instance_valid(player):
		return
	if finished and finish_cine_left > 0.0:
		if not paused:
			_update_finish_cine(delta)
		return
	if preview_left > 0.0:
		if countdown > 0.0 and not finished:
			if not paused:
				_update_preview(delta)
			return
		# Countdown wurde von außen beendet (Tests): Vorschau entfällt, von außen
		# gesetzte Lage und Blickrichtung bleiben erhalten.
		_end_preview(false)
	if not paused and not finished and countdown > 0:
		countdown = maxf(0, countdown - delta)
		var tick: int = ceili(countdown)
		if tick != last_countdown_tick:
			last_countdown_tick = tick
			_sound_effect("start" if tick == 0 else "countdown")
		# Die große Zahl steht an der Startampel; darunter bleibt der Steuerungshinweis.
		if countdown == 0:
			message.text = "LOS! Finde deinen Weg."
		if countdown == 0:
			start_green_left = START_GREEN_SECONDS
			racing = true
			_update_audio()
	if racing and not paused and not finished:
		elapsed += delta
		var axis: float = Input.get_axis("ui_left", "ui_right")
		if Input.is_physical_key_pressed(KEY_A):
			axis -= 1
		if Input.is_physical_key_pressed(KEY_D):
			axis += 1
		if absf(axis) < 0.01:
			axis = steering
		axis = clampf(axis, -1, 1)
		var braking: float = maxf(brake, control_brake)
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			braking = 1.0
		_drive_player(delta, axis, braking)
		boost_time = maxf(0, boost_time - delta)
		hit_timer = maxf(0, hit_timer - delta)
		shield_time = maxf(0, shield_time - delta)
		rival_contact_timer = maxf(0, rival_contact_timer - delta)
		wall_sound_timer = maxf(0, wall_sound_timer - delta)
		if mode == "arena":
			_update_arena(delta)
			if elapsed >= 90:
				_finish()
		else:
			_drive_opponents(delta)
			_track_events()
			_update_checkpoints()
			if mode == "time_trial":
				records.capture(delta, elapsed, player.position, player.rotation, axis, speed)
				_update_ghost()
			if mode != "training" and distance >= track_length * TOTAL_LAPS and checkpoint_index >= TOTAL_LAPS * 8:
				_finish()
		save_timer += delta
		if save_timer >= 5:
			save_timer = 0
			_save_session()
	for i in range(gems.size()):
		if mode != "arena":
			var key: int = int(distance / track_length) * 24 + i
			gems[i].visible = not collected.has(key)
		if gems[i].visible and not paused and not reduced_motion:
			gems[i].rotation.y += delta * 1.7
	if mode != "arena":
		_sync_item_box_visibility()
		for i in range(item_boxes.size()):
			if item_boxes[i].visible and not paused and not reduced_motion:
				item_boxes[i].rotation.y += delta * 1.35
				item_boxes[i].rotation.x = sin(elapsed * 2.0 + float(i)) * 0.08
	if is_instance_valid(shield_visual):
		shield_visual.visible = shield_time > 0
	if is_instance_valid(pulse_visual):
		if not paused:
			pulse_age += delta
		pulse_visual.visible = pulse_age < 0.65
		pulse_visual.scale = Vector3.ONE * (1.0 + pulse_age * 18.0)
	_update_vehicles(delta)
	_update_camera(delta)
	_update_hud()
	_update_start_lights(delta)
	if engine_playback and not muted and host_sound_enabled and racing and not paused and not finished:
		for i in range(engine_playback.get_frames_available()):
			var phase: float = (float(Time.get_ticks_usec()) / 1000000.0 + float(i) / 22050) * (70 + speed * 5)
			var sample: float = sin(phase * TAU) * 0.025 * effects_volume
			engine_playback.push_frame(Vector2(sample, sample))


func _drive_player(delta: float, axis: float, braking: float) -> void:
	if mode != "arena" and _drive_loop(delta, axis, braking):
		return
	var kart: Dictionary = CATALOG.entry(CATALOG.KARTS, selected_kart)
	var rules: Dictionary = CATALOG.entry(CATALOG.DIFFICULTIES, difficulty)
	var target: float = 20.5 * float(kart.speed) * float(rules.speed)
	var throttle: float = 1.0 if _gas_active() else 0.0
	if mode == "arena":
		target *= 0.68
		if difficulty == "gemuetlich":
			target *= 1.0 - absf(axis) * 0.24
	var boost_active: bool = boost_time > 0
	if boost_active:
		target *= 1.42
	target *= throttle
	target *= 1.0 - braking * 0.94
	# Holding BREMSE while (almost) stopped and without gas reverses slowly, to get unstuck.
	if braking > 0.5 and throttle == 0.0 and speed < 1.0:
		target = -5.0
	if hit_timer > 0:
		target *= 0.45
	var road: Dictionary = {}
	if mode != "arena":
		road = world.sample_road(player.position, previous_road_distance)
		lane = float(road.lateral)
		if absf(lane) > ROAD_WIDTH * 0.48:
			target *= 0.54
		# Beginner assistance nudges the steering at the shoulder; movement stays physical.
		if difficulty == "gemuetlich" and absf(lane) > ROAD_WIDTH * 0.31:
			var correction: float = angle_difference(player_heading, _heading(float(road.distance)))
			axis = clampf(axis - correction * 0.5 - signf(lane) * 0.30, -1.0, 1.0)
	var acceleration: float = (20.0 if braking > 0.1 else 10.0) * float(kart.accel)
	if boost_active and target > speed:
		acceleration *= BOOST_ACCELERATION_MULTIPLIER
	if not airborne or boost_active:
		speed = move_toward(speed, target, delta * acceleration)
	var grip_turn: float = clampf(absf(speed) / 8.0, 0, 1)
	var turn_rate: float = (1.42 + (0.35 if drifting else 0.0)) * float(kart.turn) * grip_turn
	if speed < 0.0:
		turn_rate = -turn_rate
	if airborne:
		turn_rate *= 0.35
	player_heading -= axis * turn_rate * delta
	var forward := Vector3(-sin(player_heading), 0, -cos(player_heading))
	var grip: float = 3.1 if drifting else 9.0
	physical_velocity = physical_velocity.lerp(forward * speed, minf(1, delta * grip))
	player.position += physical_velocity * delta
	if drifting and speed > 6:
		drift_charge = minf(3, drift_charge + delta * absf(axis))
	if mode == "arena":
		player.position.y = 0.035
		var radius: float = Vector2(player.position.x, player.position.z).length()
		if radius > ARENA.RADIUS - 1.0:
			var normal: Vector3 = Vector3(player.position.x, 0, player.position.z).normalized()
			player.position = normal * (ARENA.RADIUS - 1.0) + Vector3.UP * 0.035
			physical_velocity = physical_velocity.bounce(normal) * 0.45
			speed *= 0.6
		for obstacle in arena.obstacles:
			var away: Vector3 = player.position - obstacle
			away.y = 0
			if away.length() < 3.0:
				player.position = obstacle + away.normalized() * 3.0 + Vector3.UP * 0.035
				physical_velocity = physical_velocity.bounce(away.normalized()) * 0.4
				speed *= 0.6
		player.rotation = Vector3(0, player_heading, 0)
		return
	road = world.sample_road(player.position, previous_road_distance)
	lane = float(road.lateral)
	if absf(lane) > WORLD.WALL_LATERAL:
		_collide_with_rail(road)
		road = world.sample_road(player.position, previous_road_distance)
		lane = float(road.lateral)
	_update_wrong_way(road, delta)
	var road_distance: float = float(road.distance)
	var travel: float = fposmod(road_distance - previous_road_distance + track_length * 0.5, track_length) - track_length * 0.5
	if absf(lane) < ROAD_WIDTH * 0.5 + 2.0:
		if not _move_vertically(road, road_distance, delta):
			return
		offroad_seconds = 0
		if absf(travel) <= maxf(3.0, speed * delta * 2.5):
			distance = maxf(0.0, distance + travel)
	else:
		offroad_seconds += delta
		player.position.y -= offroad_seconds * delta * 10.0
		if offroad_seconds > 1.15:
			_reset_kart()
			return
	previous_road_distance = road_distance
	var normal: Vector3 = (road.basis as Basis).y
	var right: Vector3 = forward.cross(normal).normalized()
	var ground_forward: Vector3 = normal.cross(right).normalized()
	player.basis = Basis(right, normal, -ground_forward).orthonormalized()
	var pitch: float = 0.0
	if airborne:
		pitch = clampf(vertical_speed * 0.05, -0.32, 0.32)
	elif world.ramp_height(road_distance) > 0.0:
		pitch = float(world.jump.angle)
	else:
		pitch = world.alternate_route_pitch(road_distance, lane)
	if pitch != 0.0:
		player.basis = player.basis.rotated(right, pitch).orthonormalized()


func _drive_loop(delta: float, axis: float, braking: float) -> bool:
	if not is_instance_valid(world) or world.loop_layout.is_empty():
		loop_state.active = false
		return false
	var layout: Dictionary = world.loop_layout
	if not loop_state.active:
		var road: Dictionary = world.sample_road(player.position, previous_road_distance)
		var entry_offset: float = float(road.distance) - float(layout.start)
		if absf(entry_offset) > 1.0 or absf(float(road.lateral) - float(layout.lane)) > 0.9 or speed < 16.0 or physical_velocity.dot(road.forward) < 8:
			return false
		loop_state.enter(layout, speed, distance - entry_offset)
		airborne = false
		message.text = "Loop! Halte deinen Schwung."
	player.transform = loop_state.advance(world, delta, axis, braking, _gas_active())
	speed = loop_state.speed
	if loop_state.active:
		previous_road_distance = float(layout.start) + loop_state.progress * PHYSICAL_LOOP.ADVANCE
		distance = loop_state.entry_progress + loop_state.progress * PHYSICAL_LOOP.ADVANCE
		lane = float(layout.lane) + loop_state.lateral
		physical_velocity = -player.basis.z * speed
		return true
	var exit_distance: float = float(layout.start) + (0 if loop_state.failed else PHYSICAL_LOOP.ADVANCE)
	distance = loop_state.entry_progress + (0 if loop_state.failed else PHYSICAL_LOOP.ADVANCE)
	previous_road_distance = exit_distance
	player_heading = _heading(exit_distance)
	player.transform = world.reset_transform(exit_distance, float(layout.lane))
	if loop_state.failed:
		speed = 8
		ghost_valid = false
		message.text = "Wieder sicher auf der Straße. Mit mehr Schwung klappt der Loop!"
	else:
		loop_count += 1
		boost_time = maxf(boost_time, 1.5)
		message.text = "Loop geschafft! Sternenturbo!"
	physical_velocity = Vector3(-sin(player_heading), 0, -cos(player_heading)) * speed
	return true


## Ground contact, ramp, take-off, flight, landing and the cloud rescue over the gap.
## Returns false when the kart was rescued (the caller then stops this physics step).
func _move_vertically(road: Dictionary, road_distance: float, delta: float) -> bool:
	var ground: float = float(road.height) + 0.035 + world.ramp_height(road_distance) + world.alternate_route_height(road_distance, lane)
	var jump: Dictionary = world.jump
	if not airborne and not jump.is_empty():
		var leaving_ramp: bool = (
			previous_road_distance >= jump.ramp_start
			and previous_road_distance < jump.take_off
			and road_distance >= jump.take_off
			and road_distance < jump.gap_end
		)
		if leaving_ramp:
			airborne = true
			jump_count += 1
			air_time = 0.0
			vertical_speed = minf(speed * sin(float(jump.angle)), JUMP_MAX_LIFT)
			message.text = "Sprung!"
		elif world.in_gap(road_distance):
			# Rolled or reversed into the gap without take-off: there is no road here.
			airborne = true
			vertical_speed = 0.0
			air_time = 0.0
	if not airborne:
		player.position.y = ground
		return true
	vertical_speed -= JUMP_GRAVITY * delta
	player.position.y += vertical_speed * delta
	air_time += delta
	if world.in_gap(road_distance):
		if player.position.y < float(road.height) - 2.5:
			_rescue_from_gap()
			return false
	elif player.position.y <= ground:
		player.position.y = ground
		airborne = false
		landing_count += 1
		if air_time > 0.35:
			boost_time = maxf(boost_time, 1.2)
			message.text = "Super gelandet! Turbo!"
			_sound_effect("drift")
		air_time = 0.0
		vertical_speed = 0.0
	return true


func _rescue_from_gap() -> void:
	# A cloud carries the kart just past the gap: no repeated falls, no shortcut.
	var target: float = float(world.jump.gap_end) + 3.0
	distance += fposmod(target - previous_road_distance, track_length)
	previous_road_distance = target
	player.transform = world.reset_transform(target)
	player_heading = _heading(target)
	speed = 8.0
	physical_velocity = Vector3(-sin(player_heading), 0, -cos(player_heading)) * speed
	airborne = false
	vertical_speed = 0.0
	air_time = 0.0
	gap_falls += 1
	reset_count += 1
	ghost_valid = false
	message.text = "Eine Wolke trägt dich weiter. Mehr Schwung beim nächsten Sprung!"


func _gas_active() -> bool:
	if auto_gas or gas_held:
		return true
	return Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)


func _collide_with_rail(road: Dictionary) -> void:
	# The rail is a wall: stay on its inner face and slide along it.
	var road_basis: Basis = road.basis
	var side: float = signf(lane)
	player.position -= road_basis.x * (lane - side * WORLD.WALL_LATERAL)
	var into_wall: float = physical_velocity.dot(road_basis.x) * side
	if into_wall <= 0.0:
		return
	wall_contacts += 1
	physical_velocity -= road_basis.x * side * into_wall * 1.3
	speed *= clampf(1.0 - into_wall * 0.03, 0.72, 0.98)
	var along: float = _heading(float(road.distance))
	if absf(angle_difference(player_heading, along)) > PI / 2:
		along += PI
	player_heading = lerp_angle(player_heading, along, minf(1.0, 0.25 + into_wall * 0.04))
	if wall_sound_timer <= 0.0 and into_wall > 2.0:
		wall_sound_timer = 0.4
		_sound_effect("collision")


func _update_wrong_way(road: Dictionary, delta: float) -> void:
	var against: bool = speed > 4.0 and physical_velocity.dot(road.forward) < -2.0
	wrong_way_seconds = wrong_way_seconds + delta if against else 0.0
	var now_wrong: bool = wrong_way_seconds > 1.5
	if now_wrong and not wrong_way:
		message.text = "Falsche Richtung! Dreh um."
	elif wrong_way and not now_wrong:
		message.text = "Richtig unterwegs. Weiter so!"
	wrong_way = now_wrong


func _opponent_place(index: int) -> int:
	if index < 0 or index >= opponent_distances.size():
		return 6
	var progress: float = opponent_distances[index]
	var place: int = 1
	if distance > progress:
		place += 1
	for other in range(opponent_distances.size()):
		if other != index and opponent_distances[other] > progress:
			place += 1
	return clampi(place, 1, 6)


func _sync_rival_item_fx(index: int) -> void:
	if index < 0 or index >= opponent_item_fx.size():
		return
	var fx = opponent_item_fx[index]
	fx.set_item(opponent_items[index] if index < opponent_items.size() else "")
	fx.set_shield(opponent_shield_times[index] if index < opponent_shield_times.size() else 0.0)
	fx.set_pulse_warning(
		opponent_pulse_warning_times[index] if index < opponent_pulse_warning_times.size() else 0.0,
		RIVAL_PULSE_WARNING_SECONDS
	)
	fx.set_stunned(opponent_stuns[index] if index < opponent_stuns.size() else 0.0)


func _update_rival_item_tactics(index: int, local_gap: Vector3, delta: float) -> void:
	if index >= opponent_items.size() or index >= opponent_pulse_warning_times.size():
		return
	opponent_item_cooldowns[index] = maxf(0.0, opponent_item_cooldowns[index] - delta)
	opponent_boost_times[index] = maxf(0.0, opponent_boost_times[index] - delta)
	opponent_shield_times[index] = maxf(0.0, opponent_shield_times[index] - delta)

	# AI pulse is fair and readable: warn first, then resolve against the player's
	# *current* distance/shield. Moving out of range during the warning dodges it.
	var warning_before: float = opponent_pulse_warning_times[index]
	if warning_before > 0.0:
		opponent_pulse_warning_times[index] = maxf(0.0, warning_before - delta)
		if warning_before > 0.0 and opponent_pulse_warning_times[index] <= 0.0:
			if index < opponent_item_fx.size():
				opponent_item_fx[index].fire_pulse()
			if local_gap.length() <= RIVAL_PULSE_RADIUS:
				if shield_time > 0.0:
					message.text = "Sternenschild blockt den Rivalen-Impuls!"
					_sound_effect("item")
				else:
					hit_timer = maxf(hit_timer, 0.38)
					message.text = "Rivalen-Impuls trifft – kurz gebremst!"
					_sound_effect("collision")
		_sync_rival_item_fx(index)
		return

	if opponent_items[index].is_empty() and opponent_item_cooldowns[index] <= 0.0:
		var local_distance: float = fposmod(opponent_distances[index], track_length)
		for box_distance in item_box_distances:
			var offset: float = (
				fposmod(local_distance - box_distance + track_length * 0.5, track_length)
				- track_length * 0.5
			)
			if absf(offset) < 1.4:
				opponent_items[index] = _roll_item_for_place(_opponent_place(index))
				opponent_item_cooldowns[index] = 1.8
				break

	if opponent_items[index].is_empty():
		_sync_rival_item_fx(index)
		return

	var progress_gap: float = distance - opponent_distances[index]
	match opponent_items[index]:
		"boost":
			if progress_gap > 1.0 and progress_gap < 28.0:
				opponent_boost_times[index] = 2.2
				opponent_items[index] = ""
		"pulse":
			if local_gap.length() < RIVAL_PULSE_RADIUS + 1.5:
				opponent_pulse_warning_times[index] = RIVAL_PULSE_WARNING_SECONDS
				opponent_items[index] = ""
				message.text = "Rivale lädt Lichtimpuls – Abstand oder Schild!"
				_sound_effect("item")
		"shield":
			if local_gap.length() < 7.0:
				opponent_shield_times[index] = 5.0
				opponent_items[index] = ""
	_sync_rival_item_fx(index)


func _drive_opponents(delta: float) -> void:
	var rules: Dictionary = CATALOG.entry(CATALOG.DIFFICULTIES, difficulty)
	for i in range(opponents.size()):
		var rival: LumoRaceKart = opponents[i]
		var sampled: Dictionary = world.sample_road(rival.position, fposmod(opponent_distances[i], track_length))
		var target_lane: float = clampf(-2.8 + i * 1.35 + sin(elapsed * 0.35 + i) * 0.3, -3.4, 3.4)
		var local_gap: Vector3 = player.position - rival.position
		_update_rival_item_tactics(i, local_gap, delta)
		if local_gap.length() < 7 and absf(float(sampled.lateral) - lane) < 1.3:
			target_lane = clampf(lane + (1.8 if i % 2 == 0 else -1.8), -3.8, 3.8)
		var aim: Vector3 = world.position_at(float(sampled.distance) + 10.0, target_lane)
		var desired_heading: float = atan2(-(aim.x - rival.position.x), -(aim.z - rival.position.z))
		var angle: float = angle_difference(opponent_headings[i], desired_heading)
		opponent_headings[i] += clampf(angle, -1.55 * delta, 1.55 * delta)
		var target_speed: float = 20.5 * float(rules.speed) * float(rules.rival) * (0.97 + i * 0.014)
		if opponent_boost_times[i] > 0.0:
			target_speed *= 1.32
		target_speed *= clampf(1.0 - absf(angle) * 0.33, 0.58, 1.0)
		opponent_stuns[i] = maxf(0, opponent_stuns[i] - delta)
		_sync_rival_item_fx(i)
		if opponent_stuns[i] > 0:
			target_speed *= 0.3
		var forward := Vector3(-sin(opponent_headings[i]), 0, -cos(opponent_headings[i]))
		if local_gap.length() < 2.6 and forward.dot(local_gap.normalized()) > 0.6:
			target_speed = minf(target_speed, maxf(4, speed - 1))
		rival.position += forward * target_speed * delta
		var next: Dictionary = world.sample_road(rival.position, float(sampled.distance))
		var travel: float = fposmod(float(next.distance) - float(sampled.distance) + track_length * 0.5, track_length) - track_length * 0.5
		opponent_distances[i] += travel
		opponent_lanes[i] = float(next.lateral)
		var rival_lateral: float = float(next.lateral)
		if absf(rival_lateral) > WORLD.WALL_LATERAL and absf(rival_lateral) <= ROAD_WIDTH * 0.5 + 1:
			# Rivals respect the same rail wall as the player.
			var rail_side: float = signf(rival_lateral)
			var overlap: float = rival_lateral - rail_side * WORLD.WALL_LATERAL
			rival.position -= (next.basis as Basis).x * overlap
			opponent_lanes[i] = rail_side * WORLD.WALL_LATERAL
		rival.position.y = (
			float(next.height)
			+ 0.035
			+ world.rival_arc(float(next.distance))
			+ world.alternate_route_height(float(next.distance), rival_lateral)
		)
		if absf(float(next.lateral)) > ROAD_WIDTH * 0.5 + 1:
			rival.transform = world.reset_transform(opponent_distances[i], target_lane)
			opponent_headings[i] = _heading(opponent_distances[i])
		else:
			var normal: Vector3 = (next.basis as Basis).y
			var right: Vector3 = forward.cross(normal).normalized()
			var rival_basis: Basis = Basis(right, normal, -normal.cross(right)).orthonormalized()
			var route_pitch: float = world.alternate_route_pitch(
				float(next.distance), rival_lateral
			)
			if absf(route_pitch) > 0.001:
				rival_basis = rival_basis.rotated(right, route_pitch).orthonormalized()
			rival.basis = rival_basis
		rival.set_motion(
			target_speed,
			clampf(-angle, -1, 1),
			opponent_boost_times[i] > 0.0,
			false
		)


func _reset_kart() -> void:
	loop_state.active = false
	if menu_active or not is_instance_valid(player) or finished:
		return
	if mode == "arena":
		player.position = Vector3(0, 0.035, 28)
		player_heading = 0
	else:
		var checkpoint_floor: float = float(checkpoint_index) * track_length / 8.0
		var checkpoint_ceiling: float = (checkpoint_index + 1) * track_length / 8.0 - 1.0
		var candidate: float = maxf(checkpoint_floor, distance - 6.0)
		distance = world.safe_respawn_distance(candidate, checkpoint_floor, checkpoint_ceiling)
		lane = 0
		player.transform = world.reset_transform(distance)
		player_heading = _heading(distance)
		previous_road_distance = fposmod(distance, track_length)
	speed = 0
	physical_velocity = Vector3.ZERO
	offroad_seconds = 0
	airborne = false
	vertical_speed = 0.0
	air_time = 0.0
	reset_count += 1
	ghost_valid = false
	message.text = "Wieder sicher auf der Strecke. Du schaffst das!"


func _update_ghost() -> void:
	if not is_instance_valid(ghost):
		return
	var frame: Dictionary = records.sample(elapsed)
	ghost.visible = not frame.is_empty()
	if not frame.is_empty():
		ghost.position = frame.position
		ghost.rotation = frame.rotation
		ghost.set_motion(float(frame.speed), float(frame.steer), false, false)


func _update_hud() -> void:
	var place: int = _place()
	if mode == "arena":
		hud.text = "KRISTALL-ARENA    %02d:%02d    ◆ %d    PLATZ %d / 6" % [int(maxf(0, 90 - elapsed)) / 60, int(maxf(0, 90 - elapsed)) % 60, arena_scores, place]
	elif mode == "training":
		hud.text = "FREIES TRAINING    %d km/h    ★ %d    PAUSE → BEENDEN" % [int(speed * 3.6), collected.size()]
	elif mode == "time_trial":
		hud.text = "ZEITFAHREN    RUNDE %d / %d    %.2f s    %d km/h" % [mini(TOTAL_LAPS, int(distance / track_length) + 1), TOTAL_LAPS, elapsed, int(speed * 3.6)]
	else:
		hud.text = "RUNDE %d / %d    PLATZ %d / 6    %d km/h    ★ %d" % [mini(TOTAL_LAPS, int(distance / track_length) + 1), TOTAL_LAPS, place, int(speed * 3.6), collected.size()]
	var enabled: bool = racing and not paused and not finished
	boost_button.text = "SPEED\n◆ %d" % boosts
	boost_button.disabled = boosts == 0 or not enabled
	var drift_state: String = "HALTEN"
	if drift_charge >= DRIFT_TIERS[1]:
		drift_state = "ORANGE!"
	elif drift_charge >= DRIFT_TIERS[0]:
		drift_state = "BLAU!"
	drift_button.text = "DRIFT\n" + drift_state
	drift_button.disabled = not enabled
	item_button.text = {"": "ITEM\n◇", "shield": "SCHILD\n◎", "pulse": "IMPULS\n✧", "boost": "WIND\n➜"}.get(item, "ITEM")
	item_button.disabled = item.is_empty() or not enabled
	joystick.set_enabled(enabled)
	gas_button.disabled = not enabled
	brake_button.disabled = not enabled
	gas_button.visible = not auto_gas


func _place() -> int:
	var place: int = 1
	if mode == "arena":
		for score in opponent_scores:
			if score > arena_scores:
				place += 1
	else:
		for i in range(opponents.size()):
			if opponent_distances[i] > distance:
				place += 1
	return place


func _track_events() -> void:
	for i in range(opponents.size()):
		var away: Vector3 = player.position - opponents[i].position
		away.y = 0
		if rival_contact_timer <= 0 and away.length() < 1.45:
			rival_contact_timer = 0.6
			_sound_effect("collision")
			if shield_time <= 0:
				hit_timer = maxf(hit_timer, 0.25)
				player.position += away.normalized() * 0.18
	var lap: int = int(distance / track_length)
	for i in range(gems.size()):
		var key: int = lap * 24 + i
		if not collected.has(key) and player.position.distance_to(gems[i].position) < 1.75:
			collected[key] = true
			if collected.size() % 3 == 0:
				boosts = mini(3, boosts + 1)
			if collected.size() % 2 == 0 and item.is_empty():
				item = ["shield", "pulse", "boost"][rng.randi_range(0, 2)]
	for i in range(item_boxes.size()):
		var item_key: int = lap * item_boxes.size() + i
		if (
			not item_box_collected.has(item_key)
			and player.position.distance_to(item_boxes[i].position) < 2.0
		):
			item_box_collected[item_key] = true
			if item.is_empty():
				item = _roll_item_for_place(_place())
				message.text = "Überraschungs-Item!"
				_sound_effect("item")
	for fraction in [0.12, 0.42, 0.74]:
		if absf(fposmod(distance, track_length) - fraction * track_length - 1.1) < 1.2 and absf(lane) < 2.1:
			boost_time = maxf(boost_time, 1.0)


func _use_item() -> void:
	if item.is_empty() or not racing or paused or finished:
		return
	_sound_effect("item")
	match item:
		"boost":
			boost_time = maxf(boost_time, 3.0)
			message.text = "Rückenwind!"
		"shield":
			shield_time = 6.0
			message.text = "Sternenschild: sechs Sekunden geschützt."
		"pulse":
			pulse_age = 0
			pulse_visual.position = player.position + Vector3.UP * 0.15
			for i in range(opponents.size()):
				if (
					player.position.distance_to(opponents[i].position) < 13
					and opponent_shield_times[i] <= 0.0
				):
					opponent_stuns[i] = 2.3
			message.text = "Lichtimpuls: Rivalen in deiner Nähe werden kurz langsamer."
	item = ""


func _update_arena(delta: float) -> void:
	for i in range(gems.size()):
		arena_pickup_timers[i] = maxf(0, arena_pickup_timers[i] - delta)
		gems[i].visible = arena_pickup_timers[i] <= 0
		if gems[i].visible and player.position.distance_to(gems[i].position) < 1.85:
			arena_scores += 1
			arena_pickup_timers[i] = 8.0
			if arena_scores % 3 == 0:
				boosts = mini(3, boosts + 1)
			if arena_scores % 2 == 0 and item.is_empty():
				item = ["shield", "pulse", "boost"][rng.randi_range(0, 2)]
	var rules: Dictionary = CATALOG.entry(CATALOG.DIFFICULTIES, difficulty)
	for i in range(opponents.size()):
		var rival: LumoRaceKart = opponents[i]
		var target_index: int = opponent_targets[i]
		if arena_pickup_timers[target_index] > 0:
			var closest: float = INF
			for candidate in range(gems.size()):
				var d: float = rival.position.distance_squared_to(gems[candidate].position)
				if arena_pickup_timers[candidate] <= 0 and d < closest:
					closest = d
					target_index = candidate
			opponent_targets[i] = target_index
		var target_position: Vector3 = gems[target_index].position
		var delta_position: Vector3 = target_position - rival.position
		var desired: float = atan2(-delta_position.x, -delta_position.z)
		opponent_headings[i] = rotate_toward(opponent_headings[i], desired, delta * 1.9)
		opponent_stuns[i] = maxf(0, opponent_stuns[i] - delta)
		var rival_speed: float = (9.5 + i * 0.3) * float(rules.rival) * (0.3 if opponent_stuns[i] > 0 else 1.0)
		var forward := Vector3(-sin(opponent_headings[i]), 0, -cos(opponent_headings[i]))
		rival.position += forward * rival_speed * delta
		rival.position.y = 0.035
		for obstacle in arena.obstacles:
			var away: Vector3 = rival.position - obstacle
			away.y = 0
			if away.length() < 3.0:
				rival.position = obstacle + away.normalized() * 3.05 + Vector3.UP * 0.035
				opponent_headings[i] += delta * 2.5
		if Vector2(rival.position.x, rival.position.z).length() > ARENA.RADIUS - 1:
			rival.position = Vector3(rival.position.x, 0, rival.position.z).normalized() * (ARENA.RADIUS - 1) + Vector3.UP * 0.035
		rival.rotation.y = opponent_headings[i]
		rival.set_motion(rival_speed, 0, false, false)
		if arena_pickup_timers[target_index] <= 0 and rival.position.distance_to(target_position) < 1.9:
			opponent_scores[i] += 1
			arena_pickup_timers[target_index] = 8.0
		var away_from_player: Vector3 = player.position - rival.position
		away_from_player.y = 0
		if away_from_player.length() < 1.5 and rival_contact_timer <= 0:
			rival_contact_timer = 0.6
			_sound_effect("collision")
			if shield_time <= 0:
				hit_timer = 0.4
				player.position += away_from_player.normalized() * 0.25


func _update_checkpoints() -> void:
	if absf(lane) > ROAD_WIDTH * 0.5 + 0.8:
		return
	var spacing: float = track_length / 8.0
	var target: float = (checkpoint_index + 1) * spacing
	# Ordered gates only advance when crossed locally, preventing shortcut laps.
	if distance >= target and distance < target + maxf(4.0, speed * 0.3):
		checkpoint_index += 1
		if checkpoint_index % 8 == 0:
			lap_times.append(elapsed - lap_started_at)
			lap_started_at = elapsed
			message.text = "Runde geschafft! Weiter so." if mode == "training" else "Letzte Runde!"


func _update_vehicles(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var enabled: bool = racing and not paused and not finished
	player.set_motion(speed if enabled else 0, steering, boost_time > 0 and enabled, drifting and enabled)
	if not enabled:
		for kart in opponents:
			kart.set_motion(0, 0, false, false)


func _update_camera(delta: float, snap: bool = false) -> void:
	if not is_instance_valid(camera):
		return
	# Heinz' racing references keep the kart large in frame and put the horizon/
	# setpiece directly ahead. Speed stretches the view; boost never teleports it.
	if loop_state.active:
		var origin: Vector3 = world.position_at(float(world.loop_layout.start), float(world.loop_layout.lane))
		var entry_basis: Basis = world.frame(float(world.loop_layout.start))
		var desired_loop: Vector3 = origin + entry_basis.x * 12 + entry_basis.z * 15 + Vector3.UP * 11
		camera.position = camera.position.lerp(desired_loop, minf(1, delta * 4))
		camera.look_at(player.position + Vector3.UP * 0.6)
		return
	var ahead := Vector3(-sin(player_heading), 0, -cos(player_heading))
	var right := Vector3(-ahead.z, 0, ahead.x)
	var speed_ratio: float = clampf(absf(speed) / 25.0, 0.0, 1.0)
	var chase_distance: float = VISUAL_GRADE.camera_distance(speed_ratio)
	var air_lift: float = 0.28 if airborne and not reduced_motion else 0.0
	var lateral_lead: float = 0.0 if reduced_motion else clampf(steering, -1.0, 1.0) * 0.24
	var desired: Vector3 = (
		player.position
		- ahead * chase_distance
		+ right * lateral_lead
		+ Vector3.UP * (VISUAL_GRADE.CAMERA_HEIGHT + air_lift)
	)
	var target: Vector3 = (
		player.position
		+ ahead * (VISUAL_GRADE.CAMERA_LOOK_AHEAD + speed_ratio * 1.8)
		+ Vector3.UP * VISUAL_GRADE.CAMERA_TARGET_HEIGHT
	)
	camera.position = (
		desired
		if snap
		else camera.position.lerp(desired, minf(1.0, delta * VISUAL_GRADE.CAMERA_LERP))
	)
	camera.look_at(target)
	if not reduced_motion:
		var roll: float = (
			-clampf(steering, -1.0, 1.0)
			* VISUAL_GRADE.CAMERA_ROLL_MAX
			* (0.35 + speed_ratio * 0.65)
		)
		camera.rotate_object_local(Vector3(0, 0, 1), roll)
	var baseline_fov: float = VISUAL_GRADE.camera_fov(
		speed_ratio, boost_time > 0.0 and not paused, reduced_motion
	)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / maxf(1.0, viewport_size.y)
	var target_fov: float = _resize_compensated_fov(baseline_fov, aspect)
	camera.fov = (
		target_fov
		if snap
		else lerpf(camera.fov, target_fov, minf(1.0, delta * VISUAL_GRADE.FOV_LERP))
	)
	if is_instance_valid(speed_fx):
		speed_fx.set_motion(speed_ratio, boost_time > 0.0 and not paused, reduced_motion)


static func _resize_compensated_fov(vertical_fov: float, aspect: float) -> float:
	var reference_aspect: float = 16.0 / 9.0
	var horizontal_span: float = tan(deg_to_rad(vertical_fov) * 0.5) * reference_aspect
	# Wide cover displays gain horizontal visibility instead of cropping the
	# driver's kart by shrinking the vertical field of view below its baseline.
	var compensated: float = rad_to_deg(2.0 * atan(horizontal_span / maxf(aspect, 0.1)))
	return clampf(maxf(vertical_fov, compensated), 40.0, 110.0)


func _boost() -> void:
	if boosts > 0 and racing and not paused and not finished:
		boosts -= 1
		boost_time = 3.2
		message.text = "Lumo-Boost!"
		_sound_effect("boost")


func _release_drift() -> void:
	drifting = false
	if racing and not paused and not finished and drift_charge >= DRIFT_TIERS[0]:
		var tier: int = 1 if drift_charge >= DRIFT_TIERS[1] else 0
		drift_tier_count[tier] += 1
		boost_time = maxf(boost_time, DRIFT_BOOST_SECONDS[tier])
		message.text = "Oranger Drift-Turbo!" if tier == 1 else "Blauer Drift-Turbo!"
		_sound_effect("drift")
	drift_charge = 0


func _unhandled_input(event: InputEvent) -> void:
	# Ein Tippen oder Klick überspringt Streckenvorschau bzw. Zielfahrt.
	var tap: bool = (
		(event is InputEventScreenTouch and event.pressed)
		or (event is InputEventMouseButton and event.pressed)
	)
	if not tap or paused:
		return
	if preview_left > 0.0:
		_end_preview()
		get_viewport().set_input_as_handled()
	elif finished and finish_cine_left > 0.0:
		_skip_finish_cine()
		get_viewport().set_input_as_handled()


func _track_entry(id: String) -> Dictionary:
	for track in CATALOG.TRACKS:
		if str(track.id) == id:
			return track
	return {}


func _update_preview(delta: float) -> void:
	preview_left = maxf(0.0, preview_left - delta)
	var t: float = 1.0 - preview_left / maxf(preview_total, 0.001)
	_show_preview_card(t)
	# Die Titelkarte ersetzt während der Kamerafahrt die Hinweiszeile.
	message.visible = false
	# Flug über den Großteil der Runde bis kurz hinter die Startlinie.
	var fly: float = clampf(t / (1.0 - PREVIEW_BLEND_SECONDS / PREVIEW_SECONDS), 0.0, 1.0)
	var eased: float = fly * fly * (3.0 - 2.0 * fly)
	var along: float = track_length * lerpf(0.18, 0.97, eased)
	var basis: Basis = world.frame(along)
	var swing: float = sin(eased * PI * 2.0) * 7.0
	var from: Vector3 = world.position_at(along) + basis.x * swing + basis.z * 9.0 + Vector3.UP * (6.5 + sin(eased * PI) * 4.0)
	var look: Vector3 = world.position_at(along + 16.0) + Vector3.UP * 1.2
	var flight := Transform3D(Basis(), from).looking_at(look, Vector3.UP)
	# Letzte gut eine Sekunde: weich in die Verfolgerkamera hinter Lumo gleiten.
	var blend: float = clampf((t - (1.0 - PREVIEW_BLEND_SECONDS / PREVIEW_SECONDS)) / (PREVIEW_BLEND_SECONDS / PREVIEW_SECONDS), 0.0, 1.0)
	if blend > 0.0:
		_update_camera(1.0, true)
		var chase: Transform3D = camera.global_transform
		camera.global_transform = flight.interpolate_with(chase, blend * blend * (3.0 - 2.0 * blend))
	else:
		camera.global_transform = flight
	_roll_grid(1.0 - preview_left / GRID_ROLL_SECONDS)
	_update_vehicles(0)
	if preview_left <= 0.0:
		_end_preview()


func _end_preview(snap_all: bool = true) -> void:
	preview_left = 0.0
	message.visible = true
	if is_instance_valid(preview_card):
		preview_card.hide()
	if snap_all:
		_roll_grid(1.0)
	else:
		# Nur Karts, die noch in ihrer Einroll-Lage stehen, auf den Startplatz.
		var karts: Array = [player] + opponents
		for i in range(mini(karts.size(), mini(grid_to.size(), grid_last.size()))):
			if is_instance_valid(karts[i]) and karts[i].transform.is_equal_approx(grid_last[i]):
				karts[i].transform = grid_to[i]
				karts[i].set_motion(0.0, 0.0, false, false)
	grid_from.clear()
	grid_last.clear()
	_update_camera(1.0, true)


## Merkt sich die echten Startplätze und setzt die Karts dahinter, sofern eine
## Vorschau läuft; sonst stehen sie sofort richtig.
func _prepare_grid_roll() -> void:
	grid_from.clear()
	grid_to.clear()
	grid_last.clear()
	if mode == "arena" or not is_instance_valid(player):
		return
	var karts: Array = [player] + opponents
	for kart in karts:
		grid_to.append(kart.transform)
	# Nur während einer laufenden Vorschau rollen; Fortsetzen und Grafikwechsel
	# behalten die gespeicherten Positionen.
	if preview_left <= 0.0:
		return
	var lanes: Array = [lane]
	lanes.append_array(opponent_lanes)
	var distances: Array = [distance]
	distances.append_array(opponent_distances)
	for i in range(karts.size()):
		var back: Transform3D = world.reset_transform(float(distances[i]) - GRID_ROLL_DISTANCE, float(lanes[i]))
		back.origin.y = grid_to[i].origin.y
		grid_from.append(back)
	_roll_grid(0.0)


## 0 = alle Karts hinter der Linie, 1 = auf ihren Startplätzen (exakt).
func _roll_grid(progress: float) -> void:
	if grid_from.is_empty() or grid_to.is_empty():
		return
	var p: float = clampf(progress, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - p, 3.0)
	var karts: Array = [player] + opponents
	grid_last.clear()
	for i in range(mini(karts.size(), grid_to.size())):
		if not is_instance_valid(karts[i]):
			grid_last.append(Transform3D())
			continue
		karts[i].transform = grid_to[i] if p >= 1.0 else grid_from[i].interpolate_with(grid_to[i], eased)
		grid_last.append(karts[i].transform)
		# Räder drehen sich passend zum Ausrollen; danach stehen sie still.
		var rolling: float = 0.0 if p >= 1.0 else 3.0 * GRID_ROLL_DISTANCE / GRID_ROLL_SECONDS * pow(1.0 - p, 2.0)
		karts[i].set_motion(rolling, 0.0, false, false)
	if p >= 1.0:
		player_heading = _heading(distance)


func _build_start_lights() -> void:
	start_lights = PanelContainer.new()
	start_lights.name = "StartLights"
	start_lights.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_lights.add_theme_stylebox_override("panel", _style(Color(0.02, 0.05, 0.11, 0.88), 30))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	start_lights.add_child(row)
	for i in range(3):
		var lamp := Panel.new()
		lamp.name = "StartLamp%d" % (i + 1)
		lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lamp.custom_minimum_size = Vector2(46, 46)
		row.add_child(lamp)
		start_lamps.append(lamp)
	countdown_label = Label.new()
	countdown_label.name = "CountdownNumber"
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_label.add_theme_font_override("font", UI.HEADING)
	countdown_label.add_theme_color_override("font_color", Color("f7fbff"))
	countdown_label.add_theme_color_override("font_outline_color", Color("0a2a55"))
	countdown_label.add_theme_constant_override("outline_size", 8)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(countdown_label)
	start_lights.hide()
	safe_ui.add_child(start_lights)
	preview_card = PanelContainer.new()
	preview_card.name = "PreviewTitleCard"
	preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_card.add_theme_stylebox_override("panel", _style(Color(0.02, 0.06, 0.13, 0.82), 26))
	var card := VBoxContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_constant_override("separation", 2)
	preview_card.add_child(card)
	preview_name = Label.new()
	preview_name.add_theme_font_override("font", UI.HEADING)
	preview_name.add_theme_color_override("font_color", Color("f7fbff"))
	preview_tag = Label.new()
	preview_tag.add_theme_font_override("font", UI.BODY)
	preview_tag.add_theme_color_override("font_color", Color("8fe8ff"))
	preview_skip = Label.new()
	preview_skip.add_theme_font_override("font", UI.BODY)
	preview_skip.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98, 0.8))
	preview_skip.text = "Tippen zum Überspringen"
	for label in [preview_name, preview_tag, preview_skip]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(label)
	preview_card.hide()
	safe_ui.add_child(preview_card)


## Titelkarte blendet zu Beginn der Kamerafahrt ein und vor der Startaufstellung aus.
func _show_preview_card(t: float) -> void:
	if not is_instance_valid(preview_card):
		return
	var entry := _track_entry(track_id)
	preview_name.text = str(entry.get("name", world.track_name if is_instance_valid(world) else ""))
	preview_tag.text = str(entry.get("tag", ""))
	var area: Vector2 = safe_ui.size
	var unit: float = minf(area.y, area.x * 0.56)
	preview_name.add_theme_font_size_override("font_size", int(clampf(unit * 0.085, 26.0, 72.0)))
	preview_tag.add_theme_font_size_override("font_size", int(clampf(unit * 0.034, 14.0, 30.0)))
	preview_skip.add_theme_font_size_override("font_size", int(clampf(unit * 0.026, 12.0, 24.0)))
	var fade_in: float = clampf(t / 0.08, 0.0, 1.0)
	var fade_out: float = clampf((0.72 - t) / 0.08, 0.0, 1.0)
	preview_card.modulate.a = minf(fade_in, fade_out)
	preview_card.visible = preview_card.modulate.a > 0.01
	preview_card.reset_size()
	preview_card.position = Vector2((area.x - preview_card.size.x) * 0.5, area.y * 0.16)


func _lamp_style(color: Color, lit: bool, diameter: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color if lit else Color(0.10, 0.13, 0.20, 0.95)
	style.set_corner_radius_all(int(diameter * 0.5))
	style.set_border_width_all(3)
	style.border_color = color.lightened(0.35) if lit else Color(0.25, 0.32, 0.44, 0.9)
	if lit:
		style.shadow_color = Color(color, 0.65)
		style.shadow_size = int(diameter * 0.35)
	return style


## Rot leuchten nacheinander auf (3, 2, 1), bei LOS alle grün – zeitgleich mit
## den Countdown-Tönen.
func _update_start_lights(delta: float) -> void:
	if not is_instance_valid(start_lights):
		return
	if not paused:
		start_green_left = maxf(0.0, start_green_left - delta)
	var counting: bool = countdown > 0.0 and preview_left <= 0.0
	var visible_now: bool = (
		not paused and not menu_active and not finished and mode != "arena" and (counting or start_green_left > 0.0)
	)
	start_lights.visible = visible_now
	if not visible_now:
		return
	var area: Vector2 = safe_ui.size
	var diameter: float = clampf(minf(area.x, area.y) * 0.085, 30.0, 70.0)
	var red_lit: int = 3 if countdown <= 0.0 else clampi(4 - ceili(countdown), 0, 3)
	countdown_label.text = "LOS!" if countdown <= 0.0 else str(ceili(countdown))
	countdown_label.add_theme_font_size_override("font_size", int(diameter * 0.95))
	countdown_label.custom_minimum_size = Vector2(diameter * (2.3 if countdown <= 0.0 else 1.1), diameter)
	for i in range(start_lamps.size()):
		start_lamps[i].custom_minimum_size = Vector2(diameter, diameter)
		var green: bool = countdown <= 0.0
		var color: Color = Color("44f08a") if green else Color("ff4b55")
		start_lamps[i].add_theme_stylebox_override("panel", _lamp_style(color, green or i < red_lit, diameter))
	start_lights.reset_size()
	start_lights.position = Vector2((area.x - start_lights.size.x) * 0.5, area.y * 0.2)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if preview_left > 0.0 and event.pressed and not paused:
			_end_preview()
			return
		if finished and finish_cine_left > 0.0 and event.pressed:
			_skip_finish_cine()
			return
		if menu_active:
			return
		if event.keycode == KEY_SHIFT:
			if not event.pressed:
				_release_drift()
			else:
				drifting = racing and not paused
		elif event.pressed and event.keycode == KEY_SPACE:
			_boost()
		elif event.pressed and event.keycode == KEY_E:
			_use_item()
		elif event.pressed and event.keycode == KEY_R:
			_reset_kart()
		elif event.pressed and event.keycode == KEY_ESCAPE:
			if finished:
				_return_to_world()
			elif paused:
				_resume()
			else:
				_pause()


func _clear_column(column: VBoxContainer) -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()


func _pause() -> void:
	if finished or paused or menu_active:
		return
	if preview_left > 0.0:
		# Pause während der Vorschau: Karts sofort auf ihre Plätze, nichts halb Gerolltes speichern.
		_end_preview()
	paused = true
	_update_audio()
	if is_instance_valid(kart_audio):
		kart_audio.set_paused(true)
	steering = 0
	lateral_velocity = 0
	brake = 0
	drifting = false
	drift_charge = 0
	_save_session()
	_clear_column(modal_column)
	modal_scroll.scroll_vertical = 0
	pause_navigation.show()
	modal_column.add_child(_label("Eine kleine Pause", 28))
	modal_column.add_child(_label("Dein Rennen wartet. Du kannst später hier weiterfahren.", 19))
	modal_column.add_child(_button("Weiterfahren", _resume))
	if mode == "training":
		modal_column.add_child(_button("Training abschließen", _finish))
	var motion := _button(
		"Ruhige Bewegung: an (App)" if host_reduce_motion else ("Ruhige Bewegung: an" if reduced_motion else "Ruhige Bewegung: aus"), func(): pass
	)
	motion.pressed.connect(
		func():
			preferred_reduced_motion = not preferred_reduced_motion
			reduced_motion = preferred_reduced_motion or host_reduce_motion
			player.reduced_motion = reduced_motion
			motion.text = "Ruhige Bewegung: an" if reduced_motion else "Ruhige Bewegung: aus"
			_save_preferences()
	)
	motion.disabled = host_reduce_motion
	modal_column.add_child(motion)
	var sound := _button("Ton: aus (App)" if not host_sound_enabled else ("Ton: aus" if muted else "Ton: an"), func(): pass)
	sound.pressed.connect(
		func():
			muted = not muted
			sound.text = "Ton: aus" if muted else "Ton: an"
			_save_preferences()
	)
	sound.disabled = not host_sound_enabled
	modal_column.add_child(sound)
	var detail := _button("Grafik: " + {"high": "Hoch", "medium": "Ausgewogen", "low": "Leicht"}.get(graphics_profile, "Hoch"), func(): pass)
	detail.pressed.connect(
		func():
			graphics_profile = {"high": "medium", "medium": "low", "low": "high"}.get(graphics_profile, "high")
			lightweight = graphics_profile == "low"
			_save_preferences()
			_save_session()
			_rebuild_graphics()
	)
	modal_column.add_child(detail)
	var challenge := _button(
		"Tempo: gemütlich" if difficulty == "gemuetlich" else "Tempo: flott", func(): pass
	)
	challenge.pressed.connect(
		func():
			difficulty = "flott" if difficulty == "gemuetlich" else "gemuetlich"
			challenge.text = "Tempo: gemütlich" if difficulty == "gemuetlich" else "Tempo: flott"
			_save_preferences()
	)
	modal_column.add_child(challenge)
	var gas_mode := _button("Gas: automatisch" if auto_gas else "Gas: GAS-Taste halten", func(): pass)
	gas_mode.name = "GasModeToggle"
	gas_mode.pressed.connect(
		func():
			auto_gas = not auto_gas
			gas_held = false
			gas_mode.text = "Gas: automatisch" if auto_gas else "Gas: GAS-Taste halten"
			_save_preferences()
	)
	modal_column.add_child(gas_mode)
	modal_column.add_child(_volume_row("Musik", music_volume, func(value: float):
		music_volume = value
		_apply_volumes()))
	modal_column.add_child(_volume_row("Effekte", effects_volume, func(value: float):
		effects_volume = value
		_apply_volumes()))
	modal_column.add_child(_button("Neue Fahrt auswählen", _leave_race_for_menu))
	modal_column.add_child(_button("Rennen abbrechen", _abandon, Color("3a4577")))
	modal.show()
	_apply_responsive_layout()
	call_deferred("_apply_responsive_layout")


func _resume() -> void:
	if menu_active:
		return
	paused = false
	_update_audio()
	if is_instance_valid(kart_audio):
		kart_audio.set_paused(false)
	modal.hide()


func _return_to_world() -> void:
	_return_to_app("games")


func _host_return_payload() -> Dictionary:
	if finished:
		return result_payload.duplicate(true)
	return {
		"game": "kart", "status": "abandoned" if abandoned else "paused",
		"resultId": result_id, "stars": 0, "solved": 0
	}


func _return_to_app(destination: String) -> void:
	_save_session()
	if finished:
		HostBridge.reward(result_payload)
		if mode != "cup" and HostBridge.reward_is_recoverable(result_id):
			DirAccess.remove_absolute(SESSION)
	var payload: Dictionary = _host_return_payload()
	if HostBridge.is_embedded():
		if not HostBridge.return_to_app(destination, payload):
			_show_host_save_failure()
		elif abandoned:
			DirAccess.remove_absolute(SESSION)
		return
	if abandoned:
		DirAccess.remove_absolute(SESSION)
	SceneRouter.goto("learn" if destination == "learn" else "games")


func _show_host_save_failure() -> void:
	message.text = HostBridge.SAVE_FAILURE
	if not modal_column.has_node("HostSaveFailure"):
		var label := _label(HostBridge.SAVE_FAILURE, 20)
		label.name = "HostSaveFailure"
		label.add_theme_color_override("font_color", Color("3a4577"))
		modal_column.add_child(label)
		modal_column.move_child(label, 1)


func _abandon() -> void:
	_save_session()
	abandoned = true
	_return_to_app("games")


## [param cinematic] false: Ergebnis sofort zeigen (z. B. gespeichertes Rennen
## nach dem Ziel wieder geöffnet), ohne Zielfahrt.
func _finish(cinematic: bool = true) -> void:
	if finished or menu_active:
		return
	completed_race = true
	racing = false
	_update_audio()
	paused = false
	finished = true
	if is_instance_valid(kart_audio):
		kart_audio.set_paused(false)
	_sound_effect("finish")
	var place: int = _place()
	var earned: int = 3
	if mode == "training":
		earned = 1 if elapsed >= 45 else 0
	if earned > 0:
		ProgressStore.add_stars(earned)
	result_payload = {
		"game": "kart", "sessionId": str(SceneRouter.launch_options.get("sessionId", "")),
		# The Flutter host requires an integer "solved"; Kart has no learning tasks.
		"resultId": result_id, "status": "completed", "stars": earned,
		"solved": 0, "elapsedSeconds": snappedf(elapsed, 0.1), "place": place,
		"mode": mode, "track": track_id, "driver": selected_driver, "kart": selected_kart,
		"checkpoints": checkpoint_index, "resets": reset_count
	}
	if mode == "arena":
		result_payload["crystals"] = arena_scores
	if mode == "time_trial":
		best_record = records.finish(elapsed, ghost_valid)
	if mode == "cup":
		var ranking: Array[Dictionary] = [{"id": 0, "distance": distance}]
		for i in range(opponents.size()):
			ranking.append({"id": i + 1, "distance": opponent_distances[i]})
		ranking.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.distance) > float(b.distance))
		for rank in range(ranking.size()):
			cup_points[int(ranking[rank].id)] += CATALOG.CUP_POINTS[rank]
		cup_results.append({"track": track_id, "place": place, "time": elapsed, "result_id": result_id})
		pending_cup_next = cup_index < CATALOG.TRACKS.size() - 1
		result_payload["cupRound"] = cup_index + 1
		result_payload["cupPoints"] = cup_points[0]
	if lap_times.is_empty() or elapsed - lap_started_at > 1.0:
		lap_times.append(elapsed - lap_started_at)
	result_payload["bestLapSeconds"] = snappedf(_best_lap(), 0.001)
	result_payload["starTokens"] = collected.size()
	# Belohnung und Ergebnis-ID gehen sofort an der Linie raus; die Zielfahrt ist nur Bild.
	var reward_accepted: bool = HostBridge.reward(result_payload)
	_save_session()
	var save_failed: bool = HostBridge.is_embedded() and not reward_accepted
	if cinematic and not save_failed:
		_start_finish_cine(place)
	else:
		# Speicherproblem oder Wiederaufnahme: Ergebnis sofort, nichts verdecken.
		if is_instance_valid(player) and player.has_method("celebrate"):
			player.celebrate(place if _ranked() else 1)
		_show_result()
	if save_failed:
		_show_host_save_failure()
	print("[Kart] completed: mode=%s track=%s stars=%d place=%d" % [mode, track_id, earned, place])


func _show_result() -> void:
	_clear_column(modal_column)
	modal_scroll.scroll_vertical = 0
	pause_navigation.hide()
	var title: String = "Ziel erreicht!"
	if mode == "training":
		title = "Gut trainiert!"
	elif mode == "arena":
		title = "Kristall-Arena geschafft!"
	elif mode == "cup":
		title = (
			"Rennen %d von %d geschafft!" % [cup_index + 1, CATALOG.TRACKS.size()]
			if pending_cup_next
			else "Dein Sternen-Cup ist geschafft!"
		)
	var ranked: bool = _ranked()
	var place_now: int = int(result_payload.get("place", 1))
	if ranked and not (mode == "cup" and not pending_cup_next):
		title = _place_title(place_now)
	var title_label: Label = _label(title, 34 if ranked else 30)
	title_label.name = "ResultTitle"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ranked:
		title_label.add_theme_color_override("font_color", _place_color(place_now))
	modal_column.add_child(title_label)
	if ranked:
		var cheer: Label = _label(_place_cheer(place_now), 21)
		cheer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		modal_column.add_child(cheer)
	var stats: Label = _label(_result_stats_text(), 21)
	stats.name = "ResultStats"
	modal_column.add_child(stats)
	var details: String = ""
	if ranked:
		details = "Platz %d von 6" % place_now
	if mode == "arena":
		details += ("\n" if details != "" else "") + "%d Kristalle gesammelt" % arena_scores
	if details != "":
		modal_column.add_child(_label(details, 21))
	if mode == "time_trial":
		var record_text: String = "Deine neue Bestzeit – Geisterfahrt gespeichert!" if best_record else ("Bestzeit: %.2f Sekunden" % records.previous_best if records.previous_best > 0 else "Erste Trainingszeit. Ohne Zurücksetzen wird deine Geisterfahrt gespeichert.")
		modal_column.add_child(_label(record_text, 20))
	if mode == "cup":
		var names: Array[String] = [str(CATALOG.entry(CATALOG.DRIVERS, selected_driver).name), "Milo", "Nova", "Borin", "Yuki", "Fynn"]
		var standings: Array[Dictionary] = []
		for i in range(cup_points.size()):
			standings.append({"name": names[i], "points": cup_points[i], "id": i})
		standings.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.points) > int(b.points))
		var lines: String = "GESAMTWERTUNG\n"
		for i in range(standings.size()):
			lines += "%d. %s    %d Punkte%s\n" % [i + 1, standings[i].name, int(standings[i].points), "  ← DU" if int(standings[i].id) == 0 else ""]
		modal_column.add_child(_label(lines.strip_edges(), 19))
		if pending_cup_next:
			modal_column.add_child(_button("Weiter: " + str(CATALOG.TRACKS[cup_index + 1].name), _next_cup_race))
	if not pending_cup_next:
		modal_column.add_child(_button("Noch einmal fahren", _restart_setup))
	modal_column.add_child(_button("Neue Fahrt auswählen", _leave_race_for_menu))
	modal_column.add_child(_button("Zur Spieleauswahl", _return_to_world))
	modal_column.add_child(_button("Zum Lernen", func(): _return_to_app("learn")))
	modal.show()
	_apply_responsive_layout()
	call_deferred("_apply_responsive_layout")


func _ranked() -> bool:
	return mode not in ["training", "time_trial", "arena"]


func _best_lap() -> float:
	var best: float = 0.0
	for lap in lap_times:
		if lap > 0.5 and (best == 0.0 or lap < best):
			best = lap
	return best


func _format_time(seconds: float) -> String:
	var whole: int = int(seconds)
	return "%02d:%02d.%03d" % [whole / 60, whole % 60, int(round((seconds - whole) * 1000.0)) % 1000]


func _result_stats_text() -> String:
	var lines: PackedStringArray = ["Gesamtzeit   " + _format_time(elapsed)]
	var best: float = _best_lap()
	if best > 0.0 and mode not in ["arena", "training"]:
		lines.append("Beste Runde   " + _format_time(best))
	lines.append("Sterne gesammelt   %d" % collected.size())
	lines.append("Belohnung   +%d Sterne" % int(result_payload.get("stars", 0)))
	return "\n".join(lines)


func _place_title(place: int) -> String:
	match place:
		1:
			return "1. PLATZ!"
		2:
			return "2. Platz!"
		3:
			return "3. Platz!"
	return "Platz %d" % place


func _place_cheer(place: int) -> String:
	match place:
		1:
			return "Lumo jubelt – du hast gewonnen!"
		2:
			return "Super gefahren – Silber für dich!"
		3:
			return "Stark – du stehst auf dem Treppchen!"
	return "Gut gekämpft! Beim nächsten Mal geht es weiter nach vorn."


func _place_color(place: int) -> Color:
	match place:
		1:
			return Color("ffd86b")
		2:
			return Color("dfe8f2")
		3:
			return Color("e7a066")
	return Color("9fe4ff")


## Zieleinlauf: Eingaben sind aus, das Kart rollt aus, die Kamera schwenkt
## seitlich nach vorn auf Lumo, Lumo reagiert auf den Platz. Danach erscheint
## das Ergebnis über der weiterlaufenden 3D-Szene.
func _start_finish_cine(place: int) -> void:
	finish_place = place
	finish_coast_speed = maxf(speed, 6.0)
	modal.hide()
	if is_instance_valid(controls_row):
		controls_row.hide()
	if is_instance_valid(player) and player.has_method("celebrate"):
		player.celebrate(place if _ranked() else 1)
	message.text = _place_title(place) if _ranked() else "Ziel!"
	finish_cine_left = FINISH_CINE_REDUCED_SECONDS if reduced_motion else FINISH_CINE_SECONDS
	if place == 1 and not reduced_motion and not lightweight and _ranked():
		_spawn_finish_confetti()


func _update_finish_cine(delta: float) -> void:
	finish_cine_left = maxf(0.0, finish_cine_left - delta)
	var total: float = FINISH_CINE_REDUCED_SECONDS if reduced_motion else FINISH_CINE_SECONDS
	var t: float = clampf(1.0 - finish_cine_left / total, 0.0, 1.0)
	var ahead := Vector3(-sin(player_heading), 0, -cos(player_heading))
	# Ausrollen mit sanfter Bremsung, nicht abrupt stehen bleiben.
	finish_coast_speed = move_toward(finish_coast_speed, 0.0, delta * maxf(6.0, finish_coast_speed * 0.55))
	player.position += ahead * finish_coast_speed * delta
	player.set_motion(finish_coast_speed, 0.0, false, false)
	speed = finish_coast_speed
	if is_instance_valid(camera):
		var blend: float = smoothstep(0.0, 1.0, t)
		var side := Vector3(-ahead.z, 0, ahead.x)
		var angle: float = lerpf(0.0, PI * 0.78, blend)
		var radius: float = lerpf(6.6, 4.6, blend)
		var offset: Vector3 = (-ahead * cos(angle) + side * sin(angle)) * radius
		var desired: Vector3 = player.position + offset + Vector3.UP * lerpf(3.5, 1.7, blend)
		camera.position = camera.position.lerp(desired, minf(1.0, delta * 6.0))
		camera.look_at(player.position + Vector3.UP * 1.25)
	_update_hud()
	if finish_cine_left <= 0.0:
		_show_result()


func _skip_finish_cine() -> void:
	if finished and finish_cine_left > 0.0:
		finish_cine_left = 0.0
		_show_result()


func _spawn_finish_confetti() -> void:
	if is_instance_valid(finish_confetti):
		finish_confetti.queue_free()
	var particles := CPUParticles3D.new()
	particles.amount = 70
	particles.lifetime = 2.4
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.direction = Vector3.UP
	particles.spread = 55.0
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 9.0
	particles.gravity = Vector3(0, -7.5, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.1
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	particles.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color("ffd86b"))
	ramp.add_point(0.5, Color("53ddfd"))
	ramp.set_color(1, Color("ff8be8"))
	particles.color_initial_ramp = ramp
	particles.position = player.position + Vector3.UP * 2.0
	race_root.add_child(particles)
	particles.emitting = true
	finish_confetti = particles


func _next_cup_race() -> void:
	if not pending_cup_next or not finished:
		return
	cup_index += 1
	track_id = str(CATALOG.TRACKS[cup_index].id)
	_begin_race()


func _restart_setup() -> void:
	_start_selected_race(setup_snapshot)


func _leave_race_for_menu() -> void:
	_save_session()
	saved_session_available = not abandoned and (not finished or pending_cup_next)
	_show_garage()


func _rebuild_graphics() -> void:
	var saved_transform: Transform3D = player.transform
	var saved_heading: float = player_heading
	var saved_item_boxes: Dictionary = item_box_collected.duplicate()
	var rival_transforms: Array[Transform3D] = []
	for rival in opponents:
		rival_transforms.append(rival.transform)
	var state: Dictionary = {}
	for key in [
		"opponent_headings",
		"opponent_scores",
		"opponent_targets",
		"opponent_stuns",
		"opponent_items",
		"opponent_item_cooldowns",
		"opponent_boost_times",
		"opponent_shield_times",
		"opponent_pulse_warning_times",
		"arena_pickup_timers",
	]:
		state[key] = get(key).duplicate()
	var saved_recording: Array = records.recording.duplicate(true)
	var saved_replay_index: int = records.replay_index
	_build_world()
	player.transform = saved_transform
	player_heading = saved_heading
	for i in range(opponents.size()):
		opponents[i].transform = rival_transforms[i]
	for key in state:
		var target: Array = get(key)
		target.assign(state[key])
	item_box_collected.assign(saved_item_boxes)
	_sync_item_box_visibility()
	for i in range(opponent_item_fx.size()):
		_sync_rival_item_fx(i)
	records.recording = saved_recording
	records.replay_index = saved_replay_index
	_update_camera(1, true)
	paused = false
	_pause()


func _load_preferences() -> void:
	var config := ConfigFile.new()
	config.load(PREFERENCES)
	preferred_reduced_motion = bool(config.get_value("race", "reduced_motion", false))
	var host_options: Dictionary = SceneRouter.launch_options.duplicate(true)
	host_options.merge(HostBridge.launch_options(), true)
	host_sound_enabled = bool(host_options.get("soundEnabled", true))
	host_reduce_motion = bool(host_options.get("reduceAnimations", false))
	reduced_motion = preferred_reduced_motion or host_reduce_motion
	lightweight = bool(
		config.get_value("race", "lightweight", SettingsStore.get_profile() == "low")
	)
	muted = bool(config.get_value("race", "muted", false))
	music_volume = clampf(float(config.get_value("race", "music_volume", 1.0)), 0.0, 1.0)
	effects_volume = clampf(float(config.get_value("race", "effects_volume", 1.0)), 0.0, 1.0)
	# Touch devices start with the GAS pedal; keyboard and automated runs keep auto-gas.
	var touch_device: bool = OS.has_feature("android") or OS.has_feature("ios")
	auto_gas = bool(config.get_value("race", "auto_gas", not touch_device))
	difficulty = str(config.get_value("race", "difficulty", "gemuetlich"))
	graphics_profile = str(config.get_value("race", "graphics_profile", "low" if lightweight else "high"))
	if graphics_profile not in ["high", "medium", "low"]:
		graphics_profile = "high"
	lightweight = graphics_profile == "low"


func _save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("race", "reduced_motion", preferred_reduced_motion)
	config.set_value("race", "lightweight", lightweight)
	config.set_value("race", "graphics_profile", graphics_profile)
	config.set_value("race", "muted", muted)
	config.set_value("race", "music_volume", music_volume)
	config.set_value("race", "effects_volume", effects_volume)
	config.set_value("race", "auto_gas", auto_gas)
	config.set_value("race", "difficulty", difficulty)
	config.save(PREFERENCES)
	_update_audio()
	for kart in opponents:
		kart.reduced_motion = reduced_motion


func _save_session() -> void:
	if abandoned or menu_active or not is_instance_valid(player):
		return
	var config := ConfigFile.new()
	config.set_value("race", "version", SESSION_VERSION)
	for key in [
		"distance", "result_id", "checkpoint_index", "lane", "speed", "countdown", "elapsed",
		"boost_time", "boosts", "opponent_distances", "opponent_lanes", "collected", "difficulty",
		"mode", "track_id", "selected_driver", "selected_kart", "player_heading", "previous_road_distance",
		"cup_index", "cup_points", "cup_results", "pending_cup_next", "finished", "completed_race", "result_payload",
		"arena_scores", "arena_pickup_timers", "opponent_scores", "opponent_targets", "opponent_headings",
		"item", "shield_time", "reset_count", "setup_snapshot", "item_box_collected", "opponent_items"
	]:
		config.set_value("race", key, get(key))
	for key in RIVAL_SESSION_TIMERS:
		config.set_value("race", key, get(key))
	if loop_state.active:
		# A interrupted loop resumes safely on its entry road, with no lap shortcut.
		config.set_value("race", "distance", loop_state.entry_progress)
		config.set_value("race", "previous_road_distance", float(world.loop_layout.start))
		config.set_value("race", "player_heading", _heading(float(world.loop_layout.start)))
		config.set_value("race", "player_position", world.reset_transform(float(world.loop_layout.start), float(world.loop_layout.lane)).origin)
	else:
		config.set_value("race", "player_position", player.position)
	var positions: Array[Vector3] = []
	for rival in opponents:
		positions.append(rival.position)
	config.set_value("race", "opponent_positions", positions)
	if config.save(SESSION + ".tmp") == OK:
		var error: Error = DirAccess.rename_absolute(SESSION + ".tmp", SESSION)
		if error != OK:
			push_warning("Race checkpoint could not be saved: %s" % error)


func _restore_session() -> bool:
	var config := ConfigFile.new()
	if config.load(SESSION) != OK:
		return false
	if int(config.get_value("race", "version", 0)) not in SESSION_VERSIONS:
		return false
	var saved_distance: float = float(config.get_value("race", "distance", -1))
	if saved_distance < 0 or not is_finite(saved_distance):
		return false
	var keys: Array[String] = [
		"distance", "result_id", "checkpoint_index", "lane", "speed", "countdown", "elapsed", "boost_time", "boosts",
		"collected", "difficulty", "mode", "track_id", "selected_driver", "selected_kart",
		"player_heading", "previous_road_distance", "cup_index",
		"pending_cup_next", "finished", "completed_race", "result_payload", "arena_scores", "item", "shield_time",
		"reset_count", "setup_snapshot"
	]
	for key in keys:
		set(key, config.get_value("race", key, get(key)))
	for key in [
		"opponent_distances", "opponent_lanes", "cup_points", "cup_results",
		"arena_pickup_timers", "opponent_scores", "opponent_targets", "opponent_headings"
	]:
		var target: Array = get(key)
		target.assign(config.get_value("race", key, target))
	_restore_item_continuity(config)
	if int(config.get_value("race", "version", 0)) < 3:
		checkpoint_index = clampi(int(distance / (track_length / 8.0)), 0, TOTAL_LAPS * 8)
		player.transform = world.reset_transform(distance, lane)
		player_heading = _heading(distance)
		previous_road_distance = fposmod(distance, track_length)
	else:
		player.position = config.get_value("race", "player_position", player.position)
		var positions: Array = config.get_value("race", "opponent_positions", [])
		for i in range(mini(positions.size(), opponents.size())):
			opponents[i].position = positions[i]
	player.rotation.y = player_heading
	ghost_valid = false
	mode = _known_mode(mode)
	racing = countdown <= 0 and not completed_race
	_update_vehicles(0)
	_update_camera(1, true)
	if finished:
		_show_result()
	return true


func _sync_item_box_visibility() -> void:
	var lap: int = int(distance / track_length)
	for i in range(item_boxes.size()):
		item_boxes[i].visible = not item_box_collected.has(lap * item_boxes.size() + i)


func _restore_item_continuity(config: ConfigFile) -> void:
	item_box_collected.clear()
	var saved_pickups = config.get_value("race", "item_box_collected", {})
	if saved_pickups is Dictionary:
		for key in saved_pickups:
			if (
				typeof(key) == TYPE_INT and key >= 0
				and typeof(saved_pickups[key]) == TYPE_BOOL and saved_pickups[key]
			):
				item_box_collected[key] = true
	_sync_item_box_visibility()
	var saved_items = config.get_value("race", "opponent_items", [])
	for i in range(opponents.size()):
		var saved_item: String = ""
		if saved_items is Array and i < saved_items.size() and saved_items[i] is String:
			saved_item = saved_items[i]
		opponent_items[i] = saved_item if saved_item in ["boost", "shield", "pulse"] else ""
	for key in RIVAL_SESSION_TIMERS:
		var timers: Array = get(key)
		var saved_timers = config.get_value("race", key, [])
		for i in range(opponents.size()):
			var seconds: float = 0.0
			if saved_timers is Array and i < saved_timers.size():
				var value = saved_timers[i]
				if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)):
					seconds = clampf(float(value), 0.0, float(RIVAL_SESSION_TIMERS[key]))
			timers[i] = seconds
	for i in range(opponent_item_fx.size()):
		_sync_rival_item_fx(i)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not is_instance_valid(modal):
			return
		if is_instance_valid(intro) and not intro.leaving:
			# Zurück während des Intros überspringt nur das Intro.
			intro.leave()
			return
		if menu_active:
			_return_to_world()
		elif finished or paused:
			_return_to_world()
		else:
			_pause()
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		if is_instance_valid(engine_player):
			engine_player.stop()
			engine_playback = null
		if is_instance_valid(modal) and not finished:
			_pause()


func _exit_tree() -> void:
	get_tree().auto_accept_quit = previous_auto_accept_quit
	get_tree().quit_on_go_back = previous_quit_on_go_back
	if is_instance_valid(engine_player):
		engine_player.stop()
		engine_playback = null
		engine_player.stream = null
	_save_session()
	get_window().content_scale_size = previous_scale
	if OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(previous_orientation)
	elif DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		get_window().size = previous_size


func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var key: String = color.to_html() + str(metallic)
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	mat.metallic = metallic
	materials[key] = mat
	return mat


func _gem_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [
		Vector3(0, 0.5, 0),
		Vector3(0, -0.5, 0),
		Vector3(0.35, 0, 0),
		Vector3(0, 0, 0.35),
		Vector3(-0.35, 0, 0),
		Vector3(0, 0, -0.35)
	]
	for ring in range(4):
		var a: int = 2 + ring
		var b: int = 2 + (ring + 1) % 4
		for index in [0, b, a, 1, a, b]:
			tool.add_vertex(points[index])
	tool.generate_normals()
	return tool.commit()


func _glow_material(color: Color, energy: float = 1.2) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.35
	return material


## Build one chevron arm from a track frame. The arm always converges toward
## local travel (-basis.z), so visual boost arrows cannot silently point backwards.
static func _chevron_arm_geometry(track_basis: Basis, side: float) -> Dictionary:
	var forward := (-track_basis.z).normalized()
	var right := track_basis.x.normalized()
	var up := track_basis.y.normalized()
	var tip := forward * 0.38
	var tail := -forward * 0.42 + right * side * 0.72
	var direction := (tip - tail).normalized()
	var local_z := direction.cross(up).normalized()
	return {
		"basis": Basis(direction, up, local_z),
		"offset": (tip + tail) * 0.5,
		"direction": direction,
		"forward": forward,
	}


## Turbo pad (reference k03): dark plate, three glowing chevrons, orange side lights.
## It covers exactly the boost zone checked in _track_events.
func _turbo_pad(distance_on_track: float) -> void:
	var basis: Basis = world.frame(distance_on_track + 1.1)
	var centre: Vector3 = _track_position(distance_on_track + 1.1, 0) + basis.y * 0.035
	var plate := _box(race_root, centre, Vector3(4.4, 0.04, 2.6), Color("142a6e"))
	plate.basis = basis
	var cyan := _glow_material(Color("4fe6ff"), 1.6)
	var orange := _glow_material(Color("ff9a3c"), 1.4)
	for side in [-1.0, 1.0]:
		var bar_at: Vector3 = centre + basis.x * side * 2.15 + basis.y * 0.02
		var bar := _box(race_root, bar_at, Vector3(0.18, 0.05, 2.6), Color("ff9a3c"))
		bar.basis = basis
		bar.material_override = orange
	var travel := (-basis.z).normalized()
	for chevron in range(3):
		var anchor: Vector3 = centre + travel * (0.85 - chevron * 0.75) + basis.y * 0.03
		for arm in [-1.0, 1.0]:
			var geometry: Dictionary = _chevron_arm_geometry(basis, arm)
			var piece_at: Vector3 = anchor + geometry.offset
			var piece := _box(race_root, piece_at, Vector3(1.3, 0.04, 0.2), Color("4fe6ff"))
			piece.basis = geometry.basis
			piece.material_override = cyan


static func _item_pool_for_place(place: int) -> Array[String]:
	if place >= 5:
		return ["boost", "boost", "boost", "shield", "shield", "pulse"]
	if place >= 3:
		return ["boost", "boost", "shield", "shield", "pulse", "pulse"]
	return ["boost", "shield", "shield", "pulse", "pulse", "pulse"]


func _roll_item_for_place(place: int) -> String:
	var pool: Array[String] = _item_pool_for_place(place)
	return pool[rng.randi_range(0, pool.size() - 1)]


func _item_box(distance_on_track: float, lateral: float) -> void:
	var basis: Basis = world.frame(distance_on_track)
	var node := Node3D.new()
	node.name = "MysteryItemBox"
	node.position = _track_position(distance_on_track, lateral) + basis.y * 0.85
	node.basis = basis
	node.scale = Vector3.ONE * (1.18 if world.track_id == "bergwelt" else 1.0)
	race_root.add_child(node)
	MYSTERY_PRISM.build(node)
	item_boxes.append(node)
	item_box_distances.append(distance_on_track)


func _mesh(parent: Node3D, mesh: Mesh, position: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	node.material_override = _material(color)
	parent.add_child(node)
	return node


func _box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	if not boxes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		boxes[size] = mesh
	var box: BoxMesh = boxes[size]
	return _mesh(parent, box, position, color)


func _ball(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	if sphere_mesh == null:
		sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 1.0
		sphere_mesh.height = 2.0
		sphere_mesh.radial_segments = 24
		sphere_mesh.rings = 12
	var node := _mesh(parent, sphere_mesh, position, color)
	node.scale = size
	return node


func _build_engine_sound() -> void:
	kart_audio = KART_AUDIO.new()
	add_child(kart_audio)
	kart_audio.set_muted(muted or not host_sound_enabled)
	kart_audio.set_volumes(music_volume, effects_volume)
	engine_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050
	stream.buffer_length = 0.1
	engine_player.stream = stream
	add_child(engine_player)
	_update_audio()


func _update_audio() -> void:
	if is_instance_valid(kart_audio):
		kart_audio.set_muted(muted or not host_sound_enabled)
		kart_audio.set_paused(paused)
	if not is_instance_valid(engine_player):
		return
	if muted or not host_sound_enabled or menu_active or paused or finished or not racing:
		engine_player.stop()
		engine_playback = null
	elif not engine_player.playing:
		engine_player.play()
		engine_playback = engine_player.get_stream_playback()


## Lautstärkezeile im Pausenmenü: große Schieberegler (10 %-Schritte), sofort hörbar.
func _volume_row(title: String, value: float, on_change: Callable) -> Control:
	# Untereinander statt nebeneinander: bleibt auch im schmalen Hochformat innerhalb der Pause.
	var row := VBoxContainer.new()
	row.name = "Volume" + title
	row.add_theme_constant_override("separation", 2)
	var label := _label(title, 20)
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = "Slider"
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 10
	slider.value = roundf(value * 100.0)
	slider.custom_minimum_size = Vector2(0, 48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = title + "-Lautstärke"
	slider.value_changed.connect(func(v: float):
		on_change.call(v / 100.0)
		_save_preferences())
	row.add_child(slider)
	return row


func _apply_volumes() -> void:
	if is_instance_valid(kart_audio):
		kart_audio.set_volumes(music_volume, effects_volume)


func _sound_effect(kind: String) -> void:
	if is_instance_valid(kart_audio):
		kart_audio.effect(kind)

