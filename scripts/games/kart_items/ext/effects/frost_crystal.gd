extends "res://scripts/games/kart_items/ext/kart_item_ext_effect.gd"
## FROSTKRISTALL – eine Eiskapsel fliegt im sichtbaren Bogen zum Rivalen vorn und überzieht
## beim Auftreffen dessen RÄDER mit Eis. Kette aus echten Positionen:
##   0.00 s          AUSLÖSER   Kapsel springt vorn vom eigenen Kart ab (Glasklang).
##   0.00–flug       WEG        Bogen vom Abwurfpunkt zum *aktuellen* Ziel (folgt ihm), Höhe
##                               1,2 m + 4 % der Distanz; Frostspur zeichnet die Bahn nach.
##                               flug = Abstand / 38 m/s, 0,55–1,30 s.
##   flug            EINSCHLAG  Kapsel zerspringt in Splitter + Frostnebel am Kart.
##   flug+0.00–0.20  REAKTION   Eiskrusten wachsen an allen vier Radnaben; 1,6 s lang Lenkung
##                               auf 58 %, Haftung 55 % (Kind: leicht rutschig, nie blockiert),
##                               Tempo 90 %; Raureif-Spuren bleiben hinter den Hinterrädern.
##   letzte 0,6 s    ABKLINGEN  Krusten schrumpfen, Tropfen fallen, Dampf steigt auf.
## Passagenvertrag: Ziel nur auf sicherer Fahrbahn (kein Brückendeck, keine offene Kante, keine
## Rampe, keine Passagen-Zone). Wird es während des Flugs unsicher, verpufft der Frost harmlos.

const FX = preload("res://scripts/games/kart_items/ext/kart_item_ext_fx.gd")
const SPEED: float = 38.0
const FROST: float = 1.6
const MELT: float = 0.6
const RANGE: float = 50.0
const TURN: float = 0.58
const GRIP: float = 0.55
const PACE: float = 0.9
const ICE := Color(0.72, 0.93, 1.0)


func _init() -> void:
	pool_cap = 3


func use(owner: int, item_id: String, _row: Dictionary) -> bool:
	var target: int = host.pick_target(owner, RANGE, 0.0, true)
	if target == -99:
		if owner == -1:
			var any: int = host.pick_target(owner, RANGE, 0.0, false)
			host.say(
				(
					(
						"Frostkristall wartet: %s fährt gerade an einer Brücke oder Kante."
						% host.race._rival_name(any)
					)
					if any != -99
					else "Frostkristall: Kein Rivale vorn in Reichweite – halte ihn noch."
				)
			)
		return false
	var gap: float = absf(host.progress(target) - host.progress(owner))
	(
		active
		. append(
			{
				"owner": owner,
				"target": target,
				"item": item_id,
				"age": 0.0,
				"flight": clampf(gap / SPEED, 0.55, 1.3),
				"start_p": host.progress(owner) + 1.4,
				"start_l": host.lateral(owner),
				"result": "",
			}
		)
	)
	host.note_attack(target)
	if owner == -1:
		host.say("Frostkristall fliegt zu %s!" % host.race._rival_name(target))
		host.sound("frost_launch")
	elif target == -1:
		host.warn_player("Achtung: Eiskapsel von %s – Schild!" % host.race._rival_name(owner))
	return true


func rival_wants(index: int, _item_id: String, _context: Dictionary) -> bool:
	var target: int = host.pick_target(index, 40.0, 0.0, true)
	if target == -99 or host.protected(target):
		return false
	return host.progress(target) - host.progress(index) > 7.0


func incoming(key: int) -> float:
	var best: float = INF
	for entry in active:
		if int(entry.target) == key and str(entry.result).is_empty():
			best = minf(best, float(entry.flight) - float(entry.age))
	return best


func _valid_saved(entry: Dictionary) -> bool:
	return (
		super._valid_saved(entry)
		and entry.has("flight")
		and entry.has("target")
		and host._valid_key(int(entry.target))
		and host._valid_key(int(entry.owner))
	)


func _end_time(entry: Dictionary) -> float:
	return float(entry.flight) + (FROST + 0.25 if str(entry.result) == "hit" else 0.9)


func tick(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for entry in active:
		entry.age = float(entry.age) + delta
		if float(entry.age) >= float(entry.flight) and str(entry.result).is_empty():
			_impact(entry)
		if float(entry.age) > _end_time(entry):
			release(entry)
			continue
		var rig: Node3D = acquire(entry)
		if rig != null:
			_draw(entry, rig)
		keep.append(entry)
	active = keep


func _start_point(entry: Dictionary) -> Vector3:
	return host.track_global(float(entry.start_p), float(entry.start_l), 0.9)


func _capsule_at(entry: Dictionary, s: float) -> Vector3:
	var from: Vector3 = _start_point(entry)
	var to: Vector3 = host.kart_centre(int(entry.target))
	var height: float = 1.2 + from.distance_to(to) * 0.04
	return from.lerp(to, s) + Vector3.UP * sin(PI * s) * height


func _impact(entry: Dictionary) -> void:
	var target: int = int(entry.target)
	var owner: int = int(entry.owner)
	var from: Vector3 = _capsule_at(entry, 0.9)
	var centre: Vector3 = host.kart_centre(target)
	var dome_point: Vector3 = centre + (from - centre).normalized() * 1.4
	if not host.safe_at(host.progress(target), target):
		entry.result = "fizzled"
		stats.fizzled += 1
		stats.safety_skipped += 1
		if host.involves_player(owner, target):
			host.say("Der Frost verpufft – an Brücken und Kanten friert niemand ein.")
		return
	entry.result = host.resolve(target, owner, str(entry.item), dome_point)
	match str(entry.result):
		"hit":
			stats.hits += 1
			host.add_mod(target, "frost", FROST, PACE, TURN, GRIP)
			if owner == -1:
				host.say("Eis an den Rädern! %s rutscht kurz." % host.race._rival_name(target))
			elif target == -1:
				host.say("Eis an den Rädern – sanft lenken, es taut gleich!")
		"blocked":
			stats.blocked += 1
		"grace":
			stats.grace += 1
	if host.involves_player(owner, target) or host.eye().distance_to(centre) < 60.0:
		host.sound("frost_hit", 1.0 if str(entry.result) == "hit" else 1.15)


# --- Darstellung ---------------------------------------------------------------------------


func build_rig() -> Node3D:
	var rig := Node3D.new()
	rig.name = "FrostCrystal"
	rig.top_level = true
	var capsule := MeshInstance3D.new()
	capsule.name = "Capsule"
	capsule.mesh = FX.crystal_mesh(0.42, 1.3)
	capsule.material_override = FX.solid(
		Color(0.32, 0.72, 1.0), Color(0.2, 0.6, 1.0), 2.4, 0.95, 0.05
	)
	capsule.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(capsule)
	var core: MeshInstance3D = FX.sprite(1.9, FX.soft(Color(0.35, 0.72, 1.0, 0.75), true))
	core.name = "Core"
	rig.add_child(core)
	var trail_recipe := {
		"amount": host.budget(40),
		"lifetime": 0.55,
		"size": 0.34,
		"spread": 180.0,
		"speed_min": 0.1,
		"speed_max": 0.6,
		"colors": [Color(0.85, 0.95, 1, 1), Color(0.35, 0.7, 1.0, 0.85), Color(0.3, 0.6, 1.0, 0)],
		"additive": false,
		"gravity": Vector3(0, -0.6, 0),
		"grow": 0.5,
	}
	var trail: CPUParticles3D = FX.emitter(trail_recipe)
	trail.name = "Trail"
	rig.add_child(trail)
	var streak := MeshInstance3D.new()
	streak.name = "Streak"
	streak.mesh = ImmediateMesh.new()
	streak.material_override = FX.soft(Color.WHITE, false, false)
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(streak)
	var shards_recipe := {
		"amount": host.budget(34),
		"lifetime": 0.75,
		"size": 0.2,
		"one_shot": true,
		"explosiveness": 1.0,
		"spread": 180.0,
		"speed_min": 2.5,
		"speed_max": 6.5,
		"gravity": Vector3(0, -9.0, 0),
		"additive": false,
		"colors": [Color(0.9, 0.97, 1, 1), Color(0.35, 0.72, 1.0, 1), Color(0.3, 0.6, 1.0, 0)],
	}
	var shards: CPUParticles3D = FX.emitter(shards_recipe)
	shards.name = "Shards"
	rig.add_child(shards)
	var mist_recipe := {
		"amount": host.budget(14),
		"lifetime": 0.9,
		"size": 1.1,
		"one_shot": true,
		"explosiveness": 0.9,
		"spread": 180.0,
		"speed_min": 0.5,
		"speed_max": 1.6,
		"additive": false,
		"grow": 2.0,
		"colors": [Color(0.7, 0.86, 1.0, 0.8), Color(0.75, 0.9, 1.0, 0.0)],
	}
	var mist: CPUParticles3D = FX.emitter(mist_recipe)
	mist.name = "Mist"
	rig.add_child(mist)
	var ice_material: StandardMaterial3D = FX.solid(
		Color(0.42, 0.78, 1.0), Color(0.25, 0.62, 1.0), 1.3, 0.9, 0.05
	)
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.5
	shell_mesh.height = 1.0
	shell_mesh.radial_segments = 12
	shell_mesh.rings = 6
	for k in range(4):
		var wheel := Node3D.new()
		wheel.name = "Ice%d" % k
		var shell := MeshInstance3D.new()
		shell.mesh = shell_mesh
		shell.material_override = ice_material
		shell.scale = Vector3(0.82, 0.78, 0.82)
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wheel.add_child(shell)
		for spike in range(3):
			var shard := MeshInstance3D.new()
			shard.mesh = FX.crystal_mesh(0.12, 0.6)
			shard.material_override = ice_material
			var angle: float = TAU * spike / 3.0 + k
			shard.position = (
				Vector3(0.0, 0.18 + 0.05 * spike, 0.0) + Vector3(cos(angle), 0.0, sin(angle)) * 0.2
			)
			shard.rotation = Vector3(cos(angle) * 0.5, angle, sin(angle) * 0.5)
			shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			wheel.add_child(shard)
		rig.add_child(wheel)
	for k in range(2):
		var rime_recipe := {
			"amount": host.budget(30),
			"lifetime": 1.4,
			"size": 0.2,
			"spread": 30.0,
			"speed_min": 0.0,
			"speed_max": 0.2,
			"colors":
			[Color(0.6, 0.85, 1, 0.95), Color(0.45, 0.75, 1.0, 0.8), Color(0.45, 0.75, 1.0, 0)],
			"additive": false,
			"box": Vector3(0.12, 0.02, 0.12),
			"scale_min": 0.8,
			"scale_max": 1.4,
		}
		var rime: CPUParticles3D = FX.emitter(rime_recipe)
		rime.name = "Rime%d" % k
		rig.add_child(rime)
	var drips_recipe := {
		"amount": host.budget(18),
		"lifetime": 0.6,
		"size": 0.12,
		"direction": Vector3.DOWN,
		"spread": 12.0,
		"speed_min": 0.4,
		"speed_max": 1.2,
		"gravity": Vector3(0, -9.0, 0),
		"box": Vector3(0.7, 0.05, 0.85),
		"colors": [Color(0.75, 0.92, 1.0, 1), Color(0.4, 0.75, 1.0, 0.9), Color(0.4, 0.75, 1.0, 0)],
	}
	var drips: CPUParticles3D = FX.emitter(drips_recipe)
	drips.name = "Drips"
	rig.add_child(drips)
	var steam_recipe := {
		"amount": host.budget(16),
		"lifetime": 1.0,
		"size": 0.7,
		"spread": 25.0,
		"speed_min": 0.6,
		"speed_max": 1.4,
		"gravity": Vector3(0, 0.8, 0),
		"box": Vector3(0.75, 0.05, 0.9),
		"additive": false,
		"grow": 2.2,
		"colors": [Color(1, 1, 1, 0.0), Color(0.95, 0.98, 1.0, 0.55), Color(1, 1, 1, 0)],
	}
	var steam: CPUParticles3D = FX.emitter(steam_recipe)
	steam.name = "Steam"
	rig.add_child(steam)
	return rig


func reset_rig(rig: Node3D, _entry: Dictionary) -> void:
	for node_name in ["Capsule", "Core", "Streak"]:
		(rig.get_node(node_name) as Node3D).visible = false
	for k in range(4):
		(rig.get_node("Ice%d" % k) as Node3D).visible = false
	for emitter_name in ["Trail", "Rime0", "Rime1", "Drips", "Steam"]:
		(rig.get_node(emitter_name) as CPUParticles3D).emitting = false
	(rig.get_node("Streak") as MeshInstance3D).mesh.clear_surfaces()
	rig.set_meta("path", PackedVector3Array())
	rig.set_meta("burst", false)
	rig.set_meta("melt_sound", false)
	rig.set_meta("steam_on", false)


func _draw(entry: Dictionary, rig: Node3D) -> void:
	var age: float = float(entry.age)
	var flight: float = float(entry.flight)
	var target: int = int(entry.target)
	var reduced: bool = host.reduced_motion
	var capsule: MeshInstance3D = rig.get_node("Capsule")
	var core: MeshInstance3D = rig.get_node("Core")
	var trail: CPUParticles3D = rig.get_node("Trail")
	var streak: MeshInstance3D = rig.get_node("Streak")
	var flying: bool = age < flight
	capsule.visible = flying
	core.visible = flying
	trail.emitting = flying
	var path: PackedVector3Array = rig.get_meta("path", PackedVector3Array())
	if flying:
		var s: float = clampf(age / flight, 0.0, 1.0)
		var at: Vector3 = _capsule_at(entry, s)
		var ahead: Vector3 = _capsule_at(entry, minf(1.0, s + 0.05))
		capsule.global_position = at
		core.global_position = at
		trail.global_position = at
		if at.distance_squared_to(ahead) > 0.0001:
			capsule.global_basis = (
				Basis.looking_at(ahead - at, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
			)
		if not reduced:
			capsule.rotate_object_local(Vector3.UP, age * 9.0)
		capsule.scale = Vector3.ONE * minf(1.0, 0.4 + age * 6.0)
		path.append(at)
		if path.size() > 14:
			path = path.slice(path.size() - 14)
	elif path.size() > 0:
		path = path.slice(1)
	rig.set_meta("path", path)
	# Sichtbare Bahn: weiß-blaue Frostspur, die zum Schweif hin ausdünnt.
	if path.size() >= 2:
		streak.visible = true
		var lines: Array = []
		for k in range(path.size() - 1):
			var alpha: float = float(k + 1) / float(path.size())
			lines.append(
				{
					"points": PackedVector3Array([path[k], path[k + 1]]),
					"width": 0.35 + alpha,
					"color": Color(0.3, 0.68, 1.0, 0.85 * alpha)
				}
			)
		FX.ribbons(streak.mesh, lines, host.eye(), 0.22, ICE, Transform3D.IDENTITY)
	else:
		streak.visible = false
	if flying or str(entry.result).is_empty():
		return
	var since: float = age - flight
	var centre: Vector3 = host.kart_centre(target)
	if not bool(rig.get_meta("burst", false)):
		rig.set_meta("burst", true)
		var burst_at: Vector3 = centre
		if str(entry.result) == "blocked":
			burst_at = centre + (_capsule_at(entry, 0.85) - centre).normalized() * 1.4
		elif str(entry.result) == "fizzled":
			burst_at = _capsule_at(entry, 0.92)
		FX.burst(rig.get_node("Shards"), burst_at)
		FX.burst(rig.get_node("Mist"), burst_at)
	var frozen: bool = str(entry.result) == "hit" and since < FROST
	var wheels: Array[Vector3] = []
	if frozen:
		wheels = host.wheel_points(target)
	var kart: Node3D = host.kart(target)
	var melt: float = clampf((since - (FROST - MELT)) / MELT, 0.0, 1.0)
	var grow: float = 1.0 if reduced else smoothstep(0.0, 0.2, since)
	for k in range(4):
		var ice: Node3D = rig.get_node("Ice%d" % k)
		ice.visible = frozen and k < wheels.size()
		if ice.visible:
			ice.global_position = wheels[k] + Vector3.UP * 0.02
			ice.global_basis = (
				kart.global_basis.orthonormalized() if is_instance_valid(kart) else Basis()
			)
			ice.scale = Vector3.ONE * maxf(0.05, grow * (1.0 - melt * 0.85))
	for k in range(2):
		var rime: CPUParticles3D = rig.get_node("Rime%d" % k)
		rime.emitting = frozen and melt < 0.6 and wheels.size() >= 4
		if rime.emitting:
			rime.global_position = wheels[2 + k] - Vector3.UP * 0.22
	var drips: CPUParticles3D = rig.get_node("Drips")
	var steam: CPUParticles3D = rig.get_node("Steam")
	var melting: bool = frozen and melt > 0.0
	drips.emitting = melting
	steam.emitting = melting and host.quality != "low"
	if melting and is_instance_valid(kart):
		var low: Vector3 = kart.global_position + kart.global_basis.y.normalized() * 0.3
		drips.global_transform = Transform3D(kart.global_basis.orthonormalized(), low)
		steam.global_transform = Transform3D(kart.global_basis.orthonormalized(), low)
		if not bool(rig.get_meta("steam_on", false)):
			# Alpha-Dampf erst hier starten (keine Schwarzscheibe im Kompatibilitäts-Renderer).
			rig.set_meta("steam_on", true)
			steam.restart()
		if (
			not bool(rig.get_meta("melt_sound", false))
			and host.involves_player(int(entry.owner), target)
		):
			rig.set_meta("melt_sound", true)
			host.sound("frost_melt")
