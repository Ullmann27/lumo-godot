extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var layout = load("res://scripts/games/skypost/sky_post_layout.gd").build()
	var g = layout.GATES
	var n = g.size()
	for i in range(n):
		var a = g[(i - 1 + n) % n]
		var b = g[i]
		var c = g[(i + 1) % n]
		var d1 = Vector2(b.x - a.x, b.z - a.z)
		var d2 = Vector2(c.x - b.x, c.z - b.z)
		print("gate %d %s turn %.0f deg, leg %.0f m" % [i, b, rad_to_deg(absf(d1.angle_to(d2))), b.distance_to(c)])
	var line = layout.race_line(2.0)
	var hits = 0
	for p in line:
		var r = layout.resolve(p, 3.0)
		if str(r.kind) in ["island", "building"]:
			hits += 1
			print("  line blocked at ", p, " ", r.kind)
	print("line samples ", line.size(), " blocked ", hits)
	quit()
