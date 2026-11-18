extends RefCounted
## Gemeinsame Hilfen der Einführungs-Tests: echte Touch-Eingaben auf Bedienelemente,
## Ablage je Kind leeren und die Pflichtprüfungen zählen.

const GUIDE_PATH := "res://scripts/systems/first_run_guide.gd"
static var guide_script: Script

var tree: SceneTree
var checks: int = 0
var label: String = "Guide"


func _init(scene_tree: SceneTree, name: String) -> void:
	guide_script = load(GUIDE_PATH)
	tree = scene_tree
	label = name


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error("[%s] FAIL: %s" % [label, message])
		print("[%s] FAIL: %s" % [label, message])
		tree.quit(1)
	assert(ok, message)


static func reset_child(child: String) -> void:
	var path: String = guide_script.store_path(child)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func automatic_mode() -> void:
	SceneRouter.launch_options.erase("firstRunGuide")


static func use_child(child: String) -> void:
	SceneRouter.launch_options["childKey"] = child
	SceneRouter.launch_options["firstRunGuide"] = "force"


func touch(at: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	_send(event)


func drag(at: Vector2, relative: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = relative
	_send(event)


## Wie ein echter Finger: über Input (inkl. Maus-Nachbildung für normale Buttons),
## Koordinaten vom Bild in Fensterpixel umgerechnet.
func _send(event: InputEvent) -> void:
	var to_window: Transform2D = tree.root.get_final_transform()
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		event.position = to_window * event.position
	if event is InputEventScreenDrag:
		event.relative = to_window.basis_xform(event.relative)
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## Finger auf die Mitte eines Bedienelements legen (bleibt liegen bis release()).
func press(control: Control, index: int = 0) -> Vector2:
	var centre: Vector2 = control.get_global_rect().get_center()
	touch(centre, true, index)
	return centre


func release(at: Vector2, index: int = 0) -> void:
	touch(at, false, index)


## Prüft, dass das Zeigerziel existiert, sichtbar ist und im Bild liegt.
func check_target(guide, expected: Control, step: String) -> void:
	var rect: Rect2 = guide.target_rect()
	var view: Rect2 = tree.root.get_visible_rect()
	check(rect.has_area(), "%s: Zeigerziel hat eine Fläche" % step)
	check(
		view.grow(2.0).encloses(rect), "%s: Zeigerziel liegt im Bild %s in %s" % [step, rect, view]
	)
	if expected != null:
		check(expected.is_visible_in_tree(), "%s: Ziel-Element ist sichtbar" % step)
		check(
			rect.is_equal_approx(expected.get_global_rect()),
			"%s: Zeiger liegt auf dem echten Element" % step
		)


## Skip- und Wiederholen-Knopf sind mindestens 126 Bildschirmpixel groß.
func check_touch_size(guide, button: Control, what: String) -> void:
	var pixels: float = minf(button.size.x, button.size.y) * guide.pixels_per_unit()
	check(pixels >= 125.5, "%s ist %.0f px groß (≥126)" % [what, pixels])


func frames(count: int) -> void:
	for _frame in range(count):
		await tree.process_frame
