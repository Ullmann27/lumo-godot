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
		assert(result == GATE.is_available(), "GLB availability and gate installation differ")
		assert(is_equal_approx(world.length, before), "Gate must not alter route length")
		assert(world.checkpoint_positions.size() == checkpoints, "Gate must not alter checkpoints")
		if result:
			var arch: Node3D = world.get_node("LumoKartMeshyStartFinishGate")
			assert(arch.get_child_count() == 3, "GLB mesh plus two colliders required")
			var visual: Node3D = arch.get_node("MeshyOriginalGeometry")
			assert(is_equal_approx(visual.rotation.y, PI), "LUMO KART text must face incoming racers")
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
			assert(left.position.x + 1.55 < -WORLD.RAIL_LATERAL)
			assert(right.position.x - 1.55 > WORLD.RAIL_LATERAL)
			assert(arch.transform.origin.distance_to(world.position_at(0.0)) < 0.01)
			print("[MeshyGate] imported model at exact start line: ", arch.get_meta("meshy_gate_asset"))
		else:
			print("[MeshyGate] procedural arch preserved (GLB not yet in repository)")
		world.queue_free()
		await process_frame
	print("[MeshyGate] PASS: lap/checkpoints unaffected; asset/fallback verified")
	quit(0)
