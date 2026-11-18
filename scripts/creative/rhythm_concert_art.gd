class_name RhythmConcertArt
extends Node3D

## Konzertbühne der Rhythm Party: LED-Wand mit Takt-Visualisierung, Traversen,
## Moving Heads mit weichen Lichtkegeln, Lautsprechertürme, Podest für Lumo,
## Publikum aus den echten Mitspieler-Modellen, Konfetti, Treffer-Ringe,
## Taktlinien auf der Notenbahn und ein eigenes Farbthema je Tour-Bühne.
## Reine Optik: Timing, Spuren, Wertung und Speichern bleiben in rhythm_world.gd.
## Lichtbewegung bleibt unter 0,5 Hz, Helligkeitspuls unter 3 Hz; mit
## "Ruhige Bewegung" stehen Lichter und LED-Wand still.

const KIT = preload("res://scripts/creative/adventure_kit.gd")
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const LANE_COLORS = [Color("62dcff"), Color("b997ff"), Color("ffc985"), Color("77efbd")]
## Farbthemen: Wiesenbühne, Wolkenkonzert, Funkenfest, Mondfinale (TOUR.STAGES-Reihenfolge).
const THEMES = [
	{"a": Color("5ee8a8"), "b": Color("ffe27a"), "c": Color("9cf0ff"), "beam": Color("fff2b0"), "rim": Color("6cf0b0")},
	{"a": Color("8fd8ff"), "b": Color("ffb0e6"), "c": Color("ffffff"), "beam": Color("d8f0ff"), "rim": Color("9cd8ff")},
	{"a": Color("ff8a3a"), "b": Color("ffd24a"), "c": Color("ff5a6a"), "beam": Color("ffc070"), "rim": Color("ff9a40")},
	{"a": Color("6a7cff"), "b": Color("c08aff"), "c": Color("e8eeff"), "beam": Color("c8d0ff"), "rim": Color("9a8aff")},
]
const PERFORMER_AT := Vector3(0, 0, -30.5)

var reduced_motion := false
var led: MeshInstance3D
var led_mat: ShaderMaterial
var lane_mat: ShaderMaterial
var beams: Array[MeshInstance3D] = []
var heads: Array[Node3D] = []
var beam_mats: Array[ShaderMaterial] = []
var rim_mat: StandardMaterial3D
var confetti: GPUParticles3D
var rings: Array[MeshInstance3D] = []
var ring_age: Array[float] = []
var hold_glows: Array[MeshInstance3D] = []
var crowd: Array[Node3D] = []
var crowd_players: Array[AnimationPlayer] = []
var theme_index := 0
var _clock := 0.0
var _energy := 0.3
var _cheer_until := -1.0


func build(world: Node3D, reduce_motion: bool) -> void:
	reduced_motion = reduce_motion
	var tier := LumoQuality.tier()
	_led_wall()
	_riser()
	_truss_and_lights(tier)
	_speakers()
	_crowd(world, tier)
	_effects(tier)
	set_theme(0)


func _led_wall() -> void:
	led = MeshInstance3D.new()
	led.name = "RhythmLedWall"
	var quad := QuadMesh.new()
	quad.size = Vector2(17.0, 10.2)
	led.mesh = quad
	led.position = Vector3(0, 5.75, -33.33)
	led_mat = ShaderMaterial.new()
	led_mat.shader = KIT.shader("led_wall")
	led.material_override = led_mat
	led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(led)
	# Rahmen der LED-Wand
	var frame: Array[Transform3D] = []
	for y in [0.6, 10.9]:
		frame.append(Transform3D(Basis.from_scale(Vector3(17.6, 0.35, 0.5)), Vector3(0, y, -33.2)))
	for x in [-8.75, 8.75]:
		frame.append(Transform3D(Basis.from_scale(Vector3(0.35, 10.6, 0.5)), Vector3(x, 5.75, -33.2)))
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	BuildVoxelStyle.multimesh(self, "RhythmLedFrame", box, KIT.material("metal_dark"), frame)


func _riser() -> void:
	var riser := MeshInstance3D.new()
	riser.name = "LumoRiser"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 2.4
	cyl.height = 1.0
	cyl.radial_segments = 40
	riser.mesh = cyl
	riser.position = PERFORMER_AT + Vector3(0, 0.5, 0)
	var top := StandardMaterial3D.new()
	top.albedo_color = Color("1c1830")
	top.metallic = 0.6
	top.roughness = 0.25
	riser.material_override = top
	add_child(riser)
	var rim := MeshInstance3D.new()
	rim.name = "LumoRiserRim"
	var torus := TorusMesh.new()
	torus.inner_radius = 2.22
	torus.outer_radius = 2.4
	torus.rings = 48
	torus.ring_segments = 8
	rim.mesh = torus
	rim.position = PERFORMER_AT + Vector3(0, 0.99, 0)
	rim_mat = StandardMaterial3D.new()
	rim_mat.emission_enabled = true
	rim_mat.emission_energy_multiplier = 2.2
	rim.material_override = rim_mat
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)
	# Frontlicht auf Lumo (fest, ohne Schatten): Lumo ist der Star.
	var key := SpotLight3D.new()
	key.name = "LumoKeyLight"
	key.position = PERFORMER_AT + Vector3(0, 10.0, 13.0)
	key.look_at_from_position(key.position, PERFORMER_AT + Vector3(0, 5.5, 0), Vector3.UP)
	key.light_color = Color("fff0e0")
	key.light_energy = 3.2
	key.spot_range = 28.0
	key.spot_angle = 22.0
	key.shadow_enabled = false
	add_child(key)


func _truss_and_lights(tier: String) -> void:
	var truss: Array[Transform3D] = []
	for z in [-30.0, -15.5]:
		truss.append(KIT.xf(Vector3(0, 11.6, z)))
		for x in [-9.4, 9.4]:
			truss.append(Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis.from_scale(Vector3(0.64, 1.0, 1.0)), Vector3(x, 5.8, z)))
	KIT.scatter(self, "RhythmTruss3D", "stage", "truss_beam", truss, true)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.18
	cone.bottom_radius = 2.3
	cone.height = 11.0
	cone.radial_segments = 16
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var head_count := 4 if tier == "low" else 8
	for i in range(head_count):
		var row := i % 2
		var z := -30.0 if row == 0 else -15.5
		var x := -6.6 + float(i / 2) * (13.2 / float(maxi(1, head_count / 2 - 1)))
		var pivot := Node3D.new()
		pivot.name = "MovingHead%d" % i
		pivot.position = Vector3(x, 11.05, z)
		add_child(pivot)
		var model := KIT.place(pivot, "Body", "stage", "moving_head", Transform3D.IDENTITY, false)
		if model != null:
			model.scale = Vector3.ONE * 1.1
		var beam := MeshInstance3D.new()
		beam.name = "Beam"
		beam.mesh = cone
		beam.position = Vector3(0, -6.3, 0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bm := ShaderMaterial.new()
		bm.shader = KIT.shader("light_beam")
		bm.set_shader_parameter("intensity", 0.16)
		beam.material_override = bm
		pivot.add_child(beam)
		heads.append(pivot)
		beams.append(beam)
		beam_mats.append(bm)


func _speakers() -> void:
	var towers: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		towers.append(KIT.xf(Vector3(side * 7.4, 0, -27.5), side * -0.25 + PI, 1.25))
		towers.append(KIT.xf(Vector3(side * 10.6, 0, -19.5), side * -0.45 + PI, 1.05))
	KIT.scatter(self, "RhythmSpeakerTowers", "stage", "speaker_tower", towers, true)


func _crowd(world: Node3D, tier: String) -> void:
	var ids: Array[String] = []
	for entry in ROSTER.all():
		ids.append(str(entry.id))
	if ids.is_empty():
		return
	var spots: Array[Vector3] = [Vector3(-9.6, 0, -2.0), Vector3(9.6, 0, -2.0), Vector3(-10.8, 0, -7.5), Vector3(10.8, 0, -7.5), Vector3(-9.8, 0, -12.5)]
	if tier == "high":
		spots.append_array([Vector3(10.0, 0, -12.5), Vector3(-12.0, 0, 2.5), Vector3(12.0, 0, 2.5)])
	elif tier == "low":
		spots = spots.slice(0, 3)
	var level := 2 if tier == "low" else 1
	for i in range(spots.size()):
		var id := ids[i % ids.size()]
		var path := ROSTER.racing_model_path(id, level)
		if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
			continue
		var holder := Node3D.new()
		holder.name = "Fan_" + id + "_%d" % i
		holder.position = spots[i]
		add_child(holder)
		var model := (load(path) as PackedScene).instantiate() as Node3D
		holder.add_child(model)
		# Modelle schauen nach +Z; zum Podest drehen.
		var to_stage := PERFORMER_AT - spots[i]
		holder.rotation.y = atan2(to_stage.x, to_stage.z)
		holder.scale = Vector3.ONE * 2.3
		for node: Node in model.find_children("*", "AnimationPlayer", true, false):
			var player := node as AnimationPlayer
			if player.has_animation("idle"):
				player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
				if player.has_animation("celebrate"):
					player.get_animation("celebrate").loop_mode = Animation.LOOP_LINEAR
				player.play("celebrate" if i % 2 == 0 and not reduced_motion else "idle")
				player.seek(float(i) * 0.37, true)
				if reduced_motion:
					player.pause()
				crowd_players.append(player)
			break
		crowd.append(holder)
	# Leuchtstäbe als weiche Funken über dem Publikum.
	if tier != "low":
		for side in [-1.0, 1.0]:
			var glow := KIT.sparkle_particles("CrowdGlow%d" % int(side), 18, Color(0.7, 0.9, 1.0, 0.8), 2.4, 2.8)
			glow.position = Vector3(side * 10.5, 3.6, -7.0)
			add_child(glow)


func _effects(tier: String) -> void:
	confetti = GPUParticles3D.new()
	confetti.name = "RhythmConfetti"
	confetti.amount = 70 if tier == "low" else 160
	confetti.lifetime = 3.2
	confetti.one_shot = true
	confetti.explosiveness = 0.85
	confetti.emitting = false
	confetti.position = Vector3(0, 10.5, -10.0)
	confetti.visibility_aabb = AABB(Vector3(-12, -12, -10), Vector3(24, 16, 20))
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(7.0, 0.5, 6.0)
	proc.direction = Vector3(0, -1, 0)
	proc.spread = 35.0
	proc.initial_velocity_min = 1.0
	proc.initial_velocity_max = 3.0
	proc.gravity = Vector3(0, -2.2, 0)
	proc.angular_velocity_min = -220.0
	proc.angular_velocity_max = 220.0
	proc.angle_min = -180.0
	proc.angle_max = 180.0
	proc.scale_min = 0.8
	proc.scale_max = 1.4
	proc.anim_offset_max = 1.0
	confetti.process_material = proc
	var quad := QuadMesh.new()
	quad.size = Vector2(0.32, 0.32)
	var cm := StandardMaterial3D.new()
	cm.albedo_texture = KIT.texture("confetti.png")
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	cm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	cm.particles_anim_h_frames = 2
	cm.particles_anim_v_frames = 2
	cm.particles_anim_loop = false
	cm.emission_enabled = true
	cm.emission_texture = KIT.texture("confetti.png")
	cm.emission_energy_multiplier = 0.6
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = cm
	confetti.draw_pass_1 = quad
	add_child(confetti)
	# Treffer-Ringe und Halte-Leuchten je Spur.
	for lane in range(4):
		var x := (float(lane) - 1.5) * 2.35
		var ring := MeshInstance3D.new()
		ring.name = "HitRing%d" % lane
		var torus := TorusMesh.new()
		torus.inner_radius = 0.82
		torus.outer_radius = 1.0
		torus.rings = 32
		torus.ring_segments = 6
		ring.mesh = torus
		ring.position = Vector3(x, 0.4, 3.0)
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		rm.albedo_color = LANE_COLORS[lane]
		ring.material_override = rm
		ring.visible = false
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		rings.append(ring)
		ring_age.append(9.0)
		var glow := MeshInstance3D.new()
		glow.name = "HoldGlow%d" % lane
		var col := CylinderMesh.new()
		col.top_radius = 0.9
		col.bottom_radius = 0.95
		col.height = 3.4
		col.cap_top = false
		col.cap_bottom = false
		col.radial_segments = 16
		glow.mesh = col
		glow.position = Vector3(x, 1.75, 3.0)
		var gm := ShaderMaterial.new()
		gm.shader = KIT.shader("light_beam")
		gm.set_shader_parameter("beam_color", LANE_COLORS[lane])
		gm.set_shader_parameter("intensity", 0.55)
		gm.set_shader_parameter("beam_length", 3.4)
		gm.set_shader_parameter("invert", 1.0)
		glow.material_override = gm
		glow.visible = false
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glow)
		hold_glows.append(glow)


## Notenbahn-Material mit Taktlinien (ersetzt die einfarbige Spurfläche).
func lane_material() -> ShaderMaterial:
	if lane_mat == null:
		lane_mat = ShaderMaterial.new()
		lane_mat.shader = KIT.shader("lane_highway")
	return lane_mat


func set_theme(index: int) -> void:
	theme_index = posmod(index, THEMES.size())
	var t: Dictionary = THEMES[theme_index]
	if led_mat != null:
		led_mat.set_shader_parameter("color_a", t.a)
		led_mat.set_shader_parameter("color_b", t.b)
		led_mat.set_shader_parameter("color_c", t.c)
	for i in range(beam_mats.size()):
		beam_mats[i].set_shader_parameter("beam_color", t.beam if i % 2 == 0 else t.a)
	if rim_mat != null:
		rim_mat.albedo_color = t.rim
		rim_mat.emission = t.rim
	if lane_mat != null:
		lane_mat.set_shader_parameter("line_color", t.a.lerp(Color.WHITE, 0.35))


func hit(lane: int) -> void:
	if lane < 0 or lane >= rings.size():
		return
	ring_age[lane] = 0.0
	rings[lane].visible = true


func cheer(big: bool) -> void:
	_cheer_until = _clock + (3.0 if big else 1.8)
	if confetti != null and not reduced_motion:
		confetti.amount = maxi(40, confetti.amount)
		confetti.restart()
		confetti.emitting = true
	for player in crowd_players:
		if player.has_animation("celebrate") and not reduced_motion:
			player.play("celebrate", 0.2)


## Pro Bild vom Spiel: Liedzeit, Taktlänge, gehaltene Spuren, Combo-Energie.
func tick(delta: float, song_time: float, beat_len: float, running: bool, held: Dictionary, combo: int) -> void:
	_clock += delta
	var beats := song_time / maxf(0.2, beat_len) if running else _clock * 0.8
	var phase := fposmod(beats, 1.0)
	_energy = lerpf(_energy, clampf(0.25 + float(combo) / 20.0, 0.25, 1.0) if running else 0.25, minf(1.0, delta * 2.0))
	if led_mat != null:
		led_mat.set_shader_parameter("beat_phase", phase)
		led_mat.set_shader_parameter("beat_count", floor(beats))
		led_mat.set_shader_parameter("energy", _energy)
		led_mat.set_shader_parameter("calm", 1.0 if reduced_motion else 0.0)
	if lane_mat != null:
		lane_mat.set_shader_parameter("song_time", song_time if running else 0.0)
		lane_mat.set_shader_parameter("beat_len", beat_len)
	if not reduced_motion:
		for i in range(heads.size()):
			# Langsames Schwenken (unter 0,5 Hz), keine Farbwechsel im Takt.
			var a := _clock * (0.35 + 0.05 * float(i % 3)) + float(i) * 1.1
			heads[i].rotation = Vector3(sin(a) * 0.28 + 0.12, 0.0, cos(a * 0.8) * 0.34)
	else:
		for i in range(heads.size()):
			heads[i].rotation = Vector3(0.12, 0.0, (float(i % 2) - 0.5) * 0.3)
	for lane in range(rings.size()):
		if not rings[lane].visible:
			continue
		ring_age[lane] += delta
		var k := ring_age[lane] / 0.4
		if k >= 1.0:
			rings[lane].visible = false
			continue
		rings[lane].scale = Vector3.ONE * (1.0 + k * 0.9)
		(rings[lane].material_override as StandardMaterial3D).albedo_color.a = 1.0 - k
	for lane in range(hold_glows.size()):
		hold_glows[lane].visible = running and held.has(lane)
	if _cheer_until > 0.0 and _clock > _cheer_until:
		_cheer_until = -1.0
		for i in range(crowd_players.size()):
			var player := crowd_players[i]
			if not reduced_motion:
				player.play("celebrate" if i % 2 == 0 else "idle", 0.3)
