extends SceneTree
## Real renderer captures of the production garage, selected components and
## the complete numerical comparison. Never substitutes a concept image.
const TUNING = preload("res://scripts/games/kart_tuning.gd")
const PARTS = preload("res://scripts/games/kart_part_catalog.gd")
const DYNO = preload("res://scripts/games/kart_dyno.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const CORNER: Dictionary = {
    "engine": "axial", "tires": "performance", "wing": "venturi",
    "booster": "kondensator", "suspension": "adaptiv", "steering": "vector",
    "brakes": "keramik", "gearbox": "doppelkupplung", "ballast": "carbon",
}
const JUMP: Dictionary = {
    "engine": "axial", "tires": "stollen", "wing": "gleiter",
    "booster": "kondensator", "suspension": "adaptiv", "steering": "flug",
    "brakes": "keramik", "gearbox": "gelaende", "ballast": "carbon",
}
var game
var output := ""
var shots: Array[Dictionary] = []
var failures: Array[String] = []


func _initialize() -> void:
    output = OS.get_environment("LUMO_KART_ACTION_PROOF_DIR")
    if output.is_empty():
        output = "user://kart-evolution-proof"
    call_deferred("_run")


func _frames(count: int = 8) -> void:
    for index in range(count):
        await process_frame



func _inspect_ui() -> Dictionary:
    var garage = game.garage
    var bay = garage.parts_bay
    var dp: float = garage._preview_dp_scale()
    var result := {"dp_scale": dp, "controls": []}
    if bay.is_open():
        var controls: Array[Control] = [bay.mount_button, bay.back_button, bay.category]
        for tile in bay.tiles.values():
            controls.append(tile)
        for control in controls:
            var dimensions := control.get_global_rect().size / dp
            result.controls.append({"name": str(control.name), "width_dp": dimensions.x, "height_dp": dimensions.y})
            if dimensions.x < 47.99 or dimensions.y < 47.99:
                failures.append("Touch target smaller than 48 dp: " + str(control.name))
        var popup: PopupMenu = bay.category.get_popup()
        var row_height: float = (popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size"))
            + popup.get_theme_constant("v_separation")) / dp
        result["category_row_height_dp"] = row_height
        if row_height < 47.99:
            failures.append("Category popup row smaller than 48 dp")
    else:
        var card = garage.find_child("KartCard_comet", true, false)
        if card == null:
            failures.append("Selected vehicle card missing")
        else:
            var factors: Dictionary = game.workshop.multipliers("comet")
            if card.performance_factors != factors:
                failures.append("Vehicle card does not use the mounted workshop configuration")
            var expected_speed := FLEET.NEUTRAL * float(factors.speed)
            var expected_turn := FLEET.NEUTRAL * float(factors.turn)
            if not is_equal_approx(float(card.bars.base.speed), expected_speed) or not is_equal_approx(
                float(card.bars.base.handling), expected_turn):
                failures.append("Vehicle card bars differ from actual driving factors")
            result["vehicle_card"] = {"factors": card.performance_factors,
                "bars": card.bars.base, "tooltip": card.tooltip_text}
    return result


func _shot(label: String, parts: Dictionary) -> void:
    await _frames(12)
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    var path := output.path_join(label + ".png")
    if image == null or image.is_empty() or image.save_png(path) != OK:
        failures.append("Unable to capture " + label)
        return
    var record := {"label": label, "png": path, "sha256": FileAccess.get_sha256(path),
        "size": [image.get_width(), image.get_height()], "parts": parts, "ui": _inspect_ui(),
        "dyno": DYNO.measure(game.workshop.multipliers_with("comet", parts))}
    image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
    var jpg := output.path_join(label + ".jpg")
    if image.save_jpg(jpg, 0.82) != OK:
        failures.append("Unable to save review JPEG " + label)
    else:
        record["review_jpg"] = jpg
    shots.append(record)
    print("[KartEvolutionCapture] ", path)


func _preview(parts: Dictionary) -> void:
    var bay = game.garage.parts_bay
    bay._on_open()
    for slot in PARTS.SLOTS:
        bay._on_slot(slot)
        bay._on_tile(str(parts.get(slot, "serie")))
        await _frames(2)
    bay._on_slot("engine")
    await _frames(8)
    if bay.dyno_values.size() != DYNO.METRICS.size():
        failures.append("Full twelve-metric comparison is missing")
    var expected := DYNO.measure(game.workshop.multipliers_with("comet", bay.pending))
    for metric in bay.dyno_values:
        if not is_equal_approx(float(bay.dyno_values[metric][1]), float(expected[metric])):
            failures.append("Preview differs from shared physics: " + metric)


func _mount() -> void:
    var bay = game.garage.parts_bay
    if bay._pending_price() > 0:
        bay._on_mount()
        await _frames(2)
    bay._on_mount()
    await _frames(12)


func _run() -> void:
    if DisplayServer.get_name() == "headless":
        print("[KartEvolutionCapture] FAIL: real renderer required")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(output)
    root.size = Vector2i(1280, 720)
    game = load("res://scenes/games/kart_island.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    await _frames(12)
    var workshop = TUNING.new("evolution_capture_only", 1000)
    workshop.save_enabled = false
    workshop.looks.clear()
    workshop.levels.clear()
    workshop.tunes.clear()
    workshop.owned.clear()
    game.workshop = workshop
    game.garage.workshop = workshop
    game._show_reference_landing(true)
    await _frames(8)
    game.reference_landing.mode_selected.emit("garage")
    await _frames(8)
    game.garage.stars = 1000
    game.garage.workshop = workshop
    game.garage.reduced_motion = true
    game.garage._select("kart", "comet")
    game.garage._choose_preview_view(0, false)
    await _frames(16)
    await _shot("vehicle-01-serie", {})
    await _preview(CORNER)
    await _shot("vehicle-02-comparison", CORNER)
    var bay = game.garage.parts_bay
    bay.body_scroll.scroll_vertical = int(bay.body_scroll.get_v_scroll_bar().max_value)
    await _shot("vehicle-03-comparison-details", CORNER)
    await _mount()
    await _shot("vehicle-04-corner-tech", CORNER)
    await _preview(JUMP)
    await _shot("vehicle-05-jump-preview", JUMP)
    await _mount()
    await _shot("vehicle-06-jump-rally", JUMP)
    var report := FileAccess.open(output.path_join("vehicle-evolution-capture.json"), FileAccess.WRITE)
    if report == null:
        failures.append("Capture report unavailable")
    else:
        report.store_string(JSON.stringify({"status": "PASS" if failures.is_empty() else "FAIL",
            "engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
            "captures": shots, "failures": failures, "source": "actual production garage and parts bay",
            "physical_android_fps_verified": false}, "  "))
        report.close()
    var freed: bool = await TEARDOWN.release_scene(self, game, "[KartEvolutionCapture]")
    if not freed:
        failures.append("Scene teardown failed")
    print("[KartEvolutionCapture] %s captures=%d" %
        ["PASS" if failures.is_empty() and shots.size() == 6 else "FAIL", shots.size()])
    quit(0 if failures.is_empty() and shots.size() == 6 else 1)
