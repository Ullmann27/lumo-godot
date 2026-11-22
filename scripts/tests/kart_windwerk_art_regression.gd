extends SceneTree
## Every modular prop contains three separately modeled render distances.
const ART = preload("res://scripts/games/kart_windwerk_art.gd")
const MODELS := ["station", "mill", "turbine", "bridge", "signal_gate", "slider", "workshop", "orchard"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	for id: String in MODELS:
		var part := ART.module(id)
		root.add_child(part)
		var previous := 2147483647
		for level in range(3):
			var mesh := part.find_child("LOD%d" % level, true, false) as MeshInstance3D
			if mesh == null:
				errors.append(id + " missing LOD%d" % level)
				continue
			var triangles := 0
			for surface in mesh.mesh.get_surface_count():
				triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
			if triangles >= previous or triangles <= 0:
				errors.append(id + " does not simplify at LOD%d" % level)
			previous = triangles
			if mesh.visibility_range_end <= mesh.visibility_range_begin:
				errors.append(id + " empty visibility range")
		if id in ["turbine", "mill"]:
			var rotor := part.find_child("Rotor", true, false)
			if rotor == null or rotor.find_children("RotorLOD*", "MeshInstance3D", true, false).size() != 3:
				errors.append(id + " incomplete rotor")
		part.free()
	if errors.is_empty():
		print("[WindwerkArt] PASS 8 imported modules, decreasing triangle counts, three camera ranges and two mechanical rotors")
	else:
		for error in errors:
			push_error(error)
	quit(0 if errors.is_empty() else 1)
