extends "res://scripts/games/kart_items/ext/kart_item_ext_effect.gd"
## TURBO-KETTE XL – kraftvoller Turbo mit drei einzeln auslösbaren Ladungen.
## Je Ladung (1,5 s): vorhandener Kart-Schub (gleiche Fahrphysik wie Turbo-Feld/Rückenwind)
## plus 8 % mehr Höchsttempo; sichtbar als zwei leuchtende Auspuffstrahlen, Energielinien
## entlang der Flanken und ein Zündring am Heck.
##   0.00–0.12 s  ZÜNDUNG   Zündring dehnt sich am Heck, Strahlen schießen heraus.
##   0.12–1.50 s  SCHUB     Strahlen pulsieren mit dem Motor, Energielinien ziehen nach hinten.
##   1.50–1.80 s  ABKLINGEN Strahlen schrumpfen, Linien verblassen.
## Streckengeometrie: keine Zündung, wenn Brückendeck, offene Kante, Rampe oder Passagen-Zone
## bis 30 m voraus liegen (die Ladung bleibt erhalten); kommt so eine Stelle während des
## Schubs, endet er weich. Rivalen zünden ihre Ladungen nacheinander auf freier Strecke.
## Schild/Schonzeit: kein Angriff, wirkt nur auf das eigene Kart (Schonzeit unberührt).

const FX = preload("res://scripts/games/kart_items/ext/kart_item_ext_fx.gd")
const BURST: float = 1.5
const FADE: float = 0.3
const EXTRA: float = 1.08
const RIVAL_GAP: float = 1.1
const JET := Color(0.45, 0.95, 1.0)
const HOT := Color(1.0, 0.55, 0.95)


func _init() -> void:
	pool_cap = 6


func use(owner: int, item_id: String, row: Dictionary) -> bool:
	if not host.safe_at(host.progress(owner), owner):
		if owner == -1:
			host.say("Turbo-Kette wartet: vorn kommt eine Brücke, Kante oder Rampe.")
		return false
	var charges: int = 1 if owner == -1 else maxi(1, int(row.get("charges", 3)))
	var entry: Dictionary = _entry_for(owner)
	if entry.is_empty():
		entry = {
			"owner": owner, "item": item_id, "age": 0.0, "burst": 0.0, "left": charges, "cool": 0.0
		}
		active.append(entry)
	else:
		entry.left = int(entry.left) + charges
	_ignite(entry)
	return true


func _entry_for(key: int) -> Dictionary:
	for entry in active:
		if int(entry.owner) == key:
			return entry
	return {}


func _ignite(entry: Dictionary) -> void:
	var owner: int = int(entry.owner)
	entry.left = int(entry.left) - 1
	entry.burst = BURST
	entry.age = 0.0
	entry.cool = RIVAL_GAP + BURST
	host.add_mod(owner, "turbo_xl", BURST, EXTRA, 1.0, 1.0)
	if owner == -1:
		host.race.boost_time = maxf(float(host.race.boost_time), host.race._boost_for(BURST))
		host.race.camera_punch = maxf(
			float(host.race.camera_punch), 0.0 if host.reduced_motion else 0.4
		)
		var left: int = int(host.race.item_charges) - 1
		host.say(
			"TURBO-KETTE XL! Noch %d×" % left if left > 0 else "TURBO-KETTE XL – letzte Ladung!"
		)
		host.sound("turbo_xl")
	else:
		host.race.opponent_boost_times[owner] = maxf(
			float(host.race.opponent_boost_times[owner]), BURST
		)
		if host.eye().distance_to(host.kart_centre(owner)) < 40.0:
			host.sound("turbo_xl", 1.1)
	stats.bursts = int(stats.get("bursts", 0)) + 1


func rival_wants(index: int, _item_id: String, context: Dictionary) -> bool:
	if not host.safe_at(host.progress(index), index):
		return false
	return float(context.get("ahead_gap", INF)) < 45.0 or int(context.get("place", 1)) >= 3


func _valid_saved(entry: Dictionary) -> bool:
	return super._valid_saved(entry) and entry.has("burst") and host._valid_key(int(entry.owner))


func tick(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for entry in active:
		var owner: int = int(entry.owner)
		entry.age = float(entry.age) + delta
		entry.burst = float(entry.burst) - delta
		entry.cool = float(entry.cool) - delta
		if float(entry.burst) > 0.0 and not host.safe_at(host.progress(owner), owner):
			# Gefährliche Stelle voraus: Schub endet weich.
			entry.burst = 0.0
			host.add_mod(owner, "turbo_xl", 0.01, 1.0, 1.0, 1.0)
			if owner == -1:
				host.race.boost_time = minf(float(host.race.boost_time), 0.25)
			stats.safety_skipped += 1
		if owner >= 0 and int(entry.left) > 0 and float(entry.cool) <= 0.0:
			if host.safe_at(host.progress(owner), owner):
				_ignite(entry)
		if float(entry.burst) < -FADE and (owner == -1 or int(entry.left) <= 0):
			release(entry)
			continue
		var rig: Node3D = acquire(entry)
		if rig != null:
			_draw(entry, rig)
		keep.append(entry)
	active = keep


func build_rig() -> Node3D:
	var rig := Node3D.new()
	rig.name = "TurboXL"
	rig.top_level = true
	var cone := CylinderMesh.new()
	cone.top_radius = 0.16
	cone.bottom_radius = 0.0
	cone.height = 1.0
	cone.radial_segments = 12
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	for side in [-1, 1]:
		var jet := Node3D.new()
		jet.name = "Jet%d" % (0 if side < 0 else 1)
		jet.position = Vector3(0.34 * side, 0.42, 1.05)
		rig.add_child(jet)
		for layer in [["Outer", HOT, 1.0], ["Core", JET, 0.55]]:
			var flame := MeshInstance3D.new()
			flame.name = str(layer[0])
			flame.mesh = cone
			flame.material_override = FX.glow_unique(Color(layer[1], 0.85), false)
			flame.rotation.x = -PI * 0.5
			flame.scale = Vector3.ONE * float(layer[2])
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			jet.add_child(flame)
		var glow: MeshInstance3D = FX.sprite(
			0.9, FX.glow(Color(0.6, 0.95, 1.0, 0.9), true, FX.soft_dot())
		)
		glow.name = "Glow"
		jet.add_child(glow)
	var lines := MeshInstance3D.new()
	lines.name = "Lines"
	lines.mesh = ImmediateMesh.new()
	lines.material_override = FX.glow(Color.WHITE)
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(lines)
	var ring: MeshInstance3D = FX.sprite(
		2.4, FX.glow_unique(Color(0.6, 0.95, 1.0, 1.0), false, FX.soft_ring())
	)
	ring.name = "Ring"
	ring.position = Vector3(0.0, 0.45, 1.2)
	rig.add_child(ring)
	var spark_recipe := {
		"amount": host.budget(30),
		"lifetime": 0.35,
		"size": 0.14,
		"direction": Vector3.BACK,
		"spread": 18.0,
		"speed_min": 5.0,
		"speed_max": 10.0,
		"local": false,
		"colors": [Color(1, 1, 1, 1), Color(0.5, 0.95, 1.0, 0.9), Color(1.0, 0.5, 0.9, 0)],
	}
	var sparks: CPUParticles3D = FX.emitter(spark_recipe)
	sparks.name = "Sparks"
	rig.add_child(sparks)
	return rig


func reset_rig(rig: Node3D, _entry: Dictionary) -> void:
	(rig.get_node("Sparks") as CPUParticles3D).emitting = false


func _draw(entry: Dictionary, rig: Node3D) -> void:
	var kart: Node3D = host.kart(int(entry.owner))
	if not is_instance_valid(kart):
		return
	var reduced: bool = host.reduced_motion
	var burst: float = float(entry.burst)
	var age: float = float(entry.age)
	var power: float = 1.0 if burst > 0.0 else clampf(1.0 + burst / FADE, 0.0, 1.0)
	var ignite: float = clampf(age / 0.12, 0.0, 1.0)
	rig.global_transform = Transform3D(kart.global_basis.orthonormalized(), kart.global_position)
	rig.visible = power > 0.0
	var pulse: float = 1.0 if reduced else 0.85 + 0.15 * sin(age * 38.0)
	for k in range(2):
		var jet: Node3D = rig.get_node("Jet%d" % k)
		var length: float = lerpf(0.2, 1.9, ignite) * power * pulse
		jet.scale = Vector3(1.0, 1.0, 1.0)
		for flame_name in ["Outer", "Core"]:
			var flame: MeshInstance3D = jet.get_node(flame_name)
			var base: float = 1.0 if flame_name == "Outer" else 0.55
			flame.scale = Vector3(
				base * (0.8 + 0.4 * power), base * length, base * (0.8 + 0.4 * power)
			)
			flame.position = Vector3(0, 0, 0.5 * base * length)
		(jet.get_node("Glow") as Node3D).scale = Vector3.ONE * (0.6 + 0.6 * power)
	var ring: MeshInstance3D = rig.get_node("Ring")
	ring.visible = age < 0.45
	if ring.visible:
		var t: float = age / 0.45
		ring.scale = Vector3.ONE * (0.4 + 1.6 * t)
		(ring.material_override as StandardMaterial3D).albedo_color.a = 1.0 - t
	var sparks: CPUParticles3D = rig.get_node("Sparks")
	sparks.emitting = burst > 0.0 and host.quality != "low"
	sparks.global_position = kart.global_transform * Vector3(0, 0.42, 1.3)
	sparks.direction = kart.global_basis.z.normalized()
	# Energielinien: entlang beider Flanken nach hinten, Länge wächst mit dem Tempo.
	var mesh: ImmediateMesh = (rig.get_node("Lines") as MeshInstance3D).mesh
	if power <= 0.0 or (reduced and burst <= 0.0):
		mesh.clear_surfaces()
		return
	var speed: float = (
		absf(float(host.race.speed))
		if int(entry.owner) == -1
		else absf(float(host.race.opponents[int(entry.owner)].motion_speed))
	)
	var lines: Array = []
	var count: int = 4 if host.quality == "low" else 6
	for k in range(count):
		var side: float = -1.0 if k % 2 == 0 else 1.0
		var height: float = 0.25 + 0.28 * float(k / 2)
		var phase: float = fmod(age * 3.0 + float(k) * 0.37, 1.0)
		var reach: float = clampf(speed * 0.12, 1.2, 4.5) * (0.6 + 0.4 * phase)
		var start: Vector3 = kart.global_transform * Vector3(0.95 * side, height, -0.4)
		var finish: Vector3 = (
			kart.global_transform * Vector3((1.0 + 0.15 * phase) * side, height, -0.4 + reach)
		)
		var colour: Color = JET.lerp(HOT, float(k) / float(count))
		colour.a = 0.85 * power * (1.0 - phase * 0.5)
		lines.append({"points": PackedVector3Array([start, finish]), "width": 1.0, "color": colour})
	FX.ribbons(mesh, lines, host.eye(), 0.09, JET, rig.global_transform.affine_inverse())
