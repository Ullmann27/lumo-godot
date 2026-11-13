extends SceneTree
## Checks the actual teaching scene; this is never a renderer/FPS assertion.
const WORLD := "res://scenes/learning/learning_world.tscn"
var checks := 0
var failures := 0


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[LearningStudio] " + label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for reduced: bool in [false, true]:
		var game = load(WORLD).instantiate()
		game.capture_options = {
			"learning": {"kind": "bridge_ten", "a": 8, "b": 5},
			"reduceAnimations": reduced
		}
		root.add_child(game)
		await process_frame
		await physics_frame
		var atelier: Node3D = game.get_node("LearningGardenAtelier")
		var studio: Node3D = atelier.get_node_or_null("BlenderLearningStudio")
		_check(studio != null, "actual Blender GLB is mounted in the live lesson")
		if studio == null:
			game.queue_free()
			await process_frame
			continue
		var meshes: Array[Node] = studio.find_children("*", "MeshInstance3D", true, false)
		_check(meshes.size() >= 8 and meshes.size() <= 12, "material-batched mesh ceiling")
		var triangles := 0
		var moving_materials := 0
		for mesh: MeshInstance3D in meshes:
			_check(mesh.mesh != null and mesh.is_visible_in_tree(), "imported mesh is actually visible")
			triangles += mesh.mesh.get_faces().size() / 3
			for index in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(index)
				_check(material != null, "no missing imported material")
				if material is ShaderMaterial:
					moving_materials += 1
					_check(
						is_equal_approx(material.get_shader_parameter("motion_weight"), 0.0 if reduced else 1.0),
						"reduced motion controls the real foliage shader"
					)
		_check(triangles > 1000 and triangles < 45000, "actual imported triangle budget")
		_check(moving_materials == 2, "both original studio foliage groups use bounded vertex motion")
		_check(game.tokens.size() == 5 and game.targets.size() == 20, "atelier preserves the exact 8+5 manipulatives")
		_check(game.fox.is_usable(), "original teaching actor remains connected")
		_check(
			atelier.find_children("OriginalLumoLantern*", "Node3D", true, false).size() == 2,
			"original lantern assets retained"
		)
		var original_placed: Array = game.activity.placed.duplicate()
		var original_explanation: String = game.activity.explanation()
		game._notification(NOTIFICATION_APPLICATION_PAUSED)
		await process_frame
		game._notification(NOTIFICATION_APPLICATION_RESUMED)
		_check(
			game.activity.placed == original_placed
			and game.activity.explanation() == original_explanation
			and game.activity.a == 8 and game.activity.b == 5,
			"studio does not change lesson state on lifecycle events"
		)
		game.queue_free()
		await process_frame
	if failures == 0:
		print("[LearningStudio] PASS checks=", checks, "; runtime asset, materials, reduced motion and preserved learning")
		quit(0)
	else:
		quit(1)
