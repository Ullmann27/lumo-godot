## Sternenjagd – Lumo und das Kind fangen Sterne über der Wolkeninsel.
##
## Drei Wellen mit 5, 7 und 9 Sternen. In Welle 2 tanzen die Sterne hin und
## her, in Welle 3 fliegt zusätzlich eine Sternschnuppe vorbei (Bonus).
## Die Sterne werden aus Bildschirmpunkten gesetzt und liegen deshalb im
## Hoch- wie im Querformat immer sichtbar zwischen Kopfleiste und Rand.
## Ein Tipp zählt in großzügigem Umkreis (mindestens 48 dp Durchmesser).
## Treffer: Funkenregen, „+1“, Ton, hüpfender Zähler, Lumo dreht sich zum
## Stern. Ende: gemessene Zeit, Bestzeit je Kind, „Nochmal“ oder zurück
## zur Spielewelt. Es werden keine Lern-Sterne (Währung) vergeben.
extends Node3D

signal star_caught(total: int)
signal wave_started(index: int)
signal hunt_finished(seconds: float)

const KIT = preload("res://scripts/creative/creative_kit.gd")
const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const WAVES: Array[int] = [5, 7, 9]
const WAVE_TEXT: Array[String] = [
	"Tippe auf die leuchtenden Sterne!",
	"Welle 2 – die Sterne tanzen!",
	"Welle 3 – fang auch die Sternschnuppe!",
]
const SAVE_PATH: String = "user://lumo_sternenjagd.cfg"
## Anteil des Bildes oben (Kopfleiste) und unten, in den kein Stern fällt.
const TOP_BAND: float = 0.2
const BOTTOM_BAND: float = 0.1
const STAR_GOLD := Color("ffd23f")
const STAR_GLOW := Color("ffb52e")

@export var lumo_path: NodePath

var wave: int = -1
var caught_in_wave: int = 0
var caught_total: int = 0
var bonus_caught: bool = false
var elapsed: float = 0.0
var running: bool = false
var best_seconds: float = 0.0
var stars: Array[Node3D] = []
var shooting_star: Node3D
var camera: Camera3D
var back_button: Button
var counter_label: Label
var counter_pill: PanelContainer
var wave_label: Label
var banner: Label
var hint: Control
var result_panel: PanelContainer
var result_box: VBoxContainer
var safe: MarginContainer

var _lumo: Node3D
var _star_mesh: ArrayMesh
var _star_material: StandardMaterial3D
var _halo_material: StandardMaterial3D
var _spark_material: StandardMaterial3D
var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()
var _child_section: String = "kind"
var _previous_quit_on_back: bool = true


func _ready() -> void:
	_rng.randomize()
	_lumo = get_node_or_null(lumo_path) as Node3D
	camera = get_node_or_null("Camera3D") as Camera3D
	var child_key: String = str(SceneRouter.launch_options.get("childKey", ""))
	if not child_key.is_empty():
		_child_section = child_key.sha256_text().substr(0, 24)
	_previous_quit_on_back = get_tree().quit_on_go_back
	get_tree().quit_on_go_back = false
	_build_world()
	_build_ui()
	_load_best()
	get_viewport().size_changed.connect(_layout)
	MobileRuntime.safe_area_changed.connect(_layout)
	_layout()
	if _lumo != null and _lumo.has_method("play_behavior"):
		_lumo.play_behavior("greet")
	start_hunt()
	print("[StarCollect] scene_loaded")


func _exit_tree() -> void:
	get_tree().quit_on_go_back = _previous_quit_on_back
	if MobileRuntime.safe_area_changed.is_connected(_layout):
		MobileRuntime.safe_area_changed.disconnect(_layout)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_to_games()


# --- Welt -------------------------------------------------------------------


func _build_world() -> void:
	LumoEnvironment.apply(self, "creative_night")
	var art := JumpSkyIslandsArt.new()
	var island_root := Node3D.new()
	island_root.name = "StarIsland"
	island_root.position = Vector3(0, -JumpSkyIslandsArt.TOP_Y, 0)
	add_child(island_root)
	island_root.scale = Vector3(1.35, 1.0, 1.25)
	art.island(island_root, 0)
	for at in [Vector3(-2.5, 0, -1.6), Vector3(2.4, 0, -1.3), Vector3(-2.0, 0, 1.4)]:
		art.tree(island_root, at)
	art.finish(self)
	art.clouds(self, 40.0)
	art.backdrop(self, 60.0)
	_build_sky_stars()
	var warm := OmniLight3D.new()
	warm.name = "LumoLight"
	warm.position = Vector3(0.6, 2.6, 2.6)
	warm.light_color = Color("ffe2b0")
	warm.light_energy = 1.3
	warm.omni_range = 7.0
	add_child(warm)
	_star_mesh = LumoWorldMeshes.star()
	_star_material = StandardMaterial3D.new()
	_star_material.albedo_color = STAR_GOLD
	_star_material.emission_enabled = true
	_star_material.emission = STAR_GLOW
	_star_material.emission_energy_multiplier = 2.2
	_star_material.metallic = 0.35
	_star_material.roughness = 0.25
	_halo_material = StandardMaterial3D.new()
	_halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_halo_material.albedo_texture = _radial_texture(Color(1.0, 0.82, 0.35, 0.9))
	_halo_material.no_depth_test = false
	_spark_material = _star_material.duplicate()
	_spark_material.emission_energy_multiplier = 3.0
	if camera != null:
		camera.position = Vector3(0, 1.6, 7.4)
		camera.look_at(Vector3(0, 2.3, 0))
		camera.fov = 58.0


## Ferne, funkelnde Hintergrundsterne in einem einzigen Zeichenaufruf.
func _build_sky_stars() -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = LumoWorldMeshes.star()
	multi.instance_count = 70
	var rng := RandomNumberGenerator.new()
	rng.seed = 2058
	for i in range(multi.instance_count):
		var at := Vector3(
			rng.randf_range(-48.0, 48.0), rng.randf_range(4.0, 34.0), rng.randf_range(-60.0, -28.0)
		)
		var spin := Basis(Vector3.FORWARD, rng.randf_range(0.0, TAU))
		multi.set_instance_transform(
			i, Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.14, 0.34)), at)
		)
	var node := MultiMeshInstance3D.new()
	node.name = "SkyStars"
	node.multimesh = multi
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("dfe9ff")
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _radial_texture(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	return texture


func _make_star(scale_factor: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "HuntStar"
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 1.5 * scale_factor
	halo.mesh = quad
	halo.material_override = _halo_material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _star_mesh
	body.scale = Vector3.ONE * 0.36 * scale_factor
	body.material_override = _star_material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	return root


# --- Spielablauf -------------------------------------------------------------


func start_hunt() -> void:
	for star in stars:
		if is_instance_valid(star):
			star.queue_free()
	stars.clear()
	_clear_shooting_star()
	wave = -1
	caught_total = 0
	bonus_caught = false
	elapsed = 0.0
	result_panel.hide()
	_next_wave()


func _next_wave() -> void:
	wave += 1
	caught_in_wave = 0
	running = true
	_spawn_wave(WAVES[wave])
	_show_banner(WAVE_TEXT[wave])
	_update_counter()
	if wave == 2:
		var delay := get_tree().create_timer(2.2)
		delay.timeout.connect(_launch_shooting_star)
	if _lumo != null and wave > 0 and _lumo.has_method("play_behavior"):
		_lumo.play_behavior("idle")
	wave_started.emit(wave)
	print("[StarCollect] wave:%d stars:%d" % [wave + 1, WAVES[wave]])


## Freie Bildschirmpunkte im Spielfeld, nicht auf Lumo, mit Abstand zueinander.
func _free_points(count: int) -> Array[Vector2]:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var field := Rect2(
		view.x * 0.1, view.y * TOP_BAND, view.x * 0.8, view.y * (1.0 - TOP_BAND - BOTTOM_BAND)
	)
	var lumo_rect := _lumo_screen_rect()
	var spacing: float = tap_radius() * 2.3
	var points: Array[Vector2] = []
	for attempt in range(count * 160):
		if points.size() >= count:
			break
		if attempt > 0 and attempt % (count * 40) == 0:
			spacing *= 0.85
		var candidate := Vector2(
			_rng.randf_range(field.position.x, field.end.x),
			_rng.randf_range(field.position.y, field.end.y)
		)
		if lumo_rect.has_point(candidate):
			continue
		var free := true
		for other in points:
			if other.distance_to(candidate) < spacing:
				free = false
				break
		if free:
			points.append(candidate)
	return points


func _lumo_screen_rect() -> Rect2:
	if camera == null:
		return Rect2()
	var feet: Vector2 = camera.unproject_position(Vector3(0, 0, 0))
	var head: Vector2 = camera.unproject_position(Vector3(0, 2.3, 0))
	var width: float = absf(feet.y - head.y) * 0.5
	return Rect2(head.x - width * 0.5, head.y, width, feet.y - head.y)


func _spawn_wave(count: int) -> void:
	var points := _free_points(count)
	for i in range(points.size()):
		var depth: float = _rng.randf_range(5.6, 7.4)
		var at: Vector3 = (
			camera.project_position(points[i], depth) if camera != null else Vector3(i, 2, 0)
		)
		var star := _make_star()
		star.position = at
		star.set_meta("base", at)
		star.set_meta("phase", _rng.randf_range(0.0, TAU))
		star.scale = Vector3.ZERO
		add_child(star)
		stars.append(star)
		var grow := star.create_tween()
		grow.tween_interval(0.06 * i)
		grow.tween_property(star, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(
			Tween.EASE_OUT
		)
	_place_hint()


func _launch_shooting_star() -> void:
	if not running or wave != 2 or camera == null or is_instance_valid(shooting_star):
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var from: Vector3 = camera.project_position(Vector2(-view.x * 0.05, view.y * 0.24), 6.5)
	var to: Vector3 = camera.project_position(Vector2(view.x * 1.05, view.y * 0.42), 6.5)
	shooting_star = _make_star(1.25)
	shooting_star.name = "ShootingStar"
	shooting_star.position = from
	add_child(shooting_star)
	var trail := CPUParticles3D.new()
	trail.name = "Trail"
	trail.amount = 28
	trail.lifetime = 0.6
	trail.local_coords = false
	trail.mesh = _star_mesh
	trail.material_override = _spark_material
	trail.scale_amount_min = 0.05
	trail.scale_amount_max = 0.1
	trail.gravity = Vector3(0, -0.6, 0)
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.4
	shooting_star.add_child(trail)
	var fly := shooting_star.create_tween()
	fly.tween_property(shooting_star, "position", to, 5.5)
	fly.tween_callback(_clear_shooting_star)


func _clear_shooting_star() -> void:
	if is_instance_valid(shooting_star):
		shooting_star.queue_free()
	shooting_star = null


func _process(delta: float) -> void:
	_clock += delta
	if running:
		elapsed += delta
	for star in stars:
		if not is_instance_valid(star):
			continue
		var base: Vector3 = star.get_meta("base")
		var phase: float = star.get_meta("phase")
		var offset := Vector3(0, sin(_clock * 1.8 + phase) * 0.12, 0)
		if wave >= 1:
			offset.x = sin(_clock * 0.9 + phase) * 0.55
		star.position = base + offset
		var body := star.get_node_or_null("Body") as Node3D
		if body != null:
			body.rotation.y = _clock * 1.6 + phase
	if is_instance_valid(shooting_star):
		var body := shooting_star.get_node_or_null("Body") as Node3D
		if body != null:
			body.rotation.z = _clock * 5.0


## Trefferradius in Ansichtspunkten: mindestens 48 dp Durchmesser.
func tap_radius() -> float:
	return maxf(24.0 * _unit(), get_viewport().get_visible_rect().size.x * 0.06)


func _unhandled_input(event: InputEvent) -> void:
	var at := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		at = event.position
	elif (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.device != InputEvent.DEVICE_ID_EMULATION
	):
		at = event.position
	if at == Vector2.INF or not running:
		return
	if try_catch_at(at):
		get_viewport().set_input_as_handled()


## Fängt den nächstgelegenen Stern im Trefferradius um einen Bildschirmpunkt.
func try_catch_at(at: Vector2) -> bool:
	if camera == null:
		return false
	var best: Node3D = null
	var best_distance: float = tap_radius()
	var targets: Array[Node3D] = stars.duplicate()
	if is_instance_valid(shooting_star):
		targets.append(shooting_star)
	for star in targets:
		if not is_instance_valid(star) or camera.is_position_behind(star.global_position):
			continue
		var distance: float = camera.unproject_position(star.global_position).distance_to(at)
		if distance <= best_distance:
			best_distance = distance
			best = star
	if best == null:
		return false
	if best == shooting_star:
		_catch_shooting_star()
	else:
		_catch(best)
	return true


func _catch(star: Node3D) -> void:
	stars.erase(star)
	caught_in_wave += 1
	caught_total += 1
	_burst(star.global_position, 22)
	_float_text(star.global_position, "+1")
	var pop := star.create_tween()
	pop.tween_property(star, "scale", Vector3.ONE * 1.6, 0.1)
	pop.tween_property(star, "scale", Vector3.ZERO, 0.18)
	pop.tween_callback(star.queue_free)
	AudioManager.play_sfx("star_collected")
	EventBus.companion_reaction.emit("star_collected")
	_face(star.global_position)
	_update_counter(true)
	if is_instance_valid(hint):
		hint.hide()
	star_caught.emit(caught_total)
	print("[StarCollect] collected:%d wave:%d" % [caught_total, wave + 1])
	if caught_in_wave >= WAVES[wave]:
		_wave_done()


func _catch_shooting_star() -> void:
	var at: Vector3 = shooting_star.global_position
	bonus_caught = true
	_burst(at, 40)
	_float_text(at, "Bonus!")
	AudioManager.play_sfx("celebrate")
	_face(at)
	_clear_shooting_star()
	_show_banner("Sternschnuppe gefangen!")
	print("[StarCollect] shooting_star caught")


func _wave_done() -> void:
	running = false
	if _lumo != null and _lumo.has_method("play_behavior"):
		_lumo.play_behavior("celebrate")
	if wave + 1 < WAVES.size():
		_show_banner("Super! Gleich kommen neue Sterne …")
		var pause := get_tree().create_timer(1.6)
		pause.timeout.connect(_next_wave)
	else:
		_clear_shooting_star()
		AudioManager.play_sfx("celebrate")
		_finish()


func _face(target: Vector3) -> void:
	if _lumo == null:
		return
	var angle: float = clampf(atan2(target.x, maxf(target.z + 2.0, 0.5)), -0.6, 0.6)
	var turn := _lumo.create_tween()
	turn.tween_property(_lumo, "rotation:y", angle, 0.25)
	turn.tween_interval(0.6)
	turn.tween_property(_lumo, "rotation:y", 0.0, 0.5)


func _burst(at: Vector3, amount: int) -> void:
	var sparks := CPUParticles3D.new()
	sparks.name = "StarBurst"
	sparks.position = at
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = amount
	sparks.lifetime = 0.8
	sparks.mesh = _star_mesh
	sparks.material_override = _spark_material
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 1.6
	sparks.initial_velocity_max = 3.2
	sparks.gravity = Vector3(0, -3.0, 0)
	sparks.scale_amount_min = 0.06
	sparks.scale_amount_max = 0.13
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	sparks.scale_amount_curve = shrink
	add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(1.2).timeout.connect(sparks.queue_free)


func _float_text(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 96
	label.outline_size = 22
	label.modulate = Color("fff4c4")
	label.outline_modulate = Color("7a3d00")
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = at + Vector3(0, 0.3, 0)
	add_child(label)
	var rise := label.create_tween().set_parallel()
	rise.tween_property(label, "position:y", at.y + 1.0, 0.8)
	rise.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.25)
	rise.chain().tween_callback(label.queue_free)


func _finish() -> void:
	running = false
	var seconds: float = elapsed
	var record: bool = best_seconds <= 0.0 or seconds < best_seconds
	if record:
		best_seconds = seconds
		_save_best()
	_show_result(seconds, record)
	hunt_finished.emit(seconds)
	print("[StarCollect] finished seconds:%.1f record:%s" % [seconds, str(record)])


# --- Bestzeit ----------------------------------------------------------------


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		best_seconds = float(config.get_value(_child_section, "best_seconds", 0.0))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value(_child_section, "best_seconds", best_seconds)
	config.save(SAVE_PATH)


# --- Oberfläche ---------------------------------------------------------------


## Ansichtspunkte je Gerätepunkt (dp): 48 * _unit() ergibt am Handy 48 dp.
func _unit() -> float:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var window_pixels := Vector2(get_window().size)
	if window_pixels.x <= 0.0 or window_pixels.y <= 0.0:
		window_pixels = view
	var pixels_per_unit: float = maxf(
		0.1, minf(window_pixels.x / maxf(view.x, 1.0), window_pixels.y / maxf(view.y, 1.0))
	)
	return MobileRuntime.get_ui_density() / pixels_per_unit


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HuntUI"
	add_child(layer)
	safe = MarginContainer.new()
	safe.name = "Safe"
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(safe)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	back_button = KIT.button("‹ Spielewelt", _back_to_games, 120)
	back_button.name = "BackButton"
	top.add_child(back_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	counter_pill = PanelContainer.new()
	counter_pill.name = "Counter"
	counter_pill.add_theme_stylebox_override(
		"panel", KIT.tinted_panel(Color(0.05, 0.08, 0.22, 0.88), STAR_GOLD, 26)
	)
	counter_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(counter_pill)
	var pill_row := HBoxContainer.new()
	pill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter_pill.add_child(pill_row)
	var icon := KIT.StarIcon.new()
	icon.filled = true
	icon.name = "StarIcon"
	pill_row.add_child(icon)
	counter_label = _label("0 / 5", 30, Color("fff2b8"))
	counter_label.name = "CounterLabel"
	pill_row.add_child(counter_label)
	wave_label = _label("Welle 1 von 3", 18, Color("cfe0ff"))
	wave_label.name = "WaveLabel"
	column.add_child(wave_label)
	banner = _label("", 26, Color.WHITE)
	banner.name = "Banner"
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(banner)
	hint = TapHint.new()
	hint.name = "TapHint"
	layer.add_child(hint)
	result_panel = PanelContainer.new()
	result_panel.name = "ResultPanel"
	result_panel.add_theme_stylebox_override(
		"panel", KIT.tinted_panel(Color(0.04, 0.07, 0.2, 0.95), STAR_GOLD, 26)
	)
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(result_panel)
	result_box = VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_panel.add_child(result_box)
	result_panel.hide()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.14, 0.9))
	label.set_meta("base_size", size)
	return label


func _layout() -> void:
	if not is_inside_tree() or not is_instance_valid(safe):
		return
	var unit: float = _unit()
	var view: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = 1.0 / maxf(0.1, Vector2(get_window().size).x / maxf(view.x, 1.0))
	var insets: Rect2 = MobileRuntime.get_safe_area_insets()
	safe.add_theme_constant_override(
		"margin_left", ceili(maxf(14.0 * unit, insets.position.x * factor))
	)
	safe.add_theme_constant_override(
		"margin_right", ceili(maxf(14.0 * unit, insets.size.x * factor))
	)
	safe.add_theme_constant_override(
		"margin_top", ceili(maxf(10.0 * unit, insets.position.y * factor))
	)
	safe.add_theme_constant_override(
		"margin_bottom", ceili(maxf(10.0 * unit, insets.size.y * factor))
	)
	back_button.custom_minimum_size = Vector2(118, 52) * unit
	back_button.add_theme_font_size_override("font_size", roundi(18 * unit))
	counter_pill.custom_minimum_size = Vector2(150, 52) * unit
	var icon := counter_pill.find_child("StarIcon", true, false) as Control
	if icon != null:
		icon.custom_minimum_size = Vector2.ONE * 34.0 * unit
	for label in [counter_label, wave_label, banner]:
		var base: int = int(label.get_meta("base_size", 20))
		label.add_theme_font_size_override("font_size", roundi(base * unit))
		label.add_theme_constant_override("outline_size", roundi(5 * unit))
	result_panel.custom_minimum_size = Vector2(minf(340.0 * unit, view.x * 0.86), 0)
	for item in result_box.get_children():
		if item is Button:
			item.custom_minimum_size = Vector2(0, 56) * unit
			item.add_theme_font_size_override("font_size", roundi(20 * unit))
		elif item is Label:
			var size: int = int(item.get_meta("base_size", 20))
			item.add_theme_font_size_override("font_size", roundi(size * unit))
	result_box.add_theme_constant_override("separation", roundi(12 * unit))
	_place_hint()


func _update_counter(bounce: bool = false) -> void:
	if wave < 0:
		return
	counter_label.text = "%d / %d" % [caught_in_wave, WAVES[wave]]
	wave_label.text = "Welle %d von %d" % [wave + 1, WAVES.size()]
	if bounce:
		counter_pill.pivot_offset = counter_pill.size * 0.5
		var pop := counter_pill.create_tween()
		pop.tween_property(counter_pill, "scale", Vector2.ONE * 1.15, 0.08)
		pop.tween_property(counter_pill, "scale", Vector2.ONE, 0.16)


func _show_banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	var fade := banner.create_tween()
	fade.tween_interval(2.4)
	fade.tween_property(banner, "modulate:a", 0.0, 0.6)


func _place_hint() -> void:
	if not is_instance_valid(hint) or camera == null:
		return
	var first: Node3D = null
	for star in stars:
		if is_instance_valid(star):
			first = star
			break
	if caught_total > 0 or first == null:
		hint.hide()
		return
	var at: Vector2 = camera.unproject_position(first.get_meta("base"))
	hint.radius = tap_radius()
	hint.position = at
	hint.show()


func _show_result(seconds: float, record: bool) -> void:
	for child in result_box.get_children():
		child.queue_free()
	var title := _label("Alle Sterne gefangen!", 30, Color("fff2b8"))
	result_box.add_child(title)
	var total := _label(
		"%d Sterne in %d Sekunden" % [caught_total, roundi(seconds)], 22, Color.WHITE
	)
	result_box.add_child(total)
	var best_text := (
		"Neue Bestzeit!" if record else "Deine Bestzeit: %d Sekunden" % roundi(best_seconds)
	)
	result_box.add_child(_label(best_text, 20, Color("9ff0c4") if record else Color("cfe0ff")))
	if bonus_caught:
		result_box.add_child(_label("Sternschnuppe gefangen!", 20, Color("ffd38a")))
	var again := KIT.button("Nochmal spielen", start_hunt, 200, Color(), "primary")
	again.name = "AgainButton"
	result_box.add_child(again)
	var back := KIT.button("Zur Spielewelt", _back_to_games, 200)
	back.name = "ResultBackButton"
	result_box.add_child(back)
	result_panel.show()
	_layout()


func _back_to_games() -> void:
	running = false
	if _lumo != null and _lumo.has_method("play_behavior"):
		_lumo.play_behavior("idle")
	AudioManager.play_sfx("ui_back")
	SceneRouter.goto("games")


## Pulsierender Ring über dem ersten Stern: „hier tippen“.
class TapHint:
	extends Control
	var radius: float = 40.0
	var _time: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		hide()

	func _process(delta: float) -> void:
		if not visible:
			return
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var pulse: float = fposmod(_time, 1.1) / 1.1
		var ring: float = radius * (0.75 + pulse * 0.6)
		draw_arc(Vector2.ZERO, ring, 0.0, TAU, 48, Color(1, 0.95, 0.6, 1.0 - pulse), 5.0, true)
		draw_arc(Vector2.ZERO, radius * 0.8, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)
