extends Node3D
## The moving and living parts of the adventure path: platforms (drifting,
## bobbing, crumbling), bouncy mushrooms, fallen logs, crabs, beetles and rolling
## coconuts, barrels, vines and the zip line, the four crystal letters, the
## puzzle gates of the learning stops, rescue lanterns and the rolling stone ball.
## Reads the track state each frame; changes nothing in it.

const MESHES = preload("res://scripts/games/run/jungle/run_jungle_meshes.gd")
const SHADERS = preload("res://scripts/games/run/jungle/run_jungle_shaders.gd")
const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const NEAR: float = 140.0
const LOOKS: Dictionary = {
	"moss": [Color("6b8f3a"), Color("7a5a3c")],
	"branch": [Color("8a6a46"), Color("5d4330")],
	"stone": [Color("a59c86"), Color("6f6a5c")],
	"leaf": [Color("58b84a"), Color("2f7d3a")],
	"plank": [Color("c0915a"), Color("7a5a3c")],
	"lily": [Color("4fc06a"), Color("2a8a4a")],
	"ruin": [Color("c9b38c"), Color("8e7f60")],
	"crystal": [Color("8fe8ff"), Color("4d6f9a")],
}

var world
var plan
var track
var reduced_motion: bool = false
var _solid: ShaderMaterial
var _glow: ShaderMaterial
var _platforms: Dictionary = {}
var _mushrooms: Dictionary = {}
var _squash: Dictionary = {}
var _enemies: Dictionary = {}
var _enemy_gone: Dictionary = {}
var _rides: Dictionary = {}
var _letters: Dictionary = {}
var _gates: Dictionary = {}
var _gate_open: Dictionary = {}
var _boulder: Node3D
var _mesh_cache: Dictionary = {}


func build(race_world, course_plan, calm: bool) -> void:
	world = race_world
	plan = course_plan
	reduced_motion = calm
	_solid = SHADERS.material(SHADERS.SOLID)
	_glow = SHADERS.material(SHADERS.GLOW, {"pulse": 0.0, "strength": 1.4})
	for index in range(plan.platforms.size()):
		_build_platform(index, plan.platforms[index])
	for index in range(plan.bounces.size()):
		_build_mushroom(index, plan.bounces[index])
	for hurdle in plan.hurdles:
		_build_log(hurdle)
	for blocker in plan.blockers:
		_build_rubble(blocker)
	for index in range(plan.enemies.size()):
		_build_enemy(index, plan.enemies[index])
	for index in range(plan.rides.size()):
		_build_ride(index, plan.rides[index])
	for index in range(plan.letters.size()):
		_build_letter(index, plan.letters[index])
	for index in range(plan.checkpoints.size()):
		if bool(plan.checkpoints[index].question):
			_build_gate(index, float(plan.checkpoints[index].s) + 1.8)
	if not plan.chase.is_empty():
		_boulder = _node("Boulder", _mesh("boulder"))
		_boulder.visible = false


# ------------------------------------------------------------------ helpers

func point(s: float, lat: float, h: float) -> Vector3:
	return world.position_at(s, lat) + world.frame(s).y * h


func _place(node: Node3D, s: float, lat: float, h: float, yaw: float = 0.0) -> void:
	node.transform = Transform3D(world.frame(s) * Basis(Vector3.UP, yaw), point(s, lat, h))


func _mesh(kind: String) -> Mesh:
	if _mesh_cache.has(kind):
		return _mesh_cache[kind]
	var mesh: Mesh
	match kind:
		"boulder":
			mesh = MESHES.boulder()
		"crab":
			mesh = MESHES.crab()
		"beetle":
			mesh = MESHES.beetle()
		"coconut":
			mesh = MESHES.coconut()
		"barrel":
			mesh = MESHES.barrel()
		"warp":
			mesh = MESHES.barrel(Color("e0a830"))
		"mushroom":
			mesh = MESHES.mushroom(Color("ff5a4e"))
		"gold":
			mesh = MESHES.mushroom(Color("ffc83a"))
		"torch":
			mesh = MESHES.torch()
	_mesh_cache[kind] = mesh
	return mesh


func _node(label: String, mesh: Mesh, material: Material = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material if material != null else _solid
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.visibility_range_end = NEAR
	add_child(node)
	return node


# ------------------------------------------------------------------ builders

func _build_platform(index: int, platform: Dictionary) -> void:
	var look: Array = LOOKS.get(str(platform.look), LOOKS.moss)
	var length: float = float(platform.s1) - float(platform.s0)
	var half: float = float(platform.half)
	var top: float = float(platform.top)
	var kit := MESHES.Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + index
	var depth: float = 0.5 if top < 0.5 else 0.7
	# Deck slab in local platform space: x across, z along (forward is -z), y up.
	MESHES._box(kit, Vector3(0, -depth * 0.5, 0), Vector3(half, depth * 0.5, length * 0.5), look[0])
	MESHES._box(kit, Vector3(0, -depth - 0.2, 0), Vector3(half * 0.8, 0.25, length * 0.45), look[1])
	match str(platform.look):
		"moss", "lily", "leaf":
			for k in range(int(length * 1.5)):
				MESHES.blob(kit, Vector3(rng.randf_range(-half, half), 0.02, rng.randf_range(-length * 0.5, length * 0.5)), Vector3(0.35, 0.12, 0.35), Color(look[0]).lightened(0.15), rng, 0.2, 2, 6)
		"branch":
			MESHES.tube(kit, [Vector3(0, -0.9, length * 0.6), Vector3(0, -0.8, -length * 0.6)], [0.75, 0.6], 8, [look[1], look[1]])
			for k in range(int(length)):
				MESHES.blob(kit, Vector3((-1.0 if k % 2 == 0 else 1.0) * (half + 0.1), -0.1, rng.randf_range(-length * 0.5, length * 0.5)), Vector3(0.6, 0.35, 0.6), Color("3a9e48"), rng, 0.25, 3, 7)
		"crystal":
			for k in range(3):
				MESHES.blob(kit, Vector3(rng.randf_range(-half, half), -depth, rng.randf_range(-length * 0.4, length * 0.4)), Vector3(0.25, 0.9, 0.25), Color("8fe8ff"), rng, 0.1, 3, 5)
	if bool(platform.crumble):
		for k in range(int(length / 0.8)):
			var z: float = -length * 0.5 + 0.4 + float(k) * 0.8
			MESHES._box(kit, Vector3(0, 0.01, z), Vector3(half, 0.02, 0.04), Color("4a3220"))
	var mid: float = (float(platform.s0) + float(platform.s1)) * 0.5
	var node := _node("Platform%d" % index, kit.mesh())
	_place(node, mid, float(platform.lat), top)
	_platforms[index] = {"node": node, "mid": mid}


func _build_mushroom(index: int, pad: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Mushroom%d" % index
	add_child(holder)
	_place(holder, float(pad.s), float(pad.lat), float(pad.get("top", 0.0)))
	var cap := MeshInstance3D.new()
	cap.mesh = _mesh(str(pad.get("look", "mushroom")))
	cap.material_override = _solid
	cap.scale = Vector3.ONE * 0.95
	cap.visibility_range_end = NEAR
	holder.add_child(cap)
	_mushrooms[index] = cap


func _build_log(hurdle: Dictionary) -> void:
	var s: float = float(hurdle.s)
	var road: float = world.half_width_at(s) + 0.6
	var left: float = maxf(float(hurdle.lat) - float(hurdle.half), -road)
	var right: float = minf(float(hurdle.lat) + float(hurdle.half), road)
	var kit := MESHES.Kit.new()
	var bark := Color("7a5232")
	MESHES.tube(kit, [Vector3(left, 0.32, 0), Vector3((left + right) * 0.5, 0.36, 0), Vector3(right, 0.32, 0)], [0.32, 0.34, 0.3], 9, [bark, bark.lightened(0.1), bark], true)
	MESHES.tube(kit, [Vector3(right, 0.32, 0), Vector3(right + 0.01, 0.32, 0)], [0.3, 0.0], 9, [Color("d9b07a"), Color("d9b07a")])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s)
	MESHES.blob(kit, Vector3((left + right) * 0.5, 0.62, 0), Vector3(0.6, 0.12, 0.3), Color("4f9a3c"), rng, 0.2, 2, 7)
	var node := _node("Log%d" % int(s), kit.mesh())
	_quiet(node)
	_place(node, s, 0.0, 0.0)


func _quiet(node: GeometryInstance3D) -> void:
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_rubble(blocker: Dictionary) -> void:
	var kit := MESHES.Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(float(blocker.s) * 10.0)
	var radius: float = float(blocker.radius)
	MESHES._box(kit, Vector3(0, 0.55, 0), Vector3(radius * 0.9, 0.55, radius * 0.8), Color("bfa77f"))
	MESHES._box(kit, Vector3(0.1, 1.35, 0), Vector3(radius * 0.7, 0.3, radius * 0.6), Color("c9b38c"))
	MESHES.blob(kit, Vector3(0, 1.7, 0), Vector3(radius * 0.7, 0.15, radius * 0.6), Color("4f9a3c"), rng, 0.2, 2, 7)
	var node := _node("Rubble%d" % int(blocker.s), kit.mesh())
	_quiet(node)
	_place(node, float(blocker.s), float(blocker.lat), 0.0, rng.randf_range(-0.3, 0.3))


func _build_enemy(index: int, enemy: Dictionary) -> void:
	var node := _node("Enemy%d" % index, _mesh(str(enemy.kind)))
	_enemies[index] = node


func _build_ride(index: int, ride: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Ride%d" % index
	add_child(holder)
	_rides[index] = holder
	match str(ride.kind):
		"barrel", "warp":
			var barrel := MeshInstance3D.new()
			barrel.name = "Barrel"
			barrel.mesh = _mesh("barrel" if str(ride.kind) == "barrel" else "warp")
			barrel.material_override = _solid
			barrel.visibility_range_end = NEAR
			holder.add_child(barrel)
			var star := MeshInstance3D.new()
			star.mesh = preload("res://scripts/games/kart_world_meshes.gd").star()
			star.material_override = _glow
			star.scale = Vector3.ONE * 0.38
			star.position = Vector3(0, 0, -0.8)
			barrel.add_child(star)
			_place(holder, float(ride.s), float(ride.lat), float(ride.h))
			_aim(holder, ride, 0.0)
		"vine":
			var rope := MeshInstance3D.new()
			rope.name = "Rope"
			var kit := MESHES.Kit.new()
			MESHES.tube(kit, [Vector3.ZERO, Vector3(0, -1.0, 0)], [0.06, 0.06], 5, [Color("4a7a2a"), Color("4a7a2a")])
			var rng := RandomNumberGenerator.new()
			rng.seed = index
			for k in range(6):
				MESHES.blob(kit, Vector3(rng.randf_range(-0.1, 0.1), -float(k) / 6.0, 0), Vector3(0.12, 0.03, 0.08), Color("5bb34a"), rng, 0.1, 2, 5)
			rope.mesh = kit.mesh()
			rope.material_override = _solid
			holder.add_child(rope)
			holder.transform = Transform3D(world.frame(float(ride.ps)), point(float(ride.ps), float(ride.lat), float(ride.ph)))
			var branch := MeshInstance3D.new()
			var branch_kit := MESHES.Kit.new()
			MESHES.tube(branch_kit, [Vector3(-4, 0.2, 0), Vector3(4, 0.1, 0)], [0.35, 0.25], 7, [Color("6b4a31"), Color("6b4a31")])
			MESHES.blob(branch_kit, Vector3(0, 0.8, 0), Vector3(2.6, 1.0, 1.6), Color("2f8f3e"), rng, 0.25, 3, 8)
			branch.mesh = branch_kit.mesh()
			branch.material_override = _solid
			holder.add_child(branch)
			_swing(index, ride, float(ride.a0))
		"zip":
			var kit := MESHES.Kit.new()
			var from: Vector3 = point(float(ride.s), float(ride.lat), float(ride.h) + 0.2)
			var to: Vector3 = point(float(ride.ts), float(ride.lat), float(ride.th) + 0.2)
			var steps: int = 16
			var points: Array = []
			var radii: Array = []
			var colours: Array = []
			for k in range(steps + 1):
				var u: float = float(k) / float(steps)
				points.append(from.lerp(to, u) + Vector3.DOWN * float(ride.sag) * 4.0 * u * (1.0 - u))
				radii.append(0.022)
				colours.append(Color("6b5132"))
			MESHES.tube(kit, points, radii, 4, colours)
			for end in [from, to]:
				MESHES.tube(kit, [end + Vector3.DOWN * 6.0, end + Vector3.UP * 0.4], [0.18, 0.15], 6, [Color("6b4a31"), Color("6b4a31")])
			var cable := MeshInstance3D.new()
			cable.mesh = kit.mesh()
			cable.material_override = _solid
			holder.add_child(cable)
			var pulley := MeshInstance3D.new()
			pulley.name = "Pulley"
			pulley.mesh = MESHES.box(Vector3(0.18, 0.3, 0.3), Color("ffcf33"))
			pulley.material_override = _solid
			holder.add_child(pulley)
			pulley.position = from
	_rides[index] = holder


func _build_letter(index: int, letter: Dictionary) -> void:
	var node := MeshInstance3D.new()
	node.name = "Letter%s" % str(letter.char)
	var gem := MESHES.Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 + index
	MESHES.blob(gem, Vector3(0, 0.6, 0), Vector3(0.75, 0.75, 0.3), Color("62d8ff"), rng, 0.0, 3, 6)
	node.mesh = gem.mesh()
	node.material_override = SHADERS.material(SHADERS.GLOW, {"pulse": 0.3, "strength": 1.5})
	var glyph := Label3D.new()
	glyph.text = str(letter.char)
	glyph.font = FONT
	glyph.font_size = 120
	glyph.pixel_size = 0.009
	glyph.outline_size = 18
	glyph.modulate = Color("ffffff")
	glyph.outline_modulate = Color("1a4c8a")
	glyph.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	glyph.position = Vector3(0, 0.6, 0.0)
	glyph.no_depth_test = false
	node.add_child(glyph)
	var halo := MeshInstance3D.new()
	halo.mesh = MESHES.card(2.2, 2.2)
	halo.material_override = SHADERS.material(SHADERS.SHAFT, {"colour": Color(0.5, 0.95, 1.0, 0.5)})
	halo.position = Vector3(0, -1.1, -0.2)
	node.add_child(halo)
	add_child(node)
	_place(node, float(letter.s), float(letter.lat), float(letter.h) - 0.6)
	_letters[index] = node


func _build_gate(index: int, at: float) -> void:
	var half: float = world.half_width_at(at)
	var holder := Node3D.new()
	holder.name = "PuzzleGate%d" % index
	add_child(holder)
	_place(holder, at, 0.0, 0.0)
	var door := MeshInstance3D.new()
	door.name = "Door"
	var kit := MESHES.Kit.new()
	MESHES._box(kit, Vector3(0, 2.2, 0), Vector3(half + 0.3, 2.2, 0.25), Color("a8956e"))
	for row in range(3):
		MESHES._box(kit, Vector3(0, 0.8 + float(row) * 1.4, 0.27), Vector3(half * 0.8, 0.08, 0.04), Color("6f6450"))
	door.mesh = kit.mesh()
	door.material_override = _solid
	holder.add_child(door)
	var sign := Label3D.new()
	sign.text = "?"
	sign.font = FONT
	sign.font_size = 200
	sign.pixel_size = 0.012
	sign.outline_size = 24
	sign.modulate = Color("ffe27a")
	sign.outline_modulate = Color("3a2a10")
	sign.position = Vector3(0, 2.3, 0.32)
	door.add_child(sign)
	_gates[index] = door


# ------------------------------------------------------------------ live

func open_gate(checkpoint: int) -> void:
	_gate_open[checkpoint] = 0.0 if not reduced_motion else 1.0


func take_letter(index: int) -> void:
	if _letters.has(index):
		_letters[index].hide()


func letter_position(index: int) -> Vector3:
	var letter: Dictionary = plan.letters[index]
	return point(float(letter.s), float(letter.lat), float(letter.h))


func squash_enemy(index: int) -> void:
	_enemy_gone[index] = 0.0


func press_mushroom(index: int) -> void:
	_squash[index] = 1.0


func grab_ride(index: int) -> void:
	_squash["ride%d" % index] = 1.0


## Brings platforms back after a rescue (crumbled planks reappear with the track state).
func sync() -> void:
	for bit in range(plan.letters.size()):
		if track.letters & (1 << bit):
			take_letter(bit)
	for index in track.defeated:
		if _enemies.has(index):
			_enemies[index].hide()


func advance(delta: float, time: float, player_s: float, player) -> void:
	for index in _platforms:
		var entry: Dictionary = _platforms[index]
		if absf(float(entry.mid) - player_s) > NEAR:
			continue
		var platform: Dictionary = plan.platforms[index]
		var offset: Vector3 = track.platform_offset(platform, time)
		var drop: float = 0.0
		var crumble: float = track.crumble_progress(index)
		if crumble > 1.0:
			drop = 30.0
		elif crumble > 0.0 and not reduced_motion:
			offset.y += sin(time * 60.0) * 0.04 * crumble
		var node: Node3D = entry.node
		node.visible = drop < 1.0
		_place(node, float(entry.mid) + offset.x, float(platform.lat) + offset.y, float(platform.top) + offset.z)
	for index in _enemies:
		var enemy: Dictionary = plan.enemies[index]
		var node: Node3D = _enemies[index]
		if absf(float(enemy.s) - player_s) > NEAR:
			continue
		if _enemy_gone.has(index):
			_enemy_gone[index] = float(_enemy_gone[index]) + delta
			var t: float = float(_enemy_gone[index])
			node.scale = Vector3(1.0 + t * 2.0, maxf(0.05, 1.0 - t * 4.0), 1.0 + t * 2.0)
			if t > 0.35:
				node.hide()
			continue
		if track.defeated.has(index):
			node.hide()
			continue
		var at: Vector2 = track.enemy_position(enemy, time)
		var yaw: float = 0.0
		match str(enemy.kind):
			"crab":
				yaw = PI
				var step: float = sin(time * 14.0) * 0.06 if not reduced_motion else 0.0
				_place(node, at.x, at.y, absf(step))
			"beetle":
				var heading: float = cos(time * float(enemy.rate) + float(enemy.phase))
				yaw = 0.0 if heading > 0.0 else PI
				_place(node, at.x, at.y, 0.0, yaw)
			"coconut":
				_place(node, at.x, at.y, 0.0, PI)
				if not reduced_motion:
					node.rotate_object_local(Vector3.RIGHT, -time * float(enemy.rate) / 0.45)
	for key in _squash.keys():
		var value: float = maxf(0.0, float(_squash[key]) - delta * 3.5)
		_squash[key] = value
		if typeof(key) == TYPE_INT and _mushrooms.has(key):
			var squash: float = sin(value * PI) * 0.35 if not reduced_motion else 0.0
			_mushrooms[key].scale = Vector3(0.95 + squash, 0.95 - squash, 0.95 + squash)
		if value <= 0.0:
			_squash.erase(key)
	for index in _rides:
		var ride: Dictionary = plan.rides[index]
		if absf(float(ride.s) - player_s) > NEAR:
			continue
		match str(ride.kind):
			"barrel", "warp":
				var active: bool = player.ride_index == index and player.is_riding()
				var holder: Node3D = _rides[index]
				var recoil: float = 0.0
				if active and player.ride_fired:
					recoil = maxf(0.0, 0.3 - player.ride_t) * 1.2
				_aim(holder, ride, time if not active else player.ride_t * 3.0)
				holder.get_node("Barrel").scale = Vector3.ONE * (1.0 + recoil)
			"vine":
				if player.ride_index == index and player.is_riding():
					var u: float = clampf(player.ride_t / float(ride.time), 0.0, 1.0)
					_swing(index, ride, lerpf(float(ride.a0), float(ride.a1), 0.5 - 0.5 * cos(PI * u)))
				elif not reduced_motion:
					_swing(index, ride, float(ride.a0) + sin(time * 1.4) * 0.08)
			"zip":
				var pulley: Node3D = _rides[index].get_node("Pulley")
				if player.ride_index == index and player.is_riding():
					pulley.position = point(player.s, player.lat, player.h + 1.75)
	for index in _gate_open:
		var value: float = minf(1.0, float(_gate_open[index]) + delta * 2.6)
		_gate_open[index] = value
		var door: Node3D = _gates.get(index)
		if door != null:
			door.position.y = -4.6 * smoothstep(0.0, 1.0, value)
			door.visible = value < 1.0
	if _boulder != null:
		_boulder.visible = track.chase_active
		if track.chase_active:
			var radius: float = float(plan.chase.radius)
			_place(_boulder, track.boulder_s, 0.0, radius)
			if not reduced_motion:
				_boulder.rotate_object_local(Vector3.RIGHT, -track.boulder_s / radius)


func _aim(holder: Node3D, ride: Dictionary, time: float) -> void:
	var barrel: Node3D = holder.get_node("Barrel")
	var target: Vector3 = point(float(ride.ts), float(ride.tlat), float(ride.th))
	if str(ride.kind) == "warp":
		target = holder.global_position + Vector3.UP * 10.0 + world.forward(float(ride.s)) * 2.0
	var aim: Vector3 = target - holder.global_position
	if aim.length_squared() < 0.01:
		return
	var wobble: float = 0.0 if reduced_motion else sin(time * 3.0) * 0.12
	barrel.global_transform = Transform3D(Basis.looking_at(aim.normalized(), Vector3.UP).rotated(Vector3.UP, wobble), holder.global_position)


func _swing(index: int, ride: Dictionary, angle: float) -> void:
	var rope: Node3D = _rides[index].get_node("Rope")
	var length: float = float(ride.rope) + 0.4
	rope.transform = Transform3D(Basis(Vector3.RIGHT, angle).scaled_local(Vector3(1.0, length, 1.0)), Vector3.ZERO)
