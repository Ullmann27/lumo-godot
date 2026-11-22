extends RefCounted
## Flight bot of Lumos Sternenpost for the tests and the picture runs: steers
## with the same stick the child uses (sky_post.gd autopilot), reads the address
## riddle's answer, drops the letter when the landing prediction lies inside the
## right mailbox's circle, flies the ring gates in order and never orbits a
## goal: when a goal lies beside the glider inside its turning circle, it first
## flies straight on and then turns back.

const DROP_SHARE: float = 0.6

var game
var wide_turn: float = 0.0
var drops: int = 0
var approach_house := -1
var approach_seconds := 0.0
var escape_seconds := 0.0
## Optional: deliberately drop at this house (index into layout.houses) once.
var wrong_house: int = -1


func _init(owner) -> void:
	game = owner


func stick(_unused = null) -> Vector2:
	match str(game.mode):
		"race":
			return _race()
		"free":
			return _free()
	return _delivery()


func _towards(aim: Vector3, climb_gain: float = 0.14) -> Vector2:
	var flight = game.flight
	var to: Vector3 = aim - flight.pos
	var flat: float = Vector2(to.x, to.z).length()
	var wanted: float = atan2(-to.x, -to.z)
	var error: float = wrapf(wanted - flight.yaw, -PI, PI)
	var climb: float = clampf(to.y * climb_gain, -1.0, 1.0)
	# A goal inside the turning circle cannot be reached by turning harder:
	# fly straight on first, then turn back.
	if wide_turn > 0.0:
		wide_turn -= 1.0 / 60.0
		return Vector2(0.0, climb)
	var radius: float = flight.speed / game.TUNING.TURN_RATE
	var side: Vector3 = flight.flat_forward().cross(Vector3.UP).normalized()
	var turn_centre: Vector3 = flight.pos + side * (radius if error < 0.0 else -radius)
	var from_centre: float = Vector2(aim.x - turn_centre.x, aim.z - turn_centre.z).length()
	if absf(error) > 0.6 and from_centre < radius * 0.92:
		wide_turn = clampf((radius - from_centre) / maxf(flight.speed, 1.0) + 0.6, 0.6, 2.2)
		return Vector2(0.0, climb)
	# SCHWUNG on straight stretches of the race, like a child would.
	if str(game.mode) == "race" and absf(error) < 0.12 and flat > 45.0:
		game.press_boost()
	return Vector2(clampf(-error * 2.2, -1.0, 1.0), climb)


func _delivery() -> Vector2:
	var delivery = game.delivery
	if delivery == null or delivery.finished():
		return Vector2(0.0, 0.1)
	var flight = game.flight
	var house: int = delivery.target_house()
	if wrong_house >= 0:
		house = wrong_house
	var box: Vector3 = game.layout.houses[house].mailbox
	if house != approach_house:
		approach_house = house
		approach_seconds = 0.0
		escape_seconds = 0.0
	if escape_seconds > 0.0:
		escape_seconds -= 1.0 / 60.0
		return Vector2(0.0, clampf((box.y + 12.0 - flight.pos.y) * 0.16, -1.0, 1.0))
	if delivery.in_district(flight.pos) and delivery.drop.is_empty():
		approach_seconds += 1.0 / 60.0
		if approach_seconds > 12.0:
			# Ein verfehlter Anflug braucht wieder eine Gerade für den Abwurf.
			# Sonst umkreist der Bot bei Seitenwind denselben Briefkasten.
			approach_seconds = 0.0
			wide_turn = 0.0
			escape_seconds = 3.0
	if not delivery.in_district(flight.pos):
		return _towards(delivery.centre() + Vector3(0, 14.0, 0))
	if delivery.drop.is_empty() and delivery.can_drop(flight.pos):
		var landing: Variant = delivery.predict(flight.pos, flight.velocity)
		if landing != null:
			var miss: float = Vector2(landing.x - box.x, landing.z - box.z).length()
			if miss < delivery.catch_radius() * DROP_SHARE:
				game.press_drop()
				drops += 1
				if wrong_house >= 0:
					wrong_house = -1
	return _towards(box + Vector3(0, 10.5, 0), 0.16)


func _race() -> Vector2:
	var race = game.race
	if race == null or race.finished:
		return Vector2(0.0, 0.05)
	var flight = game.flight
	var frame: Transform3D = game.layout.gate_frame(race.next_gate())
	var local: Vector3 = frame.affine_inverse() * flight.pos
	var aim: Vector3 = frame.origin
	# On the wrong side of the ring: come around to its front first.
	if local.z < -0.5:
		aim = frame * Vector3(0, 0, 22.0)
	elif local.z > 6.0:
		aim = frame * Vector3(0, 0, minf(local.z * 0.35, 8.0))
	return _towards(aim, 0.2)


## Free flight: visits the photo spots one after another.
func _free() -> Vector2:
	var target: Variant = game.goal
	if target == null:
		return Vector2(0.25, 0.0)
	return _towards(target, 0.2)
