extends Control
## Lumo-Kart-Intro: Lumo fährt auf einer Lichtbahn ins Bild, driftet auf die
## Garagenbühne, das Logo erscheint und Lumo freut sich. Tippen oder eine Taste
## überspringt jederzeit; danach ist das Menü sofort bedienbar. Nur Bild und Ton,
## keine Lern- oder Spielzustände.

signal finished

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const DURATION: float = 4.4
const FADE: float = 0.35
const DRIVE_END: float = 1.45
const DRIFT_END: float = 2.45
const SETTLE_END: float = 2.95
const LOGO_START: float = 2.3
const RUNWAY_START: float = -17.0
const DRIFT_START: float = -3.4
const FINAL_HEADING: float = -0.45

## Optionaler Ton (KartAudio mit effect(kind)).
var audio: Node
var reduced_motion: bool = false
var time: float = 0.0
var kart: Node3D
var camera: Camera3D
var logo: Control
var lumo_label: Label
var kart_label: Label
var flag: GridContainer
var tagline: Label
var hint: Label
var leaving: bool = false
var fade_left: float = 0.0
var _cues: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	theme = UI.create()
	var background := TextureRect.new()
	background.texture = preload("res://assets/kart/menu/lumo-world.webp")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)
	var veil := ColorRect.new()
	veil.color = Color(0.008, 0.024, 0.075, 0.72)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(veil)
	var stage_box := SubViewportContainer.new()
	stage_box.stretch = true
	stage_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(stage_box)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage_box.add_child(viewport)
	_build_stage(viewport)
	_build_logo()
	resized.connect(_layout)
	_layout()
	_update(0.0)


func _build_stage(viewport: SubViewport) -> void:
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b0cfff")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.environment = env
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -35, 0)
	key.light_color = Color("e1f1ff")
	key.light_energy = 0.85
	key.shadow_enabled = true
	stage.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.0, 2.6, 1.2)
	rim.light_color = Color("63dfff")
	rim.light_energy = 0.55
	rim.omni_range = 10
	stage.add_child(rim)
	# Lichtbahn von links auf die Bühne, mit leuchtenden Kanten und Pfeilen.
	var runway := MeshInstance3D.new()
	var runway_mesh := BoxMesh.new()
	runway_mesh.size = Vector3(18.0, 0.06, 2.9)
	runway.mesh = runway_mesh
	runway.position = Vector3(-10.2, -0.12, 0.35)
	runway.material_override = _glossy(Color("0f2747"))
	stage.add_child(runway)
	for side in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(18.0, 0.05, 0.07)
		edge.mesh = edge_mesh
		edge.position = Vector3(-10.2, -0.07, 0.35 + side * 1.45)
		edge.material_override = _glow(Color("45d9ef"))
		stage.add_child(edge)
	for index in range(7):
		var arrow := MeshInstance3D.new()
		var arrow_mesh := PrismMesh.new()
		arrow_mesh.size = Vector3(0.55, 0.62, 0.02)
		arrow.mesh = arrow_mesh
		arrow.rotation = Vector3(-PI / 2, 0, -PI / 2)
		arrow.position = Vector3(-17.0 + index * 2.1, -0.075, 0.35)
		arrow.material_override = _glow(Color("ffd36b") if index % 2 == 0 else Color("53ddfd"))
		stage.add_child(arrow)
	var podium := MeshInstance3D.new()
	var podium_mesh := CylinderMesh.new()
	podium_mesh.top_radius = 2.0
	podium_mesh.bottom_radius = 2.05
	podium_mesh.height = 0.18
	podium_mesh.radial_segments = 64
	podium.mesh = podium_mesh
	podium.position.y = -0.13
	podium.material_override = _glossy(Color("12304c"))
	stage.add_child(podium)
	for radius in [2.04, 2.30]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius
		torus.outer_radius = radius + 0.035
		torus.rings = 64
		ring.mesh = torus
		ring.position.y = -0.04
		ring.material_override = _glow(Color("45d9ef"))
		stage.add_child(ring)
	for index in range(12):
		var star := MeshInstance3D.new()
		star.mesh = SHAPES.star()
		star.scale = Vector3.ONE * (0.04 + index % 3 * 0.018)
		star.position = Vector3(sin(index * 2.4) * 3.2, 0.9 + index % 4 * 0.55, cos(index * 2.4) * 2.4 + 1.0)
		star.material_override = _glow(Color("ffd36b") if index % 4 == 0 else Color("a8deee"))
		stage.add_child(star)
	kart = VEHICLE.new()
	kart.configure("fox", Color("357cba"), "comet")
	kart.reduced_motion = reduced_motion
	stage.add_child(kart)
	camera = Camera3D.new()
	camera.fov = 40
	stage.add_child(camera)
	camera.current = true


func _glossy(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.7
	material.roughness = 0.3
	return material


func _glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


func _build_logo() -> void:
	logo = Control.new()
	logo.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(logo)
	lumo_label = _logo_label("LUMO", Color("f7fbff"), Color("53ddfd"))
	logo.add_child(lumo_label)
	kart_label = _logo_label("KART", Color("53ddfd"), Color("0a3f8f"))
	logo.add_child(kart_label)
	flag = GridContainer.new()
	flag.columns = 5
	flag.add_theme_constant_override("h_separation", 0)
	flag.add_theme_constant_override("v_separation", 0)
	flag.mouse_filter = MOUSE_FILTER_IGNORE
	for index in range(15):
		var square := ColorRect.new()
		square.color = Color("f7fbff") if (index % 5 + index / 5) % 2 == 0 else Color(0, 0, 0, 0)
		square.mouse_filter = MOUSE_FILTER_IGNORE
		flag.add_child(square)
	logo.add_child(flag)
	tagline = Label.new()
	tagline.text = "Rennen. Driften. Gewinnen."
	tagline.add_theme_font_override("font", UI.BODY)
	tagline.add_theme_color_override("font_color", Color("9fe8ff"))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(tagline)
	hint = Label.new()
	hint.text = "Tippen zum Überspringen"
	hint.add_theme_font_override("font", UI.BODY)
	hint.add_theme_color_override("font_color", Color(0.75, 0.86, 1.0, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(hint)


func _logo_label(text: String, fill: Color, glow: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI.HEADING)
	label.add_theme_color_override("font_color", fill)
	label.add_theme_color_override("font_outline_color", glow)
	label.add_theme_color_override("font_shadow_color", Color(glow, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 6)
	label.add_theme_constant_override("shadow_outline_size", 18)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label


func _layout() -> void:
	if not is_instance_valid(logo):
		return
	var area: Vector2 = size
	if area.x <= 0.0 or area.y <= 0.0:
		return
	var unit: float = minf(area.y, area.x * 0.56)
	var font_size: int = int(clampf(unit * 0.135, 30.0, 128.0))
	for label in [lumo_label, kart_label]:
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_constant_override("outline_size", maxi(4, font_size / 11))
		label.size = Vector2.ZERO
	var lumo_size: Vector2 = lumo_label.get_minimum_size()
	var kart_size: Vector2 = kart_label.get_minimum_size()
	var square: float = maxf(6.0, font_size * 0.13)
	for child in flag.get_children():
		child.custom_minimum_size = Vector2(square, square)
	var flag_size := Vector2(square * 5, square * 3)
	var gap: float = font_size * 0.22
	var total: float = lumo_size.x + gap + kart_size.x + gap * 0.6 + flag_size.x
	logo.size = Vector2(total, maxf(lumo_size.y, kart_size.y))
	logo.position = Vector2((area.x - total) * 0.5, area.y * 0.035)
	logo.pivot_offset = logo.size * 0.5
	lumo_label.position = Vector2.ZERO
	kart_label.position = Vector2(lumo_size.x + gap, 0)
	flag.position = Vector2(lumo_size.x + gap + kart_size.x + gap * 0.6, kart_size.y * 0.22)
	flag.rotation = -0.18
	var small: int = int(clampf(unit * 0.045, 15.0, 40.0))
	tagline.add_theme_font_size_override("font_size", small)
	tagline.size = Vector2(area.x, small * 1.6)
	tagline.position = Vector2(0, logo.position.y + logo.size.y + small * 0.2)
	hint.add_theme_font_size_override("font_size", maxi(14, small - 6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size = Vector2(area.x * 0.5, small * 1.5)
	hint.position = Vector2(area.x * 0.5 - small, area.y - small * 2.0)


func _process(delta: float) -> void:
	if leaving:
		fade_left = maxf(0.0, fade_left - delta)
		modulate.a = fade_left / FADE
		if fade_left <= 0.0:
			finished.emit()
			queue_free()
		return
	time += delta
	_update(time)
	if time >= DURATION:
		leave()


## Zeitgesteuerte Szene; auch von Tests direkt mit festen Zeitpunkten aufrufbar.
func _update(t: float) -> void:
	var heading: float = -PI / 2
	var position_x: float = RUNWAY_START
	var position_z: float = 0.35
	var speed: float = 0.0
	var steer: float = 0.0
	var boost: bool = false
	var drift: bool = false
	if t < DRIVE_END:
		var f: float = t / DRIVE_END
		position_x = lerpf(RUNWAY_START, DRIFT_START, 1.0 - pow(1.0 - f, 1.6))
		speed = lerpf(14.0, 9.0, f)
		boost = f < 0.55
		_cue("boost", 0.05, t)
	elif t < DRIFT_END:
		var f: float = (t - DRIVE_END) / (DRIFT_END - DRIVE_END)
		var ease_out: float = 1.0 - pow(1.0 - f, 2.2)
		position_x = lerpf(DRIFT_START, 0.0, ease_out)
		position_z = lerpf(0.35, 0.0, ease_out)
		heading = lerpf(-PI / 2, 0.42, smoothstep(0.0, 1.0, f))
		speed = lerpf(9.0, 1.5, f)
		steer = 1.0
		drift = true
		_cue("drift", DRIVE_END, t)
	else:
		var f: float = clampf((t - DRIFT_END) / (SETTLE_END - DRIFT_END), 0.0, 1.0)
		position_x = 0.0
		position_z = 0.0
		heading = lerpf(0.42, FINAL_HEADING, smoothstep(0.0, 1.0, f))
		speed = lerpf(1.5, 0.0, f)
		steer = lerpf(1.0, 0.0, f)
		if t >= SETTLE_END - 0.15 and kart.has_method("celebrate") and not _cues.has("celebrate"):
			_cues["celebrate"] = true
			kart.celebrate(1)
	kart.position = Vector3(position_x, 0.0, position_z)
	kart.rotation.y = heading
	kart.set_motion(speed, steer, boost, drift)
	# Kamera begleitet die Einfahrt und kommt vor Lumo zur Ruhe.
	var c: float = smoothstep(0.0, SETTLE_END, t)
	var eye := Vector3(lerpf(2.6, 3.7, c), lerpf(2.9, 2.5, c), lerpf(-9.4, -6.6, c))
	# Ziel liegt über dem Kart: Lumo steht im unteren Bilddrittel, das Logo oben frei.
	var target := Vector3(lerpf(position_x * 0.55, 0.0, c), lerpf(1.1, 1.75, c), lerpf(0.2, 0.0, c))
	camera.look_at_from_position(eye, target)
	# Logo springt herein und atmet danach sanft.
	var l: float = clampf((t - LOGO_START) / 0.55, 0.0, 1.0)
	var pop: float = 1.0 + 2.70158 * pow(l - 1.0, 3) + 1.70158 * pow(l - 1.0, 2) if l > 0.0 else 0.0
	var breathe: float = 0.0 if reduced_motion else sin(maxf(0.0, t - LOGO_START - 0.55) * 2.4) * 0.015
	logo.scale = Vector2.ONE * maxf(0.001, lerpf(0.55, 1.0, pop) + breathe)
	logo.modulate.a = l
	tagline.modulate.a = clampf((t - LOGO_START - 0.35) / 0.4, 0.0, 1.0)
	hint.modulate.a = clampf(t / 0.6, 0.0, 1.0) * (0.55 + 0.25 * sin(t * 3.0))
	if l > 0.0:
		_cue("start", LOGO_START, t)


func _cue(kind: String, at: float, t: float) -> void:
	if t < at or _cues.has(kind):
		return
	_cues[kind] = true
	if is_instance_valid(audio) and audio.has_method("effect"):
		audio.effect(kind)


func leave() -> void:
	if leaving:
		return
	leaving = true
	fade_left = FADE
	# Während des Ausblendens geht jeder Tipp schon ans Menü darunter.
	mouse_filter = MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		leave()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and not leaving:
		leave()
		get_viewport().set_input_as_handled()
