extends RefCounted
## Real 3D garage bay for the Kart menu preview. No race geometry, no save
## data, no track IDs. Props are original LUMO blocks, never branded copies.
## LOW keeps walls, floor, sign and turntable; HIGH adds tools and a ceiling.

const WALL := Color("243850")
const WALL_TRIM := Color("0e1a2c")
const FLOOR := Color("1b2a3c")
const CONCRETE := Color("2a3548")
const STEEL := Color("6d7c90")
const GOLD := Color("ffc14a")
const CYAN := Color("3ae0ff")
const AMBER := Color("ff9a3c")


static func build(stage: Node3D, turntable_parent: Node3D, profile: String = "high") -> Dictionary:
	var rich: bool = profile != "low"
	var root := Node3D.new()
	root.name = "GarageInterior3D"
	stage.add_child(root)
	# One material per surface family, shared by the whole bay. Metallic floors
	# without reflection probes turned black in GLES; retain a readable diffuse base.
	var materials := {
		"wall": _mat(Color("263d59"), 0.06, 0.82),
		"floor": _mat(Color("30465e"), 0.12, 0.58),
		"recess": _mat(Color("152a43"), 0.08, 0.76),
		"steel": _mat(Color("8195ab"), 0.58, 0.36),
		"ivory": _mat(Color("c4d5df"), 0.14, 0.46),
		"rubber": _mat(Color("192330"), 0.0, 0.88),
		"orange": _mat(AMBER, 0.10, 0.48),
		"podium": _mat(Color("28435e"), 0.42, 0.36),
		"cyan": _emit(Color("367285"), CYAN, 0.48),
		"warm": _emit(Color("d8b87b"), Color("ffe2a5"), 0.42),
	}
	_box(root, "GarageFloor", Vector3(16.0, 0.08, 16.0), Vector3(0.0, -0.38, 0.4),
		materials.floor, true)
	_box(root, "GarageBackWall", Vector3(16.2, 6.2, 0.18), Vector3(0.0, 2.65, 4.35),
		materials.wall, true)
	_box(root, "GarageLeftWall", Vector3(0.18, 6.2, 12.0), Vector3(-5.7, 2.65, -0.4),
		materials.wall, true)
	_box(root, "GarageRightWall", Vector3(0.18, 6.2, 12.0), Vector3(5.7, 2.65, -0.4),
		materials.wall, true)

	# Structural depth is visible from the production preview camera, including
	# the low tier. Repeated ribs, seams and strips are instanced draw batches.
	_box(root, "ServiceBayInset", Vector3(6.4, 3.82, 0.10), Vector3(0.0, 1.57, 4.20),
		materials.recess, false)
	var frame_parts: Array[Transform3D] = []
	for x in [-3.34, 3.34]:
		frame_parts.append(_box_transform(Vector3(0.22, 3.88, 0.28), Vector3(x, 1.57, 4.03)))
	frame_parts.append(_box_transform(Vector3(6.9, 0.22, 0.28), Vector3(0, 3.59, 4.03)))
	_batch_boxes(root, "ServiceBayFrame", frame_parts, materials.ivory, true)
	var ribs: Array[Transform3D] = []
	for x in [-4.8, -4.0, -2.7, -1.8, -0.9, 0.9, 1.8, 2.7, 4.0, 4.8]:
		ribs.append(_box_transform(Vector3(0.065, 3.5, 0.11), Vector3(x, 1.5, 4.11)))
	_batch_boxes(root, "BayWallRibs", ribs, materials.steel, false)
	var seams: Array[Transform3D] = []
	for x in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		seams.append(_box_transform(Vector3(0.025, 0.008, 9.0), Vector3(x, -0.332, 0.3)))
	for z in [-3.6, -1.6, 0.4, 2.4, 4.4]:
		seams.append(_box_transform(Vector3(10.0, 0.008, 0.025), Vector3(0, -0.332, z)))
	_batch_boxes(root, "FloorPanelSeams", seams, materials.recess, false)
	var light_strips: Array[Transform3D] = []
	for x in [-3.12, 3.12]:
		light_strips.append(_box_transform(Vector3(0.045, 3.54, 0.035), Vector3(x, 1.57, 3.86)))
		light_strips.append(_box_transform(Vector3(0.045, 0.012, 4.0), Vector3(x, -0.324, -0.6)))
	light_strips.append(_box_transform(Vector3(6.25, 0.045, 0.035), Vector3(0, 3.36, 3.86)))
	_batch_boxes(root, "BayGuideLights", light_strips, materials.cyan, false)
	var warm_strips: Array[Transform3D] = []
	for x in [-2.25, 2.25]:
		warm_strips.append(_box_transform(Vector3(1.18, 0.06, 0.26), Vector3(x, 3.16, 3.79)))
	_batch_boxes(root, "BayWarmSoftboxes", warm_strips, materials.warm, false)

	var sign_board := _box(root, "NeonLumoSignBoard", Vector3(3.6, 0.88, 0.10), Vector3(0.0, 2.49, 3.97),
		materials.recess, false)
	var sign := Label3D.new()
	sign.name = "NeonLumoSign"
	sign.text = "LUMO"
	sign.font_size = 68
	sign.pixel_size = 0.012
	sign.modulate = Color("e6f8ff")
	sign.outline_modulate = Color("103e52")
	sign.outline_size = 4
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.position = Vector3(0.0, 2.58, 3.90)
	sign.rotation.y = PI
	root.add_child(sign)
	var motto := Label3D.new()
	motto.name = "ServiceBayMotto"
	motto.text = "DEIN KART. DEIN ABENTEUER."
	motto.font_size = 24
	motto.pixel_size = 0.009
	motto.modulate = Color("a5dce6")
	motto.outline_size = 2
	motto.position = Vector3(0.0, 2.14, 3.90)
	motto.rotation.y = PI
	root.add_child(motto)
	var sign_light := OmniLight3D.new()
	sign_light.name = "NeonSignFill"
	sign_light.position = Vector3(0.0, 3.4, 3.4)
	sign_light.light_color = Color("9bd7e5")
	sign_light.light_energy = 0.45 if rich else 0.28
	sign_light.omni_range = 7.0
	sign_light.light_specular = 0.18
	sign_light.shadow_enabled = false
	root.add_child(sign_light)
	var cove := OmniLight3D.new()
	cove.name = "GarageCoveFill"
	cove.position = Vector3(0.0, 3.6, 1.3)
	cove.light_color = Color("d4e5f1")
	cove.light_energy = 0.65 if rich else 0.40
	cove.light_specular = 0.20
	cove.omni_range = 9.0
	cove.shadow_enabled = false
	root.add_child(cove)
	_box(root, "GarageWallTrim", Vector3(15.6, 0.12, 0.1), Vector3(0.0, 0.05, 4.12),
		materials.ivory, false)

	var hero := SpotLight3D.new()
	hero.name = "GarageHeroSpot"
	hero.position = Vector3(0.2, 4.6, -2.6)
	hero.light_color = Color("fff4de")
	hero.light_energy = 1.15 if rich else 0.85
	hero.spot_range = 10.0
	hero.spot_angle = 32.0
	# The existing stage key already supplies contact shadows. A second shadow
	# pass from this fill added geometry cost without clarifying the car.
	hero.shadow_enabled = false
	root.add_child(hero)
	hero.look_at(Vector3(0.0, 0.4, 0.0))

	if rich:
		_box(root, "GarageCeiling", Vector3(16.2, 0.12, 12.4), Vector3(0.0, 5.55, 0.2),
			materials.recess, false)
		_box(root, "ToolCabinet", Vector3(1.35, 1.35, 0.65), Vector3(-3.95, 0.34, 2.68),
			materials.recess, true)
		_box(root, "ToolCabinetDoor", Vector3(1.21, 1.16, 0.06), Vector3(-3.95, 0.36, 2.30),
			materials.steel, true)
		var drawer_details: Array[Transform3D] = []
		for y in [-0.02, 0.25, 0.52, 0.79]:
			drawer_details.append(_box_transform(Vector3(1.08, 0.024, 0.07), Vector3(-3.95, y, 2.25)))
			drawer_details.append(_box_transform(Vector3(0.38, 0.046, 0.09), Vector3(-3.95, y + 0.11, 2.21)))
		_batch_boxes(root, "CabinetDrawerDetails", drawer_details, materials.ivory, false)
		_box(root, "CabinetWorktop", Vector3(1.49, 0.09, 0.78), Vector3(-3.95, 1.06, 2.63),
			materials.ivory, true)
		for i in range(3):
			var tire := MeshInstance3D.new()
			tire.name = "TireStack%d" % i
			var tire_mesh := TorusMesh.new()
			tire_mesh.inner_radius = 0.24
			tire_mesh.outer_radius = 0.48
			tire_mesh.rings = 20
			tire_mesh.ring_segments = 8
			tire.mesh = tire_mesh
			tire.position = Vector3(3.90, -0.18 + i * 0.24, 2.64)
			tire.material_override = materials.rubber
			root.add_child(tire)
		_box(root, "Toolbox", Vector3(0.64, 0.30, 0.40), Vector3(-3.91, 1.25, 2.65),
			materials.orange, true)
		_box(root, "ToolboxHandle", Vector3(0.28, 0.075, 0.085), Vector3(-3.91, 1.43, 2.65),
			materials.steel, false)

	var turntable := _cylinder(turntable_parent, "GarageTurntable", 1.85, 0.11,
		Vector3(0.0, -0.27, 0.0), materials.podium)
	var plinth := _cylinder(turntable_parent, "GarageTurntablePlinth", 1.95, 0.08,
		Vector3(0.0, -0.32, 0.0), materials.recess)
	plinth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lip := MeshInstance3D.new()
	lip.name = "GarageTurntableLip"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.86
	torus.outer_radius = 1.92
	torus.rings = 48
	torus.ring_segments = 6
	lip.mesh = torus
	lip.position = Vector3(0.0, -0.21, 0.0)
	lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lip.material_override = materials.cyan
	turntable_parent.add_child(lip)
	var markers: Array[Transform3D] = []
	for i in range(16):
		var angle: float = TAU * i / 16.0
		var transform := _box_transform(Vector3(0.055, 0.012, 0.16),
			Vector3(sin(angle) * 1.73, -0.206, cos(angle) * 1.73))
		transform.basis = Basis(Vector3.UP, angle).scaled(Vector3(0.055, 0.012, 0.16))
		markers.append(transform)
	_batch_boxes(turntable_parent, "TurntableGuideMarks", markers, materials.ivory, false)

	var buttons := {
		"start": _action_button(root, "start", "Weiter", Vector3(2.15, 1.42, -1.05), GOLD),
		"strecke": _action_button(root, "strecke", "Strecke", Vector3(2.15, 0.52, -1.05), CYAN),
		"kart": _action_button(root, "kart", "Kart anpassen", Vector3(-2.15, 1.42, -1.05), CYAN),
		"back": _action_button(root, "back", "Zurück", Vector3(-2.15, 0.52, -1.05), Color("c4d5df")),
	}
	root.set_meta("garage_material_families", materials.size())
	return {"root": root, "sign": sign, "sign_board": sign_board, "turntable": turntable,
		"hero": hero, "buttons": buttons, "rich": rich, "materials": materials}


static func _box_transform(size: Vector3, position: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY.scaled(size), position)


static func _batch_boxes(parent: Node3D, batch_name: String, transforms: Array[Transform3D], material: Material, shadows: bool) -> void:
	var batch := MultiMeshInstance3D.new()
	batch.name = batch_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for index in range(transforms.size()):
		instances.set_instance_transform(index, transforms[index])
	batch.multimesh = instances
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(batch)


static func set_button_state(button: Dictionary, state: String) -> void:
	if button.is_empty() or not is_instance_valid(button.get("panel")):
		return
	var glow: float = 0.12
	match state:
		"hover":
			glow = 0.42
		"press":
			glow = 0.65
		_:
			glow = 0.12
	var material: StandardMaterial3D = button.panel.material_override
	if material:
		material.emission_energy_multiplier = glow
	if is_instance_valid(button.get("label")):
		button.label.modulate = Color.WHITE.lerp(button.color, 0.35 if state == "idle" else 0.05)


static func _action_button(parent: Node3D, id: String, title: String, pos: Vector3, color: Color) -> Dictionary:
	var body := StaticBody3D.new()
	body.name = "Garage3DButton_" + id
	body.position = pos
	body.rotation.y = PI
	body.set_meta("garage_action", id)
	parent.add_child(body)
	var panel := MeshInstance3D.new()
	panel.name = "Panel"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.15, 0.48, 0.08)
	panel.mesh = mesh
	panel.material_override = _emit(Color("102033"), color, 0.12)
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(panel)
	var stem := MeshInstance3D.new()
	stem.name = "Stem"
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.06
	stem_mesh.bottom_radius = 0.08
	stem_mesh.height = maxf(0.2, pos.y)
	stem.mesh = stem_mesh
	stem.position = Vector3(0.0, -pos.y * 0.5, 0.0)
	stem.material_override = _mat(STEEL, 0.55, 0.4)
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(stem)
	var label := Label3D.new()
	label.name = "Label"
	label.text = title
	label.font_size = 42
	label.pixel_size = 0.011
	label.position = Vector3(0.0, 0.0, 0.055)
	label.modulate = color
	label.outline_size = 6
	label.outline_modulate = Color("061018")
	body.add_child(label)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 0.52, 0.16)
	collision.shape = shape
	body.add_child(collision)
	return {"id": id, "body": body, "panel": panel, "label": label, "color": color, "state": "idle"}


static func _box(parent: Node3D, mesh_name: String, size: Vector3, pos: Vector3, material: Material, shadows: bool) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = mesh_name
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = pos
	item.material_override = material
	item.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	parent.add_child(item)
	return item


static func _cylinder(parent: Node3D, mesh_name: String, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = mesh_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	item.mesh = mesh
	item.position = pos
	item.material_override = material
	parent.add_child(item)
	return item


static func _mat(color: Color, metal: float, rough: float, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = rough
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


static func _emit(albedo: Color, glow: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.15
	material.roughness = 0.38
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = energy
	return material
