extends SceneTree
## Cinema must change the real batched coachwork without touching driver,
## authored vertex colors, geometry, brakes, LOD proxy or per-frame state.
const KART = preload("res://scripts/games/kart_vehicle.gd")
const FINISH = preload("res://scripts/games/visual/kart_cinema_materials.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for identity in FLEET.ids():
		var fleet_kart: LumoRaceKart = KART.new()
		root.add_child(fleet_kart)
		fleet_kart.configure("fox", Color("f08a2c"), identity)
		var proxy: Mesh = fleet_kart.far_mesh.mesh
		for quality in ["high", "low"]:
			fleet_kart.set_graphics_quality(quality)
			assert(fleet_kart.far_mesh.mesh == proxy, "Cinema must preserve every original fleet LOD proxy")
			var active_finishes := 0
			var coachwork: Node = fleet_kart.get_node("AuroraCoachwork")
			for node in coachwork.find_children("*", "MeshInstance3D", true, false):
				for surface in range(node.mesh.get_surface_count()):
					var source := node.mesh.surface_get_material(surface) as StandardMaterial3D
					if source != null and source.metallic > 0.2 and not source.emission_enabled:
						var finish: ShaderMaterial = node.get_surface_override_material(surface)
						assert(finish != null)
						assert(finish.get_meta("lumo_cinema_kind") == ("metal" if source.metallic >= 0.6 else "paint"))
						active_finishes += 1
			assert(active_finishes > 0, "Every fleet coachwork must use real cinema finishes")
		fleet_kart.free()
	var kart: LumoRaceKart = KART.new()
	root.add_child(kart)
	kart.configure("fox", Color("f08a2c"), "comet")
	var body: MeshInstance3D = kart.get_node("AuroraCoachwork/BatchedSculptedSurfaces")
	var mesh: Mesh = body.mesh
	var source_colors: Array = []
	for surface in range(mesh.get_surface_count()):
		source_colors.append(mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR])
	for profile in ["high", "low", "high"]:
		kart.set_graphics_quality(profile)
		var finishes := 0
		for surface in range(mesh.get_surface_count()):
			var source: StandardMaterial3D = mesh.surface_get_material(surface)
			assert(source_colors[surface] == mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR])
			if source.metallic > 0.2 and not source.emission_enabled:
				var active: ShaderMaterial = body.get_surface_override_material(surface)
				assert(active != null, "Coachwork must actually use Cinema in the player/garage quality path")
				assert(active.shader == (FINISH.MOBILE if profile == "low" else FINISH.HIGH))
				assert(active.get_shader_parameter("instance_colors"))
				finishes += 1
		assert(finishes >= 2)
		assert(body.mesh == mesh, "Quality switches must not rebuild the kart")
		for lamp in kart.brake_lights:
			assert(lamp.material_override is StandardMaterial3D and not lamp.visible)
	kart.set_look({"paint": Color("cc7240")})
	assert(kart.get_node("AuroraCoachwork/BatchedSculptedSurfaces").get_surface_override_material(0) is ShaderMaterial,
		"Workshop rebuild must retain the chosen cinema profile")
	kart.free()
	print("[KartCinemaKart] PASS: live coachwork finish, high/mobile switches, unchanged pigments/mesh/brakes and workshop rebuild")
	quit(0)
