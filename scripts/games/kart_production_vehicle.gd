extends Node3D
## Frozen Aurora GLBs on one stable mechanical hierarchy. Only mesh visibility
## changes at LOD boundaries; wheel/driver anchors never move or get replaced.

const VARIANTS: Array[String] = ["comet", "glider", "turbo"]
## Every kart of the fleet drives one of the three authored bodies, so the
## driver always sits in a real cockpit. Paint, trim, accent and neon come
## from the kart's own look.
const BODY_OF: Dictionary = {
	"comet": "comet", "boru_rally": "comet", "nala_comet": "comet", "zuri_volt": "comet",
	"terra": "comet", "koloss": "comet",
	"glider": "glider", "gecko_velo": "glider", "noa_tide": "glider", "iva_aurora": "glider",
	"turbo": "turbo", "blitz": "turbo", "phantom": "turbo", "stella": "turbo",
}
const WHEELS: Array[String] = ["FL", "RL", "FR", "RR"]
const MODEL_DIRECTORY := "res://assets/kart/production/karts/"
const LOD_HYSTERESIS := 2.0
## Lackart (matt/metallic/perlmutt), Startnummer und Fantasie-Aufkleber je Kart-Design.
const FINISH = preload("res://scripts/games/kart_vehicle_finish.gd")
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
## Schaustück-Teile (Glas, Anlauffarben, Staubfilm) aus aurora_<v>_showcase.glb: nur in
## Garage, Werkstatt und auf dem Podest, nie im Rennen. Wird erst bei Bedarf geladen.
var _showcase_meshes: Array[MeshInstance3D] = []
var _showcase_loaded := false
const DUST_PATH := "res://assets/kart/production/details/kart_dust_film.png"
## Austauschbare Anbauteile (Radaufsätze, Auspuffblenden), siehe kart_tuning.gd und
## tools/lumo_kart_art/karts/build_parts.py. Wurzel jedes Teils = sein Montagepunkt.
const PARTS_PATH := "res://assets/kart/production/parts/kart_parts.glb"
const TUNING = preload("res://scripts/games/kart_tuning.gd")
## Montierte Teile je Steckplatz ("wheel_cover"/"exhaust" -> id); Tests lesen das.
var mounted_parts: Dictionary = {}
var _part_nodes: Array[Node3D] = []


## The sculpted in-code karts remain the fallback for a body that cannot be
## loaded. Tests set this to keep that fallback path exercised.
static var fallback_only: bool = false


static func supports(id: String) -> bool:
	return BODY_OF.has(id) and not fallback_only


## Authored body ("comet", "glider" or "turbo") of a fleet kart.
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
	var dressed_look: Dictionary = stock.duplicate()
	dressed_look.merge(look, true)
	_dressing = FINISH.dress(asset_root, design, dressed_look)
	set_lod(0)
	set_braking(0.0)
	_refresh_finish()
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
		if material_name.ends_with("_paint"):
			# Jede Lackschicht ist eine eigene Kopie: Lackart je Design, ohne Stock-Material
			# anderer Karts zu verändern.
			finish = original.duplicate() as StandardMaterial3D
			# Serienlack kommt aus der Flotte (Comet: kräftiges Kometenblau statt Nachtblau,
			# damit Lack und Glanz im Schauraum und auf der Strecke lesbar sind).
			finish.albedo_color = look.get("paint", original.albedo_color) if custom_paint else stock.get("paint", original.albedo_color)
			_paints.append(finish)
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
	if enabled and not _showcase_loaded:
		_load_showcase()
	if enabled:
		set_lod(0)
	_sync_showcase()


func _load_showcase() -> void:
	_showcase_loaded = true
	if asset_root == null:
		return
	var path := MODEL_DIRECTORY + "aurora_" + variant + "_showcase.glb"
	if not ResourceLoader.exists(path):
		return
	var packed := _scene(path)
	if packed == null:
		return
	var source := packed.instantiate() as Node3D
	for player in source.find_children("*", "AnimationPlayer", true, false):
		player.free()
	for item in source.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		var target := asset_root.get_node_or_null(source.get_path_to(mesh.get_parent()))
		if not target is Node3D:
			continue
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		mesh.name = str(mesh.name) + "_Showcase"
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		target.add_child(mesh)
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if original != null and original.resource_name == "RoadDustFilm":
				var dust := original.duplicate() as StandardMaterial3D
				dust.albedo_color = Color(1, 1, 1, 1)
				dust.albedo_texture = load(DUST_PATH)
				dust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				dust.roughness = 0.95
				dust.metallic = 0.0
				mesh.set_surface_override_material(surface, dust)
		_showcase_meshes.append(mesh)
	source.free()


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
func apply_parts(look: Dictionary) -> void:
	for node in _part_nodes:
		if is_instance_valid(node):
			_dressing.erase(node)
			node.get_parent().remove_child(node)
			node.free()
	_part_nodes.clear()
	mounted_parts = {}
	if asset_root == null:
		return
	var packed: PackedScene = _scene(PARTS_PATH) if ResourceLoader.exists(PARTS_PATH) else null
	var paint: Color = _paints[0].albedo_color if not _paints.is_empty() else Color("e8eef6")
	for slot in TUNING.PART_SLOTS:
		var entry: Dictionary = TUNING.option(slot, str(look.get(slot, "serie")))
		mounted_parts[slot] = str(entry.get("id", "serie"))
		var node_name: String = str(entry.get("node", ""))
		if node_name.is_empty() or packed == null:
			continue
		if slot == "wheel_cover":
			for rotor in wheel_rotors:
				var cover := _part_instance(packed, node_name, paint)
				if cover == null:
					continue
				rotor.add_child(cover)
				# Aufsätze schauen nach +X (rechte Seite); links um die Hochachse gedreht.
				if rotor.get_parent().position.x < 0.0:
					cover.basis = Basis(Vector3.UP, PI)
				_part_nodes.append(cover)
		else:
			for side in ["L", "R"]:
				var marker := asset_root.find_child("Boost_" + side, true, false) as Node3D
				var tip := _part_instance(packed, node_name, paint)
				if marker == null or tip == null:
					if tip != null:
						tip.free()
					continue
				marker.add_child(tip)
				# Etwas größer als modelliert: im Rennen sieht man das Heck nur klein von hinten.
				tip.scale = Vector3.ONE * 1.5
				_part_nodes.append(tip)
	for node in _part_nodes:
		node.visible = lod_level == 0
		_dressing.append(node)


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
