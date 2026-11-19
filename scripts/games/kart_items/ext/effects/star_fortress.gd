extends "res://scripts/games/kart_items/ext/kart_item_ext_effect.gd"
## STERNENFESTUNG – besondere Form des Sternenschilds: 12 s statt 6 s Schutz.
## Darstellung: innen die vorhandene cyanfarbene Schildkuppel (läuft über dieselbe Schilduhr),
## außen eine zweite, goldene Kuppel; am Boden ein runder Restzeit-Ring (gold -> cyan) mit
## zwölf Sekunden-Marken, die nacheinander erlöschen.
##   0.00–0.45 s  AUFBAU    goldene Kuppel wächst vom Boden hoch, Sternfunken steigen auf.
##   0.45–10 s    SCHUTZ    Doppelkuppel, Ring läuft ab; Treffer erzeugen Wellen an beiden Kuppeln.
##   10–12 s      ENDE NAHT Ring und Kuppel atmen langsam (0,8 Hz, kein Blinken).
##   12–12.6 s    ABBAU     Kuppel sinkt, Ring erlischt, kleiner Funkenregen.
## Regeln (Verhältnis zum Sternenschild):
##  - Obergrenze 12 s: erneutes Einsammeln frischt auf 12 s auf, addiert nie (kein Dauerschutz).
##  - Die Festung hält die normale Schilduhr mindestens auf ihrer Restzeit; ein Sternenschild
##    während der Festung verlängert nicht und verkürzt nicht.
##  - Ein Sternenschild ohne Festung bleibt 6 s; die Festung ersetzt ihn durch 12 s.

const FX = preload("res://scripts/games/kart_items/ext/kart_item_ext_fx.gd")
const SHIELD_DOME = preload("res://scripts/games/kart_items/kart_shield_dome.gd")
const CAP: float = 12.0
const SINK: float = 0.6
const RING_RADIUS: float = 1.85
const GOLD := Color(1.0, 0.8, 0.25)
const CYAN := Color(0.4, 0.92, 1.0)


func _init() -> void:
	pool_cap = 6


func use(owner: int, item_id: String, row: Dictionary) -> bool:
	var seconds: float = minf(CAP, float(row.get("seconds", CAP)))
	var entry: Dictionary = _entry_for(owner)
	if entry.is_empty():
		entry = {"owner": owner, "item": item_id, "age": 0.0, "left": seconds}
		active.append(entry)
	else:
		# Auffrischen auf höchstens 12 s – nie addieren.
		entry.left = maxf(float(entry.left), seconds)
		stats.refreshed = int(stats.get("refreshed", 0)) + 1
	_hold_shield(owner, float(entry.left))
	if owner == -1:
		host.say("Sternenfestung! Zwölf Sekunden doppelt geschützt.")
		host.sound("fortress_up")
	elif host.eye().distance_to(host.kart_centre(owner)) < 40.0:
		host.sound("fortress_up", 1.1)
	return true


func rival_wants(index: int, _item_id: String, context: Dictionary) -> bool:
	if bool(context.get("threatened", false)) or host.incoming_for(index) < 1.6:
		return true
	if float(context.get("player_near", INF)) < 8.0:
		return true
	return int(context.get("place", 6)) <= 2 and float(context.get("behind_gap", INF)) < 14.0


func _entry_for(key: int) -> Dictionary:
	for entry in active:
		if int(entry.owner) == key:
			return entry
	return {}


func left_for(key: int) -> float:
	var entry: Dictionary = _entry_for(key)
	return maxf(0.0, float(entry.left)) if not entry.is_empty() else 0.0


func total_for(key: int) -> float:
	return CAP if left_for(key) > 0.0 else 6.0


func _hold_shield(key: int, seconds: float) -> void:
	if seconds <= 0.0:
		return
	if key == -1:
		host.race.shield_time = maxf(float(host.race.shield_time), seconds)
	elif key < host.race.opponent_shield_times.size():
		host.race.opponent_shield_times[key] = maxf(
			float(host.race.opponent_shield_times[key]), seconds
		)


func _valid_saved(entry: Dictionary) -> bool:
	return (
		super._valid_saved(entry)
		and entry.has("left")
		and host._valid_key(int(entry.owner))
		and float(entry.left) <= CAP
	)


## Treffer auf die Festung: Welle auch an der goldenen Außenkuppel.
func on_blocked(key: int, at: Vector3) -> void:
	var entry: Dictionary = _entry_for(key)
	if entry.is_empty() or not entry.has("rig") or not is_instance_valid(entry.rig):
		return
	var dome = entry.rig.get_node_or_null("Pivot/Outer")
	if dome != null:
		dome.impact(at)


func tick(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for entry in active:
		entry.age = float(entry.age) + delta
		var before: float = float(entry.left)
		entry.left = before - delta
		var key: int = int(entry.owner)
		if float(entry.left) > 0.0:
			_hold_shield(key, float(entry.left))
		elif before > 0.0:
			if key == -1:
				host.say("Die Sternenfestung löst sich auf.")
				host.sound("fortress_end")
		if float(entry.left) < -SINK or not host._valid_key(key):
			release(entry)
			continue
		var rig: Node3D = acquire(entry)
		if rig != null:
			_draw(entry, rig, delta)
		keep.append(entry)
	active = keep


# --- Darstellung ---------------------------------------------------------------------------


func build_rig() -> Node3D:
	var rig := Node3D.new()
	rig.name = "StarFortress"
	rig.top_level = true
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	pivot.scale = Vector3.ONE * 1.22
	rig.add_child(pivot)
	var outer = SHIELD_DOME.new()
	outer.name = "Outer"
	outer.set_tint(GOLD)
	pivot.add_child(outer)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	ring.mesh = ImmediateMesh.new()
	# Alpha-Mischung: Ring und Käfig bleiben auch auf hellem Schnee kräftig sichtbar.
	ring.material_override = FX.soft(Color.WHITE, false, false)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(ring)
	var cage := MeshInstance3D.new()
	cage.name = "Cage"
	cage.mesh = ImmediateMesh.new()
	cage.material_override = FX.soft(Color.WHITE, false, false)
	cage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(cage)
	var tip: MeshInstance3D = FX.sprite(
		0.75, FX.glow(Color(1.0, 0.97, 0.8, 1.0), true, FX.soft_dot())
	)
	tip.name = "Tip"
	rig.add_child(tip)
	var sparkle_recipe := {
		"amount": host.budget(26),
		"lifetime": 1.2,
		"size": 0.16,
		"direction": Vector3.UP,
		"spread": 15.0,
		"speed_min": 0.5,
		"speed_max": 1.4,
		"sphere": 1.7,
		"local": true,
		"colors": [Color(1, 0.9, 0.5, 0), Color(1, 0.88, 0.4, 1), Color(0.5, 0.95, 1.0, 0)],
	}
	var sparkle: CPUParticles3D = FX.emitter(sparkle_recipe)
	sparkle.name = "Sparkle"
	sparkle.position = Vector3(0, 0.9, 0)
	rig.add_child(sparkle)
	var burst_recipe := {
		"amount": host.budget(36),
		"lifetime": 0.9,
		"size": 0.2,
		"one_shot": true,
		"explosiveness": 0.9,
		"spread": 70.0,
		"speed_min": 2.0,
		"speed_max": 5.0,
		"gravity": Vector3(0, -3.0, 0),
		"colors": [Color(1, 1, 0.85, 1), Color(1, 0.85, 0.3, 1), Color(0.4, 0.9, 1.0, 0)],
	}
	var burst: CPUParticles3D = FX.emitter(burst_recipe)
	burst.name = "Burst"
	rig.add_child(burst)
	return rig


func reset_rig(rig: Node3D, entry: Dictionary) -> void:
	var outer = rig.get_node("Pivot/Outer")
	outer.reveal = 0.0
	outer.remaining = 0.0
	outer.visible = false
	rig.set_meta("raised", false)
	rig.set_meta("ended", false)
	var kart: Node3D = host.kart(int(entry.owner))
	if is_instance_valid(kart):
		rig.global_transform = Transform3D(
			kart.global_basis.orthonormalized(), kart.global_position
		)


func _draw(entry: Dictionary, rig: Node3D, delta: float) -> void:
	var key: int = int(entry.owner)
	var kart: Node3D = host.kart(key)
	if not is_instance_valid(kart):
		return
	var reduced: bool = host.reduced_motion
	var left: float = float(entry.left)
	rig.global_transform = Transform3D(kart.global_basis.orthonormalized(), kart.global_position)
	var outer = rig.get_node("Pivot/Outer")
	outer.reduced_motion = reduced
	outer.advance(delta, maxf(0.0, left))
	var sparkle: CPUParticles3D = rig.get_node("Sparkle")
	sparkle.emitting = left > 0.0 and host.quality != "low"
	if not bool(rig.get_meta("raised", false)):
		rig.set_meta("raised", true)
		FX.burst(rig.get_node("Burst"), kart.global_position + Vector3.UP * 0.9)
	if left <= 0.0 and not bool(rig.get_meta("ended", false)):
		rig.set_meta("ended", true)
		FX.burst(rig.get_node("Burst"), kart.global_position + Vector3.UP * 1.6)
	# Restzeit-Ring am Boden: heller Bogen = verbleibende Zeit, 12 Sekunden-Marken.
	var ring_mesh: ImmediateMesh = (rig.get_node("Ring") as MeshInstance3D).mesh
	var tip: MeshInstance3D = rig.get_node("Tip")
	var fraction: float = clampf(left / CAP, 0.0, 1.0)
	var grow: float = 1.0 if reduced else smoothstep(0.0, 0.45, float(entry.age))
	var fade: float = 1.0 if left > 0.0 else clampf(1.0 + left / SINK, 0.0, 1.0)
	var ending: float = clampf(1.0 - left / 2.0, 0.0, 1.0) if left > 0.0 else 1.0
	var breathe: float = (
		1.0 if reduced else 1.0 - 0.35 * ending * (0.5 + 0.5 * sin(float(entry.age) * TAU * 0.8))
	)
	var radius: float = RING_RADIUS * grow
	var lines: Array = []
	var segments: int = 48
	var background := PackedVector3Array()
	for k in range(segments + 1):
		var a: float = TAU * k / segments
		background.append(Vector3(sin(a) * radius, 0.07, -cos(a) * radius))
	lines.append({"points": background, "width": 1.0, "color": Color(0.2, 0.4, 0.65, 0.45 * fade)})
	var lit := PackedVector3Array()
	var lit_segments: int = maxi(1, int(ceil(segments * fraction)))
	for k in range(lit_segments + 1):
		var a: float = TAU * fraction * k / lit_segments
		lit.append(Vector3(sin(a) * radius, 0.08, -cos(a) * radius))
	if fraction > 0.0:
		var colour: Color = CYAN.lerp(GOLD, fraction)
		colour.a = fade * breathe
		lines.append({"points": lit, "width": 2.2, "color": colour})
	for k in range(12):
		var a: float = TAU * (float(k) + 0.5) / 12.0
		var inner := Vector3(sin(a), 0.09, -cos(a)) * Vector3(radius + 0.18, 1.0, radius + 0.18)
		var outer_point := (
			Vector3(sin(a), 0.09, -cos(a)) * Vector3(radius + 0.48, 1.0, radius + 0.48)
		)
		var on: bool = float(k) + 0.5 < left
		(
			lines
			. append(
				{
					"points": PackedVector3Array([inner, outer_point]),
					"width": 2.4,
					"color":
					Color(GOLD if on else Color(0.35, 0.45, 0.6), (0.95 if on else 0.3) * fade),
				}
			)
		)
	var to_world: Transform3D = rig.global_transform
	var world_lines: Array = []
	for line in lines:
		var points := PackedVector3Array()
		for p in line.points:
			points.append(to_world * p)
		world_lines.append({"points": points, "width": line.width, "color": line.color})
	# Blick „von oben“: die Bänder liegen flach auf der Fahrbahn.
	var above: Vector3 = kart.global_position + kart.global_basis.y.normalized() * 1000.0
	FX.ribbons(ring_mesh, world_lines, above, 0.15, GOLD, to_world.affine_inverse())
	_draw_cage(rig, float(entry.age), grow, fade * breathe, left)
	tip.visible = fraction > 0.0
	if tip.visible:
		var a: float = TAU * fraction
		tip.position = Vector3(sin(a) * radius, 0.2, -cos(a) * radius)


## Äußere goldene Kuppel: drei Bögen über den Scheitel (sechs Rippen) + Mittelring, dreht langsam.
## Die zweite Kuppel bleibt so vor Schnee und Himmel lesbar; innen die cyanfarbene Schildkuppel.
func _draw_cage(rig: Node3D, age: float, grow: float, alpha: float, left: float) -> void:
	var mesh: ImmediateMesh = (rig.get_node("Cage") as MeshInstance3D).mesh
	var sink: float = 1.0 if left > 0.0 else clampf(1.0 + left / SINK, 0.0, 1.0)
	if alpha <= 0.01 or sink <= 0.0:
		mesh.clear_surfaces()
		return
	var spin: float = 0.0 if host.reduced_motion else age * 0.5
	var to_world: Transform3D = rig.global_transform
	var lines: Array = []
	var radius: float = 1.75 * grow
	var height: float = 2.5 * grow * sink
	var gold := Color(0.98, 0.72, 0.12, 0.85 * alpha)
	for k in range(3):
		var a: float = TAU * float(k) / 6.0 + spin
		var points := PackedVector3Array()
		for s in range(13):
			var t: float = PI * float(s) / 12.0
			var local := Vector3(
				cos(t) * radius * sin(a), sin(t) * height + 0.08, cos(t) * radius * -cos(a)
			)
			points.append(to_world * local)
		lines.append({"points": points, "width": 1.0, "color": gold})
	var belt := PackedVector3Array()
	for s in range(37):
		var b: float = TAU * float(s) / 36.0
		belt.append(
			to_world * Vector3(sin(b) * radius * 0.87, height * 0.5 + 0.08, -cos(b) * radius * 0.87)
		)
	lines.append({"points": belt, "width": 0.8, "color": Color(0.5, 0.95, 1.0, 0.8 * alpha)})
	FX.ribbons(mesh, lines, host.eye(), 0.07, GOLD, to_world.affine_inverse())
