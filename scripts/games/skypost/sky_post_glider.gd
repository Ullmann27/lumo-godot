extends Node3D
## One Sternsegler as seen in the world: the Blender glider with moving
## ailerons, elevator, rudder, propeller and control yoke, and its pilot in the
## open cockpit. Lumo is the original rigged fox (kart seat pose, both hands on
## the yoke); rivals are the animal drivers of Lumo Kart on the same yoke.
## Purely visual: motion comes from sky_post_flight.gd or the rival pilots.

const MODELS = preload("res://scripts/games/skypost/sky_post_models.gd")
const LUMO_ADAPTER = preload("res://scripts/characters/lumo/lumo_kart_animation_adapter.gd")
const RIVAL_DRIVER = preload("res://scripts/games/kart_production_driver.gd")

## Paint (body) and trim colours Lumo can choose in the menu.
const COLOURS := {
	"sternblau": {"name": "Sternblau", "paint": Color("f3efe4"), "trim": Color("2c6fe0")},
	"sonnengelb": {"name": "Sonnengelb", "paint": Color("ffd24a"), "trim": Color("2c6fe0")},
	"kirschrot": {"name": "Kirschrot", "paint": Color("e8473e"), "trim": Color("fff4e0")},
	"mintgruen": {"name": "Mintgrün", "paint": Color("86e3c4"), "trim": Color("1f5f8b")},
}
const COLOUR_ORDER: Array[String] = ["sternblau", "sonnengelb", "kirschrot", "mintgruen"]

## Read by the Lumo/rival adapters (same contract as a kart): the yoke and its grips.
var steering_wheel: Node3D
var wheel_rest_grips: Array = [Vector3(-0.17, 0.0, 0.0), Vector3(0.17, 0.0, 0.0)]
var model: Node3D
var pilot
var pilot_kind: String = ""
var is_lumo: bool = false
var reduced_motion: bool = false
var profile: String = "medium"
var _aileron_l: Node3D
var _aileron_r: Node3D
var _elevator: Node3D
var _rudder: Node3D
var _propeller: Node3D
var _yoke_rest := Transform3D.IDENTITY
var _spin: float = 0.0
var _surfaces := Vector3.ZERO
var _paint: StandardMaterial3D
var _trim: StandardMaterial3D


## [param lod_profile]: "hero" for Lumo's own glider, else the world profile.
func build(lod_profile: String, paint: Color, trim: Color, calm: bool) -> void:
	reduced_motion = calm
	profile = lod_profile
	_paint = _material(paint, 0.3)
	_trim = _material(trim, 0.32)
	model = MODELS.instance("sternsegler", lod_profile, {"SP_Paint": _paint, "SP_Trim": _trim})
	model.name = "Sternsegler"
	add_child(model)
	steering_wheel = MODELS.part(model, "Yoke")
	if steering_wheel == null:
		steering_wheel = Node3D.new()
		steering_wheel.name = "Yoke"
		steering_wheel.position = Vector3(0, 1.02, -0.36)
		model.add_child(steering_wheel)
	_yoke_rest = steering_wheel.transform
	_aileron_l = MODELS.part(model, "AileronL")
	_aileron_r = MODELS.part(model, "AileronR")
	_elevator = MODELS.part(model, "Elevator")
	_rudder = MODELS.part(model, "Rudder")
	_propeller = MODELS.part(model, "Propeller")


func _material(colour: Color, roughness: float) -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.albedo_color = colour
	made.roughness = roughness
	made.metallic_specular = 0.6
	made.clearcoat_enabled = profile != "low"
	made.clearcoat = 0.5
	made.clearcoat_roughness = 0.2
	return made


func set_colours(paint: Color, trim: Color) -> void:
	_paint.albedo_color = paint
	_trim.albedo_color = trim


## Seats the original Lumo (true) or the rival animal [param species].
func seat_pilot(species: String) -> bool:
	if is_instance_valid(pilot):
		return true
	if species == "lumo":
		var adapter = LUMO_ADAPTER.new()
		adapter.name = "LumoPilot"
		add_child(adapter)
		if not adapter.bind_visual(self):
			adapter.queue_free()
			return false
		adapter.set_reduced_motion(reduced_motion)
		pilot = adapter
		pilot_kind = "lumo"
		is_lumo = true
		return true
	var driver = RIVAL_DRIVER.new()
	add_child(driver)
	if not driver.bind_visual(self, species):
		driver.queue_free()
		return false
	# The rival rigs sit a little higher than Lumo; settle them onto the cushion.
	driver.position = Vector3(0, -0.07, 0.02)
	driver.set_reduced_motion(reduced_motion)
	driver.set_graphics_quality("low" if profile == "low" else "medium")
	pilot = driver
	pilot_kind = species
	return true


## Moves the control surfaces, yoke and propeller and feeds the pilot.
## [param stick]: x right, y up; [param boost] while SCHWUNG/ring boost lasts.
func animate(delta: float, stick: Vector2, speed: float, boost: bool, bump: bool = false) -> void:
	var follow: float = 1.0 - exp(-10.0 * delta)
	_surfaces = _surfaces.lerp(Vector3(stick.x, stick.y, stick.x), follow)
	if is_instance_valid(_aileron_l):
		_aileron_l.rotation.x = -_surfaces.x * 0.45
		_aileron_r.rotation.x = _surfaces.x * 0.45
	if is_instance_valid(_elevator):
		_elevator.rotation.x = _surfaces.y * 0.4
	if is_instance_valid(_rudder):
		_rudder.rotation.y = -_surfaces.z * 0.35
	if is_instance_valid(_propeller):
		var turn: float = (34.0 if boost else 9.0 + speed * 0.4) * (0.25 if reduced_motion else 1.0)
		_spin = fmod(_spin + turn * delta, TAU)
		_propeller.rotation.z = _spin
	# The yoke rolls with the stick and moves back when Lumo climbs.
	var yoke := _yoke_rest
	yoke = yoke.rotated_local(Vector3.BACK, -_surfaces.x * 0.55)
	yoke = yoke.rotated_local(Vector3.RIGHT, _surfaces.y * 0.18)
	yoke.origin += Vector3(0, 0, _surfaces.y * 0.05)
	steering_wheel.transform = yoke
	if is_instance_valid(pilot):
		if pilot_kind == "lumo":
			pilot.apply_vehicle_sample(speed, _surfaces.x, false, bump, boost, false)
		else:
			pilot.apply_vehicle_sample(speed, _surfaces.x, false, bump, boost, false)
			pilot.advance_tick(delta)


func set_suspended(value: bool) -> void:
	if is_instance_valid(pilot):
		pilot.set_suspended(value)


func celebrate() -> void:
	if is_instance_valid(pilot):
		if pilot_kind == "lumo":
			pilot.celebrate_finished_race(1)
		else:
			pilot.celebrate_finished_race(1)


func wave() -> bool:
	if is_instance_valid(pilot) and pilot_kind == "lumo":
		return pilot.play_menu_behavior("greeting_wave")
	return false


func wing_tips() -> Array[Vector3]:
	return [to_global(Vector3(-3.95, 0.75, -0.3)), to_global(Vector3(3.95, 0.75, -0.3))]
