extends Node3D

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b9dceb")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.35
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 0.6
	add_child(sun)
	var lumo = load("res://scenes/characters/lumo/lumo_character.tscn").instantiate()
	add_child(lumo)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.1, 4.8)
	add_child(camera)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		safe.add_theme_constant_override("margin_" + side, 28)
	layer.add_child(safe)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	safe.add_child(column)
	column.add_child(_button("‹ Zur 3D-Welt", func(): SceneRouter.goto("home")))
	column.add_child(_label("Lumos 3D-Abenteuer", 32))
	column.add_child(_label("Wähle dein Spiel. An den Lernstopps wartet Lumo auf dich.", 23))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(_label("Welche Klasse und welches Fach?", 22))
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 16)
	column.add_child(choices)
	var grade := OptionButton.new()
	grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grade.custom_minimum_size.y = 64
	grade.add_theme_font_size_override("font_size", 23)
	for value in range(1, 5):
		grade.add_item("%d. Klasse" % value, value)
	grade.selected = clampi(int(SceneRouter.launch_options.get("grade", 1)) - 1, 0, 3)
	choices.add_child(grade)
	var subject := OptionButton.new()
	subject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subject.custom_minimum_size.y = 64
	subject.add_theme_font_size_override("font_size", 23)
	subject.add_item("Mathematik")
	subject.add_item("Deutsch")
	subject.selected = 1 if SceneRouter.launch_options.get("subject", "") == "Deutsch" else 0
	choices.add_child(subject)
	var launch := func(scene: String):
		SceneRouter.launch_options = {"grade": grade.selected + 1, "subject": "Deutsch" if subject.selected == 1 else "Mathematik"}
		SceneRouter.goto(scene)
	column.add_child(_button("Insel-Cup · Kart fahren", func(): launch.call("kart")))
	column.add_child(_button("Wolkeninseln · Springen", func(): launch.call("jump")))
	column.add_child(_button("Sterne in der 3D-Welt sammeln", func(): launch.call("stars")))

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("343457"))
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 74
	button.add_theme_font_size_override("font_size", 24)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("7264e8")
	style.set_corner_radius_all(16)
	style.set_content_margin_all(18)
	button.add_theme_stylebox_override("normal", style)
	var pressed: StyleBoxFlat = style.duplicate()
	pressed.bg_color = Color("9184f1")
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", pressed)
	button.pressed.connect(action)
	return button
