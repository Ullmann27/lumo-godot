extends SceneTree
## Exercise the imported Blender tunnel through the real game's world builder.
const WORLD = preload("res://scripts/games/kart_world.gd")
const LAYOUT = preload("res://scripts/games/kart_production_tunnel_layout.gd")
const LAYER: int = 1 << 20
var _records: Array[Dictionary] = []
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("[ProductionTunnelPhysics] " + label)


func _run() -> void:
	var selected: String = "all"
	var full_detail: bool = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--track="):
			selected = argument.trim_prefix("--track=")
		if argument == "--full":
			full_detail = true
	for track in LAYOUT.THEMES:
		if selected != "all" and selected != track:
			continue
		var failures_before: int = _failures
		var world = WORLD.new()
		root.add_child(world)
		var before_build: int = Time.get_ticks_msec()
		world.build(not full_detail, track, true)
		var build_ms: int = Time.get_ticks_msec() - before_build
		await physics_frame
		await physics_frame
		_check(is_instance_valid(world.production_tunnels), track + ": actual build installs tunnel")
		if not is_instance_valid(world.production_tunnels):
			world.queue_free()
			await process_frame
			continue
		var tunnel = world.production_tunnels
		var layout: Dictionary = world.production_tunnel_layout
		var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
		var max_socket_error: float = 0.0
		var max_join_error: float = 0.0
		var max_join_rotation: float = 0.0
		var previous_out: Marker3D
		for module in tunnel.modules:
			var model: Node3D = module.get_node("CoreLOD0" if full_detail else "CoreLOD1")
			var inlet: Marker3D = model.find_child("SocketIn", true, false) as Marker3D
			var outlet: Marker3D = model.find_child("SocketOut", true, false) as Marker3D
			_check(inlet != null and outlet != null, track + ": module has imported sockets")
			if inlet == null or outlet == null:
				continue
			max_socket_error = maxf(max_socket_error, inlet.global_position.distance_to(world.to_global(world.position_at(float(module.get_meta("road_start"))))))
			max_socket_error = maxf(max_socket_error, outlet.global_position.distance_to(world.to_global(world.position_at(float(module.get_meta("road_end"))))))
			if previous_out != null:
				max_join_error = maxf(max_join_error, previous_out.global_position.distance_to(inlet.global_position))
				max_join_rotation = maxf(max_join_rotation, previous_out.global_basis.get_rotation_quaternion().angle_to(inlet.global_basis.get_rotation_quaternion()))
			previous_out = outlet
		_check(max_socket_error < 0.001, track + ": road and Blender socket positions agree")
		_check(max_join_error < 0.001 and max_join_rotation < 0.001, track + ": successive module sockets meet")
		_check(int(tunnel.statistics.collision_triangles) > 0, track + ": hollow collision faces exist")
		var free_ray_count: int = 0
		var free_capsule_count: int = 0
		var start: float = float(layout.start)
		var finish: float = float(layout.end)
		var steps: int = ceili((finish - start) / 1.5)
		for step in range(steps):
			var distance: float = lerpf(start, finish - 1.0, float(step) / maxi(1, steps - 1))
			for lateral in [-5.4, 0.0, 5.4]:
				var from: Vector3 = world.position_at(distance, lateral) + world.frame(distance).y * 2.52
				var to: Vector3 = world.position_at(distance + 1.0, lateral) + world.frame(distance + 1.0).y * 2.52
				var query := PhysicsRayQueryParameters3D.create(world.to_global(from), world.to_global(to), LAYER)
				_check(space.intersect_ray(query).is_empty(), track + ": reserved road and chase-camera ray stays clear")
				free_ray_count += 1
			for lateral in [-4.75, 0.0, 4.75]:
				var from: Vector3 = world.position_at(distance, lateral) + Vector3.UP * 0.035
				var to: Vector3 = world.position_at(distance + 1.0, lateral) + Vector3.UP * 0.035
				var motion: Dictionary = world.resolve_tunnel_motion(from, to)
				_check(not bool(motion.collided) and (motion.position as Vector3).distance_to(to) < 0.001, track + ": full kart capsule drives unobstructed")
				free_capsule_count += 1
		var middle: float = (start + finish) * 0.5
		var feet: Vector3 = world.position_at(middle) + Vector3.UP * 0.035
		var basis: Basis = world.frame(middle)
		var contacts: Dictionary = {}
		var targets: Dictionary = {
			"right_wall": feet + basis.x * 11.0,
			"left_wall": feet - basis.x * 11.0,
			"ceiling": feet + basis.y * 10.0,
			"diagonal_slide": feet + basis.x * 11.0 - basis.z * 4.0,
		}
		for kind in targets:
			var target: Vector3 = targets[kind]
			var contact: Dictionary = world.resolve_tunnel_motion(feet, target)
			_check(bool(contact.collided), track + ": " + kind + " has actual shape contact")
			_check((contact.position as Vector3).distance_to(target) > 0.5, track + ": " + kind + " changes movement")
			_check((contact.normal as Vector3).length() > 0.9, track + ": " + kind + " supplies contact normal")
			if kind == "ceiling":
				_check((contact.normal as Vector3).dot(basis.y) < -0.5, track + ": roof normal opposes upward jump")
			if kind == "diagonal_slide":
				_check(((contact.position as Vector3) - feet).dot(-basis.z) > 1.0, track + ": residual forward movement slides along wall")
			contacts[kind] = {"position": _vector(contact.position), "normal": _vector(contact.normal), "collided": contact.collided}
		var camera_anchor: Vector3 = feet + Vector3.UP
		var through_wall: Vector3 = feet + basis.x * 13.0 + Vector3.UP * 2.52
		var clipped: Vector3 = world.clip_tunnel_camera(camera_anchor, through_wall)
		_check(clipped.distance_to(through_wall) > 2.0, track + ": camera sphere stops at tunnel wall")
		var chase: Vector3 = feet + basis.z * 4.8 + Vector3.UP * 2.52
		_check(world.clip_tunnel_camera(camera_anchor, chase).distance_to(chase) < 0.001, track + ": ordinary chase camera remains free")
		tunnel.update_light_focus(feet + Vector3.UP * 2.52)
		var active_lights: int = 0
		for light in tunnel.light_pool:
			if light.visible:
				active_lights += 1
			_check(not light.shadow_enabled, track + ": mobile tunnel lights do not render shadow maps")
		_check(active_lights > 0 and active_lights <= (4 if full_detail else 3), track + ": bounded imported light-socket pool is active")
		_records.append({"track": track, "passed": failures_before == _failures, "statistics": tunnel.statistics,
			"build_milliseconds_on_headless_host": build_ms, "socket_position_error_m": max_socket_error,
			"joint_position_error_m": max_join_error, "joint_rotation_error_rad": max_join_rotation,
			"free_road_camera_rays": free_ray_count, "free_capsule_sweeps": free_capsule_count,
			"contacts": contacts, "active_lights": active_lights, "camera_wall_clip_m": clipped.distance_to(through_wall)})
		print("[ProductionTunnelPhysics] ", track, " ", "PASS" if failures_before == _failures else "FAIL", " build_ms=", build_ms, " triangles=", tunnel.statistics.triangles, " collision=", tunnel.statistics.collision_triangles, " sockets=", max_socket_error)
		world.queue_free()
		await process_frame
		await physics_frame
	_check(not _records.is_empty(), "selected track produced a record")
	var directory: String = "res://evidence/lumo_kart_art/tracks/runtime"
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory + "/physics_" + selected + ("_full" if full_detail else "_mobile") + ".json"
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"passed": _failures == 0, "failures": _failures,
			"engine": Engine.get_version_info(), "device_fps_measured": false, "tracks": _records}, "  "))
	quit(0 if _failures == 0 else 1)


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
