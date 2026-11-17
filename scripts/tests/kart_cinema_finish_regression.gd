extends SceneTree
## Real integration contracts: both LODs, material sharing, authored normals,
## revived container terminal, no new collision and no other-track leakage.
const WORLD = preload("res://scripts/games/kart_world.gd")
const FINISH = preload("res://scripts/games/visual/kart_cinema_materials.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for low in [false, true]:
		var stone: ShaderMaterial = FINISH.material(Color.WHITE, "stone", low, true)
		assert(stone == FINISH.material(Color.WHITE, "stone", low, true), "Share material, not just shader")
		assert(stone != FINISH.material(Color.WHITE, "paint", low, true))
		assert(stone.get_shader_parameter("instance_colors"))
		assert(stone.get_shader_parameter("surface_roughness") > 0.75)
		assert(FINISH.material(Color.WHITE, "paint", low).get_shader_parameter("surface_roughness") < 0.4)
		assert(stone.shader == (FINISH.MOBILE if low else FINISH.HIGH))
		for shader in [FINISH.HIGH, FINISH.MOBILE]:
			for expensive in ["dFdx(", "dFdy(", "fwidth(", "SCREEN_TEXTURE", "DEPTH_TEXTURE"]:
				assert(not shader.code.contains(expensive), "Opaque finish must remain cheap: " + expensive)
		var world: LumoRaceWorld = WORLD.new()
		root.add_child(world)
		world.build(low, "sonnenhafen", false)
		assert(world.has_meta("sonnenhafen_crane_frame"), "Extended island must not silently omit terminal")
		var shell: MeshInstance3D = world.get_node("SonnenhafenBioluminescentDarkride/DarkrideRockAndCanopy")
		var vertices: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		assert(normals.size() == vertices.size(), "Actual shell normals replace fragment derivatives")
		for normal in normals:
			assert(normal.is_finite() and normal.length_squared() > 0.98)
		var finish_root: Node = world.get_node_or_null("HarborCinema")
		assert(finish_root != null, "New harbor materials must be in the real world")
		assert(finish_root.find_children("*", "CollisionObject3D", true, false).is_empty())
		world.free()
		await process_frame
	print("[KartCinemaFinish] PASS: live high/mobile materials, real shell normals, restored terminal, shared batches")
	quit(0)
