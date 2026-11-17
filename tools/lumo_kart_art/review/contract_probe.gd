extends SceneTree
## Exercise the provided sockets and separate hollow collision in real Godot physics.

var repo := ""


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://../../../").simplify_path().trim_suffix("/")
	call_deferred("_run")


func _run() -> void:
	var loader = load(repo.path_join("tools/lumo_kart_art/asset_contract_loader.gd"))
	var prefix := repo.path_join("assets/kart/production/tracks/zauberwald/")
	var straight: Node3D = loader.load_model(prefix + "straight_12m.glb")
	var curve: Node3D = loader.load_model(prefix + "curve_right_30.glb")
	assert(straight != null and curve != null)
	root.add_child(straight)
	root.add_child(curve)
	straight.position = Vector3(4, 1, -3)
	straight.rotation.y = 0.25
	assert(loader.connect_modules(straight, curve))
	var outlet := straight.find_child("SocketOut", true, false) as Node3D
	var inlet := curve.find_child("SocketIn", true, false) as Node3D
	var position_error := outlet.global_position.distance_to(inlet.global_position)
	var basis_error := (outlet.global_basis.x - inlet.global_basis.x).length()
	assert(position_error < 0.0001 and basis_error < 0.0001)
	var proxy: Node3D = loader.load_model(prefix + "straight_12m_collision.glb")
	assert(proxy != null)
	proxy.transform = straight.transform
	# Deliberately build the body before adding the proxy to the scene tree.
	var collision: StaticBody3D = loader.create_tunnel_collision(proxy)
	root.add_child(collision)
	for child in collision.get_children():
		assert(child.shape is ConcavePolygonShape3D, "A whole-tunnel convex hull blocks the route")
	proxy.free()
	await physics_frame
	await physics_frame
	var space := root.get_world_3d().direct_space_state
	var origin := straight.global_transform * Vector3(0, 2.52, -6)
	var observations := {}
	for spec in [
		["travel_lane", Vector3(0, 2.52, -10), false],
		["roof", Vector3(0, 12, -6), true],
		["left_wall", Vector3(-10, 2.52, -6), true],
		["right_wall", Vector3(10, 2.52, -6), true],
	]:
		var query := PhysicsRayQueryParameters3D.create(origin, straight.global_transform * spec[1])
		var hit := space.intersect_ray(query)
		var collided := not hit.is_empty()
		observations[spec[0]] = {"collided": collided, "expected": spec[2]}
		assert(collided == spec[2], "Hollow tunnel collision contract failed: " + str(spec[0]))
	var output := repo.path_join("evidence/lumo_kart_art/review/godot_collision_contract.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"passed": true, "godot": Engine.get_version_info().string,
		"socket_position_error_m": position_error, "socket_basis_error": basis_error,
		"physics_rays": observations, "physical_android": false,
		"straight_sha256": FileAccess.get_sha256(prefix + "straight_12m.glb"),
		"curve_sha256": FileAccess.get_sha256(prefix + "curve_right_30.glb"),
		"collision_sha256": FileAccess.get_sha256(prefix + "straight_12m_collision.glb")}, "  "))
	file.close()
	straight.free()
	curve.free()
	collision.free()
	print("[LumoKartArtContracts] PASS socket joins and hollow static physics")
	quit(0)
