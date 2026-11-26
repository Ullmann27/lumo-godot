extends RefCounted
## Effects of the ground under the tyres and of kart-to-kart contact, emitted
## through kart_drive_fx's own particle batches, budgets and sound hooks (no
## extra nodes or draw calls):
##   kerb    rumble level for camera tremor, body rock and the kerb loop
##   puddle  one splash on entry, spray and mist while in the water, then a
##           fading wet tyre track (WET_SECONDS)
##   verge   clods, grass bits and dust beyond the asphalt
##   contact a bump, sparks only when two karts rub at speed, a lean away

const GROUND = preload("res://scripts/games/kart_fx/kart_fx_ground.gd")

const WATER := Color(0.78, 0.9, 1.0, 0.85)
const MIST := Color(0.9, 0.95, 1.0, 0.32)
const WET_MARK := Color(0.03, 0.05, 0.07, 0.5)
const WET_SECONDS := 1.6
const CLOD := Color("6a4a2c")
const GRASS := Color("6c9a3a")
const VERGE_DUST := Color(0.72, 0.62, 0.46, 0.5)
## Closing speed (m/s) from which rubbing karts throw sparks.
const SPARK_CLOSING := 3.0


static func advance(
	fx,
	kart: Node3D,
	tyres: Array[Node3D],
	forward: Vector3,
	up: Vector3,
	right: Vector3,
	speed: float,
	step: float,
	grounded: bool
) -> void:
	var race = fx.race
	var previous: String = str(fx.ground.kind)
	fx.ground = GROUND.ROAD
	if grounded and str(race.mode) != "arena" and race.get("world") != null:
		fx.ground = GROUND.sample(
			race.world, float(race.previous_road_distance), float(race.lane), false
		)
	var kind: String = str(fx.ground.kind)
	var wanted: float = 0.0
	if kind == "curb":
		wanted = float(fx.ground.depth) * clampf(speed / 12.0, 0.0, 1.0)
		fx._count("curb_ticks", 1)
	elif kind == "verge":
		wanted = float(fx.ground.depth) * clampf(speed / 8.0, 0.0, 1.0) * 0.8
	fx.rumble_level = move_toward(fx.rumble_level, wanted, step * 10.0)
	if kind == "puddle" and speed > 3.0:
		if previous != "puddle":
			splash(fx, kart.global_position, forward, up, right, speed, 1.0)
		_spray(fx, tyres, forward, up, right, speed, step)
		fx.wet_time = WET_SECONDS
	elif fx.wet_time > 0.0:
		fx.wet_time = maxf(0.0, fx.wet_time - step)
	if fx.wet_time > 0.0 and kind != "puddle" and speed > 2.0:
		# Wet tyres print a fading dark track for a few metres after the puddle.
		for index in range(tyres.size()):
			var color := WET_MARK
			color.a *= fx.wet_time / WET_SECONDS
			var at: Vector3 = tyres[index].global_position + up * 0.025
			var life: float = float(fx.budget.mark_life) * 0.6
			if fx.marks.stroke("wet:%d" % index, at, up, 0.26, color, life, 0):
				fx._count("wet_marks", 1)
	else:
		fx.marks.lift("wet:0")
		fx.marks.lift("wet:1")
	if kind == "verge" and speed > 3.0:
		_verge(fx, tyres, forward, up, right, speed, step)


static func _spray(
	fx,
	tyres: Array[Node3D],
	forward: Vector3,
	up: Vector3,
	right: Vector3,
	speed: float,
	step: float
) -> void:
	var rng: RandomNumberGenerator = fx._rng
	var rate: float = float(fx.budget.rate)
	var spray: float = clampf(speed / 20.0, 0.25, 1.0) * float(fx.ground.wet)
	for index in range(tyres.size()):
		var tyre: Vector3 = tyres[index].global_position + up * 0.05
		var side: float = -1.0 if index == 0 else 1.0
		var drops: int = fx._emit("spray:%d" % index, 140.0 * spray * rate, step)
		for _n in range(drops):
			var velocity: Vector3 = (
				forward * speed * rng.randf_range(0.15, 0.4)
				+ right * side * rng.randf_range(1.0, 3.2)
				+ up * rng.randf_range(1.6, 3.8)
			)
			fx.puffs.spawn(
				tyre,
				velocity,
				rng.randf_range(0.05, 0.09) * fx._size(),
				0.04,
				0.0,
				rng.randf_range(0.35, 0.6),
				1.0,
				fx._tone(WATER, 0.06),
				Color(0.4, rng.randf(), 0.0, 1.0)
			)
		fx._count("water_spray", drops)
		var mist: int = fx._emit("mist:%d" % index, 36.0 * spray * rate, step)
		for _n in range(mist):
			fx.puffs.spawn(
				tyre + up * 0.15,
				forward * speed * 0.2 + up * rng.randf_range(0.4, 1.0),
				0.3 * fx._size(),
				rng.randf_range(1.0, 1.6) * fx._size(),
				0.0,
				rng.randf_range(0.5, 0.8),
				-0.02,
				MIST,
				Color(1.9, rng.randf(), 0.4, 0.0)
			)
		fx._count("water_mist", mist)


static func _verge(
	fx,
	tyres: Array[Node3D],
	forward: Vector3,
	up: Vector3,
	right: Vector3,
	speed: float,
	step: float
) -> void:
	var rng: RandomNumberGenerator = fx._rng
	var side_sign: float = float(fx.ground.side)
	for index in range(tyres.size()):
		var tyre: Vector3 = tyres[index].global_position + up * 0.05
		var clods: int = fx._emit(
			"clods:%d" % index, (40.0 + speed * 3.0) * float(fx.budget.rate), step
		)
		for _n in range(clods):
			var leaf: bool = rng.randf() < 0.4
			var velocity: Vector3 = (
				-forward * rng.randf_range(1.0, 3.5)
				+ right * side_sign * rng.randf_range(0.2, 1.8)
				+ up * rng.randf_range(1.8, 4.2)
			)
			fx.puffs.spawn(
				tyre,
				velocity,
				rng.randf_range(0.06, 0.11) * fx._size(),
				0.06,
				0.0,
				rng.randf_range(0.5, 0.9),
				1.0,
				fx._tone(GRASS if leaf else CLOD, 0.15),
				Color(0.3, rng.randf(), rng.randf_range(-9.0, 9.0), 2.0 if leaf else 1.0)
			)
		fx._count("verge_clods", clods)
	fx._tyre_smoke(
		"verge_dust",
		tyres,
		forward,
		up,
		step,
		46.0 * clampf(speed / 15.0, 0.3, 1.0),
		VERGE_DUST,
		1.25
	)


## Water thrown up when a tyre hits a puddle: a fan of drops, a ring of spray
## and a soft splash. [param strength] scales a rival's splash down.
static func splash(
	fx, at: Vector3, forward: Vector3, up: Vector3, right: Vector3, speed: float, strength: float
) -> void:
	var rng: RandomNumberGenerator = fx._rng
	var pace: float = clampf(speed / 22.0, 0.3, 1.0)
	var amount: int = maxi(
		6, int((26.0 + 50.0 * pace) * maxf(0.4, float(fx.budget.rate)) * strength)
	)
	for index in range(amount):
		var angle: float = TAU * float(index) / float(amount) + rng.randf() * 0.4
		var flat: Vector3 = right * cos(angle) + forward * sin(angle) * 0.6
		var velocity: Vector3 = (
			flat * rng.randf_range(2.0, 4.5) * (0.6 + pace)
			+ forward * speed * 0.25
			+ up * rng.randf_range(2.0, 4.6)
		)
		fx.puffs.spawn(
			at + up * 0.08 + flat * 0.6,
			velocity,
			rng.randf_range(0.06, 0.11) * fx._size(),
			0.05,
			0.0,
			rng.randf_range(0.45, 0.75),
			1.0,
			fx._tone(WATER, 0.08),
			Color(0.35, rng.randf(), 0.0, 1.0)
		)
	fx._count("splash_drops", amount)
	fx._count("splash", 1)
	fx._sound("splash", 0.9 + rng.randf() * 0.2 + pace * 0.1, (0.5 + 0.5 * pace) * strength)


## Two karts touched. Sparks only when they rub at speed; always a soft bump
## and, for the child's kart, a short lean away and a small jolt.
static func kart_contact(fx, kart: Node3D, other: Node3D, away: Vector3, closing: float) -> void:
	if not fx._can_emit() or not is_instance_valid(kart) or not is_instance_valid(other):
		return
	var rng: RandomNumberGenerator = fx._rng
	var up: Vector3 = kart.global_basis.y.normalized()
	var flat: Vector3 = away - up * away.dot(up)
	if flat.length() < 0.01:
		flat = kart.global_basis.x
	flat = flat.normalized()
	var at: Vector3 = kart.global_position.lerp(other.global_position, 0.5) + up * 0.3
	var strength: float = clampf((closing - 1.0) / 8.0, 0.0, 1.0)
	fx._count("kart_contact", 1)
	if closing > SPARK_CLOSING:
		var travel: Vector3 = (-kart.global_basis.z).normalized()
		var kart_speed: float = absf(float(fx.race.speed))
		var count: int = int((14.0 + 46.0 * strength) * maxf(0.4, float(fx.budget.rate)))
		for _n in range(count):
			var direction: Vector3 = (
				(
					travel * rng.randf_range(0.2, 1.0)
					+ flat * rng.randf_range(-0.6, 0.6)
					+ up * rng.randf_range(0.3, 1.2)
				)
				. normalized()
			)
			fx.sparks.spawn(
				at,
				direction * rng.randf_range(3.0, 8.0) + travel * kart_speed * 0.5,
				rng.randf_range(0.08, 0.15) * fx._size(),
				0.02,
				0.045,
				rng.randf_range(0.25, 0.6),
				1.0,
				fx.SPARK_HOT.lerp(fx.SPARK_WHITE, rng.randf()),
				Color(1.5, rng.randf(), 1.0, 0.9),
				kart.global_position.y + 0.02
			)
		fx._count("contact_sparks", count)
	if kart == fx.race.player and not fx.reduced_motion:
		var side: float = signf(flat.dot(kart.global_basis.x))
		fx._roll_velocity += side * (0.5 + strength * 1.4)
		fx.shake = maxf(fx.shake, 0.015 + strength * 0.05)
	fx._sound("bump", 0.9 + rng.randf() * 0.2, 0.45 + strength * 0.55)
