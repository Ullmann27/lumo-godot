extends SceneTree
const VISUAL = preload("res://scripts/creative/build_settlement_visual.gd")
const DETAIL = preload("res://scripts/creative/lumo_world_meshy_detail.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[WorldMeshy] " + label)


func _run() -> void:
	for kind in ["house", "market"]:
		var body: StaticBody3D = VISUAL.create(kind)
		body.set_meta("saved_building_id", "test-" + kind)
		body.set_meta("saved_plot", 3)
		var original := body.get_node("Visual") as Node3D
		var colliders := body.find_children("*", "CollisionShape3D", true, false)
		_check(colliders.size() == 1, kind + " has original collision")
		_check(not DETAIL.apply(body, "low"), kind + " low uses original")
		_check(not DETAIL.apply(body, "medium"), kind + " medium uses original")
		_check(original.visible, kind + " original retained before successful fit")
		_check(DETAIL.apply(body, "high"), kind + " imports and fits real GLB")
		var detail := body.get_node_or_null("MeshyDetail") as Node3D
		_check(detail != null, kind + " has actual detail node")
		if detail != null:
			_check(not original.visible, kind + " no duplicate original rendering")
			_check(detail.get_child_count() > 0, kind + " includes actual meshes")
			var limit: Vector3 = (colliders[0].shape as BoxShape3D).size
			var extent: Vector3 = detail.get_meta("fitted_size")
			_check(extent.x <= limit.x + 0.001 and extent.y <= limit.y + 0.001 and extent.z <= limit.z + 0.001, kind + " fits existing collision envelope")
			_check(detail.find_children("*", "CollisionObject3D", true, false).is_empty(), kind + " no imported collisions")
		_check(body.find_children("*", "CollisionShape3D", true, false) == colliders, kind + " same collider identity")
		_check(body.get_meta("saved_building_id") == "test-" + kind and body.get_meta("saved_plot") == 3, kind + " save identity unchanged")
		_check(not DETAIL.apply(body, "ultra"), kind + " repeated import is rejected")
		body.free()
	_check(DETAIL.fitted("res://missing_world_meshy.glb", Vector3.ONE) == null, "missing file falls back")
	_check(DETAIL.fitted(str(DETAIL.MODELS.house), Vector3.ZERO) == null, "invalid envelope falls back")
	print("[WorldMeshy] %s %d checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
