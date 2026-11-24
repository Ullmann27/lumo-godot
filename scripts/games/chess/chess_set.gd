extends Node3D
## Das 3D-Schachspiel auf Lumos Tisch: Brett und Figuren aus Blender
## (assets/chess, siehe tools/lumo_chess_art/build_chess_set.py), Holz aus
## eigenen Texturen, weiche Kontaktschatten, leuchtende Felder, Sterne und
## Mauern für die Mini-Spiele, Feldnamen am Rand (abschaltbar).
##
## Reine Darstellung: kennt das Brett nur über `show_board()` und die Züge
## über `animate_move()`. Weiß sitzt vorn (+Z, beim Kind), Linie a links.

signal move_animated

const MODELS := "res://assets/chess/models/%s.glb"
const TEX := "res://assets/chess/textures/%s.webp"
const NAMES := ["", "pawn", "knight", "bishop", "rook", "queen", "king"]
const SQUARE := 0.1
const TOP := 0.0304
const SHADOW_SIZE := [0.0, 0.074, 0.08, 0.076, 0.08, 0.086, 0.088]

var reduced_motion := false
var time_scale := 1.0
var pieces: Dictionary = {}  # Feld -> Node3D
var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var _glow_root: Node3D
var _prop_root: Node3D
var _coords: Node3D
var _glows: Array[MeshInstance3D] = []
var _glow_time := 0.0
var _lifted: Node3D
var _lift_from := -1
var _anim: Tween
var _board_node: Node3D


func _ready() -> void:
	_build_board()
	_glow_root = Node3D.new()
	_glow_root.name = "Glow"
	add_child(_glow_root)
	_prop_root = Node3D.new()
	_prop_root.name = "Props"
	add_child(_prop_root)
	_build_coords()


func _process(delta: float) -> void:
	_glow_time += delta
	var pulse := 0.75 if reduced_motion else 0.62 + 0.25 * sin(_glow_time * 4.2)
	for glow: MeshInstance3D in _glows:
		var material := glow.material_override as StandardMaterial3D
		if material != null and glow.has_meta("pulse"):
			material.albedo_color.a = float(glow.get_meta("alpha")) * pulse
	for prop: Node in _prop_root.get_children():
		if prop.has_meta("star") and not reduced_motion:
			(prop as Node3D).rotation.y += delta * 1.6
			(prop as Node3D).position.y = (
				TOP + 0.045 + 0.008 * sin(_glow_time * 3.0 + float(prop.get_meta("star")))
			)


# ---------------------------------------------------------------- Materialien


func _texture(name: String) -> Texture2D:
	var path := TEX % name
	return load(path) if ResourceLoader.exists(path) else null


## Lackiertes Holz: Maserung dreiplanar im Raum der Figur (wandert mit), sanfter
## Glanz, leichter Randschimmer. Läuft gleich in gl_compatibility und Mobile.
func wood_material(key: String) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.resource_name = "chess_" + key
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match key:
		"white", "black":
			material.albedo_texture = _texture("piece_maple" if key == "white" else "piece_walnut")
			material.uv1_triplanar = true
			material.uv1_triplanar_sharpness = 3.0
			material.uv1_scale = Vector3.ONE * 9.0
			material.roughness = 0.47 if key == "white" else 0.38
			material.metallic_specular = 0.62
			material.rim_enabled = true
			material.rim = 0.22 if key == "white" else 0.35
			material.rim_tint = 0.6
			material.albedo_color = (
				Color(0.78, 0.80, 0.80) if key == "white" else Color.WHITE
			)
		"brass":
			material.albedo_color = Color("dab777")
			material.metallic = 0.48
			material.roughness = 0.32
		"frame":
			material.albedo_texture = _texture("frame_walnut")
			material.uv1_triplanar = true
			material.uv1_scale = Vector3.ONE * 2.2
			material.roughness = 0.3
			material.metallic_specular = 0.6
		"top":
			material.albedo_texture = _texture("board_top")
			material.albedo_color = Color(0.69, 0.77, 0.74)
			material.roughness = 0.3
			material.metallic_specular = 0.28
		"felt":
			material.albedo_texture = _texture("felt_green")
			material.roughness = 1.0
		"shadow":
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_texture = _texture("piece_shadow")
			material.albedo_color = Color(0.03, 0.015, 0.0, 0.62)
			material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			material.render_priority = -1
	_materials[key] = material
	return material


func _skin(node: Node, wood: String) -> void:
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		for surface in range(instance.mesh.get_surface_count()):
			var source := instance.mesh.surface_get_material(surface)
			var key := source.resource_name.get_slice(".", 0) if source != null else ""
			var target := wood
			match key:
				"felt", "board_felt":
					target = "felt"
				"brass":
					target = "brass"
				"board_top":
					target = "top"
				"frame":
					target = "frame"
			instance.set_surface_override_material(surface, wood_material(target))


# ---------------------------------------------------------------------- Brett


func _build_board() -> void:
	var path := MODELS % "board"
	if ResourceLoader.exists(path):
		_board_node = (load(path) as PackedScene).instantiate() as Node3D
		_board_node.name = "Board"
		add_child(_board_node)
		_skin(_board_node, "frame")
	else:
		var slab := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.95, 0.03, 0.95)
		slab.mesh = box
		slab.position.y = 0.015
		slab.material_override = wood_material("top")
		add_child(slab)
		_board_node = slab


func _build_coords() -> void:
	_coords = Node3D.new()
	_coords.name = "Coordinates"
	add_child(_coords)
	for i in 8:
		for side: int in [-1, 1]:
			var file_label := _coord_label("abcdefgh"[i])
			file_label.position = Vector3((i - 3.5) * SQUARE, TOP - 0.0002, side * 0.448)
			_coords.add_child(file_label)
			var rank_label := _coord_label(str(i + 1))
			rank_label.position = Vector3(side * 0.448, TOP - 0.0002, (3.5 - i) * SQUARE)
			_coords.add_child(rank_label)


func _coord_label(text: String) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.00032
	label.outline_size = 0
	label.modulate = Color("f2ddab")
	label.rotation.x = -PI * 0.5
	label.shaded = false
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return label


func set_coords_visible(value: bool) -> void:
	_coords.visible = value


static func square_center(sq: int) -> Vector3:
	return Vector3(((sq & 7) - 3.5) * SQUARE, TOP, (3.5 - float(sq >> 3)) * SQUARE)


## Feld unter einem Punkt (lokale Koordinaten des Bretts), -1 außerhalb.
static func square_at(local: Vector3) -> int:
	var f := int(floor(local.x / SQUARE + 4.0))
	var r := int(floor(4.0 - local.z / SQUARE))
	if f < 0 or f > 7 or r < 0 or r > 7:
		return -1
	return r * 8 + f


## Feld unter einem Bildschirmpunkt für die Kamera, -1 außerhalb.
func pick(camera: Camera3D, point: Vector2) -> int:
	var hit := ray_to_board(camera, point)
	return square_at(hit) if hit.is_finite() else -1


func ray_to_board(camera: Camera3D, point: Vector2) -> Vector3:
	var origin := to_local(camera.project_ray_origin(point))
	var dir := (global_basis.inverse() * camera.project_ray_normal(point)).normalized()
	if absf(dir.y) < 1e-5:
		return Vector3.INF
	var t := (TOP - origin.y) / dir.y
	if t < 0.0:
		return Vector3.INF
	return origin + dir * t


## Bildschirmpunkt eines Feldes (für Tests und Hinweise).
func screen_point(camera: Camera3D, sq: int) -> Vector2:
	return camera.unproject_position(to_global(square_center(sq)))


# -------------------------------------------------------------------- Figuren


func _mesh_scene(t: int) -> PackedScene:
	if not _meshes.has(t):
		var path := MODELS % NAMES[t]
		_meshes[t] = load(path) if ResourceLoader.exists(path) else null
	return _meshes[t]


func make_piece(piece: int) -> Node3D:
	var t := piece & 7
	var holder := Node3D.new()
	holder.name = "%s_%s" % ["w" if piece >> 3 == 0 else "b", NAMES[t]]
	var scene := _mesh_scene(t)
	var model: Node3D
	if scene != null:
		model = scene.instantiate() as Node3D
	else:
		model = MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.025
		capsule.height = 0.05 + t * 0.012
		(model as MeshInstance3D).mesh = capsule
		model.position.y = capsule.height * 0.5
	model.name = "Model"
	holder.add_child(model)
	_skin(model, "white" if piece >> 3 == 0 else "black")
	# Springer schauen zur Seite, damit ihr Pferdekopf im Profil zu sehen ist.
	if t == 2:
		model.rotation.y = -PI * 0.5 if piece >> 3 == 0 else PI * 0.5
	elif piece >> 3 == 1:
		model.rotation.y = PI
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * SHADOW_SIZE[t] * 1.5
	quad.orientation = PlaneMesh.FACE_Y
	shadow.mesh = quad
	shadow.material_override = wood_material("shadow")
	shadow.position.y = 0.0006
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(shadow)
	holder.set_meta("piece", piece)
	return holder


## Stellt das Brett genau nach `board` (64 Felder) auf; vorhandene Figuren
## bleiben stehen, wenn sie schon passen.
func show_board(board: PackedInt32Array) -> void:
	if is_instance_valid(_anim) and _anim.is_running():
		_anim.kill()
	_lifted = null
	_lift_from = -1
	for sq: int in pieces.keys():
		var node: Node3D = pieces[sq]
		if not is_instance_valid(node) or int(node.get_meta("piece")) != board[sq]:
			if is_instance_valid(node):
				node.queue_free()
			pieces.erase(sq)
	for sq in 64:
		if board[sq] == 0 or pieces.has(sq):
			if pieces.has(sq):
				(pieces[sq] as Node3D).position = square_center(sq)
				(pieces[sq] as Node3D).scale = Vector3.ONE
			continue
		var node := make_piece(board[sq])
		node.position = square_center(sq)
		add_child(node)
		pieces[sq] = node


## Spielt einen Zug als Bewegung: anheben, im Bogen ziehen, absetzen, geschlagene
## Figur sinkt weg. `board_after` ist das Brett nach dem Zug.
func animate_move(m: int, board_after: PackedInt32Array, seconds: float = 0.55) -> void:
	var from := m & 63
	var to := (m >> 6) & 63
	var flags := m >> 15
	var mover: Node3D = pieces.get(from)
	if _lift_from == from and is_instance_valid(_lifted):
		mover = _lifted
	_lifted = null
	_lift_from = -1
	if not is_instance_valid(mover) or reduced_motion:
		show_board(board_after)
		# Verzögert melden: Der Aufrufer wartet erst nach diesem Aufruf auf das
		# Signal (sonst hinge der Tisch bei „Animationen reduzieren“).
		move_animated.emit.call_deferred()
		return
	var victim_sq := to
	if flags & 4:
		victim_sq = to - 8 if (to >> 3) == 5 else to + 8
	var victim: Node3D = pieces.get(victim_sq)
	pieces.erase(from)
	pieces.erase(victim_sq)
	var duration := seconds / maxf(time_scale, 0.01)
	if is_instance_valid(_anim) and _anim.is_running():
		_anim.kill()
	_anim = create_tween()
	var start := mover.position
	var goal := square_center(to)
	var arc := 0.05 + 0.025 * start.distance_to(goal) / SQUARE
	_anim.tween_method(
		func(t: float) -> void:
			if is_instance_valid(mover):
				var p := start.lerp(goal, ease(t, -1.6))
				p.y = TOP + sin(t * PI) * arc
				mover.position = p,
		0.0,
		1.0,
		duration
	)
	if is_instance_valid(victim) and victim != mover:
		var sink := create_tween()
		sink.tween_interval(duration * 0.75)
		sink.tween_property(victim, "scale", Vector3.ONE * 0.01, duration * 0.4)
		sink.tween_callback(victim.queue_free)
	# Rochade: der Turm springt mit.
	if flags & 8:
		var rook_from := {6: 7, 2: 0, 62: 63, 58: 56}.get(to, -1) as int
		var rook_to := {6: 5, 2: 3, 62: 61, 58: 59}.get(to, -1) as int
		var rook: Node3D = pieces.get(rook_from)
		if is_instance_valid(rook):
			pieces.erase(rook_from)
			var hop := create_tween()
			hop.tween_property(rook, "position", square_center(rook_to), duration)
			pieces[rook_to] = rook
	pieces[to] = mover
	_anim.tween_callback(
		func() -> void:
			show_board(board_after)
			move_animated.emit()
	)


func is_animating() -> bool:
	return is_instance_valid(_anim) and _anim.is_running()


## Hebt eine Figur zum Ziehen an (Finger hält sie).
func lift(sq: int) -> void:
	var node: Node3D = pieces.get(sq)
	if not is_instance_valid(node):
		return
	_lifted = node
	_lift_from = sq
	node.position.y = TOP + 0.03


func drag_to(local: Vector3) -> void:
	if is_instance_valid(_lifted):
		_lifted.position = Vector3(
			clampf(local.x, -0.42, 0.42), TOP + 0.035, clampf(local.z, -0.42, 0.42)
		)


## Legt eine angehobene Figur zurück auf ihr Feld.
func drop_back() -> void:
	if is_instance_valid(_lifted):
		_lifted.position = square_center(_lift_from)
	_lifted = null
	_lift_from = -1


# ------------------------------------------------------- Leuchten und Sterne


## Leuchtende Felder. kind: "select" (gold), "move" (Punkte), "capture" (Ring),
## "hint" (grün pulsierend), "last" (zart), "danger" (rot), "show" (blau).
func set_glow(squares: Dictionary) -> void:
	for glow: MeshInstance3D in _glows:
		glow.queue_free()
	_glows.clear()
	for sq: int in squares:
		var kind := str(squares[sq])
		var mesh := MeshInstance3D.new()
		mesh.name = "Glow_%s_%d" % [kind, sq]
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.render_priority = 1
		var color := Color("ffd45a")
		var alpha := 0.5
		match kind:
			"move":
				var dot := CylinderMesh.new()
				dot.top_radius = 0.023
				dot.bottom_radius = 0.023
				dot.height = 0.001
				dot.radial_segments = 32
				mesh.mesh = dot
				# Kräftiges Grün: auf hellem Ahorn und dunklem Nussholz gut sichtbar.
				color = Color("3fcf78")
				alpha = 0.92
			"capture":
				var ring := TorusMesh.new()
				ring.inner_radius = 0.036
				ring.outer_radius = 0.046
				ring.rings = 32
				ring.ring_segments = 6
				mesh.mesh = ring
				mesh.scale = Vector3(1, 0.05, 1)
				color = Color("ff9a5a")
				alpha = 0.9
			_:
				var quad := QuadMesh.new()
				quad.size = Vector2.ONE * SQUARE * 0.96
				quad.orientation = PlaneMesh.FACE_Y
				mesh.mesh = quad
				match kind:
					"hint":
						color = Color("74f0a0")
						alpha = 0.6
						mesh.set_meta("pulse", true)
					"last":
						color = Color("ffe08a")
						alpha = 0.26
					"can":
						color = Color("ffd45a")
						alpha = 0.2
					"danger":
						color = Color("ff3b3b")
						alpha = 0.72
						mesh.set_meta("pulse", true)
					"show":
						color = Color("6fd3ff")
						alpha = 0.5
						mesh.set_meta("pulse", true)
					_:
						alpha = 0.5
		material.albedo_color = Color(color, alpha)
		mesh.set_meta("alpha", alpha)
		mesh.set_meta("square", sq)
		mesh.set_meta("kind", kind)
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position = square_center(sq) + Vector3(0, 0.0012, 0)
		_glow_root.add_child(mesh)
		_glows.append(mesh)


func glow_squares() -> Dictionary:
	var out := {}
	for glow: MeshInstance3D in _glows:
		out[int(glow.get_meta("square"))] = str(glow.get_meta("kind"))
	return out


## Sterne (zum Sammeln) und Mauern (Labyrinth) auf dem Brett.
func set_props(stars: Array, walls: Array) -> void:
	for child: Node in _prop_root.get_children():
		child.queue_free()
	var index := 0
	for sq: int in stars:
		var star := MeshInstance3D.new()
		star.name = "Star_%d" % sq
		star.mesh = _star_mesh()
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("ffd23f")
		material.emission_enabled = true
		material.emission = Color("ffb300")
		material.emission_energy_multiplier = 1.4
		material.roughness = 0.3
		material.metallic = 0.4
		star.material_override = material
		star.position = square_center(sq) + Vector3(0, 0.045, 0)
		star.set_meta("star", index)
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_prop_root.add_child(star)
		index += 1
	for sq: int in walls:
		var wall := MeshInstance3D.new()
		wall.name = "Wall_%d" % sq
		var box := BoxMesh.new()
		box.size = Vector3(SQUARE * 0.86, 0.04, SQUARE * 0.86)
		wall.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("b8a48c")
		material.roughness = 0.85
		wall.material_override = material
		wall.position = square_center(sq) + Vector3(0, 0.02, 0)
		_prop_root.add_child(wall)


func remove_star(sq: int) -> void:
	var star := _prop_root.get_node_or_null("Star_%d" % sq)
	if star != null:
		star.queue_free()


func _star_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer := 0.032
	var inner := 0.014
	var depth := 0.009
	var rim: Array[Vector3] = []
	for i in 10:
		var a := TAU * i / 10.0
		var r := outer if i % 2 == 0 else inner
		rim.append(Vector3(sin(a) * r, cos(a) * r, 0))
	for side: float in [1.0, -1.0]:
		var tip := Vector3(0, 0, depth * side)
		for i in 10:
			var a := rim[i]
			var b := rim[(i + 1) % 10]
			if side > 0:
				st.add_vertex(tip)
				st.add_vertex(b)
				st.add_vertex(a)
			else:
				st.add_vertex(tip)
				st.add_vertex(a)
				st.add_vertex(b)
	st.generate_normals()
	return st.commit()
