extends Node3D
# gdlint: disable=max-file-lines
## Free steering arcade racing, original Lumo worlds, five complete modes and host-safe saves.
## Product rule (Heinz, 2026-10-04): no learning questions, learning cups or answer timers in Kart.

const UI = preload("res://scripts/games/kart_ui_theme.gd")
const KART_AUDIO = preload("res://scripts/games/kart_audio.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const TUNING = preload("res://scripts/games/kart_tuning.gd")
const GARAGE = preload("res://scripts/games/kart_spatial_menu.gd")
const REFERENCE_LANDING = preload("res://scripts/games/kart_neon_hub.gd")
const INTRO = preload("res://scripts/games/kart_intro.gd")
const RECORDS = preload("res://scripts/games/kart_records.gd")
const TRACK_PASS = preload("res://scripts/games/kart_track_pass.gd")
const ARENA = preload("res://scripts/games/kart_arena.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const PHYSICAL_LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const TRACK_PIECES = preload("res://scripts/games/track_pieces/kart_track_pieces.gd")
const RIVAL_STUNTS = preload("res://scripts/games/kart_rival_stunts.gd")
const RIVAL_FLIGHT = preload("res://scripts/games/kart_rival_flight.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")
const DARKRIDE_EVENT = preload("res://scripts/games/kart_darkride_event_director.gd")
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const ADVENTURE_DRAMA = preload("res://scripts/games/kart_adventure_drama.gd")
const ROADSIDE_LASSO = preload("res://scripts/games/kart_roadside_lasso.gd")
const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")
const MINIMAP = preload("res://scripts/games/kart_hud/kart_race_minimap.gd")
const RACE_HUD = preload("res://scripts/games/kart_hud/kart_race_hud.gd")
const TOUCH_ACTION = preload("res://scripts/games/kart_touch_action.gd")
const JOYSTICK = preload("res://scripts/games/kart_joystick.gd")
const RIVAL_ITEM_FX = preload("res://scripts/games/kart_rival_item_fx.gd")
const RIVAL_RACECRAFT = preload("res://scripts/games/kart_rival_racecraft.gd")
const RIVAL_RAMP_PLAN = preload("res://scripts/games/kart_rival_ramp_plan.gd")
const OPPONENT_ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const VISUAL_GRADE = preload("res://scripts/games/kart_visual_grade.gd")
const SPEED_FX = preload("res://scripts/games/kart_speed_fx.gd")
const DRIVE_FEEDBACK = preload("res://scripts/games/kart_drive_feedback.gd")
## Fahrgefühl-Effekte (Funken, Spuren, Rauch, Motor, Federung): scripts/games/kart_fx/.
const DRIVE_FX = preload("res://scripts/games/kart_fx/kart_drive_fx.gd")
const RESONANCE = preload("res://scripts/games/kart_resonance_system.gd")
const STUNT = preload("res://scripts/games/kart_sonnenhafen_stunt_sequence.gd")
const MYSTERY_PRISM = preload("res://scripts/games/kart_mystery_prism.gd")
const PRECISION = preload("res://scripts/games/kart_precision_jump.gd")
const AIR_TRICK = preload("res://scripts/games/kart_air_trick.gd")
const JUMP_HINT = preload("res://scripts/games/visual/kart_jump_speed_hint.gd")
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const PASSAGE_ART = preload("res://scripts/games/kart_passage_art.gd")
## LUMO-Passagen (Eisbrücke, Kronenbrücke, Lianenaffe): Zähler für Tests und Ergebnis.
var passage_falls: int = 0
var passage_hits: int = 0
var passage_announced: Dictionary = {}
var _passage_last_phase: Dictionary = {}
var _passage_hit_cooldown: float = 0.0
const MESSAGE_SECONDS: float = 6.0
var _message_seen: String = ""
var _message_age: float = 0.0
var _traffic_player_entry: int = -1
## Karts (rivals + child) at the front of the last _rival_traffic list; static obstacles follow.
var _traffic_kart_entries: int = -1
var passage_creep: String = ""
var passage_fall_respawn: float = -1.0
## The jump speed hint appears this many metres before the ramp starts.
const JUMP_HINT_LEAD_M: float = 70.0
## Maximum intentional lateral displacement during a precision flight.
const PRECISION_AIR_LATERAL_M: float = 2.0
const ITEM_CATALOG = preload("res://scripts/games/kart_items/kart_item_catalog.gd")
## Item-Protokoll ohne Spielwirkung (Tests, Balance-Messung).
const ITEM_TELEMETRY = preload("res://scripts/games/kart_items/kart_item_telemetry.gd")
const ITEM_ZONES = preload("res://scripts/games/kart_items/kart_item_zones.gd")
## „LUMO Sternenkompass“: Darstellung der einmaligen Ziehung (kart_items/kart_star_compass.gd).
const STAR_COMPASS = preload("res://scripts/games/kart_items/kart_star_compass.gd")
var star_compass = STAR_COMPASS.new()
## Faire Sternraketen: Start-/Rettungsschutz, Verfolger-Limit, keine Treffer an Sturzstellen.
const ROCKET_FAIRNESS = preload("res://scripts/games/kart_items/kart_rocket_fairness.gd")
var rocket_fairness = ROCKET_FAIRNESS.new()
var item_telemetry = ITEM_TELEMETRY.new()
const RACE_RULES = preload("res://scripts/games/kart_items/kart_race_rules.gd")
const ITEM_RUNTIME = preload("res://scripts/games/kart_items/kart_item_runtime.gd")
const FX_DIRECTOR = preload("res://scripts/games/kart_items/kart_fx_director.gd")
const ITEM_BOX_SCENE = preload("res://scenes/games/props/kart_item_box.tscn")
const ITEM_HUD = preload("res://scripts/games/kart_items/kart_item_hud.gd")
const ROCKET_PODS = preload("res://scripts/games/kart_items/kart_rocket_pods.gd")
const ROCKET_FLIGHT = preload("res://scripts/games/kart_items/kart_rocket_flight.gd")
const FRAME_SMOOTHER = preload("res://scripts/games/kart_items/kart_frame_smoother.gd")
const ITEM_STATUS_FX = preload("res://scripts/games/kart_items/kart_item_status_fx.gd")
const SHIELD_DOME = preload("res://scripts/games/kart_items/kart_shield_dome.gd")
const BOOST_RING_SCENE = preload("res://scenes/games/props/kart_boost_ring.tscn")
const MODAL_STYLE = preload("res://scripts/games/kart_modal_style.gd")
const TRIGGER_GROUP := "lumo_kart_triggers"
## Built-in boost ring layout per course (fraction of lap, lateral offset).
const BOOST_RING_LAYOUT: Array = [[0.27, 0.0], [0.61, -1.6]]
## A row of surprise boxes across the road (lateral metres) at two calm spots per lap.
const CATALOG_BOX_ROW: Array[float] = [-3.2, 0.0, 3.2]
const CATALOG_BOX_ROWS_PER_LAP: int = 2
const CATALOG_BOX_RADIUS: float = 2.2
const TOTAL_LAPS: int = 2
const ROAD_WIDTH: float = 10.8
const SESSION: String = "user://kart_sonnenhafen_session.cfg"
const PREFERENCES: String = "user://kart_preferences.cfg"
const BOOST_ACCELERATION_MULTIPLIER: float = 2.0
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const RESULT_KIT = preload("res://scripts/games/kart_result_kit.gd")
const RESULT_BADGE = preload("res://scripts/games/kart_result_badge.gd")
const RESULT_WIDGETS = preload("res://scripts/games/kart_result_widgets.gd")
const DESIGN_VIEWPORT := Vector2(1280.0, 720.0)
const PEDAL_PAD_BASE_SIZE := Vector2(440.0, 300.0)
## Version 4 drops the removed learning-question state; older saves still resume as plain races.
const SESSION_VERSION: int = 4
const SESSION_VERSIONS: Array[int] = [1, 2, 3, 4]
const MODE_IDS: Array[String] = ["race", "cup", "time_trial", "training", "arena"]
## Drift turbo tiers: blue after 0.8 s of full steering, orange after 1.8 s, purple after 2.7 s.
const DRIFT_TIERS: Array[float] = RACE_RULES.DRIFT_TIERS
const DRIFT_BOOST_SECONDS: Array[float] = RACE_RULES.DRIFT_BOOST_SECONDS
## Arcade jump: strong gravity and a capped take-off speed keep flights short and readable.
## Tuned on the Himmelsinseln gap: 17 m/s (Entdecken) clears it, a crawl below ~13 m/s falls,
## turbo speed lands before the crystal cave.
const JUMP_GRAVITY: float = 30.0
const JUMP_MAX_LIFT: float = 4.0
## The hero ramp has a longer arc; all other launches retain their baseline gravity.
var current_jump_gravity: float = JUMP_GRAVITY
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
var roadside_lasso: Node3D
var darkride_event = DARKRIDE_EVENT.new()
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
var start_light_state: int = -1
var start_light_diameter: float = -1.0
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
var finish_coast_reverse: bool = false
var finish_road_distance: float = -1.0
var finish_camera_world: int = 0
var finish_camera_boxes: Array[Dictionary] = []
var finish_place: int = 0
var finish_confetti: Node3D
var lap_times: Array[float] = []
var lap_started_at: float = 0.0
var elapsed: float = 0.0
var boost_time: float = 0.0
var boosts: int = 1
var drift_charge: float = 0.0
var drift_tier_count: Array[int] = [0, 0, 0]
## Arcade gameplay layer (items, spins, slipstream, tricks, combos, catch-up).
var item_charges: int = 0
var player_spin_time: float = 0.0
var magnet_time: float = 0.0
var aurora_time: float = 0.0
var slipstream_charge: float = 0.0
var slipstream_ready_leader: int = -1
var combo: int = 0
var last_boost_source_at: float = -100.0
var item_runtime: Node3D
var fx: Node3D
## Raketen-Inszenierung (Spur, Einschlag, Wirbel, Trefferbild) und bildweise Glättung.
var rocket_flight: Node3D
var frame_smoother: Node
## Laufender Sternmagnet / Nordlicht-Lauf als Ring am Kart.
var item_status_fx: Node3D
var track_triggers: Array[Node3D] = []
var trigger_cooldowns: Dictionary = {}
var opponent_spin_times: Array[float] = []
var opponent_aurora_times: Array[float] = []
var opponent_previous_positions: Array[Vector3] = []
var player_previous_position := Vector3.ZERO
var gameplay_stats: Dictionary = {}
var wall_contacts: int = 0
var airborne: bool = false
var air_trick: Dictionary = {}
var vertical_speed: float = 0.0
var air_time: float = 0.0
var jump_count: int = 0
var landing_count: int = 0
## Brief post-landing settle so hard touchdowns don't yank the kart sideways.
var landing_settle: float = 0.0
## Camera FOV punch for mini-turbo and item bursts (visual only).
var camera_punch: float = 0.0
## Eased field of view without the short kicks (0 = not set yet).
var camera_base_fov: float = 0.0
var gap_falls: int = 0
## Sonnenhafen precision jump: the kicker in flight, and the measured results.
var precision_kicker: Dictionary = {}
var precision_launch_lateral: float = 0.0
var last_precision_landing: String = ""
var last_precision_flown: float = 0.0
var precision_results: Dictionary = {}
var jump_hint: Control
## Action-Parcours: genutzte Turbo-Felder (je Runde einmal), Slalom-Fortschritt, Schanzen, Stürze.
var action_pads_used: Dictionary = {}
var action_gates_hit: int = 0
var action_gates_passed: int = 0
var action_slaloms_cleared: int = 0
var action_pads_triggered: int = 0
var action_kicker_jumps: int = 0
var action_edge_falls: int = 0
var action_in_dive: bool = false
var dive_tint: ColorRect
var wall_sound_timer: float = 0.0
var wrong_way: bool = false
var wrong_way_seconds: float = 0.0
var drifting: bool = false
var racing: bool = false
var finished: bool = false
var paused: bool = false
var abandoned: bool = false
var rng := RandomNumberGenerator.new()
## Fester Zufalls-Seed nur für Tests und Messungen; -1 (Standard) lässt das Spiel wie bisher zufällig.
## Wird bei jedem Rennstart neu gesetzt, damit Vorher/Nachher-Läufe gleich beginnen.
var race_seed: int = -1
var player: LumoRaceKart
var camera: Camera3D
var speed_fx: Node3D
var drive_feedback: Node3D
var drive_fx: Node3D
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
var item_box_laterals: Array[float] = []
var item_box_collected: Dictionary = {}
## Surprise item boxes (branch item system) beside the HEAD skill resonance rings.
var catalog_boxes: Array[Node3D] = []
var catalog_box_distances: Array[float] = []
var catalog_box_laterals: Array[float] = []
var catalog_box_collected: Dictionary = {}
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
## Zieleinlauf: Tafel rechts (quer) bzw. unten (hoch), ohne Abdunklung; die
## Kamera stellt das Kart in die freie Fläche.
var result_view: bool = false
var result_scale: float = 1.0
var result_camera_time: float = 0.0
## Bildschirmanteil (0..1), in dessen Mitte das Kart stehen soll, und der Anteil
## der freien Fläche an Breite und Höhe.
var result_focus: Vector2 = Vector2(0.5, 0.5)
var result_free: Vector2 = Vector2.ONE
var safe_ui: Control
var muted: bool = false
var host_sound_enabled: bool = true
var host_reduce_motion: bool = false
var preferred_reduced_motion: bool = false
## Hook kart-garage: Linkshänder-Steuerung (Lenk-Stick rechts, Knöpfe links), siehe kart_race_hud.gd.
var left_handed: bool = false
var reduced_motion: bool = false
var lightweight: bool = false
var difficulty: String = "gemuetlich"
var save_timer: float = 0.0
## Persist the first real racing second, then keep the normal five-second cadence.
var first_active_snapshot_pending: bool = false
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
var reference_landing: Control
var menu_active: bool = true
var mode: String = "race"
var track_id: String = "sonnenhafen"
var selected_driver: String = "fox"
var selected_kart: String = "comet"
## Tuning-Werkstatt des aktuellen Kindes (Stufen, Aussehen, Sternebudget) und die daraus
## berechneten Fahrfaktoren des gewählten Karts. Leer = Werte direkt aus der Flotte.
var workshop
var kart_factors: Dictionary = {}
var loop_state = PHYSICAL_LOOP.new()
var loop_count: int = 0
var player_heading: float = 0.0
var physical_velocity := Vector3.ZERO
var previous_road_distance: float = 0.0
var offroad_seconds: float = 0.0
var open_edge_fall: bool = false
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
var track_pass
var _track_pass_owner := ""
var ghost: LumoRaceKart
var ghost_valid: bool = true
var best_record: bool = false
var setup_snapshot: Dictionary = {}
const REVERSE_ENGAGE_SECONDS: float = 0.28
const REVERSE_SPEED: float = 5.0
var control_brake: float = 0.0
var brake_visual_amount: float = 0.0
var reverse_hold_time: float = 0.0
var map: Control
var map_panel: PanelContainer
var _minimap_layout_pending := false
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
var menu_settings_open: bool = false
var menu_settings_navigation: HBoxContainer
var previous_scale := Vector2i(720, 1280)
var previous_size := Vector2i(720, 1280)
var previous_orientation: int = DisplayServer.SCREEN_PORTRAIT
var previous_auto_accept_quit: bool = true
var previous_quit_on_go_back: bool = true
var _session_handed_off: bool = false


func _ready() -> void:
	set_physics_process(false)
	rng.randomize()
	result_id = HostBridge.new_result_id()
	# Capture the owner at entry; changing host options later cannot attribute
	# the current child's already-running race to another child.
	track_pass = TRACK_PASS.new(str(HostBridge.launch_options().get("childKey", "standalone")))
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
	# Erste Einführung je Kind (zeigt sich erst im Rennen): scripts/games/guides/kart_guide.gd
	load("res://scripts/games/guides/kart_guide.gd").attach(self)
	_build_engine_sound()
	saved_session_available = (
		session_config.load(SESSION) == OK
		and int(session_config.get_value("race", "version", 0)) in SESSION_VERSIONS
	)
	_show_garage()
	set_physics_process(true)
	print("[Kart] Holographic garage ready: five modes, %d worlds, free steering" % CATALOG.TRACKS.size())


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
	item_box_laterals.clear()
	item_box_collected.clear()
	catalog_boxes.clear()
	catalog_box_distances.clear()
	catalog_box_laterals.clear()
	catalog_box_collected.clear()
	item_telemetry.clear()
	rocket_fairness.reset()
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
	opponent_spin_times.clear()
	opponent_aurora_times.clear()
	opponent_previous_positions.clear()
	track_triggers.clear()
	trigger_cooldowns.clear()
	ghost = null
	darkride_event.bind_world(null)
	if is_instance_valid(kart_audio):
		kart_audio.bind_world(null)
	roadside_lasso = null
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
		if is_instance_valid(kart_audio):
			kart_audio.bind_world(world)
		roadside_lasso = ROADSIDE_LASSO.new()
		roadside_lasso.name = "RoadsideLasso"
		world.add_child(roadside_lasso)
		roadside_lasso.setup(world)
		darkride_event.bind_world(world)
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
		# Stunt stars on the loop's riding line and over its boost pad (Sonnenhafen).
		for at in STUNT.star_positions(world):
			var stunt_star: MeshInstance3D = _mesh(race_root, star_mesh, at, Color("ffc94a"))
			stunt_star.scale = Vector3.ONE * 0.55
			stunt_star.material_override = _glow_material(Color("ffc94a"), 0.6)
			gems.append(stunt_star)
			gem_distances.append(STUNT.loop_start(world))
		# Turbo-Felder und Item-Ringe folgen der Abenteuer-Dramaturgie je Strecke
		# (kart_adventure_drama.gd); Strecken ohne eigene Dramaturgie behalten die alten Werte.
		# LUMO passages: no pad, ring or box on a narrow deck, a plaza or at Kiri's line.
		for fraction in ADVENTURE_DRAMA.turbo_fractions(track_id):
			_turbo_pad(PASSAGES.clear_distance(world, float(fraction) * track_length))
		var item_layout: Array = ADVENTURE_DRAMA.item_layout(track_id)
		for entry in item_layout:
			_item_box(PASSAGES.clear_distance(world, float(entry[0]) * track_length), float(entry[1]))
		for entry in BOOST_RING_LAYOUT:
			_boost_ring(PASSAGES.clear_distance(world, float(entry[0]) * track_length), float(entry[1]))
		# Sammelzonen für Zufallsprismen: 5–8 je Runde (kart_items/kart_item_zones.gd).
		for zone in ITEM_ZONES.plan(world, _catalog_zone_occupied()):
			for lateral in zone.laterals:
				_catalog_box(float(zone.distance), float(lateral))
	player = VEHICLE.new()
	player.set_meta("roadside_speed_factor", 1.0)
	var driver: Dictionary = CATALOG.entry(CATALOG.DRIVERS, selected_driver)
	player.set_look(_ensure_workshop().look(selected_kart))
	player.configure(selected_driver, driver.color, selected_kart)
	player.set_animated_lumo_enabled(true)
	player.reduced_motion = reduced_motion
	player.set_graphics_quality(graphics_profile)
	race_root.add_child(player)
	drive_feedback = DRIVE_FEEDBACK.new()
	drive_feedback.reduced_motion = reduced_motion
	race_root.add_child(drive_feedback)
	drive_feedback.bind_vehicle(player)
	# Hook kart_fx: Fahrgefühl-Effekte lesen nur den echten Fahrzustand dieses Rennens.
	drive_fx = DRIVE_FX.new()
	race_root.add_child(drive_fx)
	drive_fx.bind_race(self)
	shield_visual = SHIELD_DOME.new()
	shield_visual.reduced_motion = reduced_motion
	player.add_child(shield_visual)
	pulse_visual = MeshInstance3D.new()
	var pulse_mesh := TorusMesh.new()
	pulse_mesh.inner_radius = 0.82
	pulse_mesh.outer_radius = 1.28
	pulse_mesh.rings = 48
	pulse_mesh.ring_segments = 8
	pulse_visual.mesh = pulse_mesh
	var pulse_material := StandardMaterial3D.new()
	pulse_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pulse_material.albedo_color = Color("d4b8ff")
	pulse_material.emission_enabled = true
	pulse_material.emission = Color("c58cff")
	pulse_material.emission_energy_multiplier = 2.6
	pulse_visual.material_override = pulse_material
	pulse_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pulse_visual.visible = false
	race_root.add_child(pulse_visual)
	var animals: Array[String] = ["otter", "rabbit", "badger", "cat", "fox"]
	var colors: Array[Color] = [Color("75d7f1"), Color("a696ee"), Color("83dab9"), Color("c8d8ef"), Color("6987db")]
	var reference_rivals: bool = OPPONENT_ROSTER.ready_for_race()
	if reference_rivals:
		var roster := OPPONENT_ROSTER.for_game("kart")
		var frog_index := roster.find_custom(func(entry: Dictionary) -> bool: return entry.id == "frog")
		if mode == "race" and track_id == "jungle_emerald_3600" and selected_driver != "frog" and frog_index >= animals.size():
			# Keep the five starting positions and the cup lineup stable.
			roster[animals.size() - 1] = roster[frog_index]
		for index in range(animals.size()):
			animals[index] = str(roster[index].id)
			colors[index] = Color(str(roster[index].color))
	var rival_count: int = 0 if mode in ["time_trial", "training"] else 5
	var rival_karts: Array[String] = _rival_karts()
	for i in range(rival_count):
		var opponent: LumoRaceKart = VEHICLE.new()
		opponent.set_meta("roadside_speed_factor", 1.0)
		opponent.set_meta("reference_rival", reference_rivals)
		# Without the authored roster a fox can race as a rival: then it is
		# the real Lumo too, never the stand-in figure.
		opponent.set_animated_lumo_enabled(animals[i] == "fox")
		opponent.configure(animals[i], colors[i], rival_karts[i % rival_karts.size()])
		opponent.set_reference_rival_enabled(reference_rivals)
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
		opponent_spin_times.append(0.0)
		opponent_aurora_times.append(0.0)
		opponent_previous_positions.append(Vector3.ZERO)
	camera = Camera3D.new()
	camera.fov = VISUAL_GRADE.BASE_FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = true
	camera.far = float(LumoQuality.budget(graphics_profile).camera_far)
	race_root.add_child(camera)
	speed_fx = SPEED_FX.new()
	speed_fx.name = "CameraSpeedFx"
	camera.add_child(speed_fx)
	speed_fx.set_motion(0.0, false, reduced_motion)
	_build_gameplay_layer()
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
				# Lumo's ghost is the real Lumo as well, not the stand-in figure.
				ghost.set_animated_lumo_enabled(selected_driver == "fox")
				ghost.configure(selected_driver, Color("d3faff"), selected_kart)
				ghost.reduced_motion = reduced_motion
				# Lock the replay skin before applying transparency; a later driver
				# LOD replacement would otherwise reintroduce opaque materials.
				ghost.set_graphics_quality("low")
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
	garage.workshop = _ensure_workshop()
	garage.has_saved_race = saved_session_available
	garage.reduced_motion = reduced_motion
	garage.graphics_profile = graphics_profile
	garage.track_pass = track_pass
	if not setup_snapshot.is_empty():
		var restored: Dictionary = setup_snapshot.duplicate(true)
		restored["mode"] = _known_mode(str(restored.get("mode", "race")))
		garage.setup = restored
	else:
		# Frischer Einstieg: ein neues Kind beginnt auf "Entdecken", sonst gilt
		# die Stufe, die dieses Kind zuletzt gefahren oder eingestellt hat.
		garage.setup["difficulty"] = known_level(difficulty)
	garage.start_requested.connect(_start_selected_race)
	garage.resume_requested.connect(_resume_saved_race)
	garage.main_menu_requested.connect(func(): _show_reference_landing(true))
	garage.exit_requested.connect(_return_to_app)
	safe_ui.add_child(garage)
	# Art-directed landing is the first screen in an actual Android launch.
	# Keep CLI headless gameplay tests deterministic and unchanged.
	if not OS.get_cmdline_args().has("--script"):
		_show_reference_landing(not setup_snapshot.is_empty())
	if not intro_done:
		intro_done = true
		if _intro_wanted():
			intro = INTRO.new()
			intro.audio = kart_audio
			intro.reduced_motion = reduced_motion
			intro.finished.connect(func(): intro = null)
			safe_ui.add_child(intro)


func _show_reference_landing(preserve_setup: bool = false) -> void:
	if not is_instance_valid(garage) or not is_instance_valid(safe_ui):
		return
	if is_instance_valid(reference_landing):
		reference_landing.queue_free()
	reference_landing = REFERENCE_LANDING.new()
	reference_landing.total_stars = ProgressStore.total_stars()
	if not preserve_setup:
		garage.setup.mode = "cup"
	reference_landing.current_mode = _known_mode(str(garage.setup.mode))
	reference_landing.selected_track = str(garage.setup.get("track", ""))
	reference_landing.mode_selected.connect(_reference_select_mode)
	reference_landing.quick_start.connect(_reference_quick_start)
	reference_landing.open_settings.connect(_reference_open_settings)
	reference_landing.return_to_games.connect(func(): _return_to_app("games"))
	reference_landing.stage_region_changed.connect(garage.set_landing_stage_region)
	reference_landing.preview_rotate_requested.connect(_reference_rotate_kart)
	garage.show()
	garage.set_landing_active(true)
	safe_ui.add_child(reference_landing)


func _hide_reference_landing() -> void:
	if is_instance_valid(reference_landing):
		reference_landing.hide()
	if is_instance_valid(garage):
		garage.show()
		garage.set_landing_active(false)
		garage.preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE


func _reference_select_mode(selected: String) -> void:
	if not is_instance_valid(garage):
		return
	if _is_catalog_track(selected):
		# Neon-Menü: Strecken-Highlight und Wochen-Abenteuer wählen echte Katalogstrecken.
		garage.setup["track"] = selected
		_single_race_for_chosen_course()
		print("[Kart] track_selected: ", selected, " mode=", garage.setup.mode)
		return
	match selected:
		"race", "cup", "time_trial", "training", "arena":
			# Mode selection updates the actual next race on the same live stage.
			garage.setup["mode"] = selected
			return
		"driver":
			garage.step = 1
		"garage":
			garage.step = 2
		"world":
			# Die Streckenliste gibt es nur für Rennarten mit frei wählbarer Strecke.
			_single_race_for_chosen_course()
			garage.step = 3
		"difficulty":
			garage.step = 4
		"modes":
			garage.step = 0
		_:
			return
	_hide_reference_landing()
	garage._refresh()
	garage._apply_responsive_layout.call_deferred()



## Wer eine Strecke aussucht, will genau diese fahren. Cup und Arena haben keine
## frei wählbare Strecke und würden die Wahl stillschweigend übergehen (Issue #204).
func _single_race_for_chosen_course() -> void:
	if str(garage.setup.get("mode", "race")) not in ["cup", "arena"]:
		return
	garage.setup["mode"] = "race"
	if is_instance_valid(reference_landing) and reference_landing.has_method("set_current_mode"):
		reference_landing.set_current_mode("race")


static func _is_catalog_track(id: String) -> bool:
	for entry in CATALOG.TRACKS:
		if str(entry.id) == id:
			return true
	return false


func _reference_rotate_kart(radians: float) -> void:
	if not is_instance_valid(garage) or not is_instance_valid(garage.preview_pivot):
		return
	if not is_finite(radians):
		return
	garage.preview_angle = fposmod(garage.preview_angle + clampf(radians, -PI * 0.5, PI * 0.5), TAU)
	garage.preview_pivot.rotation.y = garage.preview_angle
	garage._fit_welcome_camera()

func _reference_open_settings() -> void:
	if not menu_active or not is_instance_valid(garage):
		return
	menu_settings_open = true
	difficulty = str(garage.setup.difficulty)
	_clear_column(modal_column)
	modal_scroll.scroll_vertical = 0
	pause_navigation.hide()
	modal_column.add_child(_label("Deine Kart-Einstellungen", 28))
	modal_column.add_child(_label("Ton, Steuerung und Darstellung für deine nächste Fahrt.", 18))
	_append_preferences()
	menu_settings_navigation.show()
	MODAL_STYLE.dress(modal, _modal_dp_scale())
	modal.show()
	modal_backdrop.move_to_front()
	modal.move_to_front()
	_apply_responsive_layout()
	_apply_responsive_layout.call_deferred()


func _close_menu_settings() -> void:
	menu_settings_open = false
	menu_settings_navigation.hide()
	modal.hide()


func _menu_back() -> void:
	if menu_settings_open:
		_close_menu_settings()
	elif is_instance_valid(garage) and garage.handle_back():
		return
	elif is_instance_valid(reference_landing) and reference_landing.visible:
		if reference_landing.has_method("handle_back") and reference_landing.handle_back():
			return
		_return_to_world()
	elif is_instance_valid(garage):
		garage._back()
	else:
		_return_to_world()


func _reference_quick_start() -> void:
	if not is_instance_valid(garage):
		return
	var selection: Dictionary = garage.setup.duplicate(true)
	var requested: String = str(reference_landing.current_mode) if is_instance_valid(reference_landing) else "cup"
	selection["mode"] = _known_mode(requested) if requested in MODE_IDS else _known_mode(str(garage.setup.mode))
	_hide_reference_landing()
	_start_selected_race(selection)


func _intro_wanted() -> bool:
	if intro_mode == "off" or reduced_motion:
		return false
	if intro_mode == "force":
		return true
	if bool(SceneRouter.launch_options.get("kartEntryPrepared", false)):
		return false
	# Automatisierte Szenenprüfungen starten mit --script und erwarten das Menü sofort.
	return not OS.get_cmdline_args().has("--script")


func _start_selected_race(setup: Dictionary) -> void:
	setup_snapshot = setup.duplicate(true)
	mode = _known_mode(str(setup.get("mode", "race")))
	selected_driver = str(setup.get("driver", "fox"))
	selected_kart = str(setup.get("kart", "comet"))
	track_id = str(setup.get("track", "sonnenhafen"))
	if not _is_catalog_track(track_id):
		# Unbekannte Strecken wurden früher stillschweigend zu Sonnenhafen.
		push_warning("[Kart] Unbekannte Strecke '%s' – Rennen nicht gestartet" % track_id)
		if is_instance_valid(garage) and is_instance_valid(garage.detail):
			garage.detail.text = "Diese Strecke ist noch nicht startbereit. Bitte wähle eine andere."
		return
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
	_session_handed_off = false
	_track_pass_owner = track_pass.child_key.sha256_text()
	_refresh_kart_factors()
	_reset_action_course()
	loop_state = PHYSICAL_LOOP.new()
	loop_count = 0
	if is_instance_valid(garage):
		garage.queue_free()
	if is_instance_valid(reference_landing):
		reference_landing.queue_free()
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
	save_timer = 0.0
	first_active_snapshot_pending = true
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
	brake_visual_amount = 0.0
	reverse_hold_time = 0.0
	drift_charge = 0
	drift_tier_count = [0, 0, 0]
	wall_contacts = 0
	airborne = false
	air_trick = {}
	vertical_speed = 0
	air_time = 0
	jump_count = 0
	landing_count = 0
	gap_falls = 0
	passage_falls = 0
	passage_hits = 0
	passage_announced.clear()
	passage_creep = ""
	passage_fall_respawn = -1.0
	_passage_last_phase.clear()
	_passage_hit_cooldown = 0.0
	precision_kicker = {}
	precision_launch_lateral = 0.0
	last_precision_landing = ""
	last_precision_flown = 0.0
	precision_results = {}
	wrong_way = false
	wrong_way_seconds = 0
	drifting = false
	shield_time = 0
	item = ""
	_reset_gameplay_layer()
	physical_velocity = Vector3.ZERO
	checkpoint_index = 0
	arena_scores = 0
	reset_count = 0
	offroad_seconds = 0
	open_edge_fall = false
	ghost_valid = true
	best_record = false
	collected.clear()
	opponent_distances = [-4, -7, -10, -13, -16]
	opponent_lanes = [-3.2, -1.65, -0.1, 1.45, 3.0]
	result_id = HostBridge.new_result_id()
	result_payload = {}
	if race_seed >= 0:
		rng.seed = race_seed
		seed(race_seed)
	_build_world()
	if is_instance_valid(kart_audio):
		kart_audio.set_paused(false)
		kart_audio.play_track("arena" if mode == "arena" else track_id)
	message.text = (
		"Stick links lenkt · rechts GAS halten, BREMSE, DRIFT, SPEED, TAKTIK"
		if OS.has_feature("android") or OS.has_feature("ios")
		else "W: Gas · S: Bremse · A/D: lenken · Umschalt: Drift · Leertaste: Boost · E: Taktik"
	)
	_save_preferences()
	_save_session()
	# Showing the race after the garage changes container minimum sizes. The
	# world also changes minimap visibility; resolve both for the actual surface.
	_apply_responsive_layout()
	_apply_responsive_layout.call_deferred()
	# The real Android acceptance test must distinguish the actual 3D race
	# from the visually rich five-step garage. Only emit this marker after
	# _build_world() has completed and the race HUD has been shown.
	if not is_instance_valid(race_root) or not is_instance_valid(player) or not is_instance_valid(camera):
		push_error("[Kart] Failed to assemble the playable 3D race")
	else:
		if is_instance_valid(world) and str(world.track_id) != track_id:
			push_error("[Kart] Gewählte Strecke %s, gebaute Welt %s" % [track_id, world.track_id])
		print("[Kart] race_world_ready: ", track_id, " mode=", mode)


func _resume_saved_race() -> void:
	# _ready already parsed SESSION into session_config. A second disk load can
	# fail while that in-memory copy is still valid (tmp-dir collision, tear
	# during queue_free). Falling through silently left the garage up, so tests
	# saw paused=false and a freshly minted result_id.
	if session_config.load(SESSION) != OK:
		if (
			not saved_session_available
			or int(session_config.get_value("race", "version", 0)) not in SESSION_VERSIONS
		):
			return
	mode = _known_mode(str(session_config.get_value("race", "mode", "race")))
	track_id = str(session_config.get_value("race", "track_id", "sonnenhafen"))
	selected_driver = str(session_config.get_value("race", "selected_driver", "fox"))
	selected_kart = str(session_config.get_value("race", "selected_kart", "comet"))
	_refresh_kart_factors()
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
		# _pause() no-ops when finished, already paused, or menu_active. A
		# restored unfinished race must still report paused so resume identity
		# cannot fall through to a freshly minted _ready result_id check.
		if not finished and not paused:
			paused = true
		if not finished:
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
	drift_button.button_down.connect(_press_drift)
	drift_button.button_up.connect(_release_drift)
	boost_button = _action("SPEED\n◆ 1", _boost, Color("66f7e8"), 112)
	boost_button.name = "BoostAction"
	boost_button.icon_id = "boost"
	item_button = _action("TAKTIK\n◇", _use_item, Color("a7c5ff"), 112)
	item_button.name = "ItemAction"
	item_button.icon_id = "item"
	var layout: Array = [
		[gas_button, Vector2(361, 222), 156],
		[brake_button, Vector2(222, 242), 116],
		[drift_button, Vector2(228, 108), 106],
		[boost_button, Vector2(370, 66), 112],
		[item_button, Vector2(96, 226), 112]
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
	jump_hint = JUMP_HINT.new()
	column.add_child(jump_hint)
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
	# The settled HUD and pedal rectangles determine the available map space.
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	map_panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.065, 0.13, 0.78)))
	map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_ui.add_child(map_panel)
	map = MINIMAP.new()
	map.custom_minimum_size = Vector2(160, 128)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(map)
	for control in [top, message, jump_hint, joystick, pedal_pad]:
		control.item_rect_changed.connect(_queue_minimap_layout)
		control.visibility_changed.connect(_queue_minimap_layout)
	for action in pedal_pad.get_children():
		action.item_rect_changed.connect(_queue_minimap_layout)
		action.visibility_changed.connect(_queue_minimap_layout)
	hud_content.visibility_changed.connect(_queue_minimap_layout)
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
	modal.visibility_changed.connect(_on_modal_visibility_changed)
	modal.draw.connect(_draw_result_plate)
	modal_column = VBoxContainer.new()
	modal_column.add_theme_constant_override("separation", 10)
	# Settings and result buttons pass touch drags to their ScrollContainer.
	# Its scroll-begin notification cancels the Button's pending click.
	modal_column.child_entered_tree.connect(
		func(child: Node):
			if child is Button:
				child.mouse_filter = Control.MOUSE_FILTER_PASS
	)
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
	modal_column.sort_children.connect(modal.queue_redraw)
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
	menu_settings_navigation = HBoxContainer.new()
	menu_settings_navigation.name = "MenuSettingsNavigation"
	var settings_close := _button("Zurück zum Kart-Menü", _close_menu_settings, Color("166580"))
	settings_close.name = "CloseKartSettings"
	settings_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_settings_navigation.add_child(settings_close)
	modal_body.add_child(menu_settings_navigation)
	menu_settings_navigation.hide()
	modal.hide()
	RACE_HUD.dress(self)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	MobileRuntime.safe_area_changed.connect(_on_viewport_size_changed)
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
	# Dim the entire viewport; preserve safe insets for dialog and controls.
	modal_backdrop.offset_left = -scaled.position.x
	modal_backdrop.offset_top = -scaled.position.y
	modal_backdrop.offset_right = scaled.size.x
	modal_backdrop.offset_bottom = scaled.size.y
	safe_ui.set_meta("kart_safe_insets_applied", true)
	call_deferred("_apply_responsive_layout")


func _on_viewport_size_changed() -> void:
	if not is_inside_tree():
		return
	_update_safe_area()
	_apply_responsive_layout()


func _update_safe_area() -> void:
	if not is_inside_tree() or not is_instance_valid(safe_ui):
		return
	safe_ui.visible = MobileRuntime.safe_area_is_ready()
	var insets := Rect2()
	if OS.has_feature("android") or OS.has_feature("ios") or MobileRuntime.requires_safe_area_observation():
		insets = MobileRuntime.get_safe_area_insets()
		# Usable screen bounds alone can omit camera cutouts in immersive mode.
		var screen: Vector2i = DisplayServer.screen_get_size()
		var unobscured: Rect2i = DisplayServer.get_display_safe_area()
		if not MobileRuntime.requires_safe_area_observation() and screen.x > 0 and screen.y > 0 and unobscured.has_area():
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
	var window_size: Vector2 = Vector2(get_window().size) / MobileRuntime.get_ui_density()
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
		var pad_height: float = clampf(display_size.y * 0.29, 176.0, 290.0)
		joystick.custom_minimum_size = Vector2.ONE * stick_size * ui_scale
		pedal_pad.custom_minimum_size = Vector2(pad_width, pad_height) * ui_scale
		controls_row.add_theme_constant_override("separation", roundi(gap * ui_scale))
		controls_gap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		controls_gap.custom_minimum_size = Vector2(gap * ui_scale, 1.0)
		# Thumb cluster on the right: big enough for a child's thumb, clear of the road middle.
		var diameter: float = maxf(48.0, minf(84.0, minf(pad_width * 0.29, pad_height * 0.28)))
		var compact_positions: Dictionary = {
			"DriftAction": Vector2(pad_width * 0.46, pad_height * 0.2),
			"BoostAction": Vector2(pad_width * 0.84, pad_height * 0.2),
			"ItemAction": Vector2(pad_width * 0.46, pad_height * 0.5),
			"BrakePedal": Vector2(pad_width * 0.84, pad_height * 0.5),
			"GasPedal": Vector2(pad_width * 0.65, pad_height * 0.82)
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
		# 300dp-tall cluster. Every action remains at least 48 dp.
		joystick.custom_minimum_size = Vector2.ONE * 96.0 * ui_scale
		pedal_pad.custom_minimum_size = Vector2(180, 100) * ui_scale
		controls_row.add_theme_constant_override("separation", roundi(8.0 * ui_scale))
		controls_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls_gap.custom_minimum_size = Vector2.ZERO
		var short_actions: Dictionary = {
			"DriftAction": [Vector2(84, 24), 48.0],
			"BoostAction": [Vector2(148, 24), 48.0],
			"ItemAction": [Vector2(24, 74), 48.0],
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
		top_button_size = Vector2(92, 48)
	hud.add_theme_font_size_override(
		"font_size", roundi((15.0 if compact_portrait or short_landscape else (18.0 if compact else 23.0)) * ui_scale)
	)
	var modal_width: float = minf(
		620.0 * ui_scale, maxf(1.0, safe_ui.size.x - margin_dp * 2.0 * ui_scale)
	)
	# Hochformat (Fold offen): Pause und Einstellungen ohne abgeschnittene Zeilen.
	var modal_height: float = minf(
		(780.0 if compact_portrait else 560.0) * ui_scale, maxf(1.0, safe_ui.size.y - margin_dp * 2.0 * ui_scale)
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
	if result_view:
		_layout_result(ui_scale, margin_dp, display_size)
	else:
		modal.offset_left = -modal_width * 0.5
		modal.offset_right = modal_width * 0.5
		modal.offset_top = -modal_height * 0.5
		modal.offset_bottom = modal_height * 0.5
	RACE_HUD.relayout(self, ui_scale, short_landscape)
	# A Container can grow its offsets while an old minimum size is being
	# rescaled. Restore the anchored rectangle after all new minimums are set.
	hud_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_queue_minimap_layout()


func _queue_minimap_layout() -> void:
	if _minimap_layout_pending or not is_inside_tree():
		return
	_minimap_layout_pending = true
	_apply_minimap_layout.call_deferred()


func _apply_minimap_layout() -> void:
	_minimap_layout_pending = false
	if not is_inside_tree() or not is_instance_valid(map_panel):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var display_size: Vector2 = Vector2(get_window().size) / MobileRuntime.get_ui_density()
	if minf(viewport_size.x, viewport_size.y) <= 0.0 or minf(display_size.x, display_size.y) <= 0.0:
		map_panel.hide()
		return
	var ui_scale: float = maxf(viewport_size.x / display_size.x, viewport_size.y / display_size.y)
	var compact: bool = display_size.x < 900.0 or display_size.x < display_size.y
	var short_landscape: bool = display_size.x >= display_size.y and safe_ui.size.y / ui_scale < 360.0
	if mode == "arena" or compact or short_landscape or not hud_content.is_visible_in_tree():
		map_panel.hide()
		return
	# Container sorting can finish after _apply_responsive_layout. Observe its
	# final rectangles, including changed instructions and a live jump hint.
	var safe_rect: Rect2 = safe_ui.get_global_rect()
	var gap: float = 6.0 * ui_scale
	var safe_left: float = safe_rect.position.x + maxf(gap, float(hud_content.get_theme_constant("margin_left")))
	var safe_right: float = safe_rect.end.x - maxf(gap, float(hud_content.get_theme_constant("margin_right")))
	var safe_bottom: float = safe_rect.end.y - maxf(gap, float(hud_content.get_theme_constant("margin_bottom")))
	var top_bar: Control = top_pause_button.get_parent()
	var top: float = maxf(safe_rect.position.y + gap, top_bar.get_global_rect().end.y + gap)
	for notice in [message, jump_hint]:
		if notice.is_visible_in_tree():
			top = maxf(top, notice.get_global_rect().end.y + gap)
	var padding: Vector2 = map_panel.get_theme_stylebox("panel").get_minimum_size()
	var preferred_content: Vector2 = Vector2(160.0, 128.0) * ui_scale
	var occupied_rects: Array[Rect2] = []
	var candidate_rights: Array[float] = [safe_right]
	var controls: Array = [top_menu_button, top_reset_button, top_pause_button, joystick]
	controls.append_array(pedal_pad.get_children())
	for control in controls:
		if not control.is_visible_in_tree():
			continue
		var occupied: Rect2 = control.get_global_rect()
		if control.get_parent() == pedal_pad:
			# The production action artwork is 1.12 times the hit rectangle.
			occupied = occupied.grow(maxf(occupied.size.x, occupied.size.y) * 0.06)
		occupied_rects.append(occupied)
		if occupied.end.y + gap > top:
			candidate_rights.append(minf(safe_right, occupied.position.x - gap))
	# Try the right edge first, then only the real control edges. Dense views
	# can use the free space left of SPEED/DRIFT without covering instructions.
	candidate_rights.sort()
	candidate_rights.reverse()
	for right in candidate_rights:
		var left: float = maxf(safe_left, right - preferred_content.x - padding.x)
		var bottom: float = safe_bottom
		for occupied in occupied_rects:
			if occupied.end.y + gap <= top:
				continue
			if occupied.end.x + gap > left and occupied.position.x - gap < right:
				bottom = minf(bottom, occupied.position.y - gap)
		var available: Vector2 = Vector2(right - left, bottom - top) - padding
		var fit: float = minf(1.0, minf(available.x / preferred_content.x, available.y / preferred_content.y))
		# Keep a readable passive overview; never shrink a driving control.
		if fit < 0.5:
			continue
		var content_size: Vector2 = preferred_content * fit
		map.custom_minimum_size = content_size
		map_panel.custom_minimum_size = Vector2.ZERO
		map_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		map_panel.position = Vector2(right - content_size.x - padding.x, top) - safe_rect.position
		map_panel.size = content_size + padding
		map_panel.show()
		return
	map_panel.hide()

## Zieleinlauf-Tafel: quer rechts angedockt (rund 45 % der sicheren Breite),
## hoch und fast quadratisch unten. Der Inhalt ist ein Entwurf von 560 Einheiten
## Breite, der mit der Tafel skaliert. Reicht die Höhe nicht, weicht zuerst die
## Schlusszeile, dann schrumpft der Maßstab; Knöpfe bleiben mindestens 48 dp hoch.
## Passt selbst der kleinste Maßstab nicht (sehr flache Fenster, viele
## Zusatzzeilen), rücken die Aktionen direkt unter die Wertzeilen: Sie bleiben
## ohne Scrollen erreichbar, nur die Zusatzzeilen liegen dann im Scrollbereich.
func _layout_result(ui_scale: float, margin_dp: float, display_size: Vector2) -> void:
	var margin: float = margin_dp * ui_scale
	var area: Vector2 = safe_ui.size
	var landscape: bool = display_size.x >= display_size.y * 1.3
	var panel_width: float = area.x - margin * 2.0
	var available: float = area.y - margin * 2.0
	if landscape:
		panel_width = minf(panel_width, area.x * 0.45)
	else:
		panel_width = minf(panel_width, 660.0 * ui_scale)
		# Über der Tafel bleibt Platz für Lumo im Kart.
		available = minf(available, maxf(area.y * 0.6, 340.0 * ui_scale))
	var factor: float = clampf(panel_width / (RESULT_KIT.DESIGN_WIDTH * ui_scale), 0.42, 2.2)
	var cheer: Control = modal_column.get_node_or_null("ResultCheer")
	if cheer != null:
		cheer.visible = true
	var needed: float = _apply_result_scale(factor * ui_scale, ui_scale, panel_width)
	for stage in range(6):
		if needed <= available:
			break
		if stage == 0 and cheer != null:
			cheer.visible = false
		else:
			factor = maxf(0.42, factor * clampf(available / needed, 0.7, 0.97))
		needed = _apply_result_scale(factor * ui_scale, ui_scale, panel_width)
	if not landscape:
		var fitted_width: float = minf(panel_width, RESULT_KIT.DESIGN_WIDTH * factor * ui_scale * 1.14)
		if fitted_width < panel_width:
			panel_width = fitted_width
			needed = _apply_result_scale(factor * ui_scale, ui_scale, panel_width)
	var height: float = minf(needed, area.y - margin * 2.0)
	_order_result_actions(needed > height)
	if landscape:
		modal.offset_right = area.x * 0.5 - margin
		modal.offset_left = modal.offset_right - panel_width
		modal.offset_top = -height * 0.5
		modal.offset_bottom = height * 0.5
	else:
		modal.offset_left = -panel_width * 0.5
		modal.offset_right = panel_width * 0.5
		modal.offset_bottom = area.y * 0.5 - margin
		modal.offset_top = modal.offset_bottom - height
	# Freie Fläche für das Kart: links neben bzw. über der Tafel.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var origin: Vector2 = safe_ui.global_position
	if landscape:
		var free_right: float = origin.x + area.x * 0.5 + modal.offset_left
		result_free = Vector2(clampf(free_right / viewport_size.x, 0.2, 1.0), 1.0)
		result_focus = Vector2(result_free.x * 0.5, 0.52)
	else:
		var free_bottom: float = origin.y + area.y * 0.5 + modal.offset_top
		result_free = Vector2(1.0, clampf(free_bottom / viewport_size.y, 0.2, 1.0))
		result_focus = Vector2(0.5, result_free.y * 0.57)
	modal.queue_redraw()


## Setzt den Maßstab aller Bausteine und liefert die Höhe, die die Tafel bei
## dieser Breite braucht (Rahmen, Inhalt, Aktionen).
func _apply_result_scale(unit: float, dp: float, panel_width: float) -> float:
	result_scale = unit
	var frame := StyleBoxEmpty.new()
	frame.content_margin_left = 14.0 * unit
	frame.content_margin_right = 14.0 * unit
	frame.content_margin_top = 2.0 * unit
	frame.content_margin_bottom = 14.0 * unit
	modal.add_theme_stylebox_override("panel", frame)
	for side in ["left", "right", "top", "bottom"]:
		modal_padding.add_theme_constant_override("margin_" + side, 0)
	modal_column.add_theme_constant_override("separation", roundi(8.0 * unit))
	var inner: float = maxf(1.0, panel_width - frame.get_minimum_size().x)
	var total: float = frame.get_minimum_size().y
	var rows: int = 0
	for child in modal_column.get_children():
		if not (child is Control) or child.is_queued_for_deletion():
			continue
		var height: float = _scale_result_node(child, unit, dp, inner)
		if child.visible:
			total += height
			rows += 1
	total += float(maxi(0, rows - 1) * modal_column.get_theme_constant("separation"))
	# Ein Pixel Luft, damit Rundungen keinen Scrollbalken erzeugen.
	return ceilf(total) + 2.0


## Normal stehen die Aktionen am Ende der Tafel. Bei Platzmangel (`early`)
## folgen sie direkt auf die Wertzeilen, vor Streckenpass, Bestzeit und Cup-Wertung.
func _order_result_actions(early: bool) -> void:
	var rows: Array[Node] = []
	for row_name in ["ResultMainActions", "ResultMoreActions", "ResultCheer"]:
		if modal_column.has_node(row_name):
			rows.append(modal_column.get_node(row_name))
	var stats: Node = modal_column.get_node_or_null("ResultStats")
	var first: int = modal_column.get_child_count() - rows.size()
	if early and stats != null:
		first = stats.get_index() + 1
	for index in range(rows.size()):
		if rows[index].get_index() != first + index:
			modal_column.move_child(rows[index], first + index)


func _scale_result_node(node: Control, unit: float, dp: float, width: float) -> float:
	if node is BoxContainer and not node.has_method("apply_result_scale"):
		# Aktionszeile: zwei Knöpfe nebeneinander, auf sehr schmalen Tafeln gestapelt.
		node.add_theme_constant_override("separation", roundi(10.0 * unit))
		node.vertical = width < 300.0 * dp
		var tallest: float = 0.0
		var stacked: float = 0.0
		for child in node.get_children():
			child.apply_result_scale(unit, dp)
			tallest = maxf(tallest, child.custom_minimum_size.y)
			stacked += child.custom_minimum_size.y
		if node.vertical:
			return stacked + float(maxi(0, node.get_child_count() - 1) * node.get_theme_constant("separation"))
		return tallest
	if node.has_method("apply_result_scale"):
		node.apply_result_scale(unit, dp)
		return node.result_height(width)
	if node is Label:
		if not node.has_meta("kart_result_font_size"):
			node.set_meta("kart_result_font_size", node.get_theme_font_size("font_size"))
		var font_size: int = RESULT_KIT.font_size(float(node.get_meta("kart_result_font_size")), unit, dp)
		node.add_theme_font_size_override("font_size", font_size)
		return ceilf(node.get_theme_font("font").get_multiline_string_size(
			node.text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size
		).y) + 2.0
	return node.get_combined_minimum_size().y


func _draw_result_plate() -> void:
	if not result_view:
		return
	var top: float = 0.0
	var badge: Control = modal_column.get_node_or_null("ResultTitle")
	if badge != null:
		# Die Zahl ragt über die Tafelkante hinaus, wie in Heinz' Zielbildern.
		top = clampf(
			badge.global_position.y - modal.global_position.y + badge.size.y * 0.5, 0.0, modal.size.y * 0.5
		)
	modal.draw_style_box(
		RESULT_KIT.plate_style(result_scale), Rect2(0, top, modal.size.x, modal.size.y - top)
	)


func _on_modal_visibility_changed() -> void:
	if not modal.visible and result_view:
		_end_result_view()
	modal_backdrop.visible = modal.visible and not result_view


func _end_result_view() -> void:
	result_view = false
	if is_instance_valid(player):
		var animator = player.get("lumo_animation")
		if is_instance_valid(animator):
			animator.clear_attention_target()
	modal.add_theme_stylebox_override("panel", _style(Color("0b1b32"), 24))
	modal_column.add_theme_constant_override("separation", 10)
	modal.queue_redraw()


func _apply_ui_scale(control: Node, ui_scale: float) -> void:
	# These controls own their device-dp layout. In particular, the minimap
	# fits its child minimum to the actual gap between the HUD and pedals.
	# Recursing here would restore a larger cached minimum after a resize.
	if control == garage or control == reference_landing or control == map_panel:
		return
	# Die Ergebnistafel skaliert ihre Bausteine selbst (_apply_result_scale).
	if result_view and control == modal_column:
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


## Per-course contact width; every legacy track keeps its original values.
func _road_width_at(at: float) -> float:
	return world.road_width_at(at) if is_instance_valid(world) else ROAD_WIDTH


func _wall_lateral_at(at: float) -> float:
	return world.wall_lateral_at(at) if is_instance_valid(world) else WORLD.WALL_LATERAL


func _advance_jungle_world(delta: float) -> void:
	if track_id != "jungle_emerald_3600" or not is_instance_valid(world):
		return
	if is_instance_valid(kart_audio):
		kart_audio.update_course_state(
			delta, distance, track_length, distance >= track_length * float(TOTAL_LAPS - 1),
			finished, player.global_position
		)
	var jungle_environment = world.get_node_or_null("DschungelherzEnvironment")
	if jungle_environment != null and jungle_environment.has_method("advance"):
		jungle_environment.advance(delta, player.global_position, not paused, reduced_motion)


func _physics_process(delta: float) -> void:
	if menu_active or not is_instance_valid(player):
		return
	_advance_jungle_world(delta)
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
		brake_visual_amount = braking
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
			_update_gameplay_layer(delta)
			_track_events()
			_update_passages(delta)
			_fade_stale_message(delta)
			TRACK_PIECES.race_tick(self, delta)
			if is_instance_valid(roadside_lasso):
				roadside_lasso.advance(self, delta)
			darkride_event.tick(distance, track_length, delta, reduced_motion)
			_update_checkpoints()
			if mode == "time_trial":
				records.capture(delta, elapsed, player.position, player.rotation, axis, speed)
				_update_ghost()
			if mode != "training" and distance >= track_length * TOTAL_LAPS and checkpoint_index >= TOTAL_LAPS * 8:
				_finish()
		save_timer += delta
		if save_timer >= 5 or (first_active_snapshot_pending and elapsed >= 1.0):
			save_timer = 0
			first_active_snapshot_pending = false
			_save_session()
	if is_instance_valid(world):
		var attraction = world.get_node_or_null("SonnenhafenHarborAttraction")
		if attraction != null:
			attraction.advance(delta, player.position, racing and not paused and not finished, reduced_motion)
		var streetfronts = world.get_node_or_null("SonnenhafenStreetfronts")
		if streetfronts != null:
			streetfronts.advance(delta, player.position, racing and not paused and not finished, reduced_motion)
	for i in range(gems.size()):
		if mode != "arena":
			var key: int = _gem_key(int(distance / track_length), i)
			gems[i].visible = not collected.has(key)
		if gems[i].visible and not paused and not reduced_motion:
			gems[i].rotation.y += delta * 1.7
	if mode != "arena":
		_sync_item_box_visibility()
		for i in range(item_boxes.size()):
			if item_boxes[i].visible:
				RESONANCE.advance_ring(item_boxes[i], elapsed + float(i) * 0.37, reduced_motion)
		for i in range(catalog_boxes.size()):
			if catalog_boxes[i].visible and catalog_boxes[i].has_method("advance_managed"):
				catalog_boxes[i].advance_managed(0.0 if paused else delta, reduced_motion)
	if is_instance_valid(shield_visual):
		shield_visual.reduced_motion = reduced_motion
		shield_visual.advance(0.0 if paused else delta, shield_time)
	_update_item_hud(0.0 if paused else delta)
	if is_instance_valid(pulse_visual):
		if not paused:
			pulse_age += delta
		pulse_visual.visible = pulse_age < 0.65
		pulse_visual.scale = Vector3.ONE * (1.0 + pulse_age * 22.0)
	if is_instance_valid(world) and mode != "arena":
		PASSAGE_ART.update_visuals(world, elapsed)
	_update_vehicles(delta)
	_update_camera(delta)
	_update_hud()
	_update_start_lights(delta)
	# Hook kart_fx: der mehrschichtige Motor (kart_drive_fx) ersetzt den einfachen Sinus.
	var layered_engine: bool = is_instance_valid(drive_fx) and drive_fx.owns_engine_sound()
	if engine_playback and not layered_engine and not muted and host_sound_enabled and racing and not paused and not finished:
		for i in range(engine_playback.get_frames_available()):
			var phase: float = (float(Time.get_ticks_usec()) / 1000000.0 + float(i) / 22050) * (70 + speed * 5)
			var sample: float = sin(phase * TAU) * 0.025 * effects_volume
			engine_playback.push_frame(Vector2(sample, sample))


## Werkstatt des aktuellen Kindes (einmal anlegen; die Sterne kommen aus dem Fortschritt).
func _ensure_workshop():
	if workshop == null:
		var child: String = str(HostBridge.launch_options().get("childKey", "standalone"))
		workshop = TUNING.new(child, ProgressStore.lifetime_stars())
	workshop.report_lifetime(ProgressStore.lifetime_stars())
	return workshop


## Fünf verschiedene Karts für die Gegner: nie das eigene, je Strecke eine andere Mischung.
func _rival_karts() -> Array[String]:
	var pool: Array[String] = []
	for id in FLEET.ids():
		if id != selected_kart:
			pool.append(id)
	var result: Array[String] = []
	var offset: int = absi(hash(track_id)) % pool.size()
	for index in range(5):
		result.append(pool[(offset + index) % pool.size()])
	return result


## Fahrfaktoren des gewählten Karts samt Tuning (Comet ohne Tuning ist überall 1,0).
func _refresh_kart_factors() -> void:
	kart_factors = _ensure_workshop().multipliers(selected_kart)


func _factor(name: String, fallback: float = 1.0) -> float:
	if kart_factors.is_empty():
		_refresh_kart_factors()
	return float(kart_factors.get(name, fallback))


## Boost-Dauer des Karts: ein starker Turbo hält länger.
func _boost_for(seconds: float) -> float:
	return seconds * _factor("boost_time")


func _drive_player(delta: float, axis: float, braking: float) -> void:
	if player_spin_time > 0.0:
		# A friendly spin: steering is muted for a moment, the kart keeps rolling.
		axis *= 0.25
		drifting = false
		drift_charge = 0.0
	if mode != "arena" and not open_edge_fall and _drive_loop(delta, axis, braking):
		return
	var rules: Dictionary = CATALOG.entry(CATALOG.DIFFICULTIES, difficulty)
	if kart_factors.is_empty():
		_refresh_kart_factors()
	var target: float = POWERTRAIN.top_speed(kart_factors, float(rules.speed))
	target *= clampf(float(player.get_meta("roadside_speed_factor", 1.0)), 0.0, 1.0)
	if mode != "arena":
		target *= world.dive_factor(previous_road_distance)
	var manual_gas: bool = _manual_gas_active()
	var throttle: float = 1.0 if auto_gas or manual_gas else 0.0
	if mode == "arena":
		target *= 0.68
		if difficulty == "gemuetlich":
			target *= 1.0 - absf(axis) * 0.24
	var boost_active: bool = boost_time > 0
	if boost_active:
		target *= 1.0 + 0.42 * _factor("boost_power")
	# Explicit gas prevents accidental reverse; passive Auto-Gas must not block it.
	if braking > 0.5 and not airborne and not manual_gas:
		if speed <= 0.9:
			reverse_hold_time += delta
		else:
			reverse_hold_time = 0.0
		# At a LUMO passage a held brake means "wait here", never "roll backwards".
		var hold_still: bool = mode != "arena" and not PASSAGES.zone_at(world, previous_road_distance).is_empty()
		if speed < -0.1 or (reverse_hold_time >= REVERSE_ENGAGE_SECONDS and not hold_still):
			target = -REVERSE_SPEED
		else:
			target = 0.0
	else:
		reverse_hold_time = 0.0
		target *= throttle
		target *= 1.0 - braking * 0.94
		target = _passage_creep_target(target, manual_gas)
	if hit_timer > 0:
		target *= _factor("stability", 0.45)
	if target > 0.0:
		target *= _gameplay_speed_factor()
	var road: Dictionary = {}
	if mode != "arena":
		road = world.sample_road(player.position, previous_road_distance)
		lane = float(road.lateral)
		if absf(lane) > _road_width_at(float(road.distance)) * 0.48:
			target *= _factor("offroad", 0.54)
		# Beginner assistance nudges the steering at the shoulder; movement stays physical.
		if difficulty == "gemuetlich" and absf(lane) > _road_width_at(float(road.distance)) * 0.31:
			var correction: float = angle_difference(player_heading, _heading(float(road.distance)))
			axis = clampf(axis - correction * 0.5 - signf(lane) * 0.30, -1.0, 1.0)
		axis = _passage_steer_assist(axis, road)
	var acceleration: float = POWERTRAIN.acceleration(kart_factors, braking > 0.1)
	if boost_active and target > speed:
		acceleration *= BOOST_ACCELERATION_MULTIPLIER
	if not airborne or boost_active:
		speed = move_toward(speed, target, delta * acceleration)
	var grip_turn: float = clampf(absf(speed) / (8.0 * POWERTRAIN.PACE_SCALE), 0, 1)
	var turn_rate: float = (1.42 + (0.35 if drifting else 0.0)) * _factor("turn") * grip_turn * POWERTRAIN.PACE_SCALE
	if speed < 0.0:
		turn_rate = -turn_rate
	if airborne:
		turn_rate *= 0.35
	if landing_settle > 0.0:
		turn_rate *= lerpf(1.0, 0.62, clampf(landing_settle / 0.32, 0.0, 1.0))
		landing_settle = maxf(0.0, landing_settle - delta)
	player_heading -= axis * turn_rate * delta
	var forward := Vector3(-sin(player_heading), 0, -cos(player_heading))
	var grip: float = (3.1 if drifting else 9.0 * _factor("grip")) * POWERTRAIN.PACE_SCALE
	physical_velocity = physical_velocity.lerp(forward * speed, minf(1, delta * grip))
	# Child-friendly precision flight: velocity-only boundary, measured from
	# the SAME curving road frame as the game's lane value. The lip frame alone
	# cannot constrain a long curved flight (it drifted 2.98 m in CI).
	# Clip the next *velocity* before integration, never teleport the player
	# or alter vertical ballistics / the landing rescue.
	if airborne and not precision_kicker.is_empty():
		var next_position: Vector3 = player.position + physical_velocity * delta
		var next_road: Dictionary = world.sample_road(next_position, previous_road_distance)
		var moved_sideways: float = float(next_road.lateral) - precision_launch_lateral
		var excess: float = moved_sideways - clampf(
			moved_sideways, -PRECISION_AIR_LATERAL_M, PRECISION_AIR_LATERAL_M
		)
		if absf(excess) > 0.0001:
			var side: Vector3 = (next_road.basis as Basis).x
			physical_velocity -= side * (excess / maxf(delta, 0.0001))
	var before_horizontal: Vector3 = player.position
	player.position += physical_velocity * delta
	_constrain_tunnel_motion(before_horizontal)
	if drifting and speed > 6 and not airborne:
		drift_charge = minf(3, drift_charge + delta * absf(axis) * POWERTRAIN.PACE_SCALE)
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
	if not open_edge_fall and absf(lane) > _wall_lateral_at(float(road.distance)) and world.open_edge_side(float(road.distance)) != signf(lane) and not PASSAGES.void_at(world, float(road.distance)):
		_collide_with_rail(road)
		road = world.sample_road(player.position, previous_road_distance)
		lane = float(road.lateral)
	_update_wrong_way(road, delta)
	_update_action_course(road)
	var road_distance: float = float(road.distance)
	var travel: float = fposmod(road_distance - previous_road_distance + track_length * 0.5, track_length) - track_length * 0.5
	# An einer offenen Kante gibt es neben der Fahrbahn keinen Boden: dort beginnt der Sturz sofort.
	var edge_margin: float = 0.3 if mode != "arena" and world.open_edge_side(road_distance) == signf(lane) else 2.0
	var passage_void: bool = mode != "arena" and PASSAGES.void_at(world, road_distance)
	if passage_void:
		edge_margin = PASSAGES.DECK_FALL_MARGIN
	if not open_edge_fall and absf(lane) < _road_width_at(road_distance) * 0.5 + edge_margin:
		var before_vertical: Vector3 = player.position
		if not _move_vertically(road, road_distance, delta):
			return
		_constrain_tunnel_motion(before_vertical)
		offroad_seconds = 0
		if absf(travel) <= maxf(3.0, speed * delta * 2.5):
			distance = maxf(0.0, distance + travel)
	else:
		# A fast kart can pass the end of an open section before its fall timer
		# expires. Once over the void, the next rail must not lift it onto road.
		if world.open_edge_side(road_distance) != 0.0 and world.open_edge_side(road_distance) == signf(lane):
			open_edge_fall = true
		if passage_void:
			if not open_edge_fall or passage_fall_respawn < 0.0:
				passage_fall_respawn = PASSAGES.respawn_for(world, road_distance)
			open_edge_fall = true
		if passage_fall_respawn >= 0.0:
			# Into the gap, not over it: the kart loses its forward run while it drops.
			physical_velocity = physical_velocity.lerp(Vector3.ZERO, minf(1.0, delta * 2.5))
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
		pitch = world.ramp_pitch(road_distance)
	else:
		pitch = world.alternate_route_pitch(road_distance, lane)
	if pitch != 0.0:
		player.basis = player.basis.rotated(right, pitch).orthonormalized()
	if airborne and not air_trick.is_empty() and not reduced_motion:
		player.basis = (
			player.basis * Basis.from_euler(AIR_TRICK.visual_euler(air_trick))
		).orthonormalized()


## Collection key of a course star. The 24 classic stars keep their saved keys;
## extra stunt stars use their own range so laps never collide.
static func _gem_key(lap: int, index: int) -> int:
	if index < 24:
		return lap * 24 + index
	return 1000000 + lap * 256 + index


func _drive_loop(delta: float, axis: float, braking: float) -> bool:
	if not is_instance_valid(world) or world.loop_layout.is_empty():
		loop_state.active = false
		return false
	var layout: Dictionary = world.loop_layout
	if not loop_state.active:
		var road: Dictionary = world.sample_road(player.position, previous_road_distance)
		var entry_offset: float = float(road.distance) - float(layout.start)
		var window: float = float(layout.get("entry_window", 1.0))
		var lane_tolerance: float = float(layout.get("lane_tolerance", 0.9))
		var min_speed: float = float(layout.get("min_entry_speed", 16.0))
		var off_lane: bool = absf(float(road.lateral) - float(layout.lane)) > lane_tolerance
		var too_slow: bool = speed < min_speed or physical_velocity.dot(road.forward) < 8
		# Enter only after reaching the lip. The old symmetric window pulled the
		# kart forward before entry and discarded its lateral position.
		if entry_offset < 0.0 or entry_offset > maxf(window, speed * delta + 0.2) or off_lane or too_slow or airborne:
			return false
		loop_state.enter(layout, speed, distance - entry_offset, float(road.lateral) - float(layout.lane), entry_offset)
		airborne = false
		message.text = "Loop! Halte deinen Schwung."
	player.transform = loop_state.advance(world, delta, axis, braking, _gas_active())
	speed = loop_state.speed
	if loop_state.active:
		previous_road_distance = float(layout.start) + loop_state.progress * PHYSICAL_LOOP.ADVANCE
		distance = maxf(distance, loop_state.entry_progress + loop_state.progress * PHYSICAL_LOOP.ADVANCE)
		lane = (
			float(layout.lane)
			+ PHYSICAL_LOOP.exit_shift_of(layout) * PHYSICAL_LOOP.shift_fraction(loop_state.progress)
			+ loop_state.lateral
		)
		physical_velocity = -player.basis.z * speed
		return true
	var exit_distance: float = float(layout.start) + (0 if loop_state.failed else PHYSICAL_LOOP.ADVANCE)
	distance = loop_state.entry_progress + (0 if loop_state.failed else PHYSICAL_LOOP.ADVANCE)
	previous_road_distance = exit_distance
	player_heading = _heading(exit_distance)
	var exit_lane: float = float(layout.get("fail_lane", layout.lane)) if loop_state.failed else PHYSICAL_LOOP.exit_lane(layout) + loop_state.lateral
	player.transform = world.reset_transform(exit_distance, exit_lane)
	lane = exit_lane
	if loop_state.failed:
		speed = 8
		ghost_valid = false
		message.text = "Wieder sicher auf der Straße. Mit mehr Schwung klappt der Loop!"
	else:
		loop_count += 1
		boost_time = maxf(boost_time, _boost_for(1.5))
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
			air_trick = {}
			jump_count += 1
			air_time = 0.0
			current_jump_gravity = JUMP_GRAVITY
			vertical_speed = minf(
				speed * sin(float(jump.angle)) * float(jump.get("lift_scale", 1.0)),
				float(jump.get("max_lift", JUMP_MAX_LIFT))
			)
			message.text = "Sprung!"
	if not airborne and world.in_gap(road_distance):
		# Rolled or reversed into a gap without take-off: there is no road here.
		airborne = true
		air_trick = {}
		current_jump_gravity = JUMP_GRAVITY
		vertical_speed = 0.0
		air_time = 0.0
	if not airborne:
		var kicker: Dictionary = ACTION.kicker_crossed(
			world.action, fposmod(previous_road_distance, track_length), fposmod(road_distance, track_length)
		)
		if not kicker.is_empty() and speed > 6.0:
			# Sprungschanze: abheben, kurz fliegen und mit Turbo landen.
			airborne = true
			air_trick = {}
			action_kicker_jumps += 1
			air_time = 0.0
			player.position.y = ground + float(kicker.height)
			current_jump_gravity = float(kicker.get("flight_gravity", JUMP_GRAVITY))
			if bool(kicker.get("precision_jump", false)):
				# Same numbers as the speed hint; nothing is corrected in flight.
				precision_kicker = kicker
				precision_launch_lateral = lane
				vertical_speed = PRECISION.launch_vertical(speed, kicker)
				message.text = "Sprung! Ziel: die grüne Landezone."
				return true
			var lift: float = speed * sin(float(kicker.angle)) + float(kicker.get("lift_bonus", 1.6))
			vertical_speed = minf(lift, float(kicker.get("max_lift", JUMP_MAX_LIFT)))
			message.text = "Panorama-Flug!" if bool(kicker.get("hero_flight", false)) else "Schanze!"
			return true
	if not airborne:
		player.position.y = ground
		return true
	vertical_speed -= current_jump_gravity * delta
	player.position.y += vertical_speed * delta
	air_time += delta
	_update_air_trick(delta)
	if world.in_gap(road_distance):
		if player.position.y < float(road.height) - 2.5:
			_record_precision_landing(PRECISION.LANDING_SHORT, road_distance)
			_rescue_from_gap()
			return false
	elif not precision_kicker.is_empty() and player.position.y < ground - 0.5:
		# Too short: the kart meets the far edge of the gap below the road.
		# It is not lifted onto the road; it falls and the cloud takes over.
		_record_precision_landing(PRECISION.LANDING_SHORT, road_distance)
		_rescue_from_gap()
		return false
	elif player.position.y <= ground:
		var impact: float = maxf(0.0, -vertical_speed)
		player.position.y = ground
		airborne = false
		current_jump_gravity = JUMP_GRAVITY
		landing_count += 1
		var precision_result: String = ""
		if not precision_kicker.is_empty():
			var flown: float = fposmod(road_distance - float(precision_kicker.take_off), track_length)
			precision_result = PRECISION.classify_landing(flown, precision_kicker)
			_record_precision_landing(precision_result, road_distance)
		if precision_result == PRECISION.LANDING_LONG:
			# Overshot the zone: a hard landing costs speed and gives no turbo.
			speed *= 0.6
			physical_velocity *= 0.6
			message.text = "Zu weit geflogen! Nächstes Mal etwas bremsen."
			_sound_effect("collision")
		elif precision_result == PRECISION.LANDING_ZONE:
			boost_time = maxf(boost_time, _boost_for(1.2))
			message.text = "Perfekt in der Landezone! Turbo!"
			_sound_effect("drift")
		elif air_time > 0.35:
			boost_time = maxf(boost_time, _boost_for(1.2))
			message.text = "Super gelandet! Turbo!"
			_sound_effect("drift")
		var trick_reward: Dictionary = AIR_TRICK.landing_bonus(air_trick, precision_result)
		if bool(trick_reward.get("rewarded", false)):
			boost_time += _boost_for(float(trick_reward.boost))
			message.text = str(trick_reward.label)
			_sound_effect("boost")
			_stat("tricks")
			_award_boost("trick_landing", 0.0, "")
		if is_instance_valid(drive_feedback):
			drive_feedback.landed(
				impact,
				precision_result == PRECISION.LANDING_ZONE
				or (precision_result != PRECISION.LANDING_LONG and air_time > 0.35),
				race_root.global_basis * (road.basis as Basis)
			)
		# Hook kart_fx: Staubring, Funken und Federstoß bei der echten Landung.
		if is_instance_valid(drive_fx):
			drive_fx.landed(impact, race_root.global_basis * (road.basis as Basis))
		air_trick = {}
		# Settle sideways slide after a firm landing. Precision zone/long
		# outcomes already apply their own speed rules and stay untouched.
		if (
			impact > 4.5
			and precision_result != PRECISION.LANDING_ZONE
			and precision_result != PRECISION.LANDING_LONG
		):
			landing_settle = maxf(landing_settle, clampf((impact - 4.5) * 0.05, 0.10, 0.32))
			var along := Vector3(-sin(player_heading), 0, -cos(player_heading))
			var sideways: Vector3 = physical_velocity - along * physical_velocity.dot(along)
			physical_velocity -= sideways * 0.42
		air_time = 0.0
		vertical_speed = 0.0
	return true


## The race integrates position itself; imported tunnel bodies therefore need
## the same swept collision query for horizontal movement and ballistic lift.
func _constrain_tunnel_motion(previous_position: Vector3) -> void:
	if mode == "arena" or not is_instance_valid(world):
		return
	var contact: Dictionary = world.resolve_tunnel_motion(previous_position, player.position)
	player.position = contact.position
	if not bool(contact.collided):
		return
	var normal: Vector3 = contact.normal
	physical_velocity = physical_velocity.slide(normal)
	if vertical_speed > 0.0 and normal.y < -0.25:
		vertical_speed = 0.0


func _record_precision_landing(result: String, road_distance: float) -> void:
	if precision_kicker.is_empty():
		return
	last_precision_landing = result
	last_precision_flown = fposmod(road_distance - float(precision_kicker.take_off), track_length)
	precision_results[result] = int(precision_results.get(result, 0)) + 1
	precision_kicker = {}


func _reset_action_course() -> void:
	action_pads_used.clear()
	action_gates_hit = 0
	action_gates_passed = 0
	action_slaloms_cleared = 0
	action_pads_triggered = 0
	action_kicker_jumps = 0
	action_edge_falls = 0
	action_in_dive = false
	_update_dive_tint()


## Turbo-Felder, Slalom-Tore und Tauchstrecke des Action-Parcours (Schanze: _move_vertically).
func _update_action_course(road: Dictionary) -> void:
	var course: Dictionary = world.action
	if course.is_empty():
		return
	var current: float = float(road.distance)
	var lap: int = int(distance / maxf(track_length, 1.0))
	var pad: int = ACTION.pad_at(course, current, lane)
	if pad >= 0 and not airborne:
		var key: String = "%d:%d" % [lap, pad]
		if not action_pads_used.has(key):
			action_pads_used[key] = true
			action_pads_triggered += 1
			boost_time = maxf(boost_time, _boost_for(ACTION.PAD_BOOST_SECONDS))
			message.text = "Turbo-Feld!"
			_sound_effect("boost")
	for gate in ACTION.gates_crossed(course, previous_road_distance, current):
		if int(gate.index) == 0:
			action_gates_passed = 0
		var hit: bool = false
		for pylon in ACTION.pylon_laterals(gate):
			if absf(lane - pylon) < ACTION.PYLON_RADIUS + 0.35:
				hit = true
		if hit:
			action_gates_hit += 1
			speed *= 0.86
			message.text = "Hütchen erwischt!"
			_sound_effect("collision")
		elif absf(lane - float(gate.lateral)) < ACTION.GATE_HALF_WIDTH:
			action_gates_passed += 1
		if int(gate.index) == ACTION.GATE_COUNT - 1:
			if action_gates_passed == ACTION.GATE_COUNT:
				action_slaloms_cleared += 1
				boost_time = maxf(boost_time, _boost_for(ACTION.SLALOM_BOOST_SECONDS))
				message.text = "Slalom perfekt! Turbo!"
				_sound_effect("boost")
			else:
				message.text = "Slalom: %d von %d Toren" % [action_gates_passed, ACTION.GATE_COUNT]
	var diving: bool = ACTION.dive_at(course, current)
	if diving != action_in_dive:
		action_in_dive = diving
		if diving:
			message.text = "Abgetaucht! Durch den Unterwasser-Tunnel."
		_update_dive_tint()


## Leicht blaues Bild, solange das Kart durch den Unterwasser-Tunnel fährt.
func _update_dive_tint() -> void:
	if not is_instance_valid(safe_ui):
		return
	if not is_instance_valid(dive_tint):
		if not action_in_dive:
			return
		dive_tint = ColorRect.new()
		dive_tint.name = "DiveTint"
		dive_tint.color = Color(0.06, 0.38, 0.72, 0.16)
		dive_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dive_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var layer: Node = safe_ui.get_parent()
		layer.add_child(dive_tint)
		layer.move_child(dive_tint, 0)
	dive_tint.visible = action_in_dive


func _update_air_trick(delta: float) -> void:
	if not airborne:
		return
	if air_trick.is_empty() and drifting and air_time > 0.05:
		air_trick = AIR_TRICK.start(steering)
		if not reduced_motion:
			message.text = "Rolle!" if str(air_trick.get("kind", "")) == AIR_TRICK.KIND_ROLL else "Salto!"
	if not air_trick.is_empty():
		air_trick = AIR_TRICK.advance(air_trick, delta)


func _rescue_from_gap() -> void:
	# A cloud carries the kart just past the gap: no repeated falls, no shortcut.
	var precision: bool = world.jump.is_empty() and last_precision_landing == PRECISION.LANDING_SHORT
	var target: float = world.gap_exit_distance(previous_road_distance)
	distance += fposmod(target - previous_road_distance, track_length)
	previous_road_distance = target
	player.transform = world.reset_transform(target)
	player_heading = _heading(target)
	speed = 8.0
	physical_velocity = Vector3(-sin(player_heading), 0, -cos(player_heading)) * speed
	airborne = false
	air_trick = {}
	vertical_speed = 0.0
	air_time = 0.0
	gap_falls += 1
	reset_count += 1
	# Schonzeit nach dem Rücksetzer: keine Treffer gleich nach dem Neustart.
	player_grace_time = maxf(player_grace_time, float(_lock_rules().grace))
	ghost_valid = false
	message.text = (
		"Zu kurz! Eine Wolke trägt dich rüber. Nächstes Mal mehr Gas!" if precision
		else "Eine Wolke trägt dich weiter. Mehr Schwung beim nächsten Sprung!"
	)


## Who stopped on a bridge plaza is rolled over gently by Auto-Gas (creep speed) until
## the deck ends. Gas held by hand or a boost overrides it; a flying start is untouched.
func _passage_creep_target(target: float, manual_gas: bool) -> float:
	if mode == "arena" or not is_instance_valid(world):
		return target
	var entry: Dictionary = PASSAGES.zone_at(world, previous_road_distance)
	if entry.is_empty() or str(entry.kind) != "bridge":
		passage_creep = ""
		return target
	var local: float = fposmod(previous_road_distance, track_length)
	if local > float(entry.deck_end):
		passage_creep = ""
		return target
	if absf(speed) < 1.0 and local < float(entry.deck_start):
		passage_creep = str(entry.id)
	if passage_creep == str(entry.id) and not manual_gas and boost_time <= 0.0:
		return minf(target, PASSAGES.CREEP_SPEED)
	return target


## Entdecken (Fahrhilfe): on the plaza run-up and on the deck the steering is gently
## pulled onto the centre line. The child still steers; the help never drives alone.
func _passage_steer_assist(axis: float, road: Dictionary) -> float:
	if difficulty != "gemuetlich" or airborne or not is_instance_valid(world):
		return axis
	var d: float = float(road.distance)
	var local: float = fposmod(d, track_length)
	# Die Hilfe beginnt rund 1,7 s vor dem Deck (bei vollem Tempo gut 80 m): Wer weit
	# außen anfährt, wird rechtzeitig zur Mitte geführt statt erst am Rand der Brücke.
	var reach: float = maxf(26.0, absf(speed) * 1.7)
	var entry: Dictionary = {}
	for candidate in PASSAGES.of(world):
		if str(candidate.kind) != "bridge":
			continue
		if local <= float(candidate.deck_end) and float(candidate.deck_start) - local <= reach:
			entry = candidate
			break
	if entry.is_empty():
		return axis
	var correction: float = angle_difference(player_heading, _heading(d + 4.0))
	if absf(lane) < 0.15 and absf(correction) < 0.03:
		return axis
	return clampf(axis - correction * 0.9 - clampf(lane * 0.55, -0.6, 0.6), -1.0, 1.0)


## Hinweise bleiben nicht über Runden stehen: Nach MESSAGE_SECONDS blendet die Zeile
## aus, bis ein neuer Text kommt (Gerätefund 19.11.: Rettungstext stand dauerhaft im Bild).
func _fade_stale_message(delta: float) -> void:
	if message.text != _message_seen:
		_message_seen = message.text
		_message_age = 0.0
		message.modulate.a = 1.0
		return
	_message_age += delta
	if _message_age > MESSAGE_SECONDS:
		message.modulate.a = move_toward(message.modulate.a, 0.0, delta * 2.0)


## Announcements, Kiri's call and the swing hit. Rivals get the same rules.
func _update_passages(delta: float) -> void:
	_passage_hit_cooldown = maxf(0.0, _passage_hit_cooldown - delta)
	var local: float = fposmod(previous_road_distance, track_length)
	var lap: int = int(distance / maxf(track_length, 1.0))
	for entry in PASSAGES.of(world):
		var key: String = "%s:%d" % [str(entry.id), lap]
		var before: float = float(entry.zone_start) - local
		var announce_at: float = maxf(70.0, absf(speed) * PASSAGES.ANNOUNCE_SECONDS)
		if before > 0.0 and before < announce_at and not passage_announced.has(key):
			passage_announced[key] = true
			message.text = str(entry.approach_text)
		if str(entry.kind) not in ["swing", "gate"]:
			continue
		var state: Dictionary = PASSAGES.swing_state(entry, elapsed)
		var phase: String = str(state.phase)
		if phase == "warn" and str(_passage_last_phase.get(entry.id, "")) != "warn":
			if absf(float(entry.plane) - local) < 160.0:
				_sound_effect(str(entry.get("cue", "monkey_call")))
				if before < 0.0 and local < float(entry.plane):
					message.text = str(entry.get("warn_text", "Uh-uh-AAH! Kiri holt Schwung. Kurz warten!"))
		if phase == "open" and str(_passage_last_phase.get(entry.id, "")) == "swing":
			# The waiting child learns that green means "go" (the old warning stayed on screen).
			if before < 0.0 and local < float(entry.plane):
				message.text = str(entry.get("go_text", "Grün! Jetzt vorbei."))
		_passage_last_phase[entry.id] = phase
		if (
			PASSAGES.blocker_hits(world, entry, previous_road_distance, lane, elapsed, absf(speed))
			and _passage_hit_cooldown <= 0.0 and shield_time <= 0.0 and not open_edge_fall
		):
			_passage_hit_cooldown = 1.6
			passage_hits += 1
			if str(entry.get("effect", "bump")) == "reset":
				# Into the lava pulse: the Lumo cloud lifts the kart back before the stream.
				passage_fall_respawn = float(entry.respawn)
				open_edge_fall = true
				message.text = str(entry.get("hit_text", "Zu heiß! Die Lumo-Wolke holt dich zurück."))
			else:
				_spin_player(0.6)
				speed = minf(speed, 3.0)
				physical_velocity = physical_velocity.limit_length(3.0)
				message.text = str(entry.get("hit_text", "Kiri hat dich angestupst! Bei Rot kurz warten."))
			_sound_effect("collision")
		for i in range(opponents.size()):
			var rival_lane: float = opponent_lanes[i] if i < opponent_lanes.size() else 0.0
			if PASSAGES.blocker_hits(
				world, entry, opponent_distances[i], rival_lane, elapsed, absf(opponents[i].motion_speed)
			):
				opponent_stuns[i] = maxf(opponent_stuns[i], 0.8)


func _manual_gas_active() -> bool:
	return gas_held or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)


func _gas_active() -> bool:
	return auto_gas or _manual_gas_active()


func _collide_with_rail(road: Dictionary) -> void:
	# The rail is a wall: stay on its inner face and slide along it.
	var road_basis: Basis = road.basis
	var side: float = signf(lane)
	player.position -= road_basis.x * (lane - side * _wall_lateral_at(float(road.distance)))
	var into_wall: float = physical_velocity.dot(road_basis.x) * side
	if into_wall <= 0.0:
		return
	wall_contacts += 1
	# Hook kart_fx: Funken, Schleifspur, Kratzgeräusch und Stoß am echten Berührungspunkt.
	if is_instance_valid(drive_fx):
		drive_fx.rail_contact(player, race_root.global_basis * (road_basis.x * side), into_wall, speed)
	# Slide along the curb instead of bouncing off it and spinning out.
	physical_velocity -= road_basis.x * side * into_wall * 1.08
	speed *= clampf(1.0 - into_wall * 0.022, 0.80, 0.99)
	var along: float = _heading(float(road.distance))
	if absf(angle_difference(player_heading, along)) > PI / 2:
		along += PI
	player_heading = lerp_angle(player_heading, along, minf(1.0, 0.38 + into_wall * 0.05))
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
	fx.set_stunned(maxf(
		opponent_stuns[index] if index < opponent_stuns.size() else 0.0,
		opponent_spin_times[index] if index < opponent_spin_times.size() else 0.0
	))


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
			# The same telegraphed pulse hits every nearby unshielded racer,
			# not a coordinated AI-only attack against the child.
			for other in range(opponents.size()):
				if other == index or opponent_shield_times[other] > 0.0:
					continue
				if opponents[index].position.distance_to(opponents[other].position) <= RIVAL_PULSE_RADIUS:
					opponent_stuns[other] = maxf(opponent_stuns[other], 0.38)
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
			if (
				absf(offset) < 1.4
				and absf(opponents[index].motion_speed) >= RESONANCE.MIN_PICKUP_SPEED
				and opponents[index].position.distance_to(
					item_boxes[item_box_distances.find(box_distance)].position
				) < 2.65
			):
				var rival_road: Dictionary = world.sample_road(
					opponents[index].position, local_distance
				)
				var rival_score: Dictionary = RESONANCE.award(
					absf(opponents[index].motion_speed), RIVAL_RACECRAFT.cruise_speed(
						opponents[index].kart_style, CATALOG.entry(CATALOG.DIFFICULTIES, difficulty)
					),
					float(rival_road.lateral) - item_box_laterals[item_box_distances.find(box_distance)],
					float(opponents[index].get_meta("racecraft_drift_charge", 0.0)),
					opponent_stuns[index] > 0.0
				)
				opponent_items[index] = str(rival_score.item)
				opponent_item_cooldowns[index] = 1.8
				break

	if opponent_items[index].is_empty() and opponent_item_cooldowns[index] <= 0.0:
		_rival_collect_catalog_box(index)
	if opponent_items[index].is_empty():
		_sync_rival_item_fx(index)
		return

	match opponent_items[index]:
		"boost":
			if _rival_can_boost(index):
				opponent_boost_times[index] = 2.2
				opponent_items[index] = ""
		"pulse":
			if _rival_target_near(index, RIVAL_PULSE_RADIUS + 1.5):
				opponent_pulse_warning_times[index] = RIVAL_PULSE_WARNING_SECONDS
				opponent_items[index] = ""
				if local_gap.length() < 30.0:
					message.text = "Rivale lädt Lichtimpuls – Abstand oder Schild!"
					_sound_effect("item")
		"shield":
			if _rival_target_near(index, 7.0) or _rival_threatened(index):
				opponent_shield_times[index] = 5.0
				opponent_items[index] = ""
		_:
			_rival_use_catalog_item(index, local_gap)
	_sync_rival_item_fx(index)


func _rival_target_near(index: int, radius: float) -> bool:
	var origin: Vector3 = opponents[index].position
	if origin.distance_to(player.position) < radius:
		return true
	for other in range(opponents.size()):
		if other == index:
			continue
		if origin.distance_to(opponents[other].position) < radius:
			return true
	return false


func _update_rival_drift(index: int, road: Dictionary, pace: float, delta: float) -> bool:
	var rival: LumoRaceKart = opponents[index]
	var charge: float = float(rival.get_meta("racecraft_drift_charge", 0.0))
	var at: float = float(road.distance)
	var now_forward: Vector3 = world.forward(at)
	var next_forward: Vector3 = world.forward(at + 3.0)
	var turn_rate: float = absf(angle_difference(
		atan2(now_forward.x, now_forward.z), atan2(next_forward.x, next_forward.z)
	)) * pace / 3.0
	var aligned: bool = absf(angle_difference(opponent_headings[index], _heading(at))) < 0.30
	var controlled: bool = aligned and absf(float(road.lateral)) < 4.0 and opponent_stuns[index] <= 0.0
	var drifting_now: bool = difficulty != "gemuetlich" and controlled and pace >= 10.0 and turn_rate > 0.09
	if drifting_now:
		charge = minf(2.2, charge + delta * POWERTRAIN.PACE_SCALE * clampf(turn_rate * 3.2, 0.0, 1.0))
	else:
		# Same time tiers as the player's held drift. Charge is earned only by
		# a sustained controlled turn, and a collision cancels it completely.
		if controlled and pace >= 8.0 and charge >= DRIFT_TIERS[0] and _rival_can_boost(index):
			var tier: int = 1 if charge >= DRIFT_TIERS[1] else 0
			opponent_boost_times[index] = maxf(opponent_boost_times[index], DRIFT_BOOST_SECONDS[tier])
		charge = 0.0
	rival.set_meta("racecraft_drift_charge", charge)
	return drifting_now


func _rival_traffic(index: int, road: Dictionary) -> PackedVector3Array:
	var traffic := PackedVector3Array()
	var origin: Vector3 = opponents[index].position
	var basis: Basis = road.basis
	for other in range(opponents.size()):
		if other == index:
			continue
		var gap: Vector3 = opponents[other].position - origin
		if gap.length_squared() < 10000.0 and absf(gap.dot(basis.y)) < 3.0:
			traffic.append(Vector3(gap.dot(-basis.z), float(road.lateral) + gap.dot(basis.x), absf(opponents[other].motion_speed)))
	var player_gap: Vector3 = player.position - origin
	_traffic_player_entry = -1
	if player_gap.length_squared() < 10000.0 and absf(player_gap.dot(basis.y)) < 3.0:
		_traffic_player_entry = traffic.size()
		traffic.append(Vector3(player_gap.dot(-basis.z), float(road.lateral) + player_gap.dot(basis.x), maxf(0.0, speed)))
	_traffic_kart_entries = traffic.size()
	for obstacle in world.action_obstacles:
		var gap: Vector3 = obstacle - origin
		if gap.length_squared() < 10000.0 and absf(gap.dot(basis.y)) < 3.0:
			traffic.append(Vector3(gap.dot(-basis.z), float(road.lateral) + gap.dot(basis.x), 0.0))
	return traffic


func _rival_can_boost(index: int) -> bool:
	var road: Dictionary = world.sample_road(opponents[index].position, fposmod(opponent_distances[index], track_length))
	var road_distance: float = float(road.distance)
	var rules: Dictionary = CATALOG.entry(CATALOG.DIFFICULTIES, difficulty)
	var cruise: float = RIVAL_RACECRAFT.cruise_speed(opponents[index].kart_style, rules)
	var precision_ahead: bool = false
	for kicker in world.action.get("kickers", []):
		if bool(kicker.get("precision_jump", false)):
			var remaining: float = float(kicker.take_off) - road_distance
			if remaining >= -5.0 and remaining < cruise * 3.2:
				precision_ahead = true
	var heading_error: float = angle_difference(opponent_headings[index], _heading(road_distance + 10.0))
	return RIVAL_RACECRAFT.may_boost(
		RIVAL_RACECRAFT.curvature(world, road_distance), heading_error,
		float(road.lateral), _rival_traffic(index, road), cruise,
		precision_ahead, opponent_stuns[index] > 0.0
	)


func _rival_profile() -> Dictionary:
	# Entdecken / Abenteuer / Extrem. Speed still comes only from the
	# catalog multipliers — never from the gap to the player.
	match difficulty:
		"gemuetlich":
			return {
				"look_ahead": 6.5,
				"turn_rate": 1.08 * POWERTRAIN.PACE_SCALE,
				"wobble": 1.15,
				"wobble_hz": 0.55,
				"mistake": 0.85,
				"mistake_hz": 0.31,
				"overtake": 11.0,
				"lane_spread": 1.15,
			}
		"pro":
			return {
				"look_ahead": 18.0,
				"turn_rate": 2.45 * POWERTRAIN.PACE_SCALE,
				"wobble": 0.025,
				"wobble_hz": 2.1,
				"mistake": 0.0,
				"mistake_hz": 1.0,
				"overtake": 36.0,
				"lane_spread": 1.55,
			}
		_:
			return {
				"look_ahead": 10.0,
				"turn_rate": 1.55 * POWERTRAIN.PACE_SCALE,
				"wobble": 0.32,
				"wobble_hz": 0.35,
				"mistake": 0.22,
				"mistake_hz": 0.62,
				"overtake": 20.0,
				"lane_spread": 1.35,
			}


func _drive_opponents(delta: float) -> void:
	var rules: Dictionary = CATALOG.entry(CATALOG.DIFFICULTIES, difficulty)
	var profile: Dictionary = _rival_profile()
	for i in range(opponents.size()):
		var rival: LumoRaceKart = opponents[i]
		if RIVAL_STUNTS.update_loop(self, i, delta):
			continue
		if RIVAL_FLIGHT.update(self, i, delta):
			continue
		var sampled: Dictionary = world.sample_road(rival.position, fposmod(opponent_distances[i], track_length))
		var bend: float = RIVAL_RACECRAFT.curvature(world, float(sampled.distance))
		var target_lane: float = -2.8 + float(i) * 1.35
		target_lane += sin(elapsed * float(profile.wobble_hz) + float(i)) * float(profile.wobble)
		if float(profile.mistake) > 0.0:
			target_lane += sin(elapsed * float(profile.mistake_hz) + float(i) * 2.3) * float(profile.mistake)
		# A small measured apex bias improves the line without cutting across
		# the verge. Every driver keeps an individual risk/clearance preference.
		if difficulty != "gemuetlich":
			target_lane -= clampf(bend * 35.0, -1.0, 1.0) * float(RIVAL_RACECRAFT.style(i).line)
		if difficulty != "gemuetlich" and opponent_items[i].is_empty():
			# Earn the next resonance gate by actually driving through it. Traffic
			# safety still wins over a pickup, and stunt lane choice is applied later.
			for ring in range(item_box_distances.size()):
				var ahead: float = fposmod(item_box_distances[ring] - float(sampled.distance), track_length)
				if ahead > 1.0 and ahead < maxf(26.0, absf(rival.motion_speed) * 1.35):
					target_lane = item_box_laterals[ring]
					break
		if opponent_items[i].is_empty():
			# Sammelzonen: auch Rivalen fahren das nächste Zufallsprisma an.
			var prism_lane: float = ITEM_ZONES.rival_lane(
				catalog_box_distances, catalog_box_laterals, float(sampled.distance),
				float(sampled.lateral), rival.motion_speed, track_length
			)
			if prism_lane < INF:
				target_lane = prism_lane
		var traffic: PackedVector3Array = _rival_traffic(i, sampled)
		target_lane = RIVAL_RACECRAFT.choose_lane(
			float(sampled.lateral), target_lane, traffic, float(profile.overtake) + 10.0, i
		)
		var local_gap: Vector3 = player.position - rival.position
		_update_rival_item_tactics(i, local_gap, delta)
		target_lane = RIVAL_STUNTS.planned_loop_lane(self, i, float(sampled.distance), target_lane)
		var passage_rule: Dictionary = PASSAGES.rival_control(
			world, float(sampled.distance), absf(rival.motion_speed), elapsed, traffic, _traffic_player_entry,
			float(sampled.lateral), _traffic_kart_entries
		)
		if float(passage_rule.lane) < INF:
			target_lane = float(passage_rule.lane)
		var look_ahead: float = float(profile.look_ahead)
		if absf(rival.motion_speed) < 4.0 and absf(target_lane - float(sampled.lateral)) > 0.6:
			look_ahead = 1.5
		var aim: Vector3 = world.position_at(float(sampled.distance) + look_ahead, target_lane)
		var desired_heading: float = atan2(-(aim.x - rival.position.x), -(aim.z - rival.position.z))
		var angle: float = angle_difference(opponent_headings[i], desired_heading)
		var turn_cap: float = float(profile.turn_rate) * delta
		opponent_headings[i] += clampf(angle, -turn_cap, turn_cap)
		# Same fleet performance figures as the human kart, without tuning or
		# a player-gap multiplier. Strong drivers brake for actual upcoming bends.
		var target_speed: float = RIVAL_RACECRAFT.cruise_speed(rival.kart_style, rules)
		if opponent_boost_times[i] > 0.0:
			target_speed *= 1.32
		target_speed = minf(target_speed, RIVAL_RACECRAFT.corner_speed(bend, difficulty, rival.kart_style, i))
		target_speed *= clampf(1.0 - absf(angle) * 0.33, 0.58, 1.0)
		# Die Rampenplanung beschleunigt vom zuletzt GEPLANTEN Tempo aus, nicht vom
		# gefahrenen: Gummiband/Nordlicht wirken unten genau einmal je Takt. Vorher
		# wurden sie vor einer Rampe Takt für Takt aufmultipliziert (Sonnenhafen:
		# 45 -> 273 m/s, Rivale flog rund 1.000 m weit).
		target_speed = RIVAL_RAMP_PLAN.target_speed(
			world, float(sampled.distance), rival.kart_style, float(rules.speed),
			float(rival.get_meta(&"racecraft_planned_speed", absf(rival.motion_speed))),
			target_speed, opponent_boost_times[i] > 0.0, delta
		)
		target_speed = RIVAL_RACECRAFT.traffic_speed(float(sampled.lateral), traffic, target_speed)
		rival.set_meta(&"racecraft_planned_speed", target_speed)
		opponent_stuns[i] = maxf(0, opponent_stuns[i] - delta)
		_sync_rival_item_fx(i)
		if opponent_stuns[i] > 0:
			target_speed *= 0.3
		target_speed *= clampf(float(rival.get_meta("roadside_speed_factor", 1.0)), 0.0, 1.0)
		target_speed *= _rival_gameplay_factor(i)
		var rival_drifting: bool = _update_rival_drift(i, sampled, target_speed, delta)
		var forward := Vector3(-sin(opponent_headings[i]), 0, -cos(opponent_headings[i]))
		if opponent_stuns[i] <= 0.0:
			target_speed = RIVAL_RACECRAFT.manoeuvre_speed(
				float(sampled.lateral), target_lane, traffic, target_speed,
				Vector2(forward.dot(-(sampled.basis as Basis).z), forward.dot((sampled.basis as Basis).x)), delta
			)
		if float(passage_rule.lane) < INF or float(passage_rule.speed) < INF or bool(passage_rule.smooth):
			# Brake, wait and pull away again smoothly at a LUMO passage.
			target_speed = minf(target_speed, float(passage_rule.speed))
			target_speed = minf(target_speed, absf(rival.motion_speed) + 30.0 * delta)
		rival.position += forward * target_speed * delta
		var next: Dictionary = world.sample_road(rival.position, float(sampled.distance))
		var travel: float = fposmod(float(next.distance) - float(sampled.distance) + track_length * 0.5, track_length) - track_length * 0.5
		opponent_distances[i] += travel
		opponent_lanes[i] = float(next.lateral)
		if RIVAL_FLIGHT.try_launch(self, i, sampled, next, target_speed):
			continue
		var rival_lateral: float = float(next.lateral)
		if absf(rival_lateral) > _wall_lateral_at(float(next.distance)) and absf(rival_lateral) <= _road_width_at(float(next.distance)) * 0.5 + 1:
			# Rivals respect the same rail wall as the player.
			var rail_side: float = signf(rival_lateral)
			var overlap: float = rival_lateral - rail_side * _wall_lateral_at(float(next.distance))
			rival.position -= (next.basis as Basis).x * overlap
			# Hook kart_fx: auch Rivalen sprühen Funken, wenn sie an der Planke entlangschrammen.
			if is_instance_valid(drive_fx) and absf(overlap) > 0.01:
				drive_fx.rail_contact(rival, race_root.global_basis * ((next.basis as Basis).x * rail_side), absf(overlap) / maxf(delta, 0.001), target_speed)
			opponent_lanes[i] = rail_side * _wall_lateral_at(float(next.distance))
		rival.position.y = (
			float(next.height)
			+ 0.035
			+ world.ramp_height(float(next.distance))
			+ world.alternate_route_height(float(next.distance), rival_lateral)
		)
		if absf(float(next.lateral)) > _road_width_at(float(next.distance)) * 0.5 + 1:
			# Steer back onto the asphalt. Never teleport with reset_transform.
			var overflow: float = absf(float(next.lateral)) - (_road_width_at(float(next.distance)) * 0.5 + 0.85)
			var recover: float = minf(overflow, maxf(target_speed, 8.0) * delta * 1.15)
			rival.position -= (next.basis as Basis).x * signf(float(next.lateral)) * recover
			opponent_lanes[i] = float(next.lateral) - signf(float(next.lateral)) * recover
			opponent_headings[i] = lerp_angle(
				opponent_headings[i], _heading(opponent_distances[i]), minf(1.0, 2.6 * delta)
			)
			var recovered: Dictionary = world.sample_road(rival.position, float(next.distance))
			rival.position.y = (
				float(recovered.height)
				+ 0.035
				+ world.ramp_height(float(recovered.distance))
				+ world.alternate_route_height(float(recovered.distance), float(recovered.lateral))
			)
			var rec_forward := Vector3(-sin(opponent_headings[i]), 0, -cos(opponent_headings[i]))
			var rec_normal: Vector3 = (recovered.basis as Basis).y
			var rec_right: Vector3 = rec_forward.cross(rec_normal).normalized()
			if rec_right.length() > 0.001:
				rival.basis = Basis(rec_right, rec_normal, -rec_normal.cross(rec_right)).orthonormalized()
		else:
			var normal: Vector3 = (next.basis as Basis).y
			var right: Vector3 = forward.cross(normal).normalized()
			var rival_basis: Basis = Basis(right, normal, -normal.cross(right)).orthonormalized()
			var route_pitch: float = world.ramp_pitch(float(next.distance))
			if absf(route_pitch) < 0.001:
				route_pitch = world.alternate_route_pitch(float(next.distance), rival_lateral)
			if absf(route_pitch) > 0.001:
				rival_basis = rival_basis.rotated(right, route_pitch).orthonormalized()
			rival.basis = rival_basis
		rival.set_motion(
			target_speed,
			clampf(-angle, -1, 1),
			opponent_boost_times[i] > 0.0,
			rival_drifting
		)


func _reset_kart() -> void:
	loop_state.active = false
	precision_kicker = {}
	if menu_active or not is_instance_valid(player) or finished:
		return
	var fell_from_edge: bool = (
		open_edge_fall or (
			mode != "arena" and world.open_edge_side(previous_road_distance) != 0.0
			and absf(lane) > _road_width_at(previous_road_distance) * 0.5
		)
	)
	open_edge_fall = false
	var passage_reset: float = -1.0
	if mode != "arena":
		passage_reset = PASSAGES.respawn_for(world, previous_road_distance)
		if passage_fall_respawn >= 0.0:
			passage_reset = passage_fall_respawn
			# The kart drifted while falling: count from the passage, not from where it fell.
			distance = distance - fposmod(distance, track_length) + passage_reset + 6.0
			previous_road_distance = passage_reset
	passage_fall_respawn = -1.0
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
	air_trick = {}
	vertical_speed = 0.0
	air_time = 0.0
	reset_count += 1
	ghost_valid = false
	message.text = "Wieder sicher auf der Strecke. Du schaffst das!"
	if fell_from_edge:
		# Faire Rettung nach einem Sturz von der offenen Kante: etwas Schwung und kurzer Schutz.
		action_edge_falls += 1
		speed = 6.0
		physical_velocity = Vector3(-sin(player_heading), 0, -cos(player_heading)) * speed
		shield_time = maxf(shield_time, 2.0)
		message.text = "Die Lumo-Wolke hat dich aufgefangen. Weiter geht’s!"
	if mode != "arena" and passage_reset >= 0.0:
		# LUMO-Passage: calmly back on the level plaza, centred, standing, aligned.
		speed = 0.0
		physical_velocity = Vector3.ZERO
		shield_time = maxf(shield_time, 1.5)
		if fell_from_edge:
			passage_falls += 1
		message.text = "Die Lumo-Wolke bringt dich zurück. Ausrichten und langsam hinüber!"
		_sound_effect("whoosh")


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
	var display_speed: int = 0 if finished else int(speed * 3.6)
	if mode == "arena":
		hud.text = "KRISTALL-ARENA    %02d:%02d    ◆ %d    PLATZ %d / 6" % [int(maxf(0, 90 - elapsed)) / 60, int(maxf(0, 90 - elapsed)) % 60, arena_scores, place]
	elif mode == "training":
		hud.text = "FREIES TRAINING    %d km/h    ★ %d    PAUSE → BEENDEN" % [display_speed, collected.size()]
	elif mode == "time_trial":
		hud.text = "ZEITFAHREN    RUNDE %d / %d    %.2f s    %d km/h" % [mini(TOTAL_LAPS, int(distance / track_length) + 1), TOTAL_LAPS, elapsed, display_speed]
	else:
		hud.text = "RUNDE %d / %d    PLATZ %d / 6    %d km/h    ★ %d" % [mini(TOTAL_LAPS, int(distance / track_length) + 1), TOTAL_LAPS, place, display_speed, collected.size()]
	var enabled: bool = racing and not paused and not finished
	boost_button.text = "SPEED\n◆ %d" % boosts
	boost_button.disabled = boosts == 0 or not enabled
	var drift_state: String = RACE_RULES.drift_label(drift_charge)
	if airborne and air_trick.is_empty():
		drift_state = "TRICK!"
	drift_button.text = "DRIFT\n" + drift_state
	drift_button.disabled = not enabled
	if item.is_empty() or item in ["shield", "pulse", "boost"]:
		item_button.text = {"": "TAKTIK\n◇", "shield": "SCHILD\n◎", "pulse": "IMPULS\n✧", "boost": "SCHUB\n➜"}.get(item, "TAKTIK")
	else:
		item_button.text = ITEM_CATALOG.label(item)
	if item_charges > 1:
		item_button.text += " ×%d" % item_charges
	item_button.item_kind = item
	item_button.disabled = item.is_empty() or not enabled
	joystick.set_enabled(enabled)
	gas_button.disabled = not enabled
	brake_button.disabled = not enabled
	gas_button.visible = not auto_gas
	RACE_HUD.push(self, place, display_speed)
	_update_jump_hint(enabled)


## Speed hint on the run-up to a precision jump (prediction only, no assist).
func _update_jump_hint(enabled: bool) -> void:
	if not is_instance_valid(jump_hint):
		return
	var kicker: Dictionary = {}
	if enabled and mode != "arena" and is_instance_valid(world) and not airborne and not loop_state.active:
		var d: float = fposmod(previous_road_distance, track_length)
		for candidate in world.action.get("kickers", []):
			if not bool(candidate.get("precision_jump", false)):
				continue
			if d >= float(candidate.start) - JUMP_HINT_LEAD_M and d < float(candidate.take_off):
				kicker = candidate
	if kicker.is_empty():
		jump_hint.hide_hint()
	else:
		jump_hint.show_for(speed, kicker)


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
	for obstacle in world.action_obstacles:
		var separation: Vector3 = player.position - obstacle
		separation.y = 0.0
		if separation.length() < 0.9 and hit_timer <= 0.0 and shield_time <= 0.0:
			hit_timer = 0.15
			speed *= 0.88
			message.text = (
				"Hindernis! Weiche zur freien Spur aus."
				if ADVENTURE_DRAMA.has(track_id) and track_id != "sonnenhafen"
				else "Hütchen! Lenke durch die freie Mitte."
			)
			_sound_effect("collision")
	for i in range(opponents.size()):
		var away: Vector3 = player.position - opponents[i].position
		away.y = 0
		if rival_contact_timer <= 0 and away.length() < 1.45:
			rival_contact_timer = 0.6
			_sound_effect("collision")
			if shield_time <= 0:
				hit_timer = maxf(hit_timer, 0.25)
				var push: Vector3 = away.normalized() * 0.18
				if not PASSAGES.zone_at(world, previous_road_distance).is_empty():
					# Waiting zone / deck: a rival never shoves the child sideways into danger.
					var along: Vector3 = world.forward(previous_road_distance)
					push = along * minf(0.0, push.dot(along))
				player.position += push
	var lap: int = int(distance / track_length)
	for i in range(gems.size()):
		var key: int = _gem_key(lap, i)
		if not collected.has(key) and player.position.distance_to(gems[i].position) < _gem_pickup_radius():
			collected[key] = true
			if collected.size() % 3 == 0:
				boosts = mini(3, boosts + 1)
			# Gem collection rewards the existing boost charges, never random weapons.
			# All tactical items come from a measured resonance-ring crossing.
	for i in range(item_boxes.size()):
		var item_key: int = lap * item_boxes.size() + i
		if (
			not item_box_collected.has(item_key)
			and item.is_empty() and speed >= RESONANCE.MIN_PICKUP_SPEED
			and not airborne
			and player.position.distance_to(item_boxes[i].position) < 2.65
		):
			# Every lap offers the same rings. No ranking, RNG or unknown loot.
			var reference_speed: float = POWERTRAIN.top_speed(
				kart_factors, float(CATALOG.entry(CATALOG.DIFFICULTIES, difficulty).speed)
			)
			var reward: Dictionary = RESONANCE.award(
				speed, reference_speed, lane - item_box_laterals[i],
				drift_charge, hit_timer > 0.0
			)
			item_box_collected[item_key] = true
			item = str(reward.item)
			if is_instance_valid(drive_feedback):
				drive_feedback.collect_item(item_boxes[i].global_position, item)
			message.text = "Resonanz %d%%: %s!" % [
				roundi(float(reward.score) * 100.0),
				"Impuls" if item == "pulse" else "Schild" if item == "shield" else "Schub"
			]
			_sound_effect("item")
	_collect_catalog_boxes(lap)
	for fraction in ADVENTURE_DRAMA.turbo_fractions(track_id):
		var pad_at: float = PASSAGES.clear_distance(world, float(fraction) * track_length)
		if absf(fposmod(distance, track_length) - pad_at - 1.1) < 1.2 and absf(lane) < 2.1:
			_trigger_once("pad_%d" % int(float(fraction) * 1000.0), "boost_pad")
			boost_time = maxf(boost_time, _boost_for(1.0))


func _use_item() -> void:
	if item_roulette_time > 0.0 and not item.is_empty() and racing and not paused and not finished:
		# Tipp während der Ziehung: Ergebnis sofort zeigen, aber nichts benutzen.
		_finish_item_roulette(true)
		return
	if item.is_empty() or not racing or paused or finished or item_roulette_time > 0.0:
		return
	if item == ROCKET_ID:
		if rocket_phase != "armed":
			_arm_rockets()
		else:
			_fire_player_rockets()
		return
	_sound_effect("item")
	if item not in ["boost", "shield", "pulse"]:
		_use_catalog_item()
		return
	match item:
		"boost":
			boost_time = maxf(boost_time, _boost_for(3.0))
			camera_punch = maxf(camera_punch, 0.30)
			message.text = "Rückenwind!"
			# Vorher nur der allgemeine Item-Ton: jetzt Schub-Funken und Turbo-Klang.
			_fx("boost_pad", player.global_position + Vector3.UP * 0.6)
		"shield":
			shield_time = 6.0
			camera_punch = maxf(camera_punch, 0.0 if reduced_motion else 0.14)
			message.text = "Sternenschild: sechs Sekunden geschützt."
			_sound_effect("shield_up")
			_fx("shield_up", player.global_position + Vector3.UP * 0.6)
			_mark_item_hint_seen("shield")
		"pulse":
			pulse_age = 0
			camera_punch = maxf(camera_punch, 0.36)
			pulse_visual.position = player.position + Vector3.UP * 0.15
			for i in range(opponents.size()):
				if (
					player.position.distance_to(opponents[i].position) < 13
					and opponent_shield_times[i] <= 0.0
				):
					opponent_stuns[i] = 2.3
			message.text = "Lichtimpuls: Rivalen in deiner Nähe werden kurz langsamer."
	item = ""
	item_charges = 0
	_sync_player_rocket_phase()


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
				# Arena rewards now follow actual gems secured, not a roulette.
				item = ["boost", "shield", "pulse"][(arena_scores / 2 - 1) % 3]
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
	if absf(lane) > _road_width_at(distance) * 0.5 + 0.8:
		return
	var spacing: float = track_length / 8.0
	var target: float = (checkpoint_index + 1) * spacing
	# Ordered gates only advance when crossed locally, preventing shortcut laps.
	if distance >= target and distance < target + maxf(4.0, speed * 0.3):
		checkpoint_index += 1
		if checkpoint_index % 8 == 0:
			if lap_started_at >= 0.0:
				lap_times.append(elapsed - lap_started_at)
			lap_started_at = elapsed
			message.text = "Runde geschafft! Weiter so." if mode == "training" else "Letzte Runde!"


func _update_vehicles(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var enabled: bool = racing and not paused and not finished
	player.set_motion(speed if enabled else 0, steering, boost_time > 0 and enabled, drifting and enabled)
	var spark_tier := 0
	if drifting and enabled:
		if drift_charge >= DRIFT_TIERS[1]:
			spark_tier = 2
		elif drift_charge >= DRIFT_TIERS[0]:
			spark_tier = 1
	player.set_drift_spark_tier(spark_tier)
	player.set_braking(brake_visual_amount if enabled else 0.0)
	player.set_driver_runtime_state(airborne, hit_timer > 0.0, paused)
	if is_instance_valid(drive_feedback):
		drive_feedback.advance(
			_delta, racing and not finished and not menu_active, paused, airborne, reduced_motion
		)
	# Hook kart_fx: ein Takt Fahrgefühl-Effekte aus dem echten Fahrzustand.
	if is_instance_valid(drive_fx):
		drive_fx.advance(_delta)
	if not enabled:
		for kart in opponents:
			kart.set_motion(0, 0, false, false)
	for i in range(opponents.size()):
		var kart: LumoRaceKart = opponents[i]
		var flight: Variant = kart.get_meta(RIVAL_FLIGHT.STATE_KEY) if kart.has_meta(RIVAL_FLIGHT.STATE_KEY) else null
		var rival_airborne: bool = flight != null and bool(flight.active)
		var rival_stunned: bool = (
			(i < opponent_stuns.size() and opponent_stuns[i] > 0.0)
			or (i < opponent_spin_times.size() and opponent_spin_times[i] > 0.0)
		)
		kart.set_driver_runtime_state(rival_airborne, rival_stunned, paused)
	for fx in opponent_item_fx:
		if is_instance_valid(fx):
			fx.advance(_delta, paused or not racing or finished, reduced_motion)


func _update_camera(delta: float, snap: bool = false) -> void:
	if not is_instance_valid(camera):
		return
	if result_view and finished and finish_cine_left <= 0.0:
		_update_result_camera(delta, snap)
		return
	# Heinz' racing references keep the kart large in frame and put the horizon/
	# setpiece directly ahead. Speed stretches the view; boost never teleports it.
	if loop_state.active:
		var origin: Vector3 = world.position_at(float(world.loop_layout.start), float(world.loop_layout.lane))
		var entry_basis: Basis = world.frame(float(world.loop_layout.start))
		var radius: float = PHYSICAL_LOOP.radius_of(world.loop_layout)
		var desired_loop: Vector3 = origin + entry_basis.x * 12 + entry_basis.z * 15 + Vector3.UP * 11
		var focus: Vector3 = player.position + Vector3.UP * 0.6
		if bool(world.loop_layout.get("stunt", false)):
			# Cinematic side view through the open ring: the kart stays visible
			# on the inner deck all the way round, also upside down at the top.
			var hub: Vector3 = (
				world.position_at(
					float(world.loop_layout.start) + PHYSICAL_LOOP.ADVANCE * 0.5,
					float(world.loop_layout.lane) + PHYSICAL_LOOP.exit_shift_of(world.loop_layout) * 0.5
				)
				+ entry_basis.y * radius
			)
			desired_loop = (
				hub - entry_basis.x * radius * 2.7 + entry_basis.z * radius * 0.45
				- entry_basis.y * radius * 0.15
			)
			focus = focus.lerp(hub, 0.35)
		camera.position = (
			desired_loop if snap else camera.position.lerp(desired_loop, minf(1.0, delta * 4.0))
		)
		camera.look_at(focus)
		# The loop camera must not freeze boost FOV, speed streaks or reduced-motion preferences.
		_update_camera_speed_effects(delta, snap, clampf(absf(speed) / 25.0, 0.0, 1.0))
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
	if finished:
		target = player.position + Vector3.UP * 1.25
		camera.position = _clear_finish_camera(camera.position, target)
	if mode != "arena" and is_instance_valid(world):
		camera.position = world.clip_tunnel_camera(player.position + Vector3.UP, camera.position)
	camera.look_at(target)
	if not reduced_motion:
		var roll: float = (
			-clampf(steering, -1.0, 1.0)
			* VISUAL_GRADE.CAMERA_ROLL_MAX
			* (0.35 + speed_ratio * 0.65)
		)
		camera.rotate_object_local(Vector3(0, 0, 1), roll)
	_update_camera_speed_effects(delta, snap, speed_ratio)


## Ergebnisbild: Kamera vorn rechts vor dem Kart, so gedreht, dass Lumo in der
## freien Fläche neben bzw. über der Tafel steht. Gilt nur, solange das Ergebnis
## sichtbar ist; die Rennkamera bleibt unverändert.
func _update_result_camera(delta: float, snap: bool) -> void:
	var immediate: bool = snap or reduced_motion
	result_camera_time += delta
	var blend: float = 1.0 if immediate else smoothstep(0.0, 1.0, result_camera_time / 0.9)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / maxf(1.0, viewport_size.y)
	var target_fov: float = clampf(_resize_compensated_fov(48.0, aspect), 48.0, 76.0)
	camera.fov = target_fov if immediate else lerpf(camera.fov, target_fov, minf(1.0, delta * 4.0))
	var tan_vertical: float = tan(deg_to_rad(target_fov) * 0.5)
	var tan_horizontal: float = tan_vertical * aspect
	# Kart mit Lumo (schräg von vorn, mit Perspektive etwa 3,6 m breit und
	# 2,5 m hoch) füllt die freie Fläche; hoch steht es ohne Tafel daneben.
	var subject_width: float = 3.6 if result_free.x < 1.0 else 3.0
	var view_distance: float = clampf(maxf(
		subject_width / (2.0 * tan_horizontal * result_free.x * 0.92),
		2.5 / (2.0 * tan_vertical * result_free.y * 0.86)
	), 2.8, 9.5)
	var target: Vector3 = player.position + Vector3.UP * 1.0
	var desired: Vector3 = _result_camera_position(view_distance, target)
	if not immediate:
		desired = camera.position.lerp(desired, minf(1.0, delta * 4.5))
	camera.position = _clear_finish_camera(desired, target)
	if mode != "arena" and is_instance_valid(world):
		camera.position = world.clip_tunnel_camera(player.position + Vector3.UP, camera.position)
	camera.look_at(target)
	# Nach rechts bzw. unten schwenken: Das Kart rückt in die freie Fläche.
	camera.rotate_object_local(Vector3.UP, -atan((0.5 - result_focus.x) * 2.0 * tan_horizontal) * blend)
	camera.rotate_object_local(Vector3.RIGHT, -atan((0.5 - result_focus.y) * 2.0 * tan_vertical) * blend)
	if is_instance_valid(speed_fx):
		speed_fx.set_motion(0.0, false, reduced_motion)
	_keep_result_cheer()


## Bevorzugt vorn rechts vor dem Kart. Steht dort eine Leitplanke oder ein
## Gebäude im Weg (das Kart rollt oft am Rand aus), folgt die nächste freie
## Richtung: vorn links, gerade von vorn, dann seitlich.
func _result_camera_position(view_distance: float, target: Vector3) -> Vector3:
	_cache_finish_camera_boxes()
	var ahead := Vector3(-sin(player_heading), 0, -cos(player_heading))
	var side := Vector3(-ahead.z, 0, ahead.x)
	var best: Vector3 = target
	var best_clear: float = -1.0
	for angle in [0.62, -0.62, 0.0, 1.25, -1.25]:
		var candidate: Vector3 = (
			player.position
			+ (ahead * cos(angle) + side * sin(angle)) * view_distance
			+ Vector3.UP * (0.6 + view_distance * 0.2)
		)
		var clear: float = _finish_camera_segment_fraction(target, candidate)
		if clear >= 0.9:
			return candidate
		if clear > best_clear:
			best_clear = clear
			best = candidate
	return best


## Lumo schaut zur Kamera und jubelt, solange das Ergebnis eines Treppchenplatzes
## (oder einer Fahrt ohne Rang) zu sehen ist: Die vorhandene Jubelbewegung beginnt
## nach ihrem Ende neu. Bei ruhiger Bewegung bleibt Lumo ruhig sitzen.
func _keep_result_cheer() -> void:
	if reduced_motion or paused or not is_instance_valid(player):
		return
	var place: int = int(result_payload.get("place", 1)) if _ranked() else 1
	for animator in [player.get("lumo_animation"), player.get("production_driver")]:
		if not is_instance_valid(animator):
			continue
		if animator.has_method("set_attention_target"):
			animator.set_attention_target(camera.global_position)
		if place <= 3 and not bool(animator.victory):
			animator.celebrate_finished_race(place)


func _update_camera_speed_effects(delta: float, snap: bool, speed_ratio: float) -> void:
	var baseline_fov: float = VISUAL_GRADE.camera_fov(
		speed_ratio, boost_time > 0.0 and not paused, reduced_motion
	)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / maxf(1.0, viewport_size.y)
	var target_fov: float = _resize_compensated_fov(baseline_fov, aspect)
	# The eased base value is kept apart from the short kicks: easing from a
	# value that already contains a kick lets the kicks pile up frame by frame
	# until the field of view leaves its valid range.
	camera_base_fov = (
		target_fov
		if snap or camera_base_fov <= 0.0
		else lerpf(camera_base_fov, target_fov, minf(1.0, delta * VISUAL_GRADE.FOV_LERP))
	)
	var kicked_fov: float = camera_base_fov
	if camera_punch > 0.0 and not reduced_motion:
		kicked_fov += camera_punch * 9.5
		camera_punch = maxf(0.0, camera_punch - delta * 2.2)
	if is_instance_valid(fx) and not snap:
		# Drive-through push: brief FOV punch and a tiny shake (both off in reduced motion).
		kicked_fov += fx.camera_fov_kick()
		camera.position += camera.basis * fx.camera_shake()
	if is_instance_valid(drive_fx) and not snap:
		kicked_fov += drive_fx.camera_fov_kick()  # Hook kart_fx: Turbo-FOV-Schub
	camera.fov = clampf(kicked_fov, 20.0, 140.0)
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
		boost_time = _boost_for(3.2)
		message.text = "Lumo-Boost!"
		_sound_effect("boost")


func _release_drift() -> void:
	drifting = false
	if racing and not paused and not finished and drift_charge >= DRIFT_TIERS[0]:
		var tier: int = RACE_RULES.drift_tier(drift_charge)
		drift_tier_count[tier] += 1
		boost_time = maxf(boost_time, _boost_for(DRIFT_BOOST_SECONDS[tier]))
		camera_punch = maxf(camera_punch, [0.20, 0.34, 0.45][tier])
		message.text = ["Blauer Drift-Turbo!", "Oranger Drift-Turbo!", "Lila Mega-Drift-Turbo!"][tier]
		_sound_effect("drift")
		if is_instance_valid(drive_feedback):
			drive_feedback.boost_release(tier + 1)
		_award_boost(["drift_blue", "drift_orange", "drift_purple"][tier], 0.0, "")
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
		lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	style.border_width_top = 5
	style.border_width_bottom = 2
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
	var state: int = 4 if countdown <= 0.0 else red_lit
	# Materials change only on a countdown beat or viewport resize.
	# No per-frame StyleBox allocation on the Android render loop.
	var refresh: bool = state != start_light_state or not is_equal_approx(diameter, start_light_diameter)
	start_light_state = state
	start_light_diameter = diameter
	countdown_label.text = "LOS!" if countdown <= 0.0 else str(ceili(countdown))
	countdown_label.add_theme_font_size_override("font_size", int(diameter * 0.95))
	countdown_label.custom_minimum_size = Vector2(diameter * (2.3 if countdown <= 0.0 else 1.1), diameter)
	for i in range(start_lamps.size()):
		start_lamps[i].custom_minimum_size = Vector2(diameter, diameter)
		var green: bool = countdown <= 0.0
		var color: Color = Color("44f08a") if green else Color("ff4b55")
		if refresh:
			start_lamps[i].add_theme_stylebox_override("panel", _lamp_style(color, green or i < red_lit, diameter))
	start_lights.reset_size()
	start_lights.position = Vector2((area.x - start_lights.size.x) * 0.5, area.y * 0.2)
	start_lights.pivot_offset = start_lights.size * 0.5
	# One small settling motion per beat, never a repeating ambient animation.
	var beat_age: float = ceili(countdown) - countdown if counting else START_GREEN_SECONDS - start_green_left
	var pulse: float = 0.0 if reduced_motion else maxf(0.0, 1.0 - beat_age / 0.22)
	start_lights.scale = Vector2.ONE * (1.0 + 0.045 * pulse * pulse)


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
				_press_drift()
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
	_update_vehicles(0.0)
	_save_session()
	_clear_column(modal_column)
	modal_scroll.scroll_vertical = 0
	menu_settings_navigation.hide()
	pause_navigation.show()
	modal_column.add_child(_label("Eine kleine Pause", 28))
	modal_column.add_child(_label("Dein Rennen wartet. Du kannst später hier weiterfahren.", 19))
	var resume := _button("Weiterfahren", _resume)
	resume.name = "PauseResume"
	resume.custom_minimum_size.y = 72
	resume.add_theme_font_size_override("font_size", 26)
	modal_column.add_child(resume)
	if mode == "training":
		var finish_training := _button("Training abschließen", _finish)
		finish_training.name = "FinishTraining"
		modal_column.add_child(finish_training)
	# Die Wege aus der Pause stehen direkt unter „Weiterfahren“, die Einstellungen danach.
	var new_drive := _button("Neue Fahrt auswählen", _leave_race_for_menu)
	new_drive.name = "PauseNewDrive"
	modal_column.add_child(new_drive)
	var abandon := _button("Rennen abbrechen", _abandon, Color("3a4577"))
	abandon.name = "PauseAbandon"
	modal_column.add_child(abandon)
	_append_preferences()
	MODAL_STYLE.dress(modal, _modal_dp_scale())
	modal.show()
	_apply_responsive_layout()
	call_deferred("_apply_responsive_layout")


func _append_preferences() -> void:
	var motion := _button(
		"Ruhige Bewegung: an (App)" if host_reduce_motion else ("Ruhige Bewegung: an" if reduced_motion else "Ruhige Bewegung: aus"), func(): pass
	)
	motion.pressed.connect(
		func():
			preferred_reduced_motion = not preferred_reduced_motion
			reduced_motion = preferred_reduced_motion or host_reduce_motion
			if is_instance_valid(player):
				player.reduced_motion = reduced_motion
			if is_instance_valid(garage):
				garage.reduced_motion = reduced_motion
				if is_instance_valid(garage.preview_kart):
					garage.preview_kart.reduced_motion = reduced_motion
			motion.text = "Ruhige Bewegung: an" if reduced_motion else "Ruhige Bewegung: aus"
			_save_preferences()
	)
	motion.name = "MotionToggle"
	motion.disabled = host_reduce_motion
	modal_column.add_child(motion)
	# Hook kart-garage: Linkshänder-Schalter; Spiegelung macht RACE_HUD.apply_handedness.
	var hand := _button(RACE_HUD.handedness_text(left_handed), func(): pass)
	hand.name = "HandednessToggle"
	# Langer Text: auf schmalen Handys umbrechen statt das Pausenfenster zu verbreitern.
	hand.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hand.pressed.connect(
		func():
			left_handed = not left_handed
			hand.text = RACE_HUD.handedness_text(left_handed)
			_save_preferences()
			_apply_responsive_layout()
	)
	modal_column.add_child(hand)
	var sound := _button("Ton: aus (App)" if not host_sound_enabled else ("Ton: aus" if muted else "Ton: an"), func(): pass)
	sound.pressed.connect(
		func():
			muted = not muted
			sound.text = "Ton: aus" if muted else "Ton: an"
			_save_preferences()
	)
	sound.name = "AudioToggle"
	sound.disabled = not host_sound_enabled
	modal_column.add_child(sound)
	var detail := _button("Grafik: " + {"high": "Hoch", "medium": "Ausgewogen", "low": "Leicht"}.get(graphics_profile, "Hoch"), func(): pass)
	detail.pressed.connect(
		func():
			graphics_profile = {"high": "medium", "medium": "low", "low": "high"}.get(graphics_profile, "high")
			lightweight = graphics_profile == "low"
			# Apply the user-selected visual tier across all Godot game worlds.
			LumoQuality.set_tier(graphics_profile)
			_save_preferences()
			detail.text = "Grafik: " + {"high": "Hoch", "medium": "Ausgewogen", "low": "Leicht"}[graphics_profile]
			if menu_active:
				garage.graphics_profile = graphics_profile
				garage.preview_signature = ""
				garage._refresh_preview()
			else:
				_save_session()
				_rebuild_graphics()
	)
	detail.name = "GraphicsProfileToggle"
	modal_column.add_child(detail)
	# Alle drei Stufen des Katalogs (Entdecken → Abenteuer → Extrem) der Reihe nach.
	var challenge := _button(_level_toggle_text(), func(): pass)
	challenge.pressed.connect(
		func():
			var ids: Array[String] = []
			for level in CATALOG.DIFFICULTIES:
				ids.append(str(level.id))
			difficulty = ids[posmod(ids.find(known_level(difficulty)) + 1, ids.size())]
			if menu_active:
				garage.setup.difficulty = difficulty
			challenge.text = _level_toggle_text()
			_save_preferences()
	)
	challenge.name = "DifficultyToggle"
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

func _level_toggle_text() -> String:
	return "Stufe: " + str(CATALOG.entry(CATALOG.DIFFICULTIES, known_level(difficulty)).name)


## Pixel je dp wie in _apply_responsive_layout (für Rahmen und Ecken des Fensters).
func _modal_dp_scale() -> float:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size: Vector2 = Vector2(get_window().size) / MobileRuntime.get_ui_density()
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return 1.0
	return maxf(viewport_size.x / window_size.x, viewport_size.y / window_size.y)


func _resume() -> void:
	if menu_active:
		return
	paused = false
	_update_vehicles(0.0)
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
		elif finished and mode != "cup" and HostBridge.reward_is_recoverable(result_id):
			# A durable completed handoff must survive the host freeing this scene.
			_session_handed_off = true
		elif abandoned:
			DirAccess.remove_absolute(SESSION)
		return
	if abandoned:
		DirAccess.remove_absolute(SESSION)
	if finished and mode != "cup" and HostBridge.reward_is_recoverable(result_id):
		_session_handed_off = true
	SceneRouter.goto("learn" if destination == "learn" else "games")


func _show_host_save_failure() -> void:
	message.text = HostBridge.SAVE_FAILURE
	if not modal_column.has_node("HostSaveFailure"):
		var label: Control
		if result_view:
			# Im Ergebnis ist die obere Meldungszeile ausgeblendet: Hinweis in der Tafel.
			label = RESULT_WIDGETS.Row.new().setup("notice", HostBridge.SAVE_FAILURE, "", 0, Color("ffb648"))
		else:
			label = _label(HostBridge.SAVE_FAILURE, 20)
			label.add_theme_color_override("font_color", Color("3a4577"))
		label.name = "HostSaveFailure"
		modal_column.add_child(label)
		modal_column.move_child(label, 1)
		if result_view:
			_apply_responsive_layout()


func _abandon() -> void:
	_save_session()
	abandoned = true
	_return_to_app("games")


## [param cinematic] false: Ergebnis sofort zeigen (z. B. gespeichertes Rennen
## nach dem Ziel wieder geöffnet), ohne Zielfahrt.
func _finish(cinematic: bool = true) -> void:
	if finished or menu_active:
		return
	if is_instance_valid(drive_feedback):
		drive_feedback.reset()
	# Hook kart_fx: im Ziel keine Spuren/Funken mehr aus dem Rennen.
	if is_instance_valid(drive_fx):
		drive_fx.reset()
	completed_race = true
	racing = false
	_update_audio()
	paused = false
	finished = true
	if is_instance_valid(kart_audio):
		kart_audio.set_paused(false)
	_sound_effect("finish")
	if track_id == "jungle_emerald_3600" and is_instance_valid(world):
		var jungle_environment = world.get_node_or_null("DschungelherzEnvironment")
		if jungle_environment != null and jungle_environment.has_method("celebrate_finish"):
			jungle_environment.celebrate_finish()
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
		"solved": 0, "elapsedSeconds": snappedf(elapsed, 0.001), "place": place,
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
	if lap_started_at >= 0.0 and (lap_times.is_empty() or elapsed - lap_started_at > 1.0):
		lap_times.append(elapsed - lap_started_at)
	result_payload["bestLapSeconds"] = snappedf(_best_lap(), 0.001)
	result_payload["starTokens"] = collected.size()
	var pass_result := result_payload.duplicate(true)
	pass_result["difficulty"] = difficulty
	# Legacy race checkpoints had no child owner. Keep those races resumable,
	# but never attribute their objectives to the next child who opens Kart.
	if _track_pass_owner == track_pass.child_key.sha256_text():
		result_payload["trackPass"] = track_pass.complete(pass_result, distance, track_length)
	# Belohnung und Ergebnis-ID gehen sofort an der Linie raus; die Zielfahrt ist nur Bild.
	var reward_accepted: bool = HostBridge.reward(result_payload)
	_save_session()
	_celebrate_opponents()
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


func _celebrate_opponents() -> void:
	for i in range(opponents.size()):
		var rival: LumoRaceKart = opponents[i]
		var place: int = _opponent_place(i)
		if mode == "arena" and i < opponent_scores.size():
			place = 1 + int(arena_scores > opponent_scores[i])
			for j in range(opponent_scores.size()):
				if j != i and opponent_scores[j] > opponent_scores[i]:
					place += 1
		rival.celebrate(place)


func _show_result() -> void:
	if is_instance_valid(controls_row):
		controls_row.hide()
	_update_hud()
	message.text = _place_title(int(result_payload.get("place", 1))) if _ranked() else "Ziel!"
	_clear_column(modal_column)
	modal_scroll.scroll_vertical = 0
	pause_navigation.hide()
	menu_settings_navigation.hide()
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
	var cup_final: bool = ranked and mode == "cup" and not pending_cup_next
	# Abzeichen: große Platzzahl mit „PLATZ von 6“; ohne Rang die Überschrift.
	var badge := RESULT_BADGE.new()
	badge.place = place_now
	badge.ranked = ranked
	badge.title = title
	badge.subline = "von 6" if ranked else ""
	badge.reduced_motion = reduced_motion
	modal_column.add_child(badge)
	if cup_final:
		var headline: Label = _label(title, 24)
		headline.name = "ResultHeadline"
		headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		headline.add_theme_color_override("font_color", _place_color(place_now))
		modal_column.add_child(headline)
	var stats := RESULT_WIDGETS.Stats.new()
	stats.text = _result_stats_text()
	modal_column.add_child(stats)
	var mastery: Variant = result_payload.get("trackPass", {})
	if mastery is Dictionary and bool(mastery.get("eligible", false)):
		var mastery_text := "Streckenpass · %d/3 Ziele\n%s" % [int(mastery.get("stage", 0)), TRACK_PASS.goal_text(int(mastery.get("stage", 0)))]
		var mastery_icon: String = "pass"
		if not bool(mastery.get("saved", true)):
			mastery_text = "Der Streckenpass konnte nicht gespeichert werden. Dein Rennergebnis bleibt erhalten."
			mastery_icon = "notice"
		var mastery_row := RESULT_WIDGETS.Row.new().setup(mastery_icon, mastery_text)
		mastery_row.name = "TrackPassResult"
		modal_column.add_child(mastery_row)
	if mode == "arena":
		var crystals := RESULT_WIDGETS.Row.new().setup("crystal", "Kristalle gesammelt", str(arena_scores))
		crystals.name = "ResultCrystals"
		modal_column.add_child(crystals)
	if mode == "time_trial":
		var record_text: String = "Deine neue Bestzeit – Geisterfahrt gespeichert!" if best_record else ("Bestzeit: %.2f Sekunden" % records.previous_best if records.previous_best > 0 else "Erste Trainingszeit. Ohne Zurücksetzen wird deine Geisterfahrt gespeichert.")
		var record_row := RESULT_WIDGETS.Row.new().setup("record", record_text)
		record_row.name = "ResultRecord"
		modal_column.add_child(record_row)
	var primary: Button
	var secondary: Button
	if mode == "cup":
		var names: Array[String] = [str(CATALOG.entry(CATALOG.DRIVERS, selected_driver).name), "Milo", "Nova", "Borin", "Yuki", "Fynn"]
		var standings: Array[Dictionary] = []
		for i in range(cup_points.size()):
			standings.append({"name": names[i], "points": cup_points[i], "id": i, "me": i == 0})
		standings.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.points) > int(b.points))
		modal_column.add_child(RESULT_WIDGETS.Standings.new().setup(standings))
	if pending_cup_next:
		primary = RESULT_WIDGETS.Action.new().setup(
			"Weiter: " + str(CATALOG.TRACKS[cup_index + 1].name), _next_cup_race, "primary", "next"
		)
		secondary = RESULT_WIDGETS.Action.new().setup("Zur Spieleauswahl", _return_to_world, "secondary")
	else:
		# Die zwei nächsten Schritte groß (Auftrag 18.11.): gleich noch einmal oder eine
		# andere Strecke wählen. Spielewelt und Lernen bleiben klein darunter.
		primary = RESULT_WIDGETS.Action.new().setup("Noch einmal", _restart_setup, "primary", "replay")
		secondary = RESULT_WIDGETS.Action.new().setup("Zur Streckenwahl", _leave_to_track_choice, "secondary", "next")
	primary.name = "ResultPrimary"
	secondary.name = "ResultSecondary"
	var main_row := BoxContainer.new()
	main_row.name = "ResultMainActions"
	main_row.add_child(primary)
	main_row.add_child(secondary)
	modal_column.add_child(main_row)
	var more_row := BoxContainer.new()
	more_row.name = "ResultMoreActions"
	if pending_cup_next:
		more_row.add_child(RESULT_WIDGETS.Action.new().setup("Neue Fahrt auswählen", _leave_race_for_menu))
	else:
		more_row.add_child(RESULT_WIDGETS.Action.new().setup("Zur Spieleauswahl", _return_to_world))
	more_row.add_child(RESULT_WIDGETS.Action.new().setup("Zum Lernen", func(): _return_to_app("learn")))
	modal_column.add_child(more_row)
	for row in [main_row, more_row]:
		for action in row.get_children():
			# Wie alle Dialogknöpfe: Ein Wischen, das auf dem Knopf beginnt, scrollt
			# die Tafel und löst die Aktion nicht aus.
			action.mouse_filter = Control.MOUSE_FILTER_PASS
	if ranked:
		modal_column.add_child(RESULT_WIDGETS.Tagline.new().setup(_place_cheer(place_now)))
	result_view = true
	result_camera_time = 0.0
	# Das Ergebnis steht frei über der Szene: keine Renn-Anzeige, keine Abdunklung.
	hud_content.hide()
	modal.show()
	modal_backdrop.hide()
	_apply_responsive_layout()
	call_deferred("_apply_responsive_layout")
	_play_result_entrance(badge, stats)


## Abzeichen ploppt auf, die Zeilen blenden nacheinander ein. Bei ruhiger
## Bewegung steht alles sofort.
func _play_result_entrance(badge: Control, stats: Control) -> void:
	if reduced_motion:
		badge.appear = 1.0
		return
	badge.play_in()
	var rows: Array = stats.get_children()
	for row_name in ["ResultMainActions", "ResultMoreActions", "ResultCheer"]:
		if modal_column.has_node(row_name):
			rows.append(modal_column.get_node(row_name))
	for index in range(rows.size()):
		var row: Control = rows[index]
		row.modulate.a = 0.0
		var fade: Tween = row.create_tween()
		fade.tween_interval(0.12 + 0.07 * float(index))
		fade.tween_property(row, "modulate:a", 1.0, 0.22)


func _ranked() -> bool:
	return mode not in ["training", "time_trial", "arena"]


func _best_lap() -> float:
	var best: float = 0.0
	for lap in lap_times:
		if lap > 0.5 and (best == 0.0 or lap < best):
			best = lap
	return best


func _format_time(seconds: float) -> String:
	var total_milliseconds: int = roundi(seconds * 1000.0)
	var whole: int = total_milliseconds / 1000
	return "%02d:%02d.%03d" % [whole / 60, whole % 60, total_milliseconds % 1000]


func _result_stats_text() -> String:
	var lines: PackedStringArray = ["Gesamtzeit   " + _format_time(elapsed)]
	var best: float = _best_lap()
	# Older completed saves retain their acknowledged best in the result payload,
	# even though they never stored individual lap intervals. Display that known
	# value without inventing history for an unfinished, partially measured lap.
	if best == 0.0 and finished:
		var saved_best = result_payload.get("bestLapSeconds", 0.0)
		if typeof(saved_best) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(saved_best)):
			if 0.0 < float(saved_best) and float(saved_best) <= elapsed + 0.001:
				best = float(saved_best)
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
	finish_coast_reverse = speed < 0.0
	finish_coast_speed = physical_velocity.length() * (-1.0 if finish_coast_reverse else 1.0)
	finish_road_distance = previous_road_distance
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
	_coast_finished_kart(delta)
	var ahead := Vector3(-sin(player_heading), 0, -cos(player_heading))
	if is_instance_valid(camera):
		if reduced_motion:
			_update_camera(delta)
		else:
			var blend: float = smoothstep(0.0, 1.0, t)
			var side := Vector3(-ahead.z, 0, ahead.x)
			var angle: float = lerpf(0.0, PI * 0.78, blend)
			var radius: float = lerpf(6.6, 4.6, blend)
			var offset: Vector3 = (-ahead * cos(angle) + side * sin(angle)) * radius
			var target: Vector3 = player.position + Vector3.UP * 1.25
			var desired: Vector3 = player.position + offset + Vector3.UP * lerpf(3.5, 1.7, blend)
			desired = camera.position.lerp(desired, minf(1.0, delta * 6.0))
			camera.position = _clear_finish_camera(desired, target)
			if mode != "arena" and is_instance_valid(world):
				camera.position = world.clip_tunnel_camera(player.position + Vector3.UP, camera.position)
			camera.look_at(target)
	_update_hud()
	if finish_cine_left <= 0.0:
		_show_result()


## Keep the actual momentum and the same contact surface after the result is fixed.
func _coast_finished_kart(delta: float) -> void:
	var magnitude: float = physical_velocity.length()
	var damped: float = move_toward(magnitude, 0.0, delta * maxf(6.0, magnitude * 0.55))
	physical_velocity *= damped / magnitude if magnitude > 0.0 else 0.0
	var before_horizontal: Vector3 = player.position
	player.position += physical_velocity * delta
	_constrain_tunnel_motion(before_horizontal)
	if mode != "arena" and is_instance_valid(world):
		var road: Dictionary = world.sample_road(player.position, finish_road_distance)
		lane = float(road.lateral)
		# Settle the existing contact projection and nearest-surface estimate.
		# This does not steer or move the kart toward the centre of the lane.
		for contact_step in range(4):
			finish_road_distance = float(road.distance)
			if not airborne and not world.in_gap(finish_road_distance):
				# Banked road normals couple vertical contact to lateral contact.
				# Resolve the ground before the rail so neither undoes the other.
				player.position.y = (
					float(road.height) + 0.035
					+ world.ramp_height(finish_road_distance)
					+ world.alternate_route_height(finish_road_distance, lane)
				)
				road = world.sample_road(player.position, finish_road_distance)
				lane = float(road.lateral)
			if absf(lane) > _wall_lateral_at(float(road.distance)):
				_collide_with_rail(road)
			road = world.sample_road(player.position, finish_road_distance)
			lane = float(road.lateral)
		finish_road_distance = float(road.distance)
		var ground: float = (
			float(road.height) + 0.035
			+ world.ramp_height(finish_road_distance)
			+ world.alternate_route_height(finish_road_distance, lane)
		)
		if airborne or world.in_gap(finish_road_distance):
			airborne = true
			vertical_speed -= JUMP_GRAVITY * delta
			var before_vertical: Vector3 = player.position
			player.position.y += vertical_speed * delta
			_constrain_tunnel_motion(before_vertical)
			if not world.in_gap(finish_road_distance) and player.position.y <= ground:
				player.position.y = ground
				airborne = false
				vertical_speed = 0.0
		# Grounded contact was already solved together with the rail above.
		var normal: Vector3 = (road.basis as Basis).y
		var forward := Vector3(-sin(player_heading), 0, -cos(player_heading))
		var right: Vector3 = forward.cross(normal).normalized()
		player.basis = Basis(right, normal, -normal.cross(right).normalized()).orthonormalized()
	elif mode == "arena":
		player.position.y = 0.035
	finish_coast_speed = physical_velocity.length() * (-1.0 if finish_coast_reverse else 1.0)
	speed = finish_coast_speed
	player.set_motion(finish_coast_speed, 0.0, false, false)


## Box props are GPU instances, not physics bodies. Use their drawn transforms.
func _cache_finish_camera_boxes() -> void:
	if not is_instance_valid(world) or finish_camera_world == world.get_instance_id():
		return
	finish_camera_world = world.get_instance_id()
	finish_camera_boxes.clear()
	for child in world.get_children():
		if not child is MultiMeshInstance3D:
			continue
		var instances: MultiMesh = child.multimesh
		if instances == null or not instances.mesh is BoxMesh:
			continue
		var bounds: AABB = instances.mesh.get_aabb()
		for index in range(instances.instance_count):
			var pose: Transform3D = child.global_transform * instances.get_instance_transform(index)
			if pose.origin.distance_to(player.global_position) > 45.0 + pose.basis.get_scale().length():
				continue
			var scale_size: Vector3 = pose.basis.get_scale().abs()
			var margin := Vector3(
				0.15 / maxf(scale_size.x, 0.001),
				0.15 / maxf(scale_size.y, 0.001),
				0.15 / maxf(scale_size.z, 0.001)
			)
			finish_camera_boxes.append({
				"inverse": pose.affine_inverse(),
				"bounds": AABB(bounds.position - margin, bounds.size + margin * 2.0)
			})


func _finish_camera_segment_fraction(target: Vector3, desired: Vector3) -> float:
	var nearest: float = 1.0
	for box in finish_camera_boxes:
		var inverse: Transform3D = box.inverse
		var local_start: Vector3 = inverse * target
		var local_end: Vector3 = inverse * desired
		var ray: Vector3 = local_end - local_start
		var bounds: AABB = box.bounds
		var enter: float = 0.0
		var leave: float = 1.0
		for axis in range(3):
			if absf(ray[axis]) < 0.000001:
				if local_start[axis] < bounds.position[axis] or local_start[axis] > bounds.end[axis]:
					enter = 2.0
					break
			else:
				var first: float = (bounds.position[axis] - local_start[axis]) / ray[axis]
				var last: float = (bounds.end[axis] - local_start[axis]) / ray[axis]
				enter = maxf(enter, minf(first, last))
				leave = minf(leave, maxf(first, last))
		if enter <= leave and leave >= 0.0 and enter < nearest:
			nearest = maxf(0.0, enter - 0.02)
	return nearest


func _clear_finish_camera(desired: Vector3, target: Vector3) -> Vector3:
	_cache_finish_camera_boxes()
	var result: Vector3 = target.lerp(desired, _finish_camera_segment_fraction(target, desired))
	if result.distance_to(target) < 2.2 and is_instance_valid(world):
		var road: Dictionary = world.sample_road(player.position, finish_road_distance)
		var fallback: Vector3 = player.position - road.forward * 4.6 + (road.basis as Basis).y * 3.5
		result = target.lerp(fallback, _finish_camera_segment_fraction(target, fallback))
	return result


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
	# Quad with vertex colours: a plain QuadMesh drew single confetti pieces black.
	var quad: ArrayMesh = preload("res://scripts/systems/particle_quad.gd").make(Vector2(0.12, 0.07))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.surface_set_material(0, mat)
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


## Ergebnis → „Zur Streckenwahl“: zurück ins Menü, direkt in die Rennwelten.
func _leave_to_track_choice() -> void:
	_leave_race_for_menu()
	_reference_select_mode("world")


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
	left_handed = bool(config.get_value("race", "left_handed", false))  # Hook kart-garage
	var host_options: Dictionary = SceneRouter.launch_options.duplicate(true)
	host_options.merge(HostBridge.launch_options(), true)
	host_sound_enabled = bool(host_options.get("soundEnabled", true))
	host_reduce_motion = bool(host_options.get("reduceAnimations", false))
	reduced_motion = preferred_reduced_motion or host_reduce_motion
	# Without hardware graphics (emulator, very weak device) the race starts light.
	lightweight = bool(
		config.get_value(
			"race", "lightweight",
			SettingsStore.get_profile() == "low" or PerformanceManager.software_rendered_mobile()
		)
	)
	muted = bool(config.get_value("race", "muted", false))
	music_volume = clampf(float(config.get_value("race", "music_volume", 1.0)), 0.0, 1.0)
	effects_volume = clampf(float(config.get_value("race", "effects_volume", 1.0)), 0.0, 1.0)
	# Touch devices start with the GAS pedal; keyboard and automated runs keep auto-gas.
	var touch_device: bool = OS.has_feature("android") or OS.has_feature("ios")
	auto_gas = bool(config.get_value("race", "auto_gas", not touch_device))
	# Die Stufe gehört zum Kind. Der frühere gemeinsame Wert "race/difficulty" stammte
	# aus der erzwungenen Startstufe "Extrem" und war keine Wahl – er zählt nicht mehr.
	difficulty = known_level(str(config.get_value("levels", _level_key(), "gemuetlich")))
	graphics_profile = str(config.get_value("race", "graphics_profile", "low" if lightweight else "high"))
	if graphics_profile not in ["high", "medium", "low"]:
		graphics_profile = "high"
	lightweight = graphics_profile == "low"


## Schlüssel des Kindes für seine gespeicherte Gegnerstufe (wie beim Streckenpass).
func _level_key() -> String:
	var options: Dictionary = SceneRouter.launch_options.duplicate(true)
	options.merge(HostBridge.launch_options(), true)
	var child: String = str(options.get("childKey", "standalone"))
	return (child if not child.is_empty() else "standalone").sha256_text()


## Unbekannte oder beschädigte Werte fallen auf die Einstiegsstufe "Entdecken" zurück.
static func known_level(id: String) -> String:
	for entry in CATALOG.DIFFICULTIES:
		if str(entry.id) == id:
			return id
	return "gemuetlich"


func _save_preferences() -> void:
	var config := ConfigFile.new()
	# Vorhandene Datei behalten: darin stehen die Stufen der anderen Kinder.
	config.load(PREFERENCES)
	config.set_value("race", "reduced_motion", preferred_reduced_motion)
	config.set_value("race", "left_handed", left_handed)  # Hook kart-garage
	config.set_value("race", "lightweight", lightweight)
	config.set_value("race", "graphics_profile", graphics_profile)
	config.set_value("race", "muted", muted)
	config.set_value("race", "music_volume", music_volume)
	config.set_value("race", "effects_volume", effects_volume)
	config.set_value("race", "auto_gas", auto_gas)
	config.set_value("race", "difficulty", difficulty)
	config.set_value("levels", _level_key(), known_level(difficulty))
	config.save(PREFERENCES)
	_update_audio()
	for kart in opponents:
		kart.reduced_motion = reduced_motion


func _save_session() -> void:
	if abandoned or _session_handed_off or menu_active or not is_instance_valid(player):
		return
	var config := ConfigFile.new()
	config.set_value("race", "version", SESSION_VERSION)
	config.set_value("race", "track_pass_owner", _track_pass_owner)
	for key in [
		"distance", "result_id", "checkpoint_index", "lane", "speed", "countdown", "elapsed",
		"lap_times", "lap_started_at",
		"boost_time", "boosts", "opponent_distances", "opponent_lanes", "collected", "difficulty",
		"mode", "track_id", "selected_driver", "selected_kart", "player_heading", "previous_road_distance",
		"cup_index", "cup_points", "cup_results", "pending_cup_next", "finished", "completed_race", "result_payload",
		"arena_scores", "arena_pickup_timers", "opponent_scores", "opponent_targets", "opponent_headings",
		"item", "shield_time", "reset_count", "setup_snapshot", "item_box_collected", "opponent_items",
		"item_charges", "catalog_box_collected", "item_roulette_time"
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
	RIVAL_STUNTS.save_positions(self, config)
	RIVAL_FLIGHT.save_positions(self, config)
	var tmp_path: String = SESSION + ".tmp"
	if config.save(tmp_path) != OK:
		push_warning("Race checkpoint tmp write failed")
		return
	var error: Error = DirAccess.rename_absolute(tmp_path, SESSION)
	if error != OK:
		push_warning("Race checkpoint could not be saved: %s" % error)


func _restore_session() -> bool:
	var config := ConfigFile.new()
	if config.load(SESSION) != OK:
		# Reuse the copy _ready / _resume_saved_race already parsed.
		if (
			saved_session_available
			and int(session_config.get_value("race", "version", 0)) in SESSION_VERSIONS
		):
			config = session_config
		else:
			return false
	if int(config.get_value("race", "version", 0)) not in SESSION_VERSIONS:
		return false
	var saved_distance: float = float(config.get_value("race", "distance", -1))
	if saved_distance < 0 or not is_finite(saved_distance):
		return false
	_track_pass_owner = str(config.get_value("race", "track_pass_owner", ""))
	RIVAL_FLIGHT.clear(self)
	_session_handed_off = false
	var keys: Array[String] = [
		"distance", "result_id", "checkpoint_index", "lane", "speed", "countdown", "elapsed", "boost_time", "boosts",
		"collected", "difficulty", "mode", "track_id", "selected_driver", "selected_kart",
		"player_heading", "previous_road_distance", "cup_index",
		"pending_cup_next", "finished", "completed_race", "result_payload", "arena_scores", "item", "shield_time",
		"reset_count", "setup_snapshot"
	]
	for key in keys:
		set(key, config.get_value("race", key, get(key)))
	if _track_pass_owner != track_pass.child_key.sha256_text():
		result_payload.erase("trackPass")
	# Explicit typed write: a generic set() must not leave the _ready identity.
	result_id = str(config.get_value("race", "result_id", result_id))
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
	_restore_lap_timing(config)
	player.rotation.y = player_heading
	ghost_valid = false
	mode = _known_mode(mode)
	racing = countdown <= 0 and not completed_race
	# Sub-second restores still need their first active snapshot; later saves do not.
	save_timer = 0.0
	first_active_snapshot_pending = elapsed < 1.0 and not completed_race
	_update_vehicles(0)
	_update_camera(1, true)
	if finished:
		_show_result()
	return true


func _restore_lap_timing(config: ConfigFile) -> void:
	# -1 is an explicitly unmeasured current lap. It survives another save and
	# becomes known only at the next legitimate lap boundary. First-lap legacy
	# saves still have the known race start at zero.
	lap_times.clear()
	lap_started_at = 0.0 if checkpoint_index < 8 and not finished else -1.0
	if (
		not config.has_section_key("race", "lap_times")
		or not config.has_section_key("race", "lap_started_at")
	):
		return
	var saved_laps = config.get_value("race", "lap_times")
	var saved_start = config.get_value("race", "lap_started_at")
	if not saved_laps is Array or typeof(saved_start) not in [TYPE_INT, TYPE_FLOAT]:
		return
	var start: float = float(saved_start)
	if (
		not is_finite(elapsed)
		or elapsed < 0.0
		or not is_finite(start)
		or (start < 0.0 and start != -1.0)
		or start > elapsed
	):
		return
	var completed_laps: int = checkpoint_index / 8
	var partial_finish: bool = finished and mode in ["training", "arena"]
	if saved_laps.size() > completed_laps + int(partial_finish):
		return
	var restored: Array[float] = []
	var total: float = 0.0
	for interval in saved_laps:
		if (
			typeof(interval) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(interval))
			or float(interval) <= 0.0
		):
			return
		var seconds: float = float(interval)
		total += seconds
		restored.append(seconds)
	var valid: bool = total <= elapsed + 0.001
	if start >= 0.0:
		valid = valid and (completed_laps == 0 or start > 0.0)
		if partial_finish and restored.size() == completed_laps + 1:
			valid = (
				valid
				and absf(total - elapsed) <= 0.001
				and absf(total - restored[-1] - start) <= 0.001
			)
		else:
			valid = valid and total <= start + 0.001
			if restored.size() == completed_laps:
				valid = valid and absf(total - start) <= 0.001
	if not valid:
		return
	lap_times.assign(restored)
	lap_started_at = start


func _sync_item_box_visibility() -> void:
	var lap: int = int(distance / track_length)
	for i in range(item_boxes.size()):
		item_boxes[i].visible = not item_box_collected.has(lap * item_boxes.size() + i)
	for i in range(catalog_boxes.size()):
		catalog_boxes[i].visible = not catalog_box_collected.has(lap * catalog_boxes.size() + i)


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
	catalog_box_collected.clear()
	var saved_boxes = config.get_value("race", "catalog_box_collected", {})
	if saved_boxes is Dictionary:
		for key in saved_boxes:
			if typeof(key) == TYPE_INT and key >= 0 and typeof(saved_boxes[key]) == TYPE_BOOL and saved_boxes[key]:
				catalog_box_collected[key] = true
	_sync_item_box_visibility()
	var saved_items = config.get_value("race", "opponent_items", [])
	for i in range(opponents.size()):
		var saved_item: String = ""
		if saved_items is Array and i < saved_items.size() and saved_items[i] is String:
			saved_item = saved_items[i]
		opponent_items[i] = saved_item if ITEM_CATALOG.has(saved_item) else ""
	if not item.is_empty() and not ITEM_CATALOG.has(item):
		item = ""
	var saved_charges = config.get_value("race", "item_charges", 0)
	var max_charges: int = maxi(1, int(ITEM_CATALOG.entry(item).get("charges", 1)))
	item_charges = 0 if item.is_empty() else clampi(int(saved_charges) if typeof(saved_charges) in [TYPE_INT, TYPE_FLOAT] else 1, 1, max_charges)
	# A resumed race never starts armed: pods unfold again and wait for the first tap.
	rocket_phase = ""
	item_roulette_time = 0.0
	star_compass.clear()
	# Eine laufende Ziehung läuft mit demselben Ergebnis weiter (nie neu gezogen).
	var saved_roulette = config.get_value("race", "item_roulette_time", 0.0)
	var roulette_saved: bool = typeof(saved_roulette) in [TYPE_INT, TYPE_FLOAT]
	if not item.is_empty() and roulette_saved and float(saved_roulette) > 0.0:
		star_compass.start(item, reduced_motion, Vector3.ZERO)
		item_roulette_time = clampf(float(saved_roulette), 0.0, star_compass.total)
	_sync_player_rocket_phase()
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
			_menu_back()
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
	if MobileRuntime.safe_area_changed.is_connected(_on_viewport_size_changed):
		MobileRuntime.safe_area_changed.disconnect(_on_viewport_size_changed)
	if get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.disconnect(_on_viewport_size_changed)
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


static func _item_pool_for_place(_place: int) -> Array[String]:
	# Historical API retained for save and test compatibility. Former rank-
	# dependent lottery cannot be invoked in the new skill-only race system.
	return ["boost"]


func _roll_item_for_place(_place: int) -> String:
	# Never infer an item from the race position. Real ring items are awarded
	# only by RESONANCE.award from line, speed and drift.
	return "boost"


## Surprise item boxes draw from the data-driven catalogue (assets/kart/items/kart_items.json).
## Skill resonance rings keep their deterministic award.
func _roll_catalog_item(place: int, progress: float = -INF) -> String:
	# Data-driven odds from assets/kart/items/kart_items.json; the legacy three-item
	# pool stays as a safe fallback if the catalog cannot be read.
	var rolled: String = ITEM_CATALOG.roll(
		place, rng, _catch_up_amount(place, distance if progress == -INF else progress)
	)
	if not rolled.is_empty():
		return rolled
	var pool: Array[String] = _item_pool_for_place(place)
	return pool[rng.randi_range(0, pool.size() - 1)]


func _item_box(distance_on_track: float, lateral: float) -> void:
	var basis: Basis = world.frame(distance_on_track)
	var transform := Transform3D(
		basis, _track_position(distance_on_track, lateral) + basis.y * 1.9
	)
	var node: Node3D = RESONANCE.build_ring(race_root, transform)
	item_boxes.append(node)
	item_box_distances.append(distance_on_track)
	item_box_laterals.append(lateral)


func _boost_ring(distance_on_track: float, lateral: float) -> void:
	var ring: Node3D = BOOST_RING_SCENE.instantiate()
	ring.name = "BoostRing"
	race_root.add_child(ring)
	ring.global_transform = Transform3D(world.frame(distance_on_track), _track_position(distance_on_track, lateral))


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


func _sound_effect(kind: String, pitch: float = 1.0) -> void:
	if is_instance_valid(kart_audio):
		kart_audio.effect(kind, pitch)


# --- Arcade gameplay layer (Lumo-Kart items, spins, slipstream, tricks, combos) ---

const RIVAL_DISPLAY_NAMES: Dictionary = {
	"otter": "Otter", "rabbit": "Hase", "badger": "Dachs", "cat": "Katze", "fox": "Fuchs",
	"lion": "Löwe", "owl": "Eule", "squirrel": "Eichhörnchen", "turtle": "Schildkröte", "frog": "Frosch",
}
var player_spin_total: float = 1.0
var opponent_spin_totals: Array[float] = []
var _player_base_basis := Basis.IDENTITY
var _player_spun_basis := Basis.IDENTITY
var _player_spin_applied: bool = false
var _flash_layer: CanvasLayer


func _build_gameplay_layer() -> void:
	item_runtime = ITEM_RUNTIME.new()
	item_runtime.name = "KartItemRuntime"
	item_runtime.reduced_motion = reduced_motion
	race_root.add_child(item_runtime)
	if mode != "arena" and is_instance_valid(world):
		item_runtime.setup(track_length, WORLD.WALL_LATERAL, _frame_at)
	_flash_layer = CanvasLayer.new()
	_flash_layer.name = "KartFlashLayer"
	_flash_layer.layer = 1
	race_root.add_child(_flash_layer)
	fx = FX_DIRECTOR.new()
	fx.name = "KartFxDirector"
	race_root.add_child(fx)
	fx.setup(_flash_layer, graphics_profile, reduced_motion)
	fx.sound_hook.connect(_on_fx_sound)
	rocket_flight = ROCKET_FLIGHT.new()
	race_root.add_child(rocket_flight)
	rocket_flight.setup(self, graphics_profile, reduced_motion)
	frame_smoother = FRAME_SMOOTHER.new()
	frame_smoother.nodes_provider = _smoothed_nodes
	frame_smoother.offset_provider = rocket_flight.offset_for
	race_root.add_child(frame_smoother)
	item_status_fx = ITEM_STATUS_FX.new()
	player.add_child(item_status_fx)
	opponent_spin_totals.clear()
	for i in range(opponents.size()):
		opponent_spin_totals.append(1.0)
		opponent_previous_positions[i] = opponents[i].global_position
	player_previous_position = player.global_position
	# Track scenes may place their own LumoKartItemBox / BoostRing / BoostPad nodes.
	for node in get_tree().get_nodes_in_group(TRIGGER_GROUP):
		if not race_root.is_ancestor_of(node) or node in item_boxes:
			continue
		if node in catalog_boxes:
			continue
		if str(node.get("trigger_kind")) == "item_box" and mode != "arena":
			node.managed = true
			var sampled_box: Dictionary = world.sample_road(node.global_position, 0.0)
			catalog_boxes.append(node)
			catalog_box_distances.append(float(sampled_box.distance))
			catalog_box_laterals.append(float(sampled_box.lateral))
		else:
			track_triggers.append(node)
	_build_item_experience()


## Was der Bild-Glätter zwischen zwei Physiktakten weich zeigt: nur während des Rennens.
func _smoothed_nodes() -> Array:
	if menu_active or not racing or finished:
		return []
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return []
	var nodes: Array = [camera, player]
	nodes.append_array(opponents)
	if is_instance_valid(item_runtime):
		for entry in item_runtime.projectiles + item_runtime.traps:
			if is_instance_valid(entry.node):
				nodes.append(entry.node)
	return nodes


func _frame_at(progress: float, lateral: float) -> Transform3D:
	return Transform3D(world.frame(progress), _track_position(progress, lateral))


func _reset_gameplay_layer() -> void:
	item_charges = 0
	player_spin_time = 0.0
	player_spin_total = 1.0
	magnet_time = 0.0
	aurora_time = 0.0
	slipstream_charge = 0.0
	slipstream_ready_leader = -1
	combo = 0
	last_boost_source_at = -100.0
	trigger_cooldowns.clear()
	_player_spin_applied = false
	for i in range(opponent_spin_times.size()):
		opponent_spin_times[i] = 0.0
		opponent_aurora_times[i] = 0.0
	if is_instance_valid(item_runtime):
		item_runtime.clear()
	if is_instance_valid(rocket_flight):
		rocket_flight.clear()
	_reset_item_experience()
	gameplay_stats = {
		"items_used": 0, "rival_items_used": 0, "player_hits_taken": 0, "player_hits_scored": 0,
		"blocked": 0, "intercepted": 0, "slipstreams": 0, "tricks": 0, "rings": 0, "max_combo": 0,
		"boost_sources": {},
	}


func _on_fx_sound(_event_id: String, fallback: String) -> void:
	_sound_effect(fallback)


func _fx(event_id: String, at: Vector3, strength: float = 1.0) -> void:
	if is_instance_valid(fx):
		fx.trigger(event_id, at, strength)


func _stat(key: String, amount: int = 1) -> void:
	if gameplay_stats.is_empty():
		_reset_gameplay_layer()
	gameplay_stats[key] = int(gameplay_stats.get(key, 0)) + amount


func _rival_name(index: int) -> String:
	if index < 0 or index >= opponents.size():
		return "Ein Rivale"
	return str(RIVAL_DISPLAY_NAMES.get(str(opponents[index].animal), "Ein Rivale"))


func _leader_progress() -> float:
	var best: float = distance
	for value in opponent_distances.slice(0, opponents.size()):
		best = maxf(best, value)
	return best


func _catch_up_amount(place: int, progress: float) -> float:
	if place < 3 or opponents.is_empty():
		return 0.0
	return RACE_RULES.gap_ratio(_leader_progress() - progress)


func _gem_pickup_radius() -> float:
	return 6.0 if magnet_time > 0.0 else 1.75


## Player top-speed factor from spins, Nordlicht, magnet tow and the catch-up help.
func _gameplay_speed_factor() -> float:
	var factor: float = 1.0
	if player_spin_time > 0.0:
		factor *= 0.3
	if aurora_time > 0.0:
		factor *= 1.22
	elif magnet_time > 0.0:
		factor *= 1.06
	if mode in ["race", "cup"] and not opponents.is_empty():
		factor *= RACE_RULES.player_catch_up(_leader_progress() - distance, difficulty)
	return factor


func _rival_gameplay_factor(index: int) -> float:
	var factor: float = 1.0
	if index < opponent_spin_times.size() and opponent_spin_times[index] > 0.0:
		factor *= 0.25
	if index < opponent_aurora_times.size() and opponent_aurora_times[index] > 0.0:
		factor *= 1.2
	if mode in ["race", "cup"] and index < opponent_distances.size():
		factor *= RACE_RULES.rival_rubber_band(opponent_distances[index] - distance, difficulty)
	return factor


func _racers() -> Array:
	var result: Array = [{
		"key": -1, "progress": distance, "lateral": lane,
		"protected": shield_time > 0.0 or aurora_time > 0.0,
	}]
	for i in range(opponents.size()):
		result.append({
			"key": i, "progress": opponent_distances[i], "lateral": opponent_lanes[i],
			"protected": opponent_shield_times[i] > 0.0 or opponent_aurora_times[i] > 0.0,
		})
	return result


## Closest racer ahead of / behind `key` in race progress.
func _neighbour(key: int, ahead: bool) -> Dictionary:
	var own: float = distance if key < 0 else opponent_distances[key]
	var own_lane: float = lane if key < 0 else opponent_lanes[key]
	var best := {"key": -99, "gap": INF, "lateral": 0.0}
	for racer in _racers():
		if int(racer.key) == key:
			continue
		var gap: float = (float(racer.progress) - own) * (1.0 if ahead else -1.0)
		if gap > 0.5 and gap < float(best.gap):
			best = {"key": int(racer.key), "gap": gap, "lateral": float(racer.lateral) - own_lane}
	return best


func _rival_threatened(index: int) -> bool:
	if not is_instance_valid(item_runtime) or index >= opponent_distances.size():
		return false
	return item_runtime.incoming_for(index, opponent_distances[index]) < 1.2


func _grant_item(id: String) -> void:
	# Ein direkt vergebenes Item beendet eine laufende Kompass-Darstellung (sonst würde der
	# nächste Tipp nur die alte Ziehung überspringen).
	item_roulette_time = 0.0
	star_compass.clear()
	item = id
	item_charges = maxi(1, int(ITEM_CATALOG.entry(id).get("charges", 1)))
	rocket_phase = ""
	_sync_player_rocket_phase()


func _consume_item() -> void:
	item_charges = maxi(1, item_charges) - 1
	if item_charges <= 0:
		item = ""
		item_charges = 0
	_stat("items_used")
	_sync_player_rocket_phase()


func _use_catalog_item() -> void:
	var id: String = item
	var row: Dictionary = ITEM_CATALOG.entry(id)
	if row.is_empty():
		item = ""
		item_charges = 0
		return
	var at: Vector3 = player.global_position + Vector3.UP * 0.8
	var behaviour: String = str(row.behaviour)
	if mode == "arena" and behaviour in ["homing_projectile", "bouncing_projectile", "dropped_trap"]:
		behaviour = "boost"
	match behaviour:
		"boost":
			boost_time = maxf(boost_time, _boost_for(float(row.get("seconds", 1.6))))
			var left: int = item_charges - 1
			message.text = "%s! Noch %d×" % [row.name, left] if left > 0 else "%s!" % row.name
			_award_boost("boost_pad", 0.0, "")
		"homing_projectile":
			var target: Dictionary = _neighbour(-1, true)
			item_runtime.fire_homing(id, -1, distance, lane, int(target.key))
			message.text = (
				"Sternrakete fliegt zu %s!" % _rival_name(int(target.key))
				if int(target.key) >= 0 else "Sternrakete fliegt voraus!"
			)
			_fx("rocket_launch", at)
		"bouncing_projectile":
			item_runtime.fire_bouncing(id, -1, distance, lane, clampf(steering, -1.0, 1.0) * 6.0)
			message.text = "Funkenkugel – sie prallt von den Banden ab!"
			_fx("rocket_launch", at, 0.6)
		"dropped_trap":
			item_runtime.drop_trap(id, -1, distance, lane)
			message.text = "Blubberblase liegt hinter dir – sie fängt auch Raketen!"
			_fx("bubble_drop", _track_position(distance - 2.2, lane) + Vector3.UP * 0.8, 0.7)
		"magnet":
			magnet_time = float(row.get("seconds", 4.0))
			message.text = "Sternmagnet: Sterne fliegen zu dir, Windschatten zieht stärker!"
			_fx("magnet", at)
		"aurora":
			aurora_time = float(row.get("seconds", 4.5))
			shield_time = maxf(shield_time, aurora_time)
			boost_time = maxf(boost_time, _boost_for(aurora_time * 0.5))
			message.text = "Nordlicht-Lauf! Du leuchtest und bist geschützt."
			_fx("aurora", at)
	_consume_item()


func _rival_use_catalog_item(index: int, local_gap: Vector3) -> void:
	var id: String = opponent_items[index]
	if not ITEM_CATALOG.has(id):
		opponent_items[index] = ""
		return
	if id == ROCKET_ID:
		# Sternraketen: hold, lock on (with a warning for the player), then fire pairs.
		return
	var behaviour: String = ITEM_CATALOG.behaviour(id)
	var ahead: Dictionary = _neighbour(index, true)
	var behind: Dictionary = _neighbour(index, false)
	var context := {
		"ahead_gap": ahead.gap, "ahead_lateral": ahead.lateral, "behind_gap": behind.gap,
		"threatened": _rival_threatened(index), "player_near": local_gap.length(),
		"place": _opponent_place(index),
	}
	if not RACE_RULES.rival_should_use(id, behaviour, context):
		return
	var progress: float = opponent_distances[index]
	var rival_lane: float = opponent_lanes[index]
	match behaviour:
		"boost":
			opponent_boost_times[index] = 2.2
		"homing_projectile":
			if not is_instance_valid(item_runtime) or not item_runtime.fire_homing(id, index, progress, rival_lane, int(ahead.key)):
				return
			if int(ahead.key) == -1:
				message.text = "Achtung: Sternrakete von %s! Schild oder Blubberblase hilft." % _rival_name(index)
			_fx("rocket_launch", opponents[index].global_position + Vector3.UP * 0.8, 0.5)
		"bouncing_projectile":
			if not is_instance_valid(item_runtime) or not item_runtime.fire_bouncing(id, index, progress, rival_lane, 0.0):
				return
		"dropped_trap":
			if not is_instance_valid(item_runtime):
				return
			item_runtime.drop_trap(id, index, progress, rival_lane)
		"magnet":
			opponent_boost_times[index] = 1.5
		"aurora":
			var seconds: float = ITEM_CATALOG.number(id, "seconds", 4.5)
			opponent_aurora_times[index] = seconds
			opponent_shield_times[index] = maxf(opponent_shield_times[index], minf(seconds, 5.0))
		_:
			return
	opponent_items[index] = ""
	opponent_item_cooldowns[index] = 1.8
	_stat("rival_items_used")


func _update_gameplay_layer(delta: float) -> void:
	player_spin_time = maxf(0.0, player_spin_time - delta)
	magnet_time = maxf(0.0, magnet_time - delta)
	aurora_time = maxf(0.0, aurora_time - delta)
	for i in range(opponent_spin_times.size()):
		opponent_spin_times[i] = maxf(0.0, opponent_spin_times[i] - delta)
		opponent_aurora_times[i] = maxf(0.0, opponent_aurora_times[i] - delta)
	if is_instance_valid(item_runtime) and item_runtime.placer.is_valid():
		for event in item_runtime.step(delta, _racers()):
			_apply_item_event(event)
	if is_instance_valid(rocket_flight):
		rocket_flight.tick(delta)
	_update_item_feedback(delta)
	_update_slipstream(delta)
	_update_track_triggers()
	_update_aurora_contacts()
	_update_item_experience(delta)
	_apply_spin_visuals()
	player_previous_position = player.global_position
	for i in range(opponents.size()):
		opponent_previous_positions[i] = opponents[i].global_position


## Kleine Item-Rückmeldungen ohne Spielwirkung (Bande, Blase, Laufzeit-Ring, Ende).
func _update_item_feedback(delta: float) -> void:
	if is_instance_valid(item_runtime):
		for cue in item_runtime.take_feedback():
			var at: Vector3 = cue.get("position", Vector3.ZERO)
			if at != Vector3.ZERO:
				_fx("spark_bounce" if str(cue.kind) == "wall_bounce" else "bubble_pop", at, 0.6)
	if is_instance_valid(item_status_fx):
		item_status_fx.reduced_motion = reduced_motion
		var magnet_before: bool = item_status_fx.magnet_ring.visible
		var aurora_before: bool = item_status_fx.aurora_ring.visible
		item_status_fx.advance(
			delta, magnet_time, ITEM_CATALOG.number("star_magnet", "seconds", 4.0),
			aurora_time, ITEM_CATALOG.number("aurora", "seconds", 4.5)
		)
		if (magnet_before and magnet_time <= 0.0) or (aurora_before and aurora_time <= 0.0):
			_fx("item_end", player.global_position + Vector3.UP * 0.7, 0.5)


func _spin_player(seconds: float) -> void:
	player_spin_time = seconds
	player_spin_total = maxf(0.1, seconds)
	speed *= 0.6
	hit_timer = maxf(hit_timer, 0.3)
	_stat("player_hits_taken")


func _spin_rival(index: int, seconds: float) -> void:
	opponent_spin_times[index] = seconds
	opponent_spin_totals[index] = maxf(0.1, seconds)


func _apply_item_event(event: Dictionary) -> void:
	var target: int = int(event.target)
	var source: int = int(event.get("source", -99))
	var at: Vector3 = event.get("position", Vector3.ZERO)
	var rocket: bool = str(event.get("item", "")) == ROCKET_ID
	if is_instance_valid(rocket_flight):
		rocket_flight.on_item_event(event, rocket)
	item_telemetry.note_event(str(event.type), event, elapsed)
	if str(event.type) == "intercepted":
		_stat("intercepted")
		_fx("blocked", at)
		if source == -1 or target == -1:
			message.text = "Die Blubberblase hat die Rakete gefangen!"
		return
	if str(event.type) == "expired":
		_fx("rocket_fizzle", at)
		if source == -1:
			message.text = "Daneben – die Sternraketen verpuffen."
		return
	if str(event.type) == "blocked":
		_stat("blocked")
		_fx("shield_deflect" if rocket else "blocked", at)
		if target == -1:
			if is_instance_valid(shield_visual) and shield_visual.has_method("impact"):
				shield_visual.impact(at)
			message.text = "Abgeprallt! Dein Sternenschild hält." if rocket else "Dein Schild hält – nichts passiert!"
			_popup("ABGEPRALLT!", player.global_position + Vector3.UP * 2.3, Color("1aa3c4"))
		elif target >= 0 and target < opponent_item_fx.size():
			opponent_item_fx[target].shield_impact(at)
			if source == -1:
				message.text = "%s hat einen Schild – abgeprallt!" % _rival_name(target)
				_popup("ABGEPRALLT!", opponents[target].global_position + Vector3.UP * 2.3, Color("1aa3c4"))
		return
	# Schonzeit: a racer who was just hit is not spun again straight away.
	var in_grace: bool = (
		player_grace_time > 0.0 if target == -1
		else (target >= 0 and target < opponent_grace_times.size() and opponent_grace_times[target] > 0.0)
	)
	if not in_grace and not rocket_fairness.hit_allowed(self, target):
		# Sturzstelle (Rampe, Brücke, offene Kante …): das Geschoss zerplatzt harmlos.
		in_grace = true
	if in_grace:
		item_telemetry.note_event("grace", event, elapsed)
		_fx("rocket_pop", at)
		return
	var grace: float = float(_lock_rules().grace)
	if target == -1:
		_spin_player(float(event.spin))
		player_grace_time = grace
		# Das Kind selbst: milder Hüpfer, die Kamera bleibt ruhig (halbe Effektstärke).
		var hit_at: Vector3 = player.global_position + Vector3.UP * 0.8
		_fx("rocket_hit" if rocket else "hit_spin", hit_at, 0.45 if rocket else 1.0)
		if is_instance_valid(rocket_flight) and rocket:
			rocket_flight.start_tumble(-1, float(event.spin) * 0.8, true)
		message.text = "Huch, gedreht! Gleich geht's weiter."
		if source >= 0 and source < opponents.size():
			opponents[source].cheer_in_race(1.2)
	elif target >= 0 and target < opponents.size():
		_spin_rival(target, float(event.spin))
		if is_instance_valid(rocket_flight):
			rocket_flight.start_tumble(target, float(event.spin), rocket)
		if target < opponent_grace_times.size():
			opponent_grace_times[target] = grace
		_fx("rocket_hit" if rocket else "hit_spin", opponents[target].global_position + Vector3.UP * 0.8, 0.6 if source != -1 else 1.0)
		if source == -1:
			_stat("player_hits_scored")
			var whirl: bool = rocket and not reduced_motion
			message.text = (
				"Treffer! %s wirbelt durch die Luft." if whirl else "Treffer! %s dreht sich im Kreis."
			) % _rival_name(target)
			_popup("TREFFER!", opponents[target].global_position + Vector3.UP * 2.4, Color("ff3b5c"))
			# Lumo cheers briefly (real rigged Lumo: its own celebrate clip).
			player.cheer_in_race(1.3)
			_cheer_timer = 1.3


func _update_slipstream(delta: float) -> void:
	if mode not in ["race", "cup"] or opponents.is_empty() or airborne:
		slipstream_charge = maxf(0.0, slipstream_charge - delta * 2.0)
		return
	var forward := Vector3(-sin(player_heading), 0.0, -cos(player_heading))
	var leader: int = -1
	for i in range(opponents.size()):
		if RACE_RULES.in_slipstream(player.global_position, forward, opponents[i].global_position, speed):
			leader = i
			break
	if leader < 0:
		slipstream_charge = maxf(0.0, slipstream_charge - delta * 2.0)
		slipstream_ready_leader = -1
		return
	slipstream_ready_leader = leader
	slipstream_charge += delta * (2.0 if magnet_time > 0.0 else 1.0)
	if slipstream_charge >= RACE_RULES.SLIPSTREAM_CHARGE_SECONDS:
		slipstream_charge = 0.0
		message.text = "Windschatten von %s – Schub!" % _rival_name(leader)
		_stat("slipstreams")
		_award_boost("slipstream", RACE_RULES.SLIPSTREAM_BOOST_SECONDS, "")


func _trigger_once(key: String, event_id: String, seconds: float = 0.0) -> bool:
	if float(trigger_cooldowns.get(key, -1.0)) > elapsed:
		return false
	trigger_cooldowns[key] = elapsed + 1.2
	_award_boost(event_id, seconds, "")
	return true


func _update_track_triggers() -> void:
	for trigger in track_triggers:
		if not is_instance_valid(trigger):
			continue
		var key: String = str(trigger.get_instance_id())
		match str(trigger.get("trigger_kind")):
			"boost_ring":
				# A jump of more than 6 m in one frame is a reset/restore teleport, not a pass.
				if player_previous_position.distance_to(player.global_position) < 6.0 and trigger.crossed(player_previous_position, player.global_position):
					if _trigger_once(key, "boost_ring", float(trigger.boost_seconds)):
						trigger.celebrate()
						_stat("rings")
						message.text = "Durch den Turbo-Ring!"
				for i in range(opponents.size()):
					if opponent_previous_positions[i].distance_to(opponents[i].global_position) < 6.0 and trigger.crossed(opponent_previous_positions[i], opponents[i].global_position):
						opponent_boost_times[i] = maxf(opponent_boost_times[i], 1.2)
			"boost_pad":
				if trigger.contains(player.global_position):
					_trigger_once(key, "boost_pad", float(trigger.boost_seconds))


func _award_boost(event_id: String, seconds: float, text: String) -> void:
	combo = RACE_RULES.next_combo(combo, elapsed - last_boost_source_at)
	last_boost_source_at = elapsed
	if seconds > 0.0:
		boost_time = maxf(boost_time, _boost_for(seconds))
	var sources: Dictionary = gameplay_stats.get("boost_sources", {})
	sources[event_id] = int(sources.get(event_id, 0)) + 1
	gameplay_stats["boost_sources"] = sources
	gameplay_stats["max_combo"] = maxi(int(gameplay_stats.get("max_combo", 0)), combo)
	var at: Vector3 = player.global_position + Vector3.UP * 0.6
	_fx(event_id, at)
	if combo >= 2:
		boost_time += RACE_RULES.combo_bonus(combo)
		message.text = "Turbo-Kette ×%d!" % combo
		_fx("combo", at, 0.6)
	elif not text.is_empty():
		message.text = text


func _update_aurora_contacts() -> void:
	if aurora_time <= 0.0:
		return
	for i in range(opponents.size()):
		var gap: Vector3 = opponents[i].global_position - player.global_position
		gap.y = 0.0
		if gap.length() < 1.9 and opponent_spin_times[i] <= 0.0 and opponent_shield_times[i] <= 0.0:
			_spin_rival(i, ITEM_CATALOG.number("aurora", "spin_seconds", 1.0))
			_stat("player_hits_scored")
			_fx("hit_spin", opponents[i].global_position + Vector3.UP * 0.8, 0.6)


func _press_drift() -> void:
	# Holding DRIFT in the air starts the HEAD air-trick system (kart_air_trick.gd);
	# its landing reward feeds the combo chain.
	drifting = racing and not paused and not finished


## Friendly spin (two turns, easing out). Applied on top
## of the physics basis each physics frame, never accumulated.
func _apply_spin_visuals() -> void:
	if _player_spin_applied and player.basis.is_equal_approx(_player_spun_basis):
		player.basis = _player_base_basis
	_player_spin_applied = false
	var base: Basis = player.basis
	var spun: Basis = base
	if player_spin_time > 0.0:
		var t: float = 1.0 - player_spin_time / player_spin_total
		var turns: float = 0.25 if reduced_motion else 2.0
		var angle: float = TAU * turns * (1.0 - pow(1.0 - t, 2.0))
		spun = spun.rotated(base.y.normalized(), angle)
	if spun != base:
		_player_base_basis = base
		player.basis = spun.orthonormalized()
		_player_spun_basis = player.basis
		_player_spin_applied = true
	for i in range(opponents.size()):
		if opponent_spin_times[i] <= 0.0:
			continue
		var rival_t: float = 1.0 - opponent_spin_times[i] / opponent_spin_totals[i]
		var rival_turns: float = 0.25 if reduced_motion else 2.0
		var rival_basis: Basis = opponents[i].basis
		opponents[i].basis = rival_basis.rotated(
			rival_basis.y.normalized(), TAU * rival_turns * (1.0 - pow(1.0 - rival_t, 2.0))
		).orthonormalized()


# --- Surprise item boxes (catalogue roll) beside the skill resonance rings ---


## Two calm lap fractions, as far as possible from rings, turbo fields, boost rings,
## story beats, jumps and the loop, so a box row never sits on a ramp.
func _catalog_box_fractions() -> Array[float]:
	var busy: Array[float] = []
	for entry in ADVENTURE_DRAMA.item_layout(track_id):
		busy.append(float(entry[0]))
	for fraction in ADVENTURE_DRAMA.turbo_fractions(track_id):
		busy.append(float(fraction))
	for entry in BOOST_RING_LAYOUT:
		busy.append(float(entry[0]))
	for beat in ADVENTURE_DRAMA.profile(track_id).get("beats", []):
		busy.append(float(beat[0]))
	var length: float = maxf(track_length, 1.0)
	for kicker in world.action.get("kickers", []) if world.action is Dictionary else []:
		for offset in [-30.0, 0.0, 30.0]:
			busy.append(fposmod(float(kicker.get("take_off", 0.0)) + offset, length) / length)
	if not world.loop_layout.is_empty():
		busy.append(fposmod(float(world.loop_layout.start), length) / length)
	var picks: Array[float] = []
	for _row in range(CATALOG_BOX_ROWS_PER_LAP):
		var best: float = -1.0
		var best_gap: float = -1.0
		for step in range(6, 95):
			var candidate: float = float(step) / 100.0
			var gap: float = 1.0
			for other in busy + picks:
				var d: float = absf(candidate - other)
				gap = minf(gap, minf(d, 1.0 - d))
			for other in picks:
				if absf(candidate - other) < 0.28:
					gap = -1.0
			if _road_width_at(candidate * length) < ROAD_WIDTH * 0.85:
				gap = -1.0
			if gap > best_gap:
				best_gap = gap
				best = candidate
		if best >= 0.0:
			picks.append(best)
	picks.sort()
	return picks


## Bereits platzierte Ringe und Turbofelder: Sammelzonen halten davon Abstand.
func _catalog_zone_occupied() -> Array:
	var occupied: Array = item_box_distances.duplicate()
	for entry in BOOST_RING_LAYOUT:
		occupied.append(PASSAGES.clear_distance(world, float(entry[0]) * track_length))
	for fraction in ADVENTURE_DRAMA.turbo_fractions(track_id):
		occupied.append(PASSAGES.clear_distance(world, float(fraction) * track_length))
	return occupied


func _catalog_box(distance_on_track: float, lateral: float) -> void:
	var basis: Basis = world.frame(distance_on_track)
	var node: Node3D = ITEM_BOX_SCENE.instantiate()
	node.name = "SurpriseItemBox"
	node.managed = true
	node.position = _track_position(distance_on_track, lateral) + basis.y * 1.05
	node.basis = basis
	race_root.add_child(node)
	catalog_boxes.append(node)
	catalog_box_distances.append(distance_on_track)
	catalog_box_laterals.append(lateral)


func _collect_catalog_boxes(lap: int) -> void:
	for i in range(catalog_boxes.size()):
		var key: int = lap * catalog_boxes.size() + i
		if catalog_box_collected.has(key) or not catalog_boxes[i].visible:
			continue
		if player.position.distance_to(catalog_boxes[i].position) > CATALOG_BOX_RADIUS:
			continue
		catalog_box_collected[key] = true
		catalog_boxes[i].visible = false
		_fx("item_box", catalog_boxes[i].global_position)
		if item.is_empty():
			var prism_at: Vector3 = catalog_boxes[i].global_position
			_grant_item_with_roulette(_roll_catalog_item(_place()), prism_at)
			MYSTERY_PRISM.shatter(race_root, catalog_boxes[i].global_position, reduced_motion)
			item_telemetry.note_draw(-1, _place(), item, lap, elapsed)
			message.text = "Überraschung!"
		else:
			item_telemetry.note_full(-1, lap, elapsed)


func _rival_collect_catalog_box(index: int) -> void:
	for i in range(catalog_boxes.size()):
		if opponents[index].position.distance_to(catalog_boxes[i].position) <= CATALOG_BOX_RADIUS:
			opponent_items[index] = _roll_catalog_item(_opponent_place(index), opponent_distances[index])
			item_telemetry.note_draw(
				index, _opponent_place(index), opponent_items[index],
				int(opponent_distances[index] / maxf(track_length, 1.0)), elapsed
			)
			opponent_item_cooldowns[index] = 1.8
			return


# --- Sternraketen, Zielerfassung und Sternenschild (item experience) ---------------------

## Lock-on per difficulty: cone half-angle (deg), range (m), seconds to a full lock.
## "Entdecken" (gemuetlich) is generous so a child locks on almost at once.
const LOCK_RULES: Dictionary = {
	"gemuetlich": {"cone": 38.0, "range": 85.0, "lock": 0.45, "rival_lock": 2.2, "rival_hold": 7.0, "rival_salvo_gap": 7.0, "grace": 3.5},
	"normal": {"cone": 28.0, "range": 65.0, "lock": 0.7, "rival_lock": 1.5, "rival_hold": 3.5, "rival_salvo_gap": 4.0, "grace": 2.6},
	"profi": {"cone": 22.0, "range": 55.0, "lock": 0.9, "rival_lock": 1.1, "rival_hold": 1.8, "rival_salvo_gap": 2.5, "grace": 2.0},
}
const ROCKET_ID := "star_rocket"
const ROULETTE_SECONDS: float = STAR_COMPASS.STANDARD_SECONDS
const ITEM_HINTS_PATH := "user://kart_item_hints.cfg"
## Lock counts as "good enough" for homing from this progress on.
const LOCK_HOMING_THRESHOLD: float = 0.5

var rocket_phase: String = ""
var lock_target: int = -99
var lock_progress: float = 0.0
var player_grace_time: float = 0.0
var opponent_grace_times: Array[float] = []
var opponent_lock_times: Array[float] = []
var opponent_lock_targets: Array[int] = []
var opponent_rocket_hold: Array[float] = []
var opponent_pods: Array = []
var item_roulette_time: float = 0.0
var item_hint: String = ""
var item_hint_time: float = 0.0
var item_hints_seen: Dictionary = {}
var player_pods: Node3D
var item_hud: Control
var item_slot: Control
var player_warning: float = 0.0
var _lock_beep_timer: float = 0.0
var _warning_tone_timer: float = 0.0
var _lock_announced: bool = false
var _cheer_timer: float = 0.0
## After a salvo the sight rests briefly, so the flight stays the centre of attention.
var lock_rearm_time: float = 0.0
## Short world-anchored HUD call-outs ("TREFFER!", "ABGEPRALLT!").
var item_popups: Array[Dictionary] = []


func _popup(text: String, world: Vector3, color: Color) -> void:
	item_popups.append({"text": text, "world": world, "age": 0.0, "color": color})
	if item_popups.size() > 3:
		item_popups.pop_front()


func _lock_rules() -> Dictionary:
	return LOCK_RULES.get(difficulty, LOCK_RULES.normal)


func _build_item_experience() -> void:
	_load_item_hints()
	opponent_grace_times.clear()
	opponent_lock_times.clear()
	opponent_lock_targets.clear()
	opponent_rocket_hold.clear()
	opponent_pods.clear()
	for _i in range(opponents.size()):
		opponent_grace_times.append(0.0)
		opponent_lock_times.append(0.0)
		opponent_lock_targets.append(-99)
		opponent_rocket_hold.append(0.0)
		opponent_pods.append(null)
	player_pods = _make_pods(player)
	if is_instance_valid(item_runtime):
		item_runtime.quality = graphics_profile
	if not is_instance_valid(item_hud) and is_instance_valid(safe_ui):
		item_hud = ITEM_HUD.new()
		safe_ui.add_child(item_hud)
		safe_ui.move_child(item_hud, 0)
	if is_instance_valid(item_hud):
		item_hud.camera = camera
		item_hud.reduced_motion = reduced_motion
	if is_instance_valid(item_button) and not is_instance_valid(item_slot):
		item_slot = ITEM_HUD.new()
		item_slot.name = "ItemSlotOverlay"
		item_slot.mode = "slot"
		item_button.add_child(item_slot)


func _make_pods(kart: Node3D) -> Node3D:
	if not is_instance_valid(kart):
		return null
	var pods: Node3D = ROCKET_PODS.new()
	var body: String = "code"
	var production: Variant = kart.get("production_vehicle")
	if is_instance_valid(production):
		body = str(production.variant)
	pods.reduced_motion = reduced_motion
	kart.add_child(pods)
	if not pods.setup(body):
		pods.queue_free()
		return null
	return pods


func _reset_item_experience() -> void:
	rocket_phase = ""
	lock_target = -99
	lock_progress = 0.0
	player_grace_time = 0.0
	item_roulette_time = 0.0
	star_compass.clear()
	item_hint = ""
	player_warning = 0.0
	_lock_announced = false
	for i in range(opponent_grace_times.size()):
		opponent_grace_times[i] = 0.0
		opponent_lock_times[i] = 0.0
		opponent_lock_targets[i] = -99
		opponent_rocket_hold[i] = 0.0
	if is_instance_valid(player_pods):
		player_pods.deploy(0)
	for pods in opponent_pods:
		if is_instance_valid(pods):
			pods.deploy(0)


## Called whenever the player's held item changes (grant, restore, use up).
func _sync_player_rocket_phase() -> void:
	if item == ROCKET_ID and item_charges > 0:
		if rocket_phase.is_empty():
			rocket_phase = "ready"
		if is_instance_valid(player_pods):
			player_pods.deploy(item_charges)
			player_pods.arm(rocket_phase == "armed")
	else:
		rocket_phase = ""
		lock_target = -99
		lock_progress = 0.0
		if is_instance_valid(player_pods):
			player_pods.stow()


## Item box pickup: the slot wheel spins briefly, then the item is ready.
## Das Ergebnis steht schon fest (genau eine Ziehung); der Sternenkompass zeigt es nur.
func _grant_item_with_roulette(id: String, from_world: Vector3 = Vector3.ZERO) -> void:
	_grant_item(id)
	item_roulette_time = star_compass.start(id, reduced_motion, from_world)
	_sound_effect("roulette_tick")


## Ende der Darstellung: regulär oder per Tipp aufs Item-Feld übersprungen.
func _finish_item_roulette(skipped: bool) -> void:
	item_roulette_time = 0.0
	star_compass.finish(skipped)
	_sound_effect("roulette_done")
	message.text = "%s! Tippe ITEM." % str(ITEM_CATALOG.entry(item).get("name", "Überraschung"))
	_show_item_hint(item)


func _show_item_hint(id: String) -> void:
	if id not in [ROCKET_ID, "shield"] or bool(item_hints_seen.get(id, false)):
		return
	item_hint = id
	item_hint_time = 6.0


func _load_item_hints() -> void:
	var config := ConfigFile.new()
	if config.load(ITEM_HINTS_PATH) == OK:
		for key in [ROCKET_ID, "shield"]:
			item_hints_seen[key] = bool(config.get_value("seen", key, false))


func _mark_item_hint_seen(id: String) -> void:
	if item_hint == id:
		item_hint = ""
	if bool(item_hints_seen.get(id, false)):
		return
	item_hints_seen[id] = true
	var config := ConfigFile.new()
	for key in item_hints_seen:
		config.set_value("seen", key, item_hints_seen[key])
	config.save(ITEM_HINTS_PATH)


func _player_forward() -> Vector3:
	var forward := Vector3(-sin(player_heading), 0.0, -cos(player_heading))
	return forward.normalized()


## Nearest rival ahead inside the sight cone; keeps the current one unless another is
## clearly closer (no jitter between two rivals side by side).
func _pick_lock_target() -> int:
	var rules: Dictionary = _lock_rules()
	var origin: Vector3 = player.global_position
	var forward: Vector3 = _player_forward()
	var best: int = -99
	var best_distance: float = INF
	var current_distance: float = INF
	for i in range(opponents.size()):
		if i < opponent_grace_times.size() and opponent_grace_times[i] > 0.0:
			continue
		var offset: Vector3 = opponents[i].global_position - origin
		offset.y = 0.0
		var distance_m: float = offset.length()
		if distance_m < 2.0 or distance_m > float(rules.range):
			continue
		var cone: float = float(rules.cone) * (1.15 if i == lock_target else 1.0)
		if rad_to_deg(forward.angle_to(offset.normalized())) > cone:
			continue
		if i == lock_target:
			current_distance = distance_m
		if distance_m < best_distance:
			best_distance = distance_m
			best = i
	if lock_target >= 0 and current_distance < INF and best_distance > current_distance * 0.7:
		return lock_target
	return best


func _arm_rockets() -> void:
	rocket_phase = "armed"
	lock_target = -99
	lock_progress = 0.0
	_lock_announced = false
	if is_instance_valid(player_pods):
		player_pods.arm(true)
	_sound_effect("rocket_arm")
	_fx("rocket_fire", player.global_position + Vector3.UP * 0.6, 0.3)
	message.text = "Raketen scharf! Ziel suchen – nochmal tippen = FEUER!"
	_mark_item_hint_seen(ROCKET_ID)


func _fire_player_rockets() -> void:
	var target: int = lock_target if lock_progress >= LOCK_HOMING_THRESHOLD else -99
	var launches: Array = []
	if is_instance_valid(player_pods):
		launches = player_pods.take_pair()
	if is_instance_valid(item_runtime) and item_runtime.placer.is_valid():
		# Die Raketen erben das Kart-Tempo und sind schneller: man sieht sie wegfliegen.
		item_runtime.fire_pair(ROCKET_ID, -1, distance, lane, target, launches, maxf(0.0, speed))
		item_telemetry.note_salvo(-1, target, elapsed)
	_fx("rocket_fire", player.global_position + Vector3.UP * 0.7)
	_sound_effect("rocket_launch")
	camera_punch = maxf(camera_punch, 0.0 if reduced_motion else 0.42)
	message.text = (
		"FEUER! Sternraketen auf %s!" % _rival_name(target) if target >= 0
		else "FEUER! Sternraketen fliegen geradeaus!"
	)
	_consume_item()
	lock_progress = 0.0
	lock_target = -99
	lock_rearm_time = 0.9
	_lock_announced = false
	if item == ROCKET_ID:
		# Second salvo ready: stay armed and lock again.
		rocket_phase = "armed"
	_sync_player_rocket_phase()


func _update_player_lock(delta: float) -> void:
	if rocket_phase != "armed":
		return
	if lock_rearm_time > 0.0:
		lock_rearm_time = maxf(0.0, lock_rearm_time - delta)
		return
	var target: int = _pick_lock_target()
	if target != lock_target:
		# Switching springs the brackets back open; a quick re-lock is still easy.
		lock_progress = 0.0 if target < 0 else minf(lock_progress, 0.25)
		lock_target = target
		_lock_announced = false
	if lock_target < 0:
		return
	var before: float = lock_progress
	lock_progress = minf(1.0, lock_progress + delta / maxf(0.05, float(_lock_rules().lock)))
	_lock_beep_timer -= delta
	if lock_progress < 1.0 and _lock_beep_timer <= 0.0:
		_lock_beep_timer = lerpf(0.22, 0.09, lock_progress)
		_sound_effect("lock_beep", 1.0 + lock_progress * 0.6)
	if before < 1.0 and lock_progress >= 1.0 and not _lock_announced:
		_lock_announced = true
		_sound_effect("lock_on")
		message.text = "ZIEL ERFASST: %s – tippe FEUER!" % _rival_name(lock_target)


## Rival rocket logic: hold, lock (the player gets warned), then fire a pair.
func _update_rival_rockets(index: int, delta: float) -> bool:
	if index >= opponent_lock_times.size() or opponent_items[index] != ROCKET_ID:
		if index < opponent_lock_times.size():
			opponent_lock_times[index] = 0.0
			opponent_lock_targets[index] = -99
			opponent_rocket_hold[index] = 0.0
		_sync_rival_pods(index, 0, false)
		return false
	var rules: Dictionary = _lock_rules()
	opponent_rocket_hold[index] += delta
	var pairs: int = maxi(1, int(opponent_rival_charges(index)))
	_sync_rival_pods(index, pairs, opponent_lock_times[index] > 0.0)
	if opponent_rocket_hold[index] < float(rules.rival_hold) or opponent_item_cooldowns[index] > 0.0:
		return true
	var ahead: Dictionary = _neighbour(index, true)
	var target: int = int(ahead.key)
	var valid: bool = target != -99 and float(ahead.gap) < float(rules.range) * 0.8
	if target == -1 and player_grace_time > 0.0:
		valid = false
	if target == -1 and not rocket_fairness.child_targetable(self, index):
		valid = false
	if target >= 0 and not rocket_fairness.hit_allowed(self, target):
		valid = false
	if target >= 0 and opponent_grace_times[target] > 0.0:
		valid = false
	if not valid:
		opponent_lock_times[index] = 0.0
		opponent_lock_targets[index] = -99
		return true
	if opponent_lock_targets[index] != target:
		opponent_lock_targets[index] = target
		opponent_lock_times[index] = 0.0
	opponent_lock_times[index] += delta
	if opponent_lock_times[index] < float(rules.rival_lock):
		return true
	# Fire one pair from the rival's pods.
	var launches: Array = []
	var pods: Variant = opponent_pods[index]
	if is_instance_valid(pods):
		launches = pods.take_pair()
	if is_instance_valid(item_runtime) and item_runtime.placer.is_valid():
		item_runtime.fire_pair(ROCKET_ID, index, opponent_distances[index], opponent_lanes[index], target, launches)
		item_telemetry.note_salvo(index, target, elapsed)
	_fx("rocket_fire", opponents[index].global_position + Vector3.UP * 0.8, 0.5)
	if target == -1:
		message.text = "%s feuert Sternraketen auf dich – Schild!" % _rival_name(index)
		_sound_effect("rocket_launch")
	_stat("rival_items_used")
	opponent_lock_times[index] = 0.0
	opponent_lock_targets[index] = -99
	opponent_rocket_hold[index] = float(rules.rival_hold) - float(rules.rival_salvo_gap)
	var left: int = int(opponent_item_charges.get(index, 2)) - 1
	opponent_item_charges[index] = left
	if left <= 0:
		opponent_items[index] = ""
		opponent_item_charges.erase(index)
		opponent_item_cooldowns[index] = 3.0
	return true


var opponent_item_charges: Dictionary = {}


func opponent_rival_charges(index: int) -> int:
	if not opponent_item_charges.has(index):
		opponent_item_charges[index] = maxi(1, int(ITEM_CATALOG.entry(ROCKET_ID).get("charges", 2)))
	return int(opponent_item_charges[index])


func _sync_rival_pods(index: int, pairs: int, armed: bool) -> void:
	if index >= opponent_pods.size():
		return
	var pods: Variant = opponent_pods[index]
	if pairs <= 0:
		if is_instance_valid(pods):
			pods.stow()
		return
	if not is_instance_valid(pods):
		pods = _make_pods(opponents[index])
		opponent_pods[index] = pods
		if not is_instance_valid(pods):
			return
	if pods.pairs_left() != pairs:
		pods.deploy(pairs)
	pods.arm(armed)


func _update_item_experience(delta: float) -> void:
	rocket_fairness.observe(reset_count, elapsed, player_spin_time)
	player_grace_time = maxf(0.0, player_grace_time - delta)
	for i in range(opponent_grace_times.size()):
		opponent_grace_times[i] = maxf(0.0, opponent_grace_times[i] - delta)
	var roulette_before: float = item_roulette_time
	item_roulette_time = maxf(0.0, item_roulette_time - delta)
	var tick_pitch: float = star_compass.advance(delta, roulette_before, item_roulette_time)
	if tick_pitch > 0.0:
		_sound_effect("roulette_tick", tick_pitch)
	if roulette_before > 0.0 and item_roulette_time <= 0.0:
		_finish_item_roulette(false)
	if item_hint_time > 0.0:
		item_hint_time = maxf(0.0, item_hint_time - delta)
		if item_hint_time <= 0.0:
			item_hint = ""
	_update_player_lock(delta)
	for i in range(opponents.size()):
		_update_rival_rockets_safe(i, delta)
	# Warning: a rival is locking on, or rockets are on their way to the player.
	var locked_on: float = 0.0
	for i in range(opponent_lock_targets.size()):
		if opponent_lock_targets[i] == -1:
			locked_on = maxf(locked_on, clampf(opponent_lock_times[i] / maxf(0.1, float(_lock_rules().rival_lock)), 0.25, 1.0))
	var incoming: bool = is_instance_valid(item_runtime) and item_runtime.incoming_for(-1, distance) < INF
	player_warning = 1.0 if incoming else locked_on
	if player_warning > 0.0:
		_warning_tone_timer -= delta
		if _warning_tone_timer <= 0.0:
			_warning_tone_timer = 0.62
			_sound_effect("missile_warning", 1.12 if incoming else 1.0)
	else:
		_warning_tone_timer = 0.0
	if is_instance_valid(player_pods):
		player_pods.reduced_motion = reduced_motion
		player_pods.advance(delta)
	for pods in opponent_pods:
		if is_instance_valid(pods):
			pods.reduced_motion = reduced_motion
			pods.advance(delta)
	if is_instance_valid(item_runtime):
		for at in item_runtime.popped_debris():
			_fx("rocket_pop", at)
	if _cheer_timer > 0.0:
		_cheer_timer = maxf(0.0, _cheer_timer - delta)
		if _cheer_timer <= 0.0 and not finished and is_instance_valid(player):
			player.end_in_race_cheer()


func _update_rival_rockets_safe(index: int, delta: float) -> void:
	if index < opponent_items.size():
		_update_rival_rockets(index, delta)


func _update_item_hud(delta: float) -> void:
	if not is_instance_valid(item_hud):
		return
	for popup in item_popups:
		popup.age = float(popup.age) + delta
	item_popups = item_popups.filter(func(popup: Dictionary) -> bool: return float(popup.age) < 1.1)
	var shown_item: String = item
	var target_world := Vector3.ZERO
	var has_target: bool = rocket_phase == "armed" and lock_target >= 0 and lock_target < opponents.size()
	if has_target:
		target_world = opponents[lock_target].global_position + Vector3.UP * 1.0
	var shield_ready: bool = item == "shield" and item_roulette_time <= 0.0
	item_hud.reduced_motion = reduced_motion
	item_hud.camera = camera
	item_hud.visible = racing and not finished and not menu_active
	item_hud.push_state({
		"phase": rocket_phase if item_roulette_time <= 0.0 else "",
		"item": shown_item, "charges": item_charges,
		"item_color": ITEM_CATALOG.color(shown_item).to_html() if not shown_item.is_empty() else "#ffffff",
		"roulette": (
			item_roulette_time / maxf(0.01, star_compass.total) if item_roulette_time > 0.0 else 0.0
		),
		"compass": star_compass.hud_state(
			item_roulette_time, camera, player.global_position + Vector3.UP * 0.9
		),
		"has_target": has_target, "target": lock_target, "target_world": target_world,
		"target_name": _rival_name(lock_target) if has_target else "", "lock": lock_progress,
		# Hook kart-garage: echte Entfernung zum Ziel und Reichweite für den Entfernungsbalken.
		"target_distance": player.global_position.distance_to(opponents[lock_target].global_position) if has_target and is_instance_valid(player) else -1.0,
		"lock_range": float(_lock_rules().range),
		"rearm": lock_rearm_time,
		"popups": item_popups,
		"warning": player_warning, "incoming": is_instance_valid(item_runtime) and item_runtime.incoming_for(-1, distance) < INF,
		"shield_ready": shield_ready,
		"shield_left": shield_time, "shield_total": 6.0,
		"hint": item_hint if item_roulette_time <= 0.0 else "",
		"item_rect": item_button.get_global_rect() if is_instance_valid(item_button) and item_button.is_visible_in_tree() else Rect2(),
	}, delta)
	if is_instance_valid(item_slot):
		item_slot.reduced_motion = reduced_motion
		item_slot.push_state(item_hud.state, delta)


func _sync_rival_item_fx_all() -> void:
	for i in range(opponent_item_fx.size()):
		_sync_rival_item_fx(i)
