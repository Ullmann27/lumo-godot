extends "res://scripts/games/kart_items/ext/kart_item_ext_effect.gd"
## ZEITBLÜTE – eine Lichtblüte öffnet sich ein Stück voraus auf der Fahrbahn; in ihrem
## begrenzten Zeitfeld fahren Gegner langsamer. Das Spiel und alle Karts außerhalb laufen normal.
##   0.00–0.45 s  AUSLÖSER  Same fliegt im Bogen vom eigenen Kart nach vorn: 12 m vor den nächsten
##                          Gegner (bis 50 m), sonst 18 m voraus.
##   0.45–1.05 s  ÖFFNEN    zwölf Blütenblätter falten sich auf (Feld Ø 9 m), Zifferblatt-Ring.
##   1.05–5.5 s   WIRKEN    Feld liegt fest; Gegner darin: Tempo 55 %, sichtbarer Zeitring am
##                          Kart, Lichtpollen schweben langsam. Eigenes Kart: nicht betroffen.
##   5.5–6.2 s    ABKLINGEN Blätter schließen sich und sinken, Ring erlischt.
## Platzierung: nur auf sicherer Fahrbahn (kein Brückendeck, keine Kante, Rampe, Passagen-Zone)
## und nicht über einer Checkpoint-Grenze (±8 m); sonst wird bis 40 m weiter gesucht, sonst
## bleibt das Item im Knopf. Schild: geschützte Karts fahren unbeeinflusst durch. Schonzeit:
## wer sie beim Eintritt hat, bleibt unbeeinflusst; der Eintritt selbst setzt sie.

const FX = preload("res://scripts/games/kart_items/ext/kart_item_ext_fx.gd")
const AHEAD: float = 18.0
const TARGET_LEAD: float = 12.0
const THROW: float = 0.45
const OPEN: float = 0.6
const ACTIVE_END: float = 5.5
const CLOSE: float = 0.7
const RADIUS: float = 4.5
const SLOW: float = 0.55
const PETALS: int = 12
const TEAL := Color(0.45, 1.0, 0.85)
const ROSE := Color(1.0, 0.6, 0.85)


func _init() -> void:
	pool_cap = 3
	rear_warning = false


func _placement(owner: int) -> float:
	var length: float = host.track_length()
	var spacing: float = length / 8.0
	# Vor den nächsten Gegner (er fährt hinein), sonst 18 m vor das eigene Kart.
	var target: int = host.pick_target(owner, 50.0, 0.0)
	var start: float = host.progress(owner) + AHEAD
	if target != -99:
		start = maxf(start, host.progress(target) + TARGET_LEAD)
	var d: float = 0.0
	while d <= 40.0:
		var at: float = start + d
		var local: float = fposmod(at, length)
		var to_gate: float = absf(local - round(local / spacing) * spacing)
		if to_gate > 8.0 + RADIUS and host.safe_at(at):
			return at
		d += 4.0
	return INF


func use(owner: int, item_id: String, _row: Dictionary) -> bool:
	var at: float = _placement(owner)
	if at == INF:
		if owner == -1:
			host.say("Zeitblüte wartet: vorn ist es zu eng oder ein Kontrollpunkt.")
		return false
	(
		active
		. append(
			{
				"owner": owner,
				"item": item_id,
				"age": 0.0,
				"progress": at,
				"lateral": 0.0,
				"from_p": host.progress(owner),
				"from_l": host.lateral(owner),
				"inside": {},
				"affected": [],
			}
		)
	)
	if owner == -1:
		host.say("Zeitblüte! Gegner darin fahren wie in Zeitlupe.")
		host.sound("bloom_open")
	else:
		if host.progress(-1) < at and at - host.progress(-1) < 60.0:
			host.warn_player("Achtung: Zeitblüte vor dir – außen vorbei!")
		elif host.eye().distance_to(host.kart_centre(owner)) < 45.0:
			host.sound("bloom_open", 1.1)
	return true


func rival_wants(index: int, _item_id: String, context: Dictionary) -> bool:
	var ahead: float = float(context.get("ahead_gap", INF))
	return ahead > 10.0 and ahead < 30.0 and _placement(index) != INF


func _active(entry: Dictionary) -> bool:
	var age: float = float(entry.age)
	return age >= THROW + OPEN * 0.5 and age < ACTIVE_END


func _inside(entry: Dictionary, key: int) -> bool:
	return (
		absf(host.progress(key) - float(entry.progress)) <= RADIUS
		and absf(host.lateral(key) - float(entry.lateral)) <= RADIUS
	)


func incoming(key: int) -> float:
	var best: float = INF
	for entry in active:
		if int(entry.owner) == key or float(entry.age) >= ACTIVE_END:
			continue
		var gap: float = float(entry.progress) - RADIUS - host.progress(key)
		if gap > 0.0 and gap < 40.0:
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


## KI: außen am Feld vorbei (nur seitlich ausweichen, nie bremsen).
func lane_bias(index: int) -> float:
	for entry in active:
		if int(entry.owner) == index or float(entry.age) >= ACTIVE_END:
			continue
		var gap: float = float(entry.progress) - host.progress(index)
		if gap > -RADIUS and gap < 30.0:
			var side: float = host.lateral(index) - float(entry.lateral)
			return 2.0 * (signf(side) if absf(side) > 0.2 else 1.0)
	return 0.0


func _valid_saved(entry: Dictionary) -> bool:
	return super._valid_saved(entry) and entry.has("progress") and host._valid_key(int(entry.owner))


func restore(data: Variant) -> void:
	super.restore(data)
	for entry in active:
		if not entry.get("inside") is Dictionary:
			entry.inside = {}
		if not entry.get("affected") is Array:
			entry.affected = []


func tick(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for entry in active:
		entry.age = float(entry.age) + delta
		if _active(entry):
			_field(entry)
		if float(entry.age) > ACTIVE_END + CLOSE:
			release(entry)
			continue
		var rig: Node3D = acquire(entry)
		if rig != null:
			_draw(entry, rig)
		keep.append(entry)
	active = keep


func _field(entry: Dictionary) -> void:
	for key in host.racer_keys():
		if key == int(entry.owner):
			continue
		var inside: bool = _inside(entry, key)
		var was: bool = bool(entry.inside.get(str(key), false))
		entry.inside[str(key)] = inside
		if inside and not was:
			# Eintritt: Schild/Schonzeit prüfen, dann gilt das ganze Durchfahren als ein Treffer.
			var result: String = host.resolve(
				key, int(entry.owner), str(entry.item), host.kart_centre(key), "GESCHÜTZT!"
			)
			if result == "hit":
				entry.affected.append(key)
				stats.hits += 1
				if key == -1:
					host.say("In der Zeitblüte – alles langsam! Gleich vorbei.")
				if host.involves_player(int(entry.owner), key):
					host.sound("bloom_slow")
			elif result == "blocked":
				stats.blocked += 1
			else:
				stats.grace += 1
		if inside and key in entry.affected:
			host.add_mod(key, "bloom", 0.35, SLOW, 0.85, 1.0)


func build_rig() -> Node3D:
	var rig := Node3D.new()
	rig.name = "TimeBloom"
	rig.top_level = true
	var seed_sprite: MeshInstance3D = FX.sprite(
		1.2, FX.glow(Color(0.7, 1.0, 0.9, 1.0), true, FX.soft_dot())
	)
	seed_sprite.name = "Seed"
	rig.add_child(seed_sprite)
	var disc: MeshInstance3D = FX.ground_disc(
		RADIUS, FX.glow_unique(Color(0.3, 0.9, 0.8, 0.55), false, FX.soft_dot())
	)
	disc.name = "Disc"
	rig.add_child(disc)
	var petal_material := StandardMaterial3D.new()
	petal_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	petal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	petal_material.vertex_color_use_as_albedo = true
	petal_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for line_name in ["Petals", "Rings", "Clock"]:
		var line := MeshInstance3D.new()
		line.name = line_name
		line.mesh = ImmediateMesh.new()
		line.material_override = petal_material
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.add_child(line)
	var pollen_recipe := {
		"amount": host.budget(40),
		"lifetime": 3.0,
		"size": 0.16,
		"direction": Vector3.UP,
		"spread": 40.0,
		"speed_min": 0.1,
		"speed_max": 0.35,
		"box": Vector3(RADIUS * 0.8, 0.2, RADIUS * 0.8),
		"colors": [Color(1, 1, 0.9, 0), Color(0.6, 1.0, 0.9, 1), Color(1.0, 0.7, 0.9, 0)],
	}
	var pollen: CPUParticles3D = FX.emitter(pollen_recipe)
	pollen.name = "Pollen"
	rig.add_child(pollen)
	return rig


func reset_rig(rig: Node3D, _entry: Dictionary) -> void:
	(rig.get_node("Pollen") as CPUParticles3D).emitting = false


func _draw(entry: Dictionary, rig: Node3D) -> void:
	var reduced: bool = host.reduced_motion
	var age: float = float(entry.age)
	var p: float = float(entry.progress)
	var basis: Basis = host.track_basis(p)
	var up: Vector3 = basis.y.normalized()
	var centre: Vector3 = host.track_global(p, float(entry.lateral), 0.06)
	var seed_sprite: MeshInstance3D = rig.get_node("Seed")
	seed_sprite.visible = age < THROW
	if seed_sprite.visible:
		var s: float = smoothstep(0.0, 1.0, age / THROW)
		var from: Vector3 = host.track_global(float(entry.from_p), float(entry.from_l), 1.4)
		seed_sprite.global_position = from.lerp(centre, s) + up * sin(PI * s) * 2.2
	var open: float = clampf((age - THROW) / OPEN, 0.0, 1.0)
	var close: float = clampf((age - ACTIVE_END) / CLOSE, 0.0, 1.0)
	var bloom: float = smoothstep(0.0, 1.0, open) * (1.0 - smoothstep(0.0, 1.0, close))
	var disc: MeshInstance3D = rig.get_node("Disc")
	disc.visible = bloom > 0.0
	disc.global_transform = Transform3D(basis.scaled(Vector3.ONE * maxf(0.05, bloom)), centre)
	(disc.material_override as StandardMaterial3D).albedo_color.a = 0.55 * bloom
	var pollen: CPUParticles3D = rig.get_node("Pollen")
	pollen.global_transform = Transform3D(basis, centre)
	pollen.emitting = bloom > 0.5 and host.quality != "low"
	var petals_mesh: ImmediateMesh = (rig.get_node("Petals") as MeshInstance3D).mesh
	var rings_mesh: ImmediateMesh = (rig.get_node("Rings") as MeshInstance3D).mesh
	if bloom <= 0.0:
		petals_mesh.clear_surfaces()
		rings_mesh.clear_surfaces()
		return
	# Blütenblätter: zwölf Bögen, die sich vom Zentrum nach außen auffalten.
	var spin: float = 0.0 if reduced else age * 0.35
	var petals: Array = []
	var right: Vector3 = basis.x.normalized()
	var fwd: Vector3 = -basis.z.normalized()
	for k in range(PETALS):
		var a: float = TAU * float(k) / PETALS + spin
		var direction: Vector3 = (right * cos(a) + fwd * sin(a)).normalized()
		var tip: Vector3 = (
			centre + direction * RADIUS * 0.95 * bloom + up * (0.35 * (1.0 - open) + 0.25 * bloom)
		)
		var mid: Vector3 = centre + direction * RADIUS * 0.55 * bloom + up * (1.3 * bloom + 0.05)
		var colour: Color = TEAL.lerp(ROSE, float(k % 3) / 2.0)
		colour.a = 0.75 * bloom
		petals.append(
			{
				"points": PackedVector3Array([centre + up * 0.08, mid, tip]),
				"width": 1.0,
				"color": colour
			}
		)
	FX.ribbons(petals_mesh, petals, centre + up * 1000.0, 1.25, TEAL, Transform3D.IDENTITY)
	# Zifferblatt: Feldrand + langsam laufender Zeiger; Zeitringe an verlangsamten Karts.
	var rings: Array = []
	var edge := PackedVector3Array()
	for k in range(41):
		var a: float = TAU * k / 40.0
		edge.append(centre + (right * cos(a) + fwd * sin(a)) * RADIUS * bloom + up * 0.08)
	rings.append({"points": edge, "width": 1.0, "color": Color(0.2, 0.75, 0.7, 0.9 * bloom)})
	var hand_angle: float = 0.0 if reduced else -age * 0.9
	var hand: Vector3 = (right * cos(hand_angle) + fwd * sin(hand_angle)) * RADIUS * 0.85 * bloom
	rings.append(
		{
			"points": PackedVector3Array([centre + up * 0.1, centre + hand + up * 0.1]),
			"width": 1.6,
			"color": Color(1.0, 0.95, 0.75, 0.9 * bloom)
		}
	)
	for key in entry.affected:
		if _inside(entry, int(key)) and host._valid_key(int(key)):
			var at: Vector3 = host.kart_centre(int(key)) + up * 0.9
			var halo := PackedVector3Array()
			for k in range(25):
				var a: float = TAU * k / 24.0 + (0.0 if reduced else age * 1.5)
				halo.append(at + (right * cos(a) + fwd * sin(a)) * 1.25)
			rings.append({"points": halo, "width": 1.0, "color": Color(0.95, 0.45, 0.75, 0.9)})
	FX.ribbons(rings_mesh, rings, centre + up * 1000.0, 0.16, TEAL, Transform3D.IDENTITY)
	_draw_clock(rig, centre + up * (2.2 + 0.6 * bloom), right, up, bloom, age)


## Stehendes Zifferblatt über dem Feld (von weitem lesbar): Ring, zwölf Marken, laufender Zeiger.
func _draw_clock(
	rig: Node3D, at: Vector3, right: Vector3, up: Vector3, bloom: float, age: float
) -> void:
	var mesh: ImmediateMesh = (rig.get_node("Clock") as MeshInstance3D).mesh
	if bloom <= 0.0:
		mesh.clear_surfaces()
		return
	var radius: float = 1.3 * bloom
	var lines: Array = []
	var rim := PackedVector3Array()
	for k in range(41):
		var a: float = TAU * k / 40.0
		rim.append(at + (right * cos(a) + up * sin(a)) * radius)
	lines.append({"points": rim, "width": 1.6, "color": Color(0.2, 0.75, 0.7, 0.9 * bloom)})
	for k in range(12):
		var a: float = TAU * k / 12.0
		var d: Vector3 = right * cos(a) + up * sin(a)
		lines.append(
			{
				"points": PackedVector3Array([at + d * radius * 0.78, at + d * radius * 0.95]),
				"width": 1.0,
				"color": Color(1.0, 0.55, 0.8, 0.9 * bloom)
			}
		)
	var hand: float = PI * 0.5 - (0.0 if host.reduced_motion else age * 0.9)
	lines.append(
		{
			"points":
			PackedVector3Array([at, at + (right * cos(hand) + up * sin(hand)) * radius * 0.8]),
			"width": 1.4,
			"color": Color(0.95, 0.85, 0.4, bloom)
		}
	)
	FX.ribbons(mesh, lines, host.eye(), 0.12, TEAL, Transform3D.IDENTITY)
