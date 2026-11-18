extends Node3D
## Lumo-Kart driving effects: everything the car does to the world and the world
## does back. Rail sparks and scrape streaks, brake marks and tyre smoke, launch
## dust, exhaust jets and heat wisps, drift sparks per tier, surface plumes,
## landing rings, slipstream wind, confetti for taking the lead, plus the matching
## sounds, the body's spring (nose dive, squat, roll) and the camera's jolt.
##
## The race owns every rule. This node only reads the real driving state once per
## physics tick (advance(), called from the race) and the two contact hooks
## (rail_contact(), landed()). Nothing fires without its event: no idle loops of
## effects, no fake bursts. Paused races emit nothing and freeze what is in flight.
## Reduced motion: no camera jolt, no FOV punch, no speed lines, calmer spring.
## Draw calls: at most five (sparks, soft particles, marks, speed lines, flames);
## HIGH adds two short-lived lights (turbo glow, rail-hit flash).
## Rivals near the player get the same effects on a strict per-profile budget.

const PARTICLES = preload("res://scripts/games/kart_fx/kart_fx_particles.gd")
const MARKS = preload("res://scripts/games/kart_fx/kart_fx_marks.gd")
const STYLES = preload("res://scripts/games/kart_fx/kart_fx_surface_styles.gd")
const RACE_RULES = preload("res://scripts/games/kart_items/kart_race_rules.gd")
const SPARK_SHADER = preload("res://assets/shaders/kart_fx_spark.gdshader")
const PUFF_SHADER = preload("res://assets/shaders/kart_fx_puff.gdshader")
const MARK_SHADER = preload("res://assets/shaders/kart_fx_decal.gdshader")
const LINES_SHADER = preload("res://assets/shaders/kart_fx_speedlines.gdshader")
const FLAME_SHADER = preload("res://assets/shaders/kart_fx_flame.gdshader")
const FLAMES = preload("res://scripts/games/kart_fx/kart_fx_flames.gd")
const PHOTO_FINISH = preload("res://scripts/games/kart_fx/kart_fx_photo_finish.gd")

## Quality budgets. HIGH asks a lot of the newest phones; LOW stays readable.
const BUDGETS := {
	"high": {"sparks": 2400, "puffs": 1400, "marks": 2200, "mark_life": 7.5, "rate": 1.0, "size": 1.15,
		"rivals": 4, "rival_rate": 0.35, "lights": true},
	"medium": {"sparks": 1200, "puffs": 700, "marks": 1100, "mark_life": 5.0, "rate": 0.6, "size": 1.0,
		"rivals": 2, "rival_rate": 0.25, "lights": false},
	"low": {"sparks": 420, "puffs": 240, "marks": 320, "mark_life": 3.0, "rate": 0.3, "size": 0.95,
		"rivals": 0, "rival_rate": 0.0, "lights": false},
}
const DRIFT_COLORS: Array[Color] = [
	Color(0.86, 0.93, 1.0), Color("4fb8ff"), Color("ff9a3c"), Color("c77dff")
]
const SPARK_HOT := Color(1.0, 0.86, 0.45)
const SPARK_WHITE := Color(1.0, 0.96, 0.82)
## Rail face: the premium rail's lower beam (RAIL_LATERAL 6.05, 0.55 m high) seen
## from a kart pressed against the collision wall (WALL_LATERAL 5.0).
const RAIL_OFFSET := 0.93
const RAIL_HEIGHT := 0.55
## Outer tyre edge of the production karts (measured 1.0 m; kart_rail_gap_probe).
const KART_SIDE := 0.98
const HARD_HIT := 4.0

var race: Node
var profile: String = ""
var budget: Dictionary = BUDGETS.medium
var style: Dictionary = STYLES.ASPHALT
var reduced_motion: bool = false
var sparks: MultiMeshInstance3D
var puffs: MultiMeshInstance3D
var marks: MultiMeshInstance3D
var speed_lines: MeshInstance3D
var flames: MultiMeshInstance3D
var photo_finish: Node
var flash_light: OmniLight3D
var flash: float = 0.0
var boost_age: float = 0.0
var afterglow: float = 0.0
var light_tint := Color.WHITE
var counts: Dictionary = {}
var sounds: Dictionary = {}
var pitch: float = 0.0
var roll: float = 0.0
var shake: float = 0.0
var fov_punch: float = 0.0
var line_intensity: float = 0.0
var rpm: float = 0.0
var load: float = 0.0
var scrape_level: float = 0.0

var _rng := RandomNumberGenerator.new()
var _accumulators: Dictionary = {}
var _contacts: Array[Dictionary] = []
var _scrape_time: Dictionary = {}
var _hit_cooldown: Dictionary = {}
var _pitch_velocity: float = 0.0
var _roll_velocity: float = 0.0
var _accel: float = 0.0
var _previous_speed: float = 0.0
var _previous_gas: bool = false
var _previous_boost: bool = false
var _previous_place: int = 0
var _place_clock: float = 0.0
var _clock: float = 0.0
var _backfire_cooldown: float = 0.0
var _confetti_cooldown: float = 0.0
var _tilt_applied: bool = false
var _tilt_base := Basis.IDENTITY
var _tilt_basis := Basis.IDENTITY
var _shake_phase: float = 0.0
var _shaken_camera: Camera3D
var _camera_offset := Vector3.ZERO
var _zoomed_camera: Camera3D
var _zoom_offset: float = 0.0
var _racing_speed: float = 0.0
var _rival_afterglow: Dictionary = {}


func _ready() -> void:
	name = "KartDriveFx"
	_rng.seed = 20261118
	# Restore the physics basis before the race's own physics tick reads it.
	process_physics_priority = -100
	sparks = PARTICLES.new()
	add_child(sparks)
	sparks.setup("KartFxSparks", SPARK_SHADER, 64)
	sparks.spark_layout = true
	puffs = PARTICLES.new()
	add_child(puffs)
	puffs.setup("KartFxSoft", PUFF_SHADER, 64)
	marks = MARKS.new()
	add_child(marks)
	marks.setup(MARK_SHADER, 64)
	speed_lines = MeshInstance3D.new()
	speed_lines.name = "KartFxSpeedLines"
	speed_lines.mesh = _edge_ring()
	speed_lines.top_level = true
	speed_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	speed_lines.extra_cull_margin = 16384.0
	speed_lines.custom_aabb = AABB(Vector3.ONE * -1.0e5, Vector3.ONE * 2.0e5)
	var lines_material := ShaderMaterial.new()
	lines_material.shader = LINES_SHADER
	lines_material.render_priority = 4
	speed_lines.material_override = lines_material
	speed_lines.visible = false
	add_child(speed_lines)
	flames = FLAMES.new()
	add_child(flames)
	flames.setup(FLAME_SHADER)
	flash_light = OmniLight3D.new()
	flash_light.name = "KartFxImpactLight"
	flash_light.top_level = true
	flash_light.omni_range = 5.0
	flash_light.light_color = Color(1.0, 0.78, 0.45)
	flash_light.shadow_enabled = false
	flash_light.visible = false
	add_child(flash_light)
	photo_finish = PHOTO_FINISH.new()
	add_child(photo_finish)
	_apply_profile("medium")


func bind_race(owner: Node) -> void:
	race = owner
	style = STYLES.for_track(str(race.track_id))
	_apply_profile(str(race.graphics_profile))
	_read_light_tint()
	reset()


## Smoke and dust take on the scene's sunlight (warm desert, cold night lava).
func _read_light_tint() -> void:
	light_tint = Color.WHITE
	var root: Node = race.get("world") if is_instance_valid(race.get("world")) else race
	var suns := root.find_children("*", "DirectionalLight3D", true, false)
	if suns.is_empty():
		suns = race.find_children("*", "DirectionalLight3D", true, false)
	if not suns.is_empty():
		var sun: DirectionalLight3D = suns[0]
		var lit: Color = sun.light_color * clampf(sun.light_energy, 0.45, 1.15)
		light_tint = Color(1, 1, 1).lerp(lit, 0.45)
	puffs.set_parameter("light_tint", Vector3(light_tint.r, light_tint.g, light_tint.b))


func _apply_profile(next: String) -> void:
	if not BUDGETS.has(next):
		next = "medium"
	if next == profile:
		return
	profile = next
	budget = BUDGETS[next]
	sparks.resize(int(budget.sparks))
	puffs.resize(int(budget.puffs))
	marks.resize(int(budget.marks))
	flames.light_enabled = bool(budget.lights)


func reset() -> void:
	if not is_instance_valid(sparks):
		return
	sparks.clear()
	puffs.clear()
	marks.clear()
	_contacts.clear()
	_scrape_time.clear()
	_accumulators.clear()
	_restore_tilt()
	pitch = 0.0
	roll = 0.0
	_pitch_velocity = 0.0
	_roll_velocity = 0.0
	shake = 0.0
	fov_punch = 0.0
	line_intensity = 0.0
	scrape_level = 0.0
	speed_lines.visible = false
	flames.clear()
	flash = 0.0
	flash_light.visible = false
	boost_age = 0.0
	afterglow = 0.0
	_rival_afterglow.clear()
	_previous_place = 0
	_previous_boost = false
	_silence()


func _physics_process(_delta: float) -> void:
	_restore_tilt()
	_restore_camera()
	_restore_zoom()


## The camera jolt is laid on after the race has placed its camera (render time)
## and taken off again before the next race tick, so the chase camera's own
## smoothing never sees it.
func _process(_delta: float) -> void:
	_restore_camera()
	_restore_zoom()
	if not is_instance_valid(race):
		return
	photo_finish.watch(race, _racing_speed)
	var camera_node: Camera3D = race.get("camera")
	var zoom: float = photo_finish.zoom()
	if zoom != 0.0 and is_instance_valid(camera_node):
		_zoom_offset = zoom
		camera_node.fov += zoom
		_zoomed_camera = camera_node
	if bool(race.get("paused")):
		return
	var camera: Camera3D = race.get("camera")
	var jolt := camera_shake()
	if is_instance_valid(camera) and jolt != Vector3.ZERO:
		_camera_offset = camera.basis * jolt
		camera.position += _camera_offset
		_shaken_camera = camera


func _restore_zoom() -> void:
	if is_instance_valid(_zoomed_camera):
		_zoomed_camera.fov -= _zoom_offset
	_zoomed_camera = null
	_zoom_offset = 0.0


func _exit_tree() -> void:
	photo_finish.stop()
	_restore_zoom()
	_restore_camera()


func _restore_camera() -> void:
	if is_instance_valid(_shaken_camera):
		_shaken_camera.position -= _camera_offset
	_shaken_camera = null
	_camera_offset = Vector3.ZERO


# --- hooks from the race -----------------------------------------------------


## A kart (player or rival) is pressed against the rail this tick.
## [param outward] points from the kart towards the rail (world space).
func rail_contact(kart: Node3D, outward: Vector3, into_wall: float, speed: float) -> void:
	if not is_instance_valid(kart) or into_wall <= 0.0:
		return
	_contacts.append({
		"kart": kart, "outward": outward.normalized(), "into": into_wall, "speed": absf(speed),
		"offset": _rail_offset(kart, outward.normalized()),
	})


## Distance from the kart's centre to the visible rail face. The collision wall
## and the rail mesh are separate; where they sit far apart (curbs, wide
## sections) the sparks come from the kart's side instead of thin air.
func _rail_offset(kart: Node3D, outward: Vector3) -> float:
	var world = race.get("world") if is_instance_valid(race) else null
	if kart != race.player or world == null or not world.has_method("position_at") or world.get("RAIL_LATERAL") == null:
		return RAIL_OFFSET
	var side := signf(float(race.lane))
	if side == 0.0:
		return RAIL_OFFSET
	var rail_local: Vector3 = world.position_at(float(race.distance), side * float(world.RAIL_LATERAL))
	var rail: Vector3 = (kart.get_parent() as Node3D).to_global(rail_local) if kart.get_parent() is Node3D else rail_local
	return clampf((rail - kart.global_position).dot(outward) - 0.08, 0.6, 3.0)


## The player's kart touched down after a jump ([param impact] = sink speed m/s).
func landed(impact: float, surface_frame: Basis) -> void:
	if not _can_emit() or impact < 2.0:
		return
	var kart: Node3D = race.player
	var up := surface_frame.orthonormalized().y
	var center := kart.global_position + up * 0.06
	var strength := clampf((impact - 2.0) / 9.0, 0.0, 1.0)
	var rate: float = float(budget.rate)
	var dust := maxi(8, int((18.0 + 46.0 * strength) * maxf(0.45, rate)))
	var dust_color: Color = style.smoke
	for index in range(dust):
		var angle := TAU * float(index) / float(dust) + _rng.randf() * 0.3
		var flat := Vector3(cos(angle), 0.0, sin(angle))
		puffs.spawn(
			center + flat * 0.7, flat * _rng.randf_range(3.0, 6.5) * (0.7 + strength) + up * _rng.randf_range(0.2, 1.2),
			0.35 * _size(), _rng.randf_range(1.0, 1.8) * float(style.dust_scale) * _size(), 0.0,
			_rng.randf_range(0.7, 1.2), -0.03, _tone(dust_color, 0.06), Color(2.6, _rng.randf(), 0.6, 0.0)
		)
	_count("landing_dust", dust)
	if impact > 6.0:
		var burst := maxi(10, int((20.0 + 40.0 * strength) * maxf(0.4, rate)))
		for index in range(burst):
			var flat := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)).normalized()
			sparks.spawn(
				center + flat * 0.4, flat * _rng.randf_range(4.0, 9.0) + up * _rng.randf_range(1.0, 3.5),
				0.07 * _size(), 0.015, 0.03, _rng.randf_range(0.25, 0.5), 1.0, SPARK_WHITE,
				Color(1.6, _rng.randf(), 1.0, 0.9)
			)
		_count("landing_sparks", burst)
	if not reduced_motion:
		_pitch_velocity -= 0.6 + strength * 1.6
		shake = maxf(shake, 0.02 + strength * 0.07)
	_sound("land_thump", 0.95 + _rng.randf() * 0.1, 0.45 + strength * 0.55)


# --- per tick ------------------------------------------------------------------


func advance(delta: float) -> void:
	if not is_instance_valid(race) or not is_instance_valid(race.player):
		return
	var kart: Node3D = race.player
	_restore_tilt()
	_apply_profile(str(race.graphics_profile))
	reduced_motion = bool(race.reduced_motion)
	if bool(race.paused):
		# Frozen frame: no time passes, nothing is born, the pose stays.
		_contacts.clear()
		_apply_tilt(kart)
		return
	var step := clampf(delta, 0.0, 0.1)
	_clock += step
	var focus := kart.global_position
	sparks.advance(step, focus)
	puffs.advance(step, focus)
	marks.advance(step, focus)
	flames.begin(step, focus)
	_update_flash(step)
	var active: bool = bool(race.racing) and not bool(race.finished) and not bool(race.menu_active)
	if not active:
		_contacts.clear()
		marks.lift_all()
		flames.finish()
		_settle(step, kart)
		_update_engine(step, false)
		_silence(true)
		_update_lines(step, false)
		return
	var speed: float = absf(float(race.speed))
	_racing_speed = speed
	var ratio := clampf(speed / 25.0, 0.0, 1.0)
	var grounded: bool = not bool(race.airborne)
	var gas: bool = race._gas_active()
	var braking: float = clampf(float(race.brake_visual_amount), 0.0, 1.0)
	var boosting: bool = float(race.boost_time) > 0.0 and speed > 0.5
	var drifting: bool = bool(race.drifting) and absf(float(race.steering)) > 0.2 and speed > 1.0 and grounded
	var tier := _drift_tier(float(race.drift_charge)) if drifting else 0
	var heading: float = float(race.player_heading)
	var frame: Basis = kart.get_parent().global_basis if kart.get_parent() is Node3D else Basis.IDENTITY
	var forward := (frame * Vector3(-sin(heading), 0.0, -cos(heading))).normalized()
	var up := (frame * Vector3.UP).normalized()
	var right := forward.cross(up).normalized()
	var raw_accel := (float(race.speed) - _previous_speed) / maxf(step, 0.001)
	_previous_speed = float(race.speed)
	_accel = lerpf(_accel, clampf(raw_accel, -60.0, 40.0), minf(1.0, step * 9.0))
	var tyres := _rear_tyres(kart)
	_backfire_cooldown = maxf(0.0, _backfire_cooldown - step)
	_confetti_cooldown = maxf(0.0, _confetti_cooldown - step)
	for key in _hit_cooldown.keys():
		_hit_cooldown[key] = maxf(0.0, float(_hit_cooldown[key]) - step)

	_process_contacts(step, forward, up)
	var squeal := 0.0
	# Brake: rubber on the road, squeal by speed, glowing lamps, smoke at full stop.
	var brake_marking := braking > 0.35 and speed > 4.0 and grounded
	if braking > 0.05:
		_count("brake_glow", 1)
		for index in range(kart.brake_lights.size()):
			var lamp: Node3D = kart.brake_lights[index]
			if is_instance_valid(lamp) and index < 2:
				sparks.pin(index, lamp.global_position - forward * 0.04, 0.55 * (0.5 + braking * 0.5), 0.07,
					Color(1.0, 0.16, 0.12, 0.85 * braking))
	if brake_marking:
		squeal = maxf(squeal, clampf((speed - 4.0) / 18.0, 0.0, 1.0) * braking)
		for index in range(tyres.size()):
			_mark("brake:%d" % index, tyres[index].global_position, up, 0.3, braking * clampf(speed / 12.0, 0.5, 1.0))
		if braking > 0.6 and speed > 6.0:
			# Billowing smoke: amount and size grow with speed, little at walking pace.
			var heat := clampf((speed - 6.0) / 18.0, 0.0, 1.0)
			_tyre_smoke("brake_smoke", tyres, forward, up, step, (30.0 + 120.0 * heat) * braking,
				Color(0.88, 0.88, 0.9, 0.55 + 0.25 * heat), 1.1 + 0.9 * heat)
	else:
		marks.lift("brake:0")
		marks.lift("brake:1")
	# Drift: tier-coloured sparks, tyre smoke, marks, squeal.
	if drifting:
		var color: Color = DRIFT_COLORS[tier]
		var side := signf(float(race.steering))
		var rate := (36.0 + 85.0 * float(tier)) * float(budget.rate)
		for index in range(tyres.size()):
			var at: Vector3 = tyres[index].global_position + up * 0.05
			var count := _emit("drift_sparks:%d" % index, rate, step)
			for _n in range(count):
				sparks.spawn(
					at, forward * speed * _rng.randf_range(0.3, 0.62) - right * side * _rng.randf_range(0.8, 3.0)
					+ up * _rng.randf_range(1.2, 3.8),
					(0.09 + 0.03 * float(tier)) * _size(), 0.02, 0.045, _rng.randf_range(0.25, 0.48), 0.9,
					color, Color(2.2, _rng.randf(), 0.0, 0.3)
				)
			_count("drift_sparks", count)
			_mark("drift:%d" % index, tyres[index].global_position, up, 0.28, 0.9)
		if float(style.debris_rate) > 0.3:
			for index in range(tyres.size()):
				var grains := _emit("drift_debris:%d" % index, 28.0 * float(style.debris_rate) * float(budget.rate), step)
				for _n in range(grains):
					puffs.spawn(tyres[index].global_position + up * 0.06,
						forward * speed * 0.3 - right * side * _rng.randf_range(2.0, 5.0) + up * _rng.randf_range(1.5, 3.5),
						_rng.randf_range(0.05, 0.1) * _size(), 0.05, 0.0, _rng.randf_range(0.5, 0.8), 1.0,
						_tone(style.debris, 0.15), Color(0.3, _rng.randf(), _rng.randf_range(-9.0, 9.0), float(style.debris_kind)))
				_count("drift_debris", grains)
		var tint: Color = Color(style.smoke).lerp(color, 0.18 if tier > 0 else 0.0)
		var loose := float(style.dust_scale)
		_tyre_smoke("drift_smoke", tyres, forward, up, step, (34.0 + 10.0 * float(tier)) * loose, tint, 1.2 * loose)
		squeal = maxf(squeal, 0.55 + 0.12 * float(tier))
	else:
		marks.lift("drift:0")
		marks.lift("drift:1")
	# Launch: gas from (almost) standstill digs in, throws dust and pebbles back.
	if gas and grounded and speed < 13.0 and _accel > 1.5:
		var dig := clampf(1.0 - speed / 13.0, 0.15, 1.0)
		_tyre_smoke("launch_dust", tyres, forward, up, step, 70.0 * dig * float(style.dust_scale), style.smoke, float(style.dust_scale))
		var debris_rate := 60.0 * dig * float(style.debris_rate) * float(budget.rate)
		for index in range(tyres.size()):
			var count := _emit("launch_debris:%d" % index, debris_rate, step)
			for _n in range(count):
				puffs.spawn(
					tyres[index].global_position + up * 0.05,
					-forward * _rng.randf_range(2.5, 7.0) + up * _rng.randf_range(1.5, 4.0)
					+ right * _rng.randf_range(-1.2, 1.2),
					_rng.randf_range(0.05, 0.1) * _size(), 0.05, 0.0, _rng.randf_range(0.5, 0.9), 1.0,
					_tone(style.debris, 0.12), Color(0.25, _rng.randf(), _rng.randf_range(-9.0, 9.0),
						float(style.debris_kind))
				)
			_count("launch_debris", count)
		if speed < 6.0:
			for index in range(tyres.size()):
				_mark("launch:%d" % index, tyres[index].global_position, up, 0.2, 0.7 * dig)
	else:
		marks.lift("launch:0")
		marks.lift("launch:1")
	# Lift-off at speed: a soft overrun pop from the exhaust (Lastwechsel).
	if _previous_gas and not gas and speed > 10.0 and _backfire_cooldown <= 0.0:
		_backfire(kart, forward)
	_previous_gas = gas
	# Boost: exhaust jets, heat wisps, swirling air, speed lines, FOV punch.
	if boosting:
		boost_age = 0.0 if not _previous_boost else boost_age + step
		_boost_effects(kart, forward, up, right, speed, step, not _previous_boost)
		afterglow = 1.0
	else:
		afterglow = move_toward(afterglow, 0.0, step / 1.6)
	_kart_flames(kart, forward, up, boosting, boost_age, afterglow, 1.0, 0.0)
	_previous_boost = boosting
	_rivals(forward, step)
	flames.finish()
	_surface_trail(tyres, forward, up, speed, step, grounded and not drifting and not brake_marking)
	_slipstream(kart, forward, up, speed, step)
	_lead_confetti(kart, up)
	_update_lines(step, boosting and not reduced_motion)
	# Body spring: nose dive when braking, squat on gas, lean in turns.
	var target_pitch := clampf(_accel * 0.0032, -0.075, 0.045)
	var target_roll := clampf(float(race.steering) * ratio * 0.05 * (1.4 if drifting else 1.0), -0.07, 0.07)
	_spring(step, target_pitch, target_roll)
	_apply_tilt(kart)
	shake = maxf(0.0, shake - step * maxf(0.12, shake * 6.0))
	fov_punch = move_toward(fov_punch, 0.0, step * 7.0)
	_shake_phase += step
	# Sound: the layered engine and the loops follow the same state.
	_update_engine(step, true, gas, boosting, speed)
	_set_loop("scrape", scrape_level, 0.75 + speed / 30.0)
	_set_loop("squeal", squeal, 0.85 + speed / 45.0 + 0.05 * float(tier))
	var rolling := ratio * (1.0 if grounded else 0.0)
	var loop_kind: String = str(style.loop)
	_set_loop("gravel", rolling * 0.9 if loop_kind == "gravel" else 0.0, 0.8 + ratio * 0.5)
	_set_loop("snow", rolling * 0.9 if loop_kind == "snow" else 0.0, 0.8 + ratio * 0.45)
	_set_loop("turbo", 0.85 if boosting else 0.0, 1.0 + ratio * 0.2)
	_set_loop("wind", ratio * ratio * 0.75 + (0.25 if not grounded else 0.0), 0.8 + ratio * 0.5)


func _process_contacts(step: float, forward: Vector3, up: Vector3) -> void:
	var player_scraping := false
	var seen := {}
	for contact in _contacts:
		var kart: Node3D = contact.kart
		if not is_instance_valid(kart):
			continue
		var is_player: bool = kart == race.player
		var id := kart.get_instance_id()
		seen[id] = true
		# Rivals far behind or ahead are not worth a particle.
		if not is_player and race.player.global_position.distance_to(kart.global_position) > 45.0:
			continue
		var into: float = float(contact.into)
		var speed: float = float(contact.speed)
		var outward: Vector3 = contact.outward
		var along := (outward.cross(up)).normalized()
		if along.dot(forward) < 0.0:
			along = -along
		_scrape_time[id] = float(_scrape_time.get(id, 0.0)) + step
		var duration: float = _scrape_time[id]
		var offset: float = float(contact.get("offset", RAIL_OFFSET))
		var on_rail := offset <= KART_SIDE + 0.45
		var at := kart.global_position + outward * (offset if on_rail else KART_SIDE) + up * (RAIL_HEIGHT if on_rail else 0.28)
		var pace := clampf(speed / 25.0, 0.0, 1.0)
		var rate := (200.0 + 1300.0 * pace) * (0.55 + minf(duration, 1.2) * 0.6) * clampf(into / 2.5 + 0.45, 0.45, 1.7)
		rate *= float(budget.rate) * (1.0 if is_player else 0.6)
		var count := _emit("rail:%d" % id, rate, step)
		for _n in range(count):
			var jitter := along * _rng.randf_range(-0.35, 0.25) + up * _rng.randf_range(-0.18, 0.2)
			sparks.spawn(
				at + jitter,
				along * speed * _rng.randf_range(0.12, 0.55) - outward * _rng.randf_range(0.6, 3.4)
				+ up * _rng.randf_range(1.2, 6.0) + Vector3(_rng.randf_range(-0.8, 0.8), 0, _rng.randf_range(-0.8, 0.8)),
				_rng.randf_range(0.09, 0.16) * _size(), 0.02, 0.045, _rng.randf_range(0.35, 0.9), 1.0,
				SPARK_HOT.lerp(SPARK_WHITE, _rng.randf()), Color(1.6, _rng.randf(), 1.0, 0.9),
				kart.global_position.y + 0.02
			)
		_count("rail_sparks", count)
		# The hot contact patch itself glows while metal grinds on metal.
		if count > 0:
			sparks.spawn(at - outward * 0.05, along * speed * 0.5, 0.75 * _size() * (0.7 + pace * 0.6), 0.3, 0.0, 0.07,
				0.0, Color(1.0, 0.72, 0.36, 0.75), Color(1.0, _rng.randf(), 0.0, 0.4))
		if speed > 3.0 and on_rail:
			var streak := kart.global_position + outward * (offset - 0.02) + up * RAIL_HEIGHT
			# Glows hot where metal met metal, then cools to a dark scratch.
			if marks.stroke("rail:%d" % id, streak, outward, 0.14, Color(0.09, 0.09, 0.11, 0.9),
					float(budget.mark_life), 3):
				_count("rail_marks", 1)
		elif speed > 3.0:
			# Wall short of the rail: the outer tyres scrub a dark mark on the curb line.
			var scuff := kart.global_position + outward * (KART_SIDE - 0.1) + up * 0.03
			var color: Color = style.mark
			if marks.stroke("rail:%d" % id, scuff, up, 0.26, color, float(budget.mark_life), int(style.mark_kind)):
				_count("rail_marks", 1)
		if is_player:
			player_scraping = true
			scrape_level = maxf(scrape_level, clampf(0.35 + pace * 0.65, 0.0, 1.0) * clampf(into / 1.5 + 0.5, 0.5, 1.0))
		var cooldown: float = float(_hit_cooldown.get(id, 0.0))
		if into > HARD_HIT and cooldown <= 0.0:
			_hit_cooldown[id] = 0.45
			_rail_hit(kart, at, outward, up, into, is_player)
		elif is_player and into > 1.6 and cooldown <= 0.0:
			_hit_cooldown[id] = 0.35
			_sound("rail_hit_soft", 0.9 + _rng.randf() * 0.2, 0.6)
	_contacts.clear()
	for id in _scrape_time.keys():
		if not seen.has(id):
			_scrape_time.erase(id)
			marks.lift("rail:%d" % id)
	if not player_scraping:
		scrape_level = move_toward(scrape_level, 0.0, step * 6.0)


func _rail_hit(kart: Node3D, at: Vector3, outward: Vector3, up: Vector3, into: float, is_player: bool) -> void:
	var strength := clampf((into - HARD_HIT) / 10.0, 0.0, 1.0)
	var burst := int((60.0 + 160.0 * strength) * maxf(0.4, float(budget.rate)) * (1.0 if is_player else 0.6))
	var travel: Vector3 = (outward.cross(up)).normalized()
	var kart_speed: float = absf(float(kart.get("motion_speed"))) if kart.get("motion_speed") != null else 15.0
	if travel.dot(-kart.global_basis.z) < 0.0:
		travel = -travel
	var ground := kart.global_position.y + 0.02
	for _n in range(burst):
		# A fan thrown forward along the rail (the kart's momentum) and off the wall.
		var dir := (travel * _rng.randf_range(0.6, 1.6) - outward * _rng.randf_range(0.1, 0.9)
			+ up * _rng.randf_range(0.2, 1.3) + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * 0.5).normalized()
		sparks.spawn(at, dir * _rng.randf_range(4.0, 12.0) + travel * kart_speed * 0.35,
			_rng.randf_range(0.1, 0.19) * _size(), 0.02, 0.045,
			_rng.randf_range(0.4, 0.95), 1.0, SPARK_WHITE, Color(1.4, _rng.randf(), 1.0, 1.0), ground)
	# Paint flakes in the kart's own colour flutter down (nobody is hurt, the kart just scuffs).
	var paint: Color = kart.get("vehicle_color") if kart.get("vehicle_color") != null else Color("357cba")
	var flakes := int((10.0 + 18.0 * strength) * maxf(0.4, float(budget.rate)))
	for _n in range(flakes):
		puffs.spawn(at - outward * 0.15, travel * _rng.randf_range(1.0, 4.0) - outward * _rng.randf_range(0.5, 2.0)
			+ up * _rng.randf_range(1.5, 3.5), _rng.randf_range(0.05, 0.09) * _size(), 0.05, 0.0,
			_rng.randf_range(0.8, 1.3), 0.45, _tone(paint, 0.1), Color(1.2, _rng.randf(), _rng.randf_range(6.0, 12.0), 4.0))
	_count("paint_flakes", flakes)
	if not reduced_motion:
		flash = maxf(flash, 0.6 + strength * 0.6)
		flash_light.global_position = at - outward * 0.3 + up * 0.3
		_update_flash(0.0)
	# One soft glow at the impact point (small and world-anchored, never a screen flash).
	sparks.spawn(at, Vector3.ZERO, (0.9 if reduced_motion else 1.6) * (0.8 + strength), 0.4, 0.0, 0.16, 0.0,
		Color(1.0, 0.8, 0.45, 0.55 if reduced_motion else 0.9), Color(1.0, 0.0, 0.0, 0.5))
	_count("rail_burst", burst)
	_count("rail_flash", 1 if not reduced_motion else 0)
	# The driver flinches briefly (the real Lumo / 3D rivals use their hit lean).
	if "driver_hit_pending" in kart:
		kart.driver_hit_pending = true
	if is_player:
		if not reduced_motion:
			shake = maxf(shake, 0.05 + strength * 0.12)
			var side := signf(outward.dot(race.player.global_basis.x))
			_roll_velocity += side * (1.2 + strength * 2.4)
			_pitch_velocity -= 0.4 + strength * 0.8
		else:
			_roll_velocity += signf(outward.dot(race.player.global_basis.x)) * 0.4
		_sound("rail_hit", 0.92 + _rng.randf() * 0.16, 0.7 + strength * 0.3)
		var audio = race.get("kart_audio")
		if is_instance_valid(audio) and audio.has_method("duck"):
			audio.duck(0.3)
	else:
		if race.player.global_position.distance_to(kart.global_position) < 18.0:
			_sound("rail_hit_soft", 0.95 + _rng.randf() * 0.15, 0.45)


func _boost_effects(kart: Node3D, forward: Vector3, up: Vector3, right: Vector3, speed: float, step: float, started: bool) -> void:
	var exhausts: Array[Node3D] = []
	for flame in kart.flames:
		if is_instance_valid(flame) and exhausts.size() < 2:
			exhausts.append(flame)
	var rate := 45.0 * float(budget.rate)
	for index in range(exhausts.size()):
		var at: Vector3 = exhausts[index].global_position + forward * 0.02
		var count := _emit("jet:%d" % index, rate, step)
		for _n in range(count):
			var hot := _rng.randf()
			sparks.spawn(
				at, forward * (speed - _rng.randf_range(5.0, 10.0)) + up * _rng.randf_range(-0.3, 0.6)
				+ right * _rng.randf_range(-0.5, 0.5),
				_rng.randf_range(0.24, 0.36) * _size(), 0.05, 0.014, _rng.randf_range(0.12, 0.26), -0.15,
				Color("8fe8ff").lerp(Color("ffb347"), hot), Color(3.5, _rng.randf(), hot, 0.7)
			)
		_count("boost_jet", count)
		var wisps := _emit("heat:%d" % index, 16.0 * maxf(0.5, float(budget.rate)), step)
		for _n in range(wisps):
			puffs.spawn(at - forward * 0.25, forward * (speed * 0.7) + up * _rng.randf_range(0.4, 1.0),
				0.35 * _size(), 1.1 * _size(), 0.0, _rng.randf_range(0.35, 0.55), -0.04,
				Color(1.0, 0.92, 0.8, 0.12), Color(2.0, _rng.randf(), 1.5, 3.0))
		_count("heat", wisps)
	# Swirling air around the body: thin bright streaks spiralling past.
	var swirl := _emit("swirl", 34.0 * float(budget.rate), step)
	for _n in range(swirl):
		var angle := _rng.randf() * TAU
		var around := right * cos(angle) + up * (sin(angle) * 0.6 + 0.6)
		var tangent := (right * -sin(angle) + up * cos(angle) * 0.6).normalized()
		sparks.spawn(kart.global_position + around * _rng.randf_range(0.9, 1.4) + forward * _rng.randf_range(-0.5, 1.4),
			forward * speed * 0.55 + tangent * 3.0, 0.035, 0.02, 0.06, _rng.randf_range(0.25, 0.4), 0.0,
			Color(0.85, 0.97, 1.0, 0.4), Color(1.0, 0.0, 0.0, 0.3))
	_count("swirl", swirl)
	if started:
		_count("boost_start", 1)
		_sound("whoosh", 1.0, 0.7)
		if not reduced_motion:
			fov_punch = maxf(fov_punch, 5.0)


func _surface_trail(tyres: Array[Node3D], forward: Vector3, up: Vector3, speed: float, step: float, cruising: bool) -> void:
	var trail: float = float(style.trail)
	if cruising and trail > 0.0 and speed > 9.0:
		var amount := clampf((speed - 9.0) / 16.0, 0.2, 1.0) * trail
		# A real plume: dense near the tyres, lingering and rising behind the kart.
		var slip := 1.0 + clampf(absf(float(race.steering)), 0.0, 1.0) * 0.6
		_tyre_smoke("surface_trail", tyres, forward, up, step, 70.0 * amount * slip, style.smoke,
			float(style.dust_scale) * 1.6, 1.6)
		if str(style.name) == "snow":
			# Powder snow glitters in the light.
			for index in range(tyres.size()):
				var glitter := _emit("glitter:%d" % index, 26.0 * amount * float(budget.rate), step)
				for _n in range(glitter):
					sparks.spawn(tyres[index].global_position + up * 0.2 + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4)),
						forward * speed * 0.3 + up * _rng.randf_range(0.8, 2.2) + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)),
						0.07 * _size(), 0.03, 0.0, _rng.randf_range(0.6, 1.1), 0.08, Color(0.85, 0.95, 1.0, 0.9),
						Color(1.5, _rng.randf(), 0.0, 0.8))
				_count("snow_glitter", glitter)
		if int(style.debris_kind) == 2:
			for index in range(tyres.size()):
				var leaves := _emit("leaves:%d" % index, 16.0 * amount * float(budget.rate), step)
				for _n in range(leaves):
					puffs.spawn(tyres[index].global_position + up * 0.1,
						-forward * _rng.randf_range(1.0, 3.0) + up * _rng.randf_range(2.0, 3.6)
						+ Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)),
						0.17 * _size(), 0.15, 0.0, _rng.randf_range(1.1, 1.7), 0.18,
						[Color("8bc34a"), Color("f2a33a"), Color("c8642c")][_rng.randi() % 3],
						Color(1.6, _rng.randf(), _rng.randf_range(-5.0, 5.0), 2.0))
				_count("surface_leaves", leaves)
	if bool(style.embers) and speed > 4.0:
		for index in range(tyres.size()):
			var embers := _emit("embers:%d" % index, (16.0 + speed * 2.2) * float(budget.rate), step)
			for _n in range(embers):
				sparks.spawn(tyres[index].global_position + up * 0.05,
					forward * speed * 0.2 + up * _rng.randf_range(1.0, 2.6) + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)),
					_rng.randf_range(0.09, 0.15) * _size(), 0.03, 0.03, _rng.randf_range(0.7, 1.4), -0.06,
					Color(1.0, 0.5, 0.12, 1.0), Color(1.4, _rng.randf(), 0.5, 0.5))
			_count("embers", embers)


func _slipstream(kart: Node3D, forward: Vector3, up: Vector3, speed: float, step: float) -> void:
	var charge: float = float(race.get("slipstream_charge")) if race.get("slipstream_charge") != null else 0.0
	if charge <= 0.05 or speed < 8.0:
		return
	var count := _emit("slipstream", 30.0 * clampf(charge, 0.2, 1.0) * float(budget.rate), step)
	for _n in range(count):
		var offset := Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(0.2, 1.4), 0.0)
		var start := kart.global_position + forward * _rng.randf_range(2.5, 4.0) + kart.global_basis * offset
		sparks.spawn(start, forward * (speed - 9.0), 0.03, 0.02, 0.07, 0.35, 0.0, Color(0.85, 0.95, 1.0, 0.45),
			Color(1.0, 0.0, 0.0, 0.3))
	_count("slipstream", count)


func _lead_confetti(kart: Node3D, up: Vector3) -> void:
	if str(race.mode) in ["training", "time_trial"]:
		return
	var place: int = race._place()
	var took_lead := _previous_place > 1 and place == 1 and float(race.elapsed) > 3.0
	_previous_place = place
	if not took_lead or _confetti_cooldown > 0.0:
		return
	_confetti_cooldown = 6.0
	var amount := maxi(16, int(70.0 * maxf(0.35, float(budget.rate))))
	var palette: Array[Color] = [Color("ffd166"), Color("ff6b8b"), Color("66e8ff"), Color("8affd8"), Color("c77dff")]
	for index in range(amount):
		puffs.spawn(kart.global_position + up * 1.6,
			Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3)) + up * _rng.randf_range(4.0, 7.5)
			+ kart.global_basis.z * -6.0,
			0.16 * _size(), 0.16 * _size(), 0.0, _rng.randf_range(1.4, 2.0), 0.35, palette[index % palette.size()],
			Color(1.8, _rng.randf(), _rng.randf_range(5.0, 11.0), 4.0))
	_count("confetti", amount)
	_sound("confetti", 1.0, 0.8)


func _backfire(kart: Node3D, forward: Vector3) -> void:
	_backfire_cooldown = 1.4
	for flame in kart.flames:
		if not is_instance_valid(flame):
			continue
		var at: Vector3 = flame.global_position
		sparks.spawn(at, -forward * 2.0, 0.42 * _size(), 0.1, 0.0, 0.13, 0.0, Color(1.0, 0.55, 0.2, 0.9),
			Color(3.0, _rng.randf(), 0.4, 0.8))
		for _n in range(int(6 * maxf(0.5, float(budget.rate)))):
			sparks.spawn(at, -forward * _rng.randf_range(2.0, 5.0) + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0, 1.5), _rng.randf_range(-1, 1)),
				0.05, 0.01, 0.03, _rng.randf_range(0.15, 0.3), 0.6, SPARK_HOT, Color(2.0, _rng.randf(), 1.0, 0.8))
	_count("backfire", 1)
	_sound("backfire", 0.9 + _rng.randf() * 0.25, 0.6)


func _tyre_smoke(tag: String, tyres: Array[Node3D], forward: Vector3, up: Vector3, step: float, rate: float, color: Color, scale: float = 1.0, life_scale: float = 1.0) -> void:
	var speed: float = absf(float(race.speed))
	for index in range(tyres.size()):
		var count := _emit("%s:%d" % [tag, index], rate * float(budget.rate), step)
		for _n in range(count):
			puffs.spawn(
				tyres[index].global_position + up * 0.12,
				forward * speed * _rng.randf_range(0.05, 0.25) + up * _rng.randf_range(0.4, 1.3)
				+ Vector3(_rng.randf_range(-0.7, 0.7), 0, _rng.randf_range(-0.7, 0.7)),
				0.35 * _size(), _rng.randf_range(1.3, 2.2) * scale * _size(), 0.0, _rng.randf_range(0.9, 1.6) * life_scale, -0.04,
				_tone(color, 0.05), Color(1.7, _rng.randf(), _rng.randf_range(-0.8, 0.8), 0.0)
			)
		_count(tag, count)


func _mark(stream: String, at: Vector3, up: Vector3, width: float, strength: float) -> void:
	var color: Color = style.mark
	color.a *= clampf(strength, 0.0, 1.0)
	if marks.stroke(stream, at + up * 0.025, up, width, color, float(budget.mark_life), int(style.mark_kind)):
		_count(stream.get_slice(":", 0) + "_marks", 1)


# --- flames, light, rivals ---------------------------------------------------


func _update_flash(step: float) -> void:
	flash = maxf(0.0, flash - step * 7.0)
	var on: bool = bool(budget.lights) and flash > 0.02 and not reduced_motion
	flash_light.visible = on
	flash_light.light_energy = flash * 3.0 if on else 0.0


## Turbo flame bodies, Mach rings at ignition, road glow and the pipes' afterglow.
func _kart_flames(kart: Node3D, forward: Vector3, up: Vector3, boosting: bool, age: float, glow: float, scale: float, seed: float) -> void:
	var exhausts: Array[Node3D] = []
	for flame_anchor in kart.flames:
		if is_instance_valid(flame_anchor) and exhausts.size() < 2:
			exhausts.append(flame_anchor)
	if exhausts.is_empty():
		return
	var middle := Vector3.ZERO
	for anchor in exhausts:
		middle += anchor.global_position
	middle /= float(exhausts.size())
	if boosting:
		var mach := clampf(1.0 - age / 0.55, 0.0, 1.0)
		var length := (1.5 + 0.2 * sin(_clock * 4.0 + seed)) * scale
		for index in range(exhausts.size()):
			# Tilted slightly up so the chase camera sees the flame's length, not its end.
			flames.flame(exhausts[index].global_position, -forward + up * 0.18, up, length, 0.3 * scale, 1.0, mach,
				Color("ff7a1c"), seed + float(index))
		var drop := maxf(0.0, (middle - kart.global_position).dot(up) - 0.03)
		flames.ground_glow(middle - forward * 0.9 * scale - up * drop, -forward, up, 1.1 * scale, 1.0, Color(1.0, 0.55, 0.22))
		flames.light_at(middle - forward * 0.6, 1.6 * scale, Color(1.0, 0.62, 0.3))
		_count("flame", 1)
	elif glow > 0.01:
		for anchor in exhausts:
			flames.afterglow(anchor.global_position, -forward, up, 0.12 * scale, glow * 0.8,
				Color(1.0, 0.36, 0.1).lerp(Color(0.5, 0.08, 0.02), 1.0 - glow))
		_count("afterglow", 1)


## Rivals near the player: drift sparks and marks, dust on loose ground, brake
## marks and turbo flames, on a strict budget (nearest few, reduced rates).
func _rivals(_forward: Vector3, step: float) -> void:
	var allowed: int = int(budget.rivals)
	var opponents = race.get("opponents")
	if allowed <= 0 or opponents == null:
		return
	var near: Array = []
	for rival in opponents:
		if is_instance_valid(rival) and rival.visible:
			var gap: float = rival.global_position.distance_to(race.player.global_position)
			if gap < 40.0:
				near.append([gap, rival])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var share: float = float(budget.rival_rate)
	for entry in near.slice(0, allowed):
		var rival: Node3D = entry[1]
		var id := rival.get_instance_id()
		var speed: float = absf(float(rival.motion_speed))
		var forward := -rival.global_basis.z.normalized()
		var up := rival.global_basis.y.normalized()
		var right := forward.cross(up).normalized()
		var tyres := _rear_tyres(rival)
		var drifting: bool = bool(rival.motion_drift) and absf(float(rival.motion_steer)) > 0.2 and speed > 1.0
		if drifting:
			var tier := clampi(int(rival.drift_spark_tier) + 1, 1, 3)
			var color: Color = DRIFT_COLORS[tier]
			for index in range(tyres.size()):
				var count := _emit("rdrift:%d:%d" % [id, index], (40.0 + 60.0 * float(tier)) * share, step)
				for _n in range(count):
					sparks.spawn(tyres[index].global_position + up * 0.05,
						forward * speed * _rng.randf_range(0.3, 0.6)
						- right * signf(float(rival.motion_steer)) * _rng.randf_range(0.8, 2.6)
						+ up * _rng.randf_range(1.2, 3.4), 0.09 * _size(), 0.02, 0.045, _rng.randf_range(0.22, 0.4),
						0.9, color, Color(2.2, _rng.randf(), 0.0, 0.3), rival.global_position.y + 0.02)
				_count("rival_drift_sparks", count)
				if marks.stroke("rdrift:%d:%d" % [id, index], tyres[index].global_position + up * 0.025, up, 0.26,
						style.mark, float(budget.mark_life) * 0.7, int(style.mark_kind)):
					_count("rival_marks", 1)
		else:
			marks.lift("rdrift:%d:0" % id)
			marks.lift("rdrift:%d:1" % id)
		var braking: float = float(rival.get("motion_brake")) if rival.get("motion_brake") != null else 0.0
		if braking > 0.35 and speed > 4.0:
			for index in range(tyres.size()):
				var color: Color = style.mark
				color.a *= braking
				if marks.stroke("rbrake:%d:%d" % [id, index], tyres[index].global_position + up * 0.025, up, 0.28,
						color, float(budget.mark_life) * 0.7, int(style.mark_kind)):
					_count("rival_marks", 1)
		else:
			marks.lift("rbrake:%d:0" % id)
			marks.lift("rbrake:%d:1" % id)
		var trail: float = float(style.trail)
		if trail > 0.0 and speed > 9.0:
			var amount := clampf((speed - 9.0) / 16.0, 0.2, 1.0) * trail
			for index in range(tyres.size()):
				var count := _emit("rdust:%d:%d" % [id, index], 70.0 * amount * share, step)
				for _n in range(count):
					puffs.spawn(tyres[index].global_position + up * 0.12,
						forward * speed * _rng.randf_range(0.05, 0.25) + up * _rng.randf_range(0.4, 1.3),
						0.35 * _size(), _rng.randf_range(1.3, 2.2) * float(style.dust_scale) * 1.4 * _size(), 0.0,
						_rng.randf_range(1.2, 2.2), -0.04, _tone(style.smoke, 0.05), Color(1.7, _rng.randf(), 0.4, 0.0))
				_count("rival_dust", count)
		var boosting: bool = bool(rival.motion_boost) and speed > 0.5
		var glow: float = float(_rival_afterglow.get(id, 0.0))
		glow = 1.0 if boosting else move_toward(glow, 0.0, step / 1.6)
		_rival_afterglow[id] = glow
		_kart_flames(rival, forward, up, boosting, 1.0, glow, 0.85, float(id % 7))


# --- body, camera, sound -----------------------------------------------------


func _spring(step: float, target_pitch: float, target_roll: float) -> void:
	var omega := 12.0
	var damping := 2.0 * (1.0 if reduced_motion else 0.3) * omega
	var scale := 0.5 if reduced_motion else 1.0
	var substeps := maxi(1, ceili(step / 0.0167))
	var h := step / float(substeps)
	for _i in range(substeps):
		_pitch_velocity += (-(omega * omega) * (pitch - target_pitch * scale) - damping * _pitch_velocity) * h
		_roll_velocity += (-(omega * omega) * (roll - target_roll * scale) - damping * _roll_velocity) * h
		pitch = clampf(pitch + _pitch_velocity * h, -0.11, 0.08)
		roll = clampf(roll + _roll_velocity * h, -0.12, 0.12)


func _settle(step: float, kart: Node3D) -> void:
	_spring(step, 0.0, 0.0)
	shake = 0.0
	fov_punch = 0.0
	_apply_tilt(kart)


func _apply_tilt(kart: Node3D) -> void:
	if absf(pitch) < 0.0005 and absf(roll) < 0.0005:
		return
	_tilt_base = kart.basis
	kart.basis = _tilt_base * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	_tilt_basis = kart.basis
	_tilt_applied = true


func _restore_tilt() -> void:
	if not _tilt_applied:
		return
	_tilt_applied = false
	if is_instance_valid(race) and is_instance_valid(race.player):
		if race.player.basis.is_equal_approx(_tilt_basis):
			race.player.basis = _tilt_base


## Extra camera field of view (degrees) for this frame; 0 with reduced motion.
## Added on top of the race's smoothed FOV (never smoothed from), like fx.camera_fov_kick().
func camera_fov_kick() -> float:
	return 0.0 if reduced_motion else fov_punch


## Small positional jolt (camera-local metres); zero with reduced motion.
func camera_shake() -> Vector3:
	if reduced_motion or shake <= 0.001:
		return Vector3.ZERO
	var t := _shake_phase
	return Vector3(sin(t * 71.0) + sin(t * 113.0) * 0.5, sin(t * 89.0 + 1.3) + sin(t * 131.0) * 0.4, 0.0) * shake * 0.6


func _update_lines(step: float, on: bool) -> void:
	line_intensity = move_toward(line_intensity, 1.0 if on else 0.0, step * (4.0 if on else 2.5))
	speed_lines.visible = line_intensity > 0.01 and not reduced_motion
	if speed_lines.visible:
		var material := speed_lines.material_override as ShaderMaterial
		var size := get_viewport().get_visible_rect().size
		material.set_shader_parameter("fx_time", sparks.fx_time)
		material.set_shader_parameter("intensity", line_intensity)
		material.set_shader_parameter("aspect", size.x / maxf(1.0, size.y))


func _update_engine(step: float, running: bool, gas: bool = false, boosting: bool = false, speed: float = 0.0) -> void:
	var audio = race.get("kart_audio")
	if not is_instance_valid(audio):
		return
	var countdown_idle: bool = float(race.countdown) > 0.0 and not bool(race.menu_active) and not bool(race.finished)
	if not running and not countdown_idle:
		for kind in ["engine_low", "engine_mid", "engine_high", "engine_off"]:
			audio.set_loop(kind, 0.0)
		rpm = 0.0
		return
	var ratio := clampf(speed / 25.0, 0.0, 1.0)
	var target := 0.12 + 0.78 * ratio
	if gas and speed < 8.0 and running:
		target += 0.22 * (1.0 - speed / 8.0)
	if boosting:
		target += 0.12
	rpm = move_toward(rpm, clampf(target, 0.08, 1.05), step * (2.4 if target > rpm else 1.4))
	load = move_toward(load, 1.0 if (gas or boosting or countdown_idle) else 0.0, step * 7.0)
	var frequency := 52.0 + rpm * 200.0
	var on := 0.35 + 0.65 * load
	var low := 1.0 - smoothstep(75.0, 125.0, frequency)
	var mid := smoothstep(70.0, 115.0, frequency) * (1.0 - smoothstep(150.0, 210.0, frequency))
	var high := smoothstep(140.0, 200.0, frequency)
	audio.set_loop("engine_low", low * on, clampf(frequency / 62.0, 0.6, 2.0))
	audio.set_loop("engine_mid", mid * on, clampf(frequency / 118.0, 0.6, 2.0))
	audio.set_loop("engine_high", high * on, clampf(frequency / 196.0, 0.6, 2.0))
	audio.set_loop("engine_off", (1.0 - load) * 0.85 * smoothstep(60.0, 90.0, frequency), clampf(frequency / 104.0, 0.6, 2.0))


func _set_loop(kind: String, gain: float, pitch_scale: float) -> void:
	var audio = race.get("kart_audio")
	if is_instance_valid(audio):
		audio.set_loop(kind, gain, pitch_scale)


func _silence(keep_engine: bool = false) -> void:
	if not is_instance_valid(race):
		return
	var audio = race.get("kart_audio")
	if not is_instance_valid(audio):
		return
	for kind in ["scrape", "squeal", "gravel", "snow", "turbo", "wind"]:
		audio.set_loop(kind, 0.0)
	if not keep_engine:
		for kind in ["engine_low", "engine_mid", "engine_high", "engine_off"]:
			audio.set_loop(kind, 0.0)


func _sound(kind: String, pitch_scale: float, gain: float) -> void:
	sounds[kind] = int(sounds.get(kind, 0)) + 1
	var audio = race.get("kart_audio")
	if is_instance_valid(audio):
		audio.effect(kind, pitch_scale, gain)


## The race engine (the old single sine) yields to the layered engine here.
func owns_engine_sound() -> bool:
	return is_instance_valid(race) and is_instance_valid(race.get("kart_audio"))


# --- helpers -----------------------------------------------------------------


func _can_emit() -> bool:
	return (
		is_instance_valid(race) and is_instance_valid(race.player) and not bool(race.paused)
		and bool(race.racing) and not bool(race.finished) and not bool(race.menu_active)
	)


func _drift_tier(charge: float) -> int:
	var tier := 0
	for index in range(RACE_RULES.DRIFT_TIERS.size()):
		if charge >= RACE_RULES.DRIFT_TIERS[index]:
			tier = index + 1
	return clampi(tier, 0, 3)


func _rear_tyres(kart: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for spark in kart.sparks:
		if is_instance_valid(spark) and spark.is_inside_tree():
			result.append(spark)
	result.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return kart.to_local(a.global_position).z > kart.to_local(b.global_position).z)
	if result.size() > 2:
		result.resize(2)
	# Fixed left/right order, so each tyre keeps its own mark stream.
	result.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return kart.to_local(a.global_position).x < kart.to_local(b.global_position).x)
	return result


func _emit(key: String, rate: float, step: float) -> int:
	var value: float = float(_accumulators.get(key, _rng.randf())) + maxf(0.0, rate) * step
	var count := int(value)
	_accumulators[key] = value - float(count)
	return count


func _count(tag: String, amount: int) -> void:
	if amount > 0:
		counts[tag] = int(counts.get(tag, 0)) + amount


func _size() -> float:
	return float(budget.size)


func _tone(color: Color, variation: float) -> Color:
	var shade := 1.0 + _rng.randf_range(-variation, variation)
	return Color(color.r * shade, color.g * shade, color.b * shade, color.a)


## Clip-space ring between an inner ellipse and the screen edge; the speed-line
## shader writes POSITION directly, so the ring always hugs the picture border.
func _edge_ring() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var segments := 48
	for index in range(segments):
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var inner0 := Vector2(cos(a0), sin(a0)) * 0.55
		var inner1 := Vector2(cos(a1), sin(a1)) * 0.55
		var outer0 := Vector2(cos(a0), sin(a0)) / maxf(absf(cos(a0)), absf(sin(a0)))
		var outer1 := Vector2(cos(a1), sin(a1)) / maxf(absf(cos(a1)), absf(sin(a1)))
		for point in [inner0, outer0, outer1, inner0, outer1, inner1]:
			vertices.append(Vector3(point.x, point.y, 0.0))
			uvs.append(point)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func visual_state() -> Dictionary:
	return {
		"profile": profile,
		"surface": str(style.name),
		"sparks_live": sparks.live_count(),
		"soft_live": puffs.live_count(),
		"marks_live": marks.live_count(),
		"spark_capacity": sparks.capacity,
		"soft_capacity": puffs.capacity,
		"mark_capacity": marks.capacity,
		"spawned": sparks.spawned_total + puffs.spawned_total,
		"mark_segments": marks.segments_total,
		"speed_lines": speed_lines.visible,
		"line_intensity": line_intensity,
		"pitch": pitch,
		"roll": roll,
		"shake": shake,
		"fov_punch": fov_punch,
		"scrape_level": scrape_level,
		"rpm": rpm,
		"counts": counts.duplicate(),
		"sounds": sounds.duplicate(),
		"draw_batches": (
			int(sparks.visible) + int(puffs.visible) + int(marks.visible) + int(speed_lines.visible)
			+ int(flames.visible)
		),
		"flames": flames.used,
		"lights": int(flames.light.visible) + int(flash_light.visible),
		"photo_finish": photo_finish.active,
	}
