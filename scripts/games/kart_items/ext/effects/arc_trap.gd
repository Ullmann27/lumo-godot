extends "res://scripts/games/kart_items/ext/kart_item_ext_effect.gd"
## LICHTBOGEN-FALLE – das Kart setzt hinter sich zwei leuchtende Pfosten, zwischen denen
## ein knisternder Energiebogen steht. Wer hindurchfährt, wird kurz gebremst.
##   0.00–0.35 s  AUSLÖSER  Pfosten fallen vom Heck auf die Fahrbahn (3 m hinter dem Kart).
##   0.35 s       AUFBAU    Bogen zündet zwischen den Pfosten (Spannweite 2,6 m, Höhe 1,4 m).
##   bis 8 s      LAUERN    Bogen knistert, Bodenlinie glüht violett: gut sichtbar, umfahrbar.
##   Kontakt      EINSCHLAG Blitz am Kart, Funken; Tempo 70 % für 0,9 s (weich zurück).
##   danach       ABKLINGEN Bogen bricht zusammen, Pfosten versinken (0,5 s).
## Nie unpassierbar: Mitte so gelegt, dass zur Planke mindestens 2,4 m frei bleiben; kein
## Setzen auf Brückendeck, Kante, Rampe oder Passagen-Zone. Schild/Schonzeit gelten, KI weicht
## aus (lane_bias) und legt Fallen, wenn dicht hinter ihr jemand fährt.

const FX = preload("res://scripts/games/kart_items/ext/kart_item_ext_fx.gd")
const BEHIND: float = 3.0
const HALF_SPAN: float = 1.3
const FREE_GAP: float = 2.4
const LIFE: float = 8.0
const DROP: float = 0.35
const COLLAPSE: float = 0.5
const SLOW: float = 0.7
const SLOW_SECONDS: float = 0.9
const VIOLET := Color(0.75, 0.45, 1.0)
const WHITE_HOT := Color(0.95, 0.9, 1.0)

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	pool_cap = 4
	rear_warning = false


func use(owner: int, item_id: String, _row: Dictionary) -> bool:
	var at: float = host.progress(owner) - BEHIND
	if not host.safe_at(at):
		if owner == -1:
			host.say("Lichtbogen-Falle: Hier ist es zu eng – gleich nochmal.")
		return false
	var wall: float = float(host.race._wall_lateral_at(fposmod(at, host.track_length())))
	var limit: float = wall - HALF_SPAN - FREE_GAP
	if limit < 0.0:
		return false
	(
		active
		. append(
			{
				"owner": owner,
				"item": item_id,
				"age": 0.0,
				"phase": "set",
				"progress": at,
				"lateral": clampf(host.lateral(owner), -limit, limit),
				"hit_key": -99,
				"hit_at": 0.0,
			}
		)
	)
	if owner == -1:
		host.say("Lichtbogen-Falle steht hinter dir!")
		host.sound("arc_place")
	else:
		var gap: float = at - host.progress(-1)
		if gap > 0.0 and gap < 45.0:
			host.warn_player("Achtung: Lichtbogen vor dir – außen vorbei!")
		elif host.eye().distance_to(host.kart_centre(owner)) < 45.0:
			host.sound("arc_place", 1.1)
	return true


func rival_wants(index: int, _item_id: String, context: Dictionary) -> bool:
	var behind: float = float(context.get("behind_gap", INF))
	return behind > 4.0 and behind < 16.0 and host.safe_at(host.progress(index) - BEHIND)


## Sekunden, bis `key` die Falle erreicht (nur wenn sie in seiner Spur liegt).
func incoming(key: int) -> float:
	var best: float = INF
	for entry in active:
		if str(entry.phase) != "set" or int(entry.owner) == key:
			continue
		var gap: float = float(entry.progress) - host.progress(key)
		if (
			gap > 0.0
			and gap < 40.0
			and absf(host.lateral(key) - float(entry.lateral)) < HALF_SPAN + 0.8
		):
			var speed: float = maxf(
				6.0,
				(
					absf(float(host.race.speed))
					if key == -1
					else absf(float(host.race.opponents[key].motion_speed))
				)
			)
			best = minf(best, gap / speed)
	return best


func lane_bias(index: int) -> float:
	var bias: float = 0.0
	for entry in active:
		if str(entry.phase) != "set" or int(entry.owner) == index:
			continue
		var gap: float = float(entry.progress) - host.progress(index)
		if gap < 0.0 or gap > 28.0:
			continue
		var side: float = host.lateral(index) - float(entry.lateral)
		if absf(side) < HALF_SPAN + 1.4:
			var away: float = signf(side) if absf(side) > 0.1 else -signf(float(entry.lateral))
			bias += (HALF_SPAN + 1.4 - absf(side)) * (away if away != 0.0 else 1.0)
	return bias


func _valid_saved(entry: Dictionary) -> bool:
	return (
		super._valid_saved(entry)
		and entry.has("progress")
		and entry.has("phase")
		and host._valid_key(int(entry.owner))
	)


func tick(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for entry in active:
		entry.age = float(entry.age) + delta
		if str(entry.phase) == "set":
			if float(entry.age) >= LIFE:
				entry.phase = "done"
				entry.hit_at = float(entry.age)
				stats.fizzled += 1
			elif float(entry.age) >= DROP:
				_contacts(entry)
		if (
			str(entry.phase) == "done"
			and (
				float(entry.age)
				> (
					float(entry.hit_at)
					+ COLLAPSE
					+ (SLOW_SECONDS if int(entry.hit_key) != -99 else 0.0)
				)
			)
		):
			release(entry)
			continue
		var rig: Node3D = acquire(entry)
		if rig != null:
			_draw(entry, rig)
		keep.append(entry)
	active = keep


func _contacts(entry: Dictionary) -> void:
	for key in host.racer_keys():
		if key == int(entry.owner) and float(entry.age) < 3.0:
			continue
		if (
			absf(host.progress(key) - float(entry.progress)) <= 0.9
			and absf(host.lateral(key) - float(entry.lateral)) <= HALF_SPAN + 0.55
		):
			entry.phase = "done"
			entry.hit_at = float(entry.age)
			entry.hit_key = key
			entry.result = host.resolve(
				key, int(entry.owner), str(entry.item), host.kart_centre(key)
			)
			if str(entry.result) == "hit":
				stats.hits += 1
				host.add_mod(key, "arc", SLOW_SECONDS, SLOW, 0.9, 1.0)
				if key == -1:
					host.say("Bzzt! Durch den Lichtbogen – kurz langsamer.")
				elif int(entry.owner) == -1:
					host.say("%s fährt in deinen Lichtbogen!" % host.race._rival_name(key))
			elif str(entry.result) == "blocked":
				stats.blocked += 1
			else:
				stats.grace += 1
			if (
				host.involves_player(int(entry.owner), key)
				or host.eye().distance_to(host.kart_centre(key)) < 45.0
			):
				host.sound("arc_zap")
			return


func build_rig() -> Node3D:
	var rig := Node3D.new()
	rig.name = "ArcTrap"
	rig.top_level = true
	var pylon := CylinderMesh.new()
	pylon.top_radius = 0.07
	pylon.bottom_radius = 0.13
	pylon.height = 1.1
	pylon.radial_segments = 10
	var pylon_material: StandardMaterial3D = FX.solid(
		Color(0.25, 0.2, 0.4), Color(0.7, 0.4, 1.0), 1.6, 1.0, 0.3
	)
	for k in range(2):
		var post := MeshInstance3D.new()
		post.name = "Post%d" % k
		post.mesh = pylon
		post.material_override = pylon_material
		rig.add_child(post)
		var cap: MeshInstance3D = FX.sprite(
			0.8, FX.glow(Color(0.85, 0.6, 1.0, 1.0), true, FX.soft_dot())
		)
		cap.name = "Cap"
		cap.position = Vector3(0, 0.6, 0)
		post.add_child(cap)
	var arc_material := StandardMaterial3D.new()
	arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arc_material.vertex_color_use_as_albedo = true
	arc_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	arc_material.render_priority = 2
	for line_name in ["Arc", "Ground"]:
		var line := MeshInstance3D.new()
		line.name = line_name
		line.mesh = ImmediateMesh.new()
		line.material_override = arc_material
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.add_child(line)
	var spark_recipe := {
		"amount": host.budget(36),
		"lifetime": 0.6,
		"size": 0.16,
		"one_shot": true,
		"explosiveness": 0.95,
		"spread": 90.0,
		"speed_min": 2.5,
		"speed_max": 6.0,
		"gravity": Vector3(0, -9, 0),
		"colors": [Color(1, 1, 1, 1), Color(0.8, 0.5, 1.0, 1), Color(0.5, 0.3, 1.0, 0)],
	}
	var sparks: CPUParticles3D = FX.emitter(spark_recipe)
	sparks.name = "Sparks"
	rig.add_child(sparks)
	return rig


func reset_rig(rig: Node3D, _entry: Dictionary) -> void:
	rig.set_meta("sparked", false)
	rig.set_meta("seed", -1)


func _draw(entry: Dictionary, rig: Node3D) -> void:
	var reduced: bool = host.reduced_motion
	var age: float = float(entry.age)
	var p: float = float(entry.progress)
	var l: float = float(entry.lateral)
	var basis: Basis = host.track_basis(p)
	var up: Vector3 = basis.y.normalized()
	var collapse: float = 0.0
	if str(entry.phase) == "done":
		collapse = clampf((age - float(entry.hit_at)) / COLLAPSE, 0.0, 1.0)
	var drop: float = smoothstep(0.0, 1.0, age / DROP)
	var ends: Array[Vector3] = []
	for k in range(2):
		var side: float = -HALF_SPAN if k == 0 else HALF_SPAN
		var foot: Vector3 = host.track_global(p, l + side, 0.0)
		var post: MeshInstance3D = rig.get_node("Post%d" % k)
		var sink: float = collapse * 1.1
		post.global_transform = Transform3D(basis, foot + up * (0.55 + (1.0 - drop) * 0.8 - sink))
		post.visible = collapse < 1.0
		ends.append(foot + up * (1.05 - sink))
	var arc_mesh: ImmediateMesh = (rig.get_node("Arc") as MeshInstance3D).mesh
	var ground_mesh: ImmediateMesh = (rig.get_node("Ground") as MeshInstance3D).mesh
	var live: bool = age >= DROP and collapse < 0.6
	if not live:
		arc_mesh.clear_surfaces()
	else:
		var step: int = 0 if reduced else int(age / 0.08)
		if int(rig.get_meta("seed", -1)) != step:
			rig.set_meta("seed", step)
			_rng.seed = 313 + step * 17
			var lines: Array = []
			var strands: int = 1 if host.quality == "low" else 2
			for _s in range(strands):
				var points := PackedVector3Array()
				var segments: int = 12
				for k in range(segments + 1):
					var t: float = float(k) / float(segments)
					var point: Vector3 = (
						ends[0].lerp(ends[1], t) + up * sin(PI * t) * 0.55 * (1.0 - collapse)
					)
					if k > 0 and k < segments:
						point += (
							(up * _rng.randf_range(-1, 1) + basis.z * _rng.randf_range(-1, 1))
							* 0.13
							* sin(PI * t)
						)
					points.append(point)
				var glow := {"points": points, "width": 3.2, "color": Color(VIOLET, 0.55)}
				var core := {"points": points, "width": 1.0, "color": WHITE_HOT}
				lines.append(glow)
				lines.append(core)
			FX.ribbons(arc_mesh, lines, host.eye(), 0.09, VIOLET, Transform3D.IDENTITY)
	# Bodenlinie: Gefahrenmarke über die volle Spannweite (Vorwarnung von weitem).
	if collapse < 1.0:
		var pulse: float = 1.0 if reduced else 0.75 + 0.25 * sin(age * 6.0)
		var a: Vector3 = host.track_global(p, l - HALF_SPAN, 0.05)
		var b: Vector3 = host.track_global(p, l + HALF_SPAN, 0.05)
		var above: Vector3 = (a + b) * 0.5 + up * 1000.0
		var mark := {
			"points": PackedVector3Array([a, b]),
			"width": 1.0,
			"color": Color(0.8, 0.45, 1.0, 0.8 * pulse * (1.0 - collapse))
		}
		FX.ribbons(ground_mesh, [mark], above, 0.45, VIOLET, Transform3D.IDENTITY)
	else:
		ground_mesh.clear_surfaces()
	if (
		str(entry.phase) == "done"
		and int(entry.hit_key) != -99
		and not bool(rig.get_meta("sparked", false))
	):
		rig.set_meta("sparked", true)
		FX.burst(rig.get_node("Sparks"), host.kart_centre(int(entry.hit_key)), Vector3.UP)
