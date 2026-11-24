extends SceneTree
## Every course is recognisable by its ground: the real assembled road carries
## its own surface style, and lane paint stays readable on it.

const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const SURFACES = preload("res://scripts/games/kart_road_surfaces.gd")
const OWN_SHADER: Array[String] = ["candy_cloud", "jungle_emerald_3600"]
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _luminance(colour: Color) -> float:
	return colour.r * 0.2126 + colour.g * 0.7152 + colour.b * 0.0722


func _run() -> void:
	var shader: Shader = load("res://assets/shaders/kart_asphalt.gdshader")
	for marker in ["surface_style == 1", "surface_style == 2", "surface_style == 3",
			"surface_style == 4", "surface_style == 5", "surface_style == 6", "pebble_lod"]:
		_expect(shader.code.contains(marker), "Shader lost " + marker)
	var seen: Dictionary = {}
	for track_id in TRACKS.IDS:
		if track_id in OWN_SHADER:
			_expect(not SURFACES.has_surface(track_id), track_id + " brings its own road shader")
			continue
		for low in [false, true]:
			var world = WORLD.new()
			root.add_child(world)
			world.build(low, track_id, true)
			var material := world.road.material_override as ShaderMaterial
			_expect(material != null, track_id + " needs a shader road")
			if material == null:
				continue
			var style: Variant = material.get_shader_parameter("surface_style")
			if SURFACES.has_surface(track_id):
				var entry: Dictionary = SURFACES.surface(track_id)
				_expect(style is int and int(style) == int(entry.style), track_id + " style not applied")
				_expect(material.get_shader_parameter("road_tint") == entry.tint, track_id + " tint not applied")
				_expect(material.get_shader_parameter("detail_tint") == entry.detail, track_id + " detail not applied")
				_expect(absf(_luminance(entry.marking) - _luminance(entry.tint)) >= 0.25,
					track_id + " lane paint is not readable on its ground")
				seen["%d:%s" % [int(entry.style), entry.tint.to_html(false)]] = track_id
			else:
				_expect(style == null or int(style) == SURFACES.ASPHALT, track_id + " must stay classic asphalt")
			world.queue_free()
			await process_frame
	# No two themed courses share both style and colour.
	_expect(seen.size() == SURFACES.SURFACES.size(), "Two courses share the same ground")
	var status := "PASS" if failures.is_empty() else "FAIL"
	print("[KartRoadSurface] %s: %d checks on %d courses %s" % [status, checks, TRACKS.IDS.size(), failures])
	quit(0 if failures.is_empty() else 1)
