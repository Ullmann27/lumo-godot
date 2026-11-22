extends SceneTree
## Messung: wo sitzen Lumo (kart_seated) und ein Mitspieler-Rig im Raum des
## Fliegers? Liefert Hüfte, Knie, Füße, Hände und Kopf für die Cockpit-Maße.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var wheel := Node3D.new()
	wheel.name = "Yoke"
	wheel.position = Vector3(0, 0.95, -0.55)
	holder.add_child(wheel)
	holder.set("steering_wheel", wheel)
	holder.set_meta("probe", true)
	var fake = load("res://scripts/tests/sky_post_seat_probe_vehicle.gd").new()
	fake.name = "Glider"
	root.add_child(fake)
	await process_frame
	var adapter = load("res://scripts/characters/lumo/lumo_kart_animation_adapter.gd").new()
	fake.add_child(adapter)
	var ok: bool = adapter.bind_visual(fake)
	print("lumo bind ", ok)
	await process_frame
	adapter.advance_visual(0.1)
	var skeleton: Skeleton3D = adapter.actor.skeleton
	for bone_name in [
		"Root",
		"Hips",
		"Pelvis",
		"Spine",
		"Chest",
		"Neck",
		"Head",
		"Thigh.L",
		"Shin.L",
		"Foot.L",
		"ToeTip.L",
		"Hand.L",
		"Hand.R",
		"UpperArm.L",
		"TailBase",
		"Tail1",
		"Tail2",
		"Tail3",
		"EarTip.L",
		"Ear.L"
	]:
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			continue
		var at: Vector3 = fake.to_local(
			skeleton.to_global(skeleton.get_bone_global_pose(index).origin)
		)
		print("LUMO %s %s" % [bone_name, at])
	var lowest := INF
	var highest := -INF
	var minimum := Vector3.INF
	var maximum := -Vector3.INF
	for mesh in adapter.actor.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (
			(fake.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		)
		minimum = minimum.min(box.position)
		maximum = maximum.max(box.end)
	print("LUMO mesh box ", minimum, " .. ", maximum)
	var names: Array[String] = []
	for index in range(skeleton.get_bone_count()):
		names.append(skeleton.get_bone_name(index))
	print("LUMO bones ", ", ".join(names))
	# Mitspieler
	var roster = load("res://scripts/games/lumo_opponent_roster.gd")
	var driver = load("res://scripts/games/kart_production_driver.gd").new()
	fake.add_child(driver)
	print("rival bind ", driver.bind_visual(fake, "owl"))
	await process_frame
	driver.advance_tick(0.1)
	var rival: Skeleton3D = driver.skeleton
	for bone_name in [
		"Root",
		"Pelvis",
		"Spine",
		"Chest",
		"Head",
		"Thigh.L",
		"Shin.L",
		"Foot.L",
		"Hand.L",
		"Hand.R",
		"Tail"
	]:
		var index := rival.find_bone(bone_name)
		var at: Vector3 = fake.to_local(rival.to_global(rival.get_bone_global_pose(index).origin))
		print("RIVAL %s %s" % [bone_name, at])
	minimum = Vector3.INF
	maximum = -Vector3.INF
	for mesh in driver.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (
			(fake.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		)
		minimum = minimum.min(box.position)
		maximum = maximum.max(box.end)
	print("RIVAL mesh box ", minimum, " .. ", maximum, " roster ", roster.for_game("kart").size())
	quit()
