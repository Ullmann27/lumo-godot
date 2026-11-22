extends RefCounted
## Two seamless, original PCM loops per motor. Synthesize once on the grid, then
## let Godot resample/mix them on its audio thread as the physics state changes.
## Chassis voicing: shaft cycles per half-second, firing asymmetry, electric share.
const CHASSIS := {
	"comet": Vector3(35, .36, .02), "gecko_velo": Vector3(41, .50, .04),
	"boru_rally": Vector3(28, .83, .0), "glider": Vector3(39, .14, .30),
	"nala_comet": Vector3(32, .62, .02), "noa_tide": Vector3(26, .40, .08),
	"iva_aurora": Vector3(37, .19, .40), "turbo": Vector3(34, .27, .10),
	"zuri_volt": Vector3(40, .06, 1.0), "blitz": Vector3(30, .92, .02),
	"terra": Vector3(25, .76, .01), "koloss": Vector3(21, .87, .02),
	"phantom": Vector3(31, .08, 1.0), "stella": Vector3(36, .24, .16),
}
const ENGINE_PITCH := {"sprint": 1.16, "dauer": .88, "lader": .93, "leicht": 1.23, "hybrid": 1.04}
const GEAR_RATIO := {"kurz": 1.18, "lang": .82, "turbo": .92, "gelaende": 1.27, "sperre": 1.06}
const PARTS = preload("res://scripts/games/kart_part_catalog.gd")
const SAMPLE_RATE := 12000
const FRAMES := 6000
const RADIUS := 40.0

var body
var induction
var road
var rpm := 0.0
var load_amount := 0.0
var electric := 0.0
var gear_ratio := 1.0
var brake_timbre := 1.0
var tire_grip := 1.0
var boost_timbre := 1.0
var previous_speed := 0.0
var regen_brake := false
var distance_sq := INF


func _init(parent: Node, spatial: bool) -> void:
	body = _player(parent, spatial, "Motor")
	induction = _player(parent, spatial, "Intake")
	if spatial:
		road = _player(parent, true, "TiresOrTurbo")


func _player(parent: Node, spatial: bool, label: String) -> Node:
	if spatial:
		var source := AudioStreamPlayer3D.new()
		source.name = label
		source.unit_size = 6.0
		source.max_distance = RADIUS + 12.0 # Chase camera sits behind the child.
		source.max_db = 0.0
		parent.add_child(source)
		return source
	var source := AudioStreamPlayer.new()
	source.name = label
	parent.add_child(source)
	return source


func configure(style: String, look: Dictionary) -> void:
	stop()
	rpm = 0.0
	load_amount = 0.0
	previous_speed = 0.0
	var chassis: Vector3 = CHASSIS.get(style, CHASSIS.comet)
	var engine: String = look.get("engine", "serie")
	var exhaust: String = look.get("exhaust", "serie")
	var levels: Dictionary = look.get("levels", {})
	var turns := roundi(chassis.x * float(ENGINE_PITCH.get(engine, 1.0)) + float(levels.get("motor", 0)))
	electric = maxf(chassis.z, .68 if engine == "hybrid" else 0.0)
	gear_ratio = GEAR_RATIO.get(look.get("gearbox", "serie"), 1.0)
	brake_timbre = PARTS.option("brakes", look.get("brakes", "serie")).mul.get("brake", 1.0)
	regen_brake = look.get("brakes") == "reku"
	tire_grip = PARTS.option("tires", look.get("tires", "serie")).mul.get("grip", 1.0)
	boost_timbre = PARTS.option("booster", look.get("booster", "serie")).mul.get("boost_power", 1.0)
	var twin := exhaust == "doppel"
	var nozzle := exhaust == "rakete"
	var bore := 2.0 if twin else (7.0 if nozzle else 4.0)
	var collector_turns := maxi(1, roundi(turns * .5))
	var core := PackedByteArray()
	var intake := PackedByteArray()
	core.resize(FRAMES * 2)
	intake.resize(FRAMES * 2)
	for i in FRAMES:
		var cycle := TAU * float(i) / float(FRAMES)
		# Every shaft completes an integer number of turns, including the small
		# variations in firing time, so the last PCM frame leads into the first.
		var shaft := turns * cycle + .13 * sin(2.0 * cycle) + .045 * sin(7.0 * cycle)
		var wobble := chassis.y * sin(shaft)
		var pulse := sin(shaft + wobble) + .48 * sin(2.0 * shaft - wobble)
		pulse += .22 * sin(3.0 * shaft + wobble) + .11 * sin(5.0 * shaft)
		var resonator := sin(bore * shaft + .8 * sin(shaft)) * (.23 if nozzle else .16)
		if twin:
			resonator += .87 * sin(collector_turns * cycle + .2 * sin(shaft))
		var rotor := .77 * sin(shaft * 2.0) + .21 * sin(shaft * 5.0 + .4 * sin(shaft))
		var shell := lerpf(pulse * (.79 + .21 * cos(shaft + wobble)), rotor, electric)
		var reed := .44 * sin(3.0 * shaft + 1.65 * sin(shaft)) + .23 * sin(5.0 * shaft + wobble)
		if engine == "lader" or nozzle:
			reed += .23 * sin(8.0 * shaft + .9 * sin(cycle * 3.0))
		var winding := .49 * sin(shaft * 4.0 + .23 * sin(2.0 * shaft)) + .18 * sin(6.0 * shaft)
		core.encode_s16(i * 2, roundi(17000.0 * tanh(shell + resonator)))
		intake.encode_s16(i * 2, roundi(17000.0 * tanh(lerpf(reed, winding, electric) + resonator)))
	body.stream = _loop(core)
	induction.stream = _loop(intake)


func _loop(pcm: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = FRAMES
	stream.data = pcm
	return stream


func advance(step: float, speed: float, throttle: float, brake: float, boost: bool, free_rev: bool, gain_db: float) -> void:
	var road_speed := absf(speed)
	var acceleration := (road_speed - previous_speed) / maxf(step, .001)
	previous_speed = road_speed
	var wheel_rate := clampf(road_speed * gear_ratio / 43.0, 0.0, 1.35)
	var shaft_rate := wheel_rate * .83
	if free_rev:
		shaft_rate = maxf(shaft_rate, .82 * throttle)
	var target_load := throttle * (1.0 if free_rev else 1.0 - brake)
	target_load *= clampf(.76 + acceleration * .014, .4, 1.0)
	if boost:
		shaft_rate += .14
		target_load = 1.0
	shaft_rate += .15 * target_load
	rpm = move_toward(rpm, shaft_rate, step * (2.2 if rpm < shaft_rate else 1.25))
	load_amount = move_toward(load_amount, target_load, step * 5.0)
	var pitch := .80 + 1.84 * rpm
	var regen := brake * minf(1.0, wheel_rate) * (1.0 if regen_brake else electric)
	body.pitch_scale = pitch
	induction.pitch_scale = pitch * (1.0 + .11 * regen)
	body.volume_db = gain_db + linear_to_db(.47 + .27 * minf(1.0, wheel_rate) + .26 * load_amount)
	induction.volume_db = gain_db + linear_to_db(.08 + .66 * load_amount + .35 * regen)
	if not body.playing:
		body.play()
		induction.play()


func stop() -> void:
	for player in [body, induction, road]:
		if is_instance_valid(player) and player.playing:
			player.stop()
