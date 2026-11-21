extends SceneTree
const G = preload("res://scripts/games/garden/kart_garden_course.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var curve: Curve3D = G.make_curve()
	print("baked length ", curve.get_baked_length(), " planar ", G.planar_length())
	var samples: Array = G.planar_samples()
	var table = G._height_table(ceili(G.planar_length()) + 1)
	for s in [120.0, 313.6, 323.6, 330.0, 392.0, 398.0, 446.0, 458.6, 462.0, 506.0, 558.6, 713.0, 733.0, 784.4, 859.4, 910.8, 982.2, 1233.4, 1274.3, 1513.8, 1656.6, 1696.6, 1942.5, 2318.2, 2408.0]:
		var i: int = roundi(s / 0.5)
		var p := Vector3(samples[i][1], G.height_at_planar(s, table), samples[i][2])
		print("planar %.1f -> curve %.2f  h %.2f" % [s, curve.get_closest_offset(p), p.y])
	quit(0)
