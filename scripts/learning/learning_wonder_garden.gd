extends Node3D
## Presentation-only reaction to the existing lesson. Never writes task,
## profile, reward or speech state. Five blooms are decorative progress,
## not counters, answers or a second learning score.
const AMBIENCE = preload("res://scripts/systems/render/lumo_dream_ambience.gd")
const PETAL_SHADER = preload("res://assets/shaders/learning_wonder_petals.gdshader")
const FLOWERS := 5
const PETALS := 7
const MAX_BATCHES := 7

var _world: Node3D
var _activity: RefCounted
var _ambience: Node3D
var _petal_material: ShaderMaterial
var _pollen_material: StandardMaterial3D
var _batches: Array[MultiMeshInstance3D] = []
var _positions: Array[Vector3] = []
var _progress := 0.0
var _display_progress := 0.0
var _kind := "invalid"
var _family := ""
var _reduced_motion := false
var _suspended := false
var _last_frozen := false
var _size := Vector2.ZERO
var _theme_changes := 0
var _layout_changes := 0


func _ready() -> void:
	name = "LearningWonderGarden"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_world = get_parent().get_parent() as Node3D
	if _world == null:
		set_process(false)
		return
	_activity = _world.get("activity") as RefCounted
	if _activity == null or str(_activity.get("kind")) == "invalid":
		# An invalid activity does not allocate decorative objects or imply progress.
		hide()
		set_process(false)
		return
	_build_geometry()
	_ambience = AMBIENCE.attach(self, "learning_garden")
	_observe_activity(true)
	_sync_motion(true)


func _process(delta: float) -> void:
	if not is_instance_valid(_world) or _activity == null:
		return
	_sync_motion()
	if _suspended:
		return
	_observe_activity(false)
	if not is_visible_in_tree():
		return
	var next: float = (
		_progress if _reduced_motion
		else move_toward(_display_progress, _progress, clampf(delta, 0.0, 0.1) * 2.4)
	)
	if not is_equal_approx(next, _display_progress):
		_display_progress = next
		_petal_material.set_shader_parameter("progress", _display_progress)


func _sync_motion(force := false) -> void:
	_reduced_motion = bool(_world.get("reduced_motion"))
	_suspended = bool(_world.get("suspended"))
	var frozen := _reduced_motion or _suspended or not is_visible_in_tree()
	if is_instance_valid(_ambience) and (force or frozen != _last_frozen):
		# The learning scene's actual options, not an unrelated router default,
		# own accessibility. Pause retains the static composition.
		_ambience.set_reduced_motion(frozen)
	_last_frozen = frozen


func _observe_activity(instant: bool) -> void:
	var current_kind: String = str(_activity.get("kind"))
	var valid := current_kind != "invalid"
	visible = valid
	if current_kind != _kind or _family.is_empty():
		_kind = current_kind
		_size = Vector2.ZERO
		_apply_theme()
	var completed := 0
	var total := 1
	if _kind == "plant_parts":
		completed = int(_activity.get("watered")) + int(_activity.get("sunlight"))
		completed += _activity.get("inspected").size()
		total = 6
	elif valid:
		completed = _activity.get("placed").size()
		total = maxi(1, int(_activity.call("goal_count")))
	_progress = clampf(float(completed) / float(total), 0.0, 1.0) if valid else 0.0
	if valid and bool(_activity.call("is_complete")):
		_progress = 1.0
	if instant or _reduced_motion or _progress < _display_progress:
		# Reset is immediate; revisiting an explanation never inherits a bloom.
		_display_progress = _progress
		_petal_material.set_shader_parameter("progress", _display_progress)
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size != _size:
		_size = viewport_size
		_position_geometry(viewport_size.x < viewport_size.y * 0.95)


func _apply_theme() -> void:
	_family = "nature" if _kind == "plant_parts" else ("language" if _kind == "syllables" else "numbers")
	var warm := Color("eeb86a")
	var cool := Color("62c2c2")
	if _family == "language":
		warm = Color("eaa0b9")
		cool = Color("a9a2df")
	elif _family == "nature":
		warm = Color("f0ce70")
		cool = Color("8fce8e")
	_petal_material.set_shader_parameter("warm_color", warm)
	_petal_material.set_shader_parameter("cool_color", cool)
	_pollen_material.albedo_color = Color("ffcf7c")
	_pollen_material.emission = warm
	_theme_changes += 1


func _material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.76
	material.metallic_specular = 0.18
	return material


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	return mesh


func _sphere() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh


func _batch(label: String, mesh: Mesh, material: Material, count: int, custom := false) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = custom
	multi.mesh = mesh
	multi.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_batches.append(node)
	return node


func _build_geometry() -> void:
	_petal_material = ShaderMaterial.new()
	_petal_material.shader = PETAL_SHADER
	_pollen_material = _material(Color("ffcf7c"))
	_pollen_material.emission_enabled = true
	_pollen_material.emission_energy_multiplier = 0.12
	_batch("CopperPlanters", _cylinder(0.26, 0.18, 0.3), _material(Color("ad7a51"), 0.08), FLOWERS)
	_batch("PlanterRims", _cylinder(0.28, 0.28, 0.055), _material(Color("d8b17c"), 0.12), FLOWERS)
	_batch("GardenSoil", _cylinder(0.235, 0.235, 0.025), _material(Color("384e41")), FLOWERS)
	_batch("LivingStems", _cylinder(0.027, 0.037, 0.4), _material(Color("54896c")), FLOWERS)
	_batch("GardenLeaves", _sphere(), _material(Color("74ab86")), FLOWERS * 2)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.append_from(_sphere(), 0, Transform3D(Basis.from_scale(Vector3(0.48, 0.075, 0.23)), Vector3(0.24, 0, 0)))
	_batch("OpeningPetals", surface.commit(), _petal_material, FLOWERS * PETALS, true)
	_batch("WarmPollen", _sphere(), _pollen_material, FLOWERS)


func _position_geometry(portrait: bool) -> void:
	_positions.clear()
	for flower in range(FLOWERS):
		var x := (-0.65 + float(flower) * 0.70) if portrait else (-2.15 + float(flower) * 1.05)
		var z := -3.85 if _kind == "syllables" and not portrait else -3.55
		# Leave the rear-right hundred-stock and the lower source label clear.
		# A side border fits the phone instead of placing flowers behind its HUD.
		if portrait and _kind == "bridge_hundred":
			x = -2.65
			z = -2.8 + float(flower) * 1.55
		var at := Vector3(x, 0.0, z)
		_positions.append(at)
		_set_instance(0, flower, at + Vector3(0, 0.15, 0))
		_set_instance(1, flower, at + Vector3(0, 0.30, 0))
		_set_instance(2, flower, at + Vector3(0, 0.332, 0))
		_set_instance(3, flower, at + Vector3(0, 0.50, 0))
		for leaf in range(2):
			var side := -1.0 if leaf == 0 else 1.0
			var basis_value := Basis(Vector3.FORWARD, side * 0.4).scaled(Vector3(0.24, 0.055, 0.10))
			_set_instance(4, flower * 2 + leaf, at + Vector3(side * 0.1, 0.48 + float(leaf) * 0.1, 0), basis_value)
		for petal in range(PETALS):
			var index := flower * PETALS + petal
			_set_instance(5, index, at + Vector3(0, 0.72, 0))
			_batches[5].multimesh.set_instance_custom_data(index, Color(float(flower), float(petal) / float(PETALS), float(flower % 2), 1.0))
		_set_instance(6, flower, at + Vector3(0, 0.735, 0), Basis.from_scale(Vector3(0.17, 0.13, 0.17)))
	for node in _batches:
		# Covers both bud and fully open shader-deformed petals in either layout.
		node.multimesh.custom_aabb = AABB(Vector3(-3.2, -0.1, -4.4), Vector3(6.4, 1.6, 8.9))
	_layout_changes += 1


func _set_instance(batch: int, index: int, at: Vector3, basis_value := Basis.IDENTITY) -> void:
	_batches[batch].multimesh.set_instance_transform(index, Transform3D(basis_value, at))


func render_state() -> Dictionary:
	var ambience_state: Dictionary = _ambience.render_state() if is_instance_valid(_ambience) else {}
	return {
		"kind": _kind, "family": _family, "progress": _progress,
		"display_progress": _display_progress, "reduced_motion": _reduced_motion,
		"suspended": _suspended, "flowers": FLOWERS, "petals": FLOWERS * PETALS,
		"geometry_batches": _batches.size(), "ambience": ambience_state,
		"layout_changes": _layout_changes, "theme_changes": _theme_changes,
		"writes_learning_state": false,
	}
