extends Control
## Bilder zur Einführung der Dorfwelt (gehört zu build_village_tutorial.gd):
##  - Luftblick: die Kamera zeigt kurz das eigene Tal von oben und setzt dann
##    neben Lumo an einem freien Bauplatz auf,
##  - Lumo (das echte, geriggte Modell aus build_village_life.gd) wartet als
##    Begleiter am Bauplatz statt seine Runde zu laufen,
##  - Ernteweg: Karotten fliegen sichtbar vom Hof in den Vorrat und von dort
##    zur Familie im Wohnhaus – mit den echten Zahlen des Tages.
## Verändert nur Kamera und Lumos Standort, nie den Spielstand.
signal landed
const VHUD = preload("res://scripts/creative/build_village_hud.gd")
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const FLIGHT_SECONDS := 4.2
const FLOW_SECONDS := 1.8
const LUMO_OFFSET := Vector3(2.4, 0.0, 1.6)
## Blickrichtung wie die Startansicht des Dorfs (START_VIEW.x).
const LANDING_ORBIT := -0.38

var world: Node
var flying := false
var flight_time := 0.0
var flight_from: Dictionary = {}
var flight_to: Dictionary = {}
var guide_plot := -1
var lumo_held := false
var held_path: Array = []
## Ernteweg: "" | "hof_vorrat" | "vorrat_familie"
var flow := ""
var flow_amount := 0
var flow_time := 0.0
var carrot: Texture2D
var flow_label: Label


func setup(owner_world: Node) -> void:
	world = owner_world
	name = "VillageGuide"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	carrot = VHUD.texture("res_food")
	flow_label = VHUD.label("", 26, VHUD.GOLD)
	flow_label.name = "HarvestAmount"
	flow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow_label.hide()
	add_child(flow_label)


## Landeplatz: freier Bauplatz, Lumo daneben, Kamera schräg davor.
func landing_view() -> Dictionary:
	guide_plot = world._next_free_plot()
	var plot: Vector3 = world._plot_world(maxi(0, guide_plot)) if guide_plot >= 0 else world._start_focus()
	var spot := plot + LUMO_OFFSET
	return {"focus": plot.lerp(spot, 0.4), "orbit": LANDING_ORBIT, "tilt": 0.6, "radius": 26.0, "spot": spot}


func start_flight() -> void:
	flight_to = landing_view()
	# Hoch über dem Tal, leicht gedreht: man sieht Fluss, Wiesen und Nachbarn.
	flight_from = {"focus": world._start_focus(), "orbit": float(flight_to.orbit) - 0.9, "tilt": 1.2, "radius": 108.0}
	flight_time = 0.0
	flying = true
	_apply(flight_from)
	place_lumo(flight_to.spot)


func finish_flight() -> void:
	if not flying:
		return
	flying = false
	_apply(flight_to)
	place_lumo(flight_to.spot)
	if lumo_held and world.village_life.lumo.is_usable():
		world.village_life.lumo.play_behavior("greeting_wave")
	landed.emit()


## Ohne Flug (Rückkehr mitten in der Einführung): direkt neben Lumo aufsetzen.
func land_now() -> void:
	flight_to = landing_view()
	flying = false
	_apply(flight_to)
	place_lumo(flight_to.spot)


func _apply(view: Dictionary) -> void:
	world.focus = view.focus
	world.orbit = float(view.orbit)
	world.tilt = float(view.tilt)
	world.radius = float(view.radius)
	world.pan_velocity = Vector3.ZERO
	world._camera_update(true)


func _lumo() -> Node3D:
	if not is_instance_valid(world.village_life) or world.village_life.lumo == null:
		return null
	return world.village_life.lumo


func place_lumo(spot: Vector3) -> void:
	var lumo := _lumo()
	if lumo == null:
		return
	if not lumo_held:
		held_path = world.village_life.lumo_path.duplicate()
		lumo_held = true
	# A one-point path keeps Lumo standing (the walk planner refills an empty one).
	world.village_life.lumo_path.assign([Vector3(spot.x, 0.0, spot.z)])
	world.village_life.lumo_target = 0
	lumo.position = Vector3(spot.x, TERRAIN.height(spot.x, spot.z) + float(lumo.get_meta("foot_offset", 0.0)), spot.z)
	var camera_at: Vector3 = world.camera.global_position
	lumo.rotation.y = atan2(camera_at.x - spot.x, camera_at.z - spot.z)
	if lumo.has_method("set_locomotion_speed"):
		lumo.set_locomotion_speed(0.0)


func release_lumo() -> void:
	if not lumo_held:
		return
	lumo_held = false
	if is_instance_valid(world.village_life):
		world.village_life.lumo_path.assign(held_path if held_path.size() > 1 else [])
		world.village_life.lumo_target = 0
		if world.village_life.lumo_path.is_empty() and world.village_life.has_method("_plan_lumo_walk"):
			world.village_life._plan_lumo_walk(world.model.player())
	held_path.clear()


## Bildschirmpunkt eines Weltpunkts in safe_ui-Koordinaten (oder INF).
func screen_of(where: Vector3) -> Vector2:
	if world.camera == null or world.camera.is_position_behind(where):
		return Vector2.INF
	var screen: Vector2 = world.camera.unproject_position(where)
	return world.safe_ui.get_global_transform_with_canvas().affine_inverse() * screen


func building_point(kind: String) -> Vector2:
	for building in world.model.player().buildings:
		if str(building.kind) == kind:
			return screen_of(world._plot_world(int(building.plot)) + Vector3.UP * 1.6)
	return Vector2.INF


func food_chip_point() -> Vector2:
	var rect: Rect2 = world._hud_rect(world.resource_chips.food)
	return rect.get_center()


func flow_ends() -> Array:
	match flow:
		"hof_vorrat":
			return [building_point("farm"), food_chip_point()]
		"vorrat_familie":
			return [food_chip_point(), building_point("house")]
	return []


func start_flow(kind: String, amount: int) -> void:
	flow = kind
	flow_amount = amount
	flow_time = 0.0
	flow_label.text = ("+%d" if kind == "hof_vorrat" else "−%d") % amount
	flow_label.visible = amount > 0
	set_meta("flow", kind)
	queue_redraw()


func stop_flow() -> void:
	flow = ""
	flow_label.hide()
	set_meta("flow", "")
	queue_redraw()


func _process(delta: float) -> void:
	if flying:
		flight_time += delta
		var k := clampf(flight_time / FLIGHT_SECONDS, 0.0, 1.0)
		# Erst ruhig schweben, dann sanft hinunter (smoothstep).
		var ease := k * k * (3.0 - 2.0 * k)
		world.focus = (flight_from.focus as Vector3).lerp(flight_to.focus, ease)
		world.orbit = lerp_angle(float(flight_from.orbit), float(flight_to.orbit), ease)
		world.tilt = lerpf(float(flight_from.tilt), float(flight_to.tilt), ease)
		world.radius = lerpf(float(flight_from.radius), float(flight_to.radius), ease)
		world.pan_velocity = Vector3.ZERO
		world._camera_update(true)
		if k >= 1.0:
			finish_flight()
	if not flow.is_empty():
		flow_time += delta
		var ends := flow_ends()
		if ends.size() == 2 and ends[0] != Vector2.INF:
			flow_label.position = (ends[0] as Vector2) + Vector2(-20, -70)
		queue_redraw()


func _draw() -> void:
	if flow.is_empty() or carrot == null:
		return
	var ends := flow_ends()
	if ends.size() != 2 or ends[0] == Vector2.INF or ends[1] == Vector2.INF:
		return
	var a: Vector2 = ends[0]
	var b: Vector2 = ends[1]
	var lift := Vector2(0, -minf(220.0, a.distance_to(b) * 0.35))
	var control := (a + b) * 0.5 + lift
	# Gestrichelter Weg, damit der Zusammenhang auch im Standbild lesbar ist.
	var previous := a
	for index in range(1, 25):
		var t := float(index) / 24.0
		var point := a.lerp(control, t).lerp(control.lerp(b, t), t)
		if index % 2 == 1:
			draw_line(previous, point, Color(1.0, 0.86, 0.35, 0.9), 6.0, true)
		previous = point
	var count := clampi(flow_amount, 1, 6)
	for index in range(count):
		var t := fmod(flow_time / FLOW_SECONDS + float(index) / float(count), 1.0)
		var point := a.lerp(control, t).lerp(control.lerp(b, t), t)
		var size := Vector2.ONE * 46.0
		draw_texture_rect(carrot, Rect2(point - size * 0.5, size), false)
