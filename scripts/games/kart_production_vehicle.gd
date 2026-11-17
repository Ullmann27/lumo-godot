extends Node3D
## Frozen Aurora GLBs on one stable mechanical hierarchy. Only mesh visibility
## changes at LOD boundaries; wheel/driver anchors never move or get replaced.

const VARIANTS: Array[String] = ["comet", "glider", "turbo"]
const WHEELS: Array[String] = ["FL", "RL", "FR", "RR"]
const MODEL_DIRECTORY := "res://assets/kart/production/karts/"
const LOD_HYSTERESIS := 2.0
static var _scenes: Dictionary = {}

var variant := ""
var asset_root: Node3D
var steering_wheel: Node3D
var wheel_pivots: Array[Node3D] = []
var wheel_rotors: Array[Node3D] = []
var wheel_rest_grips: Array[Vector3] = []
var boost_positions: Array[Vector3] = []
var lod_level := -1
var source_paths: Array[String] = []
var _lod_meshes: Array = [[], [], []]
var _pivot_bases: Array[Basis] = []
var _rotor_bases: Array[Basis] = []
var _steering_basis := Basis.IDENTITY
var _materials: Dictionary = {}
var _brake_finish: StandardMaterial3D
var _braking := -1.0
var _near_distance := 16.0
var _far_distance := 36.0
var _preview_detail := false


static func supports(id: String) -> bool:
	return id in VARIANTS


static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		var loaded := ResourceLoader.load(path, "PackedScene") as PackedScene
		if loaded == null:
			push_error("LUMO production kart import is unavailable: " + path)
			return null
		_scenes[path] = loaded
	return _scenes[path] as PackedScene


func build(id: String, look: Dictionary, stock: Dictionary) -> bool:
	if not supports(id) or asset_root != null:
		return false
	variant = id
	name = "ProductionKart"
	set_process(false)
	for level in range(3):
		var suffix := "" if level == 0 else "_lod%d" % level
		var path := MODEL_DIRECTORY + "aurora_" + id + suffix + ".glb"
		var packed := _scene(path)
		if packed == null:
			return false
		var source := packed.instantiate() as Node3D
		if source == null:
			return false
		source_paths.append(path)
		for player in source.find_children("*", "AnimationPlayer", true, false):
			# The review clip is never an autonomous game clock.
			player.free()
		if level == 0:
			asset_root = source
			add_child(asset_root)
			for item in source.find_children("*", "MeshInstance3D", true, false):
				_lod_meshes[0].append(item)
		else:
			# The exported node/marker contract is identical in all three LODs.
			# Transplant only mesh instances; keep the LOD0 mechanical nodes alive.
			for item in source.find_children("*", "MeshInstance3D", true, false):
				var mesh := item as MeshInstance3D
				var target := asset_root.get_node_or_null(source.get_path_to(mesh.get_parent()))
				if not target is Node3D:
					push_error("LUMO kart LOD hierarchy mismatch: " + path)
					source.free()
					return false
				# Imported ownership points at the temporary LOD scene. Clear it
				# before moving the instance onto the persistent mechanical tree.
				mesh.owner = null
				mesh.get_parent().remove_child(mesh)
				mesh.name = str(mesh.name) + "_LOD%d" % level
				target.add_child(mesh)
				_lod_meshes[level].append(mesh)
			source.free()
		for mesh in _lod_meshes[level]:
			_apply_appearance(mesh, look, stock)
	steering_wheel = asset_root.find_child("SteeringWheel", true, false) as Node3D
	if steering_wheel == null:
		return false
	_steering_basis = steering_wheel.basis
	for code in WHEELS:
		var pivot := asset_root.find_child("Steer_" + code, true, false) as Node3D
		var rotor := asset_root.find_child("Wheel_" + code, true, false) as Node3D
		if pivot == null or rotor == null:
			return false
		pivot.set_meta("front", code.begins_with("F"))
		pivot.set_meta("height", pivot.position.y)
		wheel_pivots.append(pivot)
		wheel_rotors.append(rotor)
		_pivot_bases.append(pivot.basis)
		_rotor_bases.append(rotor.basis)
	for side in ["L", "R"]:
		var grip := steering_wheel.get_node_or_null("Grip_" + side) as Node3D
		var boost := asset_root.find_child("Boost_" + side, true, false) as Node3D
		if grip == null or boost == null:
			return false
		wheel_rest_grips.append(grip.position)
		boost_positions.append(boost.position)
	set_lod(0)
	set_braking(0.0)
	return true


func _apply_appearance(mesh: MeshInstance3D, look: Dictionary, stock: Dictionary) -> void:
	var wheel_part := str(mesh.name).begins_with("Wheel_")
	var custom_paint: bool = false
	for channel in ["paint", "trim", "accent"]:
		if look.has(channel) and look.get(channel) != stock.get(channel):
			custom_paint = true
	var custom_neon: bool = bool(look.get("neon_custom", false)) or (
		look.has("neon") and look.get("neon") != stock.get("neon")
	)
	for surface in range(mesh.mesh.get_surface_count()):
		var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		if original == null:
			continue
		var material_name := original.resource_name
		var key := material_name + (":wheel" if wheel_part else ":body")
		if _materials.has(key):
			mesh.set_surface_override_material(surface, _materials[key])
			continue
		var finish: StandardMaterial3D
		if material_name.ends_with("_paint") and custom_paint:
			finish = original.duplicate() as StandardMaterial3D
			finish.albedo_color = look.get("paint", original.albedo_color)
		elif material_name == "CeramicPearl" and custom_paint:
			finish = original.duplicate() as StandardMaterial3D
			finish.albedo_color = look.get("trim", original.albedo_color)
		elif material_name == "SatinAccent" and custom_paint:
			finish = original.duplicate() as StandardMaterial3D
			finish.albedo_color = look.get("accent", original.albedo_color)
		elif material_name == "BrushedAluminium" and wheel_part and (
			bool(look.get("rim_neon", false))
			or look.get("rim", Color("c9d6e6")) != Color("c9d6e6")
		):
			finish = original.duplicate() as StandardMaterial3D
			finish.albedo_color = look.get("rim", original.albedo_color)
			if bool(look.get("rim_neon", false)):
				finish.emission_enabled = true
				finish.emission = look.get("neon", Color("72e6ff"))
				finish.emission_energy_multiplier = 0.6
		elif material_name == "InsetCyanLens" and custom_neon:
			finish = original.duplicate() as StandardMaterial3D
			finish.albedo_color = look.get("neon", original.albedo_color)
			finish.emission = finish.albedo_color
		elif material_name == "RearBrakeLens":
			finish = original.duplicate() as StandardMaterial3D
			_brake_finish = finish
		if finish != null:
			_materials[key] = finish
			mesh.set_surface_override_material(surface, finish)


func apply_motion(spin_phase: float, steer: float) -> void:
	var steering := clampf(steer, -1.0, 1.0) if is_finite(steer) else 0.0
	for index in range(wheel_rotors.size()):
		# Forward is -Z. A negative X angular velocity cancels the forward
		# velocity at the tyre's bottom contact; reverse reverses this rotation.
		wheel_rotors[index].basis = _rotor_bases[index] * Basis(Quaternion(Vector3.RIGHT, -spin_phase))
		wheel_pivots[index].basis = _pivot_bases[index] * Basis(Quaternion(
			Vector3.UP, -steering * 0.34 if bool(wheel_pivots[index].get_meta("front")) else 0.0
		))
	steering_wheel.basis = _steering_basis * Basis(Quaternion(Vector3.BACK, -steering * 0.40))


func set_braking(amount: float) -> void:
	var value := clampf(amount, 0.0, 1.0)
	if is_equal_approx(value, _braking):
		return
	_braking = value
	if _brake_finish != null:
		_brake_finish.emission_enabled = true
		_brake_finish.emission_energy_multiplier = 0.35 + value * 2.25


func set_graphics_quality(profile: String) -> void:
	match profile:
		"light", "low":
			_near_distance = 7.0
			_far_distance = 18.0
		"medium":
			_near_distance = 11.0
			_far_distance = 27.0
		_:
			_near_distance = 16.0
			_far_distance = 36.0


func set_preview_detail(enabled: bool) -> void:
	_preview_detail = enabled
	if enabled:
		set_lod(0)


func update_distance(distance_squared: float) -> void:
	if _preview_detail:
		set_lod(0)
		return
	var distance := sqrt(maxf(distance_squared, 0.0))
	var requested := lod_level
	if lod_level == 0:
		requested = 2 if distance > _far_distance else (1 if distance > _near_distance else 0)
	elif lod_level == 1:
		requested = 0 if distance < _near_distance - LOD_HYSTERESIS else (2 if distance > _far_distance else 1)
	else:
		requested = 0 if distance < _near_distance - LOD_HYSTERESIS else (1 if distance < _far_distance - LOD_HYSTERESIS else 2)
	set_lod(requested)


func set_lod(level: int) -> void:
	var next_level := clampi(level, 0, 2)
	if next_level == lod_level:
		return
	lod_level = next_level
	for index in range(_lod_meshes.size()):
		for mesh in _lod_meshes[index]:
			mesh.visible = index == lod_level


func visible_surface_count() -> int:
	var count := 0
	for mesh in _lod_meshes[lod_level]:
		count += mesh.mesh.get_surface_count()
	return count
