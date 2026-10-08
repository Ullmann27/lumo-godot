extends SceneTree
const WORLD = preload("res://scripts/games/kart_world.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for track in [
		"sonnenhafen", "zauberwald", "candy_cloud", "volcano_night", "desert_drift", "bergwelt"
	]:
		for light in [false, true]:
			var world = WORLD.new()
			root.add_child(world)
			world.build(light, track, true)
			var sites: Array = world.get_meta("reference_detail_sites")
			var details: int = world.get_meta("reference_detail_count")
			assert(details > 20 and details < 1800, "Useful, bounded roadside detail density")
			for site: Dictionary in sites:
				assert(
					not world._near_road(site.position, 8.5 + float(site.radius)),
					"Assembly footprint clears every lane"
				)
				assert(not world.in_gap(float(site.distance)), "No prop floats in the jump gap")
			assert(world.groups.is_empty(), "All new geometry is spatially batched")
			print(
				"[TrackDetail] ",
				track,
				" light=",
				light,
				": ",
				sites.size(),
				" sites, ",
				details,
				" details"
			)
			world.free()
	print(
		"[TrackDetail] PASS: six worlds, both quality levels, footprint/gap safety and batched detail"
	)
	quit()
