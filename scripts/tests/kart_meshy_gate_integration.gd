extends SceneTree
## Godot 4.6.3 import/regression test for actual GLB/fallback.
const WORLD = preload("res://scripts/games/kart_world.gd")
const GATE = preload("res://scripts/games/kart_meshy_start_gate.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for mobile in [true, false]:
		var world: LumoRaceWorld = WORLD.new()
		root.add_child(world)
		world.build(mobile, "sonnenhafen", true)
		var before: float = world.length
		var checkpoints: int = world.checkpoint_positions.size()
		var result: bool = GATE.install(world)
		assert(result, "Only the validated spike-free Lumo GLB may be installed")
		assert(is_equal_approx(world.length, before), "Gate must not alter route length")
		assert(world.checkpoint_positions.size() == checkpoints, "Gate must not alter checkpoints")
		if result:
			var arch: Node3D = world.get_node("LumoKartMeshyStartFinishGate")
			assert(arch.get_child_count() == 5, "GLB, two contact surfaces and two colliders required")
			var visual: Node3D = arch.get_node("MeshyOriginalGeometry")
			assert(is_equal_approx(visual.rotation.y, 0.0), "LUMO KART text must face incoming racers")
			assert(arch.has_meta("foot_ground_drop_m"), "Terrain seating must record its drop")
			assert(float(arch.get_meta("foot_ground_drop_m")) < -0.05, "Floating feet must be lowered onto ground")
			assert(int(arch.get_meta("crisp_material_surfaces")) > 0, "Sharp PBR material sampling missing")
			assert(int(arch.get_meta("terrain_contact_shadow_count")) == 2)
			for side in [-1.0, 1.0]:
				var contact_name: String = "FootContactRight" if side > 0.0 else "FootContactLeft"
				var contact: MeshInstance3D = arch.get_node(contact_name)
				assert(contact.mesh != null and contact.mesh.get_surface_count() == 1, "Terrain contact not generated")
				var local_base: Vector3 = Vector3(
					side * GATE.FOOT_OFFSET_X,
					GATE.SOURCE_BOTTOM * GATE.ARCH_HEIGHT + visual.position.y,
					0.0
				)
				var foot: Vector3 = arch.to_global(local_base)
				var soil: float = world._ground_height(foot.x, foot.z)
				assert(foot.y <= soil - 0.05, "Foot base floats above real coast terrain")
				assert(foot.y >= soil - 3.0, "Foot must not sink meters into the terrain")
				print("[MeshyGate] foot contact ", contact_name, " soil=", soil, " base=", foot.y)
			assert(GATE.install(world), "Repeated installation must be safe")
			var arch_count: int = 0
			for child in world.get_children():
				if child.name.begins_with("LumoKartMeshyStartFinishGate"):
					arch_count += 1
			assert(arch_count == 1, "Never duplicate the start/finish arch")
			var left: StaticBody3D = arch.get_node("LeftColumn")
			var right: StaticBody3D = arch.get_node("RightColumn")
			assert(left.position.x < -WORLD.RAIL_LATERAL)
			assert(right.position.x > WORLD.RAIL_LATERAL)
			assert(left.position.x + 3.7 < -WORLD.RAIL_LATERAL)
			assert(right.position.x - 3.7 > WORLD.RAIL_LATERAL)
			assert(arch.transform.origin.distance_to(world.position_at(0.0)) < 0.01)
			print("[MeshyGate] imported model at exact start line: ", arch.get_meta("meshy_gate_asset"))
		else:
			print("[MeshyGate] procedural arch preserved (GLB not yet in repository)")
		world.queue_free()
		await process_frame
	print("[MeshyGate] PASS: lap/checkpoints unaffected; asset/fallback verified")
	quit(0)
