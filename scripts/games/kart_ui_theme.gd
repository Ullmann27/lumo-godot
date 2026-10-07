extends RefCounted
## Exact static Nunito cuts from the Flutter app, rather than an inferred axis.
const BODY = preload("res://assets/fonts/Nunito-Bold.ttf")
const HEADING = preload("res://assets/fonts/Nunito-Black.ttf")


static func create() -> Theme:
	var result := Theme.new()
	result.default_font = BODY
	result.default_font_size = 22
	result.set_font("font", "Button", BODY)
	result.set_font("font", "Label", BODY)
	result.set_color("font_color", "Label", Color("f7fbff"))
	result.set_color("font_color", "Button", Color("f7fbff"))
	return result
