extends Node3D
## Frozen Aurora GLBs on one stable mechanical hierarchy. Only mesh visibility
## changes at LOD boundaries; wheel/driver anchors never move or get replaced.

const VARIANTS: Array[String] = ["comet", "glider", "turbo"]
## The three mechanical platforms carry fourteen individually fitted Blender exteriors.
const BODY_OF: Dictionary = {
	"comet": "comet",
	"boru_rally": "comet",
	"nala_comet": "comet",
	"zuri_volt": "comet",
	"terra": "comet",
	"koloss": "comet",
	"glider": "glider",
	"gecko_velo": "glider",
	"noa_tide": "glider",
	"iva_aurora": "glider",
	"turbo": "turbo",
	"blitz": "turbo",
	"phantom": "turbo",
	"stella": "turbo",
}
const WHEELS: Array[String] = ["FL", "RL", "FR", "RR"]
const MODEL_DIRECTORY := "res://assets/kart/production/karts/"
const SHELL_DIRECTORY := "res://assets/kart/production/fleet/"
const MESHY_SHELL_DIRECTORY := "res://assets/kart/production/meshy/"
const MESHY_CLOSE_MARGIN := Vector3(0.96, 0.96, 0.96)
const LOD_HYSTERESIS := 2.0
## Lackart (matt/metallic/perlmutt), Startnummer und Fantasie-Aufkleber je Kart-Design.
const FINISH = preload("res://scripts/games/kart_vehicle_finish.gd")
const EVOLUTION = preload("res://scripts/games/kart_evolution_geometry.gd")
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
var design := ""
var _finish := "metallic"
var _profile := "high"
## Eigene Lack-Kopien dieses Karts (je Karosserie-Teil), damit Flakes nach Profil schalten.
var _paints: Array[StandardMaterial3D] = []
## Nummern und Aufkleber: nur in der nahen LOD sichtbar.
var _dressing: Array[Node3D] = []
## Material details from the selected shell are visible in close-up previews.
var _showcase_meshes: Array[MeshInstance3D] = []
var shell_path := ""
var meshy_shell_path := ""
var meshy_close_mesh: MeshInstance3D
var stock_close_mesh: MeshInstance3D
## Austauschbare Anbauteile (Radaufsätze, Auspuffblenden), siehe kart_tuning.gd und
## tools/lumo_kart_art/karts/build_parts.py. Wurzel jedes Teils = sein Montagepunkt.
const PARTS_PATH := "res://assets/kart/production/parts/kart_parts.glb"
const TUNING = preload("res://scripts/games/kart_tuning.gd")
## Montagepunkte der Leistungsteile je Karosserie: Heckdeck hinter dem Sitz (Motor), Fuß des
## Heckflügels (bei Glider und Turbo auf dem Serienflügel) und rechte Deckseite (Turbo).
const PART_MOUNTS: Dictionary = {
	"comet":
	{
		"engine": Vector3(0, 0.64, 0.70),
		"wing": Vector3(0, 0.66, 1.00),
		"booster": Vector3(0.29, 0.68, 0.86)
	},
	"glider":
	{
		"engine": Vector3(0, 0.64, 0.70),
		"wing": Vector3(0, 1.02, 1.02),
		"booster": Vector3(0.27, 0.68, 0.86)
	},
	"turbo":
	{
		"engine": Vector3(0, 0.64, 0.70),
		"wing": Vector3(0, 0.95, 1.02),
		"booster": Vector3(0.31, 0.68, 0.86)
	},
}
## Montierte Teile je Steckplatz ("wheel_cover"/"exhaust" -> id); Tests lesen das.
var mounted_parts: Dictionary = {}
var _part_nodes: Array[Node3D] = []
## The sculpted in-code karts remain the fallback for a body that cannot be
## loaded. Tests set this to keep that fallback path exercised.
static var fallback_only: bool = false

## Gefederter Aufbau: Karosserie, Lack-Details und Aufbauteile nicken, rollen und federn um
## den Sitzpunkt. Räder, Achsen, Lenkrad und Fahrerpunkte bleiben auf dem Fahrwerk.
var _sprung_body: Node3D
var _body_pitch := 0.0
var _body_roll := 0.0
var _body_heave := 0.0
var _body_pivot := Vector3(0.0, 0.31, 0.2)


static func supports(id: String) -> bool:
	return BODY_OF.has(id) and not fallback_only


## Mechanical platform for suspension, steering, grip anchors and wheels.
static func body_of(id: String) -> String:
	return str(BODY_OF.get(id, ""))


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
	variant = body_of(id)
	design = id
	_finish = FINISH.finish_of(id)
	name = "ProductionKart"
	set_process(false)
	for level in range(3):
		var suffix := "" if level == 0 else "_lod%d" % level
		var path := MODEL_DIRECTORY + "aurora_" + variant + suffix + ".glb"
		var packed := _scene(path)
		if packed == null:
			return false
		var source := packed.instantiate() as Node3D
		if source == null:
			return false
		source_paths.append(path)
		# Keep the complete animated mechanical hierarchy from the production core.
		# The replacement includes its own seat, body panels, lights and decal points.
		var old_body := source.find_child("Coachwork", true, false)
		if old_body == null:
			source.free()
			return false
		for child in old_body.get_children():
			if child is MeshInstance3D or str(child.name).begins_with("Decal_"):
				child.free()
			elif child.name == "BonnetBadge":
				for old_mesh in child.find_children("*", "MeshInstance3D", true, false):
					old_mesh.free()
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
	if not _install_shell(look, stock):
		return false
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
	var dressed_look: Dictionary = stock.duplicate()
	dressed_look.merge(look, true)
	_dressing = FINISH.dress(asset_root, design, dressed_look)
	var modern_trim: Node3D = EVOLUTION.vehicle_trim(variant)
	asset_root.add_child(modern_trim)
	_dressing.append(modern_trim)
	_build_sprung_body(modern_trim)
	for mesh: MeshInstance3D in modern_trim.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if original != null and original.resource_name == "PartPaint":
				var tinted := original.duplicate() as StandardMaterial3D
				tinted.albedo_color = dressed_look.get("paint", Color("e8eef6"))
				mesh.set_surface_override_material(surface, tinted)
	set_lod(0)
	set_braking(0.0)
	_refresh_finish()
	return true


func _install_shell(look: Dictionary, stock: Dictionary) -> bool:
	shell_path = SHELL_DIRECTORY + design + ".glb"
	var packed := _scene(shell_path)
	if packed == null:
		return false
	var shell := packed.instantiate() as Node3D
	if shell == null:
		return false
	asset_root.add_child(shell)
	stock_close_mesh = shell.find_child("LOD0", true, false) as MeshInstance3D
	if stock_close_mesh == null:
		return false
	var meshy_ready := _install_meshy_close_shell(shell, stock_close_mesh)
	for level in range(3):
		var mesh := shell.find_child("LOD%d" % level, true, false) as MeshInstance3D
		if mesh == null:
			return false
		if level == 0 and meshy_ready:
			# Keep the proven authored shell in the tree as an immediate fallback,
			# but never draw it underneath the new close-range Meshy shell.
			mesh.visible = false
			continue
		_lod_meshes[level].append(mesh)
		_apply_appearance(mesh, look, stock)
	var detail := shell.find_child("ShowroomDetail", true, false) as MeshInstance3D
	if detail != null:
		detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_showcase_meshes.append(detail)
	return true


func _install_meshy_close_shell(shell: Node3D, target_mesh: MeshInstance3D) -> bool:
	meshy_shell_path = MESHY_SHELL_DIRECTORY + design + ".glb"
	if not ResourceLoader.exists(meshy_shell_path):
		meshy_shell_path = ""
		return false
	var packed := _scene(meshy_shell_path)
	if packed == null:
		meshy_shell_path = ""
		return false
	var source_root := packed.instantiate() as Node3D
	if source_root == null:
		meshy_shell_path = ""
		return false
	var source_mesh := source_root as MeshInstance3D
	if source_mesh == null:
		var imported_meshes := source_root.find_children("*", "MeshInstance3D", true, false)
		if not imported_meshes.is_empty():
			source_mesh = imported_meshes[0] as MeshInstance3D
	if source_mesh == null or source_mesh.mesh == null:
		source_root.free()
		meshy_shell_path = ""
		return false

	# Copy only the imported render mesh. Mechanical nodes, wheels, steering,
	# seat, driver anchors, collision and tuning stay on the proven chassis.
	var visual := MeshInstance3D.new()
	visual.name = "MeshyLOD0_" + design
	visual.mesh = source_mesh.mesh
	var source_transform := _relative_transform(source_mesh, null)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var fallback_finish := StandardMaterial3D.new()
	fallback_finish.albedo_color = Color("9aa8b8")
	fallback_finish.metallic = 0.28
	fallback_finish.roughness = 0.46
	for surface in range(visual.mesh.get_surface_count()):
		if visual.mesh.surface_get_material(surface) == null:
			visual.set_surface_override_material(surface, fallback_finish)
	shell.add_child(visual)
	source_root.free()

	var target_box := target_mesh.get_aabb()
	var source_box := source_transform * visual.get_aabb()
	if (
		target_box.size.x <= 0.001 or target_box.size.y <= 0.001 or target_box.size.z <= 0.001
		or source_box.size.x <= 0.001 or source_box.size.y <= 0.001 or source_box.size.z <= 0.001
	):
		visual.queue_free()
		meshy_shell_path = ""
		return false

	# Meshy normalizes these vehicle bodies with their longitudinal axis on X.
	# LUMO's mechanical platform drives forward on -Z. A -90° yaw therefore
	# maps the low/nose end of the incoming body to the existing forward axis.
	var local_scale := Vector3(
		target_box.size.z / source_box.size.x,
		target_box.size.y / source_box.size.y,
		target_box.size.x / source_box.size.z
	) * MESHY_CLOSE_MARGIN
	# Scale in the imported mesh's axes before yawing into the chassis axes.
	# Basis.scaled() instead scales in parent axes and stretches the length a
	# second time (Glider became 4.8 m long instead of its 2.44 m envelope).
	var fit_basis := Basis(Vector3.UP, -PI / 2.0).scaled_local(local_scale)
	var fitted := Transform3D(
		fit_basis, target_box.get_center() - fit_basis * source_box.get_center()
	)
	# Fleet LOD0 meshes have authored object pivots. Their AABB is mesh-local,
	# while this visual is a sibling: preserve the complete target transform,
	# including the 0.467 m / 1.122 m offsets on the Comet-based shells.
	visual.transform = _relative_transform(target_mesh, shell) * fitted * source_transform
	visual.set_meta("meshy_visual_only", true)
	visual.set_meta("mechanics_preserved", true)
	visual.set_meta("fit_target_size", target_box.size)
	visual.set_meta("fit_source_size", source_box.size)
	visual.set_meta("fit_scale", local_scale)
	visual.set_meta("fit_yaw", -PI / 2.0)
	visual.set_meta("source_path", meshy_shell_path)
	meshy_close_mesh = visual
	_lod_meshes[0].append(visual)
	source_paths.append(meshy_shell_path)
	return true


static func _relative_transform(node: Node3D, parent: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current := node
	while current != null and current != parent:
		result = current.transform * result
		current = current.get_parent_node_3d()
	return result


func _apply_appearance(mesh: MeshInstance3D, look: Dictionary, stock: Dictionary) -> void:
	var wheel_part := str(mesh.name).begins_with("Wheel_")
	var custom_paint: bool = false
	for channel in ["paint", "trim", "accent"]:
		if look.has(channel) and look.get(channel) != stock.get(channel):
			custom_paint = true
	var custom_neon: bool = (
		bool(look.get("neon_custom", false))
		or (look.has("neon") and look.get("neon") != stock.get("neon"))
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
		if material_name.ends_with("_paint"):
			# Jede Lackschicht ist eine eigene Kopie: Lackart je Design, ohne Stock-Material
			# anderer Karts zu verändern.
			finish = original.duplicate() as StandardMaterial3D
			# Serienlack kommt aus der Flotte (Comet: kräftiges Kometenblau statt Nachtblau,
			# damit Lack und Glanz im Schauraum und auf der Strecke lesbar sind).
			finish.albedo_color = (
				look.get("paint", original.albedo_color)
				if custom_paint
				else stock.get("paint", original.albedo_color)
			)
			_paints.append(finish)
		elif material_name == "CeramicPearl" and custom_paint:
			finish = original.duplicate() as StandardMaterial3D
			finish.albedo_color = look.get("trim", original.albedo_color)
		elif material_name == "SatinAccent" and custom_paint:
			finish = original.duplicate() as StandardMaterial3D
			finish.albedo_color = look.get("accent", original.albedo_color)
		elif (
			material_name == "BrushedAluminium"
			and wheel_part
			and (
				bool(look.get("rim_neon", false))
				or look.get("rim", Color("c9d6e6")) != Color("c9d6e6")
			)
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


func _build_sprung_body(modern_trim: Node3D) -> void:
	_sprung_body = Node3D.new()
	_sprung_body.name = "SprungBody"
	asset_root.add_child(_sprung_body)
	var seat := asset_root.find_child("DriverSeat", true, false) as Node3D
	if seat != null:
		_body_pivot = _relative_transform(seat, asset_root).origin
	var body_parts: Array[Node] = [modern_trim]
	var coachwork := asset_root.find_child("Coachwork", true, false)
	if coachwork != null:
		body_parts.append(coachwork)
	# The whole fleet shell (all LODs, decals, Meshy close-range shell) hangs on the springs.
	var shell: Node = stock_close_mesh if is_instance_valid(stock_close_mesh) else null
	while shell != null and shell.get_parent() != asset_root:
		shell = shell.get_parent()
	if shell != null:
		body_parts.append(shell)
	for part in body_parts:
		if not part is Node3D or part.get_parent() == _sprung_body:
			continue
		# Built before the kart enters the tree: keep the pose via local transforms.
		var in_root := _relative_transform(part as Node3D, asset_root)
		part.reparent(_sprung_body, false)
		(part as Node3D).transform = in_root


## Aufbaubewegung in Radiant/Metern (Nicken +: Nase hoch, Rollen +: linke Seite tiefer).
func set_body_motion(pitch: float, roll: float, heave: float) -> void:
	if not is_instance_valid(_sprung_body):
		return
	_body_pitch = clampf(pitch, -0.08, 0.08) if is_finite(pitch) else 0.0
	_body_roll = clampf(roll, -0.08, 0.08) if is_finite(roll) else 0.0
	_body_heave = clampf(heave, -0.06, 0.06) if is_finite(heave) else 0.0
	var turn := Basis.from_euler(Vector3(_body_pitch, 0.0, _body_roll))
	var offset := _body_pivot - turn * _body_pivot + Vector3(0.0, _body_heave, 0.0)
	_sprung_body.transform = Transform3D(turn, offset)


## Aktuelle Aufbaubewegung (Nicken, Rollen, Hub) und der gefederte Knoten, für Tests und Garage.
func body_motion() -> Vector3:
	return Vector3(_body_pitch, _body_roll, _body_heave)


func sprung_node() -> Node3D:
	return _sprung_body


func apply_motion(spin_phase: float, steer: float) -> void:
	var steering := clampf(steer, -1.0, 1.0) if is_finite(steer) else 0.0
	for index in range(wheel_rotors.size()):
		# Forward is -Z. A negative X angular velocity cancels the forward
		# velocity at the tyre's bottom contact; reverse reverses this rotation.
		wheel_rotors[index].basis = (
			_rotor_bases[index] * Basis(Quaternion(Vector3.RIGHT, -spin_phase))
		)
		wheel_pivots[index].basis = (
			_pivot_bases[index]
			* Basis(
				Quaternion(
					Vector3.UP,
					-steering * 0.34 if bool(wheel_pivots[index].get_meta("front")) else 0.0
				)
			)
		)
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
	_profile = profile
	_refresh_finish()
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
	_refresh_finish()
	if enabled:
		set_lod(0)
	_sync_showcase()


func _sync_showcase() -> void:
	for mesh in _showcase_meshes:
		mesh.visible = _preview_detail and lod_level == 0


func showcase_mesh_count() -> int:
	return _showcase_meshes.size()


## Klarlack-Flakes (Detail-Normal-Map) nur in HIGH oder als Schaustück in Garage/Werkstatt.
func _refresh_finish() -> void:
	var flakes: bool = _preview_detail or _profile == "high"
	for paint in _paints:
		FINISH.apply_paint(paint, _finish, flakes)


func dressing_nodes() -> Array[Node3D]:
	return _dressing


func update_distance(distance_squared: float) -> void:
	if _preview_detail:
		set_lod(0)
		return
	var distance := sqrt(maxf(distance_squared, 0.0))
	var requested := lod_level
	if lod_level == 0:
		requested = 2 if distance > _far_distance else (1 if distance > _near_distance else 0)
	elif lod_level == 1:
		requested = (
			0
			if distance < _near_distance - LOD_HYSTERESIS
			else (2 if distance > _far_distance else 1)
		)
	else:
		requested = (
			0
			if distance < _near_distance - LOD_HYSTERESIS
			else (1 if distance < _far_distance - LOD_HYSTERESIS else 2)
		)
	set_lod(requested)


func set_lod(level: int) -> void:
	var next_level := clampi(level, 0, 2)
	if next_level == lod_level:
		return
	lod_level = next_level
	for index in range(_lod_meshes.size()):
		for mesh in _lod_meshes[index]:
			mesh.visible = index == lod_level
	for node in _dressing:
		node.visible = lod_level == 0
	_sync_showcase()


func visible_surface_count() -> int:
	var count := 0
	for mesh in _lod_meshes[lod_level]:
		count += mesh.mesh.get_surface_count()
	return count


## Anbauteile nach dem Look setzen (Serie = nichts angebaut). Mehrfach aufrufbar: Vorschau
## in der Garage wechselt sofort, ohne das Kart neu zu bauen.
func apply_parts(look: Dictionary, animate_slot: String = "") -> void:
	for node in _part_nodes:
		if is_instance_valid(node):
			_dressing.erase(node)
			node.get_parent().remove_child(node)
			node.free()
	_part_nodes.clear()
	mounted_parts = {}
	if asset_root == null:
		return
	var paint: Color = _paints[0].albedo_color if not _paints.is_empty() else Color("e8eef6")
	for slot in TUNING.PART_SLOTS:
		var entry: Dictionary = TUNING.option(slot, str(look.get(slot, "serie")))
		mounted_parts[slot] = str(entry.get("id", "serie"))
		var node_name: String = str(entry.get("node", ""))
		if node_name.is_empty():
			continue
		var path: String = entry.get("file", PARTS_PATH)
		var packed: PackedScene = _scene(path) if ResourceLoader.exists(path) else null
		if packed == null:
			continue
		var first_mount := _part_nodes.size()
		match slot:
			"wheel_cover", "tires":
				for rotor in wheel_rotors:
					# Aufsätze schauen nach +X (rechte Seite); links um die Hochachse gedreht.
					var turn: Basis = (
						Basis(Vector3.UP, PI) if rotor.get_parent().position.x < 0.0 else Basis()
					)
					_mount(packed, node_name, paint, rotor, Transform3D(turn, Vector3.ZERO))
			"exhaust":
				for side in ["L", "R"]:
					var marker := asset_root.find_child("Boost_" + side, true, false) as Node3D
					# Etwas größer als modelliert: im Rennen sieht man das Heck nur klein von hinten.
					_mount(
						packed,
						node_name,
						paint,
						marker,
						Transform3D(Basis().scaled(Vector3.ONE * 1.5), Vector3.ZERO)
					)
			"brakes":
				for index in wheel_pivots.size():
					var mirror := _mirror(wheel_pivots[index].position.x < 0.0)
					_mount(packed, node_name, paint, wheel_pivots[index], mirror)
					_mount(packed, node_name + "Disc", paint, wheel_rotors[index], mirror)
			"steering", "gearbox", "ballast":
				var carrier: Node3D = _sprung_body if is_instance_valid(_sprung_body) else asset_root
				if slot != "ballast":
					var axle_name := "FrontAxle" if slot == "steering" else "RearAxle"
					carrier = asset_root.find_child(axle_name, true, false) as Node3D
				var width := absf(wheel_pivots[0].position.x) / 0.77
				var fit := Transform3D(Basis().scaled(Vector3(width, 1.0, 1.0)), Vector3.ZERO)
				_mount(packed, node_name, paint, carrier, fit)
			"suspension":
				for pivot in wheel_pivots:
					_mount(packed, node_name, paint, pivot, _mirror(pivot.position.x < 0.0))
			"engine", "wing":
				_mount(packed, node_name, paint, _body_carrier(), Transform3D(Basis(), _anchor(slot)))
			"booster":
				var at: Vector3 = _anchor(slot)
				_mount(packed, node_name, paint, _body_carrier(), Transform3D(Basis(), at))
				_mount(
					packed,
					node_name,
					paint,
					_body_carrier(),
					_mirror(true).translated(Vector3(-at.x, at.y, at.z))
				)
		if slot == animate_slot:
			for index in range(first_mount, _part_nodes.size()):
				var mount := _part_nodes[index]
				var rest := mount.position
				var offset := Vector3.UP * 0.24
				if slot in ["brakes", "tires", "wheel_cover", "suspension"]:
					offset = Vector3.RIGHT * signf(mount.get_parent().get_parent().position.x) * 0.25
					if mount.get_parent() in wheel_pivots:
						offset = Vector3.RIGHT * signf(mount.get_parent().position.x) * 0.25
				mount.position = rest + offset
				mount.create_tween().tween_property(mount, "position", rest, 0.32).set_trans(
					Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for node in _part_nodes:
		node.visible = lod_level == 0
		_dressing.append(node)


func _body_carrier() -> Node3D:
	return _sprung_body if is_instance_valid(_sprung_body) else asset_root


## Montagepunkt eines Leistungsteils am Kart (Godot-Koordinaten des Karts). Dieselben Werte
## nutzt tools/lumo_kart_art/karts/render_parts_fit.py für die Passprobe in Blender.
func _anchor(slot: String) -> Vector3:
	var marker := asset_root.find_child("Mount_" + slot, true, false) as Node3D
	if marker != null:
		return marker.position
	return (PART_MOUNTS.get(variant, PART_MOUNTS.comet) as Dictionary).get(slot, Vector3.ZERO)


static func _mirror(left: bool) -> Transform3D:
	return Transform3D(Basis().scaled(Vector3(-1, 1, 1)) if left else Basis(), Vector3.ZERO)


## Hängt ein Teil als benannten Montagepunkt „Mount_<Teil>“ an den Träger.
func _mount(
	packed: PackedScene, node_name: String, paint: Color, carrier: Node3D, at: Transform3D
) -> void:
	if carrier == null:
		return
	var part := _part_instance(packed, node_name, paint)
	if part == null:
		return
	var mount := Node3D.new()
	# Links gespiegelte Teile am selben Träger bekommen „_L“ (Namen müssen eindeutig sein).
	mount.name = "Mount_" + node_name + ("_L" if at.basis.determinant() < 0.0 else "")
	carrier.add_child(mount)
	mount.transform = at
	mount.add_child(part)
	_part_nodes.append(mount)


func _part_instance(packed: PackedScene, node_name: String, paint: Color) -> Node3D:
	var source := packed.instantiate()
	var found := source.find_child(node_name, true, false) as Node3D
	if found == null:
		source.free()
		return null
	found.owner = null
	for child in found.find_children("*", "", true, false):
		child.owner = null
	found.get_parent().remove_child(found)
	source.free()
	found.transform = Transform3D.IDENTITY
	found.name = "Part_" + node_name
	for mesh in found.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if original != null and original.resource_name == "PartPaint":
				var tinted := original.duplicate() as StandardMaterial3D
				tinted.albedo_color = paint
				mesh.set_surface_override_material(surface, tinted)
	return found
