extends RefCounted
## Gemeinsame Bühne für Garage und Werkstatt: dunkles Studio mit Himmelsspiegelung für den
## Klarlack, Leuchtringen auf dem Podest, Randlicht in Türkis und weichem Glühen für Neon.
const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")


## Baut die Bühne unter `stage` und liefert Drehpunkt, Kamera und Podest zurück.
static func build(stage: Node3D, ring_color: Color = Color("45d9ef"), with_podium: bool = true) -> Dictionary:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	# Keine Sky-Ressource: Deren Spiegelungstexturen gibt der Kompatibilitäts-Renderer beim Freigeben
	# nicht zurück (GL-Leck beim Beenden). Umgebungslicht und Glanz kommen aus Farbe und Lichtern.
	settings.background_mode = Environment.BG_CANVAS
	settings.background_color = Color("0c1d36")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("3d6a9c")
	settings.ambient_light_energy = 0.55
	# Restrained grade keeps orange fur and the brown irises readable without clipping cyan.
	settings.adjustment_enabled = true
	settings.adjustment_contrast = 1.035
	settings.adjustment_saturation = 1.045
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true
	settings.glow_intensity = 0.75
	settings.glow_bloom = 0.08
	settings.glow_hdr_threshold = 0.9
	environment.environment = settings
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -32, 0)
	key.light_color = Color("fff4e4")
	key.light_energy = 1.05
	key.shadow_enabled = true
	stage.add_child(key)
	# Soft front fill is confined to the menu studio: it reveals Lumo\'s brow, iris,
	# cream muzzle and goggles from the new face inspection angle. No extra shadow map.
	var face_fill := OmniLight3D.new()
	face_fill.name = "LumoFaceFill"
	face_fill.position = Vector3(0.0, 2.30, -2.45)
	face_fill.light_color = Color("eaf4ff")
	face_fill.light_energy = 0.34
	face_fill.light_specular = 0.25
	face_fill.omni_range = 4.6
	face_fill.omni_attenuation = 1.5
	face_fill.shadow_enabled = false
	stage.add_child(face_fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.6, 2.4, 2.2)
	rim.light_color = Color("63dfff")
	rim.light_energy = 1.1
	rim.omni_range = 9.0
	stage.add_child(rim)
	var back := OmniLight3D.new()
	back.position = Vector3(2.8, 1.8, 2.6)
	back.light_color = Color("ff9a5c")
	back.light_energy = 0.55
	back.omni_range = 8.0
	stage.add_child(back)
	# MeshInstance3D allocates a renderer RID even without a mesh. Never create
	# an unparented placeholder when the transparent garage requests no podium.
	var podium: MeshInstance3D = null
	if with_podium:
		podium = MeshInstance3D.new()
		var podium_mesh := CylinderMesh.new()
		podium_mesh.top_radius = 2.05
		podium_mesh.bottom_radius = 2.12
		podium_mesh.height = 0.2
		podium_mesh.radial_segments = 64
		podium.mesh = podium_mesh
		podium.position.y = -0.14
		var podium_material := StandardMaterial3D.new()
		podium_material.albedo_color = Color("102a46")
		podium_material.metallic = 0.75
		podium_material.roughness = 0.28
		podium.material_override = podium_material
		stage.add_child(podium)
		for radius in [2.08, 2.34, 2.62]:
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = radius
			torus.outer_radius = radius + 0.032
			torus.rings = 64
			ring.mesh = torus
			ring.position.y = -0.05 if radius < 2.5 else -0.07
			var light_material := StandardMaterial3D.new()
			light_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			light_material.albedo_color = ring_color.lerp(Color.WHITE, 0.15)
			light_material.emission_enabled = true
			light_material.emission = ring_color
			light_material.emission_energy_multiplier = 1.6 if radius < 2.5 else 0.9
			ring.material_override = light_material
			stage.add_child(ring)
		for index in range(10):
			var star := MeshInstance3D.new()
			star.mesh = SHAPES.star()
			star.scale = Vector3.ONE * (0.03 + index % 3 * 0.014)
			star.position = Vector3(sin(index * 2.4) * 2.6, 0.7 + index % 4 * 0.5, cos(index * 2.4) * 2.1)
			var star_material := StandardMaterial3D.new()
			star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			star_material.albedo_color = Color("c9ecff")
			star_material.emission_enabled = true
			star_material.emission = Color("9adcff")
			star_material.emission_energy_multiplier = 1.3
			star.material_override = star_material
			stage.add_child(star)
	var camera := Camera3D.new()
	camera.fov = 37
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(3.2, 2.2, -4.5), Vector3(0, 0.85, 0))
	var pivot := Node3D.new()
	stage.add_child(pivot)
	return {"pivot": pivot, "camera": camera, "podium": podium, "key": key, "rim": rim, "face_fill": face_fill}
