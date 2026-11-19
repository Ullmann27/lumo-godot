extends SceneTree
## Rendert die Kopf-Porträts der Tischfiguren aus den vorhandenen 3D-Modellen.
## Die Bilder sind Vorlage für die Bildkarten des Sternendecks und die
## Namensschilder am Tisch. Aufruf (echter Renderer nötig):
##   xvfb-run -a -s '-screen 0 1280x1280x24' godot --path . \
##     --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://tools/cards/render_portraits.gd
const ACTOR = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const OUT := "res://tools/cards/portraits/"
const SIZE := 512
const RIVALS: Array[String] = ["lion", "owl", "rabbit", "squirrel", "turtle"]
## Highest point above the Head bone that still belongs to the portrait.
const HEAD_REACH := {"squirrel": 0.5}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Porträts brauchen einen echten Renderer")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(SIZE, SIZE)
	root.transparent_bg = true
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_CLEAR_COLOR
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("fff3e2")
	settings.ambient_light_energy = 0.62
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, 28, 0)
	key.light_color = Color("fff0d8")
	key.light_energy = 1.25
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, -150, 0)
	rim.light_color = Color("8ecbff")
	rim.light_energy = 0.7
	world.add_child(rim)
	var camera := Camera3D.new()
	camera.fov = 24
	world.add_child(camera)
	camera.current = true
	for id: String in RIVALS:
		var model: Node3D = (load("res://assets/kart/production/drivers/%s/driver.glb" % id) as PackedScene).instantiate()
		world.add_child(model)
		model.rotation.y = PI
		var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		player.play("kart_seated")
		player.seek(0.4, true)
		await _shoot(camera, _head_box(model, HEAD_REACH.get(id, 9.0)), id)
		model.queue_free()
		await process_frame
	var lumo := ACTOR.new()
	world.add_child(lumo)
	await process_frame
	lumo.play_behavior("idle")
	lumo.player.seek(0.3, true)
	await _shoot(camera, _head_box(lumo), "lumo")
	print("[CardsPortraits] PASS %d portraits in %s" % [RIVALS.size() + 1, OUT])
	quit(0)


## Kopfbereich: alles oberhalb des Halses, aus den echten Mesh-Grenzen.
func _head_box(model: Node3D, reach: float = 9.0) -> AABB:
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	skeleton.force_update_all_bone_transforms()
	var neck: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Neck")).origin)
	var head: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin)
	var top := neck.y
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		top = maxf(top, box.end.y)
	# The squirrel's tail rises above its ears: frame the head, not the tail.
	top = minf(top, head.y + reach)
	var height := top - neck.y
	return AABB(Vector3(head.x - height * 0.5, neck.y - height * 0.08, head.z), Vector3(height, height * 1.08, 0.0))


func _shoot(camera: Camera3D, box: AABB, id: String) -> void:
	var centre := box.position + box.size * 0.5
	var distance := (box.size.y * 0.5 * 1.12) / tan(deg_to_rad(camera.fov * 0.5))
	camera.position = centre + Vector3(distance * 0.26, distance * 0.10, distance)
	camera.look_at(centre)
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.save_png(OUT + id + ".png")
