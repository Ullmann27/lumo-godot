extends "res://scripts/games/kart_items/ext/kart_item_ext_effect.gd"
## SCHWERKRAFT-WELLE – eine räumliche Energiewelle läuft vom eigenen Kart ringförmig nach
## außen und hebt nahe Gegner kurz an; sie landen von selbst sicher und sind kurz langsamer.
##   0.00–0.20 s  AUSLÖSER  Kart drückt sich in den Boden, Hologramm-Gitter blitzt unter ihm auf.
##   0.20–0.75 s  WEG       drei Verzerrungsringe laufen bis 13 m nach außen; der Mittelpunkt
##                          fährt mit dem Kart (Ring folgt der Fahrbahnebene).
##   Wellenkamm   EINSCHLAG erreicht der Kamm einen Gegner (Abstand ≤ Kammradius): Treffer.
##   +0–0,9 s     REAKTION  Kart schwebt bis 1,2 m hoch (reine Anzeige, die Fahrposition bleibt
##                          auf der Fahrbahn → automatisch sichere Landung), Hologramm-Säule;
##                          Tempo 72 % für 1,1 s.
##   +0,9–1,3 s   ABKLINGEN Landung mit kleinem Staubring, Teilchen sinken.
## Schild wehrt ab (Welle bricht an der Kuppel), Schonzeit gilt, Rivalen in der Luft (Sprung)
## werden nicht angehoben. KI nutzt sie, wenn Gegner nah sind; KI mit Schild hebt ihn.

const FX = preload("res://scripts/games/kart_items/ext/kart_item_ext_fx.gd")
const CHARGE: float = 0.2
const TRAVEL: float = 0.55
const RADIUS: float = 13.0
const LIFT_TIME: float = 0.9
const LIFT: float = 1.2
const SLOW: float = 0.72
const SLOW_SECONDS: float = 1.1
const END: float = CHARGE + TRAVEL + LIFT_TIME + 0.5
const CYAN := Color(0.45, 0.9, 1.0)
const VIOLET := Color(0.7, 0.5, 1.0)


func _init() -> void:
	pool_cap = 3


func use(owner: int, item_id: String, _row: Dictionary) -> bool:
	active.append(
		{
			"owner": owner,
			"item": item_id,
			"age": 0.0,
			"progress": host.progress(owner),
			"lateral": host.lateral(owner),
			"hits": {}
		}
	)
	if owner == -1:
		host.say("Schwerkraft-Welle! Wer nah ist, hebt kurz ab.")
		host.sound("gravity_wave")
	else:
		if _distance(owner, -1) < RADIUS + 4.0:
			host.warn_player("Achtung: Schwerkraft-Welle – Abstand oder Schild!")
		elif host.eye().distance_to(host.kart_centre(owner)) < 45.0:
			host.sound("gravity_wave", 1.1)
	return true


func rival_wants(index: int, _item_id: String, _context: Dictionary) -> bool:
	var near: int = 0
	for key in host.racer_keys():
		if (
			key != index
			and _distance(index, key) < RADIUS * 0.8
			and not host.protected(key)
			and not host.in_grace(key)
		):
			if key == -1 and not host.child_attackable(index):
				continue
			near += 1
	return near >= 1


func _distance(a: int, b: int) -> float:
	var ka: Node3D = host.kart(a)
	var kb: Node3D = host.kart(b)
	if not is_instance_valid(ka) or not is_instance_valid(kb):
		return INF
	return ka.global_position.distance_to(kb.global_position)


func _front(entry: Dictionary) -> float:
	return RADIUS * smoothstep(0.0, 1.0, clampf((float(entry.age) - CHARGE) / TRAVEL, 0.0, 1.0))


## Die Welle geht vom fahrenden Kart aus: ihr Mittelpunkt fährt mit (sonst liefen alle
## Gegner, die mit gleichem Tempo vorn fahren, der Welle davon).
func _centre(entry: Dictionary) -> Vector3:
	var owner: int = int(entry.owner)
	if host._valid_key(owner):
		entry.progress = host.progress(owner)
		entry.lateral = host.lateral(owner)
	return host.track_global(float(entry.progress), float(entry.lateral), 0.0)


func incoming(key: int) -> float:
	var best: float = INF
	for entry in active:
		if (
			int(entry.owner) == key
			or entry.hits.has(str(key))
			or float(entry.age) > CHARGE + TRAVEL
		):
			continue
		var reach: float = host.kart_centre(key).distance_to(_centre(entry))
		if reach <= RADIUS:
			best = minf(best, maxf(0.0, CHARGE + TRAVEL * reach / RADIUS - float(entry.age)))
	return best


func _valid_saved(entry: Dictionary) -> bool:
	return super._valid_saved(entry) and entry.has("progress") and host._valid_key(int(entry.owner))


func restore(data: Variant) -> void:
	super.restore(data)
	for entry in active:
		if not entry.get("hits") is Dictionary:
			entry.hits = {}


func tick(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for entry in active:
		entry.age = float(entry.age) + delta
		if float(entry.age) <= CHARGE + TRAVEL + 0.05:
			_sweep(entry)
		if float(entry.age) > END:
			release(entry)
			continue
		var rig: Node3D = acquire(entry)
		if rig != null:
			_draw(entry, rig)
		keep.append(entry)
	active = keep


func _sweep(entry: Dictionary) -> void:
	var front: float = _front(entry)
	var centre: Vector3 = _centre(entry)
	for key in host.racer_keys():
		if key == int(entry.owner) or entry.hits.has(str(key)):
			continue
		if host.kart_centre(key).distance_to(centre) > front or front <= 0.0:
			continue
		if host.airborne(key):
			entry.hits[str(key)] = {"result": "air", "at": float(entry.age)}
			continue
		var result: String = host.resolve(
			key, int(entry.owner), str(entry.item), host.kart_centre(key)
		)
		entry.hits[str(key)] = {"result": result, "at": float(entry.age)}
		match result:
			"hit":
				stats.hits += 1
				host.add_mod(key, "gravity", SLOW_SECONDS, SLOW, 0.8, 1.0)
				if key == -1:
					host.say("Schwerelos! Gleich landest du wieder sicher.")
			"blocked":
				stats.blocked += 1
			_:
				stats.grace += 1


## Anzeige-Anhebung eines Karts (Meter), 0 = am Boden. Die Fahrposition ändert sich nie.
func lift_for(key: int) -> float:
	var best: float = 0.0
	for entry in active:
		var hit: Variant = entry.hits.get(str(key))
		if not hit is Dictionary or str(hit.result) != "hit":
			continue
		var t: float = (float(entry.age) - float(hit.at)) / LIFT_TIME
		if t >= 0.0 and t <= 1.0:
			best = maxf(best, sin(PI * t) * LIFT * (0.35 if host.reduced_motion else 1.0))
	return best


func build_rig() -> Node3D:
	var rig := Node3D.new()
	rig.name = "GravityWave"
	rig.top_level = true
	for line_name in ["Rings", "Columns"]:
		var line := MeshInstance3D.new()
		line.name = line_name
		line.mesh = ImmediateMesh.new()
		line.material_override = FX.glow(Color.WHITE)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.add_child(line)
	var grid: MeshInstance3D = FX.ground_disc(
		2.2, FX.glow_unique(Color(0.5, 0.85, 1.0, 1.0), false, FX.soft_ring())
	)
	grid.name = "Pulse"
	rig.add_child(grid)
	var holo_recipe := {
		"amount": host.budget(48),
		"lifetime": 0.9,
		"size": 0.14,
		"direction": Vector3.UP,
		"spread": 20.0,
		"speed_min": 0.8,
		"speed_max": 2.4,
		"box": Vector3(0.9, 0.1, 1.0),
		"colors": [Color(0.7, 1.0, 1.0, 1), Color(0.6, 0.6, 1.0, 0.8), Color(0.8, 0.5, 1.0, 0)],
	}
	for k in range(3):
		var holo: CPUParticles3D = FX.emitter(holo_recipe)
		holo.name = "Holo%d" % k
		rig.add_child(holo)
	return rig


func reset_rig(rig: Node3D, _entry: Dictionary) -> void:
	for k in range(3):
		(rig.get_node("Holo%d" % k) as CPUParticles3D).emitting = false


func _draw(entry: Dictionary, rig: Node3D) -> void:
	var reduced: bool = host.reduced_motion
	var age: float = float(entry.age)
	var centre: Vector3 = _centre(entry)
	var basis: Basis = host.track_basis(float(entry.progress))
	var up: Vector3 = basis.y.normalized()
	var right: Vector3 = basis.x.normalized()
	var fwd: Vector3 = -basis.z.normalized()
	var pulse: MeshInstance3D = rig.get_node("Pulse")
	pulse.visible = age < CHARGE + 0.25
	if pulse.visible:
		var t: float = age / (CHARGE + 0.25)
		pulse.global_transform = Transform3D(
			basis.scaled(Vector3.ONE * (0.5 + 1.2 * t)), centre + up * 0.06
		)
		(pulse.material_override as StandardMaterial3D).albedo_color.a = 1.0 - t
	# Verzerrungsringe: drei Kämme hintereinander, wellig (Raum „verbiegt“ sich).
	var front: float = _front(entry)
	var fade: float = 1.0 - clampf((age - CHARGE - TRAVEL) / 0.35, 0.0, 1.0)
	var rings: Array = []
	if front > 0.0 and fade > 0.0:
		for r in range(3):
			var radius: float = front - float(r) * 1.1
			if radius <= 0.2:
				continue
			# Ring vor und neben dem Kart; das Stück hinter ihm (durch die Kamera) bleibt weg.
			var points := PackedVector3Array()
			for k in range(37):
				var a: float = lerpf(-0.35 * PI, 1.35 * PI, float(k) / 36.0)
				var wobble: float = 0.0 if reduced else sin(a * 6.0 + age * 14.0) * 0.12
				points.append(
					(
						centre
						+ (right * cos(a) + fwd * sin(a)) * (radius + wobble)
						+ up * (0.25 + 0.35 * float(r) + wobble)
					)
				)
			var colour: Color = CYAN.lerp(VIOLET, float(r) / 2.0)
			colour.a = (0.95 - 0.25 * float(r)) * fade
			rings.append({"points": points, "width": 1.0 - 0.2 * float(r), "color": colour})
	FX.ribbons(
		(rig.get_node("Rings") as MeshInstance3D).mesh,
		rings,
		host.eye(),
		0.22,
		CYAN,
		Transform3D.IDENTITY
	)
	# Hologramm-Säulen an angehobenen Karts.
	var columns: Array = []
	var holo_index: int = 0
	for key_text in entry.hits:
		var hit: Dictionary = entry.hits[key_text]
		var key: int = int(key_text)
		var since: float = age - float(hit.at)
		var holo_on: bool = str(hit.result) == "hit" and since < LIFT_TIME and holo_index < 3
		if holo_on:
			var kart: Node3D = host.kart(key)
			var holo: CPUParticles3D = rig.get_node("Holo%d" % holo_index)
			if not holo.emitting:
				holo.global_transform = Transform3D(
					kart.global_basis.orthonormalized(), kart.global_position
				)
				holo.restart()
			holo.global_transform = Transform3D(
				kart.global_basis.orthonormalized(), kart.global_position
			)
			holo.emitting = host.quality != "low"
			holo_index += 1
			var lift: float = lift_for(key)
			for k in range(4):
				var a: float = TAU * k / 4.0 + (0.0 if reduced else age * 2.0)
				var foot: Vector3 = kart.global_position + (right * cos(a) + fwd * sin(a)) * 1.1
				columns.append(
					{
						"points": PackedVector3Array([foot, foot + up * (lift + 1.4)]),
						"width": 1.0,
						"color": Color(0.6, 0.9, 1.0, 0.6 * (1.0 - since / LIFT_TIME))
					}
				)
	for k in range(holo_index, 3):
		(rig.get_node("Holo%d" % k) as CPUParticles3D).emitting = false
	FX.ribbons(
		(rig.get_node("Columns") as MeshInstance3D).mesh,
		columns,
		host.eye(),
		0.07,
		CYAN,
		Transform3D.IDENTITY
	)
