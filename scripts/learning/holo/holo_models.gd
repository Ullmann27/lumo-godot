extends RefCounted
## Eigene, lokal erzeugte Modelle der Holo-Lernräume (keine fremden Assets):
## Apfel, geflochtener Korb, Zehnerfeld-Tablett, Wortkarte und das leuchtende
## Holo-Podest. Alle Meshes werden einmal gebaut und geteilt (statischer Cache).
## Die Materialien laufen auf gl_compatibility; die leuchtende Kontur ist eine
## Inverted-Hull-Hülle (next_pass) und kostet nur einen zusätzlichen Draw-Call.

const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;
uniform vec4 glow : source_color = vec4(0.45, 0.93, 1.0, 1.0);
uniform float width = 0.035;
uniform float strength = 1.6;
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = glow.rgb * strength;
}
"""

const RIM_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 albedo : source_color = vec4(0.85, 0.12, 0.12, 1.0);
uniform vec4 rim_color : source_color = vec4(0.55, 0.95, 1.0, 1.0);
uniform float rim_power = 2.6;
uniform float rim_strength = 0.9;
uniform float highlight = 0.0;
uniform float self_light = 0.0;
uniform float roughness_value = 0.42;
void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.55;
	EMISSION = rim_color.rgb * rim * (rim_strength + highlight * 1.8)
		+ albedo.rgb * (highlight * 0.35 + self_light);
}
"""

const GRID_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 base : source_color = vec4(0.05, 0.16, 0.28, 1.0);
uniform vec4 line : source_color = vec4(0.36, 0.86, 1.0, 1.0);
uniform float cells = 18.0;
uniform float ring_glow = 1.0;
varying vec3 local_pos;
void vertex() {
	local_pos = VERTEX;
}
void fragment() {
	vec2 uv = local_pos.xz * cells / 12.0;
	vec2 grid = abs(fract(uv - 0.5) - 0.5) / fwidth(uv);
	float g = 1.0 - min(min(grid.x, grid.y), 1.0);
	float r = length(local_pos.xz);
	float ring = smoothstep(0.06, 0.0, abs(r - 5.6)) + smoothstep(0.04, 0.0, abs(r - 4.9)) * 0.6;
	float fade = smoothstep(6.2, 2.0, r);
	ALBEDO = base.rgb;
	ROUGHNESS = 0.55;
	METALLIC = 0.2;
	EMISSION = line.rgb * (g * 0.22 * fade + ring * 0.9 * ring_glow);
}
"""

## Weidengeflecht: senkrechte Staken, waagrechte Ruten im Wechsel (über/unter).
## Die Ruten wölben die Wand wirklich nach außen (Vertex-Versatz), die Fugen
## bleiben dunkel. mode 0 = Wand (Winkel/Höhe), 1 = Boden (eben, Kreuzgeflecht),
## 2 = gedrehter Rand (Seil). Rein aus der lokalen Position – keine Textur,
## läuft auf gl_compatibility.
const WICKER_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 light_wood : source_color = vec4(0.86, 0.6, 0.32, 1.0);
uniform vec4 dark_wood : source_color = vec4(0.42, 0.24, 0.1, 1.0);
uniform vec4 rim_color : source_color = vec4(0.55, 0.92, 1.0, 1.0);
uniform float staves = 30.0;
uniform float rows = 11.0;
uniform float bulge = 0.0;
uniform float ring_radius = 1.0;
uniform int mode = 0;
varying vec3 local_pos;
float weave(vec3 p) {
	float u = (atan(p.z, p.x) / 6.2831853 + 0.5) * staves;
	float v = p.y * rows;
	float over = mod(floor(u) + floor(v), 2.0);
	float across = abs(fract(v) - 0.5) * 2.0;
	return (1.0 - across * across) * (0.55 + 0.45 * over);
}
void vertex() {
	local_pos = VERTEX;
	if (mode == 0) {
		VERTEX += NORMAL * bulge * weave(VERTEX);
	}
}
void fragment() {
	vec3 colour;
	float shade;
	if (mode == 1) {
		vec2 q = local_pos.xz * staves * 0.16;
		float over = mod(floor(q.x) + floor(q.y), 2.0);
		float along = abs(fract(over > 0.5 ? q.x : q.y) - 0.5) * 2.0;
		float groove = smoothstep(0.8, 1.0, along);
		shade = (1.0 - groove) * (0.8 + 0.2 * over);
		colour = mix(dark_wood.rgb, light_wood.rgb, shade * 0.85);
	} else if (mode >= 2) {
		vec3 p = mode == 2 ? local_pos : local_pos.xzy;
		float around = atan(p.z, p.x) / 6.2831853;
		float tube = atan(p.y, length(p.xz) - ring_radius) / 6.2831853;
		float strand = fract(around * staves + tube * 2.0);
		float groove = smoothstep(0.75, 1.0, abs(strand - 0.5) * 2.0);
		shade = 1.0 - groove;
		colour = mix(dark_wood.rgb, light_wood.rgb, 0.35 + 0.65 * shade);
	} else {
		float u = (atan(local_pos.z, local_pos.x) / 6.2831853 + 0.5) * staves;
		float v = local_pos.y * rows;
		float over = mod(floor(u) + floor(v), 2.0);
		float across = abs(fract(v) - 0.5) * 2.0;
		float along = abs(fract(u) - 0.5) * 2.0;
		float groove = smoothstep(0.78, 1.0, across) + smoothstep(0.88, 1.0, along) * 0.7 * over;
		shade = clamp(1.0 - groove, 0.0, 1.0) * (0.78 + 0.22 * over);
		colour = mix(dark_wood.rgb, light_wood.rgb, shade);
	}
	ALBEDO = colour;
	ROUGHNESS = 0.8;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = rim_color.rgb * pow(1.0 - facing, 3.0) * 0.3;
}
"""

## Hologramm-Figur: additiv leuchtend, Fresnel-Kante, wandernde Rasterlinien.
## Unshaded – läuft gleich auf gl_compatibility und Mobile.
const HOLO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.35, 0.9, 1.0, 1.0);
uniform float strength = 1.0;
uniform float lines = 1.0;
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.0);
	float scan = 0.75 + 0.25 * lines * sin(world_pos.y * 60.0 - TIME * 3.0 * lines);
	ALBEDO = tint.rgb * (0.55 + rim * 1.4) * scan * strength;
}
"""

const BASKET_RADIUS := 1.5
const BASKET_HEIGHT := 1.0
const BASKET_FILL := 0.6

static var _meshes: Dictionary = {}
static var _shaders: Dictionary = {}


static func shader(key: String) -> Shader:
	if not _shaders.has(key):
		var value := Shader.new()
		value.code = {
			"outline": OUTLINE_SHADER,
			"rim": RIM_SHADER,
			"grid": GRID_SHADER,
			"wicker": WICKER_SHADER,
			"holo": HOLO_SHADER
		}[key]
		_shaders[key] = value
	return _shaders[key]


static func rim_material(color: Color, rim: Color, roughness: float = 0.42) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader("rim")
	material.set_shader_parameter("albedo", color)
	material.set_shader_parameter("rim_color", rim)
	material.set_shader_parameter("roughness_value", roughness)
	return material


static func outline_material(color: Color, width: float, strength: float = 1.6) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader("outline")
	material.set_shader_parameter("glow", color)
	material.set_shader_parameter("width", width)
	material.set_shader_parameter("strength", strength)
	return material


static func with_outline(base: Material, color: Color, width: float) -> Material:
	base.next_pass = outline_material(color, width)
	return base


static func flat(color: Color, glow: float = 0.0, roughness: float = 0.6) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = glow
	return material


## Rotationskörper aus einem Profil (x = Radius, y = Höhe), mit Normalen.
static func lathe(profile: PackedVector2Array, segments: int, wobble: float = 0.0) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	for ring in range(profile.size() - 1):
		for segment in range(segments):
			var a0 := TAU * segment / segments
			var a1 := TAU * (segment + 1) / segments
			var quad: Array[Vector3] = []
			for corner in [[ring, a0], [ring, a1], [ring + 1, a1], [ring + 1, a0]]:
				var p: Vector2 = profile[corner[0]]
				var angle: float = corner[1]
				var radius := p.x * (1.0 + wobble * sin(angle * 5.0) * sin(p.y * 3.0))
				quad.append(Vector3(cos(angle) * radius, p.y, sin(angle) * radius))
			for index in [0, 1, 2, 0, 2, 3]:
				tool.add_vertex(quad[index])
	tool.generate_normals()
	return tool.commit()


static func apple() -> ArrayMesh:
	if _meshes.has("apple"):
		return _meshes.apple
	# Typische Apfelform: Kelchgrube unten, breite Schulter, Stielgrube oben.
	var profile := PackedVector2Array()
	var points := [
		Vector2(0.0, 0.02),
		Vector2(0.10, 0.0),
		Vector2(0.22, 0.03),
		Vector2(0.31, 0.10),
		Vector2(0.36, 0.20),
		Vector2(0.385, 0.31),
		Vector2(0.38, 0.41),
		Vector2(0.35, 0.50),
		Vector2(0.29, 0.57),
		Vector2(0.20, 0.61),
		Vector2(0.11, 0.60),
		Vector2(0.05, 0.555),
		Vector2(0.0, 0.53)
	]
	for point in points:
		profile.append(point)
	var body := lathe(profile, 22, 0.035)
	_meshes.apple = body
	return body


static func stem() -> Mesh:
	if not _meshes.has("stem"):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.018
		mesh.bottom_radius = 0.028
		mesh.height = 0.17
		mesh.radial_segments = 6
		mesh.rings = 1
		_meshes.stem = mesh
	return _meshes.stem


static func leaf() -> ArrayMesh:
	if _meshes.has("leaf"):
		return _meshes.leaf
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 8
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for step in range(steps + 1):
		var t := float(step) / steps
		var w := sin(t * PI) * 0.075
		var y := sin(t * PI) * 0.03
		left.append(Vector3(t * 0.24, y, -w))
		right.append(Vector3(t * 0.24, y, w))
	for step in range(steps):
		for tri in [
			[left[step], right[step], right[step + 1]],
			[left[step], right[step + 1], left[step + 1]]
		]:
			for vertex in tri:
				tool.add_vertex(vertex)
			for vertex in [tri[0], tri[2], tri[1]]:
				tool.add_vertex(vertex)
	tool.generate_normals()
	_meshes.leaf = tool.commit()
	return _meshes.leaf


## Ein ganzer Apfel als Knoten: Körper, Stiel, Blatt, Kontur.
static func apple_node(red: Color) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = apple()
	var material := rim_material(red, Color("ffd2b0"), 0.38)
	body.material_override = with_outline(material, Color("ffe7a8"), 0.022)
	root.add_child(body)
	var stalk := MeshInstance3D.new()
	stalk.mesh = stem()
	stalk.material_override = flat(Color("5a3a1e"))
	stalk.position = Vector3(0.01, 0.62, 0)
	stalk.rotation_degrees = Vector3(0, 0, -12)
	root.add_child(stalk)
	var blade := MeshInstance3D.new()
	blade.mesh = leaf()
	blade.material_override = flat(Color("4fb548"), 0.15, 0.5)
	blade.position = Vector3(0.03, 0.66, 0)
	blade.rotation_degrees = Vector3(20, -30, 18)
	root.add_child(blade)
	return root


## Geflochtener Weidenkorb in echter Größe (keine verzerrende Skalierung):
## hohe, leicht bauchige Wand mit gewölbten Ruten, eingelegter Boden auf
## Füllhöhe, dicker gedrehter Rand und ein nach hinten geklappter Bügel, der
## über keinem Apfel liegt. Liefert den Knoten; Maße stehen in BASKET_*.
static func basket_node() -> Node3D:
	var root := Node3D.new()
	root.name = "Korb"
	var key := "basket_v3"
	var r := BASKET_RADIUS
	var h := BASKET_HEIGHT
	if not _meshes.has(key):
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for step in range(15):
			var t := step / 14.0
			# Bauchige Wand: unten schmaler, oben ausgestellt.
			var radius := lerpf(r * 0.8, r, t) + sin(t * PI) * 0.09
			outer.append(Vector2(radius, t * h))
			inner.insert(0, Vector2(radius - 0.07, t * h))
		var wall := PackedVector2Array()
		wall.append(Vector2(0.0, 0.0))
		wall.append_array(outer)
		wall.append_array(inner)
		_meshes[key] = lathe(wall, 72)
		var floor_mesh := CylinderMesh.new()
		var fill_t := BASKET_FILL / h
		floor_mesh.top_radius = lerpf(r * 0.8, r, fill_t) + sin(fill_t * PI) * 0.09 - 0.08
		floor_mesh.bottom_radius = floor_mesh.top_radius
		floor_mesh.height = 0.04
		floor_mesh.radial_segments = 48
		floor_mesh.rings = 1
		_meshes[key + "_floor"] = floor_mesh
		var rim := TorusMesh.new()
		rim.inner_radius = r - 0.1
		rim.outer_radius = r + 0.1
		rim.rings = 72
		rim.ring_segments = 12
		_meshes[key + "_rim"] = rim
		var arch := PackedVector3Array()
		for step in range(25):
			var angle := PI * step / 24.0
			arch.append(Vector3(cos(angle) * (r - 0.02), sin(angle) * 1.75, 0.0))
		_meshes[key + "_handle"] = tube(arch, 0.075, 10)
	var wicker := ShaderMaterial.new()
	wicker.shader = shader("wicker")
	wicker.set_shader_parameter("bulge", 0.03)
	var shell := MeshInstance3D.new()
	shell.name = "Flechtwand"
	shell.mesh = _meshes[key]
	shell.material_override = wicker
	root.add_child(shell)
	var mat := ShaderMaterial.new()
	mat.shader = shader("wicker")
	mat.set_shader_parameter("mode", 1)
	mat.set_shader_parameter("light_wood", Color("b97a3e"))
	var bottom := MeshInstance3D.new()
	bottom.name = "Korbboden"
	bottom.mesh = _meshes[key + "_floor"]
	bottom.material_override = mat
	bottom.position.y = BASKET_FILL - 0.02
	root.add_child(bottom)
	var rope := ShaderMaterial.new()
	rope.shader = shader("wicker")
	rope.set_shader_parameter("mode", 2)
	rope.set_shader_parameter("staves", 60.0)
	rope.set_shader_parameter("ring_radius", r)
	rope.set_shader_parameter("light_wood", Color("d39a58"))
	rope.next_pass = outline_material(Color("8fe9ff"), 0.018, 1.2)
	var rim_node := MeshInstance3D.new()
	rim_node.name = "Flechtrand"
	rim_node.mesh = _meshes[key + "_rim"]
	rim_node.material_override = rope
	rim_node.position.y = h
	root.add_child(rim_node)
	var handle_mat := ShaderMaterial.new()
	handle_mat.shader = shader("wicker")
	handle_mat.set_shader_parameter("mode", 3)
	handle_mat.set_shader_parameter("staves", 34.0)
	handle_mat.set_shader_parameter("ring_radius", r - 0.1)
	handle_mat.set_shader_parameter("light_wood", Color("c98c4c"))
	var handle := MeshInstance3D.new()
	handle.name = "Henkel"
	handle.mesh = _meshes[key + "_handle"]
	handle.material_override = handle_mat
	handle.position = Vector3(0, h, 0)
	# Nach hinten geneigt: Im Bild steht der Bügel hinter den Äpfeln, nicht davor.
	handle.rotation_degrees = Vector3(-40, 0, 0)
	root.add_child(handle)
	return root


## Rohr entlang eines Pfades (Henkel, Bahnen).
static func tube(path: PackedVector3Array, radius: float, sides: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	var rings: Array[PackedVector3Array] = []
	for index in range(path.size()):
		var ahead := path[mini(index + 1, path.size() - 1)] - path[maxi(index - 1, 0)]
		var forward := ahead.normalized()
		var side := forward.cross(Vector3.FORWARD)
		if side.length() < 0.01:
			side = forward.cross(Vector3.UP)
		side = side.normalized()
		var up := side.cross(forward).normalized()
		var ring := PackedVector3Array()
		for corner in range(sides):
			var angle := TAU * corner / sides
			ring.append(path[index] + (side * cos(angle) + up * sin(angle)) * radius)
		rings.append(ring)
	for index in range(rings.size() - 1):
		for corner in range(sides):
			var next := (corner + 1) % sides
			var quad := [
				rings[index][corner],
				rings[index][next],
				rings[index + 1][next],
				rings[index + 1][corner]
			]
			for order in [0, 1, 2, 0, 2, 3]:
				tool.add_vertex(quad[order])
	tool.generate_normals()
	return tool.commit()


## Leuchtende Kontur als Rechteckrahmen (z. B. um einen vollen Zehner).
static func glow_frame(size_value: Vector2, thickness: float) -> Node3D:
	var root := Node3D.new()
	root.name = "ZehnerKontur"
	var material := flat(Color("ffe27a"), 3.2)
	for side in [-1.0, 1.0]:
		for axis in [0, 1]:
			var bar := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			if axis == 0:
				mesh.size = Vector3(size_value.x + thickness, thickness, thickness)
			else:
				mesh.size = Vector3(thickness, thickness, size_value.y + thickness)
			bar.mesh = mesh
			bar.material_override = material
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bar.position = (
				Vector3(0, 0, side * size_value.y * 0.5)
				if axis == 0
				else Vector3(side * size_value.x * 0.5, 0, 0)
			)
			root.add_child(bar)
	return root


## Zwanzigerfeld: zwei Zehnerfelder (je 2 × 5 Mulden) als Holo-Tablett.
static func ten_frame_node(cell: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Zehnerfeld"
	var tray := flat(Color("17375a"), 0.0, 0.45)
	var edge := flat(Color("6fe3ff"), 1.4)
	var well := flat(Color("0d2540"), 0.0, 0.7)
	for frame in range(2):
		var origin := Vector3(0, 0, frame * (cell * 2.0 + cell * 0.55))
		var plate := MeshInstance3D.new()
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(cell * 5.0 + 0.16, 0.12, cell * 2.0 + 0.16)
		plate.mesh = plate_mesh
		plate.material_override = tray
		plate.position = origin
		plate.name = "Feld%d" % frame
		root.add_child(plate)
		for side in [-1, 1]:
			var rail := MeshInstance3D.new()
			var rail_mesh := BoxMesh.new()
			rail_mesh.size = Vector3(cell * 5.0 + 0.2, 0.05, 0.05)
			rail.mesh = rail_mesh
			rail.material_override = edge
			rail.position = origin + Vector3(0, 0.07, side * (cell + 0.08))
			root.add_child(rail)
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.05, 0.05, cell * 2.0 + 0.2)
		post.mesh = post_mesh
		post.material_override = edge
		post.position = origin + Vector3(0, 0.07, 0)
		root.add_child(post)
		for column in range(5):
			for row in range(2):
				var hollow := MeshInstance3D.new()
				var hollow_mesh := CylinderMesh.new()
				hollow_mesh.top_radius = cell * 0.40
				hollow_mesh.bottom_radius = cell * 0.36
				hollow_mesh.height = 0.03
				hollow_mesh.radial_segments = 18
				hollow.mesh = hollow_mesh
				hollow.material_override = well
				hollow.position = origin + Vector3((column - 2.0) * cell, 0.065, (row - 0.5) * cell)
				root.add_child(hollow)
	return root


static func frame_slot(cell: float, slot: int) -> Vector3:
	var frame := slot / 10
	var inner := slot % 10
	var row := inner / 5
	var column := inner % 5
	return Vector3((column - 2.0) * cell, 0.08, frame * (cell * 2.55) + (row - 0.5) * cell)


## Greifbare Wortkarte: abgerundetes Rechteck mit Fase und Tiefe.
## Fläche 0 = Vorder-/Rückseite (Papier), Fläche 1 = Kante (Karton).
static func card_mesh(size: Vector3) -> ArrayMesh:
	var key := "card_%.2f_%.2f_%.2f" % [size.x, size.y, size.z]
	if _meshes.has(key):
		return _meshes[key]
	var corner := minf(0.16, size.y * 0.18)
	var bevel := minf(0.035, size.z * 0.3)
	var outer := _rounded_rect(size.x * 0.5, size.y * 0.5, corner)
	var inner := _rounded_rect(size.x * 0.5 - bevel, size.y * 0.5 - bevel, corner - bevel)
	var half := size.z * 0.5
	var faces := SurfaceTool.new()
	faces.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := SurfaceTool.new()
	edges.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [1.0, -1.0]:
		var normal := Vector3(0, 0, side)
		for index in range(inner.size()):
			var next := (index + 1) % inner.size()
			var tri := [
				Vector3(0, 0, half * side),
				Vector3(inner[index].x, inner[index].y, half * side),
				Vector3(inner[next].x, inner[next].y, half * side)
			]
			if side < 0.0:
				tri = [tri[0], tri[2], tri[1]]
			for vertex: Vector3 in tri:
				faces.set_normal(normal)
				faces.set_uv(Vector2(vertex.x / size.x + 0.5, 0.5 - vertex.y / size.y))
				faces.add_vertex(vertex)
		# Fase: vom Innenrand der Fläche zum Außenrand der Kante.
		for index in range(outer.size()):
			var next := (index + 1) % outer.size()
			var quad := [
				Vector3(inner[index].x, inner[index].y, half * side),
				Vector3(outer[index].x, outer[index].y, (half - bevel) * side),
				Vector3(outer[next].x, outer[next].y, (half - bevel) * side),
				Vector3(inner[next].x, inner[next].y, half * side)
			]
			_quad(edges, quad, side < 0.0)
	for index in range(outer.size()):
		var next := (index + 1) % outer.size()
		var wall := [
			Vector3(outer[index].x, outer[index].y, half - bevel),
			Vector3(outer[index].x, outer[index].y, -half + bevel),
			Vector3(outer[next].x, outer[next].y, -half + bevel),
			Vector3(outer[next].x, outer[next].y, half - bevel)
		]
		_quad(edges, wall, false)
	var mesh := faces.commit()
	edges.generate_normals()
	edges.commit(mesh)
	_meshes[key] = mesh
	return mesh


static func _quad(tool: SurfaceTool, quad: Array, flip: bool) -> void:
	var order := [0, 2, 1, 0, 3, 2] if flip else [0, 1, 2, 0, 2, 3]
	for index: int in order:
		tool.add_vertex(quad[index])


## Umriss eines abgerundeten Rechtecks (gegen den Uhrzeigersinn).
static func _rounded_rect(half_x: float, half_y: float, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var centres := [
		Vector2(half_x - radius, half_y - radius),
		Vector2(-half_x + radius, half_y - radius),
		Vector2(-half_x + radius, -half_y + radius),
		Vector2(half_x - radius, -half_y + radius)
	]
	for quarter in range(4):
		for step in range(6):
			var angle := PI * 0.5 * (quarter + step / 5.0)
			points.append(centres[quarter] + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func holo_material(tint: Color, strength: float = 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader("holo")
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("strength", strength)
	return material


## Holo-Podest: runde Bühne mit leuchtendem Raster und Ringen.
static func podium_node(radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "HoloPodest"
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = radius
	disc_mesh.bottom_radius = radius * 1.03
	disc_mesh.height = 0.22
	disc_mesh.radial_segments = 56
	disc.mesh = disc_mesh
	var grid := ShaderMaterial.new()
	grid.shader = shader("grid")
	disc.material_override = grid
	disc.position.y = -0.11
	disc.name = "Bodenraster"
	root.add_child(disc)
	var edge := MeshInstance3D.new()
	var edge_mesh := TorusMesh.new()
	edge_mesh.inner_radius = radius * 1.01
	edge_mesh.outer_radius = radius * 1.045
	edge_mesh.rings = 64
	edge_mesh.ring_segments = 6
	edge.mesh = edge_mesh
	edge.material_override = flat(Color("63dcff"), 2.2)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(edge)
	return root
