extends SceneTree
## Guard the original Lumo garage studio's mobile-safe character lighting.
## The additional light is a deliberately weak, shadow-free face fill.
const STAGE = preload("res://scripts/games/kart_stage.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var stage: Dictionary = STAGE.build(world)
	assert(stage.has("face_fill"), "Garage stage must expose the real Lumo face light")
	var fill: OmniLight3D = stage.face_fill
	assert(fill.name == "LumoFaceFill")
	assert(fill.position.z < -2.0 and fill.position.y > 1.6)
	assert(fill.light_energy >= 0.20 and fill.light_energy <= 0.55)
	assert(fill.omni_range <= 5.0, "Face fill must not wash the entire stage")
	assert(fill.light_specular <= 0.30, "No blown-out goggles")
	assert(not fill.shadow_enabled, "No fourth dynamic shadow map on Android")
	var key: DirectionalLight3D = stage.key
	assert(key.shadow_enabled, "Existing studio key shadow remains")
	var camera: Camera3D = stage.camera
	assert(camera.fov >= 30.0 and camera.fov <= 45.0)
	var env_node: WorldEnvironment = world.get_child(0)
	var environment: Environment = env_node.environment
	assert(environment != null and environment.adjustment_enabled)
	assert(environment.adjustment_contrast >= 1.0 and environment.adjustment_contrast < 1.1)
	assert(environment.adjustment_saturation >= 1.0 and environment.adjustment_saturation < 1.1)
	assert(environment.reflected_light_source == Environment.REFLECTION_SOURCE_DISABLED)
	world.queue_free()
	await process_frame
	print("[LumoFaceStudio] PASS: real studio fill, bounded light cost, retained key, careful color grade")
	quit(0)
