extends SceneTree


## Messwerkzeug: welche sichtbaren Teile der Welt liegen an einer Stelle? (Lücken-Kontrolle)
## -- <track> <distance> <lateral> [radius]
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var world: Node3D = load("res://scripts/games/kart_world.gd").new()
	root.add_child(world)
	world.build(false, args[0])
	for _i in range(4):
		await process_frame
	var d: float = float(args[1])
	var radius: float = float(args[3]) if args.size() > 3 else 1.5
	for lateral_text in args[2].split(","):
		var p: Vector3 = world.position_at(d, float(lateral_text)) + world.frame(d).y * 0.4
		for node in world.find_children("*", "GeometryInstance3D", true, false):
			var visual: GeometryInstance3D = node
			if visual is MultiMeshInstance3D:
				var mm: MultiMesh = visual.multimesh
				for k in range(mm.instance_count):
					var xf: Transform3D = visual.global_transform * mm.get_instance_transform(k)
					var box: AABB = xf * mm.mesh.get_aabb()
					if box.grow(radius).has_point(p):
						print(
							(
								"[Probe] lat %s MM %s inst %d box %s"
								% [lateral_text, visual.get_path(), k, box]
							)
						)
			elif visual is VisualInstance3D:
				var box2: AABB = visual.global_transform * visual.get_aabb()
				if box2.grow(radius).has_point(p) and box2.size.length() < 400.0:
					print("[Probe] lat %s %s box %s" % [lateral_text, visual.get_path(), box2])
	quit(0)
