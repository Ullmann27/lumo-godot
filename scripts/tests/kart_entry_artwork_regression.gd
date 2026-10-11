extends SceneTree
## Verifies the actual boot-scene hierarchy and per-game scene art without
## requiring a new login route or touching the ongoing kart session.

# Resolve the scene after autoload initialization. --script compiles this
# harness before autoload names such as EventBus are available to scene scripts.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var boot: Node = load("res://scenes/app/boot.tscn").instantiate()
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
		assert(art.texture != null)
		var source_texture: Texture2D = art.texture.atlas if art.texture is AtlasTexture else art.texture
		assert(source_texture.resource_path == boot.COVER_BY_SCENE[id],
			"Every game retains its actual original illustration")
		if id in ["kart", "jump"]:
			assert(art.texture is AtlasTexture and art.texture.filter_clip
				and art.texture.region == Rect2(0, 0, 1066, 1904),
				"White source border is excluded without replacing the original")
		assert(loading.indeterminate and not loading.show_percentage)
		assert((top.get_theme_stylebox("panel") as StyleBoxFlat).border_color == Color("53ddfd"))
	boot.free()
	print("[KartEntry] PASS: six genuine scene images, Nunito header, no invented loading percentage")
	quit(0)
