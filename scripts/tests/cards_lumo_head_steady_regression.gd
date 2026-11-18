extends SceneTree
## Lumo sits still at the card table: his head looks at a point and stays there.
## (On the device his head kept turning: the look was added to the pose again
## every frame, because nothing reset his head between frames.)
const SEAT_PATH := "res://scripts/games/cards/cards_seat.gd"
const STEP := 1.0 / 60.0

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("[CardsLumoHead] FAIL: ", label)


func _head(seat) -> Basis:
	return (seat.skeleton.global_transform * seat.skeleton.get_bone_global_pose(seat._head)).basis.orthonormalized()


func _run() -> void:
	# Loaded here: the seat uses autoloads that exist only once the tree runs.
	var SEAT: GDScript = load(SEAT_PATH)
	for kind in ["lumo", "lion"]:
		var seat = SEAT.new()
		root.add_child(seat)
		seat.setup(kind, Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.6)), 0)
		await process_frame
		_check(seat.usable(), kind + " sitzt am Tisch")
		if not seat.usable():
			continue
		var marks: Array[Basis] = []
		for frame in range(420):
			if frame == 20:
				seat.look_at_point(seat.global_position + Vector3(0.8, 1.2, -1.4))
			await process_frame
			seat.advance(STEP)
			if frame >= 120 and frame % 60 == 0:
				marks.append(_head(seat))
		var worst := 0.0
		for index in range(1, marks.size()):
			worst = maxf(worst, marks[0].get_rotation_quaternion().angle_to(marks[index].get_rotation_quaternion()))
		print("[CardsLumoHead] %s: größte Kopfdrehung zwischen den Messpunkten %.3f rad" % [kind, worst])
		_check(worst < 0.12, "%s: der Kopf bleibt ruhig, wenn er auf einen Punkt schaut (%.3f rad)" % [kind, worst])
		_check(marks[marks.size() - 1].y.dot(Vector3.UP) > 0.6, "%s: der Kopf steht aufrecht" % kind)
		root.remove_child(seat)
		seat.queue_free()
		await process_frame
	if failures.is_empty():
		print("[CardsLumoHead] PASS: %d checks" % checks)
	else:
		print("[CardsLumoHead] FAILED: %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
