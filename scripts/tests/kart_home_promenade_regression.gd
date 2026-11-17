extends SceneTree
## Verifies the authored geometry and that a dormant home performs no animation writes.

class ObservedPromenade extends "res://scripts/games/kart_home_promenade.gd":
	var motion_updates := 0

	func _update_motion() -> void:
		motion_updates += 1
		super._update_motion()


var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[KartHomePromenade] " + label)


func _run() -> void:
	var home := ObservedPromenade.new()
	root.add_child(home)
	home.build()
	var sheared_boxes := 0
	var road_edges := 0
	var lane_markings := 0
	for family in home._batches:
		for transform: Transform3D in home._batches[family]:
			var basis := transform.basis
			var x := basis.x.normalized()
			var y := basis.y.normalized()
			var z := basis.z.normalized()
			if maxf(absf(x.dot(y)), maxf(absf(x.dot(z)), absf(y.dot(z)))) > 0.0001:
				sheared_boxes += 1
			var dimensions := Vector3(basis.x.length(), basis.y.length(), basis.z.length())
			if dimensions.is_equal_approx(Vector3(0.08, 0.015, 0.55)):
				lane_markings += 1
			if is_equal_approx(dimensions.x, 0.18) and is_equal_approx(dimensions.y, 0.17):
				road_edges += 1
	_check(sheared_boxes == 0, "curved scenery retains orthogonal local axes")
	_check(road_edges == 152, "both road edges retain their authored width and height around every bend")
	_check(lane_markings == 26, "lane markings retain their authored dimensions around every bend")

	home.set_active(true, false)
	home.advance(0.1)
	_check(home.elapsed > 0.0, "active scenery advances normally")
	var before := home.motion_updates
	home.set_active(true, true)
	_check(home.motion_updates == before + 1 and is_zero_approx(home.elapsed), "entering reduced motion settles the visible scene once")
	before = home.motion_updates
	for _frame in range(12):
		home.set_active(true, true)
		home.advance(0.1)
	_check(home.motion_updates == before, "repeated reduced-motion sync performs no animation writes")
	home.set_active(false, true)
	for _frame in range(12):
		home.set_active(false, true)
		home.advance(0.1)
	_check(home.motion_updates == before, "hidden reduced-motion scene performs no animation writes")
	home.set_active(false, false)
	home.set_active(false, true)
	_check(home.motion_updates == before, "changing motion preference while hidden performs no animation writes")
	home.set_active(true, true)
	_check(home.motion_updates == before + 1 and is_zero_approx(home.elapsed), "returning to reduced-motion Home settles the scene once")
	home.set_active(true, false)
	home.advance(0.1)
	_check(home.elapsed > 0.0, "leaving reduced motion resumes the existing scene clock")
	before = home.motion_updates
	var stopped_time := home.elapsed
	home.set_active(false, false)
	home.advance(0.1)
	_check(home.motion_updates == before and is_equal_approx(home.elapsed, stopped_time), "hidden normal-motion scene also remains dormant")
	home.queue_free()
	await process_frame
	print("[KartHomePromenade] ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks)
	quit(0 if failures.is_empty() else 1)
