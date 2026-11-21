extends "res://scripts/games/kart_items/ext/kart_item_ext_effect.gd"
## FEUERMETEOR – eine glühende Kugel mit Feuerschweif, Rauch und Funken wird nach vorn
## geschossen. Kette aus echten Positionen (Streckenraum: Fortschritt + Querlage):
##   0.00–0.15 s  AUSLÖSER  Kugel löst sich vorn vom Kart (Stichflamme + Rauchstoß nach hinten).
##   0.15–1.70 s  WEG       fliegt 1,1 m über der Fahrbahn mit Kart-Tempo + 22 m/s, lenkt sanft
##                          (5 m/s quer) zum Rivalen vorn; Feuerschweif, Rauchfahne, Funken.
##   Treffer      EINSCHLAG Glutblitz + Funkenregen am Kart.
##                REAKTION  Tempo kurz auf 62 % (weich zurück in 1,2 s), Rußwolke steigt vom
##                          Kart auf; Kart bleibt steuerbar.
##   kein Treffer LANDUNG   in den letzten 0,35 s senkt sich die Kugel auf die Fahrbahn. Ist die
##                          Stelle sicher (keine Brücke/Kante/Rampe/Passage, nicht an der Planke),
##                          bleibt ein Glutfeld (Ø 2,8 m) 3,5 s liegen: glüht orange -> rot ->
##                          Asche aus. Wer hindurchfährt: 0,7 s 82 % Tempo (Schild/Schonzeit
##                          gelten). Es blockiert nie: links und rechts ist immer Platz.
## Schild: Kugel zerplatzt an der Kuppel in Funken, Kuppel zeigt Welle („ABGEPRALLT!“).

const FX = preload("res://scripts/games/kart_items/ext/kart_item_ext_fx.gd")
const LIFE: float = 1.7
const LAUNCH: float = 0.15
const DROP: float = 0.35
const CLOSING: float = 22.0
const LOCK_RANGE: float = 32.0
const LATERAL_SPEED: float = 5.0
const HIT_PROGRESS: float = 1.6
const HIT_LATERAL: float = 1.35
const SLOW: float = 0.62
const SLOW_SECONDS: float = 1.2
const FIELD_SECONDS: float = 3.5
const FIELD_RADIUS: float = 1.4
const FIELD_SLOW: float = 0.82
const FIELD_SLOW_SECONDS: float = 0.7
const OWNER_GRACE: float = 0.5


func _init() -> void:
	pool_cap = 4


func use(owner: int, item_id: String, _row: Dictionary) -> bool:
	var target: int = host.pick_target(owner, LOCK_RANGE, 0.0)
	var carrier: float = (
		maxf(0.0, float(host.race.speed))
		if owner == -1
		else absf(float(host.race.opponents[owner].motion_speed))
	)
	(
		active
		. append(
			{
				"owner": owner,
				"target": target,
				"item": item_id,
				"age": 0.0,
				"phase": "fly",
				"progress": host.progress(owner) + 1.6,
				"lateral": host.lateral(owner),
				"speed": maxf(30.0, carrier + CLOSING),
				"result": "",
				"field_age": 0.0,
				"touched": [],
			}
		)
	)
	if target != -99:
		host.note_attack(target)
	if owner == -1:
		host.say(
			(
				"Feuermeteor! %s"
				% (
					"Er zielt auf %s." % host.race._rival_name(target)
					if target >= 0
					else "Er fliegt geradeaus."
				)
			)
		)
		host.sound("meteor_launch")
	elif target == -1:
		host.warn_player("Achtung: Feuermeteor von hinten – ausweichen oder Schild!")
	return true


func rival_wants(index: int, _item_id: String, _context: Dictionary) -> bool:
	var target: int = host.pick_target(index, 30.0, 0.0)
	if target == -99 or host.protected(target):
		return false
	var gap: float = host.progress(target) - host.progress(index)
	return gap > 6.0 and absf(host.lateral(target) - host.lateral(index)) < 3.0


func incoming(key: int) -> float:
	var best: float = INF
	for entry in active:
		if str(entry.phase) == "fly" and int(entry.target) == key:
			var gap: float = host.progress(key) - float(entry.progress)
			if gap > -HIT_PROGRESS:
				best = minf(best, maxf(0.0, gap) / maxf(1.0, float(entry.speed)))
	return best


## KI weicht anfliegenden Meteoren und liegenden Glutfeldern aus.
func lane_bias(index: int) -> float:
	var bias: float = 0.0
	var own_p: float = host.progress(index)
	var own_l: float = host.lateral(index)
	for entry in active:
		var gap: float = 0.0
		if str(entry.phase) == "fly" and int(entry.owner) != index:
			gap = own_p - float(entry.progress)
			if gap < 0.0 or gap > 22.0:
				continue
		elif str(entry.phase) == "field":
			gap = float(entry.progress) - own_p
			if gap < 0.0 or gap > 26.0:
				continue
		else:
			continue
		var side: float = own_l - float(entry.lateral)
		if absf(side) < 2.3:
			bias += (2.3 - absf(side)) * (1.0 if side >= 0.0 else -1.0)
	return bias


func _valid_saved(entry: Dictionary) -> bool:
	return (
		super._valid_saved(entry)
		and entry.has("progress")
		and entry.has("lateral")
		and entry.has("phase")
		and host._valid_key(int(entry.owner))
	)


func tick(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for entry in active:
		entry.age = float(entry.age) + delta
		match str(entry.phase):
			"fly":
				_fly(entry, delta)
			"field":
				entry.field_age = float(entry.field_age) + delta
				_field_contacts(entry)
		if str(entry.phase) == "done" and float(entry.age) > float(entry.get("end_at", 0.0)):
			release(entry)
			continue
		if str(entry.phase) == "field" and float(entry.field_age) >= FIELD_SECONDS:
			release(entry)
			continue
		var rig: Node3D = acquire(entry)
		if rig != null:
			_draw(entry, rig)
		keep.append(entry)
	active = keep


func _fly(entry: Dictionary, delta: float) -> void:
	var target: int = int(entry.target)
	if target != -99 and host._valid_key(target):
		var to_target: float = host.progress(target) - float(entry.progress)
		if to_target > 0.0 and to_target < LOCK_RANGE:
			entry.lateral = move_toward(
				float(entry.lateral), host.lateral(target), LATERAL_SPEED * delta
			)
	entry.progress = float(entry.progress) + float(entry.speed) * delta
	for key in host.racer_keys():
		if key == int(entry.owner) and float(entry.age) < OWNER_GRACE:
			continue
		if key == int(entry.owner):
			continue
		if (
			absf(host.progress(key) - float(entry.progress)) <= HIT_PROGRESS
			and absf(host.lateral(key) - float(entry.lateral)) <= HIT_LATERAL
		):
			_hit(entry, key)
			return
	if float(entry.age) >= LIFE:
		_land(entry)


func _hit(entry: Dictionary, key: int) -> void:
	entry.target = key
	var centre: Vector3 = host.kart_centre(key)
	var from: Vector3 = host.track_global(float(entry.progress) - 2.0, float(entry.lateral), 1.1)
	entry.result = host.resolve(
		key,
		int(entry.owner),
		str(entry.item),
		centre + (from - centre).normalized() * 1.4,
		"ABGEPRALLT!"
	)
	entry.phase = "done"
	entry.end_at = float(entry.age) + (SLOW_SECONDS + 0.2 if str(entry.result) == "hit" else 0.8)
	entry.hit_at = float(entry.age)
	match str(entry.result):
		"hit":
			stats.hits += 1
			host.add_mod(key, "meteor", SLOW_SECONDS, SLOW, 0.95, 1.0)
			if int(entry.owner) == -1:
				host.say(
					"Volltreffer! %s steckt kurz in der Rußwolke." % host.race._rival_name(key)
				)
			elif key == -1:
				host.say("Puff – Rußwolke! Kurz langsamer, gleich weiter.")
		"blocked":
			stats.blocked += 1
		"grace":
			stats.grace += 1
	if host.involves_player(int(entry.owner), key) or host.eye().distance_to(centre) < 60.0:
		host.sound("meteor_hit", 1.0 if str(entry.result) == "hit" else 1.2)


func _land(entry: Dictionary) -> void:
	var at: float = float(entry.progress)
	var wall: float = float(host.race._wall_lateral_at(fposmod(at, host.track_length())))
	entry.hit_at = float(entry.age)
	if host.safe_at(at) and absf(float(entry.lateral)) < wall - FIELD_RADIUS - 0.4:
		entry.phase = "field"
		entry.field_age = 0.0
		entry.touched = []
		stats.fields = int(stats.get("fields", 0)) + 1
		if host.eye().distance_to(host.track_global(at, float(entry.lateral))) < 50.0:
			host.sound("ember_hiss")
	else:
		entry.phase = "done"
		entry.result = "fizzled"
		entry.end_at = float(entry.age) + 0.8
		stats.fizzled += 1
		stats.safety_skipped += 1


func _field_contacts(entry: Dictionary) -> void:
	# Ein Glutfeld wirkt auf jeden Fahrer höchstens einmal, nur solange es noch glüht.
	if float(entry.field_age) > FIELD_SECONDS * 0.8:
		return
	for key in host.racer_keys():
		if key in entry.touched:
			continue
		if (
			absf(host.progress(key) - float(entry.progress)) <= FIELD_RADIUS
			and absf(host.lateral(key) - float(entry.lateral)) <= FIELD_RADIUS + 0.2
		):
			entry.touched.append(key)
			var result: String = host.resolve(
				key,
				int(entry.owner),
				str(entry.item),
				host.kart_centre(key) + Vector3.DOWN * 0.4,
				"GESCHÜTZT!"
			)
			if result == "hit":
				stats.field_hits = int(stats.get("field_hits", 0)) + 1
				host.add_mod(key, "ember", FIELD_SLOW_SECONDS, FIELD_SLOW, 1.0, 1.0)
				entry.soot_key = key
				entry.soot_at = float(entry.field_age)
				if key == -1:
					host.say("Heiß! Durchs Glutfeld – kurz langsamer.")
					host.sound("ember_hiss", 1.1)


# --- Darstellung ---------------------------------------------------------------------------


func _ball_at(entry: Dictionary) -> Vector3:
	var age: float = float(entry.age)
	var drop: float = clampf((age - (LIFE - DROP)) / DROP, 0.0, 1.0)
	var lift: float = (
		lerpf(1.1, 0.25, drop * drop) + (0.0 if host.reduced_motion else sin(age * 9.0) * 0.06)
	)
	var at: Vector3 = host.track_global(float(entry.progress), float(entry.lateral), lift)
	if age < LAUNCH:
		var nose: Vector3 = (
			host.kart_centre(int(entry.owner))
			+ host.kart(int(entry.owner)).global_basis.z.normalized() * -1.3
		)
		at = nose.lerp(at, smoothstep(0.0, 1.0, age / LAUNCH))
	return at


func build_rig() -> Node3D:
	var rig := Node3D.new()
	rig.name = "FireMeteor"
	rig.top_level = true
	var ball := MeshInstance3D.new()
	ball.name = "Ball"
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	sphere.radial_segments = 16
	sphere.rings = 8
	ball.mesh = sphere
	ball.material_override = FX.solid(Color(1.0, 0.45, 0.12), Color(1.0, 0.42, 0.08), 3.2, 1.0, 0.6)
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(ball)
	for sprite_spec in [
		["Core", 1.3, Color(1.0, 0.92, 0.55, 0.95)], ["Halo", 2.8, Color(1.0, 0.45, 0.1, 0.55)]
	]:
		var glow_sprite: MeshInstance3D = FX.sprite(
			float(sprite_spec[1]), FX.glow(sprite_spec[2], true, FX.soft_dot())
		)
		glow_sprite.name = str(sprite_spec[0])
		rig.add_child(glow_sprite)
	var fire_recipe := {
		"amount": host.budget(44),
		"lifetime": 0.42,
		"size": 0.62,
		"spread": 14.0,
		"speed_min": 0.2,
		"speed_max": 1.0,
		"grow": 0.35,
		"sphere": 0.18,
		"colors":
		[
			Color(1, 0.95, 0.6, 1),
			Color(1, 0.6, 0.15, 0.9),
			Color(0.9, 0.2, 0.05, 0.5),
			Color(0.4, 0.1, 0.05, 0)
		],
	}
	var fire: CPUParticles3D = FX.emitter(fire_recipe)
	fire.name = "Fire"
	rig.add_child(fire)
	var smoke_recipe := {
		"amount": host.budget(26),
		"lifetime": 1.1,
		"size": 0.7,
		"spread": 25.0,
		"speed_min": 0.2,
		"speed_max": 0.8,
		"gravity": Vector3(0, 1.1, 0),
		"grow": 2.6,
		"additive": false,
		"sphere": 0.2,
		"colors":
		[Color(0.3, 0.27, 0.26, 0.0), Color(0.28, 0.25, 0.24, 0.6), Color(0.45, 0.43, 0.42, 0.0)],
	}
	var smoke: CPUParticles3D = FX.emitter(smoke_recipe)
	smoke.name = "Smoke"
	rig.add_child(smoke)
	var sparks_recipe := {
		"amount": host.budget(22),
		"lifetime": 0.5,
		"size": 0.1,
		"spread": 70.0,
		"speed_min": 1.5,
		"speed_max": 4.0,
		"gravity": Vector3(0, -6, 0),
		"colors": [Color(1, 0.95, 0.6, 1), Color(1, 0.6, 0.2, 0)],
	}
	var sparks: CPUParticles3D = FX.emitter(sparks_recipe)
	sparks.name = "Sparks"
	rig.add_child(sparks)
	var blast_recipe := {
		"amount": host.budget(46),
		"lifetime": 0.8,
		"size": 0.22,
		"one_shot": true,
		"explosiveness": 1.0,
		"spread": 180.0,
		"speed_min": 2.5,
		"speed_max": 7.0,
		"gravity": Vector3(0, -8, 0),
		"colors": [Color(1, 1, 0.8, 1), Color(1, 0.6, 0.15, 1), Color(0.8, 0.2, 0.05, 0)],
	}
	var blast: CPUParticles3D = FX.emitter(blast_recipe)
	blast.name = "Blast"
	rig.add_child(blast)
	var flash: MeshInstance3D = FX.sprite(
		3.4, FX.glow_unique(Color(1.0, 0.7, 0.3, 1.0), true, FX.soft_dot())
	)
	flash.name = "Flash"
	rig.add_child(flash)
	var soot_recipe := {
		"amount": host.budget(22),
		"lifetime": 1.1,
		"size": 0.85,
		"spread": 30.0,
		"speed_min": 0.6,
		"speed_max": 1.5,
		"gravity": Vector3(0, 1.4, 0),
		"box": Vector3(0.6, 0.2, 0.8),
		"additive": false,
		"grow": 2.4,
		"colors":
		[Color(0.12, 0.1, 0.1, 0.0), Color(0.15, 0.13, 0.13, 0.7), Color(0.35, 0.33, 0.33, 0.0)],
	}
	var soot: CPUParticles3D = FX.emitter(soot_recipe)
	soot.name = "Soot"
	rig.add_child(soot)
	var glow_disc: MeshInstance3D = FX.ground_disc(
		FIELD_RADIUS, FX.glow_unique(Color(1.0, 0.45, 0.1, 1.0), false, FX.soft_dot())
	)
	glow_disc.name = "FieldGlow"
	rig.add_child(glow_disc)
	var burn_material := StandardMaterial3D.new()
	burn_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	burn_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	burn_material.vertex_color_use_as_albedo = true
	burn_material.albedo_texture = FX.soft_dot()
	burn_material.albedo_color = Color(0.08, 0.06, 0.05, 0.75)
	var burn: MeshInstance3D = FX.ground_disc(FIELD_RADIUS * 1.25, burn_material)
	burn.name = "Burn"
	rig.add_child(burn)
	var embers_recipe := {
		"amount": host.budget(30),
		"lifetime": 0.9,
		"size": 0.13,
		"direction": Vector3.UP,
		"spread": 20.0,
		"speed_min": 0.6,
		"speed_max": 2.0,
		"gravity": Vector3(0, 0.3, 0),
		"box": Vector3(1.1, 0.02, 1.1),
		"colors": [Color(1, 0.9, 0.5, 1), Color(1, 0.45, 0.1, 0.9), Color(0.6, 0.1, 0.0, 0)],
	}
	var embers: CPUParticles3D = FX.emitter(embers_recipe)
	embers.name = "Embers"
	rig.add_child(embers)
	return rig


func reset_rig(rig: Node3D, entry: Dictionary) -> void:
	for node_name in ["Ball", "Core", "Halo", "Flash", "FieldGlow", "Burn"]:
		(rig.get_node(node_name) as Node3D).visible = false
	for emitter_name in ["Fire", "Smoke", "Sparks", "Soot", "Embers"]:
		(rig.get_node(emitter_name) as CPUParticles3D).emitting = false
	rig.set_meta("blasted", false)
	rig.set_meta("smoke_on", false)
	rig.set_meta("soot_on", -1.0)
	if str(entry.get("phase", "")) == "fly":
		var start: Vector3 = _ball_at(entry)
		for emitter_name in ["Fire", "Smoke", "Sparks"]:
			(rig.get_node(emitter_name) as Node3D).global_position = start


func _draw(entry: Dictionary, rig: Node3D) -> void:
	var phase: String = str(entry.phase)
	var reduced: bool = host.reduced_motion
	var ball: MeshInstance3D = rig.get_node("Ball")
	var flying: bool = phase == "fly"
	for node_name in ["Ball", "Core", "Halo"]:
		(rig.get_node(node_name) as Node3D).visible = flying
	for emitter_name in ["Fire", "Sparks"]:
		(rig.get_node(emitter_name) as CPUParticles3D).emitting = flying
	var smoke: CPUParticles3D = rig.get_node("Smoke")
	if flying:
		var at: Vector3 = _ball_at(entry)
		for node_name in ["Ball", "Core", "Halo", "Fire", "Smoke", "Sparks"]:
			(rig.get_node(node_name) as Node3D).global_position = at
		if not reduced:
			ball.rotate_object_local(Vector3.RIGHT, 0.4)
			(rig.get_node("Halo") as Node3D).scale = (
				Vector3.ONE * (0.9 + 0.12 * sin(float(entry.age) * 23.0))
			)
		var direction: Vector3 = host.track_basis(float(entry.progress)).z.normalized()
		(rig.get_node("Fire") as CPUParticles3D).direction = direction
		smoke.direction = direction
		if not bool(rig.get_meta("smoke_on", false)) and host.quality != "low":
			# Rauch (Alpha) erst am Abschusspunkt starten: keine Schwarzscheibe im Kompatibilitäts-Renderer.
			rig.set_meta("smoke_on", true)
			smoke.restart()
			smoke.emitting = true
		return
	smoke.emitting = false
	var since: float = float(entry.age) - float(entry.get("hit_at", entry.age))
	var flash: MeshInstance3D = rig.get_node("Flash")
	if phase == "done":
		var key: int = int(entry.target)
		var where: Vector3 = (
			host.kart_centre(key)
			if host._valid_key(key) and str(entry.result) != "fizzled"
			else host.track_global(float(entry.progress), float(entry.lateral), 0.4)
		)
		if str(entry.result) == "blocked":
			var from: Vector3 = host.track_global(
				float(entry.progress) - 2.0, float(entry.lateral), 1.1
			)
			where = where + (from - where).normalized() * 1.4
		if not bool(rig.get_meta("blasted", false)):
			rig.set_meta("blasted", true)
			FX.burst(rig.get_node("Blast"), where, Vector3.UP)
		flash.visible = since < 0.25
		if flash.visible:
			flash.global_position = where
			flash.scale = (
				Vector3.ONE * (0.5 + 1.2 * (1.0 - since / 0.25)) * (0.6 if reduced else 1.0)
			)
			(flash.material_override as StandardMaterial3D).albedo_color.a = 1.0 - since / 0.25
		_soot(rig, key if str(entry.result) == "hit" else -99, since)
		return
	# Glutfeld: liegt fest auf der Fahrbahn und glüht aus.
	var life: float = float(entry.field_age) / FIELD_SECONDS
	if not bool(rig.get_meta("blasted", false)):
		rig.set_meta("blasted", true)
		FX.burst(
			rig.get_node("Blast"),
			host.track_global(float(entry.progress), float(entry.lateral), 0.3),
			Vector3.UP
		)
	flash.visible = float(entry.field_age) < 0.22
	if flash.visible:
		flash.global_position = host.track_global(float(entry.progress), float(entry.lateral), 0.4)
		(flash.material_override as StandardMaterial3D).albedo_color.a = (
			1.0 - float(entry.field_age) / 0.22
		)
	var ground := Transform3D(
		host.track_basis(float(entry.progress)),
		host.track_global(float(entry.progress), float(entry.lateral), 0.04)
	)
	var glow_disc: MeshInstance3D = rig.get_node("FieldGlow")
	var burn: MeshInstance3D = rig.get_node("Burn")
	glow_disc.visible = true
	burn.visible = true
	glow_disc.global_transform = ground.translated_local(Vector3.UP * 0.01)
	burn.global_transform = ground
	var heat: float = 1.0 - smoothstep(0.15, 1.0, life)
	var flicker: float = (
		1.0
		if reduced
		else 0.85 + 0.15 * sin(float(entry.field_age) * 17.0) * sin(float(entry.field_age) * 7.0)
	)
	var colour: Color = Color(1.0, 0.75, 0.25).lerp(
		Color(0.85, 0.15, 0.05), smoothstep(0.0, 0.7, life)
	)
	colour.a = heat * flicker
	(glow_disc.material_override as StandardMaterial3D).albedo_color = colour
	glow_disc.scale = Vector3.ONE * lerpf(1.0, 0.75, life)
	(burn.material_override as StandardMaterial3D).albedo_color.a = (
		0.75 * (1.0 - smoothstep(0.75, 1.0, life))
	)
	var embers: CPUParticles3D = rig.get_node("Embers")
	embers.emitting = life < 0.8
	embers.global_transform = ground
	if entry.has("soot_key"):
		_soot(rig, int(entry.soot_key), float(entry.field_age) - float(entry.soot_at))
	else:
		_soot(rig, -99, 9.0)


func _soot(rig: Node3D, key: int, since: float) -> void:
	var soot: CPUParticles3D = rig.get_node("Soot")
	var on: bool = key != -99 and host._valid_key(key) and since < 1.0
	if on:
		var kart: Node3D = host.kart(key)
		soot.global_transform = Transform3D(
			kart.global_basis.orthonormalized(), host.kart_centre(key)
		)
		if float(rig.get_meta("soot_on", -1.0)) < 0.0:
			rig.set_meta("soot_on", 1.0)
			soot.restart()
	soot.emitting = on
