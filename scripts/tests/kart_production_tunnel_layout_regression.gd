extends SceneTree
## Read the real route and hazard plan; assert a usable section on every theme.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const LAYOUT = preload("res://scripts/games/kart_production_tunnel_layout.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: int = 0
	for track in LAYOUT.THEMES:
		var world = WORLD.new()
		world.definition = TRACKS.definition(track)
		world.track_id = track
		world._make_curve()
		if track == "bergwelt":
			world.jump = world.SKY_ISLANDS.jump_layout(world.length)
		elif track in TRACKS.EXPANSION.IDS:
			world.EXPANSION.prepare(world)
		world.action = world.ACTION.plan(world)
		var layout: Dictionary = LAYOUT.plan(world)
		if layout.is_empty():
			failures += 1
			push_error(track + ": actual road needs a safe tunnel section")
			world.free()
			continue
		assert(float(layout.length) >= 32.0)
		assert(float(layout.nearest_other_road) >= LAYOUT.OTHER_ROAD_CLEARANCE)
		for module in layout.modules:
			assert(not world.in_gap(float(module.start)))
		print("[ProductionTunnelLayout] ", track, " length=", snappedf(world.length, 0.1), " tunnel=", layout.start, "..", layout.end, " curvature=", snappedf(layout.max_curvature, 0.001), " other_road=", snappedf(layout.nearest_other_road, 0.1), " PASS")
		world.free()
	quit(0 if failures == 0 else 1)
