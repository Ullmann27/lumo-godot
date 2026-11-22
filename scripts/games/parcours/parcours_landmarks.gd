extends RefCounted
## A repeated landmark is placed at different heights and bearings along the actual route.
## The checked footprint also accounts for other levels, the foot route and moving decks.

const MESHES = preload("res://scripts/games/parcours/parcours_meshes.gd")
const PATH := "res://assets/kart/parcours/landmarks/%s.glb"
# Checkpoint, model, sideways / forward / vertical offset, scale, yaw in degrees.
const SITES := {
	"wolkenwerkstatt": [
		["start", "airship", Vector3(-24, 42, 3), 1.25, -24],
		["bruecke", "airship", Vector3(-22, 36, 0), 1.18, -21],
		["schweber", "freight_dock", Vector3(22, 44, -4), 1.26, 33],
		["aufzug", "freight_dock", Vector3(22, 38, -3), 1.10, -44],
		["spirale", "airship", Vector3(-24, 42, 4), 1.36, 36],
	],
	"eisturm": [
		["start", "observatory", Vector3(-26, 46, 0), 1.66, -37],
		["spirale", "glacier_arch", Vector3(-32, 62, 0), 2.35, 28],
		["eisbruecke", "glacier_arch", Vector3(38, 64, 0), 2.74, -22],
		["turmspitze", "observatory", Vector3(-34, 68, 0), 2.54, 32],
		["seeufer", "glacier_arch", Vector3(-30, 52, 0), 1.67, 8],
	],
	"dschungeltempel": [
		["start", "bird_shrine", Vector3(-34, 46, 0), 1.80, 24],
		["wurzelweg", "rainfall", Vector3(-20, 34, 0), 1.67, -25],
		["lianenhalle", "bird_shrine", Vector3(-26, 54, 0), 2.12, 23],
		["sonnenscheibe", "rainfall", Vector3(24, 44, 0), 1.85, 15],
		["schlucht", "bird_shrine", Vector3(-32, 54, 0), 2.70, 24],
		["flusstor", "rainfall", Vector3(22, 42, 0), 1.82, -28],
	],
}

static func populate(parent: Node3D, course, lightweight: bool) -> void:
	var models := {}
	var routes: Array[Vector3] = []
	var radii: Array[float] = []
	for slab in course.slabs:
		var segments := MESHES.segments_for(slab)
		for i in range(segments + 1):
			var sample: Dictionary = MESHES.frame_at(slab, float(i) / segments)
			var point: Vector3 = slab.base * sample.centre
			point.y = 0.0
			routes.append(point)
			radii.append(float(slab.width) * 0.5 + float(slab.get("motion", {}).get("amp", 0)) + 4.0)
	for site in SITES.get(course.id, []):
		var checkpoint: Dictionary = course.checkpoints[course.checkpoint_index_of(site[0])]
		var heading := float(checkpoint.heading)
		var basis := Basis(Vector3.UP, heading)
		var offset: Vector3 = site[2]
		var name := str(site[1])
		if not models.has(name):
			models[name] = load(PATH % name) if ResourceLoader.exists(PATH % name) else null
		var packed: PackedScene = models[name]
		if packed == null:
			continue
		var model := packed.instantiate() as Node3D
		var mesh := model as MeshInstance3D
		if mesh == null:
			var meshes := model.find_children("*", "MeshInstance3D", true, false)
			if not meshes.is_empty():
				mesh = meshes[0] as MeshInstance3D
		if not mesh:
			model.free()
			continue
		var scale_factor := float(site[3])
		var size := mesh.get_aabb().size
		var footprint := Vector2(size.x, size.z).length() * scale_factor * 0.5
		var at: Vector3 = checkpoint.pos + basis * Vector3(offset.x, offset.z, -offset.y)
		var found := false
		for attempt in range(8):
			var flat := Vector3(at.x, 0, at.z)
			var safe := true
			for i in routes.size():
				if flat.distance_squared_to(routes[i]) < pow(footprint + radii[i], 2):
					safe = false
					break
			if safe:
				found = true
				break
			at += basis.x * signf(offset.x) * 6.0
		if not found:
			model.free()
			continue
		if course.id != "wolkenwerkstatt":
			at.y = 3.15 if course.id == "eisturm" else -0.05
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visibility_range_end = 155.0 if lightweight else 235.0
		mesh.visibility_range_end_margin = 12.0
		model.name = "%s_%s" % [site[0], name]
		model.transform = Transform3D(basis.rotated(Vector3.UP, deg_to_rad(site[4])).scaled(Vector3.ONE * scale_factor), at)
		parent.add_child(model)
