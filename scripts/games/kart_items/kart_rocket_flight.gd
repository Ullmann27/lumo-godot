extends Node3D
## Inszenierung der Sternraketen (nur Darstellung, keine Spielregel):
##  - Abschuss: Mündungsblitz + Rauchstoß an der Halterdüse
##  - Flug: dichte, sich auflösende Rauchspur (Band zur Kamera) mit Glutkern, Eigenlicht
##  - Einschlag: Blitz, Rauchwolke, Funken
##  - Treffer: getroffener Rivale wirbelt in die Luft und landet (Anzeige-Versatz über den
##    Bild-Glätter, die Spiellogik sieht ihn nie); das Kind selbst nur ein kleiner Hüpfer
##  - Zuschauen: Kamera zieht leicht auf, solange die eigene Rakete fliegt und das Ziel im
##    Bild ist; ist es außerhalb, zeigt ein kleines „Trefferbild“ den Einschlag
## „Ruhige Bewegung“: kein Wirbel, kein Aufziehen, kein Trefferbild, kleinere Blitze.
## Budget je Profil (low/medium/high), alles gl_compatibility-tauglich (keine Bildschirm-
## oder Tiefentextur, nur weiche Billboards und CPU-Partikel mit Obergrenze).

const PARTICLE_QUAD = preload("res://scripts/systems/particle_quad.gd")
const PODS = preload("res://scripts/games/kart_items/kart_rocket_pods.gd")
const ROCKET_SCALE: float = 2.1
## Rauchspur: Lebensdauer (s) und Punktbudget je Profil.
const SMOKE_LIFE: float = 1.5
const CORE_LIFE: float = 0.3
const TRAIL_POINTS: Dictionary = {"low": 22, "medium": 40, "high": 60}
const IMPACT_SMOKE: Dictionary = {"low": 8, "medium": 14, "high": 20}
const IMPACT_SPARKS: Dictionary = {"low": 12, "medium": 22, "high": 32}
const MUZZLE_PUFFS: Dictionary = {"low": 5, "medium": 8, "high": 12}
const MAX_TRAILS: int = 8
const IMPACT_POOL: int = 2
const MUZZLE_POOL: int = 4
## Wirbel des getroffenen Rivalen (Anteil der Drehzeit): Flug, Aufsetzer, Ausrollen.
const TUMBLE_HEIGHT: float = 1.7
const TUMBLE_AIR: float = 0.7
const TUMBLE_BOUNCE_END: float = 0.84
const TUMBLE_PIVOT: float = 0.55
## Das Kind selbst: kurzer, milder Hüpfer ohne Überschlag.
const MILD_HEIGHT: float = 0.5
const MILD_AIR: float = 0.5
## Kamera-Aufziehen (m nach oben / hinten) und Trefferbild.
const ASSIST_UP: float = 0.45
const ASSIST_BACK: float = 1.1
const PIP_SECONDS: float = 1.75
const PIP_LEAD: float = 0.4
## Ab dieser Entfernung (m) zur Kamera ist ein Einschlag zu klein: Trefferbild zeigen.
const PIP_FAR: float = 30.0

var host: Node
var quality: String = "medium"
var reduced_motion: bool = false
## key (-1 = Kind, 0.. = Rivale) -> {age, total, kind}
var tumbles: Dictionary = {}
var assist: float = 0.0
var pip_time: float = 0.0
var pip_target: int = -99
var pip_shown_frames: int = 0
var stats := {
	"trails": 0, "impacts": 0, "muzzles": 0, "tumbles": 0, "pip": 0, "max_trail_points": 0
}
var _trails: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []
var _muzzles: Array[Dictionary] = []
var _impact_cursor: int = 0
var _muzzle_cursor: int = 0
var _smoke_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _flash_mesh: Mesh
var _puff_mesh: ArrayMesh
var _spark_mesh: ArrayMesh
var _pip_frame: Control
var _pip_viewport: SubViewport
var _pip_camera: Camera3D
var _assist_watch: float = 0.0
var _last_rocket_distance: float = -1.0


func setup(owner_race: Node, profile: String, reduced: bool) -> void:
	host = owner_race
	quality = profile if profile in TRAIL_POINTS else "medium"
	reduced_motion = reduced
	name = "KartRocketFlight"
	if _impacts.is_empty():
		_build_pools()


func clear() -> void:
	for trail in _trails:
		if is_instance_valid(trail.smoke):
			trail.smoke.queue_free()
		if is_instance_valid(trail.core):
			trail.core.queue_free()
	_trails.clear()
	tumbles.clear()
	assist = 0.0
	pip_time = 0.0
	pip_target = -99
	_hide_pip()


func trail_count() -> int:
	return _trails.size()


func trail_point_total() -> int:
	var total: int = 0
	for trail in _trails:
		total += trail.points.size()
	return total


# --- Materialien und Pools ------------------------------------------------------------


static func soft_band_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.add_point(0.5, Color(1, 1, 1, 1))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 4
	return texture


static func soft_dot_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.add_point(0.45, Color(1, 1, 1, 0.55))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 48
	texture.height = 48
	return texture


func _billboard_material(additive: bool, texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _build_pools() -> void:
	var band := soft_band_texture()
	var dot := soft_dot_texture()
	_smoke_material = StandardMaterial3D.new()
	_smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke_material.vertex_color_use_as_albedo = true
	_smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smoke_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_smoke_material.albedo_texture = band
	_core_material = _smoke_material.duplicate()
	_core_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_puff_mesh = PARTICLE_QUAD.make(Vector2(1.3, 1.3))
	_puff_mesh.surface_set_material(0, _billboard_material(false, dot))
	_spark_mesh = PARTICLE_QUAD.make(Vector2(0.16, 0.16))
	_spark_mesh.surface_set_material(0, _billboard_material(true, dot))
	var flash := PARTICLE_QUAD.make(Vector2(1.0, 1.0))
	var flash_material := _billboard_material(true, dot)
	flash_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash_material.billboard_keep_scale = true
	flash.surface_set_material(0, flash_material)
	_flash_mesh = flash
	for index in range(IMPACT_POOL):
		var impact := {
			"flash": _flash_node("ImpactFlash%d" % index),
			"smoke": _burst("ImpactSmoke%d" % index, _puff_mesh, int(IMPACT_SMOKE[quality]), 1.7),
			"sparks":
			_burst("ImpactSparks%d" % index, _spark_mesh, int(IMPACT_SPARKS[quality]), 0.6),
			"light": _flash_light("ImpactLight%d" % index),
			"age": 9.0,
			"size": 3.6,
		}
		_style_impact(impact)
		_impacts.append(impact)
	for index in range(MUZZLE_POOL):
		var muzzle := {
			"flash": _flash_node("MuzzleFlash%d" % index),
			"smoke": _burst("MuzzleSmoke%d" % index, _puff_mesh, int(MUZZLE_PUFFS[quality]), 0.9),
			"age": 9.0,
			"size": 1.5,
		}
		_style_muzzle(muzzle)
		_muzzles.append(muzzle)


func _flash_node(node_name: String) -> MeshInstance3D:
	var flash := MeshInstance3D.new()
	flash.name = node_name
	flash.mesh = _flash_mesh
	# Eigenes Material je Blitz: das Ausblenden läuft über Alpha (gl_compatibility-sicher).
	var material := (_flash_mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	material.albedo_color = Color(1.0, 0.9, 0.68, 1.0)
	flash.material_override = material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.top_level = true
	flash.visible = false
	add_child(flash)
	return flash


func _flash_light(node_name: String) -> OmniLight3D:
	if quality == "low":
		return null
	var light := OmniLight3D.new()
	light.name = node_name
	light.light_color = Color("ffc070")
	light.omni_range = 6.0
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.top_level = true
	light.visible = false
	add_child(light)
	return light


func _burst(node_name: String, mesh: Mesh, amount: int, lifetime: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = node_name
	particles.emitting = false
	particles.one_shot = true
	# Alle Teilchen auf einmal: mit < 1,0 zeigt gl_compatibility die noch nicht
	# ausgestoßenen Teilchen kurz als schwarze Scheibe am Auslöser (im Bild gefunden).
	particles.explosiveness = 1.0
	particles.lifetime_randomness = 0.35
	particles.amount = maxi(2, amount)
	particles.lifetime = lifetime
	particles.mesh = mesh
	particles.local_coords = false
	particles.top_level = true
	add_child(particles)
	return particles


func _style_impact(impact: Dictionary) -> void:
	var smoke: CPUParticles3D = impact.smoke
	smoke.direction = Vector3.UP
	smoke.spread = 180.0
	smoke.initial_velocity_min = 1.2
	smoke.initial_velocity_max = 3.6
	smoke.damping_min = 2.0
	smoke.damping_max = 3.2
	smoke.gravity = Vector3(0, 0.9, 0)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.6
	smoke.scale_amount_min = 0.9
	smoke.scale_amount_max = 1.5
	smoke.scale_amount_curve = _curve([Vector2(0, 0.5), Vector2(0.3, 1.4), Vector2(1, 2.4)])
	smoke.color_ramp = _ramp(
		[
			[0.0, Color(1.0, 0.86, 0.5, 0.95)],
			[0.12, Color(0.98, 0.58, 0.32, 0.85)],
			[0.35, Color(0.62, 0.6, 0.68, 0.7)],
			[1.0, Color(0.78, 0.78, 0.86, 0.0)],
		]
	)
	var sparks: CPUParticles3D = impact.sparks
	sparks.direction = Vector3.UP
	sparks.spread = 85.0
	sparks.explosiveness = 1.0
	sparks.initial_velocity_min = 6.0
	sparks.initial_velocity_max = 13.0
	sparks.gravity = Vector3(0, -14.0, 0)
	sparks.scale_amount_min = 0.7
	sparks.scale_amount_max = 1.6
	sparks.color_ramp = _ramp(
		[
			[0.0, Color(1.0, 1.0, 0.85, 1.0)],
			[0.35, Color(1.0, 0.75, 0.3, 1.0)],
			[1.0, Color(1.0, 0.35, 0.15, 0.0)],
		]
	)


func _style_muzzle(muzzle: Dictionary) -> void:
	var smoke: CPUParticles3D = muzzle.smoke
	smoke.direction = Vector3(0, 0.3, 1)
	smoke.spread = 40.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 3.0
	smoke.damping_min = 2.5
	smoke.damping_max = 4.0
	smoke.gravity = Vector3(0, 0.6, 0)
	smoke.scale_amount_min = 0.4
	smoke.scale_amount_max = 0.8
	smoke.scale_amount_curve = _curve([Vector2(0, 0.6), Vector2(1, 1.8)])
	smoke.color_ramp = _ramp(
		[
			[0.0, Color(1.0, 0.85, 0.55, 0.9)],
			[0.25, Color(0.85, 0.85, 0.92, 0.6)],
			[1.0, Color(0.9, 0.9, 0.96, 0.0)],
		]
	)


static func _curve(points: Array) -> Curve:
	var curve := Curve.new()
	curve.max_value = 3.0
	for point in points:
		curve.add_point(point)
	return curve


static func _ramp(stops: Array) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, stops[0][1])
	gradient.set_offset(0, stops[0][0])
	gradient.set_color(1, stops[-1][1])
	gradient.set_offset(1, stops[-1][0])
	for i in range(1, stops.size() - 1):
		gradient.add_point(stops[i][0], stops[i][1])
	return gradient


# --- Ereignisse aus dem Rennen --------------------------------------------------------


## Ein Treffer/Abprall aus kart_item_runtime: Einschlag-Effekt und ggf. Wirbel.
func on_item_event(event: Dictionary, rocket: bool) -> void:
	var kind: String = str(event.get("type", ""))
	var at: Vector3 = event.get("position", Vector3.ZERO)
	if not rocket or kind not in ["hit", "blocked", "intercepted"]:
		return
	# Am eigenen Kart (Kind getroffen) bleibt der Einschlag klein: kein Bild voller Blitz.
	var mild: bool = int(event.get("target", -99)) == -1
	impact(at, (0.4 if mild else 1.0) if kind == "hit" else 0.6)


## Startet den Wirbel eines getroffenen Fahrers (key -1 = Kind). total = Drehzeit (s).
func start_tumble(key: int, total: float, rocket: bool) -> void:
	start_response(key, "mild" if key == -1 else ("rocket" if rocket else "spin"), total)
	if key >= 0 and rocket:
		_assist_watch = maxf(_assist_watch, total)


func start_response(key: int, kind: String, seconds: float, direction: float = 1.0) -> void:
	tumbles[key] = {"age": 0.0, "total": clampf(seconds, .3, 1.2), "kind": kind, "direction": direction}
	stats.tumbles += 1


func impact(at: Vector3, strength: float = 1.0) -> void:
	if _impacts.is_empty() or at == Vector3.ZERO:
		return
	var pack: Dictionary = _impacts[_impact_cursor]
	_impact_cursor = (_impact_cursor + 1) % _impacts.size()
	pack.age = 0.0
	pack.size = (2.2 if reduced_motion else 4.0) * strength
	var flash: MeshInstance3D = pack.flash
	flash.global_position = at
	flash.visible = true
	for key in ["smoke", "sparks"]:
		var particles: CPUParticles3D = pack[key]
		# Milder Einschlag (am eigenen Kart): auch Rauch und Funken kleiner.
		if not particles.has_meta("base_scale"):
			particles.set_meta(
				"base_scale", Vector2(particles.scale_amount_min, particles.scale_amount_max)
			)
		var base: Vector2 = particles.get_meta("base_scale")
		var k := clampf(strength, 0.4, 1.0)
		particles.scale_amount_min = base.x * k
		particles.scale_amount_max = base.y * k
		particles.global_position = at
		particles.restart()
		particles.emitting = true
	if pack.light != null:
		(pack.light as OmniLight3D).global_position = at + Vector3.UP * 0.6
		(pack.light as OmniLight3D).visible = true
	stats.impacts += 1


func muzzle(at: Transform3D) -> void:
	if _muzzles.is_empty():
		return
	var pack: Dictionary = _muzzles[_muzzle_cursor]
	_muzzle_cursor = (_muzzle_cursor + 1) % _muzzles.size()
	pack.age = 0.0
	pack.size = 1.0 if reduced_motion else 1.6
	var flash: MeshInstance3D = pack.flash
	flash.global_position = at.origin
	flash.visible = true
	var smoke: CPUParticles3D = pack.smoke
	smoke.global_transform = at
	smoke.restart()
	smoke.emitting = true
	stats.muzzles += 1


# --- Wirbel / Hüpfer als Anzeige-Versatz -------------------------------------------------


## Anzeige-Versatz eines Fahrers in Kart-Raum für den Anteil u (0..1) der Drehzeit.
## Rakete auf Rivalen: hoch (~1,9 m), eine Rolle um die Längsachse, Aufsetzer, steht.
## mild (das Kind): kleiner Hüpfer ohne Rolle. reduced: nichts (nur der alte Rutscher).
static func tumble_offset(u: float, kind: String, reduced: bool, direction: float = 1.0) -> Transform3D:
	if reduced or u <= 0.0 or u >= 1.0:
		return Transform3D.IDENTITY
	var lift: float = 0.0
	var roll: float = 0.0
	var pitch: float = 0.0
	if kind == "rocket":
		if u < TUMBLE_AIR:
			var s: float = u / TUMBLE_AIR
			lift = TUMBLE_HEIGHT * 4.0 * s * (1.0 - s)
			# Die Rolle ist fertig, bevor das Kart tief genug für Bodenkontakt wäre.
			roll = TAU * smoothstep(0.06, 0.6, u)
			pitch = -0.32 * sin(PI * s)
		elif u < TUMBLE_BOUNCE_END:
			lift = 0.2 * sin(PI * (u - TUMBLE_AIR) / (TUMBLE_BOUNCE_END - TUMBLE_AIR))
			roll = TAU
	elif kind == "mild":
		if u < MILD_AIR:
			var m: float = u / MILD_AIR
			lift = MILD_HEIGHT * 4.0 * m * (1.0 - m)
			pitch = -0.12 * sin(PI * m)
		elif u < MILD_AIR + 0.12:
			lift = 0.06 * sin(PI * (u - MILD_AIR) / 0.12)
	var yaw := 0.0
	if kind in ["thunder_star", "whirlwind", "star_magnet"]:
		# A short anticipation, one clean arc, then damped suspension travel.
		var airborne := clampf((u - .08) / .62, 0.0, 1.0)
		var arc := sin(PI * airborne)
		var landing := clampf((u - .70) / .30, 0.0, 1.0)
		var rebound := sin(TAU * landing) * (1.0 - landing) * (1.0 - landing)
		var spring := sin(PI * clampf(u / .08, 0.0, 1.0))
		match kind:
			"thunder_star":
				lift = .46 * arc + .07 * absf(rebound)
				pitch = -.19 * arc + .12 * spring + .09 * rebound
				roll = .12 * sin(airborne * TAU * 2.0) * arc
			"whirlwind":
				lift = .78 * arc + .09 * absf(rebound)
				yaw = direction * .98 * sin(TAU * airborne) * arc
				roll = direction * (.22 * arc - .09 * rebound)
			"star_magnet":
				lift = .19 * arc + .035 * absf(rebound)
				roll = direction * (.28 * arc - .11 * spring - .13 * rebound)
				yaw = direction * .18 * arc
	var pivot := Vector3(0.0, TUMBLE_PIVOT, 0.0)
	var turn := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, roll) * Basis(Vector3.RIGHT, pitch)
	# Um den Schwerpunkt drehen, dann anheben.
	return (
		Transform3D(Basis.IDENTITY, pivot + Vector3.UP * lift)
		* Transform3D(turn, Vector3.ZERO)
		* Transform3D(Basis.IDENTITY, -pivot)
	)


## Für den Bild-Glätter: Anzeige-Versatz eines Knotens (Kart oder Kamera) oder null.
func offset_for(node: Node3D) -> Variant:
	if not is_instance_valid(host):
		return null
	if node == host.camera:
		return _camera_offset()
	var key: int = _racer_key(node)
	if key < -1 or not tumbles.has(key):
		return null
	var record: Dictionary = tumbles[key]
	return tumble_offset(float(record.age) / float(record.total), str(record.kind), reduced_motion, float(record.direction))



func _camera_offset() -> Variant:
	if assist <= 0.001:
		return null
	var eased: float = assist * assist * (3.0 - 2.0 * assist)
	return Transform3D(Basis.IDENTITY, Vector3(0.0, ASSIST_UP * eased, ASSIST_BACK * eased))


## -1 = Kind, 0.. = Rivale, -2 = kein Fahrer.
func _racer_key(node: Node3D) -> int:
	if node == host.player:
		return -1
	var index: int = 0
	for kart in host.opponents:
		if kart == node:
			return index
		index += 1
	return -2


## Größte momentane Anzeige-Hebung eines Fahrers (m), für Tests und Messung.
func tumble_lift(key: int) -> float:
	if not tumbles.has(key):
		return 0.0
	var record: Dictionary = tumbles[key]
	var u: float = float(record.age) / float(record.total)
	return tumble_offset(u, str(record.kind), reduced_motion, float(record.direction)).origin.y


# --- Physiktakt: Wirbel-Uhr, Kamera-Hilfe, Trefferbild, Fluggeräusch ------------------------


func tick(delta: float) -> void:
	# „Ruhige Bewegung“ kann mitten im Rennen umgeschaltet werden.
	if is_instance_valid(host):
		reduced_motion = bool(host.get("reduced_motion"))
	for key in tumbles.keys():
		tumbles[key].age = float(tumbles[key].age) + delta
		if float(tumbles[key].age) >= float(tumbles[key].total):
			tumbles.erase(key)
	_assist_watch = maxf(0.0, _assist_watch - delta)
	var own: Dictionary = _own_rocket()
	var want_assist: bool = false
	var want_pip: int = -99
	if not own.is_empty():
		var target: int = int(own.target)
		if target >= 0 and target < host.opponents.size():
			var target_pos: Vector3 = host.opponents[target].global_position + Vector3.UP * 0.6
			var visible_on_screen: bool = _on_main_screen(target_pos)
			want_assist = visible_on_screen
			var eta: float = _closing_eta(own, delta)
			# Außerhalb des Bildes oder so weit weg, dass der Einschlag winzig wäre.
			var far: bool = host.camera.global_position.distance_to(target_pos) > PIP_FAR
			if (not visible_on_screen or far) and eta < PIP_LEAD:
				want_pip = target
	elif _assist_watch > 0.0:
		want_assist = true
	if reduced_motion:
		want_assist = false
		want_pip = -99
	assist = move_toward(
		assist, 1.0 if want_assist else 0.0, delta / (0.35 if want_assist else 0.6)
	)
	if want_pip >= 0 and pip_time <= 0.0:
		pip_target = want_pip
		pip_time = PIP_SECONDS
		stats.pip += 1
	if pip_time > 0.0:
		pip_time = maxf(0.0, pip_time - delta)
		if pip_time <= 0.0 or reduced_motion:
			pip_time = 0.0
			_hide_pip()
		else:
			_update_pip()
	_feed_flight_sound(delta)


## Sekunden bis zum Einschlag aus der echten Annäherung (Rakete minus Ziel je Takt).
func _closing_eta(entry: Dictionary, delta: float) -> float:
	var gap: float = float(entry.get("to_target", INF))
	var before: float = float(entry.get("flight_gap_before", gap))
	entry["flight_gap_before"] = gap
	var closing: float = (before - gap) / maxf(delta, 0.001)
	if gap == INF or closing <= 0.5:
		return INF
	return gap / closing


## Wird gerade ein Trefferbild gezeigt?
func pip_visible() -> bool:
	return is_instance_valid(_pip_frame) and _pip_frame.visible


func _own_rocket() -> Dictionary:
	if not is_instance_valid(host) or not is_instance_valid(host.item_runtime):
		return {}
	for entry in host.item_runtime.projectiles:
		if str(entry.kind) == "homing" and int(entry.owner) == -1 and int(entry.target) >= 0:
			return entry
	return {}


func _on_main_screen(point: Vector3) -> bool:
	var camera: Camera3D = host.camera
	if not is_instance_valid(camera) or camera.is_position_behind(point):
		return false
	var screen: Vector2 = camera.unproject_position(point)
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	return Rect2(Vector2(size.x * 0.04, size.y * 0.06), size * Vector2(0.92, 0.88)).has_point(
		screen
	)


func _feed_flight_sound(delta: float) -> void:
	var audio: Node = host.get("kart_audio") if is_instance_valid(host) else null
	if not is_instance_valid(audio) or not is_instance_valid(host.camera):
		return
	var nearest: float = INF
	for entry in host.item_runtime.projectiles if is_instance_valid(host.item_runtime) else []:
		if (
			str(entry.kind) == "homing"
			and is_instance_valid(entry.node)
			and (entry.node as Node3D).is_inside_tree()
		):
			nearest = minf(
				nearest,
				host.camera.global_position.distance_to((entry.node as Node3D).global_position)
			)
	if nearest == INF:
		_last_rocket_distance = -1.0
		return
	# Lauter und heller, je näher die Rakete ist; leicht höher beim Herankommen.
	var closing: float = (
		0.0
		if _last_rocket_distance < 0.0
		else (_last_rocket_distance - nearest) / maxf(delta, 0.001)
	)
	_last_rocket_distance = nearest
	var gain: float = clampf(1.15 - nearest / 45.0, 0.12, 1.0)
	var pitch: float = clampf(
		1.0 + closing / 140.0 + (1.0 - clampf(nearest / 45.0, 0.0, 1.0)) * 0.12, 0.8, 1.3
	)
	if audio.has_method("set_loop"):
		audio.set_loop("rocket_fly", gain, pitch)


# --- Trefferbild (Bild-im-Bild) --------------------------------------------------------


func _ensure_pip() -> void:
	if is_instance_valid(_pip_frame) or not is_instance_valid(host):
		return
	var parent: Control = host.get("safe_ui")
	if not is_instance_valid(parent):
		return
	_pip_frame = PanelContainer.new()
	_pip_frame.name = "RocketHitCam"
	_pip_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("071428")
	style.border_color = Color("ffd23f")
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(4)
	_pip_frame.add_theme_stylebox_override("panel", style)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pip_frame.add_child(container)
	_pip_viewport = SubViewport.new()
	_pip_viewport.name = "HitCamViewport"
	_pip_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_pip_viewport.msaa_3d = Viewport.MSAA_DISABLED
	container.add_child(_pip_viewport)
	_pip_camera = Camera3D.new()
	_pip_camera.name = "HitCam"
	_pip_camera.fov = 48.0
	_pip_camera.far = 260.0
	_pip_viewport.add_child(_pip_camera)
	var label := Label.new()
	label.text = "TREFFER-BLICK"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("ffd23f"))
	label.add_theme_color_override("font_outline_color", Color("071428"))
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(12, 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label)
	parent.add_child(_pip_frame)
	_pip_frame.visible = false


func _update_pip() -> void:
	_ensure_pip()
	if not is_instance_valid(_pip_frame) or pip_target < 0 or pip_target >= host.opponents.size():
		return
	var parent_size: Vector2 = (_pip_frame.get_parent() as Control).size
	var width: float = clampf(parent_size.x * 0.27, 220.0, 520.0)
	var frame_size := Vector2(width, width * 9.0 / 16.0)
	_pip_frame.size = frame_size + Vector2(8, 8)
	# Oben links unter der Kopfzeile: Karte, Item-Tasten und Lenkrad bleiben frei.
	_pip_frame.position = Vector2(18.0, parent_size.y * 0.12)
	(_pip_viewport.get_parent() as Control).custom_minimum_size = frame_size
	var kart: Node3D = host.opponents[pip_target]
	var forward: Vector3 = -kart.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.1 else Vector3.FORWARD
	var side: Vector3 = forward.cross(Vector3.UP).normalized()
	# Ruhiger Blick seitlich von vorn auf den Rivalen; folgt nur seiner Fahrt.
	var focus: Vector3 = (
		host.world.position_at(host.opponent_distances[pip_target], host.opponent_lanes[pip_target])
		+ Vector3.UP * 1.1
	)
	var eye: Vector3 = focus + forward * 6.5 + side * 4.0 + Vector3.UP * 2.2
	_pip_camera.global_transform = Transform3D(Basis.looking_at(focus - eye, Vector3.UP), eye)
	_pip_camera.current = true
	_pip_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var fade: float = clampf(minf(PIP_SECONDS - pip_time, pip_time) / 0.18, 0.0, 1.0)
	_pip_frame.modulate.a = fade
	_pip_frame.visible = true
	pip_shown_frames += 1


func _hide_pip() -> void:
	if is_instance_valid(_pip_frame):
		_pip_frame.visible = false
	if is_instance_valid(_pip_viewport):
		_pip_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


# --- Je gerendertem Bild: Rauchspuren, Blitze ---------------------------------------------


func _process(delta: float) -> void:
	if not is_instance_valid(host):
		return
	_sync_trails()
	var camera: Camera3D = get_viewport().get_camera_3d()
	var eye: Vector3 = camera.global_position if is_instance_valid(camera) else Vector3.ZERO
	var keep: Array[Dictionary] = []
	for trail in _trails:
		if _advance_trail(trail, delta, eye):
			keep.append(trail)
	_trails = keep
	for pack in _impacts:
		_advance_flash(pack, delta, 0.32)
		if pack.light != null:
			var light: OmniLight3D = pack.light
			light.light_energy = maxf(0.0, 5.0 * (1.0 - float(pack.age) / 0.3))
			light.visible = light.light_energy > 0.02
	for pack in _muzzles:
		_advance_flash(pack, delta, 0.14)


func _advance_flash(pack: Dictionary, delta: float, life: float) -> void:
	var flash: MeshInstance3D = pack.flash
	if float(pack.age) > life:
		flash.visible = false
		return
	pack.age = float(pack.age) + delta
	var t: float = clampf(float(pack.age) / life, 0.0, 1.0)
	var grow: float = 1.0 - pow(1.0 - minf(1.0, t * 2.5), 3.0)
	flash.scale = Vector3.ONE * maxf(0.05, float(pack.size) * (0.3 + 0.7 * grow))
	(flash.material_override as StandardMaterial3D).albedo_color.a = 1.0 - t * t


func _sync_trails() -> void:
	if not is_instance_valid(host.item_runtime):
		return
	for entry in host.item_runtime.projectiles:
		if str(entry.kind) != "homing" or not is_instance_valid(entry.node):
			continue
		var node: Node3D = entry.node
		if node.has_meta("flight_trail"):
			continue
		if _trails.size() >= MAX_TRAILS:
			break
		node.set_meta("flight_trail", true)
		var trail := {
			"source": node,
			"points": [],
			"smoke": _ribbon("RocketSmokeTrail", _smoke_material),
			"core": _ribbon("RocketGlowCore", _core_material),
			"spacing": 0.0,
		}
		_trails.append(trail)
		stats.trails += 1
		if quality != "low":
			var light := OmniLight3D.new()
			light.name = "RocketGlow"
			light.light_color = Color("ffb35c")
			light.light_energy = 1.4
			light.omni_range = 3.2
			light.shadow_enabled = false
			light.position = Vector3(0, 0, PODS.NOZZLE_Z * ROCKET_SCALE + 0.3)
			node.add_child(light)
		var launch: Variant = entry.get("launch")
		if launch is Transform3D and float(entry.age) < 0.2:
			muzzle(launch)


func _ribbon(node_name: String, material: Material) -> MeshInstance3D:
	var ribbon := MeshInstance3D.new()
	ribbon.name = node_name
	ribbon.mesh = ImmediateMesh.new()
	ribbon.material_override = material
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon.top_level = true
	add_child(ribbon)
	return ribbon


## Ein Bild Rauchspur: neuen Punkt an der Düse, Punkte altern/steigen/zerfasern, Band neu.
## false = Spur ganz verraucht (Knoten werden freigegeben).
func _advance_trail(trail: Dictionary, delta: float, eye: Vector3) -> bool:
	var points: Array = trail.points
	for point in points:
		point.age = float(point.age) + delta
		point.position += (Vector3.UP * 0.35 + point.drift) * delta
	while not points.is_empty() and float(points[0].age) >= SMOKE_LIFE:
		points.pop_front()
	var source: Variant = trail.source
	var alive: bool = is_instance_valid(source) and (source as Node3D).is_inside_tree()
	if alive:
		# Ein abgeprallter Flugkörper hat kein Triebwerk mehr: die Spur hört auf.
		var exhaust := (source as Node3D).get_node_or_null("Exhaust") as Node3D
		if exhaust != null and not exhaust.visible:
			alive = false
	if alive:
		var nozzle: Vector3 = (
			(source as Node3D).global_transform * Vector3(0, 0, PODS.NOZZLE_Z * ROCKET_SCALE + 0.25)
		)
		var budget: int = int(TRAIL_POINTS[quality])
		var spacing: float = 0.28
		if points.size() >= 2:
			var span: float = float(points[-1].age) - float(points[0].age)
			spacing = (
				maxf(0.28, nozzle.distance_to(points[0].position) / maxf(1.0, budget - 2.0))
				if span > 0.0
				else spacing
			)
		if points.is_empty() or points[-1].position.distance_to(nozzle) >= spacing:
			var jitter := (
				Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1)) * 0.45
			)
			points.append({"position": nozzle, "age": 0.0, "drift": jitter})
			while points.size() > budget:
				points.pop_front()
		else:
			points[-1].position = nozzle
	stats.max_trail_points = maxi(int(stats.max_trail_points), points.size())
	if points.size() < 2:
		_clear_ribbon(trail)
		if not alive:
			trail.smoke.queue_free()
			trail.core.queue_free()
			return false
		return true
	_draw_ribbon(trail.smoke.mesh, points, eye, SMOKE_LIFE, false)
	_draw_ribbon(trail.core.mesh, points, eye, CORE_LIFE, true)
	return true


func _clear_ribbon(trail: Dictionary) -> void:
	(trail.smoke.mesh as ImmediateMesh).clear_surfaces()
	(trail.core.mesh as ImmediateMesh).clear_surfaces()


static func smoke_width(age: float) -> float:
	return 0.34 + 1.45 * sqrt(clampf(age / SMOKE_LIFE, 0.0, 1.0))


static func smoke_color(age: float) -> Color:
	var t: float = clampf(age / SMOKE_LIFE, 0.0, 1.0)
	var hot := Color(1.0, 0.78, 0.45, 0.95)
	var warm := Color(0.92, 0.66, 0.56, 0.92)
	var smoke := Color(0.74, 0.74, 0.82, 0.86)
	var colour: Color = (
		hot.lerp(warm, clampf(t / 0.06, 0.0, 1.0))
		if t < 0.06
		else warm.lerp(smoke, clampf((t - 0.06) / 0.2, 0.0, 1.0))
	)
	colour.a *= 1.0 - pow(t, 1.6)
	return colour


func _draw_ribbon(
	mesh: ImmediateMesh, points: Array, eye: Vector3, life: float, core: bool
) -> void:
	mesh.clear_surfaces()
	var first: int = 0
	while first < points.size() and float(points[first].age) >= life:
		first += 1
	if points.size() - first < 2:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(first, points.size()):
		var p: Vector3 = points[i].position
		var before: Vector3 = points[maxi(first, i - 1)].position
		var after: Vector3 = points[mini(points.size() - 1, i + 1)].position
		var tangent: Vector3 = after - before
		if tangent.length_squared() < 0.000001:
			tangent = Vector3.FORWARD
		var side: Vector3 = tangent.cross(eye - p)
		side = side.normalized() if side.length_squared() > 0.000001 else Vector3.RIGHT
		var age: float = float(points[i].age)
		var width: float
		var colour: Color
		if core:
			var c: float = clampf(age / life, 0.0, 1.0)
			width = 0.36 * (1.0 - c) + 0.06
			colour = Color(1.0, 0.82 - 0.35 * c, 0.42 - 0.2 * c, 1.0 - c)
		else:
			width = smoke_width(age)
			colour = smoke_color(age)
		# Die Spitze an der Düse läuft schmal zu.
		if i == points.size() - 1:
			width *= 0.4
		mesh.surface_set_color(colour)
		mesh.surface_set_uv(Vector2(0.0, 0.5))
		mesh.surface_add_vertex(p - side * width * 0.5)
		mesh.surface_set_color(colour)
		mesh.surface_set_uv(Vector2(1.0, 0.5))
		mesh.surface_add_vertex(p + side * width * 0.5)
	mesh.surface_end()
