extends Node3D
## Gelände, Wasser und Kollision der Dorfwelt aus der Höhenkarte.
## Ein Geländematerial (Gras/Erde/Fels/Sand/Schnee), eine Wasserfläche mit
## Tiefenkarte, eine Wegekarte, die nur Darstellung ist (nie Spielstand).
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const TEX := "res://assets/creative/village3d/textures/"
const TERRAIN_SHADER = preload("res://assets/creative/village3d/shaders/village_terrain.gdshader")
const WATER_SHADER = preload("res://assets/creative/village3d/shaders/village_water.gdshader")
const CHUNK_CELLS := 64
## Stadt des Kindes bis Ring 32 (x −276 … 76) und die drei Nachbarstädte am
## Ostufer (bis x 240); 2 Pixel je Meter.
const PAINT_RECT := Rect2(-282.0, -182.0, 528.0, 364.0)
const PAINT_SCALE := 2.0
const SPACING := 5.3
var tier := "medium"
var terrain_material: ShaderMaterial
var water_material: ShaderMaterial
var paint_image: Image
var paint_texture: ImageTexture
var chunks: Array[MeshInstance3D] = []
var water: MeshInstance3D
var triangles := 0
## Optional presentation seam used only when this village joins Lumo World.
## The original heightmap, plot coordinates and standalone village stay intact.
var west_entry_x := -INF
var west_entry_blend_width := 20.0


func build(quality: String) -> void:
	tier = quality
	name = "VillageLandscape"
	if not TERRAIN.ensure():
		return
	_make_materials()
	_build_terrain()
	_build_water()
	set_meta("terrain_chunks", chunks.size())
	set_meta("terrain_triangles", triangles)


func _make_materials() -> void:
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = TERRAIN_SHADER
	for slot in [
		["grass_albedo", "terrain_grass_albedo"], ["grass_normal", "terrain_grass_normal"],
		["dirt_albedo", "terrain_dirt_albedo"], ["rock_albedo", "terrain_rock_albedo"],
		["rock_normal", "terrain_rock_normal"], ["sand_albedo", "terrain_sand_albedo"],
		["noise_map", "cloud_noise"]
	]:
		terrain_material.set_shader_parameter(slot[0], load(TEX + slot[1] + ".png"))
	terrain_material.set_shader_parameter("water_level", TERRAIN.WATER_LEVEL)
	terrain_material.set_shader_parameter("detail_strength", 0.7 if tier == "low" else 1.0)
	terrain_material.set_shader_parameter("cloud_shadow", 0.0 if tier == "low" else 0.3)
	var paint_size := Vector2i(PAINT_RECT.size * PAINT_SCALE)
	paint_image = Image.create(paint_size.x, paint_size.y, false, Image.FORMAT_RG8)
	paint_image.fill(Color(0, 0, 0))
	paint_texture = ImageTexture.create_from_image(paint_image)
	terrain_material.set_shader_parameter("paint_map", paint_texture)
	terrain_material.set_shader_parameter(
		"paint_rect", Vector4(PAINT_RECT.position.x, PAINT_RECT.position.y, PAINT_RECT.size.x, PAINT_RECT.size.y)
	)
	water_material = ShaderMaterial.new()
	water_material.shader = WATER_SHADER
	water_material.set_shader_parameter("water_normal", load(TEX + "water_normal.png"))
	water_material.set_shader_parameter("noise_map", load(TEX + "cloud_noise.png"))
	var grid := TERRAIN.grid_size()
	var depth := Image.create(grid.x, grid.y, false, Image.FORMAT_L8)
	for iz in range(grid.y):
		for ix in range(grid.x):
			var below := TERRAIN.WATER_LEVEL - TERRAIN.grid_height(ix, iz)
			depth.set_pixel(ix, iz, Color(clampf(below / 5.5, 0.0, 1.0), 0, 0))
	water_material.set_shader_parameter("depth_map", ImageTexture.create_from_image(depth))
	var origin := TERRAIN.origin()
	var extent := TERRAIN.size()
	water_material.set_shader_parameter("depth_rect", Vector4(origin.x, origin.y, extent.x, extent.y))
	water_material.set_shader_parameter("wave_strength", 0.6 if tier == "low" else 1.0)
	water_material.set_shader_parameter("sea_swell", 0.0 if tier == "low" else 1.0)


func _indices(start: int, finish: int, stride: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var index := start
	while index < finish:
		result.append(index)
		index += stride
	result.append(finish)
	return result


func first_grid_column() -> int:
	if not is_finite(west_entry_x):
		return 0
	return clampi(ceili((west_entry_x - TERRAIN.origin().x) / TERRAIN.step()), 0, TERRAIN.grid_size().x - 2)


func surface_height(x: float, z: float) -> float:
	var height := TERRAIN.height(x, z)
	if not is_finite(west_entry_x):
		return height
	return height * smoothstep(west_entry_x, west_entry_x + maxf(west_entry_blend_width, TERRAIN.step()), x)


func _grid_height(ix: int, iz: int) -> float:
	var height := TERRAIN.grid_height(ix, iz)
	if not is_finite(west_entry_x):
		return height
	var x := TERRAIN.origin().x + float(ix) * TERRAIN.step()
	return height * smoothstep(west_entry_x, west_entry_x + maxf(west_entry_blend_width, TERRAIN.step()), x)


func _build_terrain() -> void:
	var grid := TERRAIN.grid_size()
	var origin := TERRAIN.origin()
	var step := TERRAIN.step()
	var stride := 2 if tier == "low" else 1
	for cz in range(0, grid.y - 1, CHUNK_CELLS):
		for cx in range(first_grid_column(), grid.x - 1, CHUNK_CELLS):
			var xs := _indices(cx, mini(cx + CHUNK_CELLS, grid.x - 1), stride)
			var zs := _indices(cz, mini(cz + CHUNK_CELLS, grid.y - 1), stride)
			var verts := PackedVector3Array()
			var normals := PackedVector3Array()
			var tangents := PackedFloat32Array()
			var colors := PackedColorArray()
			var indices := PackedInt32Array()
			for iz in zs:
				for ix in xs:
					var h := _grid_height(ix, iz)
					var hl := _grid_height(ix - 1, iz)
					var hr := _grid_height(ix + 1, iz)
					var hd := _grid_height(ix, iz - 1)
					var hu := _grid_height(ix, iz + 1)
					verts.append(Vector3(origin.x + ix * step, h, origin.y + iz * step))
					var n := Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
					normals.append(n)
					var t := Vector3(2.0 * step, hr - hl, 0.0).normalized()
					tangents.append_array([t.x, t.y, t.z, -1.0])
					# Hollows a little darker, ridges a little brighter (baked AO).
					var cavity := (hl + hr + hd + hu) * 0.25 - h
					var ao := clampf(1.0 - cavity * 0.09, 0.72, 1.06)
					colors.append(Color(ao, ao, ao))
			var row := xs.size()
			for z in range(zs.size() - 1):
				for x in range(row - 1):
					var a := z * row + x
					var b := a + 1
					var c := a + row
					var d := c + 1
					indices.append_array([a, b, c, b, d, c])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = tangents
			arrays[Mesh.ARRAY_COLOR] = colors
			arrays[Mesh.ARRAY_INDEX] = indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var chunk := MeshInstance3D.new()
			chunk.name = "TerrainChunk_%d_%d" % [cx / CHUNK_CELLS, cz / CHUNK_CELLS]
			chunk.mesh = mesh
			chunk.material_override = terrain_material
			# Only HIGH lets the mountains throw shadows across the valley.
			if tier != "high":
				chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(chunk)
			chunks.append(chunk)
			triangles += indices.size() / 3


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1600, 1500)
	var detail := 0 if tier == "low" else (96 if tier == "high" else 64)
	plane.subdivide_width = detail
	plane.subdivide_depth = detail
	water = MeshInstance3D.new()
	water.name = "VillageWater"
	water.mesh = plane
	water.position = Vector3(0, TERRAIN.WATER_LEVEL, 180)
	water.material_override = water_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


## Begehbares Gelände für Lumo und für das Antippen von Hängen.
func collision_shape() -> CollisionShape3D:
	var grid := TERRAIN.grid_size()
	var step := TERRAIN.step()
	var first_column := first_grid_column()
	var columns := grid.x - first_column
	var shape := HeightMapShape3D.new()
	shape.map_width = columns
	shape.map_depth = grid.y
	var data := PackedFloat32Array()
	data.resize(columns * grid.y)
	for iz in range(grid.y):
		for ix in range(columns):
			data[iz * columns + ix] = _grid_height(ix + first_column, iz) / step
	shape.map_data = data
	var holder := CollisionShape3D.new()
	holder.name = "TerrainCollision"
	holder.shape = shape
	holder.scale = Vector3.ONE * step
	var origin := TERRAIN.origin()
	var extent := TERRAIN.size()
	holder.position = Vector3(origin.x + float(first_column) * step + float(columns - 1) * step * 0.5, 0, origin.y + extent.y * 0.5)
	return holder


## Wege und Höfe als reine Darstellung. Spielstand und Regeln bleiben unberührt.
func paint_town(center_x: float, unlocked: Array, built: Dictionary, ring: int) -> void:
	if paint_image == null:
		return
	var half := float(ring) * SPACING + SPACING * 0.5
	var area := Rect2(center_x - half - 2.0, -half - 2.0, half * 2.0 + 4.0, half * 2.0 + 4.0)
	_fill(area, Color(0, 0, 0))
	# Gassen nur dort, wo gebaut ist (und die beiden Hauptstraßen durch die
	# Ortsmitte, breiter): freie Bauplätze bleiben Wiese statt Schachbrett.
	var homes: Dictionary = {}
	for point: Vector2 in built:
		homes[Vector2i(roundi(point.x * 10.0), roundi(point.y * 10.0))] = true
	for point: Vector2 in unlocked:
		var here := homes.has(Vector2i(roundi(point.x * 10.0), roundi(point.y * 10.0)))
		for side in [-1.0, 1.0]:
			var lane_x: float = point.x + side * SPACING * 0.5
			var lane_z: float = point.y + side * SPACING * 0.5
			var main_x := absf(lane_x - center_x) < 0.1 + SPACING * 0.5 and absf(lane_x - center_x) > 0.1
			var main_z := absf(lane_z) < 0.1 + SPACING * 0.5 and absf(lane_z) > 0.1
			var next_x := homes.has(Vector2i(roundi((point.x + side * SPACING) * 10.0), roundi(point.y * 10.0)))
			var next_z := homes.has(Vector2i(roundi(point.x * 10.0), roundi((point.y + side * SPACING) * 10.0)))
			var wide_x := 2.2 if main_x else 1.2
			var wide_z := 2.2 if main_z else 1.2
			if main_x or here or next_x:
				_fill(Rect2(lane_x - wide_x * 0.5, point.y - SPACING * 0.5 - 0.6, wide_x, SPACING + 1.2),
					Color(1.0 if main_x else 0.75, 0, 0))
			if main_z or here or next_z:
				_fill(Rect2(point.x - SPACING * 0.5 - 0.6, lane_z - wide_z * 0.5, SPACING + 1.2, wide_z),
					Color(1.0 if main_z else 0.75, 0, 0))
	for point: Vector2 in unlocked:
		var cell := Rect2(point.x - 2.3, point.y - 2.3, 4.6, 4.6)
		if built.has(point):
			_fill(cell.grow(-0.15), Color(0, 0.85, 0))
		else:
			# Nur eine leise Spur (abgemähte Wiese), kein helles Quadrat.
			_fill(cell.grow(-1.1), Color(0, 0.24, 0))
	# Landstraße vom Ortsrand zur mittleren Brücke (solange der Ort diesseits
	# des Flusses endet).
	var edge := center_x + (half if center_x < 0 else -half)
	var river := TERRAIN.river_center(0.0)
	var start := minf(edge, river)
	var finish := maxf(edge, river)
	if (edge < river) == (center_x < river):
		_fill(Rect2(start, -1.1 - SPACING * 0.5, finish - start, 2.2), Color(1, 0, 0))
	paint_texture.update(paint_image)


## Nachbarstadt: Gassen und Höfe in ihrem eigenen Gebiet (nur Darstellung).
func paint_site(center: Vector2, cells: Array, built: Dictionary, ring: int) -> void:
	if paint_image == null:
		return
	var half := float(ring) * SPACING + SPACING * 0.5
	_fill(Rect2(center.x - half - 2.0, center.y - half - 2.0, half * 2.0 + 4.0, half * 2.0 + 4.0), Color(0, 0, 0))
	for point: Vector2 in cells:
		for side in [-1.0, 1.0]:
			_fill(Rect2(point.x + side * SPACING * 0.5 - 0.6, point.y - SPACING * 0.5 - 0.6, 1.2, SPACING + 1.2),
				Color(0.7, 0, 0))
			_fill(Rect2(point.x - SPACING * 0.5 - 0.6, point.y + side * SPACING * 0.5 - 0.6, SPACING + 1.2, 1.2),
				Color(0.7, 0, 0))
	for point: Vector2 in cells:
		if built.has(point):
			_fill(Rect2(point.x - 2.15, point.y - 2.15, 4.3, 4.3), Color(0, 0.85, 0))
	paint_texture.update(paint_image)


func _fill(world: Rect2, color: Color) -> void:
	var px := Rect2i(
		Vector2i(((world.position - PAINT_RECT.position) * PAINT_SCALE).floor()),
		Vector2i((world.size * PAINT_SCALE).ceil())
	)
	var bounds := Rect2i(Vector2i.ZERO, paint_image.get_size())
	px = px.intersection(bounds)
	if px.size.x > 0 and px.size.y > 0:
		paint_image.fill_rect(px, color)
