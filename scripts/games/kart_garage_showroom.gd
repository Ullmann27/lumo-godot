extends RefCounted
## Lumo-Garage als farbiger Konzeptbild-Raum (Auftrag kart-garage, Vorgabe Heinz 18.11.):
## Sonnenuntergangs-LED-Wand (Orange → Magenta → Violett, wie die Lumo-App) hinter dem
## Drehteller, Neonrahmen um das LUMO-Schild, warme Sandwände mit Holz-Lamellen, bunte
## Wimpelkette, Pokalregal, Aufkleber-Poster, rote Werkzeugkiste, Reifenstapel mit bunten
## Felgen, gelbe Hebebühne, glänzender Boden mit Warnstreifen und Ölfleck.
## Ein selbst gerechnetes Studio-Panorama dient nur als Spiegelquelle (Lack, Chrom, Boden),
## damit der Lack im Kompatibilitäts-Renderer glänzt statt schwarz zu wirken.
## Alles aus eigenen Grundkörpern; Wiederholungen als MultiMesh. LOW bekommt nur Farbe,
## Licht und Boden; Requisiten ab MEDIUM, Staub nur HIGH. Nichts blinkt.

const INTERIOR = preload("res://scripts/games/kart_garage_interior.gd")
const PARTICLE_QUAD = preload("res://scripts/systems/particle_quad.gd")
const FINISH = preload("res://scripts/games/kart_vehicle_finish.gd")

const WOOD := Color("c98a52")
const RED := Color("e8423a")
const YELLOW := Color("ffc532")
const MAGENTA := Color("ff4fc8")
const ORANGE := Color("ff9a3c")
const CYAN := Color("3ae0ff")
const GREEN := Color("5fd068")
const GOLD := Color("ffbf3c")
## Schild-Mitte (LUMO-Schrift) – die Kamera bezieht die Ecken des Rahmens in den Bildausschnitt ein.
const SIGN_CENTER := Vector3(0.0, 1.98, 3.90)
const SIGN_HALF := Vector2(2.02, 0.56)
const BUNTING_COLORS: Array[Color] = [
	Color("ff5a4e"), Color("ffc532"), Color("3ae0ff"), Color("6ee06a"), Color("ff6fd2"), Color("8f7bff")
]


static func build(root: Node3D, materials: Dictionary, profile: String) -> Dictionary:
	var rich: bool = profile != "low"
	var mats := {
		"wood": INTERIOR._mat(WOOD, 0.0, 0.62),
		"red": INTERIOR._mat(RED, 0.25, 0.28),
		"yellow": INTERIOR._mat(YELLOW, 0.2, 0.36),
		"chrome": INTERIOR._mat(Color("dfe7ef"), 0.85, 0.18),
		"gold": INTERIOR._mat(GOLD, 0.85, 0.22),
		"dark": INTERIOR._mat(Color("1a2230"), 0.1, 0.6),
		"blue": INTERIOR._mat(Color("2f7bff"), 0.2, 0.32),
		"neon_magenta": INTERIOR._emit(MAGENTA, MAGENTA, 2.2),
		"neon_orange": INTERIOR._emit(ORANGE, ORANGE, 1.8),
		"neon_cyan": INTERIOR._emit(CYAN, CYAN, 1.6),
		"stain": _stain_material(),
	}
	var showroom := Node3D.new()
	showroom.name = "GarageShowroom"
	root.add_child(showroom)
	# Glänzender, hellerer Boden: Lichter und Kart spiegeln sich als weiche Glanzflächen.
	if materials.has("floor"):
		var floor: StandardMaterial3D = materials.floor
		# Über 0.4 bleiben: ohne Reflexionssonde wurde ein glatter Boden in GLES schwarz.
		floor.roughness = 0.42
		floor.metallic = 0.08
		floor.metallic_specular = 0.4
	_led_backdrop(showroom)
	_ceiling(showroom, mats)
	_neon_frame(showroom, mats)
	_hazard_ring(showroom, mats)
	_start_box(showroom, mats)
	_floor_marks(showroom, mats)
	_lights(showroom, rich)
	if rich:
		_wood_slats(showroom, mats)
		_bunting(showroom)
		_trophy_shelf(showroom, mats)
		_posters(showroom, mats)
		_tool_chest(showroom, mats)
		_tyre_stack(showroom, mats, Vector3(-4.75, -0.34, 2.15))
		_lift(showroom, mats)
		_cables(showroom, mats)
	if profile == "high":
		_dust(showroom)
	# Ruhende Teile gleichen Materials zu je einem Netz zusammenfassen (Draw-Calls sparen).
	merge_static(showroom, [])
	return {"root": showroom, "materials": mats}


## Fasst alle ruhenden MeshInstance3D/MultiMeshInstance3D unter root je Material und
## Schattenwurf zu einem einzigen Netz zusammen. Ausgenommene Knoten (und alles darunter)
## bleiben unverändert, ebenso Netze mit Skin, Kindern oder Instanzfarben.
## Gibt die Zahl der ersetzten Knoten zurück.
static func merge_static(root: Node3D, exclude: Array) -> int:
	var groups: Dictionary = {}
	var order: Array = []
	var merged: Array[Node] = []
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		if not _mergeable(node, root, exclude):
			continue
		var material: Material = node.material_override
		var local: Transform3D = _relative_transform(node, root)
		var parts: Array = []
		if node is MeshInstance3D:
			parts.append([node.mesh, local])
		else:
			var instances: MultiMesh = node.multimesh
			for index in range(instances.instance_count):
				parts.append([instances.mesh, local * instances.get_instance_transform(index)])
		var shadow: bool = node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var key := "%d:%s" % [material.get_instance_id(), shadow]
		if not groups.has(key):
			groups[key] = {"material": material, "shadow": shadow, "vertices": PackedVector3Array(),
				"normals": PackedVector3Array(), "uvs": PackedVector2Array(), "indices": PackedInt32Array()}
			order.append(key)
		for part in parts:
			_append_mesh(groups[key], part[0], part[1])
		merged.append(node)
	if merged.size() < 2:
		return 0
	for node in merged:
		node.get_parent().remove_child(node)
		node.free()
	for index in range(order.size()):
		var group: Dictionary = groups[order[index]]
		if group.indices.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = group.vertices
		arrays[Mesh.ARRAY_NORMAL] = group.normals
		arrays[Mesh.ARRAY_TEX_UV] = group.uvs
		arrays[Mesh.ARRAY_INDEX] = group.indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var item := MeshInstance3D.new()
		item.name = "MergedStatic%d" % index
		item.mesh = mesh
		item.material_override = group.material
		item.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if group.shadow
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		root.add_child(item)
	root.set_meta("merged_static_nodes", merged.size())
	return merged.size()


static func _mergeable(node: Node, root: Node3D, exclude: Array) -> bool:
	if not node is GeometryInstance3D or node.material_override == null or node.get_child_count() > 0:
		return false
	if node is MeshInstance3D:
		if node.mesh == null or node.skin != null:
			return false
	elif node is MultiMeshInstance3D:
		var instances: MultiMesh = node.multimesh
		if instances == null or instances.mesh == null or instances.use_colors or instances.use_custom_data:
			return false
	else:
		return false
	var walker: Node = node
	while walker != root:
		if walker == null or exclude.has(walker) or not walker is Node3D or not walker.visible:
			return false
		walker = walker.get_parent()
	return true


static func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var walker: Node = node
	while walker != root:
		result = (walker as Node3D).transform * result
		walker = walker.get_parent()
	return result


## Hängt alle Flächen eines Netzes transformiert an (Normalen mit der inversen Transponierten).
static func _append_mesh(group: Dictionary, mesh: Mesh, xform: Transform3D) -> void:
	var normal_basis: Basis = xform.basis.inverse().transposed()
	for surface in range(mesh.get_surface_count()):
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]
		var indices = arrays[Mesh.ARRAY_INDEX]
		var offset: int = group.vertices.size()
		for v in range(vertices.size()):
			group.vertices.append(xform * vertices[v])
			group.normals.append((normal_basis * normals[v]).normalized() if normals != null and normals.size() == vertices.size() else Vector3.UP)
			group.uvs.append(uvs[v] if uvs != null and uvs.size() == vertices.size() else Vector2.ZERO)
		if indices != null and indices.size() > 0:
			for i in indices:
				group.indices.append(offset + i)
		else:
			for v in range(vertices.size()):
				group.indices.append(offset + v)


## Ecken des Schild-Rahmens: die Garage-Kamera hält sie frei von Reitern und Knöpfen.
static func sign_points(root: Node3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			points.append(root.to_global(SIGN_CENTER + Vector3(sx * SIGN_HALF.x, sy * SIGN_HALF.y + 0.06, 0)))
	return points


## Spiegelquelle: helles Studio-Panorama (Deckenleuchten, warme und farbige Bänder).
## Nur für Reflexionen, der Hintergrund bleibt die Garage selbst.
static func studio_sky() -> Sky:
	var width := 256
	var height := 128
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	for y in range(height):
		var v := float(y) / float(height - 1)
		for x in range(width):
			var u := float(x) / float(width)
			var colour: Color
			if v < 0.5:
				colour = Color("4a4038").lerp(Color("b49a82"), v * 2.0)
			else:
				colour = Color("6d6a72").lerp(Color("2a3240"), (v - 0.5) * 2.0)
			# Deckenleuchten: lange, sehr helle Streifen.
			if v > 0.08 and v < 0.30 and fmod(u * 6.0, 1.0) < 0.42:
				colour = Color(1.0, 0.97, 0.9)
			# Ringleuchte genau über dem Drehteller.
			if v < 0.05:
				colour = Color(1.0, 0.98, 0.94)
			# Farbige Bänder um den Horizont: Orange, Cyan, Magenta.
			if v > 0.40 and v < 0.48:
				if u < 0.22:
					colour = Color("ffa04a")
				elif u > 0.45 and u < 0.62:
					colour = Color("47e4ff")
				elif u > 0.80 and u < 0.92:
					colour = Color("ff5fd0")
			image.set_pixel(x, y, colour)
	var material := PanoramaSkyMaterial.new()
	material.panorama = ImageTexture.create_from_image(image)
	material.energy_multiplier = 1.25
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	return sky


## Studio-Spiegelung an- oder abschalten (Garage an, Startbühne behält ihre Stimmung).
static func apply_reflections(environment: Environment, sky: Sky, enabled: bool) -> void:
	if environment == null:
		return
	if enabled:
		environment.sky = sky
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	else:
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG


static func _stain_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.03, 0.025, 0.02, 0.62)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.08
	material.metallic_specular = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _tube(parent: Node3D, mesh_name: String, from: Vector3, to: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = mesh_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 12
	mesh.rings = 1
	item.mesh = mesh
	item.material_override = material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	var axis: Vector3 = (to - from).normalized()
	var side: Vector3 = axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	item.transform = Transform3D(Basis(side, axis, side.cross(axis)), (from + to) * 0.5)
	return item


## LED-Wand im Sonnenuntergangs-Verlauf der Lumo-App: Orange unten, Magenta, Violett oben.
## Selbstleuchtend und unbeleuchtet – ein einziger Draw-Call, keine Textur-Datei.
static func _led_backdrop(parent: Node3D) -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 0.78, 1.0])
	gradient.colors = PackedColorArray([Color("3a2a8c"), Color("b83f9e"), Color("ff7a4a"), Color("ffb35a")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 128
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	material.albedo_color = Color(0.92, 0.92, 0.92)
	var wall := MeshInstance3D.new()
	wall.name = "SunsetLedWall"
	var quad := QuadMesh.new()
	quad.size = Vector2(6.3, 3.72)
	wall.mesh = quad
	wall.material_override = material
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall.position = Vector3(0.0, 1.57, 4.135)
	wall.rotation.y = PI
	parent.add_child(wall)


## Decke mit warmen Lichtbändern: im Hochformat sieht die Kamera über die Wände hinaus.
static func _ceiling(parent: Node3D, mats: Dictionary) -> void:
	INTERIOR._box(parent, "ShowroomCeiling", Vector3(11.6, 0.12, 9.2), Vector3(0.0, 5.62, -0.2), mats.dark, false)
	var panels: Array[Transform3D] = []
	for x in [-2.6, 0.0, 2.6]:
		panels.append(INTERIOR._box_transform(Vector3(1.6, 0.04, 6.4), Vector3(x, 5.55, -0.4)))
	INTERIOR._batch_boxes(parent, "CeilingLightPanels", panels, INTERIOR._emit(Color("fff3de"), Color("ffe8c4"), 1.4), false)
	# Drei Industrie-Pendelleuchten über dem Drehteller: farbige Schirme, warm leuchtende Unterseite.
	var shades := [INTERIOR._mat(Color("ff5a4e"), 0.3, 0.35), INTERIOR._mat(Color("ffc532"), 0.3, 0.35),
		INTERIOR._mat(Color("3ae0ff"), 0.3, 0.35)]
	var glow := INTERIOR._emit(Color("fff4dc"), Color("ffe4b0"), 2.6)
	var cable: Material = mats.dark
	for k in range(3):
		var x: float = -1.7 + k * 1.7
		var at := Vector3(x, 4.25, 0.6)
		_tube(parent, "PendantCable", at + Vector3(0, 0.25, 0), Vector3(x, 5.56, 0.6), 0.01, cable)
		var shade := MeshInstance3D.new()
		shade.name = "PendantShade"
		var cone := CylinderMesh.new()
		cone.top_radius = 0.07
		cone.bottom_radius = 0.34
		cone.height = 0.32
		cone.radial_segments = 24
		cone.rings = 1
		shade.mesh = cone
		shade.position = at + Vector3(0, 0.1, 0)
		shade.material_override = shades[k]
		shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(shade)
		var bulb := MeshInstance3D.new()
		bulb.name = "PendantGlow"
		var disc := CylinderMesh.new()
		disc.top_radius = 0.3
		disc.bottom_radius = 0.3
		disc.height = 0.01
		disc.radial_segments = 24
		disc.rings = 1
		bulb.mesh = disc
		bulb.position = at + Vector3(0, -0.055, 0)
		bulb.material_override = glow
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(bulb)


## Neonrahmen um das LUMO-Schild: Magenta außen, Orange als Unterstrich.
static func _neon_frame(parent: Node3D, mats: Dictionary) -> void:
	var z := SIGN_CENTER.z
	var x0 := -SIGN_HALF.x
	var x1 := SIGN_HALF.x
	var y0 := SIGN_CENTER.y - SIGN_HALF.y
	var y1 := SIGN_CENTER.y + SIGN_HALF.y
	var corners := [Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z)]
	for k in range(4):
		_tube(parent, "NeonFrame%d" % k, corners[k], corners[(k + 1) % 4], 0.028, mats.neon_magenta)
	_tube(parent, "NeonUnderline", Vector3(-1.2, y0 - 0.12, z), Vector3(1.2, y0 - 0.12, z), 0.022, mats.neon_orange)


## Gelb-schwarze Warnstreifen als Ring um den Drehteller.
static func _hazard_ring(parent: Node3D, mats: Dictionary) -> void:
	var yellow: Array[Transform3D] = []
	var black: Array[Transform3D] = []
	var count := 64
	for k in range(count):
		var angle: float = TAU * k / count
		var basis := Basis(Vector3.UP, angle).scaled(Vector3(0.228, 0.012, 0.13))
		var at := Vector3(sin(angle) * 2.28, -0.331, cos(angle) * 2.28)
		(yellow if k % 2 == 0 else black).append(Transform3D(basis, at))
	INTERIOR._batch_boxes(parent, "HazardRingYellow", yellow, mats.yellow, false)
	INTERIOR._batch_boxes(parent, "HazardRingDark", black, mats.dark, false)


## Aufgemalte Startbox vor dem Drehteller: gelbe Linien und ein Zielflaggen-Streifen.
static func _start_box(parent: Node3D, mats: Dictionary) -> void:
	var lines: Array[Transform3D] = []
	for x in [-1.75, 1.75]:
		lines.append(INTERIOR._box_transform(Vector3(0.09, 0.004, 3.0), Vector3(x, -0.3325, -3.85)))
	INTERIOR._batch_boxes(parent, "StartBoxLines", lines, mats.yellow, false)
	var white: Array[Transform3D] = []
	var black: Array[Transform3D] = []
	for i in range(14):
		for j in range(2):
			var at := Vector3(-1.625 + i * 0.25, -0.3325, -2.72 - j * 0.25)
			(white if (i + j) % 2 == 0 else black).append(INTERIOR._box_transform(Vector3(0.25, 0.004, 0.25), at))
	INTERIOR._batch_boxes(parent, "StartBoxCheckerLight", white, INTERIOR._mat(Color("eef3f7"), 0.0, 0.5), false)
	INTERIOR._batch_boxes(parent, "StartBoxCheckerDark", black, mats.dark, false)


## Ölfleck und Reifenabrieb: dunkle, glänzende Flecken knapp über dem Boden.
static func _floor_marks(parent: Node3D, mats: Dictionary) -> void:
	for blob in [[Vector3(-2.9, -0.3335, -0.9), 0.42], [Vector3(-2.55, -0.3335, -0.62), 0.18], [Vector3(-3.25, -0.3335, -1.15), 0.12]]:
		var stain := MeshInstance3D.new()
		stain.name = "OilStain"
		var mesh := CylinderMesh.new()
		mesh.top_radius = float(blob[1])
		mesh.bottom_radius = float(blob[1])
		mesh.height = 0.002
		mesh.radial_segments = 28
		stain.mesh = mesh
		stain.scale = Vector3(1.0, 1.0, 0.72)
		stain.position = blob[0]
		stain.material_override = mats.stain
		stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(stain)


static func _lights(parent: Node3D, rich: bool) -> void:
	# Farbige Lichtstimmung: Magenta tief hinter dem Kart (Kantenlicht), Orange von der Werkbank.
	var accent := OmniLight3D.new()
	accent.name = "ShowroomMagentaBack"
	accent.position = Vector3(0.4, 0.9, 2.2)
	accent.light_color = MAGENTA
	accent.light_energy = 1.1 if rich else 0.7
	accent.omni_range = 4.0
	accent.light_specular = 0.9
	parent.add_child(accent)
	var warm := OmniLight3D.new()
	warm.name = "ShowroomWarmBench"
	warm.position = Vector3(-3.4, 2.2, 1.4)
	warm.light_color = Color("ffb36b")
	warm.light_energy = 0.9 if rich else 0.6
	warm.omni_range = 5.5
	warm.light_specular = 0.35
	parent.add_child(warm)


## Holz-Lamellen an den Seiten der Rückwand: warmer Gegenpol zur LED-Wand.
static func _wood_slats(parent: Node3D, mats: Dictionary) -> void:
	var slats: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for k in range(13):
			var x: float = side * (3.62 + k * 0.155)
			slats.append(INTERIOR._box_transform(Vector3(0.11, 3.7, 0.06), Vector3(x, 1.52, 4.19)))
	INTERIOR._batch_boxes(parent, "WarmWoodSlats", slats, mats.wood, false)
	for side in [-1.0, 1.0]:
		_tube(parent, "SlatLightStrip", Vector3(side * 3.55, -0.2, 4.1), Vector3(side * 3.55, 3.3, 4.1), 0.02, mats.neon_orange)


## Bunte Wimpelkette quer über der LED-Wand: ein MultiMesh mit Eckfarben, ein Draw-Call.
static func _bunting(parent: Node3D) -> void:
	var prism := PrismMesh.new()
	prism.size = Vector3(0.26, 0.30, 0.012)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = prism
	var flags: Array[Transform3D] = []
	var colours: Array[Color] = []
	for strand in range(2):
		var x0: float = -3.3 if strand == 0 else 0.0
		var x1: float = 0.0 if strand == 0 else 3.3
		var count := 9
		for k in range(count):
			var t := (k + 0.5) / count
			var x: float = lerpf(x0, x1, t)
			var sag: float = sin(t * PI) * 0.22
			# Spitze nach unten: Prisma um die Blickachse gedreht.
			flags.append(Transform3D(Basis(Vector3.BACK, PI), Vector3(x, 3.30 - sag - 0.15, 3.80)))
			colours.append(BUNTING_COLORS[(k + strand * 3) % BUNTING_COLORS.size()])
	multimesh.instance_count = flags.size()
	for index in range(flags.size()):
		multimesh.set_instance_transform(index, flags[index])
		multimesh.set_instance_color(index, colours[index])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.55
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var batch := MultiMeshInstance3D.new()
	batch.name = "ColourfulBunting"
	batch.multimesh = multimesh
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(batch)
	var cord := INTERIOR._mat(Color("f4efe6"), 0.0, 0.6)
	for strand in range(2):
		var x0: float = -3.3 if strand == 0 else 0.0
		var x1: float = 0.0 if strand == 0 else 3.3
		for k in range(4):
			var a: float = float(k) / 4.0
			var b: float = float(k + 1) / 4.0
			_tube(parent, "BuntingCord", Vector3(lerpf(x0, x1, a), 3.30 - sin(a * PI) * 0.22, 3.80),
				Vector3(lerpf(x0, x1, b), 3.30 - sin(b * PI) * 0.22, 3.80), 0.006, cord)


## Holzregale mit goldenen Pokalen (gebaute Modelle: Fuß, Stiel, Kelch, Henkel).
## Gleiche Teile aller Pokale liegen in je einem MultiMesh: vier Draw-Calls für alle Pokale.
static func _trophy_shelf(parent: Node3D, mats: Dictionary) -> void:
	var bases: Array[Transform3D] = []
	var stems: Array[Transform3D] = []
	var cups: Array[Transform3D] = []
	var handles: Array[Transform3D] = []
	for at in [Vector3(4.55, 1.55, 4.02), Vector3(-4.55, 2.62, 4.02)]:
		INTERIOR._box(parent, "TrophyShelf", Vector3(1.5, 0.06, 0.34), at, mats.wood, true)
		for k in range(3):
			var x: float = at.x + (k - 1) * 0.46
			var s: float = 1.0 if k == 1 else 0.78
			var y: float = at.y + 0.03
			bases.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.16, 0.06, 0.16) * s), Vector3(x, y + 0.03 * s, at.z)))
			stems.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(x, y + 0.12 * s, at.z)))
			cups.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(x, y + 0.28 * s, at.z)))
			for side in [-1.0, 1.0]:
				handles.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * s), Vector3(x + side * 0.115 * s, y + 0.30 * s, at.z)))
	INTERIOR._batch_boxes(parent, "TrophyBases", bases, mats.dark, false)
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.025
	stem_mesh.bottom_radius = 0.025
	stem_mesh.height = 0.12
	stem_mesh.radial_segments = 12
	stem_mesh.rings = 1
	var cup_mesh := CylinderMesh.new()
	cup_mesh.top_radius = 0.11
	cup_mesh.bottom_radius = 0.035
	cup_mesh.height = 0.2
	cup_mesh.radial_segments = 24
	cup_mesh.rings = 1
	var handle_mesh := TorusMesh.new()
	handle_mesh.inner_radius = 0.035
	handle_mesh.outer_radius = 0.05
	handle_mesh.rings = 12
	handle_mesh.ring_segments = 6
	_batch_mesh(parent, "TrophyStems", stem_mesh, stems, mats.gold)
	_batch_mesh(parent, "TrophyCups", cup_mesh, cups, mats.gold)
	_batch_mesh(parent, "TrophyHandles", handle_mesh, handles, mats.gold)


static func _batch_mesh(parent: Node3D, batch_name: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for index in range(transforms.size()):
		instances.set_instance_transform(index, transforms[index])
	var batch := MultiMeshInstance3D.new()
	batch.name = batch_name
	batch.multimesh = instances
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(batch)


## Fantasie-Poster aus dem Aufkleber-Atlas (keine echten Marken) auf weißem Rahmen.
static func _posters(parent: Node3D, mats: Dictionary) -> void:
	var frame := INTERIOR._mat(Color("f6f2ea"), 0.0, 0.5)
	for entry in [["fuchsstern", Vector3(4.55, 2.55, 4.05), 0.95], ["kometen", Vector3(-4.55, 1.9, 4.05), 0.8],
			["sonnenhafen", Vector3(4.2, 0.62, 4.05), 0.7]]:
		var at: Vector3 = entry[1]
		var width: float = entry[2]
		INTERIOR._box(parent, "PosterFrame", Vector3(width + 0.08, width + 0.08, 0.03), at + Vector3(0, 0, 0.02), frame, false)
		var poster := MeshInstance3D.new()
		poster.name = "Poster_" + str(entry[0])
		poster.mesh = FINISH._sticker_mesh(str(entry[0]), width)
		poster.material_override = FINISH._sticker_mat()
		poster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		poster.position = at + Vector3(0, 0, -0.005)
		poster.rotation.y = PI
		parent.add_child(poster)


## Rote Werkzeugkiste auf Rollen mit Schubladen und Chromgriffen.
static func _tool_chest(parent: Node3D, mats: Dictionary) -> void:
	var at := Vector3(-2.55, 0.0, 3.55)
	INTERIOR._box(parent, "ToolChestBody", Vector3(1.05, 0.95, 0.55), at + Vector3(0, 0.22, 0), mats.red, true)
	INTERIOR._box(parent, "ToolChestTop", Vector3(1.1, 0.05, 0.6), at + Vector3(0, 0.72, 0), mats.dark, true)
	var handles: Array[Transform3D] = []
	var seams: Array[Transform3D] = []
	for k in range(5):
		var y: float = -0.14 + k * 0.17
		seams.append(INTERIOR._box_transform(Vector3(0.98, 0.012, 0.02), at + Vector3(0, y + 0.08, -0.28)))
		handles.append(INTERIOR._box_transform(Vector3(0.42, 0.025, 0.035), at + Vector3(0, y + 0.02, -0.295)))
	INTERIOR._batch_boxes(parent, "ToolChestSeams", seams, mats.dark, false)
	INTERIOR._batch_boxes(parent, "ToolChestHandles", handles, mats.chrome, false)
	for x in [-0.42, 0.42]:
		for z in [-0.2, 0.2]:
			var caster := INTERIOR._cylinder(parent, "ToolChestCaster", 0.055, 0.04, at + Vector3(x, -0.29, z), mats.dark)
			caster.rotation.z = PI * 0.5
	# Ein Schraubenschlüssel und ein Ölkännchen liegen obenauf.
	INTERIOR._box(parent, "ChestWrench", Vector3(0.36, 0.02, 0.05), at + Vector3(-0.15, 0.755, -0.05), mats.chrome, false).rotation.y = 0.4
	var can := INTERIOR._cylinder(parent, "ChestOilCan", 0.07, 0.16, at + Vector3(0.3, 0.83, 0.05), mats.blue)
	can.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Reifenstapel mit bunten Felgen-Einsätzen.
static func _tyre_stack(parent: Node3D, mats: Dictionary, at: Vector3) -> void:
	var rims := [mats.yellow, mats.blue, mats.red, mats.neon_cyan]
	var rubber := INTERIOR._mat(Color("161b24"), 0.0, 0.82)
	for k in range(4):
		var tyre := MeshInstance3D.new()
		tyre.name = "ShowroomTyre%d" % k
		var torus := TorusMesh.new()
		torus.inner_radius = 0.2
		torus.outer_radius = 0.38
		torus.rings = 24
		torus.ring_segments = 10
		tyre.mesh = torus
		tyre.scale = Vector3(1, 1.25, 1)
		tyre.position = at + Vector3(sin(k * 1.7) * 0.03, 0.12 + k * 0.23, cos(k * 1.3) * 0.03)
		tyre.material_override = rubber
		parent.add_child(tyre)
		var rim := INTERIOR._cylinder(parent, "ShowroomRim%d" % k, 0.2, 0.16, tyre.position, rims[k])
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Hebebühne: zwei gelbe Säulen, Tragarme, Hydraulikzylinder mit Chromkolben, Schläuche.
static func _lift(parent: Node3D, mats: Dictionary) -> void:
	for x in [3.15, 4.85]:
		INTERIOR._box(parent, "LiftPost", Vector3(0.22, 3.2, 0.22), Vector3(x, 1.25, 2.6), mats.yellow, true)
		INTERIOR._box(parent, "LiftFoot", Vector3(0.5, 0.06, 0.5), Vector3(x, -0.33, 2.6), mats.dark, false)
		INTERIOR._box(parent, "LiftArm", Vector3(0.12, 0.09, 1.1), Vector3(x, 0.32, 2.05), mats.yellow, true)
		INTERIOR._cylinder(parent, "LiftCylinder", 0.07, 1.2, Vector3(x, 0.35, 2.85), mats.dark)
		INTERIOR._cylinder(parent, "LiftPiston", 0.04, 0.7, Vector3(x, 1.25, 2.85), mats.chrome)
		_tube(parent, "LiftHose", Vector3(x, -0.25, 2.95), Vector3(x + (0.3 if x < 4.0 else -0.3), 0.9, 3.0), 0.018, mats.dark)
	INTERIOR._box(parent, "LiftBeam", Vector3(1.92, 0.18, 0.22), Vector3(4.0, 2.88, 2.6), mats.yellow, true)


## Kabel von der Decke zu den warmen Leuchten.
static func _cables(parent: Node3D, mats: Dictionary) -> void:
	for x in [-2.25, 2.25]:
		for dx in [-0.45, 0.45]:
			_tube(parent, "LightCable", Vector3(x + dx, 3.2, 3.79), Vector3(x + dx * 0.8, 5.5, 3.6), 0.008, mats.dark)


## Staub im Lichtkegel: langsam schwebende, sehr schwache Lichtpunkte (nur HIGH).
static func _dust(parent: Node3D) -> void:
	var dust := CPUParticles3D.new()
	dust.name = "LightConeDust"
	dust.amount = 70
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.mesh = PARTICLE_QUAD.make(Vector2(0.018, 0.018))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dust.material_override = material
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.4, 1.8, 1.4)
	dust.position = Vector3(0.1, 2.0, -1.2)
	dust.direction = Vector3(0.2, 1, 0)
	dust.spread = 180.0
	dust.gravity = Vector3(0, -0.01, 0)
	dust.initial_velocity_min = 0.01
	dust.initial_velocity_max = 0.05
	dust.color = Color(1.0, 0.9, 0.72, 0.35)
	parent.add_child(dust)
