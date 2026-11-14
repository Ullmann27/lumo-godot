extends SceneTree
## Exercise actual instanced geometry, branching, pause and accessibility.
const FX = preload("res://scripts/creative/treasure_wisps.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
    _run.call_deferred()


func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_warning("[TreasureWisp] FAIL " + message)


func _run() -> void:
    var effects = FX.new()
    root.add_child(effects)
    await process_frame
    var gold := effects.get_node("GuideGold") as MultiMeshInstance3D
    var moon := effects.get_node("GuideMoon") as MultiMeshInstance3D
    var celebration := effects.get_node("DiscoverySparkles") as MultiMeshInstance3D
    _check(gold != null and moon != null and celebration != null, "three real sprite batches")
    _check(gold.multimesh.instance_count == 16 and moon.multimesh.instance_count == 16, "limited route GPU instances")
    _check(celebration.multimesh.instance_count == 20, "reusable 20-instance discovery effect")
    _check(gold.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "no extra shadows")
    effects.set_routes(Vector3(0, 0, 6), [{"at": Vector3(0, 0, -22)}])
    await process_frame
    _check(effects.route_count() == 1 and gold.visible and not moon.visible, "one real clue gives one path")
    _check(effects.route_point(0, 0).z < 5.0, "rendered sprite source points toward the first goal")
    effects.set_routes(Vector3(0, 0, -33), [
        {"at": Vector3(-20, 0, -47)}, {"at": Vector3(20, 0, -47)}
    ])
    await process_frame
    _check(effects.route_count() == 2 and gold.visible and moon.visible, "both available forks glow")
    _check(effects.route_point(0, 0).x < 0, "gold route points to left quest goal")
    _check(effects.route_point(1, 0).x > 0, "moon route points to right quest goal")
    effects.celebrate(Vector3(0, 1.5, -33))
    _check(celebration.visible, "success visibly starts a 3D sparkle ring")
    effects.set_paused(true)
    var frozen: float = effects._clock
    for i in range(5):
        await process_frame
    _check(is_equal_approx(frozen, effects._clock), "modal pauses ambient movement")
    effects.set_paused(false)
    effects.set_reduced_motion(true)
    var steady := effects.route_point(0, 0)
    for i in range(5):
        await process_frame
    _check(steady.is_equal_approx(effects.route_point(0, 0)), "reduced motion keeps visual positions static")
    effects.set_routes(Vector3(4, 0, 0), [
        {"at": Vector3(INF, 0, 0)}, {"at": Vector3.ZERO}, {"other": 4}
    ])
    _check(effects.route_count() == 1, "nonfinite target does not generate an effect")
    effects.set_routes(Vector3.ZERO, [])
    _check(effects.route_count() == 0 and not gold.visible and not moon.visible, "completion clears false paths")
    effects.queue_free()
    await process_frame
    if failures == 0:
        print("[TreasureWisp] PASS checks=%d" % checks)
        quit(0)
    else:
        print("[TreasureWisp] FAIL checks=%d failures=%d" % [checks, failures])
        quit(1)
