extends "res://scripts/learning/learning_world.gd"
## Layout extension only. Original learning state, controls, input and fox stay
## in the existing base class; the production scene route does not change.
const WONDER_GARDEN = preload("res://scripts/learning/learning_wonder_garden.gd")


func _ready() -> void:
	super._ready()
	var atelier := get_node_or_null("LearningGardenAtelier") as Node3D
	if atelier == null:
		push_error("[LearningWonder] Production atelier is missing")
		return
	if atelier.get_node_or_null("LearningWonderGarden") == null:
		atelier.add_child(WONDER_GARDEN.new())


func _layout() -> void:
	super._layout()
	# The English gallery fits its actual object bounds in the base layout.
	# Garden framing must not shrink those interactive meshes afterwards.
	if activity.kind == "english_objects":
		return
	if not is_inside_tree() or not is_instance_valid(camera) or not is_instance_valid(header):
		return
	var dimensions := get_viewport().get_visible_rect().size
	if dimensions.x / maxf(1.0, dimensions.y) < 0.95:
		return
	# Keep the whole flower open/closed silhouette in the real free 3D area.
	# Portrait retains the reviewed base framing and its original touch sizes.
	var free_height := maxf(80.0, (footer.position.y - header.position.y - header.size.y) * ui.scale.x)
	camera.size = maxf(camera.size, 7.0 * dimensions.y / free_height)
	var content_mid := (header.position.y + header.size.y + footer.position.y) * 0.5 * ui.scale.x
	camera.v_offset = (content_mid / maxf(1.0, dimensions.y) - 0.5) * camera.size
