extends SceneTree
## Streckenkulisse: jede Strecke traegt strukturierte Pflanzen aus den Blender-Modellen
## (keine einfarbigen Kronen-Kugeln mehr nahe der Fahrbahn), Leuchten mit Lichtkegel
## und Lichtfleck, aktives Belag-Detail; Budgets je Profil werden eingehalten.
## Aufruf: godot --headless --path . --script res://scripts/tests/kart_scenery_quality_regression.gd

const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const SCENERY = preload("res://scripts/games/visual/kart_scenery.gd")
const TREE_SPECIES: Array[String] = [
	"laubbaum", "laubbaum_b", "nadelbaum", "palme", "zauberbaum", "dschungelbaum", "winterbaum"
]
## Strecken, an deren Rand Baeume oder Pflanzen gehoeren.
const GREEN_TRACKS: Array[String] = [
	"sonnenhafen", "zauberwald", "bergwelt", "jungle_temple", "winter_sprint", "desert_drift",
	"jungle_emerald_3600"
]
const OWN_ROAD_SHADER: Array[String] = ["candy_cloud", "jungle_emerald_3600"]
const MAX_LIGHTS: Dictionary = {"low": 0, "medium": 2, "high": 4, "ultra": 8}

var checks: int = 0
var failures: Array[String] = []
var performance: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("[KartScenery] FAIL ", message)


func _set_profile(name: String) -> void:
	if performance == null:
		return
	performance.call("set_profile", {"low": 0, "medium": 1, "high": 2, "ultra": 2}[name], false)
	performance.call("set_ultra", name == "ultra")


func _nodes(node: Node, prefix: String, out: Array) -> Array:
	if node.name.begins_with(prefix):
		out.append(node)
	for child in node.get_children():
		_nodes(child, prefix, out)
	return out


func _is_leafy(color: Color) -> bool:
	return color.g > color.r * 1.05 and color.g > color.b * 0.85 and color.s > 0.18


## Alte Einfarb-Kronen (Kugel/Kronen/Kegel in Baumgroesse und Laubfarbe) nahe der Fahrbahn.
func _old_crowns_near_road(world) -> int:
	var found := 0
	for node in world.get_children():
		if not (node is MultiMeshInstance3D) or not str(node.name).begins_with("Decor_"):
			continue
		var kind := str(node.name)
		if not (kind.begins_with("Decor_crown") or kind.begins_with("Decor_ball")
				or kind.begins_with("Decor_fir")) or kind.ends_with("_light"):
			continue
		var multimesh: MultiMesh = node.multimesh
		for i in range(multimesh.instance_count):
			var t: Transform3D = multimesh.get_instance_transform(i)
			if t.basis.get_scale().length() < 2.2:
				continue
			var color: Color = multimesh.get_instance_color(i) if multimesh.use_colors else Color.WHITE
			if kind.begins_with("Decor_fir"):
				color = Color(0.3, 0.6, 0.4)
			if not _is_leafy(color):
				continue
			var at: Vector3 = node.transform * t.origin
			if world._nearest_horizontal(at).x < 22.0:
				found += 1
	return found


func _check_track(track_id: String) -> void:
	var world = WORLD.new()
	root.add_child(world)
	world.build(false, track_id)
	var stats: Dictionary = world.get_meta("scenery_stats", {})
	_expect(not stats.is_empty(), track_id + ": Kulisse wurde nicht gebaut")
	var scenery: Node = world.get_node_or_null("KartScenery")
	_expect(scenery != null, track_id + ": KartScenery fehlt")
	if scenery == null:
		world.free()
		return
	var trees := 0
	var plants := 0
	for species in stats.get("species", {}):
		plants += int(stats.species[species])
		if species in TREE_SPECIES:
			trees += int(stats.species[species])
	if track_id in GREEN_TRACKS:
		_expect(trees + plants >= 40, "%s: zu wenig strukturierte Pflanzen (%d)" % [track_id, plants])
		var flora: Array = _nodes(scenery, "Flora_", [])
		_expect(not flora.is_empty(), track_id + ": keine Flora-MultiMeshes")
		for node in flora:
			var mm: MultiMesh = node.multimesh
			_expect(mm.mesh != null and mm.mesh.get_surface_count() == 1,
				track_id + ": Pflanzenmodell fehlt " + str(node.name))
			_expect(node.material_override is ShaderMaterial, track_id + ": Blattshader fehlt")
			if node.material_override is ShaderMaterial:
				var shader: Shader = (node.material_override as ShaderMaterial).shader
				_expect(not shader.code.contains("hint_screen_texture")
					and not shader.code.contains("hint_depth_texture"), "Blattshader mobil-tauglich")
				_expect(shader.code.contains("ALPHA_SCISSOR_THRESHOLD") and shader.code.contains("wind"),
					"Blattshader hat Alpha-Ausschnitt und Wind")
		var crowns: int = _old_crowns_near_road(world)
		_expect(crowns == 0, "%s: %d alte Einfarb-Kronen nahe der Fahrbahn" % [track_id, crowns])
	var look: Dictionary = SCENERY.theme(track_id)
	if look.has("lamp"):
		_expect(int(stats.get("lamps", 0)) >= 6, "%s: zu wenige Leuchten (%d)" % [track_id, stats.get("lamps", 0)])
		var lamps: Array = _nodes(scenery, "Lamps_", [])
		_expect(not lamps.is_empty(), track_id + ": keine Leuchten-MultiMeshes")
		if not lamps.is_empty():
			var lamp_mesh: Mesh = lamps[0].multimesh.mesh
			_expect(lamp_mesh.get_surface_count() == 2, track_id + ": Leuchte ohne Lichtflaeche")
			var glow: Material = lamp_mesh.surface_get_material(1)
			_expect(glow is ShaderMaterial and (glow as ShaderMaterial).shader.code.contains("blend_add"),
				track_id + ": Lichtkegel nicht additiv")
			var arrays: Array = lamp_mesh.surface_get_arrays(1)
			var has_cone := false
			for c: Color in arrays[Mesh.ARRAY_COLOR]:
				if absf(c.g - 0.5) < 0.05:
					has_cone = true
					break
			_expect(has_cone or str(look.lamp) == "leuchte_kette" or str(look.lamp) == "leuchte_fackel",
				track_id + ": Leuchte ohne Lichtkegel")
		if float(look.get("night", 0.0)) >= 0.05:
			_expect(not _nodes(scenery, "LightPools_", []).is_empty(), track_id + ": keine Lichtflecken")
	if track_id not in OWN_ROAD_SHADER:
		var road_material := world.road.material_override as ShaderMaterial
		_expect(road_material != null and float(road_material.get_shader_parameter("road_detail")) > 0.5,
			track_id + ": Belag-Detail nicht aktiv")
	print("[KartScenery] %s trees=%d plants=%d lamps=%d reflectors=%d particles=%d" % [
		track_id, trees, plants, stats.get("lamps", 0), stats.get("reflectors", 0), stats.get("particles", 0)])
	world.free()


func _profile_counts(track_id: String, profile: String) -> Dictionary:
	_set_profile(profile)
	var world = WORLD.new()
	root.add_child(world)
	world.build(profile == "low", track_id)
	var scenery: Node = world.get_node("KartScenery")
	var result := {"quality": world.get_meta("scenery_stats").quality, "lod0": 0, "verge": 0,
		"particles": 0, "lights": 0, "flora_nodes": 0, "flora_instances": 0, "shadow_nodes": 0}
	for node in _nodes(scenery, "Flora_", []):
		result.flora_nodes += 1
		if int(node.get_meta("scenery_lod")) == 0:
			result.lod0 += 1
			result.flora_instances += node.multimesh.instance_count
		if str(node.get_meta("scenery_species")) in ["wiese", "trockengras", "schneegras", "farnflur", "zauberflur"]:
			result.verge += 1
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			result.shadow_nodes += 1
	for node in _nodes(scenery, "AmbientParticles_", []):
		result.particles += node.multimesh.instance_count
	for node in _nodes(scenery, "LampLight", []):
		if node is OmniLight3D:
			result.lights += 1
	var road_material := world.road.material_override as ShaderMaterial
	result["road_detail"] = float(road_material.get_shader_parameter("road_detail"))
	world.free()
	return result


func _run() -> void:
	performance = root.get_node_or_null("PerformanceManager")
	_expect(performance != null and performance.has_method("set_ultra"), "PerformanceManager kennt ULTRA")
	_set_profile("high")
	for track_id in TRACKS.IDS:
		_check_track(track_id)
		await process_frame
	for track_id in ["sonnenhafen", "zauberwald", "holo_city"]:
		var counts: Dictionary = {}
		for profile in ["low", "medium", "high", "ultra"]:
			counts[profile] = _profile_counts(track_id, profile)
			_expect(counts[profile].quality == profile, "%s: Profil %s nicht aktiv (%s)" % [
				track_id, profile, counts[profile].quality])
			_expect(counts[profile].lights <= MAX_LIGHTS[profile], "%s %s: zu viele dynamische Lichter" % [
				track_id, profile])
			print("[KartScenery] budget %s %s %s" % [track_id, profile, counts[profile]])
			await process_frame
		var low: Dictionary = counts.low
		_expect(low.lod0 == 0 and low.verge == 0 and low.particles == 0 and low.lights == 0
			and low.shadow_nodes == 0 and low.road_detail == 0.0, track_id + ": LOW bleibt schlank")
		_expect(counts.medium.shadow_nodes == 0, track_id + ": MEDIUM ohne Pflanzenschatten")
		_expect(counts.medium.particles <= counts.high.particles
			and counts.high.particles <= counts.ultra.particles, track_id + ": Partikel steigen mit Profil")
		_expect(counts.medium.flora_instances <= counts.high.flora_instances + 1
			and counts.high.flora_instances <= counts.ultra.flora_instances + 1,
			track_id + ": Pflanzendichte steigt mit Profil")
	_set_profile("medium")
	var status := "PASS" if failures.is_empty() else "FAIL"
	print("[KartScenery] %s checks=%d failures=%d" % [status, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
