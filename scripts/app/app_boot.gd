## The existing Godot boot route with a themed real-image game entry.
## No invented percent, account registration or additional gameplay state.
extends Node

const UI = preload("res://scripts/games/kart_ui_theme.gd")
const COVER_BY_SCENE: Dictionary = {
	"kart": "res://assets/kart/menu/lumo-world.webp",
	"build": "res://assets/creative/sandstone.webp",
	"puzzle": "res://assets/creative/puzzle/candy.webp",
	"rhythm": "res://assets/creative/puzzle/volcano.webp",
	"treasure": "res://assets/creative/puzzle/moonlight.webp",
	"jump": "res://assets/kart/menu/lumo-world.webp",
}
const TITLE_BY_SCENE: Dictionary = {
	"kart": "LUMO KART",
	"build": "LUMO BAUWELT",
	"puzzle": "LUMO PUZZLE-ATELIER",
	"rhythm": "LUMO RHYTHM PARTY",
	"treasure": "LUMO SCHATZSUCHE",
	"jump": "LUMO ABENTEUER",
}


func _ready() -> void:
	EventBus.boot_started.emit()
	var options: Dictionary = {}
	if OS.has_feature("web"):
		var raw = JavaScriptBridge.eval(
			"JSON.stringify(Object.fromEntries(new URL(window.location.href).searchParams))"
		)
		var parsed = JSON.parse_string(str(raw))
		if parsed is Dictionary:
			options = parsed
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var pair = arg.trim_prefix("--").split("=", true, 1)
			options[pair[0]] = pair[1]
	# Embedded host identity wins; all original grade/profile options survive.
	if HostBridge.is_embedded():
		options.merge(HostBridge.launch_options(), true)
	SceneRouter.launch_options = options
	var requested: String = str(options.get("scene", ""))
	var target: String = requested if requested in [
		"kart", "jump", "puzzle", "build", "rhythm", "treasure", "home", "games"
	] else "games"
	_show_cover(target)
	get_viewport().size_changed.connect(_layout)
	_layout()
	# A single real render frame; never hold the child on a fake timer.
	await get_tree().process_frame
	SceneRouter.goto(target)


func _show_cover(scene_id: String) -> void:
	var cover: TextureRect = $Layer/Background
	var path: String = str(COVER_BY_SCENE.get(scene_id, "res://assets/kart/menu/lumo-world.webp"))
	cover.texture = load(path) as Texture2D
	var title: Label = $Layer/Title
	title.text = str(TITLE_BY_SCENE.get(scene_id, "LUMO SPIELEWELT"))
	title.add_theme_font_override("font", UI.HEADING)
	title.add_theme_color_override("font_color", Color("f7fbff"))
	var subtitle: Label = $Layer/Subtitle
	subtitle.text = "DEIN NÄCHSTES ABENTEUER"
	subtitle.add_theme_font_override("font", UI.BODY)
	subtitle.add_theme_color_override("font_color", Color("53ddfd"))
	var status: Label = $Layer/LoadingLabel
	status.text = "Spielwelt wird vorbereitet …"
	status.add_theme_font_override("font", UI.BODY)
	status.add_theme_color_override("font_color", Color("f7fbff"))
	var bar: ProgressBar = $Layer/LoadBar
	bar.indeterminate = true
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("20466a")
	background.set_corner_radius_all(12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("53ddfd")
	fill.set_corner_radius_all(12)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	var brand := StyleBoxFlat.new()
	brand.bg_color = Color(0.025, 0.145, 0.36, 0.90)
	brand.border_color = Color("53ddfd")
	brand.set_border_width_all(2)
	brand.set_corner_radius_all(19)
	($Layer/TopBar as Panel).add_theme_stylebox_override("panel", brand)
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.012, 0.09, 0.22, 0.90)
	glass.border_color = Color(0.32, 0.87, 1, 0.78)
	glass.set_border_width_all(2)
	glass.set_corner_radius_all(22)
	($Layer/BottomPanel as Panel).add_theme_stylebox_override("panel", glass)


func _layout() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	if size.x < 1 or size.y < 1:
		return
	var compact: bool = size.y < 410
	var margin: float = clampf(minf(size.x, size.y) * 0.035, 12.0, 32.0)
	var header_height: float = 56.0 if compact else 85.0
	var top: Panel = $Layer/TopBar
	top.position = Vector2(margin, margin)
	top.size = Vector2(size.x - margin * 2.0, header_height)
	var title: Label = $Layer/Title
	title.add_theme_font_size_override("font_size", 24 if compact else 34)
	title.position = top.position + Vector2(18, 3 if compact else 7)
	title.size = Vector2(top.size.x - 36, 40 if compact else 48)
	var subtitle: Label = $Layer/Subtitle
	subtitle.visible = not compact
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.position = top.position + Vector2(18, 51)
	subtitle.size = Vector2(top.size.x - 36, 25)
	var panel_height: float = 92.0 if compact else 132.0
	var bottom: Panel = $Layer/BottomPanel
	bottom.position = Vector2(margin, size.y - margin - panel_height)
	bottom.size = Vector2(size.x - margin * 2.0, panel_height)
	var label: Label = $Layer/LoadingLabel
	label.add_theme_font_size_override("font_size", 17 if compact else 23)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = bottom.position + Vector2(16, 11 if compact else 22)
	label.size = Vector2(bottom.size.x - 32, 32)
	var bar: ProgressBar = $Layer/LoadBar
	bar.position = bottom.position + Vector2(24, 53 if compact else 78)
	bar.size = Vector2(bottom.size.x - 48, 12)
