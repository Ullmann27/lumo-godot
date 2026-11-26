## Standalone native parent settings. Flutter has its own parent area.
extends Node

@onready var panel: ScrollContainer = %Settings
@onready var column: VBoxContainer = %Contents
@onready var quality: OptionButton = %Quality
@onready var sound: Button = %Sound
@onready var back: Button = %Back

func _ready() -> void:
	for choice in LumoQuality.GRAPHICS_CHOICES:
		if choice == "ultra" and PerformanceManager.software_rendered_mobile():
			continue
		quality.add_item(LumoQuality.GRAPHICS_LABELS[choice])
		quality.set_item_metadata(quality.item_count - 1, choice)
	quality.item_selected.connect(_select_quality)
	EventBus.quality_profile_changed.connect(_refresh_quality)
	sound.pressed.connect(_toggle_sound)
	back.pressed.connect(func(): SceneRouter.goto("home"))
	get_viewport().size_changed.connect(_layout)
	MobileRuntime.safe_area_changed.connect(_layout)
	_refresh_quality("")
	_refresh_sound()
	_layout()

func _select_quality(index: int) -> void:
	LumoQuality.set_graphics_choice(str(quality.get_item_metadata(index)))

func _refresh_quality(_tier: String) -> void:
	var active := LumoQuality.graphics_choice()
	for i in quality.item_count:
		if quality.get_item_metadata(i) == active:
			quality.select(i)
			return

func _toggle_sound() -> void:
	AudioManager.set_muted(not AudioManager.is_muted())
	_refresh_sound()

func _refresh_sound() -> void:
	sound.set_pressed_no_signal(not AudioManager.is_muted())
	sound.text = "Ton eingeschaltet" if sound.button_pressed else "Ton ausgeschaltet"

func _layout() -> void:
	var viewport := get_viewport()
	var space := viewport.get_visible_rect().size
	var scale_factor := maxf(0.01, float(viewport.get_window().size.x) / maxf(1.0, space.x))
	var dp := MobileRuntime.get_ui_density() / scale_factor
	var edges := MobileRuntime.get_safe_area_insets()
	var left := edges.position.x / scale_factor + 16.0 * dp
	var right := space.x - edges.size.x / scale_factor - 16.0 * dp
	var width := maxf(1.0, minf(right - left, 460.0 * dp))
	panel.offset_left = (left + right - width) * 0.5
	panel.offset_right = panel.offset_left + width
	panel.offset_top = edges.position.y / scale_factor + 16.0 * dp
	panel.offset_bottom = -edges.size.y / scale_factor - 16.0 * dp
	column.add_theme_constant_override("separation", roundi(12.0 * dp))
	%Title.add_theme_font_size_override("font_size", maxi(1, roundi(28.0 * dp)))
	%QualityLabel.add_theme_font_size_override("font_size", maxi(1, roundi(17.0 * dp)))
	for button: Button in [quality, sound, back]:
		button.custom_minimum_size.y = 52.0 * dp
		button.add_theme_font_size_override("font_size", maxi(1, roundi(18.0 * dp)))
	quality.get_popup().add_theme_font_size_override("font_size", maxi(1, roundi(18.0 * dp)))
	quality.get_popup().add_theme_constant_override("v_separation", maxi(1, roundi(24.0 * dp)))
