extends SceneTree
## Lumo is always the real rigged figure. The sculpted stand-in fox is only the
## loading fallback and must not be what a child sees in the intro, as ghost or
## as rival.

const INTRO = preload("res://scripts/games/kart_intro.gd")
const SITES: Dictionary = {
	"res://scripts/games/kart_intro.gd": 1,
	"res://scripts/games/kart_island.gd": 3,
	"res://scripts/games/kart_garage_menu.gd": 1,
	"res://scripts/games/kart_workshop.gd": 1,
	"res://scripts/app/app_boot.gd": 1,
}
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[KartRealLumo] " + message)


func _run() -> void:
	# Every place that builds a kart which can carry the fox switches the real Lumo on.
	for path in SITES:
		var source: String = FileAccess.get_file_as_string(path)
		var built: int = source.count("VEHICLE.new()") + source.count("kart_vehicle.gd\").new()")
		var enabled: int = source.count("set_animated_lumo_enabled(")
		_check(built >= 1, path + " builds a kart")
		_check(enabled >= int(SITES[path]), "%s enables the real Lumo for each of its %d karts" % [path, int(SITES[path])])
	var intro = INTRO.new()
	root.add_child(intro)
	for frame in range(4):
		await process_frame
	var kart = intro.kart
	_check(is_instance_valid(kart), "the intro builds its kart")
	if is_instance_valid(kart):
		_check(is_instance_valid(kart.lumo_animation), "the intro kart carries the real rigged Lumo")
		_check(is_instance_valid(kart.driver) and not kart.driver.visible, "the stand-in fox is hidden in the intro")
	intro.queue_free()
	await process_frame
	if failures.is_empty():
		print("[KartRealLumo] PASS: %d checks; intro, ghost, rivals, garage, workshop and boot hero use the real Lumo" % checks)
	else:
		print("[KartRealLumo] FAIL: %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
