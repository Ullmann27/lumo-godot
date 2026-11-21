extends Node3D
## What the child sees of a highlight (see run_moments.gd): a light arch with
## three arrows over the spot where the action happens, which starts to pulse
## in the world colour when the moment is announced, a landing target where a
## jump should come down, and the look of the moment itself (a rolling wave).
## In "ruhige Bewegung" the arch glows steadily instead of pulsing.

const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")

var world
var plan
var reduced_motion: bool = false
var _arches: Array[Node3D] = []
var _beams: Array[Node3D] = []
var _arch_s: Array[float] = []
var _materials: Array[StandardMaterial3D] = []
var _calling: Array[bool] = []
var _waves: Array[Node3D] = []
var _clock: float = 0.0


func build(race_world, course_plan, accent: Color, calm: bool) -> void:
	world = race_world
	plan = course_plan
	reduced_motion = calm
	for index in range(plan.moments.size()):
		var moment: Dictionary = plan.moments[index]
		var colour: Color = Color(str(moment.get("colour", accent.to_html(false))))
		_build_arch(index, moment, colour)
		if moment.has("land_s"):
			_build_target(float(moment.land_s), float(moment.get("land_lat", 0.0)), colour)
		if str(moment.get("look", "")) == "wave":
			_build_wave(moment)
		if bool(moment.get("finale", false)):
			_build_finale_lane(moment, colour)


func set_calling(index: int, value: bool) -> void:
	if index < 0 or index >= _calling.size():
		return
	_calling[index] = value
	_materials[index].emission_energy_multiplier = 2.2 if value else 0.7
	if not value:
		_arches[index].scale = Vector3.ONE


## `player_s`: the beam is for the distance (gone when Lumo is close), the
## ring for the run-up (gone once Lumo is through, so it never hides him).
func advance(delta: float, player_s: float) -> void:
	_clock += delta
	for index in range(_arches.size()):
		_beams[index].visible = player_s < _arch_s[index] - 14.0
		_arches[index].visible = player_s < _arch_s[index] + 0.8
	if reduced_motion:
		return
	for index in range(_arches.size()):
		if _calling[index]:
			var beat: float = 0.5 + 0.5 * sin(_clock * 9.0)
			_arches[index].scale = Vector3.ONE * (1.0 + 0.12 * beat)
			_materials[index].emission_energy_multiplier = 1.4 + 1.6 * beat
	for wave in _waves:
		wave.position = wave.get_meta("rest") + wave.basis.y.normalized() * 0.18 * sin(_clock * 3.2)


func _frame_at(s: float, lat: float, h: float) -> Transform3D:
	return Transform3D(world.frame(s), world.position_at(s, lat) + world.frame(s).y * h)


func _glow(colour: Color, energy: float = 0.7) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _mesh_part(
	parent: Node3D,
	mesh: Mesh,
	at: Vector3,
	size: Vector3,
	material: Material,
	turn: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.rotation = turn
	part.scale = size
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


## Light arch over the action spot: a ring standing across the way and three
## arrows above it that point forward.
func _build_arch(index: int, moment: Dictionary, colour: Color) -> void:
	var at: float = float(moment.get("arch_s", moment.s0))
	var lat: float = float(moment.get("lat", 0.0))
	var lift: float = float(moment.get("arch_h", 0.0))
	var holder := Node3D.new()
	holder.name = "Moment%d" % index
	holder.transform = _frame_at(at, lat, lift)
	add_child(holder)
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 1.6, 0)
	holder.add_child(pivot)
	var material: StandardMaterial3D = _glow(colour)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.55
	ring.outer_radius = 1.8
	ring.rings = 24
	ring.ring_segments = 8
	# The torus lies in its own XZ plane: stand it up across the way.
	_mesh_part(pivot, ring, Vector3.ZERO, Vector3.ONE, material, Vector3(PI * 0.5, 0, 0))
	var arrow := PrismMesh.new()
	arrow.size = Vector3(0.7, 0.55, 0.12)
	for step in range(3):
		_mesh_part(
			pivot,
			arrow,
			Vector3(0, 2.3, -0.6 * float(step)),
			Vector3.ONE,
			material,
			Vector3(-PI * 0.5, 0, 0)
		)
	# A thin beam of light above the ring, seen from far between trees and houses.
	var beam := CylinderMesh.new()
	beam.top_radius = 0.07
	beam.bottom_radius = 0.16
	beam.height = 7.0
	beam.radial_segments = 8
	var light := Node3D.new()
	pivot.add_child(light)
	_mesh_part(light, beam, Vector3(0, 5.3, 0), Vector3.ONE, material)
	var top := SphereMesh.new()
	top.radius = 0.38
	top.height = 0.76
	_mesh_part(light, top, Vector3(0, 8.9, 0), Vector3.ONE, material)
	_beams.append(light)
	_arch_s.append(at)
	_arches.append(pivot)
	_materials.append(material)
	_calling.append(false)


## Landing target: two flat rings and a bright centre on the ground.
func _build_target(s: float, lat: float, colour: Color) -> void:
	var holder := Node3D.new()
	holder.name = "LandingTarget"
	holder.transform = _frame_at(s, lat, 0.05)
	add_child(holder)
	for ring_size in [Vector2(1.5, 1.8), Vector2(0.75, 1.0)]:
		var ring := TorusMesh.new()
		ring.inner_radius = ring_size.x
		ring.outer_radius = ring_size.y
		ring.rings = 24
		ring.ring_segments = 6
		_mesh_part(holder, ring, Vector3.ZERO, Vector3(1, 0.25, 1), _glow(colour, 1.2))
	var centre := CylinderMesh.new()
	centre.top_radius = 0.42
	centre.bottom_radius = 0.42
	centre.height = 0.06
	_mesh_part(holder, centre, Vector3.ZERO, Vector3.ONE, _glow(Color("fff7df"), 1.4))
	var star := MeshInstance3D.new()
	star.mesh = SHAPES.star()
	star.position = Vector3(0, 1.9, 0)
	star.scale = Vector3.ONE * 0.7
	star.material_override = _glow(Color("ffd23a"), 1.3)
	holder.add_child(star)


## A rolling wave across the water of the moment: a long water roll with a
## white foam crest that bobs up and down.
func _build_wave(moment: Dictionary) -> void:
	var s: float = (float(moment.s0) + float(moment.s1)) * 0.5
	var half: float = float(world.wall_lateral_at(s)) + 0.9
	var holder := Node3D.new()
	holder.name = "Wave"
	holder.transform = _frame_at(s, 0.0, -0.35)
	holder.set_meta("rest", holder.position)
	add_child(holder)
	var roll := CylinderMesh.new()
	roll.top_radius = 0.5
	roll.bottom_radius = 0.5
	roll.height = 1.0
	roll.radial_segments = 18
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("35b8f2")
	water.roughness = 0.2
	water.metallic_specular = 0.8
	_mesh_part(
		holder, roll, Vector3.ZERO, Vector3(1.6, half * 2.0, 1.4), water, Vector3(0, 0, PI * 0.5)
	)
	_mesh_part(
		holder,
		roll,
		Vector3(0, 0.62, 0.15),
		Vector3(0.55, half * 2.0, 0.6),
		_glow(Color("f4fbff"), 0.5),
		Vector3(0, 0, PI * 0.5)
	)
	_waves.append(holder)


## The finale stretch: glowing posts in the world colour on both sides, every
## 10 m from the ENDSPURT call to the finish gate, so the last part of a world
## is recognisable at a glance. One mesh for all posts (MultiMesh), unshaded.
func _build_finale_lane(moment: Dictionary, colour: Color) -> void:
	var from: float = float(moment.cue) + 4.0
	var to: float = float(moment.get("lane_to", moment.s1))
	var places: Array[Transform3D] = []
	var at: float = from
	while at <= to + 0.01:
		var half: float = float(world.wall_lateral_at(at)) + 0.45
		for side in [-1.0, 1.0]:
			places.append(_frame_at(at, side * half, 0.0))
		at += 10.0
	var post := CylinderMesh.new()
	post.top_radius = 0.07
	post.bottom_radius = 0.1
	post.height = 1.6
	post.radial_segments = 6
	var lamp := SphereMesh.new()
	lamp.radius = 0.24
	lamp.height = 0.48
	lamp.radial_segments = 10
	lamp.rings = 6
	for part in [[post, Vector3(0, 0.8, 0), Color("f4f1e8")], [lamp, Vector3(0, 1.75, 0), colour]]:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = part[0]
		multi.instance_count = places.size()
		for index in range(places.size()):
			multi.set_instance_transform(index, places[index] * Transform3D(Basis.IDENTITY, part[1]))
		var drawn := MultiMeshInstance3D.new()
		drawn.name = "FinaleLane"
		drawn.multimesh = multi
		drawn.material_override = _glow(part[2], 1.6 if part[2] == colour else 0.4)
		drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(drawn)
