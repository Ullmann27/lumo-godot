extends SceneTree
## An omitted podium must never allocate an orphan RendererSceneCull instance.
const STAGE = preload("res://scripts/games/kart_stage.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for has_podium in [false, true, false, true]:
		var holder := Node3D.new()
		root.add_child(holder)
		var built: Dictionary = STAGE.build(holder, Color("53ddfd"), has_podium)
		var podium = built.get("podium")
		if has_podium:
			if not is_instance_valid(podium) or podium.get_parent() != holder:
				failures += 1
				push_error("[AAAStageLifetime] Requested podium is not owned by stage")
		elif is_instance_valid(podium):
			failures += 1
			push_error("[AAAStageLifetime] Omitted podium allocated an orphan node")
			# Cleanup in this regression only after recording the real failure.
			if podium.get_parent() == null:
				podium.free()
		var camera = built.camera
		holder.free()
		if is_instance_valid(camera) or (has_podium and is_instance_valid(podium)):
			failures += 1
			push_error("[AAAStageLifetime] Stage children survived their owner")
		built.clear()
		await process_frame
	print("[AAAStageLifetime] %s: four stage lifecycles; %d failures" % [
		"PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
