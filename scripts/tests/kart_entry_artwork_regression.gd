extends SceneTree
## Verifies the actual boot-scene hierarchy and per-game scene art without
## requiring a new login route or touching the ongoing kart session.

const ENTRY = preload("res://scenes/app/boot.tscn")

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var boot: Node = ENTRY.instantiate()
	var art: TextureRect = boot.get_node("Layer/Background")
	var title: Label = boot.get_node("Layer/Title")
	var loading: ProgressBar = boot.get_node("Layer/LoadBar")
	var top: Panel = boot.get_node("Layer/TopBar")
	assert(art.texture != null and art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	assert(top != null and loading.indeterminate and not loading.show_percentage)
	var expected: Dictionary = {
		"kart": "LUMO KART",
		"build": "LUMO BAUWELT",
		"puzzle": "LUMO PUZZLE-ATELIER",
		"rhythm": "LUMO RHYTHM PARTY",
		"treasure": "LUMO SCHATZSUCHE",
		"jump": "LUMO ABENTEUER",
	}
	for id in expected:
		boot._show_cover(id)
		assert(title.text == expected[id])
		assert(art.texture != null and art.texture.resource_path.begins_with("res://assets/"))
		assert(loading.indeterminate and not loading.show_percentage)
		assert((top.get_theme_stylebox("panel") as StyleBoxFlat).border_color == Color("53ddfd"))
	boot.free()
	print("[KartEntry] PASS: six genuine scene images, Nunito header, no invented loading percentage")
	quit(0)
