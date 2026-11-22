extends SceneTree
## Headless asset contract: the Lab-English animal words must resolve to
## real, distinct meshes and must not reuse the generic text card.
const GALLERY = preload("res://scripts/learning/english_object_gallery.gd")
const VOCABULARY = preload("res://scripts/learning/english_vocabulary.gd")

func _initialize() -> void:
	var expected := {"cat": "Katze", "dog": "Hund", "bird": "Vogel", "lion":"Löwe", "sheep":"Schaf", "cow":"Kuh"}
	for word in expected:
		assert(VOCABULARY.ENTRIES.has(word))
		var payload := VOCABULARY.checked_payload({
			"kind": "english_objects",
			"word": word,
			"meaning": expected[word],
			"objects": [word, "book", "ruler"],
		})
		assert(not payload.is_empty())
		var model := GALLERY.make(word, 0)
		assert(model != null)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		if word in ["lion", "sheep", "cow"]:
			assert(not model.get_node("RecognizableObject").find_children("*", "MeshInstance3D", true, false).is_empty())
		else:
			assert(meshes.size() >= 12)
		assert(model.get_node_or_null("ObjectTouchBody/CollisionShape3D") != null)
		model.free()
	quit(0)
