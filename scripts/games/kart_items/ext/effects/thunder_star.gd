extends "res://scripts/games/kart_items/ext/kart_item_ext_effect.gd"
## DONNERSTERN – ein elektrisch geladener Stern trifft einen nahen Rivalen mit einem Blitz
## VON OBEN. Kette aus echten Positionen (jede Phase folgt den Karts, während sie fahren):
##   0.00–0.45 s  LADEN     Stern steigt knisternd vom eigenen Kart auf (kleine Bögen am Kart).
##   0.45–0.80 s  WEG       Stern fliegt im Bogen über das Ziel, Leuchtspur dahinter.
##   0.80–strike  WARNUNG   Gewitterwolke mit gelbem Kern über dem Ziel, gelber Ring auf der
##                           Fahrbahn unter ihm schrumpft (Ziel = Kind: Warnton + Text + roter
##                           Pfeil; Zeit genug für den Schild). strike = 1.15 s (Rivale 0.95 s,
##                           Kind 1.35 s in „Entdecken“).
##   strike +0.28 s EINSCHLAG verästelter Blitz Wolke -> Kartdach (dreimal neu verästelt),
##                           Lichtblitz und Funken am Dach. Mit Schild: endet an der Kuppel,
##                           teilt sich in drei Äste zur Fahrbahn ab, Kuppel zeigt Welle.
##   +0.0–1.1 s   REAKTION  Tempo kurz auf 68 % (weich zurück, kein Stopp), Funkenbögen
##                           kriechen über das Kart, Rennfahrer bleibt steuerbar.
##   +0.0–1.0 s   ABKLINGEN Brandring am Boden glüht aus, Wolke weitet sich und löst sich auf.

const FX = preload("res://scripts/games/kart_items/ext/kart_item_ext_fx.gd")
const CHARGE: float = 0.45
const TRAVEL: float = 0.35
const BOLT_TIME: float = 0.28
const AFTER: float = 1.1
const CLOUD_HEIGHT: float = 3.6
const RANGE_AHEAD: float = 48.0
const RANGE_BEHIND: float = 22.0
const SLOW: float = 0.68
const SLOW_SECONDS: float = 1.15
const YELLOW := Color(1.0, 0.86, 0.25)
const CORE := Color(1.0, 0.97, 0.62)

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	pool_cap = 3
	_rng.seed = 7071


func strike_time(target: int) -> float:
	if target == -1:
		return 1.35 if str(host.race.difficulty) == "gemuetlich" else 1.15
	return 0.95


func use(owner: int, item_id: String, _row: Dictionary) -> bool:
	var target: int = host.pick_target(owner, RANGE_AHEAD, RANGE_BEHIND)
	if target == -99:
		if owner == -1:
			host.say("Donnerstern: Kein Rivale nah genug – halte ihn noch kurz.")
		return false
	(
		active
		. append(
			{
				"owner": owner,
				"target": target,
				"item": item_id,
				"age": 0.0,
				"strike": strike_time(target),
				"result": "",
			}
		)
	)
	host.note_attack(target)
	if owner == -1:
		host.say("Donnerstern lädt … Blitz auf %s!" % host.race._rival_name(target))
		host.sound("thunder_charge")
	elif target == -1:
		host.warn_player(
			"Achtung, %s schickt einen Donnerstern – Schild!" % host.race._rival_name(owner)
		)
	return true


func rival_wants(index: int, _item_id: String, _context: Dictionary) -> bool:
	var target: int = host.pick_target(index, 40.0, 0.0)
	return target != -99 and not host.protected(target)


func incoming(key: int) -> float:
	var best: float = INF
	for entry in active:
		if int(entry.target) == key and str(entry.result).is_empty():
			best = minf(best, float(entry.strike) - float(entry.age))
	return best


func _valid_saved(entry: Dictionary) -> bool:
	return (
		super._valid_saved(entry)
		and entry.has("target")
		and entry.has("strike")
		and host._valid_key(int(entry.target))
		and host._valid_key(int(entry.owner))
	)


func tick(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for entry in active:
		entry.age = float(entry.age) + delta
		if float(entry.age) >= float(entry.strike) and str(entry.result).is_empty():
			_strike(entry)
		if float(entry.age) > float(entry.strike) + AFTER:
			release(entry)
			continue
		var rig: Node3D = acquire(entry)
		if rig != null:
			_draw(entry, rig, delta)
		keep.append(entry)
	active = keep


func _impact_point(entry: Dictionary) -> Vector3:
	var target: int = int(entry.target)
	var up: Vector3 = (
		host.kart(target).global_basis.y.normalized()
		if is_instance_valid(host.kart(target))
		else Vector3.UP
	)
	match str(entry.result):
		"blocked":
			return host.kart_centre(target) + up * 1.45
		"grace":
			return host.track_global(host.progress(target), host.lateral(target) + 1.7, 0.05)
	return host.kart_top(target)


func _strike(entry: Dictionary) -> void:
	var target: int = int(entry.target)
	var owner: int = int(entry.owner)
	var dome_top: Vector3 = host.kart_centre(target) + Vector3.UP * 1.45
	entry.result = host.resolve(target, owner, str(entry.item), dome_top)
	match str(entry.result):
		"hit":
			stats.hits += 1
			host.add_mod(target, "thunder", SLOW_SECONDS, SLOW, 0.92, 1.0)
			if owner == -1:
				host.say(
					"ZACK! Der Blitz trifft %s – kurz langsamer." % host.race._rival_name(target)
				)
			elif target == -1:
				host.say("Blitz! Kurz langsamer – gleich geht's weiter.")
		"blocked":
			stats.blocked += 1
		"grace":
			stats.grace += 1
	if host.involves_player(owner, target) or host.eye().distance_to(dome_top) < 60.0:
		host.sound("thunder_strike", 1.0 if str(entry.result) == "hit" else 1.12)


# --- Darstellung ---------------------------------------------------------------------------


func build_rig() -> Node3D:
	var rig := Node3D.new()
	rig.name = "ThunderStar"
	rig.top_level = true
	var star := MeshInstance3D.new()
	star.name = "Star"
	star.mesh = FX.star_mesh(0.6, 0.26)
	var star_material: StandardMaterial3D = FX.glow_unique(Color(1.0, 0.9, 0.35), true)
	star.material_override = star_material
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(star)
	var halo: MeshInstance3D = FX.sprite(
		1.5, FX.glow_unique(Color(1.0, 0.8, 0.2, 0.75), true, FX.soft_dot())
	)
	halo.name = "Halo"
	rig.add_child(halo)
	var trail_recipe := {
		"amount": host.budget(36),
		"lifetime": 0.45,
		"size": 0.32,
		"spread": 180.0,
		"speed_min": 0.2,
		"speed_max": 0.9,
		"colors": [Color(1, 0.97, 0.7, 1), Color(1, 0.75, 0.2, 0.7), Color(1, 0.6, 0.1, 0)],
		"scale_min": 0.6,
		"scale_max": 1.2,
		"grow": 0.4,
	}
	var trail: CPUParticles3D = FX.emitter(trail_recipe)
	trail.name = "Trail"
	rig.add_child(trail)
	var cloud := Node3D.new()
	cloud.name = "Cloud"
	rig.add_child(cloud)
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	puff_material.vertex_color_use_as_albedo = true
	puff_material.albedo_texture = FX.soft_dot()
	puff_material.albedo_color = Color(0.22, 0.2, 0.32, 1.0)
	puff_material.disable_receive_shadows = true
	for k in range(7):
		var puff: MeshInstance3D = FX.sprite(3.1, puff_material)
		puff.name = "Puff%d" % k
		cloud.add_child(puff)
	var cloud_glow: MeshInstance3D = FX.sprite(
		3.8, FX.glow_unique(Color(1.0, 0.85, 0.3, 0.75), true, FX.soft_dot())
	)
	cloud_glow.name = "CloudGlow"
	cloud.add_child(cloud_glow)
	var ring: MeshInstance3D = FX.ground_disc(
		1.0, FX.glow_unique(Color(1.0, 0.85, 0.2, 0.95), false, FX.soft_ring())
	)
	ring.name = "WarnRing"
	rig.add_child(ring)
	var scorch: MeshInstance3D = FX.ground_disc(
		1.0, FX.glow_unique(Color(1.0, 0.55, 0.15, 0.9), false, FX.soft_ring())
	)
	scorch.name = "Scorch"
	rig.add_child(scorch)
	# Blitz in Alpha-Mischung (nicht additiv): bleibt auch vor hellem Taghimmel kräftig gelb.
	var bolt_material := StandardMaterial3D.new()
	bolt_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt_material.vertex_color_use_as_albedo = true
	bolt_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bolt_material.render_priority = 2
	for line_name in ["Bolt", "Arcs"]:
		var line := MeshInstance3D.new()
		line.name = line_name
		line.mesh = ImmediateMesh.new()
		line.material_override = bolt_material
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.add_child(line)
	var flash: MeshInstance3D = FX.sprite(
		3.0, FX.glow_unique(Color(1.0, 0.95, 0.7, 1.0), true, FX.soft_dot())
	)
	flash.name = "Flash"
	rig.add_child(flash)
	var sparks_recipe := {
		"amount": host.budget(40),
		"lifetime": 0.7,
		"size": 0.18,
		"one_shot": true,
		"explosiveness": 0.95,
		"spread": 80.0,
		"speed_min": 3.0,
		"speed_max": 8.5,
		"gravity": Vector3(0, -12, 0),
		"colors": [Color(1, 1, 0.85, 1), Color(1, 0.8, 0.25, 1), Color(1, 0.5, 0.1, 0)],
	}
	var sparks: CPUParticles3D = FX.emitter(sparks_recipe)
	sparks.name = "Sparks"
	rig.add_child(sparks)
	return rig


func reset_rig(rig: Node3D, _entry: Dictionary) -> void:
	for child_name in ["Star", "Halo", "Cloud", "WarnRing", "Scorch", "Flash"]:
		(rig.get_node(child_name) as Node3D).visible = false
	(rig.get_node("Trail") as CPUParticles3D).emitting = false
	for line_name in ["Bolt", "Arcs"]:
		((rig.get_node(line_name) as MeshInstance3D).mesh as ImmediateMesh).clear_surfaces()
	rig.set_meta("sparked", false)
	rig.set_meta("bolt_seed", -1)
	if rig.has_meta("scorch_at"):
		rig.remove_meta("scorch_at")


func _draw(entry: Dictionary, rig: Node3D, _delta: float) -> void:
	var owner: int = int(entry.owner)
	var target: int = int(entry.target)
	var age: float = float(entry.age)
	var strike: float = float(entry.strike)
	var reduced: bool = host.reduced_motion
	var star: MeshInstance3D = rig.get_node("Star")
	var halo: MeshInstance3D = rig.get_node("Halo")
	var trail: CPUParticles3D = rig.get_node("Trail")
	var cloud: Node3D = rig.get_node("Cloud")
	var ring: MeshInstance3D = rig.get_node("WarnRing")
	var scorch: MeshInstance3D = rig.get_node("Scorch")
	var flash: MeshInstance3D = rig.get_node("Flash")
	var bolt_mesh: ImmediateMesh = (rig.get_node("Bolt") as MeshInstance3D).mesh
	var arc_mesh: ImmediateMesh = (rig.get_node("Arcs") as MeshInstance3D).mesh
	var own_top: Vector3 = host.kart_top(owner)
	var target_top: Vector3 = host.kart_top(target)
	var cloud_at: Vector3 = target_top + Vector3.UP * CLOUD_HEIGHT
	var eye: Vector3 = host.eye()
	var identity := Transform3D.IDENTITY
	# 1) Laden + 2) Weg: der Stern.
	var star_visible: bool = age < CHARGE + TRAVEL
	star.visible = star_visible
	halo.visible = star_visible
	trail.emitting = star_visible and age > CHARGE * 0.5
	if star_visible:
		var star_at: Vector3
		var size: float
		if age < CHARGE:
			var t: float = age / CHARGE
			star_at = own_top + Vector3.UP * (0.15 + 0.6 * smoothstep(0.0, 1.0, t))
			size = lerpf(0.35, 0.9, t)
		else:
			var s: float = smoothstep(0.0, 1.0, (age - CHARGE) / TRAVEL)
			var from: Vector3 = own_top + Vector3.UP * 1.25
			star_at = (
				from.lerp(cloud_at, s)
				+ Vector3.UP * sin(PI * s) * (0.6 + from.distance_to(cloud_at) * 0.03)
			)
			size = 1.1
		star.global_position = star_at
		halo.global_position = star_at
		trail.global_position = star_at
		star.scale = Vector3.ONE * size
		halo.scale = Vector3.ONE * size * (1.0 if reduced else 0.9 + 0.2 * sin(age * 40.0))
		if not reduced:
			star.rotation.z = age * 6.0
	# Knisternde Bögen am eigenen Kart, solange es lädt (neu verästelt alle 60 ms).
	if age < CHARGE and not reduced:
		var lines: Array = []
		var centre: Vector3 = host.kart_centre(owner)
		_rng.seed = int(age / 0.06) * 131 + 17
		for k in range(3):
			var a: Vector3 = (
				centre
				+ Vector3(
					_rng.randf_range(-0.8, 0.8),
					_rng.randf_range(-0.1, 0.5),
					_rng.randf_range(-1.0, 1.0)
				)
			)
			for line in FX.bolt(a, own_top + Vector3.UP * 0.3, _rng, 5, 0.18, 0):
				line.color = YELLOW
				lines.append(line)
		FX.ribbons(arc_mesh, lines, eye, 0.07, YELLOW, identity)
	elif str(entry.result).is_empty() or age > strike + SLOW_SECONDS:
		arc_mesh.clear_surfaces()
	# 3) Wolke + Bodenwarnring über/unter dem Ziel (folgen dem fahrenden Ziel).
	var cloud_in: float = clampf((age - CHARGE - TRAVEL * 0.6) / 0.3, 0.0, 1.0)
	var cloud_out: float = clampf((age - strike - 0.35) / 0.6, 0.0, 1.0)
	cloud.visible = cloud_in > 0.0 and cloud_out < 1.0
	if cloud.visible:
		cloud.global_position = cloud_at
		var grow: float = lerpf(0.35, 1.0, smoothstep(0.0, 1.0, cloud_in)) * (1.0 + cloud_out * 0.6)
		for k in range(7):
			var puff: MeshInstance3D = cloud.get_node("Puff%d" % k)
			var angle: float = TAU * k / 7.0 + (0.0 if reduced else age * 0.6)
			puff.position = Vector3(cos(angle) * 1.5, sin(k * 1.7) * 0.32, sin(angle) * 1.0) * grow
			puff.scale = Vector3.ONE * grow * (0.8 + 0.25 * float(k % 3))
		var glow_node: MeshInstance3D = cloud.get_node("CloudGlow")
		var flicker: float = 1.0 if reduced else 0.75 + 0.25 * sin(age * 31.0) * sin(age * 13.0)
		var charge_up: float = clampf(
			(age - CHARGE - TRAVEL) / maxf(0.05, strike - CHARGE - TRAVEL), 0.0, 1.0
		)
		(glow_node.material_override as StandardMaterial3D).albedo_color.a = (
			(0.5 + 0.5 * charge_up) * flicker * (1.0 - cloud_out)
		)
		glow_node.position = Vector3.DOWN * 0.3
		# Alle Wolkenballen teilen ein Material (je Darstellung eins): einmal setzen genügt.
		var puff: MeshInstance3D = cloud.get_node("Puff0")
		var puff_material := puff.material_override as StandardMaterial3D
		puff_material.albedo_color.a = (1.0 - cloud_out) * smoothstep(0.0, 1.0, cloud_in)
	ring.visible = cloud_in > 0.0 and age < strike + 0.05
	if ring.visible:
		var warn: float = clampf(
			(age - CHARGE - TRAVEL * 0.6) / maxf(0.1, strike - CHARGE - TRAVEL * 0.6), 0.0, 1.0
		)
		ring.global_transform = Transform3D(
			host.track_basis(host.progress(target)).scaled(Vector3.ONE * lerpf(2.4, 1.3, warn)),
			host.track_global(host.progress(target), host.lateral(target), 0.06)
		)
		var pulse: float = 1.0 if reduced else 0.7 + 0.3 * sin(age * 18.0)
		(ring.material_override as StandardMaterial3D).albedo_color.a = 0.95 * pulse
	# 4) Einschlag: verästelter Blitz von der Wolke zum Kartdach / zur Kuppel.
	var since: float = age - strike
	if since >= 0.0 and since < BOLT_TIME and not str(entry.result).is_empty():
		var impact: Vector3 = _impact_point(entry)
		var seed_step: int = 0 if reduced else int(since / 0.07)
		if int(rig.get_meta("bolt_seed", -1)) != seed_step:
			rig.set_meta("bolt_seed", seed_step)
			_rng.seed = 991 + seed_step * 7 + int(entry.get("target", 0)) * 13
			var segments: int = 9 if host.quality != "low" else 6
			var branches: int = {"low": 1, "medium": 3, "high": 4}.get(host.quality, 3)
			var lines: Array = []
			var main_lines: Array = FX.bolt(
				cloud_at + Vector3.DOWN * 0.4, impact, _rng, segments, 0.75, branches
			)
			if str(entry.result) == "blocked":
				# Abgeleitet: drei Äste von der Kuppel zur Fahrbahn rund um das Kart.
				for k in range(3):
					var side: Vector3 = (
						Vector3(cos(TAU * k / 3.0 + 0.4), 0.0, sin(TAU * k / 3.0 + 0.4)) * 1.9
					)
					for branch in FX.bolt(
						impact, impact + side + Vector3.DOWN * 1.9, _rng, 5, 0.25, 0
					):
						branch.width = 0.55
						main_lines.append(branch)
			for line in main_lines:
				var glow_line: Dictionary = {
					"points": line.points,
					"width": float(line.width) * 3.4,
					"color": Color(1.0, 0.72, 0.08, 0.6)
				}
				var core_line: Dictionary = {
					"points": line.points, "width": float(line.width), "color": CORE
				}
				lines.append(glow_line)
				lines.append(core_line)
			FX.ribbons(bolt_mesh, lines, eye, 0.28, CORE, identity)
		var fade: float = 1.0 - since / BOLT_TIME
		flash.visible = true
		flash.global_position = impact
		flash.scale = Vector3.ONE * (0.6 + 1.0 * fade) * (0.6 if reduced else 1.0)
		(flash.material_override as StandardMaterial3D).albedo_color.a = fade
		if not bool(rig.get_meta("sparked", false)):
			rig.set_meta("sparked", true)
			FX.burst(rig.get_node("Sparks"), impact, Vector3.UP)
	else:
		bolt_mesh.clear_surfaces()
		flash.visible = false
	# 5) Reaktion: Funkenbögen kriechen über das getroffene Kart.
	if str(entry.result) == "hit" and since >= 0.0 and since < SLOW_SECONDS * 0.85:
		var arcs: Array = []
		var centre: Vector3 = host.kart_centre(target)
		var step: int = 0 if reduced else int(since / 0.06)
		_rng.seed = 5003 + step * 11
		var count: int = 1 if reduced else (2 if host.quality == "low" else 3)
		for k in range(count):
			var a: Vector3 = (
				centre
				+ Vector3(
					_rng.randf_range(-0.9, 0.9),
					_rng.randf_range(-0.3, 0.6),
					_rng.randf_range(-1.1, 1.1)
				)
			)
			var b: Vector3 = (
				centre
				+ Vector3(
					_rng.randf_range(-0.9, 0.9),
					_rng.randf_range(-0.3, 0.6),
					_rng.randf_range(-1.1, 1.1)
				)
			)
			for line in FX.bolt(a, b, _rng, 4, 0.2, 0):
				line.color = Color(1.0, 0.92, 0.45, 1.0 - since / SLOW_SECONDS)
				arcs.append(line)
		FX.ribbons(arc_mesh, arcs, eye, 0.06, YELLOW, identity)
	# 6) Abklingen: Brandring am Boden glüht aus.
	scorch.visible = since >= 0.0 and str(entry.result) != "" and since < AFTER
	if scorch.visible:
		var glow_left: float = 1.0 - since / AFTER
		var ground_key: int = target
		var at: Vector3 = host.track_global(
			host.progress(ground_key),
			host.lateral(ground_key) + (1.7 if str(entry.result) == "grace" else 0.0),
			0.05
		)
		if not rig.has_meta("scorch_at") or since < 0.03:
			rig.set_meta("scorch_at", at)
			rig.set_meta("scorch_basis", host.track_basis(host.progress(ground_key)))
		var basis: Basis = rig.get_meta("scorch_basis")
		scorch.global_transform = Transform3D(
			basis.scaled(Vector3.ONE * lerpf(0.9, 2.1, 1.0 - glow_left * glow_left)),
			rig.get_meta("scorch_at")
		)
		var colour := Color(1.0, 0.55, 0.15).lerp(Color(0.3, 0.24, 0.2), 1.0 - glow_left)
		colour.a = 0.9 * glow_left
		(scorch.material_override as StandardMaterial3D).albedo_color = colour
	elif rig.has_meta("scorch_at"):
		rig.remove_meta("scorch_at")
