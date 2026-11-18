extends Node3D
## Draws one planned course: star trails, hurdles, rocks, crates, water channels,
## bounce pads, boost strips, high paths, checkpoint flags and the finish gate.
## Static parts are batched into MultiMeshes per stretch of road; only things that
## change (stars taken, crates, rollers, pads, flags) are addressed individually.

const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")
const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const JUNGLE_PROPS = preload("res://scripts/games/run/jungle/run_jungle_props.gd")
const CHUNK: float = 120.0
const STAR_SHADER: String = """
shader_type spatial;
render_mode unshaded;
uniform float spin = 1.7;
varying float shade;
varying float rim;
void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float a = TIME * spin + phase;
	float c = cos(a);
	float sn = sin(a);
	vec3 v = VERTEX;
	rim = smoothstep(0.55, 1.0, length(v.xy));
	float bob = sin(TIME * 2.0 + phase) * 0.08 * step(0.001, spin);
	VERTEX = vec3(c * v.x + sn * v.z, v.y + bob, -sn * v.x + c * v.z);
	vec3 n = NORMAL;
	n = vec3(c * n.x + sn * n.z, n.y, -sn * n.x + c * n.z);
	NORMAL = n;
	shade = 0.78 + 0.22 * clamp(n.y * 0.6 + abs(n.z) * 0.8, 0.0, 1.0);
}
void fragment() {
	ALBEDO = mix(COLOR.rgb * shade, vec3(1.0, 0.97, 0.78), rim * 0.55);
}
"""

var world
var plan
var theme: Dictionary = {}
var low: bool = false
var reduced_motion: bool = false
var _meshes: Dictionary = {}
var _groups: Dictionary = {}
var _lit: StandardMaterial3D
var _bright: StandardMaterial3D
var _star_nodes: Array[MultiMesh] = []
var _star_chunk := PackedInt32Array()
var _star_slot := PackedInt32Array()
var _crates: Dictionary = {}
var _rollers: Dictionary = {}
var _pads: Dictionary = {}
var _pad_squash: Dictionary = {}
var _banners: Array[MeshInstance3D] = []
var _banner_labels: Array[Label3D] = []
var _part_range: float = 0.0
## Adventure path: the moving parts live in run_jungle_props.gd.
var jungle
var track
var player


func build(race_world, course_plan, look: Dictionary, lightweight: bool, calm: bool) -> void:
	world = race_world
	plan = course_plan
	theme = look
	low = lightweight
	reduced_motion = calm
	_lit = StandardMaterial3D.new()
	_lit.roughness = 0.78
	_lit.vertex_color_use_as_albedo = true
	_lit.vertex_color_is_srgb = true
	_bright = _lit.duplicate()
	_bright.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_part_range = 150.0 if low else 210.0
	_build_stars()
	if plan.adventure:
		jungle = JUNGLE_PROPS.new()
		jungle.name = "JungleProps"
		add_child(jungle)
		jungle.build(world, plan, calm)
		_part_range = 0.0
		for checkpoint in plan.checkpoints:
			_build_checkpoint(checkpoint)
		_build_finish()
		_flush()
		return
	for hurdle in plan.hurdles:
		_build_hurdle(hurdle)
	for index in range(plan.blockers.size()):
		_build_blocker(index, plan.blockers[index])
	for channel in plan.channels:
		_build_channel(channel)
	for index in range(plan.bounces.size()):
		_build_bounce(index, plan.bounces[index])
	for strip in plan.boosts:
		if not bool(strip.get("existing", false)):
			_build_boost(strip)
	for platform in plan.platforms:
		_build_platform(platform)
	# Flags and the finish gate are landmarks: visible from as far as the world shows.
	_part_range = 0.0
	for checkpoint in plan.checkpoints:
		_build_checkpoint(checkpoint)
	_build_finish()
	_flush()


# ------------------------------------------------------------------ live changes

func hide_star(index: int) -> void:
	if index < 0 or index >= _star_chunk.size():
		return
	# Shrunk in place: moving it away would stretch the batch's bounds and with
	# them its visibility range.
	_star_nodes[_star_chunk[index]].set_instance_transform(
		_star_slot[index], Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), star_position(index))
	)


func star_position(index: int) -> Vector3:
	return point(plan.star_s[index], plan.star_lat[index], plan.star_h[index])


func break_crate(index: int) -> void:
	if _crates.has(index):
		_crates[index].hide()


func knock_roller(index: int) -> void:
	if _rollers.has(index):
		_rollers[index].hide()


func press_bounce(index: int) -> void:
	_pad_squash[index] = 1.0
	if jungle != null:
		jungle.press_mushroom(index)


func take_letter(index: int) -> void:
	if jungle != null:
		jungle.take_letter(index)


func letter_position(index: int) -> Vector3:
	return jungle.letter_position(index) if jungle != null else Vector3.ZERO


func grab_ride(index: int) -> void:
	if jungle != null:
		jungle.grab_ride(index)


func squash_enemy(index: int) -> void:
	if jungle != null:
		jungle.squash_enemy(index)


func open_gate(checkpoint: int) -> void:
	if jungle != null:
		jungle.open_gate(checkpoint)


func sync_platforms() -> void:
	pass


func set_checkpoint(index: int, reached: bool) -> void:
	if index < 0 or index >= _banners.size():
		return
	var material := _banners[index].material_override as StandardMaterial3D
	var colour: Color = Color("ffd75e") if reached else Color(theme.flag)
	material.albedo_color = colour
	material.emission = colour
	_banner_labels[index].modulate = Color("23324a") if reached else Color("ffffff")


## Brings the view in line with a restored or freshly reset track state.
func sync(track) -> void:
	for index in range(track.taken.size()):
		if track.taken[index] != 0:
			hide_star(index)
	for index in track.broken:
		break_crate(int(index))
		knock_roller(int(index))
	for index in range(_banners.size()):
		set_checkpoint(index, index <= track.checkpoint)
	if jungle != null:
		jungle.sync()


func advance(delta: float, time: float, player_s: float) -> void:
	if jungle != null:
		jungle.advance(delta, time, player_s, player)
	for index in _rollers:
		var node: Node3D = _rollers[index]
		var blocker: Dictionary = plan.blockers[index]
		if not node.visible or absf(float(blocker.s) - player_s) > 150.0:
			continue
		var lateral: float = float(blocker.lat) + float(blocker.amp) * sin(
			time * float(blocker.rate) + float(blocker.phase)
		)
		var frame: Basis = world.frame(float(blocker.s))
		var radius: float = float(blocker.radius)
		node.transform = Transform3D(
			frame.rotated(frame.z.normalized(), lateral / radius),
			point(float(blocker.s), lateral, radius)
		)
	for index in _pad_squash.keys():
		var value: float = maxf(0.0, float(_pad_squash[index]) - delta * 4.0)
		var top: Node3D = _pads.get(index)
		if top != null:
			top.position.y = 0.52 + (0.0 if reduced_motion else sin(value * PI) * 0.35 - value * 0.12)
		if value <= 0.0:
			_pad_squash.erase(index)
		else:
			_pad_squash[index] = value


# ------------------------------------------------------------------ geometry helpers

func point(s: float, lat: float, h: float) -> Vector3:
	return world.position_at(s, lat) + world.frame(s).y * h


func _half_road(s: float) -> float:
	return float(world.wall_lateral_at(s)) + 0.95


func _mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var mesh: Mesh
	match kind:
		"star":
			mesh = SHAPES.star()
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
			cylinder.radial_segments = 10 if low else 16
			cylinder.rings = 1
			mesh = cylinder
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5
			cone.height = 1.0
			cone.radial_segments = 8 if low else 12
			cone.rings = 1
			mesh = cone
		"ball":
			var ball := SphereMesh.new()
			ball.radius = 0.5
			ball.height = 1.0
			ball.radial_segments = 12 if low else 20
			ball.rings = 6 if low else 10
			mesh = ball
		_:
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			mesh = box
	_meshes[kind] = mesh
	return mesh


## Queues one coloured primitive at a road position; `turn` rotates it in the road frame.
func _add(
	kind: String, s: float, lat: float, h: float, size: Vector3, colour: Color,
	glow: bool = false, turn: Basis = Basis.IDENTITY
) -> void:
	var frame: Basis = world.frame(s)
	var key: String = "%s|%d|%d" % [kind, 1 if glow else 0, floori(s / CHUNK)]
	if not _groups.has(key):
		_groups[key] = {"kind": kind, "glow": glow, "transforms": [], "colours": []}
	_groups[key].transforms.append(Transform3D((frame * turn).scaled_local(size), point(s, lat, h)))
	_groups[key].colours.append(colour)


func _flush() -> void:
	for key in _groups:
		var group: Dictionary = _groups[key]
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_colors = true
		instances.mesh = _mesh(str(group.kind))
		instances.instance_count = group.transforms.size()
		for index in range(instances.instance_count):
			instances.set_instance_transform(index, group.transforms[index])
			instances.set_instance_color(index, group.colours[index])
		var node := MultiMeshInstance3D.new()
		node.name = "Run_" + str(key).replace("|", "_")
		node.multimesh = instances
		node.material_override = _bright if bool(group.glow) else _lit
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 150.0 if low else 210.0
		node.visibility_range_end_margin = 12.0
		add_child(node)
	_groups.clear()


func _solid(colour: Color, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.75
	if glow:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = 0.55
	return material


func _part(parent: Node3D, kind: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = _mesh(kind)
	part.position = at
	part.scale = size
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.visibility_range_end = _part_range
	part.visibility_range_end_margin = 12.0 if _part_range > 0.0 else 0.0
	parent.add_child(part)
	return part


func _holder(s: float, lat: float, h: float, label: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = label
	holder.transform = Transform3D(world.frame(s), point(s, lat, h))
	add_child(holder)
	return holder


# ------------------------------------------------------------------ stars

func _build_stars() -> void:
	var shader := Shader.new()
	shader.code = STAR_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("spin", 0.0 if reduced_motion else 1.7)
	var buckets: Dictionary = {}
	for index in range(plan.star_s.size()):
		var chunk: int = floori(plan.star_s[index] / CHUNK)
		if not buckets.has(chunk):
			buckets[chunk] = []
		buckets[chunk].append(index)
	_star_chunk.resize(plan.star_s.size())
	_star_slot.resize(plan.star_s.size())
	for chunk in buckets:
		var members: Array = buckets[chunk]
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_colors = true
		instances.use_custom_data = true
		instances.mesh = _mesh("star")
		instances.instance_count = members.size()
		for slot in range(members.size()):
			var index: int = int(members[slot])
			var gold: bool = plan.star_value[index] > 1
			var frame: Basis = world.frame(plan.star_s[index])
			instances.set_instance_transform(
				slot,
				Transform3D(frame.scaled_local(Vector3.ONE * (0.95 if gold else 0.62)), star_position(index))
			)
			instances.set_instance_color(slot, Color("ffe86b") if gold else Color("ffb81f"))
			instances.set_instance_custom_data(slot, Color(fmod(plan.star_s[index] * 0.28, TAU), 0, 0, 0))
			_star_chunk[index] = _star_nodes.size()
			_star_slot[index] = slot
		var node := MultiMeshInstance3D.new()
		node.name = "RunStars%d" % int(chunk)
		node.multimesh = instances
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 150.0 if low else 210.0
		node.visibility_range_end_margin = 12.0
		add_child(node)
		_star_nodes.append(instances)


# ------------------------------------------------------------------ obstacles

func _build_hurdle(hurdle: Dictionary) -> void:
	var s: float = float(hurdle.s)
	var road: float = _half_road(s)
	var left: float = maxf(float(hurdle.lat) - float(hurdle.half), -road)
	var right: float = minf(float(hurdle.lat) + float(hurdle.half), road)
	var centre: float = (left + right) * 0.5
	var width: float = right - left
	var body: Color = theme.hurdle
	var trim: Color = theme.hurdle_trim
	var sideways := Basis(Vector3.BACK, PI * 0.5)
	match str(plan.course.theme):
		"jungle":
			# A fallen log with bright rope bands.
			_add("cylinder", s, centre, 0.34, Vector3(0.64, width, 0.64), body, false, sideways)
			for side in [-1.0, 1.0]:
				_add("cylinder", s, centre + side * width * 0.5, 0.34, Vector3(0.56, 0.06, 0.56), body.lightened(0.35), false, sideways)
			var bands: int = maxi(2, roundi(width / 1.6))
			for band in range(bands):
				var lat: float = left + width * (float(band) + 0.5) / float(bands)
				_add("cylinder", s, lat, 0.34, Vector3(0.70, 0.22, 0.70), trim, true, sideways)
		"forest":
			# A dark root with a glowing edge and little light caps.
			_add("box", s, centre, 0.26, Vector3(width, 0.52, 0.5), body)
			_add("box", s, centre, 0.56, Vector3(width, 0.10, 0.56), trim, true)
			var caps: int = maxi(2, roundi(width / 1.3))
			for cap in range(caps):
				var lat: float = left + width * (float(cap) + 0.5) / float(caps)
				_add("ball", s, lat, 0.70, Vector3(0.34, 0.22, 0.34), trim.lightened(0.3), true)
		_:
			# A harbour barrier: red and white plank on two posts.
			var planks: int = maxi(2, roundi(width / 0.9))
			for plank in range(planks):
				var lat: float = left + width * (float(plank) + 0.5) / float(planks)
				_add("box", s, lat, 0.46, Vector3(width / float(planks) + 0.01, 0.34, 0.16), trim if plank % 2 == 0 else body, plank % 2 == 0)
			for side in [-1.0, 1.0]:
				_add("box", s, centre + side * (width * 0.5 - 0.2), 0.32, Vector3(0.2, 0.64, 0.3), Color("2f4a66"))


func _build_blocker(index: int, blocker: Dictionary) -> void:
	var s: float = float(blocker.s)
	var lat: float = float(blocker.lat)
	var radius: float = float(blocker.radius)
	match str(blocker.kind):
		"rock":
			_build_rock(s, lat, radius)
		"crate":
			var holder: Node3D = _holder(s, lat, 0.0, "RunCrate%d" % index)
			var wood: StandardMaterial3D = _solid(theme.crate)
			var trim: StandardMaterial3D = _solid(theme.crate_trim)
			_part(holder, "box", Vector3(0, 0.72, 0), Vector3(1.36, 1.36, 1.36), wood)
			for height in [0.14, 1.30]:
				_part(holder, "box", Vector3(0, height, 0), Vector3(1.46, 0.2, 1.46), trim)
			var emblem: MeshInstance3D = _part(holder, "star", Vector3(0, 0.72, 0.70), Vector3.ONE * 0.36, _solid(Color("ffd75e"), true))
			emblem.name = "Emblem"
			_crates[index] = holder
		"roller":
			var holder: Node3D = _holder(s, lat, radius, "RunRoller%d" % index)
			var stone: StandardMaterial3D = _solid(theme.roller)
			_part(holder, "ball", Vector3.ZERO, Vector3.ONE * radius * 2.0, stone)
			var white: StandardMaterial3D = _solid(Color("ffffff"), true)
			var dark: StandardMaterial3D = _solid(Color("1c2233"))
			for side in [-1.0, 1.0]:
				_part(holder, "ball", Vector3(side * 0.3, 0.18, radius * 0.86), Vector3(0.34, 0.4, 0.2), white)
				_part(holder, "ball", Vector3(side * 0.3, 0.14, radius * 0.95), Vector3(0.16, 0.2, 0.1), dark)
				_part(holder, "cone", Vector3(side * radius * 0.92, 0, 0), Vector3(0.4, 0.4, 0.4), _solid(Color(theme.roller).lightened(0.25))).rotation.z = -side * PI * 0.5
			_part(holder, "cone", Vector3(0, radius * 0.92, 0), Vector3(0.4, 0.4, 0.4), _solid(Color(theme.roller).lightened(0.25)))
			_rollers[index] = holder


func _build_rock(s: float, lat: float, radius: float) -> void:
	var rock: Color = theme.rock
	var top: Color = theme.rock_top
	match str(plan.course.theme):
		"jungle":
			_add("ball", s, lat, radius * 0.72, Vector3(radius * 2.1, radius * 1.7, radius * 2.0), rock)
			_add("ball", s, lat, radius * 1.42, Vector3(radius * 1.5, radius * 0.5, radius * 1.4), top)
			if not low:
				_add("ball", s + 0.5, lat + radius * 0.9, 0.25, Vector3(0.7, 0.5, 0.7), rock.darkened(0.15))
		"forest":
			for spike in [[0.0, 0.0, 2.0, 0.9], [0.55, 0.3, 1.4, 0.6], [-0.5, -0.25, 1.2, 0.55]]:
				var tilt := Basis(Vector3.BACK, -float(spike[0]) * 0.5)
				_add("cone", s + float(spike[1]), lat + float(spike[0]), float(spike[2]) * 0.5, Vector3(float(spike[3]) * 1.3, float(spike[2]), float(spike[3]) * 1.3), rock, false, tilt)
				_add("cone", s + float(spike[1]), lat + float(spike[0]) * 1.25, float(spike[2]) * 0.86, Vector3(float(spike[3]) * 0.5, float(spike[2]) * 0.42, float(spike[3]) * 0.5), top, true, tilt)
		_:
			for barrel in [[-0.42, 0.0, 0.55], [0.42, 0.0, 0.55], [0.0, 0.0, 1.62]]:
				var up: float = float(barrel[2])
				_add("cylinder", s, lat + float(barrel[0]), up, Vector3(0.84, 1.08, 0.84), rock)
				_add("cylinder", s, lat + float(barrel[0]), up, Vector3(0.88, 0.2, 0.88), top)


func _build_channel(channel: Dictionary) -> void:
	var s0: float = float(channel.s0)
	var s1: float = float(channel.s1)
	var water: Color = theme.water
	var edge: Color = theme.water_edge
	if not bool(channel.real):
		var slices: int = maxi(3, ceili((s1 - s0) / 0.9))
		for slice in range(slices):
			var s: float = lerpf(s0, s1, (float(slice) + 0.5) / float(slices))
			var road: float = _half_road(s)
			_add("box", s, 0.0, 0.035, Vector3(road * 2.0, 0.05, (s1 - s0) / float(slices) + 0.03), water.lightened(0.12) if slice % 2 == 0 else water, true)
			if slice % 2 == 1 and not low:
				_add("box", s, sin(s) * road * 0.5, 0.07, Vector3(road * 0.5, 0.02, 0.12), edge, true)
		for s in [s0 - 0.2, s1 + 0.2]:
			_add("box", s, 0.0, 0.07, Vector3(_half_road(s) * 2.0, 0.14, 0.4), edge)
	# Tall markers on both sides announce the jump from far away.
	for side in [-1.0, 1.0]:
		var lat: float = side * (_half_road(s0) + 0.1)
		_add("cylinder", s0 - 0.4, lat, 1.2, Vector3(0.16, 2.4, 0.16), Color("2f4a66"))
		_add("box", s0 - 0.4, lat - side * 0.45, 2.1, Vector3(0.9, 0.5, 0.08), water.lightened(0.25), true)
		_add("ball", s0 - 0.4, lat, 2.5, Vector3.ONE * 0.36, edge, true)


func _build_bounce(index: int, pad: Dictionary) -> void:
	var s: float = float(pad.s)
	if bool(pad.get("band", false)):
		var road: float = _half_road(s)
		var height: float = float(world.ramp_height(s))
		_add("box", s, 0.0, height + 0.06, Vector3(road * 2.0, 0.12, 1.7), theme.pad, true)
		var arrows: int = maxi(3, roundi(road / 0.9))
		for arrow in range(arrows):
			var lat: float = -road + road * 2.0 * (float(arrow) + 0.5) / float(arrows)
			for side in [-1.0, 1.0]:
				_add("box", s, lat + side * 0.24, height + 0.14, Vector3(0.14, 0.04, 0.9), theme.pad_trim, true, Basis(Vector3.UP, side * 0.6))
		return
	var holder: Node3D = _holder(s, float(pad.lat), 0.0, "RunBounce%d" % index)
	_part(holder, "cylinder", Vector3(0, 0.08, 0), Vector3(2.5, 0.16, 2.5), _solid(Color("2f4a66")))
	_part(holder, "cylinder", Vector3(0, 0.28, 0), Vector3(1.0, 0.36, 1.0), _solid(theme.pad_trim))
	var top := Node3D.new()
	top.name = "Top"
	top.position.y = 0.52
	holder.add_child(top)
	_part(top, "cylinder", Vector3.ZERO, Vector3(2.4, 0.22, 2.4), _solid(theme.pad, true))
	_part(top, "cylinder", Vector3(0, 0.08, 0), Vector3(1.9, 0.12, 1.9), _solid(theme.pad_trim, true))
	var emblem: MeshInstance3D = _part(top, "star", Vector3(0, 0.17, 0), Vector3.ONE * 0.62, _solid(theme.pad, true))
	emblem.rotation.x = -PI * 0.5
	_pads[index] = top


func _build_boost(strip: Dictionary) -> void:
	var s0: float = float(strip.s0)
	var s1: float = float(strip.s1)
	var colour: Color = theme.boost
	var steps: int = maxi(2, ceili((s1 - s0) / 1.5))
	for step in range(steps):
		var s: float = lerpf(s0, s1, (float(step) + 0.5) / float(steps))
		var road: float = _half_road(s)
		var left: float = maxf(float(strip.lat) - float(strip.half), -road)
		var right: float = minf(float(strip.lat) + float(strip.half), road)
		var centre: float = (left + right) * 0.5
		var width: float = right - left
		_add("box", s, centre, 0.03, Vector3(width, 0.04, (s1 - s0) / float(steps) + 0.03), colour.darkened(0.35), true)
		var arrows: int = maxi(1, roundi(width / 3.4))
		for arrow in range(arrows):
			var lat: float = left + width * (float(arrow) + 0.5) / float(arrows)
			for side in [-1.0, 1.0]:
				_add("box", s, lat + side * 0.42, 0.07, Vector3(0.26, 0.04, 1.25), colour, true, Basis(Vector3.UP, side * 0.7))
	for side in [-1.0, 1.0]:
		var middle: float = (s0 + s1) * 0.5
		var road: float = _half_road(middle)
		var lat: float = clampf(float(strip.lat) + side * (float(strip.half) + 0.1), -road, road)
		_add("box", middle, lat, 0.06, Vector3(0.16, 0.08, s1 - s0), Color("fff6c2"), true)


func _build_platform(platform: Dictionary) -> void:
	var s0: float = float(platform.s0)
	var s1: float = float(platform.s1)
	var lat: float = float(platform.lat)
	var half: float = float(platform.half)
	var top: float = float(platform.top)
	var steps: int = maxi(2, ceili((s1 - s0) / 2.5))
	for step in range(steps):
		var s: float = lerpf(s0, s1, (float(step) + 0.5) / float(steps))
		var piece: float = (s1 - s0) / float(steps) + 0.04
		_add("box", s, lat, top - 0.14, Vector3(half * 2.0, 0.28, piece), theme.platform)
		_add("box", s, lat, top - 0.36, Vector3(half * 1.7, 0.18, piece), theme.platform_side)
		for side in [-1.0, 1.0]:
			_add("box", s, lat + side * (half - 0.07), top + 0.02, Vector3(0.14, 0.08, piece), Color("fff6c2"), true)
	for s in [s0 + 0.5, (s0 + s1) * 0.5, s1 - 0.5]:
		for side in [-1.0, 1.0]:
			_add("cylinder", s, lat + side * (half - 0.25), (top - 0.4) * 0.5, Vector3(0.22, top - 0.4, 0.22), theme.platform_side)


# ------------------------------------------------------------------ flags and gates

func _label(text: String, size: int, colour: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = size
	label.pixel_size = 0.012
	label.modulate = colour
	label.outline_size = 14
	label.outline_modulate = Color(0.05, 0.1, 0.2, 0.9)
	label.double_sided = false
	return label


func _build_checkpoint(checkpoint: Dictionary) -> void:
	var s: float = float(checkpoint.s)
	var road: float = _half_road(s) + 0.5
	var holder: Node3D = _holder(s, 0.0, 0.0, "RunCheckpoint%d" % int(checkpoint.index))
	var pole: StandardMaterial3D = _solid(Color("f4f1e8"))
	for side in [-1.0, 1.0]:
		_part(holder, "cylinder", Vector3(side * road, 2.4, 0), Vector3(0.26, 4.8, 0.26), pole)
		_part(holder, "ball", Vector3(side * road, 4.9, 0), Vector3.ONE * 0.5, _solid(Color("ffd75e"), true))
	var banner: MeshInstance3D = _part(
		holder, "box", Vector3(0, 4.1, 0), Vector3(road * 2.0, 1.0, 0.14), _solid(theme.flag, true)
	)
	_banners.append(banner)
	var question: bool = bool(checkpoint.question)
	var label: Label3D = _label(
		"LERNSTOPP  ?" if question else "KONTROLLPUNKT %d" % (int(checkpoint.index) + 1), 64, Color("ffffff")
	)
	label.position = Vector3(0, 4.1, 0.09)
	holder.add_child(label)
	_banner_labels.append(label)
	_part(holder, "box", Vector3(0, 0.03, 0), Vector3(road * 2.0, 0.04, 0.5), _solid(Color("ffd75e"), true))


func _build_finish() -> void:
	var s: float = plan.finish_s
	var road: float = _half_road(s) + 0.6
	var holder: Node3D = _holder(s, 0.0, 0.0, "RunFinishGate")
	var pillar: StandardMaterial3D = _solid(Color("ffd75e"), true)
	for side in [-1.0, 1.0]:
		_part(holder, "cylinder", Vector3(side * road, 3.0, 0), Vector3(0.5, 6.0, 0.5), pillar)
		_part(holder, "star", Vector3(side * road, 6.5, 0), Vector3.ONE * 0.7, pillar)
	_part(holder, "box", Vector3(0, 5.2, 0), Vector3(road * 2.0, 1.5, 0.2), _solid(Color("1d2a40")))
	var label: Label3D = _label("ZIEL", 128, Color("ffd75e"))
	label.position = Vector3(0, 5.2, 0.12)
	holder.add_child(label)
	var columns: int = roundi(road * 2.0 / 0.9)
	for row in range(2):
		for column in range(columns):
			var lat: float = -road + road * 2.0 * (float(column) + 0.5) / float(columns)
			var white: bool = (row + column) % 2 == 0
			_add(
				"box", s - 0.45 + float(row) * 0.9, lat, 0.03,
				Vector3(road * 2.0 / float(columns), 0.04, 0.9),
				Color("ffffff") if white else Color("1d2a40"), white
			)
