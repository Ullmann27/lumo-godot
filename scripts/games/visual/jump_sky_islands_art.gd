class_name JumpSkyIslandsArt
extends RefCounted
## Visual layer for Lumos Wolkeninseln (3D-Jump).
## Grass-topped floating islands, readable stone paths, lanterns, batched trees,
## hanging waterfalls, checkpoint flags, bounce pads and smaller side islands.
## Gameplay colliders for the 12 main islands stay 7 x 0.5 x 6 m. Extra pads,
## movers and the bonus island carry their own colliders in jump_islands.gd.
## Trees and island caps are MultiMesh so draw calls stay inside the mobile
## budget. Detail scales with LumoQuality. All meshes are original LUMO art.

const ISLAND_SIZE := Vector2(7.0, 6.0)
const TOP_Y: float = 0.25
const CORNER: float = 0.75
const GRASS := Color("6aa34c")
const GRASS_EDGE := Color("4e7f38")
const EARTH := Color("8f5c36")
const ROCK := Color("6a6174")
const WATERFALL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 water : source_color = vec4(0.86, 0.97, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.42, 0.80, 0.95, 1.0);
void fragment() {
	float x = UV.x;
	float flow = UV.y * 6.0 - TIME * 1.6;
	float streak = 0.5 + 0.5 * sin(x * 38.0 + sin(flow * 2.3) * 1.5) * sin(flow * 3.1 + x * 9.0);
	float edge = smoothstep(0.0, 0.18, x) * smoothstep(1.0, 0.82, x);
	ALBEDO = mix(deep.rgb, water.rgb, 0.55 + 0.45 * streak);
	ALPHA = edge * (0.55 + 0.4 * streak) * smoothstep(1.0, 0.85, UV.y);
}
"""

var budget: Dictionary
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var _materials: Dictionary = {}
var _island_mesh: ArrayMesh
var _star_mesh: ArrayMesh
var _pending_trunks: Array = []
var _pending_trunk_colors: Array = []
var _pending_canopies: Array = []
var _pending_canopy_colors: Array = []
var _pending_caps: Dictionary = {}


func _init(tier: String = "") -> void:
	budget = LumoQuality.budget(tier)
	rng.seed = 20261103
	noise.seed = 7
	noise.frequency = 0.45


func _vertex_material() -> StandardMaterial3D:
	if not _materials.has("vertex"):
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.92
		_materials["vertex"] = mat
	return _materials["vertex"]


func material(color: Color, emission: float = 0.0, roughness: float = 0.85) -> StandardMaterial3D:
	var key: String = "%s/%s/%s" % [color.to_html(), emission, roughness]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		if emission > 0.0:
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = emission
		_materials[key] = mat
	return _materials[key]


## Rounded-rectangle outline (counter-clockwise seen from above).
func _outline(half: Vector2, radius: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var centres: Array[Vector2] = [
		Vector2(half.x - radius, half.y - radius),
		Vector2(-half.x + radius, half.y - radius),
		Vector2(-half.x + radius, -half.y + radius),
		Vector2(half.x - radius, -half.y + radius),
	]
	for c in range(4):
		for s in range(7):
			var angle: float = float(c) * PI * 0.5 + float(s) / 6.0 * PI * 0.5
			points.append(centres[c] + Vector2(cos(angle), sin(angle)) * radius)
	return points


## Island visual: grass cap, grass lip, earth band and a tapering rock body.
## `depth` is the height of the underside below the top surface.
func _palette(style: int) -> Dictionary:
	match style:
		1:
			return {
				"inner": Color("d5cfc2").lightened(0.04),
				"top": Color("c4bdb0"),
				"edge": Color("8f877c"),
			}
		2:
			return {
				"inner": Color("d2a46c").lightened(0.05),
				"top": Color("c99558"),
				"edge": Color("8a6238"),
			}
		_:
			return {
				"inner": GRASS.lightened(0.06),
				"top": GRASS,
				"edge": GRASS_EDGE,
			}


func island_mesh(size: Vector2, depth: float, seed_offset: float, style: int = 0) -> ArrayMesh:
	var palette: Dictionary = _palette(style)
	var outline: Array[Vector2] = _outline(size * 0.5, CORNER)
	var n: int = outline.size()
	# ring = [scale, y, color]; jitter grows towards the tip.
	var rings: Array = [
		[0.62, TOP_Y + 0.02, palette.inner],
		[1.0, TOP_Y, palette.top],
		[1.03, TOP_Y - 0.16, palette.edge],
		[1.0, TOP_Y - 0.34, EARTH],
	]
	var steps: int = 6
	for k in range(1, steps + 1):
		var t: float = float(k) / steps
		var band: float = 0.08 if k % 2 == 0 else -0.04
		(
			rings
			. append(
				[
					0.98 * (1.0 - pow(t, 1.35)) + 0.06,
					TOP_Y - 0.34 - t * depth,
					EARTH.lerp(ROCK, minf(1.0, t * 1.4)).lightened(band),
				]
			)
		)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for r in range(rings.size()):
		var row: Array = []
		var ring: Array = rings[r]
		for i in range(n):
			var p: Vector2 = outline[i] * float(ring[0])
			var y: float = float(ring[1])
			if r >= 3:
				var jitter: float = noise.get_noise_3d(p.x, y, seed_offset)
				p *= 1.0 + jitter * 0.22 * minf(1.0, float(r - 2) / 2.0)
				y += noise.get_noise_3d(p.x + 9.0, p.y, seed_offset) * 0.35 * float(r > 3)
			row.append(Vector3(p.x, y, p.y))
		grid.append(row)
	var tip := Vector3(
		noise.get_noise_1d(seed_offset) * 0.8,
		TOP_Y - 0.34 - depth * 1.12,
		noise.get_noise_1d(seed_offset + 3.0) * 0.6
	)
	# top cap (fan from centre)
	var centre := Vector3(0, TOP_Y + 0.03, 0)
	for i in range(n):
		var j: int = (i + 1) % n
		_tri(
			surface, centre, grid[0][j], grid[0][i], palette.inner, rings[0][2], rings[0][2]
		)
	for r in range(rings.size() - 1):
		var top_color: Color = rings[r][2]
		var bottom_color: Color = rings[r + 1][2]
		for i in range(n):
			var j: int = (i + 1) % n
			var a: Vector3 = grid[r][i]
			var b: Vector3 = grid[r][j]
			var c: Vector3 = grid[r + 1][i]
			var d: Vector3 = grid[r + 1][j]
			_tri(surface, a, b, c, top_color, top_color, bottom_color)
			_tri(surface, b, d, c, top_color, bottom_color, bottom_color)
	var last: Array = grid[rings.size() - 1]
	for i in range(n):
		var j: int = (i + 1) % n
		var color: Color = rings[rings.size() - 1][2]
		_tri(surface, last[i], last[j], tip, color, color, ROCK.darkened(0.25))
	surface.index()
	surface.generate_normals()
	return surface.commit()


## Godot treats clockwise triangles as front faces; callers list vertices
## counter-clockwise as seen from outside, so they are emitted reversed.
func _tri(
	surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color
) -> void:
	surface.set_color(ca)
	surface.add_vertex(a)
	surface.set_color(cc)
	surface.add_vertex(c)
	surface.set_color(cb)
	surface.add_vertex(b)


## Gameplay island visual, matching the 7 x 6 m collider footprint.
func island(parent: Node3D, index: int) -> MeshInstance3D:
	var style: int = 1 if index == 11 else index % 3
	var node := MeshInstance3D.new()
	node.name = "IslandArt"
	node.mesh = island_mesh(ISLAND_SIZE, 3.2 + float(index % 3) * 0.6, float(index) * 13.0, style)
	node.material_override = _vertex_material()
	parent.add_child(node)
	_surface_cap(parent, style)
	return node


func _surface_cap(parent: Node3D, style: int) -> void:
	var kind := "grass_top"
	var tint := Color("b7c48a")
	if style == 1:
		kind = "paving"
		tint = Color("d8d2c4")
	elif style == 2:
		kind = "wood"
		tint = Color("e2b274")
	if not _pending_caps.has(kind):
		_pending_caps[kind] = {"tint": tint, "xforms": []}
	var local := Vector3(0, TOP_Y + 0.012, 0)
	var xf := parent.global_transform * Transform3D(
		Basis.from_scale(Vector3(6.15, 0.045, 5.15)), local
	)
	_pending_caps[kind]["xforms"].append(xf)


func tree(parent: Node3D, at: Vector3) -> void:
	var trunk_local := at + Vector3(0, TOP_Y + 0.75, 0)
	_pending_trunks.append(parent.global_transform * Transform3D(Basis.IDENTITY, trunk_local))
	_pending_trunk_colors.append(Color("c4a07a"))
	var canopy: Array = [
		[Vector3(0, 2.05, 0), 0.95, Color.WHITE],
		[Vector3(0.45, 1.75, 0.25), 0.62, Color("d8f0c8")],
		[Vector3(-0.4, 1.8, -0.2), 0.6, Color("c8e8b8")],
		[Vector3(0.05, 2.6, 0.05), 0.55, Color("e8f8d8")],
	]
	for blob in canopy:
		var local: Vector3 = at + blob[0] + Vector3(0, TOP_Y - 0.25, 0)
		var basis := Basis.from_scale(Vector3.ONE * float(blob[1]))
		_pending_canopies.append(parent.global_transform * Transform3D(basis, local))
		_pending_canopy_colors.append(blob[2])


## Golden star token used for the collectable crystals.
func gem(parent: Node3D) -> MeshInstance3D:
	if _star_mesh == null:
		_star_mesh = LumoWorldMeshes.star()
	var node := MeshInstance3D.new()
	node.name = "StarGem"
	node.mesh = _star_mesh
	node.scale = Vector3.ONE * 0.42
	node.material_override = material(Color("ffc93a"), 1.6, 0.3)
	parent.add_child(node)
	return node


## Goal flag (yellow banner with star) on the last island.
func goal_flag(parent: Node3D) -> void:
	var sand := BuildVoxelStyle.material("sand", Color("d9a86c"))
	for x in [-1.15, 1.15]:
		var pillar := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.28
		cylinder.bottom_radius = 0.34
		cylinder.height = 2.6
		cylinder.radial_segments = 12
		pillar.mesh = cylinder
		pillar.material_override = sand
		pillar.position = Vector3(x, TOP_Y + 1.3, -2.05)
		parent.add_child(pillar)
	var lintel := MeshInstance3D.new()
	var beam := BoxMesh.new()
	beam.size = Vector3(2.7, 0.42, 0.7)
	lintel.mesh = beam
	lintel.material_override = sand
	lintel.position = Vector3(0, TOP_Y + 2.72, -2.05)
	parent.add_child(lintel)
	var key := MeshInstance3D.new()
	var key_box := BoxMesh.new()
	key_box.size = Vector3(0.7, 0.38, 0.78)
	key.mesh = key_box
	key.material_override = BuildVoxelStyle.material("sand", Color("e2b878"))
	key.position = Vector3(0, TOP_Y + 3.08, -2.05)
	parent.add_child(key)
	if _star_mesh == null:
		_star_mesh = LumoWorldMeshes.star()
	var emblem := MeshInstance3D.new()
	emblem.mesh = _star_mesh
	emblem.scale = Vector3(0.55, 0.55, 0.28)
	emblem.material_override = material(Color("ffe27a"), 1.4, 0.28)
	emblem.position = Vector3(0, TOP_Y + 1.55, -2.05)
	parent.add_child(emblem)


func _scatter(
	root: Node3D, mesh: Mesh, transforms: Array, colors: Array, name: String
) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
		multi.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.name = name
	node.multimesh = multi
	node.material_override = _vertex_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	return node


## Grass tufts and flowers on every gameplay island, one MultiMesh each.
func ground_cover(root: Node3D, islands: Array[Vector3]) -> void:
	var density: float = float(budget.decor_density)
	var blade := CylinderMesh.new()
	blade.top_radius = 0.0
	blade.bottom_radius = 0.05
	blade.height = 0.2
	blade.radial_segments = 4
	blade.rings = 1
	var blossom := SphereMesh.new()
	blossom.radius = 0.08
	blossom.height = 0.12
	blossom.radial_segments = 8
	blossom.rings = 4
	var grass_t: Array = []
	var grass_c: Array = []
	var flower_t: Array = []
	var flower_c: Array = []
	var petals: Array[Color] = [
		Color("ff8fc4"), Color("fff27a"), Color("ffffff"), Color("c79bff"), Color("ffb05c")
	]
	var half: Vector2 = ISLAND_SIZE * 0.5 - Vector2(0.35, 0.35)
	for point in islands:
		for g in range(int(70 * density)):
			var at := Vector3(
				rng.randf_range(-half.x, half.x), TOP_Y + 0.08, rng.randf_range(-half.y, half.y)
			)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(
				Vector3.ONE * rng.randf_range(0.7, 1.3)
			)
			grass_t.append(Transform3D(basis, point + at))
			grass_c.append(GRASS_EDGE.lerp(Color("9ee05a"), rng.randf()))
		for f in range(int(16 * density)):
			var at := Vector3(
				rng.randf_range(-half.x, half.x), TOP_Y + 0.14, rng.randf_range(-half.y, half.y)
			)
			flower_t.append(Transform3D(Basis.IDENTITY, point + at))
			flower_c.append(petals[rng.randi() % petals.size()])
	_scatter(root, blade, grass_t, grass_c, "GrassScatter")
	_scatter(root, blossom, flower_t, flower_c, "FlowerScatter")


## Cloud sea below the course and a few high clouds, one MultiMesh.
func clouds(root: Node3D, course_length: float) -> void:
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 14
	puff.rings = 7
	var transforms: Array = []
	var colors: Array = []
	var count: int = int(budget.cloud_count)
	for i in range(count):
		var high: bool = i % 5 == 4
		var z: float = rng.randf_range(12.0, -course_length - 30.0)
		var x: float = rng.randf_range(-40.0, 40.0)
		if high:
			x = signf(x) * rng.randf_range(18.0, 45.0)
		var y: float = rng.randf_range(9.0, 15.0) if high else rng.randf_range(-9.5, -6.0)
		var scale := Vector3(
			rng.randf_range(4.5, 9.0), rng.randf_range(1.3, 2.4), rng.randf_range(3.0, 6.0)
		)
		transforms.append(Transform3D(Basis.IDENTITY.scaled(scale), Vector3(x, y, z)))
		colors.append(Color("ffffff").lerp(Color("d7ecfb"), rng.randf_range(0.0, 0.5)))
	var node := _scatter(root, puff, transforms, colors, "CloudSea")
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color("cfeaff")
	mat.emission_energy_multiplier = 0.35
	node.material_override = mat


## Distant floating islands; the first ones carry waterfalls into the clouds.
func backdrop(root: Node3D, course_length: float) -> void:
	var water := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WATERFALL_SHADER
	water.shader = shader
	var count: int = int(budget.backdrop_islands)
	for i in range(count):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var size := Vector2(rng.randf_range(11.0, 18.0), rng.randf_range(9.0, 14.0))
		var depth: float = rng.randf_range(8.0, 13.0)
		var at := Vector3(
			side * rng.randf_range(30.0, 46.0),
			rng.randf_range(1.0, 8.0),
			-course_length * (float(i) + 0.5) / float(count) - rng.randf_range(0.0, 10.0)
		)
		var node := MeshInstance3D.new()
		node.name = "BackdropIsland%d" % i
		node.mesh = island_mesh(size, depth, 100.0 + float(i) * 17.0)
		node.material_override = _vertex_material()
		node.position = at
		node.rotation.y = rng.randf_range(-0.6, 0.6)
		root.add_child(node)
		for t in range(2):
			tree(
				node,
				Vector3(
					rng.randf_range(-size.x, size.x) * 0.3,
					0,
					rng.randf_range(-size.y, size.y) * 0.3
				)
			)
		if i < 2:
			var fall := MeshInstance3D.new()
			fall.name = "Waterfall%d" % i
			var quad := QuadMesh.new()
			quad.size = Vector2(2.6, 16.0)
			fall.mesh = quad
			fall.material_override = water
			# Face the course and pour from the island edge facing the player.
			fall.position = at + Vector3(-side * size.x * 0.32, TOP_Y - 8.0, size.y * 0.42)
			fall.rotation.y = -side * 0.5
			fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(fall)
			var mist := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 2.4
			sphere.height = 2.4
			mist.mesh = sphere
			mist.material_override = material(Color("eefaff"), 0.4, 1.0)
			mist.position = fall.position + Vector3(0, -8.0, 0)
			mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mist)


## Golden motes drifting along the course (0 on LOW).
func sparkles(root: Node3D, course_length: float) -> void:
	var amount: int = int(budget.sparkles)
	if amount <= 0:
		return
	var particles := CPUParticles3D.new()
	particles.name = "Sparkles"
	particles.amount = amount
	particles.lifetime = 4.0
	particles.preprocess = 4.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(9.0, 2.0, course_length * 0.5)
	particles.position = Vector3(0, 2.0, -course_length * 0.5)
	particles.direction = Vector3.UP
	particles.spread = 30.0
	particles.gravity = Vector3(0, 0.15, 0)
	particles.initial_velocity_min = 0.1
	particles.initial_velocity_max = 0.35
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color("fff1a8")
	mat.emission_enabled = true
	mat.emission = Color("ffd75e")
	mat.emission_energy_multiplier = 2.0
	quad.material = mat
	particles.mesh = quad
	root.add_child(particles)


## Visual-only lanterns, a readable stone path on every island, crates and bushes.
func props(root: Node3D, islands: Array[Vector3]) -> void:
	var lamp_posts: Array = []
	var lamp_glows: Array = []
	var lamp_colors: Array = []
	var glow_colors: Array = []
	var path_x: Array[Transform3D] = []
	var crate_x: Array[Transform3D] = []
	var bush_t: Array = []
	var bush_c: Array = []
	var post := CylinderMesh.new()
	post.top_radius = 0.045
	post.bottom_radius = 0.06
	post.height = 1.15
	post.radial_segments = 8
	var glow := SphereMesh.new()
	glow.radius = 0.14
	glow.height = 0.22
	glow.radial_segments = 10
	glow.rings = 6
	var paver := BoxMesh.new()
	paver.size = Vector3.ONE
	var crate := BoxMesh.new()
	crate.size = Vector3.ONE
	var bush := SphereMesh.new()
	bush.radius = 1.0
	bush.height = 1.35
	bush.radial_segments = 10
	bush.rings = 6
	for i in range(islands.size()):
		var point: Vector3 = islands[i]
		for side in [-1.0, 1.0]:
			var at := point + Vector3(side * 2.55, TOP_Y + 0.58, 1.6)
			lamp_posts.append(Transform3D(Basis.IDENTITY, at))
			lamp_colors.append(Color("d8c4a0"))
			lamp_glows.append(Transform3D(Basis.IDENTITY, at + Vector3(0, 0.68, 0)))
			glow_colors.append(Color("ffe6a0"))
		for step in range(7):
			var local := Vector3(0, TOP_Y + 0.035, 2.05 - float(step) * 0.68)
			path_x.append(
				Transform3D(Basis.from_scale(Vector3(1.22, 0.045, 0.52)), point + local)
			)
		if i % 2 == 1:
			var crate_at := point + Vector3(-2.35, TOP_Y + 0.22, 0.85)
			crate_x.append(Transform3D(Basis.from_scale(Vector3(0.46, 0.4, 0.46)), crate_at))
			crate_x.append(
				Transform3D(
					Basis.from_scale(Vector3(0.34, 0.28, 0.34)), crate_at + Vector3(0.38, 0.12, 0.12)
				)
			)
		if i % 3 != 1:
			var bush_at := point + Vector3(2.2, TOP_Y + 0.22, -1.9)
			bush_t.append(Transform3D(Basis.from_scale(Vector3(0.42, 0.34, 0.42)), bush_at))
			bush_c.append(Color("7fbf55").lerp(Color("c8e88a"), rng.randf()))
	_scatter(root, post, lamp_posts, lamp_colors, "LanternPosts")
	var lights := _scatter(root, glow, lamp_glows, glow_colors, "LanternGlows")
	var glow_mat := StandardMaterial3D.new()
	glow_mat.vertex_color_use_as_albedo = true
	glow_mat.emission_enabled = true
	glow_mat.emission = Color("ffd978")
	glow_mat.emission_energy_multiplier = 0.85
	glow_mat.roughness = 0.35
	lights.material_override = glow_mat
	if not path_x.is_empty():
		BuildVoxelStyle.multimesh(
			root, "IslandPaths", paver, BuildVoxelStyle.material("paving", Color("d8d2c4")), path_x
		)
	if not crate_x.is_empty():
		BuildVoxelStyle.multimesh(
			root, "IslandCrates", crate, BuildVoxelStyle.material("wood", Color("d2a06a")), crate_x
		)
	if not bush_t.is_empty():
		var bushes := _scatter(root, bush, bush_t, bush_c, "IslandBushes")
		var bush_mat: StandardMaterial3D = BuildVoxelStyle.material("leaves", Color("98c45a")).duplicate()
		bush_mat.vertex_color_use_as_albedo = true
		bushes.material_override = bush_mat


## Flush batched trees and island caps. Call after every tree() and island().
func finish(root: Node3D) -> void:
	if not _pending_trunks.is_empty():
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.12
		cylinder.bottom_radius = 0.2
		cylinder.height = 1.5
		cylinder.radial_segments = 8
		var trunks := _scatter(root, cylinder, _pending_trunks, _pending_trunk_colors, "TreeTrunks")
		trunks.material_override = BuildVoxelStyle.material("bark", Color("c4a07a"))
		trunks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if not _pending_canopies.is_empty():
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 1.8
		sphere.radial_segments = 14
		sphere.rings = 7
		var leaves := _scatter(root, sphere, _pending_canopies, _pending_canopy_colors, "TreeCanopies")
		var leaf_mat: StandardMaterial3D = BuildVoxelStyle.material("leaves", Color.WHITE).duplicate()
		leaf_mat.vertex_color_use_as_albedo = true
		leaves.material_override = leaf_mat
		leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if not _pending_caps.is_empty():
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		for kind in _pending_caps:
			var info: Dictionary = _pending_caps[kind]
			var typed: Array[Transform3D] = []
			typed.assign(info["xforms"])
			BuildVoxelStyle.multimesh(
				root,
				"IslandCaps_%s" % str(kind),
				box,
				BuildVoxelStyle.material(str(kind), info["tint"]),
				typed
			)
	_pending_trunks.clear()
	_pending_trunk_colors.clear()
	_pending_canopies.clear()
	_pending_canopy_colors.clear()
	_pending_caps.clear()


## A hanging island with a waterfall near the start, plus side falls on the course.
func near_course_scenery(root: Node3D, islands: Array[Vector3]) -> void:
	if islands.is_empty():
		return
	var water := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WATERFALL_SHADER
	water.shader = shader
	var at: Vector3 = islands[0] + Vector3(-8.8, 5.6, -2.8)
	var hanging := MeshInstance3D.new()
	hanging.name = "NearFallIsland"
	hanging.mesh = island_mesh(Vector2(6.4, 5.1), 5.4, 77.0)
	hanging.material_override = _vertex_material()
	hanging.position = at
	hanging.rotation.y = -0.35
	root.add_child(hanging)
	tree(hanging, Vector3(-1.15, 0, -0.7))
	tree(hanging, Vector3(1.35, 0, 0.55))
	var fall := MeshInstance3D.new()
	fall.name = "NearWaterfall"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 12.5)
	fall.mesh = quad
	fall.material_override = water
	fall.position = at + Vector3(2.15, TOP_Y - 6.1, 1.35)
	fall.rotation.y = 0.85
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fall)
	var mist := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.9
	sphere.height = 1.8
	mist.mesh = sphere
	mist.material_override = material(Color("eefaff"), 0.35, 1.0)
	mist.position = fall.position + Vector3(0, -6.2, 0)
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mist)
	for i in [2, 5, 8]:
		if i >= islands.size():
			continue
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var ribbon := MeshInstance3D.new()
		ribbon.name = "IslandFall%d" % i
		var sheet := QuadMesh.new()
		sheet.size = Vector2(1.55, 6.2)
		ribbon.mesh = sheet
		ribbon.material_override = water
		ribbon.position = islands[i] + Vector3(side * 3.35, TOP_Y - 2.9, 0.15)
		ribbon.rotation.y = -side * 1.15
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ribbon)


func mini_island(parent: Node3D, size: Vector2 = Vector2(3.2, 2.6), seed_offset: float = 41.0) -> void:
	var node := MeshInstance3D.new()
	node.name = "MiniIslandArt"
	node.mesh = island_mesh(size, 2.15, seed_offset, 0)
	node.material_override = _vertex_material()
	parent.add_child(node)
	var cap := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(size.x * 0.88, 0.045, size.y * 0.86)
	cap.mesh = plate
	cap.position = Vector3(0, TOP_Y + 0.012, 0)
	cap.material_override = BuildVoxelStyle.material("grass_top", Color("b7c48a"))
	parent.add_child(cap)


func bounce_pad(parent: Node3D) -> void:
	var base := MeshInstance3D.new()
	var plate := CylinderMesh.new()
	plate.top_radius = 0.55
	plate.bottom_radius = 0.62
	plate.height = 0.12
	plate.radial_segments = 14
	base.mesh = plate
	base.material_override = material(Color("5b4fd1"), 0.2, 0.5)
	base.position = Vector3(0, TOP_Y + 0.08, 0)
	parent.add_child(base)
	var cushion := MeshInstance3D.new()
	var cap := SphereMesh.new()
	cap.radius = 0.48
	cap.height = 0.34
	cap.radial_segments = 14
	cap.rings = 7
	cushion.mesh = cap
	cushion.material_override = material(Color("53ddfd"), 0.75, 0.32)
	cushion.position = Vector3(0, TOP_Y + 0.28, 0)
	parent.add_child(cushion)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.16
	torus.outer_radius = 0.36
	torus.ring_segments = 12
	torus.rings = 14
	ring.mesh = torus
	ring.material_override = material(Color("ffc93a"), 0.6, 0.38)
	ring.position = Vector3(0, TOP_Y + 0.2, 0)
	ring.rotation_degrees.x = 90
	parent.add_child(ring)


func checkpoint_flag(parent: Node3D) -> Dictionary:
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.055
	cyl.height = 1.85
	cyl.radial_segments = 8
	pole.mesh = cyl
	pole.material_override = material(Color("d8c4a0"), 0.0, 0.55)
	pole.position = Vector3(0, TOP_Y + 0.92, 0)
	parent.add_child(pole)
	var banner := MeshInstance3D.new()
	var cloth := BoxMesh.new()
	cloth.size = Vector3(0.74, 0.5, 0.06)
	banner.mesh = cloth
	banner.position = Vector3(0.4, TOP_Y + 1.56, 0)
	banner.material_override = material(Color("7ad7f0"), 0.28, 0.42)
	parent.add_child(banner)
	if _star_mesh == null:
		_star_mesh = LumoWorldMeshes.star()
	var emblem := MeshInstance3D.new()
	emblem.mesh = _star_mesh
	emblem.scale = Vector3.ONE * 0.18
	emblem.position = Vector3(0.4, TOP_Y + 1.56, 0.05)
	emblem.material_override = material(Color("ffe27a"), 0.85, 0.3)
	parent.add_child(emblem)
	return {"banner": banner, "star": emblem}


func set_flag_active(flag: Dictionary, active: bool) -> void:
	if flag.is_empty() or not is_instance_valid(flag.get("banner")):
		return
	var banner: MeshInstance3D = flag["banner"]
	banner.material_override = material(
		Color("ffe27a") if active else Color("7ad7f0"), 1.15 if active else 0.28, 0.38
	)
