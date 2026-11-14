extends SceneTree
## Real imported meshes, motion lifecycle and existing lesson integration.
const PROPS = preload("res://scripts/learning/lumo_dream_props.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[DreamGarden] " + message)


func _projected_bounds(node: Node3D, camera: Camera3D) -> Rect2:
	var result := Rect2()
	var found := false
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mesh: MeshInstance3D in meshes:
		if not mesh.is_visible_in_tree():
			continue
		for corner in range(8):
			var point := camera.unproject_position(mesh.to_global(mesh.get_aabb().get_endpoint(corner)))
			result = result.expand(point) if found else Rect2(point, Vector2.ZERO)
			found = true
	return result


func _check_lesson_projection() -> void:
	var bridge := root.get_node("HostBridge")
	var original_options: Dictionary = bridge.get("_options").duplicate(true)
	for descriptor in [
		{"kind": "bridge_ten", "a": 8, "b": 5},
		{"kind": "subtract_ten", "a": 13, "b": 5},
		{"kind": "equal_groups", "a": 3, "b": 4},
		{"kind": "bridge_hundred", "a": 180, "b": 50},
		{"kind": "syllables", "word": "Banane", "syllables": ["Ba", "na", "ne"]},
		{"kind": "plant_parts", "plantPart": "leaf"},
		{"kind": "fraction_parts", "a": 1, "b": 4, "extra": 2},
	]:
		for dimensions in [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(2400, 1080)]:
			root.size = dimensions
			var options: Dictionary = bridge.get("_options")
			options["displayDensity"] = 2.625 if dimensions.x == 2400 else 1.0
			var game: Node3D = load("res://scenes/learning/learning_world.tscn").instantiate()
			game.set("capture_options", {"learning": descriptor, "reduceAnimations": true})
			root.add_child(game)
			for frame in range(8):
				await process_frame
			var props := game.get_node("LearningGardenAtelier/LumoDreamGardenSculptures")
			var camera := game.get("camera") as Camera3D
			if dimensions.x < dimensions.y:
				var header := game.get("header") as Control
				var footer := game.get("footer") as Control
				var begin := header.get_global_rect().end.y + 6.0
				var end := footer.get_global_rect().position.y - 6.0
				var body := Rect2(8, begin, dimensions.x - 16, end - begin)
				var book := props.get_node("StorybookGarden") as Node3D
				_check(body.encloses(_projected_bounds(book, camera)), "portrait book fully visible between HUD panels")
			for decoration: Node3D in props.get_children():
				var decoration_bounds := _projected_bounds(decoration, camera)
				for token: Node3D in game.get("tokens"):
					var token_bounds := _projected_bounds(token, camera)
					_check(
						not decoration_bounds.intersects(token_bounds.grow(3.0)),
						"%s %s %s clears actual lesson geometry" % [descriptor.kind, dimensions, decoration.name]
					)
				for property in ["_hundred_stock", "_source_label", "_frame_label", "_fraction_label", "_hundred_summary", "sun"]:
					var lesson_node: Variant = game.get(property)
					if is_instance_valid(lesson_node) and lesson_node is Node3D:
						var lesson_bounds := _projected_bounds(lesson_node, camera)
						if lesson_bounds.has_area():
							_check(
								not decoration_bounds.intersects(lesson_bounds.grow(3.0)),
								"%s %s %s clears %s" % [descriptor.kind, dimensions, decoration.name, property]
							)
				var fox := game.get("fox") as Node3D
				_check(
					not decoration_bounds.intersects(_projected_bounds(fox, camera).grow(3.0)),
					"%s %s %s clears original teacher" % [descriptor.kind, dimensions, decoration.name]
				)
			game.queue_free()
			await process_frame
	bridge.set("_options", original_options)


func _run() -> void:
	for tier in ["low", "medium", "high"]:
		var props := PROPS.new()
		props.quality = tier
		root.add_child(props)
		await process_frame
		_check(props.get_child_count() == (3 if tier == "high" else 2), tier + " bounded instances")
		_check(props._moving.size() == (9 if tier == "high" else 6), tier + " imported moving parts")
		_check(props.is_processing() == (tier != "low"), tier + " motion budget")
		_check(props.find_children("*", "CollisionObject3D", true, false).is_empty(), "visuals own no input")
		var surfaces := 0
		for mesh: MeshInstance3D in props.find_children("*", "MeshInstance3D", true, false):
			var bounds := mesh.get_aabb()
			_check(bounds.size.is_finite() and bounds.size.length() > 0.01, "finite imported mesh")
			_check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "no extra shadow passes")
			surfaces += mesh.mesh.get_surface_count()
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				_check(material != null, "real PBR material imported")
				if material != null:
					_check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "opaque mobile surface")
		_check(surfaces <= (25 if tier == "high" else 16), tier + " surface budget")
		props._apply_pose(2.0)
		var changed := 0
		for index in range(props._moving.size()):
			if not props._moving[index].transform.is_equal_approx(props._rests[index]):
				changed += 1
		_check(changed == props._moving.size(), "both star and blossom geometry actually move")
		props.set_reduced_motion(true)
		_check(not props.is_processing(), "reduced motion stops processing")
		for index in range(props._moving.size()):
			_check(props._moving[index].transform.is_equal_approx(props._rests[index]), "restored quiet pose")
		props.set_reduced_motion(false)
		props.hide()
		_check(not props.is_processing(), "hidden scenery stops processing")
		props.show()
		props.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		_check(not props.is_processing(), "background application stops processing")
		props.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		_check(props.is_processing() == (tier != "low"), "foreground restores tier policy")
		props.queue_free()
		await process_frame
	var game: Node3D = load("res://scenes/learning/learning_world.tscn").instantiate()
	game.set("capture_options", {"learning": {"kind": "bridge_ten", "a": 8, "b": 5}, "reduceAnimations": true})
	root.add_child(game)
	await process_frame
	var attached := game.get_node_or_null("LearningGardenAtelier/LumoDreamGardenSculptures")
	_check(attached != null, "production learning scene contains the exported sculptures")
	if attached != null:
		_check(not attached.is_processing(), "production reduced-motion preference reaches sculptures")
		var book := attached.get_node("StorybookGarden") as Node3D
		_check(book.position.x > 4.0 or book.position.z < -5.0, "book remains outside central lesson carpet")
	var ambience := game.get_node_or_null("LearningGardenAtelier/LumoDreamAmbience")
	_check(ambience != null, "production atelier receives shared 3D ambience")
	if ambience != null:
		_check(bool(ambience.get("reduced_motion")), "lesson motion preference reaches shader ambience")
	_check(game.get("activity").placed.is_empty(), "decoration does not advance a lesson")
	_check(game.get("fox").is_usable(), "original Lumo remains usable")
	game.queue_free()
	await process_frame
	await _check_lesson_projection()
	print("[DreamGarden] checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
