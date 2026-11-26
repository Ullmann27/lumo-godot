extends SceneTree
## Welt der Signatur-Strecken (Team B1) in allen drei Grafikprofilen: Aufbauzeit, Modelle,
## Klanginseln, Profilregeln (LOW ohne Schatten/Glow, weniger Teilchen) und ein simulierter
## Rennablauf über zwei Runden mit Ansagen und Ereignissen. Läuft headless.
##
##   godot --headless --path . --script res://scripts/tests/kart_signature_world_regression.gd \
##     [-- --track=<id>]
const SIGNATURE = preload("res://scripts/games/kart_signature/kart_signature_tracks.gd")
var failures: Array[String] = []


class FakeRace:
	extends Node
	var player := Node3D.new()
	var distance: float = 0.0
	var track_length: float = 1.0
	var paused: bool = false
	var racing: bool = true
	var finished: bool = false
	var elapsed: float = 0.0
	var message := Label.new()
	var kart_audio = null
	var heard: Array[String] = []

	func _init() -> void:
		add_child(player)
		add_child(message)


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("[SignatureWorld] " + label)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--track="):
			only = str(argument).trim_prefix("--track=")
	for track in SIGNATURE.IDS:
		if not only.is_empty() and only != track:
			continue
		var shares: Dictionary = {}
		for tier in ["low", "medium", "high"]:
			shares[tier] = await _tier(track, tier)
		check(
			shares.low < shares.medium and shares.medium <= shares.high,
			"%s: Teilchen je Profil %s" % [track, str(shares)]
		)
	print("[SignatureWorld] ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)


func _tier(track: String, tier: String) -> int:
	LumoQuality.set_tier(tier)
	var started := Time.get_ticks_msec()
	var world = load("res://scripts/games/kart_world.gd").new()
	root.add_child(world)
	world.build(tier == "low", track, false)
	var build_ms: int = Time.get_ticks_msec() - started
	var course = SIGNATURE.course(track)
	var scenery = world.get_node_or_null("SignatureEnvironment")
	check(scenery != null, "%s/%s: Kulisse gebaut" % [track, tier])
	if scenery == null:
		world.free()
		return 0
	check(scenery.tier == tier, "%s/%s: Profil übernommen (%s)" % [track, tier, scenery.tier])
	check(
		scenery.sun.shadow_enabled == (tier != "low"), "%s/%s: Schatten nach Profil" % [track, tier]
	)
	check(
		scenery.environment.glow_enabled == (tier != "low"),
		"%s/%s: Glow nach Profil" % [track, tier]
	)
	var particles: int = 0
	var modules: int = 0
	var lods: int = 0
	for node in scenery.find_children("*", "MultiMeshInstance3D", true, false):
		particles += node.multimesh.instance_count
	for node in scenery.find_children("*", "MeshInstance3D", true, false):
		if str(node.name).begins_with("LOD"):
			lods += 1
			if node.visibility_range_end > 0.0:
				modules += 1
	check(
		lods > 20 and modules == lods,
		"%s/%s: Blender-Module mit Sichtweiten (%d/%d)" % [track, tier, modules, lods]
	)
	check(
		scenery.audio != null and scenery.audio.emitters.size() == course.AMBIENCE.size(),
		"%s/%s: Klanginseln" % [track, tier]
	)
	# Zwei Runden mit 50 m/s: Ansagen und Ereignisse müssen kommen.
	var race := FakeRace.new()
	root.add_child(race)
	race.track_length = world.length
	var announcements: Array[String] = []
	var last := ""
	var step: float = 1.0 / 30.0
	while race.distance < world.length * 2.0:
		race.distance += 50.0 * step
		race.elapsed += step
		race.player.global_position = world.position_at(race.distance)
		scenery.advance_race(race, step)
		if race.message.text != last:
			last = race.message.text
			announcements.append(last)
	race.finished = true
	scenery.celebrate_finish()
	scenery.advance_race(race, step)
	var events: Dictionary = {}
	for key in ["eruptions", "lightning", "fountain_bursts", "tide"]:
		if scenery.parts.has(key):
			events[key] = scenery.parts[key]
	check(
		announcements.size() >= 4,
		"%s/%s: Ansagen in zwei Runden (%d)" % [track, tier, announcements.size()]
	)
	check(
		# Wiederkehrende Ereignisse je Runde, die Flut steigt einmal (Runde 2).
		(
			not events.is_empty()
			and events.keys().all(func(k): return int(events[k]) >= (1 if k == "tide" else 2))
		),
		"%s/%s: Ereignisse %s" % [track, tier, str(events)]
	)
	print(
		(
			"[SignatureWorld] %s %s: Aufbau %d ms, %d Teilchen, %d LOD-Meshes, Ansagen %d, Ereignisse %s"
			% [track, tier, build_ms, particles, lods, announcements.size(), str(events)]
		)
	)
	print("[SignatureWorld] Bauschritte (ms): %s" % str(scenery.parts.get("timing_ms", [])))
	race.free()
	world.free()
	await process_frame
	return particles
