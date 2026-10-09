extends SceneTree
## Assigned profile-state regression; not another mandatory native race entrypoint.

const TUNING = preload("res://scripts/games/kart_tuning.gd")
const PROGRESS_PATH: String = "user://progress.cfg"
const CHILD_A: String = "progress_profile_test_A"
const CHILD_B: String = "progress_profile_test_B"
var checks: Array[Dictionary] = []
var progress_script
var bridge
var fake_host: Node


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks.append({"name": label, "ok": ok})


func _host(child: Variant, stars: int, lifetime: Variant = null) -> void:
	bridge._host = fake_host
	var options: Dictionary = {"stars": stars}
	if child != null:
		options["childKey"] = child
	if lifetime != null:
		options["lifetimeStars"] = lifetime
	bridge._options = bridge.validated_options(options)


func _fresh_progress():
	var progress = progress_script.new()
	progress._load()
	progress.synchronize_host_wallet()
	return progress


func _run() -> void:
	await process_frame
	bridge = root.get_node("HostBridge")
	var previous_host: Object = bridge._host
	var previous_options: Dictionary = bridge._options.duplicate(true)
	var had_progress: bool = FileAccess.file_exists(PROGRESS_PATH)
	var previous_progress: PackedByteArray = (
		FileAccess.get_file_as_bytes(PROGRESS_PATH) if had_progress else PackedByteArray()
	)
	var workshop_backups: Dictionary = {}
	for child in [CHILD_A, CHILD_B]:
		var path: String = TUNING.path_for(child)
		if FileAccess.file_exists(path):
			workshop_backups[path] = FileAccess.get_file_as_bytes(path)
		DirAccess.remove_absolute(path)
	if had_progress:
		DirAccess.remove_absolute(PROGRESS_PATH)
	progress_script = load("res://scripts/systems/progress_store.gd")
	fake_host = Node.new()
	root.add_child(fake_host)
	_host(CHILD_A, 120, 120)
	var progress = _fresh_progress()
	var shop_a = TUNING.new(CHILD_A, progress.lifetime_stars())
	shop_a.save()
	_check(progress.total_stars() == 120, "A wallet120")
	_check(shop_a.available() == 120, "A budget120")
	_host(CHILD_B, 0, 0)
	progress.synchronize_host_wallet()
	var shop_b = TUNING.new(CHILD_B, progress.lifetime_stars())
	_check(progress.total_stars() == 0, "B wallet0")
	_check(progress.lifetime_stars() == 0, "B own lifetime0")
	_check(shop_b.available() == 0, "B own budget0")
	_check(not shop_b.can_upgrade("comet", "motor"), "B cannot afford4")
	_check(not shop_b.upgrade("comet", "motor"), "B purchase refuses4")
	var reloaded = _fresh_progress()
	var reloaded_b = TUNING.new(CHILD_B, reloaded.lifetime_stars())
	_check(reloaded.lifetime_stars() == 0, "B lifetime0 survives reload")
	_check(reloaded_b.available() == 0, "B budget0 survives reload")
	reloaded.free()
	_host(CHILD_A, 2, 120)
	progress.synchronize_host_wallet()
	_check(progress.total_stars() == 2, "A spendable wallet follows host2")
	_check(progress.lifetime_stars() == 120, "A lifetime120 survives spending")
	progress.add_stars(3)
	_check(progress.total_stars() == 5, "A actual reward adds3 to wallet")
	_check(progress.lifetime_stars() == 123, "A actual reward adds3 to own lifetime")
	progress.add_stars(0)
	progress.add_stars(-1)
	_check(progress.lifetime_stars() == 123, "Nonpositive rewards change nothing")
	_host(CHILD_B, 0)
	progress.synchronize_host_wallet()
	_check(progress.lifetime_stars() == 0, "Keyed old host without lifetime never borrows A")
	progress.add_stars(4)
	_check(progress.lifetime_stars() == 4, "B own earned4")
	_host(CHILD_A, 0)
	progress.synchronize_host_wallet()
	_check(progress.lifetime_stars() == 123, "A return preserves own earned123")
	reloaded = _fresh_progress()
	_check(reloaded.lifetime_stars() == 123, "A own123 persists")
	reloaded.free()
	_host(null, 0)
	progress.synchronize_host_wallet()
	_check(progress.lifetime_stars() == 123, "No-key old host keeps legacy high-water")
	bridge._host = null
	progress.synchronize_host_wallet()
	_check(progress.lifetime_stars() == 123, "Standalone keeps legacy high-water")
	progress.free()
	var config := ConfigFile.new()
	config.set_value("progress", "stars", 0)
	config.set_value("progress", "lifetime", 77)
	config.set_value(
		"progress", "lifetime_by_child", {CHILD_A: 12, CHILD_B: true, "": 99, "negative": -3}
	)
	config.save(PROGRESS_PATH)
	_host(CHILD_A, 0, 0)
	progress = _fresh_progress()
	_check(progress.lifetime_stars() == 12, "Valid own saved integer12 restores")
	_host(CHILD_B, 0, 0)
	progress.synchronize_host_wallet()
	_check(progress.lifetime_stars() == 0, "Bool saved lifetime rejected")
	_host("negative", 0, 0)
	progress.synchronize_host_wallet()
	_check(progress.lifetime_stars() == 0, "Negative saved lifetime rejected")
	_host(null, 0)
	progress.synchronize_host_wallet()
	_check(progress.lifetime_stars() == 77, "Invalid keyed rows preserve legacy scalar77")
	progress.free()
	bridge._host = previous_host
	bridge._options = previous_options
	fake_host.free()
	if had_progress:
		var file := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
		file.store_buffer(previous_progress)
		file.close()
	else:
		DirAccess.remove_absolute(PROGRESS_PATH)
	for child in [CHILD_A, CHILD_B]:
		var path: String = TUNING.path_for(child)
		if workshop_backups.has(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(workshop_backups[path])
			file.close()
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var failures := 0
	for check in checks:
		if not check.ok:
			failures += 1
	var output := "res://exports/profile-lifetime-evidence.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(
		(
			JSON.stringify(
				{"checks": checks, "check_count": checks.size(), "failure_count": failures}, "\t"
			)
			+ "\n"
		)
	)
	file.close()
	print("[ProgressProfileLifetime] checks=%d failures=%d" % [checks.size(), failures])
	quit(0 if failures == 0 else 1)
