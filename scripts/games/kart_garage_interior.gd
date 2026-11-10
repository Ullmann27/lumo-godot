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

	_box(root, "GarageFloor", Vector3(16.0, 0.08, 16.0), Vector3(0.0, -0.38, 0.4),
		_mat(FLOOR, 0.72, 0.22, 0.0), true)
	_box(root, "GarageBackWall", Vector3(16.2, 6.2, 0.18), Vector3(0.0, 2.65, 4.35),
		_mat(WALL, 0.08, 0.82), true)
	_box(root, "GarageLeftWall", Vector3(0.18, 6.2, 12.0), Vector3(-5.7, 2.65, -0.4),
		_mat(WALL, 0.08, 0.82), true)
	_box(root, "GarageRightWall", Vector3(0.18, 6.2, 12.0), Vector3(5.7, 2.65, -0.4),
		_mat(WALL, 0.08, 0.82), true)
	if rich:
		_box(root, "GarageCeiling", Vector3(16.2, 0.12, 12.4), Vector3(0.0, 5.55, 0.2),
			_mat(WALL_TRIM, 0.04, 0.9), false)

	var sign_board := _box(root, "NeonLumoSignBoard", Vector3(3.6, 0.95, 0.08), Vector3(0.0, 2.48, 4.22),
		_emit(Color("102436"), CYAN, 0.35), false)
	var sign := Label3D.new()
	sign.name = "NeonLumoSign"
	sign.text = "LUMO"
	sign.font_size = 96
	sign.pixel_size = 0.014
	sign.modulate = CYAN
	sign.outline_modulate = Color("083044")
	sign.outline_size = 8
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.position = Vector3(0.0, 2.48, 4.16)
	sign.rotation.y = PI
	root.add_child(sign)
	var sign_light := OmniLight3D.new()
	sign_light.name = "NeonSignFill"
	sign_light.position = Vector3(0.0, 3.4, 3.4)
	sign_light.light_color = CYAN
	sign_light.light_energy = 0.55 if rich else 0.28
	sign_light.omni_range = 7.0
	sign_light.shadow_enabled = false
	root.add_child(sign_light)
	var cove := OmniLight3D.new()
	cove.name = "GarageCoveFill"
	cove.position = Vector3(0.0, 4.4, 0.8)
	cove.light_color = Color("9ec6ff")
	cove.light_energy = 0.42 if rich else 0.22
	cove.omni_range = 9.0
	cove.shadow_enabled = false
	root.add_child(cove)
	_box(root, "GarageWallTrim", Vector3(15.6, 0.12, 0.1), Vector3(0.0, 2.15, 4.24),
		_emit(Color("102436"), CYAN, 0.4), false)

	var hero := SpotLight3D.new()
	hero.name = "GarageHeroSpot"
	hero.position = Vector3(0.2, 4.6, -2.6)
	hero.light_color = Color("fff4de")
	hero.light_energy = 1.35 if rich else 0.85
	hero.spot_range = 10.0
	hero.spot_angle = 32.0
	hero.shadow_enabled = rich
	root.add_child(hero)
	hero.look_at(Vector3(0.0, 0.4, 0.0))

	if rich:
		_box(root, "ToolCabinet", Vector3(1.15, 1.7, 0.48), Vector3(-4.55, 0.5, 2.6),
			_mat(CONCRETE, 0.15, 0.55), true)
		_box(root, "ToolCabinetDoor", Vector3(0.08, 1.35, 0.42), Vector3(-3.95, 0.52, 2.6),
			_mat(STEEL, 0.55, 0.35), true)
		_cylinder(root, "TireStackLow", 0.38, 0.22, Vector3(4.45, -0.12, 2.35), _mat(Color("1b1f27"), 0.05, 0.7))
		_cylinder(root, "TireStackHigh", 0.38, 0.22, Vector3(4.45, 0.12, 2.35), _mat(Color("1b1f27"), 0.05, 0.7))
		_box(root, "Toolbox", Vector3(0.7, 0.32, 0.42), Vector3(-4.4, -0.05, 1.35),
			_mat(AMBER, 0.12, 0.46), true)
		_box(root, "WrenchHandle", Vector3(0.08, 0.08, 0.62), Vector3(-4.35, 0.22, 1.35),
			_mat(STEEL, 0.7, 0.28), false)
		_box(root, "ConeMarker", Vector3(0.22, 0.42, 0.22), Vector3(4.35, -0.1, 1.15),
			_mat(AMBER, 0.05, 0.5, 0.15), false)

	var turntable := MeshInstance3D.new()
	turntable.name = "GarageTurntable"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.85
	disc.bottom_radius = 1.92
	disc.height = 0.11
	disc.radial_segments = 32
	turntable.mesh = disc
	turntable.position = Vector3(0.0, -0.27, 0.0)
	turntable.material_override = _mat(Color("1a334c"), 0.82, 0.18, 0.08)
	turntable_parent.add_child(turntable)
	var lip := MeshInstance3D.new()
	lip.name = "GarageTurntableLip"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.86
	torus.outer_radius = 1.95
	torus.rings = 24
	torus.ring_segments = 8
	lip.mesh = torus
	lip.position = Vector3(0.0, -0.21, 0.0)
	lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lip.material_override = _emit(Color("12344a"), CYAN, 0.7)
	turntable_parent.add_child(lip)

	var buttons := {
		"start": _action_button(root, "start", "Start", Vector3(2.15, 1.18, -1.05), GOLD),
		"strecke": _action_button(root, "strecke", "Strecke", Vector3(2.15, 0.58, -1.05), CYAN),
		"kart": _action_button(root, "kart", "Kart anpassen", Vector3(-2.15, 1.18, -1.05), CYAN),
		"back": _action_button(root, "back", "Zurück", Vector3(-2.15, 0.58, -1.05), Color("9eb6d2")),
	}

	return {
		"root": root,
		"sign": sign,
		"sign_board": sign_board,
		"turntable": turntable,
		"hero": hero,
		"buttons": buttons,
		"rich": rich,
	}


static func set_button_state(button: Dictionary, state: String) -> void:
	if button.is_empty() or not is_instance_valid(button.get("panel")):
		return
	var glow: float = 0.55
	match state:
		"hover":
			glow = 1.15
		"press":
			glow = 1.7
		_:
			glow = 0.55
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
	panel.material_override = _emit(Color("102033"), color, 0.55)
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
	mesh.radial_segments = 16
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
