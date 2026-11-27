extends SceneTree
const SOURCE := "res://assets/characters/lumo_nextgen_chat3/Lumo-Learning-Animated.glb"
var errors := 0
var textured := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	if not condition:
		errors += 1
		printerr("[LearningMaterials] FAIL " + label)

func _run() -> void:
	var packed := load(SOURCE) as PackedScene
	if packed == null:
		_check(false, "original learning model is importable")
		quit(1)
		return
	var model := packed.instantiate()
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface in range(instance.mesh.get_surface_count()):
			var material := instance.get_active_material(surface) as BaseMaterial3D
			if material == null or not material.normal_enabled:
				continue
			textured += 1
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var count: int = arrays[Mesh.ARRAY_VERTEX].size()
			var tangents: Variant = arrays[Mesh.ARRAY_TANGENT]
			_check(count > 0 and tangents is PackedFloat32Array and tangents.size() == count * 4,
				str(instance.name) + " normal-mapped surface has a tangent basis")
			_check(material.get_texture(BaseMaterial3D.TEXTURE_NORMAL) != null,
				str(instance.name) + " original normal texture retained")
	_check(textured > 0, "at least one real normal-mapped surface checked")
	model.free()
	if errors == 0:
		print("[LearningMaterials] PASS %d normal-mapped surfaces" % textured)
	quit(0 if errors == 0 else 1)
