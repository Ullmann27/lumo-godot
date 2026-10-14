extends RefCounted
## Authored wave-canopy architecture, matched to the existing harbor board.
const PAVILION = preload("res://scenes/games/props/harbor_wave_pavilion.tscn")
const STATIONS: Array[float] = [0.035, 0.43, 0.85]

static func build(world) -> void:
	if world.track_id != "sonnenhafen":
		return
	var instances: Array[Node3D] = []
	for fraction in STATIONS:
		var distance: float = world.length * fraction
		var pavilion: Node3D = PAVILION.instantiate()
		pavilion.name = "HarborWavePavilion%d" % instances.size()
		world.add_child(pavilion)
		pavilion.transform = Transform3D(world.frame(distance), world.position_at(distance))
		for lod in range(3):
			var root: Node3D = pavilion.get_node("LOD%d" % lod)
			if world.low_detail and lod == 0:
				root.hide()
				continue
			for mesh in root.find_children("*", "MeshInstance3D", true, false):
				mesh.visibility_range_begin = 0.0 if lod == 0 or (world.low_detail and lod == 1) else (55.0 if lod == 1 else 110.0)
				mesh.visibility_range_end = 55.0 if lod == 0 else (110.0 if lod == 1 else 210.0)
				mesh.visibility_range_begin_margin = 3.0
				mesh.visibility_range_end_margin = 3.0
		instances.append(pavilion)
	world.set_meta("harbor_wave_pavilions", instances)
