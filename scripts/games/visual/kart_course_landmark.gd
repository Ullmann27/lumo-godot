extends RefCounted
## Eigene Blender-Wahrzeichen an gut sichtbaren Stellen entlang der Steilkurven.
const PATH := "res://assets/kart/scenery/landmarks/%s.glb"


static func place(world, parent: Node3D, low: bool) -> void:
	for entry in world.THRILLS.of(world):
		if entry.kind != "bank":
			continue
		var distance: float = (entry.start + entry.end) * 0.5
		var approach_site: bool = world.track_id in ["candy_cloud", "volcano_night"]
		if approach_site:
			distance += 55.0 if world.track_id == "volcano_night" else -55.0
		var frame: Basis = world.frame(distance)
		var outside := -1.0 if frame.x.y < 0.0 else 1.0
		if approach_site:
			outside = 1.0
		elif world.track_id == "crystal_canyon":
			outside *= -1.0
		var right := Vector3(frame.x.x, 0, frame.x.z).normalized()
		var forward: Vector3 = right.cross(Vector3.UP)
		var center: Vector3 = world.position_at(distance)
		var offset: float = world.road_width_at(distance) * 0.5 + (10.0 if approach_site else 12.5)
		var resource_path := PATH % world.track_id
		var model := load(resource_path) as PackedScene
		if model == null:
			push_error("Wahrzeichen fehlt: " + resource_path)
			return
		var landmark := model.instantiate() as Node3D
		landmark.name = "Kurvenwahrzeichen"
		parent.add_child(landmark)
		landmark.position = center + right * outside * offset - Vector3.UP * (1.0 if approach_site else 1.35)
		landmark.look_at(landmark.global_position - right * outside + forward * (0.0 if approach_site else .32), Vector3.UP)
		landmark.scale = Vector3.ONE * (2.25 if world.track_id == "zauberwald" else 1.8)
		if approach_site:
			landmark.scale = Vector3.ONE * (2.4 if world.track_id == "volcano_night" else 2.0)
		landmark.set_meta("distance", distance)
		landmark.set_meta("section", entry.id)
		for level in 3:
			var mesh := landmark.find_child("%s_lod%d" % [world.track_id, level], true, false) as MeshInstance3D
			assert(mesh != null and mesh.mesh != null)
			mesh.visible = level > 0 or not low
			mesh.visibility_range_begin = 0.0 if level == 0 or (low and level == 1) else (65.0 if level == 1 else 140.0)
			mesh.visibility_range_end = [65.0, 140.0, 420.0][level]
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if (low or level == 2) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		return
