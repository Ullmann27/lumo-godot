extends Node3D
## Roadside badger crews throw a clearly telegraphed lasso at one side lane.
## Geometry and gameplay share one plan. The controller owns the only clock.

const RULES = preload("res://scripts/games/kart_lasso_rules.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const SPEED_META: StringName = &"roadside_speed_factor"
const GOLD := Color("ffb735")
const NAVY := Color("15375a")
const CYAN := Color("48deff")

var rules = RULES.new()
var layout: Array[Dictionary] = []
var views: Array[Dictionary] = []
var world
var clock: float = 0.0
var catches: int = 0
var dodges: int = 0
var _last_warning: int = -1
var _materials: Dictionary = {}
var _meshes: Dictionary = {}


static func plan(race_world) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var track_length: float = float(race_world.length)
	if track_length < 250.0:
		return result
	var blocked: Array = [Vector2(0.0, 90.0), Vector2(track_length - 70.0, track_length)]
	var jump: Dictionary = race_world.jump
	if not jump.is_empty():
		blocked.append(Vector2(float(jump.ramp_start) - 100.0, float(jump.gap_end) + 80.0))
	var loop: Dictionary = race_world.loop_layout
	if not loop.is_empty():
		blocked.append(Vector2(float(loop.start) - 100.0, float(loop.start) + 100.0))
	for ramp in race_world.action.get("kickers", []):
		blocked.append(Vector2(float(ramp.start) - 85.0, float(ramp.take_off) + 85.0))
	for dive in race_world.action.get("dives", []):
		blocked.append(Vector2(float(dive.start) - 20.0, float(dive.end) + 20.0))
	for gate in race_world.action.get("gates", []):
		blocked.append(Vector2(float(gate.distance) - 25.0, float(gate.distance) + 20.0))
	if str(race_world.track_id) == "sonnenhafen":
		blocked.append(Vector2(track_length * 0.675, track_length * 0.815))
	var taken: Array = []
	var fractions: Array = [0.28, 0.87] if track_length > 900.0 else [0.51]
	for fraction in fractions:
		var at: float = ACTION._free_start(fraction * track_length, 5.0, track_length, blocked, taken)
		if at < 0.0:
			continue
		var side: float = 1.0 if result.size() % 2 == 0 else -1.0
		result.append({"distance": at + 2.5, "lateral": side * 2.8, "side": side})
		taken.append(Vector2(at - 95.0, at + 95.0))
	return result


func setup(race_world, geometry_only: bool = false) -> void:
	world = race_world
	layout = plan(world)
	rules.configure(float(world.length), layout)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	views.clear()
	clock = 0.0
	catches = 0
	dodges = 0
	_last_warning = -1
	set_process(false)
	set_physics_process(false)
	if not geometry_only:
		for entry in layout:
			views.append(_build_crew(entry))
	set_meta("encounter_count", layout.size())


func advance(game, delta: float) -> void:
	if not game.racing or game.paused or game.finished or game.mode == "arena" or delta <= 0.0:
		return
	clock += delta
	var protected: bool = game.shield_time > 0.0 or game.boost_time > 0.0
	var result: Dictionary = rules.advance(
		"player", game.distance, game.lane, game.speed, delta,
		protected, game.airborne or game.loop_state.active
	)
	game.player.set_meta(SPEED_META, float(result.speed_factor))
	if result.event == "caught":
		game.speed *= RULES.SPEED_FACTOR
		game.physical_velocity *= RULES.SPEED_FACTOR
		catches += 1
		game.message.text = "Lasso erwischt! Mit Schild oder Turbo befreien!"
		game._sound_effect("collision")
	elif result.event == "dodged":
		dodges += 1
		game.message.text = "Lasso ausgewichen!"
	elif result.event == "blocked" or result.event == "released":
		game.message.text = "Lasso abgewehrt!"
	var warning: int = int(result.warning)
	if warning >= 0 and warning != _last_warning:
		var side: String = "rechts" if float(layout[warning].lateral) > 0.0 else "links"
		game.message.text = "Lasso %s – ausweichen, Schild oder Turbo!" % side
	_last_warning = warning
	for index in range(game.opponents.size()):
		var rival = game.opponents[index]
		var flying: bool = _active_meta(rival, &"lumo_ballistic_flight") or _active_meta(rival, &"lumo_physical_loop")
		var rival_result: Dictionary = rules.advance(
			"rival_%d" % index, game.opponent_distances[index], game.opponent_lanes[index],
			absf(rival.motion_speed), delta,
			game.opponent_shield_times[index] > 0.0 or game.opponent_boost_times[index] > 0.0,
			flying
		)
		rival.set_meta(SPEED_META, float(rival_result.speed_factor))
	_present(result, game.player, game.reduced_motion)


func _active_meta(racer: Node3D, key: StringName) -> bool:
	if not racer.has_meta(key):
		return false
	var state = racer.get_meta(key)
	return state != null and bool(state.active)


func _present(result: Dictionary, racer: Node3D, reduced_motion: bool) -> void:
	for index in range(views.size()):
		var view: Dictionary = views[index]
		var warning: bool = int(result.warning) == index
		var caught: bool = int(result.index) == index and float(result.remaining) > 0.0
		var active: bool = warning or caught
		var marker: MeshInstance3D = view.marker
		marker.visible = active
		marker.scale = Vector3.ONE * (1.0 if reduced_motion else 1.0 + sin(clock * 5.0) * 0.06)
		var rope: MeshInstance3D = view.ring
		var anchor: Vector3 = view.anchor
		var target: Vector3 = Vector3(float(layout[index].lateral), 0.9, 0.0)
		if caught:
			target = (view.root as Node3D).to_local(racer.global_position) + Vector3.UP * 0.6
		rope.position = target if active else anchor
		rope.rotation.x = 0.0 if active else PI * 0.5
		rope.rotation.y = 0.0 if reduced_motion else clock * (1.8 if warning else 0.5)
		var beam_nodes: Array = view.beams
		for segment in range(beam_nodes.size()):
			var beam: MeshInstance3D = beam_nodes[segment]
			beam.visible = active
			if active:
				var a: Vector3 = _rope_point(anchor, target, float(segment) / beam_nodes.size())
				var b: Vector3 = _rope_point(anchor, target, float(segment + 1) / beam_nodes.size())
				var direction: Vector3 = b - a
				beam.position = (a + b) * 0.5
				beam.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
				beam.scale = Vector3(1.0, maxf(direction.length(), 0.01), 1.0)
		var actor = view.actor
		if actor.global_position.distance_squared_to(racer.global_position) < 150.0 * 150.0:
			actor.set_companion_pose(0.0 if reduced_motion else clock, "help" if active else "idle")


func _rope_point(a: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(b, t) + Vector3.UP * sin(t * PI) * 0.65


func _build_crew(entry: Dictionary) -> Dictionary:
	var crew := Node3D.new()
	crew.name = "LassoCrew%d" % views.size()
	add_child(crew)
	var at: float = float(entry.distance)
	crew.transform = Transform3D(world.frame(at), world.position_at(at))
	var side: float = float(entry.side)
	var dock := Vector3(side * 7.7, 0.0, 0.0)
	_box(crew, dock + Vector3(0, 0.15, 0), Vector3(3.6, 0.3, 4.2), NAVY)
	_box(crew, dock + Vector3(0, 0.35, 0), Vector3(3.3, 0.1, 3.9), Color("976b46"))
	for edge in [-1.0, 1.0]:
		_box(crew, dock + Vector3(edge * 1.6, 0.9, 1.7), Vector3(0.13, 1.3, 0.13), GOLD)
	_box(crew, dock + Vector3(0, 1.3, 1.7), Vector3(3.4, 0.14, 0.14), GOLD)
	var actor = VEHICLE.new()
	actor.name = "RoadsideBadger"
	crew.add_child(actor)
	actor.configure_companion("badger")
	actor.position = dock + Vector3(0.0, 0.4, 0.25)
	actor.scale = Vector3.ONE * 1.65
	actor.rotation.y = side * 0.65
	actor.set_process(false)
	# A navy cap and gold insignia distinguish this crew from the racing roster.
	if is_instance_valid(actor.head):
		_box(actor.head, Vector3(0, 0.25, 0.0), Vector3(0.65, 0.12, 0.48), NAVY)
		_box(actor.head, Vector3(0, 0.20, -0.15), Vector3(0.76, 0.045, 0.45), GOLD)
	var sign := Label3D.new()
	sign.text = "LASSO!"
	sign.font_size = 64
	sign.pixel_size = 0.017
	sign.modulate = Color("fff2bc")
	sign.outline_modulate = NAVY
	sign.outline_size = 12
	sign.position = dock + Vector3(0, 3.9, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	crew.add_child(sign)
	var marker: MeshInstance3D = _mesh(crew, _torus(1.31, RULES.HALF_WIDTH), GOLD, Vector3(float(entry.lateral), 0.065, 0))
	marker.name = "LassoTargetLane"
	marker.visible = false
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var anchor := Vector3(side * 6.9, 2.7, -0.4)
	var ring: MeshInstance3D = _mesh(crew, _torus(0.84, 0.94), GOLD, anchor)
	ring.rotation.x = PI * 0.5
	var beams: Array[MeshInstance3D] = []
	for index in range(6):
		var beam: MeshInstance3D = _mesh(crew, _cylinder(), GOLD, Vector3.ZERO)
		beam.visible = false
		beams.append(beam)
	# Permanent lane chevrons remain readable even before the active warning.
	for offset in [18.0, 38.0, 60.0]:
		var sign_at: float = at - offset
		var b: Basis = world.frame(sign_at)
		var p: Vector3 = world.position_at(sign_at, side * 5.7)
		var post: MeshInstance3D = _box(self, p + b.y * 1.0, Vector3(0.13, 2.0, 0.13), NAVY)
		post.basis = b
		var flag: MeshInstance3D = _box(self, p + b.y * 2.0, Vector3(0.7, 0.7, 0.08), GOLD)
		flag.basis = b.rotated(b.z, PI * 0.25)
	return {"root": crew, "actor": actor, "marker": marker, "ring": ring, "anchor": anchor, "beams": beams}


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	if not _meshes.has("box"):
		_meshes.box = BoxMesh.new()
	var node: MeshInstance3D = _mesh(parent, _meshes.box, color, at)
	node.scale = size
	return node


func _mesh(parent: Node3D, mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var key: String = color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = 0.15
		material.roughness = 0.54
		if color == GOLD:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 0.36
		_materials[key] = material
	node.material_override = _materials[key]
	parent.add_child(node)
	return node


func _torus(inner: float, outer: float) -> TorusMesh:
	var key: String = "ring_%s_%s" % [inner, outer]
	if not _meshes.has(key):
		var mesh := TorusMesh.new()
		mesh.inner_radius = inner
		mesh.outer_radius = outer
		mesh.rings = 24
		mesh.ring_segments = 8
		_meshes[key] = mesh
	return _meshes[key]


func _cylinder() -> CylinderMesh:
	if not _meshes.has("rope"):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.045
		mesh.bottom_radius = 0.045
		mesh.height = 1.0
		mesh.radial_segments = 6
		_meshes.rope = mesh
	return _meshes.rope
