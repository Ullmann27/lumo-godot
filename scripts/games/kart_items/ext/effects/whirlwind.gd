extends "res://scripts/games/kart_items/ext/kart_item_ext_effect.gd"
## WIRBELWIND – ein kontrollierbarer Luftwirbel läuft in Fahrtrichtung über die Strecke und
## versetzt einen Rivalen kurz seitlich – nur innerhalb des sicheren Korridors.
##   0.00–0.15 s  AUSLÖSER  Wirbel entsteht vor dem eigenen Kart (Böe, Staub am Boden).
##   0.15–3.0 s   WEG       läuft mit Kart-Tempo + 12 m/s (mind. 26 m/s) die Strecke entlang;
##                          das Kind lenkt ihn mit der eigenen Lenkung (3,2 m/s quer), sonst zieht
##                          er sanft zur Spur des Rivalen vorn. Trichter aus drei drehenden
##                          Windbändern, je Strecke Staub/Sand, Schnee, Blätter, Glut oder Funken.
##   Kontakt      EINSCHLAG Böe am Ziel, Wirbel zerfällt in eine Wolke aus Streckenteilchen.
##   +0–0,55 s    REAKTION  Ziel wird bis 2,2 m seitlich versetzt (weg von der Wirbelmitte, sonst
##                          zur Fahrbahnmitte), nie über 1,15 m vor die Planke, nie auf Brücke /
##                          an offener Kante / auf Rampe (dann kein Versatz, nur Wackeln);
##                          0,8 s 85 % Tempo.
##   +0,55–1,3 s  ABKLINGEN Teilchen sinken zu Boden, Staub legt sich.

const FX = preload("res://scripts/games/kart_items/ext/kart_item_ext_fx.gd")
const LIFE: float = 3.0
const CLOSING: float = 12.0
const MIN_SPEED: float = 26.0
const STEER: float = 3.2
const AIM: float = 2.0
const LOCK: float = 40.0
const HIT_PROGRESS: float = 2.0
const HIT_LATERAL: float = 2.1
const PUSH: float = 2.2
const PUSH_SECONDS: float = 0.55
const SLOW: float = 0.85
const SLOW_SECONDS: float = 0.8
const HEIGHT: float = 4.1
const DEBRIS: int = 22
const THEMES: Dictionary = {
	"sand": [Color(0.86, 0.74, 0.52), Color(0.95, 0.88, 0.7), Color(0.75, 0.62, 0.42)],
	"snow": [Color(1, 1, 1), Color(0.86, 0.94, 1.0), Color(0.75, 0.88, 1.0)],
	"leaves": [Color(0.35, 0.72, 0.25), Color(0.62, 0.82, 0.3), Color(0.9, 0.62, 0.2)],
	"embers": [Color(1.0, 0.6, 0.2), Color(1.0, 0.85, 0.4), Color(0.5, 0.42, 0.4)],
	"sparks": [Color(0.5, 0.95, 1.0), Color(0.85, 0.6, 1.0), Color(1, 1, 1)],
}


func _init() -> void:
	pool_cap = 3


func use(owner: int, item_id: String, _row: Dictionary) -> bool:
	var target: int = host.pick_target(owner, LOCK, 0.0)
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
				"progress": host.progress(owner) + 3.0,
				"lateral": host.lateral(owner),
				"speed": maxf(MIN_SPEED, carrier + CLOSING),
				"result": "",
				"pushed": 0.0,
			}
		)
	)
	if target != -99:
		host.note_attack(target)
	if owner == -1:
		host.say(
			(
				"Wirbelwind! Lenke ihn zu %s." % host.race._rival_name(target)
				if target >= 0
				else "Wirbelwind! Lenke ihn mit dem Lenkrad."
			)
		)
		host.sound("whirl_go")
	elif target == -1:
		host.warn_player("Achtung: Wirbelwind von hinten – zur Seite oder Schild!")
	return true


func rival_wants(index: int, _item_id: String, _context: Dictionary) -> bool:
	var target: int = host.pick_target(index, 30.0, 0.0, true)
	if target == -99 or host.protected(target):
		return false
	return host.progress(target) - host.progress(index) > 5.0


func incoming(key: int) -> float:
	var best: float = INF
	for entry in active:
		if str(entry.phase) == "fly" and int(entry.target) == key:
			var gap: float = host.progress(key) - float(entry.progress)
			if gap > -HIT_PROGRESS:
				best = minf(best, maxf(0.0, gap) / maxf(1.0, float(entry.speed)))
	return best


func lane_bias(index: int) -> float:
	var bias: float = 0.0
	for entry in active:
		if str(entry.phase) != "fly" or int(entry.owner) == index:
			continue
		var gap: float = host.progress(index) - float(entry.progress)
		if gap < 0.0 or gap > 20.0:
			continue
		var side: float = host.lateral(index) - float(entry.lateral)
		if absf(side) < 2.6:
			bias += (2.6 - absf(side)) * (1.0 if side >= 0.0 else -1.0) * 0.8
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
		if str(entry.phase) == "fly":
			_fly(entry, delta)
		if str(entry.phase) == "done" and float(entry.age) > float(entry.end_at):
			release(entry)
			continue
		var rig: Node3D = acquire(entry)
		if rig != null:
			_draw(entry, rig)
		keep.append(entry)
	active = keep


func _fly(entry: Dictionary, delta: float) -> void:
	var owner: int = int(entry.owner)
	var target: int = int(entry.target)
	var wall: float = (
		float(host.race._wall_lateral_at(fposmod(float(entry.progress), host.track_length()))) - 0.6
	)
	if owner == -1 and absf(float(host.race.steering)) > 0.05:
		entry.lateral = (
			float(entry.lateral) + clampf(float(host.race.steering), -1.0, 1.0) * STEER * delta
		)
	elif target != -99 and host._valid_key(target):
		entry.lateral = move_toward(float(entry.lateral), host.lateral(target), AIM * delta)
	entry.lateral = clampf(float(entry.lateral), -wall, wall)
	entry.progress = float(entry.progress) + float(entry.speed) * delta
	for key in host.racer_keys():
		if key == owner:
			continue
		if (
			absf(host.progress(key) - float(entry.progress)) <= HIT_PROGRESS
			and absf(host.lateral(key) - float(entry.lateral)) <= HIT_LATERAL
		):
			_contact(entry, key)
			return
	if float(entry.age) >= LIFE:
		entry.phase = "done"
		entry.result = "fizzled"
		entry.hit_at = float(entry.age)
		entry.end_at = float(entry.age) + 0.8
		stats.fizzled += 1


func _contact(entry: Dictionary, key: int) -> void:
	entry.target = key
	entry.phase = "done"
	entry.hit_at = float(entry.age)
	entry.end_at = float(entry.age) + 1.3
	entry.result = host.resolve(key, int(entry.owner), str(entry.item), host.kart_centre(key))
	if str(entry.result) == "hit":
		stats.hits += 1
		var away: float = host.lateral(key) - float(entry.lateral)
		var direction: float = signf(away) if absf(away) > 0.15 else -signf(host.lateral(key))
		if direction == 0.0:
			direction = 1.0
		var moved: float = host.push(key, direction * PUSH, PUSH_SECONDS)
		if absf(moved) < 0.3 and host.safe_at(host.progress(key), key):
			moved = host.push(key, -direction * PUSH, PUSH_SECONDS)
		if absf(moved) < 0.05:
			stats.safety_skipped += 1
		entry.pushed = moved
		host.add_mod(key, "whirl", SLOW_SECONDS, SLOW, 0.8, 1.0)
		if int(entry.owner) == -1:
			host.say("Erwischt! Der Wirbel schiebt %s zur Seite." % host.race._rival_name(key))
		elif key == -1:
			host.say("Huii – der Wind schiebt dich kurz zur Seite!")
	elif str(entry.result) == "blocked":
		stats.blocked += 1
	else:
		stats.grace += 1
	if (
		host.involves_player(int(entry.owner), key)
		or host.eye().distance_to(host.kart_centre(key)) < 50.0
	):
		host.sound("whirl_hit")


# --- Darstellung ---------------------------------------------------------------------------


func build_rig() -> Node3D:
	var rig := Node3D.new()
	rig.name = "Whirlwind"
	rig.top_level = true
	var funnel := MeshInstance3D.new()
	funnel.name = "Funnel"
	funnel.mesh = ImmediateMesh.new()
	funnel.material_override = FX.glow(Color.WHITE)
	funnel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(funnel)
	var debris_material := StandardMaterial3D.new()
	var veil := MeshInstance3D.new()
	veil.name = "WindSheets"
	veil.mesh = _wind_sheets(host.quality == "low")
	veil.material_override = FX.soft(Color.WHITE, false, false).duplicate()
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(veil)
	debris_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debris_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debris_material.vertex_color_use_as_albedo = true
	debris_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var debris := MeshInstance3D.new()
	debris.name = "Debris"
	debris.mesh = ImmediateMesh.new()
	debris.material_override = debris_material
	debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(debris)
	var dust_recipe := {
		"amount": host.budget(22),
		"lifetime": 0.9,
		"size": 0.9,
		"spread": 60.0,
		"direction": Vector3.UP,
		"speed_min": 0.6,
		"speed_max": 1.8,
		"box": Vector3(0.9, 0.05, 0.9),
		"additive": false,
		"grow": 2.2,
		"colors": [Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)],
	}
	var dust: CPUParticles3D = FX.emitter(dust_recipe)
	dust.name = "Dust"
	rig.add_child(dust)
	var burst_recipe := {
		"amount": host.budget(40),
		"lifetime": 1.0,
		"size": 0.2,
		"one_shot": true,
		"explosiveness": 0.95,
		"spread": 180.0,
		"speed_min": 2.0,
		"speed_max": 5.5,
		"gravity": Vector3(0, -4.0, 0),
		"additive": false,
		"colors": [Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)],
	}
	var burst: CPUParticles3D = FX.emitter(burst_recipe)
	burst.name = "Burst"
	rig.add_child(burst)
	return rig


func reset_rig(rig: Node3D, entry: Dictionary) -> void:
	var palette: Array = THEMES.get(host.theme(), THEMES.sand)
	(rig.get_node("Dust") as CPUParticles3D).color = palette[0]
	(rig.get_node("Burst") as CPUParticles3D).color = palette[1]
	(rig.get_node("Dust") as CPUParticles3D).emitting = false
	rig.set_meta("burst", false)
	rig.set_meta("dust_on", false)
	if rig.has_meta("frozen_base"):
		rig.remove_meta("frozen_base")
	rig.set_meta("last_at", host.track_global(float(entry.progress), float(entry.lateral), 0.0))


func _base(entry: Dictionary) -> Vector3:
	if str(entry.phase) == "fly":
		var at: Vector3 = host.track_global(float(entry.progress), float(entry.lateral), 0.0)
		if float(entry.age) < 0.15:
			var start: Vector3 = host.kart(int(entry.owner)).global_position
			at = start.lerp(at, smoothstep(0.0, 1.0, float(entry.age) / 0.15))
		return at
	var key: int = int(entry.target)
	if str(entry.result) != "fizzled" and host._valid_key(key):
		return host.kart(key).global_position
	return host.track_global(float(entry.progress), float(entry.lateral), 0.0)


func _draw(entry: Dictionary, rig: Node3D) -> void:
	var reduced: bool = host.reduced_motion
	var age: float = float(entry.age)
	var flying: bool = str(entry.phase) == "fly"
	var base: Vector3 = (
		_base(entry) if flying or not rig.has_meta("frozen_base") else rig.get_meta("frozen_base")
	)
	if not flying and not rig.has_meta("frozen_base"):
		rig.set_meta("frozen_base", base)
	var up: Vector3 = host.track_basis(float(entry.progress)).y.normalized()
	var since: float = 0.0 if flying else age - float(entry.get("hit_at", age))
	var collapse: float = 0.0 if flying else clampf(since / 0.45, 0.0, 1.0)
	var grow: float = smoothstep(0.0, 0.3, age)
	var palette: Array = THEMES.get(host.theme(), THEMES.sand)
	var spin: float = 0.45 if reduced else age * 3.8
	var veil := rig.get_node("WindSheets") as MeshInstance3D
	veil.visible = grow > 0.001 and collapse < 1.0
	if veil.visible:
		var axes := Basis(Vector3.UP, spin).scaled(Vector3(grow, grow * (1.0-collapse*0.5), grow))
		veil.global_transform = Transform3D(axes, base)
		(veil.material_override as StandardMaterial3D).albedo_color.a = 1.0-collapse
	# Trichter: drei drehende Windbänder, unten schmal, oben weit.
	var lines: Array = []
	var bands: int = 3 if host.quality != "low" else 2
	var steps: int = 18
	for b in range(bands):
		var points := PackedVector3Array()
		for s in range(steps + 1):
			var t: float = float(s) / float(steps)
			var radius: float = lerpf(0.26, 1.7, t * t) * grow * (1.0 + collapse * 1.5)
			var angle: float = spin + t * TAU * 1.6 + TAU * b / bands
			var sway: Vector3 = (
				Vector3(sin(age * 3.0 + t * 2.0), 0.0, cos(age * 2.3 + t)) * 0.18 * t
			)
			if reduced:
				sway = Vector3.ZERO
			points.append(
				(
					base
					+ up * (t * HEIGHT * grow * (1.0 - collapse * 0.4))
					+ Vector3(cos(angle), 0.0, sin(angle)) * radius
					+ sway
				)
			)
		var alpha: float = (0.75 - 0.2 * b) * (1.0 - collapse)
		lines.append({"points": points, "width": 1.0, "color": Color(0.92, 0.98, 1.0, alpha)})
		lines.append({"points": points, "width": 2.4, "color": Color(palette[0], alpha * 0.35)})
	var funnel_mesh: ImmediateMesh = (rig.get_node("Funnel") as MeshInstance3D).mesh
	if collapse < 1.0:
		FX.ribbons(funnel_mesh, lines, host.eye(), 0.16, Color.WHITE, Transform3D.IDENTITY)
	else:
		funnel_mesh.clear_surfaces()
	# Streckenteilchen kreisen im Trichter (nach dem Einschlag: fliegen aus und sinken).
	var leaves: ImmediateMesh = (rig.get_node("Debris") as MeshInstance3D).mesh
	leaves.clear_surfaces()
	leaves.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = host.budget(DEBRIS)
	for k in range(count):
	var foliage := [Color("3c7456"), Color("a9ba58"), Color("ce8345"), Color("487f6b")]
		var h: float = fmod(float(k) * 0.618, 1.0)
		var angle: float = spin * (1.2 - h * 0.5) + float(k) * 2.4
		var outward := Vector3(cos(angle), 0, sin(angle))
		var radius := lerpf(0.45, 1.9, h*h) * grow
		var p := base + up*(0.22 + h*HEIGHT*0.9) + outward*radius
		if not flying:
			p += outward*since*(2.5+h*2.0) + up*(since*2.0-since*since*5.0)
		var tangent := outward.cross(up)*0.24 + up*(0.12*sin(angle))
		var vein := up*0.115 + outward*0.055
		var centre := p + outward*0.085
		var tint: Color = foliage[k % foliage.size()]
		tint.a = 1.0-clampf((since-0.5)/0.8, 0.0, 1.0)
		for half in [1.0, -1.0]:
			leaves.surface_set_color(tint if half > 0 else tint.lightened(0.28))
			for vertex in [p-tangent, centre, p+vein*float(half), p+vein*float(half), centre, p+tangent]:
				leaves.surface_add_vertex(vertex)
	leaves.surface_end()
	var dust: CPUParticles3D = rig.get_node("Dust")
	dust.global_position = base + up * 0.1
	if flying and not bool(rig.get_meta("dust_on", false)) and host.quality != "low":
		rig.set_meta("dust_on", true)
		dust.restart()
	dust.emitting = flying and host.quality != "low"
	if not flying and not bool(rig.get_meta("burst", false)):
		rig.set_meta("burst", true)
		FX.burst(rig.get_node("Burst"), base + up * 1.0, Vector3.UP)

## Three torn, translucent helical sheets outline a hollow funnel even against a bright sky.
static func _wind_sheets(low: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 20 if low else 32
	for band in range(2 if low else 3):
		var previous := PackedVector3Array()
		for i in range(steps+1):
			var t := float(i)/steps
			var angle := TAU * (1.18*t + band/3.0)
			var radius := 0.19 + 1.48*t*t
			var centre := Vector3(cos(angle)*radius + 0.26*t, HEIGHT*t, sin(angle)*radius)
			var half_width := Vector3.UP * (0.08+0.22*t) * sin(PI*t)
			var next := PackedVector3Array([centre-half_width, centre+half_width])
			if not previous.is_empty():
				var tint := Color("638a93").lerp(Color("cce7da"), t)
				tint.a = 0.75 - 0.28*t
				for vertex in [previous[0], previous[1], next[1], previous[0], next[1], next[0]]:
					surface.set_color(tint)
					surface.add_vertex(vertex)
			previous = next
	return surface.commit()
