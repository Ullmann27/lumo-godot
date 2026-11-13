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


func _projected_bounds(mesh: MeshInstance3D, camera: Camera3D) -> Rect2:
	var bounds := mesh.get_aabb()
	var projected := Rect2(
		camera.unproject_position(mesh.to_global(bounds.get_endpoint(0))), Vector2.ZERO
	)
	for corner in range(1, 8):
		projected = projected.expand(
			camera.unproject_position(mesh.to_global(bounds.get_endpoint(corner)))
		)
	return projected


func _mesh_components(mesh: Mesh) -> Array:
	var faces := mesh.get_faces()
	var index_by_point: Dictionary = {}
	var points: Array[Vector3] = []
	var neighbors: Array = []
	for triangle in range(0, faces.size(), 3):
		var ids: Array[int] = []
		for corner in range(3):
			var point := faces[triangle + corner]
			var key := Vector3i(
				roundi(point.x * 1000000.0),
				roundi(point.y * 1000000.0),
				roundi(point.z * 1000000.0)
			)
			if not index_by_point.has(key):
				index_by_point[key] = points.size()
				points.append(point)
				neighbors.append([])
			ids.append(index_by_point[key])
		for corner in range(3):
			neighbors[ids[corner]].append(ids[(corner + 1) % 3])
			neighbors[ids[(corner + 1) % 3]].append(ids[corner])
	var seen: Dictionary = {}
	var result: Array = []
	for first in range(points.size()):
		if seen.has(first):
			continue
		var stack: Array[int] = [first]
		seen[first] = true
		var connected: Array[Vector3] = []
		var bounds := AABB(points[first], Vector3.ZERO)
		while not stack.is_empty():
			var current: int = stack.pop_back()
			connected.append(points[current])
			bounds = bounds.expand(points[current])
			for neighbor: int in neighbors[current]:
				if not seen.has(neighbor):
					seen[neighbor] = true
					stack.append(neighbor)
		result.append({"points": connected, "bounds": bounds})
	return result


func _projected_component(node: MeshInstance3D, camera: Camera3D, component: Dictionary) -> Rect2:
	var first: Vector3 = component.points[0]
	var result := Rect2(camera.unproject_position(node.to_global(first)), Vector2.ZERO)
	for point: Vector3 in component.points:
		result = result.expand(camera.unproject_position(node.to_global(point)))
	return result


func _check_equality_projection(label: MeshInstance3D, camera: Camera3D, context: String) -> void:
	# Inspect the real production text triangles, including extrusion sides.
	# The equals sign has two disconnected horizontal components at the same
	# local x-span. Projecting only the front cap would miss the old occlusion.
	var components := _mesh_components(label.mesh)
	var bars: Array = []
	for left in range(components.size()):
		var a: AABB = components[left].bounds
		for right in range(left + 1, components.size()):
			var b: AABB = components[right].bounds
			if (
				a.size.x > a.size.y * 2.0
				and b.size.x > b.size.y * 2.0
				and absf(a.position.x - b.position.x) < 0.000001
				and absf(a.size.x - b.size.x) < 0.000001
			):
				bars.append(components[left])
				bars.append(components[right])
	_check(bars.size() == 2, context + " contains two actual disconnected equals bars")
	if bars.size() != 2:
		return
	var a: AABB = bars[0].bounds
	var b: AABB = bars[1].bounds
	_check(
		a.size.z > 0.0 and b.size.z > 0.0, context + " retains real three-dimensional glyph volume"
	)
	var upper := _projected_component(label, camera, bars[0])
	var lower := _projected_component(label, camera, bars[1])
	var gap := maxf(upper.position.y - lower.end.y, lower.position.y - upper.end.y)
	# Two physical pixels guarantee a visible background row even when the
	# glyph's projected edges fall between pixel centers. The old mesh's gap
	# was only 0.018–0.030 px despite a correct '=' string and disjoint caps.
	_check(gap >= 2.0, "%s keeps equals bars visibly separate: %.4f px" % [context, gap])
	print("[LearningStudio] EQUAL ", context, " gap_px=", gap)


func _check_place_value_caption() -> void:
	var game = load(WORLD).instantiate()
	game.capture_options = {
		"learning": {"kind": "bridge_hundred", "a": 180, "b": 50}, "reduceAnimations": true
	}
	root.add_child(game)
	await process_frame
	await physics_frame
	for step in range(6):
		var caption: MeshInstance3D = game._hundred_summary
		var plate: MeshInstance3D = caption.get_node("CaptionPlate")
		var glyph_bounds: AABB = caption.get_aabb()
		var plate_bounds: AABB = plate.transform * plate.get_aabb()
		_check(plate.is_visible_in_tree(), "place-value text has a real contrasting surface")
		_check(
			(
				plate_bounds.position.x < glyph_bounds.position.x
				and plate_bounds.end.x > glyph_bounds.end.x
				and plate_bounds.position.y < glyph_bounds.position.y
				and plate_bounds.end.y > glyph_bounds.end.y
			),
			"caption surface contains the full changing place-value text"
		)
		_check(plate_bounds.end.z < glyph_bounds.position.z, "surface stays behind every glyph")
		var ink: StandardMaterial3D = caption.material_override
		var background: StandardMaterial3D = plate.material_override
		var light := ink.albedo_color.srgb_to_linear().get_luminance()
		var dark := background.albedo_color.srgb_to_linear().get_luminance()
		_check(
			(light + 0.05) / (dark + 0.05) > 7.0, "unlit place-value colors retain high contrast"
		)
		_check(
			(
				ink.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
				and background.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
			),
			"lesson lighting cannot reduce caption contrast"
		)
		# Local AABBs alone missed the real oblique-camera parallax: the lower
		# glyphs projected below the navy plate onto the cream tray rim.
		var bridge := root.get_node("HostBridge")
		var old_options: Dictionary = bridge._options.duplicate(true)
		for dimensions in [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(2400, 1080)]:
			root.size = dimensions
			bridge._options["displayDensity"] = 2.625 if dimensions.x == 2400 else 1.0
			# Container wrapping must settle before sampling the fitted camera,
			# just as the production renderer capture waits after a resize.
			for frame in range(12):
				await process_frame
			game._layout()
			for frame in range(12):
				await process_frame
			_check(
				_projected_bounds(plate, game.camera).encloses(
					_projected_bounds(caption, game.camera).grow(0.5)
				),
				(
					"actual camera retains contrast behind every glyph at step %d in %s"
					% [step, dimensions]
				)
			)
			var frame_label: MeshInstance3D = game._frame_label
			var begin: float = game.header.get_global_rect().end.y + 4.0
			var end: float = game.footer.get_global_rect().position.y - 4.0
			var body := Rect2(8, begin, dimensions.x - 16, end - begin)
			_check(
				body.encloses(_projected_bounds(frame_label, game.camera)),
				(
					"upper mathematical caption remains outside the actual HUD at step %d in %s: caption=%s body=%s"
					% [step, dimensions, _projected_bounds(frame_label, game.camera), body]
				)
			)
			if game.activity.initial_count() + game.activity.placed.size() >= 10:
				_check(
					frame_label.mesh.text == "10 Zehner = 100",
					"ten tens retain the mathematical equality"
				)
				_check_equality_projection(
					frame_label, game.camera, "step %d in %s" % [step, dimensions]
				)
		bridge._options = old_options
		root.size = Vector2i(1280, 720)
		game._layout()
		if step < 5:
			_check(game.move_token(step), "caption follows the actual hundred-crossing interaction")
			await process_frame
	game.queue_free()
	await process_frame


func _run() -> void:
	for reduced: bool in [false, true]:
		var game = load(WORLD).instantiate()
		game.capture_options = {
			"learning": {"kind": "bridge_ten", "a": 8, "b": 5}, "reduceAnimations": reduced
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
			_check(
				mesh.mesh != null and mesh.is_visible_in_tree(), "imported mesh is actually visible"
			)
			triangles += mesh.mesh.get_faces().size() / 3
			for index in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(index)
				_check(material != null, "no missing imported material")
				if material is ShaderMaterial:
					moving_materials += 1
					_check(
						is_equal_approx(
							material.get_shader_parameter("motion_weight"), 0.0 if reduced else 1.0
						),
						"reduced motion controls the real foliage shader"
					)
		_check(triangles > 1000 and triangles < 45000, "actual imported triangle budget")
		_check(
			moving_materials == 2, "both original studio foliage groups use bounded vertex motion"
		)
		_check(
			game.tokens.size() == 5 and game.targets.size() == 20,
			"atelier preserves the exact 8+5 manipulatives"
		)
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
			(
				game.activity.placed == original_placed
				and game.activity.explanation() == original_explanation
				and game.activity.a == 8
				and game.activity.b == 5
			),
			"studio does not change lesson state on lifecycle events"
		)
		game.queue_free()
		await process_frame
	await _check_place_value_caption()
	if failures == 0:
		print(
			"[LearningStudio] PASS checks=",
			checks,
			"; runtime asset, materials, reduced motion and preserved learning"
		)
		quit(0)
	else:
		quit(1)
