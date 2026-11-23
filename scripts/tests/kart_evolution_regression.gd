extends SceneTree
## Integration proof for the actual catalogue, model mounts and driving formulas.
## Factor envelopes cover every independent catalogue combination mathematically;
## sampled/pairwise combinations and real race ticks are reported separately.
const CATALOG = preload("res://scripts/games/kart_part_catalog.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const TUNING = preload("res://scripts/games/kart_tuning.gd")
const FINE = preload("res://scripts/games/kart_fine_tuning.gd")
const DYNO = preload("res://scripts/games/kart_dyno.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const GEOMETRY = preload("res://scripts/games/kart_evolution_geometry.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const NEW_PARTS: Dictionary = {
    "engine": "axial", "tires": "performance", "wing": "venturi",
    "booster": "kondensator", "suspension": "adaptiv", "steering": "vector",
    "brakes": "keramik", "gearbox": "doppelkupplung", "ballast": "carbon",
}
const CHILD := "evolution_regression_only"
const STEP := 1.0 / 60.0
var failures: Array[String] = []
var checks := 0
var sampled := 0
var pairwise := 0
var envelopes: Array[Dictionary] = []
var actual_drive: Array[Dictionary] = []
var single_part_results: Array[Dictionary] = []
var boundary_drive: Array[Dictionary] = []
var game
var output := ""


func _initialize() -> void:
    output = OS.get_environment("LUMO_KART_ACTION_PROOF_DIR")
    if output.is_empty():
        output = "user://kart-evolution-proof"
    call_deferred("_run")


func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        print("[KartEvolution] FAIL ", label)


func _bounded(factors: Dictionary, base: Dictionary, label: String) -> void:
    for key in CATALOG.PART_LIMITS:
        var range_values: Array = CATALOG.PART_LIMITS[key]
        var ratio := float(factors.get(key, 1.0)) / float(base.get(key, 1.0))
        _check(is_finite(ratio) and ratio >= float(range_values[0]) - 0.00001
            and ratio <= float(range_values[1]) + 0.00001, label + "/" + key)
    _check(float(factors.offroad) >= 0.20 and float(factors.offroad) <= 0.92, label + "/offroad")
    _check(float(factors.stability) >= 0.20 and float(factors.stability) <= 0.85, label + "/stability")


func _catalogue_and_combinations() -> void:
    var option_count := 0
    for slot in CATALOG.SLOTS:
        var ids: Array[String] = []
        for entry in CATALOG.options(slot):
            option_count += 1
            _check(not ids.has(str(entry.id)), "unique " + slot + "/" + str(entry.id))
            ids.append(str(entry.id))
            for key in entry.mul:
                _check(is_finite(float(entry.mul[key])) and float(entry.mul[key]) > 0.0, "positive factor")
            for key in entry.add:
                _check(is_finite(float(entry.add[key])), "finite additive factor")
        var added := CATALOG.option(slot, str(NEW_PARTS[slot]))
        _check(added.id == NEW_PARTS[slot] and int(added.cost) == 0, "new free alternative " + slot)
        _check(ResourceLoader.exists(added.file), "real model source " + slot)
        _check(ResourceLoader.exists(added.thumb), "thumbnail source " + slot)
    _check(option_count == 65, "65 options, including nine factory choices")
    _check(CATALOG.combination_count() == 52706752, "exact number of independent loadouts")
    var base := FLEET.multipliers(FLEET.base_stats("comet"), FLEET.entry("comet").traits)
    _check(CATALOG.apply(base, {}) == base, "stock factors remain exactly unchanged")
    # Independent positive products have their exact extrema at the per-slot
    # extrema. Fine-tuning is another independent positive product.
    for key in CATALOG.PART_LIMITS:
        for maximum in [false, true]:
            var chosen: Dictionary = {}
            var tune_values: Dictionary = {}
            var product := 1.0
            for slot in CATALOG.SLOTS:
                var best := -INF if maximum else INF
                var chosen_id := "serie"
                for entry in CATALOG.options(slot):
                    var value := float(entry.mul.get(key, 1.0))
                    if (maximum and value > best) or (not maximum and value < best):
                        best = value
                        chosen_id = str(entry.id)
                chosen[slot] = chosen_id
                product *= best
            for setting in FINE.SETTINGS:
                var coefficient := float(setting.per_step.get(key, 0.0))
                var step := 0 if coefficient == 0.0 else (2 if (coefficient > 0.0) == maximum else -2)
                tune_values[setting.id] = step
                product *= 1.0 + coefficient * step
            var extra := FINE.changes(tune_values)
            var raw := CATALOG.changes(chosen, extra, false)
            _check(is_equal_approx(float(raw.mul.get(key, 1.0)), product), "independent extremum " + key)
            var bounded := CATALOG.apply(base, chosen, extra)
            _bounded(bounded, base, "extremum")
            envelopes.append({"factor": key, "maximum": maximum, "raw": product,
                "bounded": float(bounded.get(key, 1.0)) / float(base.get(key, 1.0))})
    # Every pair of concrete options across all nine slots.
    for first in range(CATALOG.SLOTS.size()):
        for second in range(first + 1, CATALOG.SLOTS.size()):
            var a: String = CATALOG.SLOTS[first]
            var b: String = CATALOG.SLOTS[second]
            for left in CATALOG.options(a):
                for right in CATALOG.options(b):
                    _bounded(CATALOG.apply(base, {a: left.id, b: right.id}), base, "pairwise")
                    pairwise += 1
    var random := RandomNumberGenerator.new()
    random.seed = 20261123
    for kart_id in FLEET.ids():
        var factory := FLEET.multipliers(FLEET.base_stats(kart_id), FLEET.entry(kart_id).traits)
        for sample in range(4096 if kart_id == "comet" else 128):
            var combination: Dictionary = {}
            var fine: Dictionary = {}
            for slot in CATALOG.SLOTS:
                var choices: Array[Dictionary] = CATALOG.options(slot)
                combination[slot] = choices[random.randi_range(0, choices.size() - 1)].id
            for setting in FINE.SETTINGS:
                fine[setting.id] = random.randi_range(-2, 2)
            var factors := CATALOG.apply(factory, combination, FINE.changes(fine))
            _bounded(factors, factory, kart_id)
            _check(POWERTRAIN.acceleration(factors, false) > 0.0, "positive actual acceleration")
            _check(POWERTRAIN.top_speed(factors) > 0.0, "positive actual top speed")
            sampled += 1
    # Display must report the real capped combination and explain saturation.
    var saturated := {"tires": "haft", "wing": "venturi", "suspension": "sport"}
    _check(not CATALOG.limit_notes(saturated, FINE.changes({"pressure": -2, "wing_angle": 2})).is_empty(),
        "visible explanation of a saturated combination")
    var before := DYNO.measure(base)
    single_part_results.append({"slot": "stock", "part": "serie", "factors": base, "dyno": before})
    print("[KartEvolutionPart] ", JSON.stringify(single_part_results[-1]))
    for slot in NEW_PARTS:
        var combined := CATALOG.apply(base, {slot: NEW_PARTS[slot]})
        var after := DYNO.measure(combined)
        single_part_results.append({"slot": slot, "part": NEW_PARTS[slot], "factors": combined, "dyno": after})
        print("[KartEvolutionPart] ", JSON.stringify(single_part_results[-1]))
        var better := false
        var worse := false
        for metric in DYNO.METRICS:
            better = better or DYNO.verdict(metric, before[metric], after[metric]) > 0
            worse = worse or DYNO.verdict(metric, before[metric], after[metric]) < 0
        _check(better and worse, "measured benefit AND trade-off " + slot)


func _geometry_and_persistence() -> void:
    var library := load("res://assets/kart/production/parts/parts_evolution.tscn") as PackedScene
    _check(library != null, "PackedScene integration")
    var source := library.instantiate()
    for component in GEOMETRY.NAMES:
        var part := source.find_child(component, true, false) as Node3D
        _check(part != null, "built model " + component)
        if part != null:
            var model := part.get_node("HardwareMesh") as MeshInstance3D
            _check(model.mesh.get_surface_count() > 0 and model.mesh.get_surface_count() <= 4,
                "bounded geometry batches " + component)
            _check(model.get_aabb().size.length() > 0.05, "nonempty geometry " + component)
    source.free()
    DirAccess.remove_absolute(TUNING.path_for(CHILD))
    var workshop = TUNING.new(CHILD, 0)
    _check(workshop.mount_parts("comet", NEW_PARTS), "mount all new parts with zero stars")
    _check(workshop.available() == 0, "no star mutation")
    var reloaded = TUNING.new(CHILD, 0)
    _check(reloaded.mounted("comet") == NEW_PARTS, "all nine parts survive save/reload")
    _check(reloaded.chosen("glider", "engine") == "serie", "other kart unchanged")
    for kart_id in FLEET.ids():
        var kart = VEHICLE.new()
        kart.set_look(workshop.look(kart_id).merged(NEW_PARTS, true))
        kart.configure("fox", Color("76bded"), kart_id)
        root.add_child(kart)
        var vehicle = kart.production_vehicle
        _check(is_instance_valid(vehicle), "production vehicle " + kart_id)
        if is_instance_valid(vehicle):
            _check(vehicle.asset_root.find_child("EvolutionCoachwork", true, false) != null, "modern trim " + kart_id)
            _check(vehicle.wheel_pivots.size() == 4, "original wheel anchors")
            for slot in NEW_PARTS:
                _check(vehicle.mounted_parts.get(slot) == NEW_PARTS[slot], "visual mounted " + kart_id + "/" + slot)
                var component: String = CATALOG.option(slot, str(NEW_PARTS[slot])).node
                _check(not vehicle.find_children("Part_" + component, "Node3D", true, false).is_empty(),
                    "actual geometry mounted " + component)
            vehicle.set_preview_detail(false)
            vehicle.set_lod(2)
            for item in vehicle.dressing_nodes():
                _check(not item.visible, "distant LOD hides cosmetic hardware")
        kart.free()
    DirAccess.remove_absolute(TUNING.path_for(CHILD))


func _reset_drive(factors: Dictionary, initial: float = 0.0) -> void:
    game.kart_factors = factors
    game.distance = 12.0
    game.previous_road_distance = 12.0
    game.player.transform = game.world.reset_transform(12.0)
    game.player_heading = game._heading(12.0)
    game.speed = initial
    game.physical_velocity = game.world.forward(12.0) * initial
    game.auto_gas = true
    game.airborne = false
    game.boost_time = 0.0
    game.hit_timer = 0.0
    game.landing_settle = 0.0
    game.player_spin_time = 0.0
    game.drifting = false
    game.drift_charge = 0.0
    game.player.set_meta("roadside_speed_factor", 1.0)



func _record_boundary_drive(workshop, kart_id: String, label: String) -> void:
    game.workshop = workshop
    game.selected_kart = kart_id
    game._refresh_kart_factors()
    var factors: Dictionary = game.kart_factors.duplicate()
    _check(factors == workshop.multipliers(kart_id), label + " reads actual workshop factors")
    var peak := POWERTRAIN.top_speed(factors, POWERTRAIN.race_pace()) * POWERTRAIN.boost_scale(factors)
    _reset_drive(factors, peak - 0.5)
    game.boost_time = 1.0
    game._drive_player(STEP, 0.0, 0.0)
    var expected_peak := move_toward(peak - 0.5, peak,
        STEP * POWERTRAIN.acceleration(factors, false) * POWERTRAIN.BOOST_ACCELERATION)
    _check(absf(game.speed - expected_peak) < 0.01, label + " actual boosted target")
    var measured_peak: float = game.speed
    _reset_drive(factors, peak)
    for tick in range(4):
        game._drive_player(STEP, 0.0, 1.0)
    var brake_rate := POWERTRAIN.acceleration(factors, true)
    var expected_braked := peak - brake_rate * STEP * 4.0
    _check(absf(game.speed - expected_braked) < 0.01, label + " actual full-speed braking")
    var record := {"case": label, "kart": kart_id, "parts": workshop.mounted(kart_id),
        "levels": workshop.levels.get(kart_id, {}).duplicate(), "fine": workshop.tune(kart_id),
        "factors": factors, "boost_target_mps": peak, "actual_boost_mps": measured_peak,
        "brake_deceleration_mps2": brake_rate, "speed_after_four_brake_ticks_mps": game.speed}
    boundary_drive.append(record)
    print("[KartEvolutionBoundary] ", JSON.stringify(record))


func _high_speed_boundaries(workshop) -> void:
    workshop.report_lifetime(10000)
    var fastest: Dictionary = {
        "engine": "lader", "tires": "slick", "wing": "flach", "booster": "kurz",
        "suspension": "serie", "steering": "serie", "brakes": "leicht",
        "gearbox": "lang", "ballast": "serie",
    }
    _check(workshop.unlock_parts(fastest), "boundary parts unlocked through real workshop")
    _check(workshop.mount_parts("stella", fastest), "fastest joint speed/boost selection mounted")
    workshop.set_tune("stella", {"pressure": 2, "wing_angle": -2, "gear": 2})
    for upgrade in TUNING.PARTS:
        for level_index in range(TUNING.MAX_LEVEL):
            _check(workshop.upgrade("stella", str(upgrade.id)), "full Stella upgrade")
    var full: Dictionary = workshop.multipliers("stella")
    var full_peak := POWERTRAIN.top_speed(full, POWERTRAIN.race_pace()) * POWERTRAIN.boost_scale(full)
    _check(absf(full_peak - 107.84237129825121) < 0.00001, "catalogue joint maximum boosted Stella")
    _check(absf(POWERTRAIN.acceleration(full, true) - 83.664) < 0.00001, "full Stella with light brakes")
    _record_boundary_drive(workshop, "stella", "full_stella_light_brakes")

    # Keep the fastest engine/turbo upgrades but deliberately omit brake upgrades.
    # This is the more demanding legal fast-build braking case.
    workshop.refund("stella")
    for upgrade in TUNING.PARTS:
        if str(upgrade.id) == "bremsen":
            continue
        for level_index in range(TUNING.MAX_LEVEL):
            _check(workshop.upgrade("stella", str(upgrade.id)), "fast Stella without brake upgrades")
    var fast_weak: Dictionary = workshop.multipliers("stella")
    _check(absf(POWERTRAIN.acceleration(fast_weak, true) - 71.904) < 0.00001,
        "fastest build without brake upgrades uses its real weaker brakes")
    _record_boundary_drive(workshop, "stella", "fast_stella_unupgraded_light_brakes")

    # Per-slot positive minima yield the actual weakest catalogue brake, rather
    # than assuming the 0.65 safety clamp is necessarily reachable.
    var weakest: Dictionary = {}
    for slot in CATALOG.SLOTS:
        var chosen := "serie"
        var best := INF
        for part in CATALOG.options(slot):
            var value := float(part.mul.get("brake", 1.0))
            if value < best:
                best = value
                chosen = str(part.id)
        weakest[slot] = chosen
    var weakest_kart := ""
    var lowest_brake := INF
    for kart_id in FLEET.ids():
        var factory := FLEET.multipliers(FLEET.base_stats(kart_id), FLEET.entry(kart_id).traits)
        var candidate := POWERTRAIN.acceleration(CATALOG.apply(factory, weakest), true)
        if candidate < lowest_brake:
            lowest_brake = candidate
            weakest_kart = kart_id
    _check(absf(lowest_brake - 62.496) < 0.00001, "actual weakest reachable brake across fleet")
    workshop.refund(weakest_kart)
    workshop.reset_tune(weakest_kart)
    _check(workshop.unlock_parts(weakest) and workshop.mount_parts(weakest_kart, weakest),
        "weakest brake configuration mounted")
    _record_boundary_drive(workshop, weakest_kart, "weakest_reachable_factory_brakes")


func _actual_race() -> void:
    game = load("res://scenes/games/kart_island.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    for index in range(8):
        await process_frame
    var workshop = TUNING.new(CHILD, 1000)
    workshop.save_enabled = false
    game.workshop = workshop
    game.garage.workshop = workshop
    game.garage.start_requested.emit(game.garage.setup.duplicate(true))
    for index in range(12):
        await process_frame
    game.mode = "time_trial"
    game.difficulty = "flott"
    game.selected_kart = "comet"
    var sets: Array[Dictionary] = [
        {}, {"engine": "axial", "gearbox": "doppelkupplung"},
        NEW_PARTS, {"tires": "performance", "steering": "vector", "brakes": "keramik"},
    ]
    for selected in sets:
        var stock: Dictionary = {}
        for slot in CATALOG.SLOTS:
            stock[slot] = "serie"
        _check(workshop.mount_parts("comet", stock.merged(selected, true)), "fixture mount")
        game._refresh_kart_factors()
        var factors: Dictionary = game.kart_factors.duplicate()
        _check(factors == workshop.multipliers("comet"), "race reads exact saved combination")
        _reset_drive(factors)
        for tick in range(18):
            game._drive_player(STEP, 0.0, 0.0)
        var expected := POWERTRAIN.acceleration(factors, false) * STEP * 18.0
        _check(absf(game.speed - expected) < 0.01, "real acceleration follows combined parts")
        var measured_accel: float = game.speed
        _reset_drive(factors, 25.0)
        for tick in range(4):
            game._drive_player(STEP, 0.0, 1.0)
        var brake_expected := 25.0 - POWERTRAIN.acceleration(factors, true) * STEP * 4.0
        _check(absf(game.speed - brake_expected) < 0.01, "real braking follows combined parts")
        _reset_drive(factors, 30.0)
        var heading: float = game.player_heading
        for tick in range(6):
            game._drive_player(STEP, 1.0, 0.0)
        var turned: float = absf(angle_difference(heading, game.player_heading))
        _check(absf(turned - POWERTRAIN.turn_rate(factors, 30.0, false, false) * STEP * 6.0) < 0.01,
            "real steering follows combined parts")
        _reset_drive(factors, 30.0)
        game.drifting = true
        for tick in range(6):
            game._drive_player(STEP, 1.0, 0.0)
        var expected_charge := POWERTRAIN.drift_charge_rate(factors, 1.0) * STEP * 6.0
        _check(absf(game.drift_charge - expected_charge) < 0.01, "real drift charging follows combined parts")
        actual_drive.append({"parts": selected, "speed_after_18_ticks_mps": measured_accel,
            "turn_after_6_ticks_rad": turned, "drift_charge_after_6_ticks": game.drift_charge,
            "dyno": DYNO.measure(factors)})
    _high_speed_boundaries(workshop)
    _check(await TEARDOWN.release_scene(self, game, "[KartEvolution]"), "scene and audio released")
    game = null


func _run() -> void:
    _catalogue_and_combinations()
    _geometry_and_persistence()
    await _actual_race()
    DirAccess.make_dir_recursive_absolute(output)
    var file := FileAccess.open(output.path_join("vehicle-evolution-regression.json"), FileAccess.WRITE)
    _check(file != null, "report file opened")
    if file != null:
        file.store_string(JSON.stringify({"status": "PASS" if failures.is_empty() else "FAIL",
            "engine": Engine.get_version_info().string, "checks": checks, "failures": failures,
            "total_catalogue_loadouts": CATALOG.combination_count(), "factor_extrema": envelopes,
            "pairwise_cases": pairwise, "sampled_complete_loadouts": sampled,
            "real_race_setups": actual_drive, "boundary_race_setups": boundary_drive,
            "single_part_comet": single_part_results,
            "android_fps_verified": false}, "  "))
        file.close()
    print("[KartEvolution] %s checks=%d pairwise=%d sampled=%d actual_race_setups=%d boundary_race_setups=%d" %
        ["PASS" if failures.is_empty() else "FAIL", checks, pairwise, sampled, actual_drive.size(), boundary_drive.size()])
    quit(0 if failures.is_empty() else 1)
