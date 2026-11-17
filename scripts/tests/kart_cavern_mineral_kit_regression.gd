extends SceneTree
## Godot's actual imported geometry, in both LODs, independent of manifest claims.
const KIT = preload("res://scripts/games/kart_cavern_mineral_kit.gd")
const EXPECTED: Dictionary = {
	"strata_shelf": [252, 768], "split_ledge": [192, 604], "hanging_canopy": [260, 800],
	"crystal_fan": [110, 322], "crystal_spire": [66, 230], "crystal_rosette": [110, 414],
}


func _initialize() -> void:
	for identity in EXPECTED:
		var mobile: Mesh = KIT.mesh(str(identity), true)
		var high: Mesh = KIT.mesh(str(identity), false)
		assert(mobile != high, "Mobile must reduce real geometry")
		assert(mobile == KIT.mesh(str(identity), true), "Kit meshes must be shared resources")
		assert(mobile.get_surface_count() == 1 and high.get_surface_count() == 1)
		assert(KIT.triangles(str(identity), true) == EXPECTED[identity][0])
		assert(KIT.triangles(str(identity), false) == EXPECTED[identity][1])
		assert(KIT.triangles(str(identity), true) < KIT.triangles(str(identity), false) * 0.65)
		var high_bounds: AABB = high.get_aabb()
		var low_bounds: AABB = mobile.get_aabb()
		assert(is_equal_approx(high_bounds.position.y, 0.0))
		assert(is_equal_approx(low_bounds.position.y, 0.0))
		assert(absf(high_bounds.end.y - low_bounds.end.y) < 0.001)
		for mesh: Mesh in [mobile, high]:
			var arrays: Array = mesh.surface_get_arrays(0)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			assert(not colors.is_empty(), "Imported mineral needs real facet variation")
			assert(not normals.is_empty(), "Cinema lighting needs authored normals")
			for color: Color in colors:
				assert(absf(color.r - color.g) < 0.01 and absf(color.r - color.b) < 0.01,
					"Imported mineral facet colors must remain grayscale")
				assert(color.r >= 0.6 and color.r <= 1.0,
					"Imported mineral pigment must remain readable light grayscale")
			for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				assert(point.is_finite())
	print("[CavernMineralKit] PASS: twelve Godot imports, six distinct originals, one surface, real mobile topology")
	quit(0)
