extends Node3D
## Only a visual layer: TreasureState owns chapter, rewards, answer and saves.
## 16 + 16 instanced glowing 3D quads mark actual available destinations.
## One recycled 20-sprite ring confirms a real discovery without changing XP.

const STAR_SHADER = preload("res://assets/creative/shaders/treasure_wisp.gdshader")
const WISPS_PER_ROUTE := 16
const CELEBRATION_WISPS := 20
const UPDATE_INTERVAL := 1.0 / 24.0
const CELEBRATION_SECONDS := 1.25

var _reduced_motion := false
var _paused := false
var _clock := 0.0
var _accumulator := 0.0
var _origin := Vector3.ZERO
var _goals: Array[Vector3] = []
var _guides: Array[MultiMeshInstance3D] = []
var _celebration: MultiMeshInstance3D
var _celebration_at := Vector3.ZERO
var _celebration_age := -1.0


func _ready() -> void:
    _guides.append(_batch("GuideGold", Color("ffe5a0"), WISPS_PER_ROUTE))
    _guides.append(_batch("GuideMoon", Color("a6e8ff"), WISPS_PER_ROUTE))
    _celebration = _batch("DiscoverySparkles", Color("ffe9bd"), CELEBRATION_WISPS)
    _celebration.visible = false
    _draw_routes()


func _batch(title: String, tint: Color, count: int) -> MultiMeshInstance3D:
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.mesh = quad
    instances.instance_count = count
    var material := ShaderMaterial.new()
    material.shader = STAR_SHADER
    material.set_shader_parameter("glow_color", tint)
    var node := MultiMeshInstance3D.new()
    node.name = title
    node.multimesh = instances
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # Moving instances need stable culling bounds along the entire island.
    node.custom_aabb = AABB(Vector3(-45, -4, -90), Vector3(90, 22, 125))
    add_child(node)
    return node


func set_reduced_motion(enabled: bool) -> void:
    _reduced_motion = enabled
    if is_inside_tree():
        _draw_routes()
        _draw_celebration()


func set_paused(enabled: bool) -> void:
    _paused = enabled


func route_count() -> int:
    return _goals.size()


func set_routes(from_position: Vector3, available: Array) -> void:
    _origin = from_position
    var new_goals: Array[Vector3] = []
    for goal in available:
        if not goal is Dictionary:
            continue
        var destination: Variant = goal.get("at")
        if destination is Vector3 and (
            is_finite(destination.x) and is_finite(destination.y) and is_finite(destination.z)
        ):
            new_goals.append(destination)
        if new_goals.size() == 2:
            break
    var changed := new_goals.size() != _goals.size()
    _goals = new_goals
    if changed and is_inside_tree():
        _draw_routes()


func celebrate(at: Vector3) -> void:
    if not (is_finite(at.x) and is_finite(at.y) and is_finite(at.z)):
        return
    _celebration_at = at
    _celebration_age = 0.0
    if is_instance_valid(_celebration):
        _celebration.visible = true
        _draw_celebration()


func _process(delta: float) -> void:
    if _paused:
        return
    var step := clampf(delta, 0.0, 0.10)
    if not _reduced_motion:
        _clock += step
    if _celebration_age >= 0.0:
        _celebration_age += step
        if _celebration_age >= CELEBRATION_SECONDS:
            _celebration_age = -1.0
            _celebration.visible = false
    _accumulator += step
    if _accumulator < UPDATE_INTERVAL:
        return
    _accumulator = 0.0
    _draw_routes()
    if _celebration_age >= 0.0:
        _draw_celebration()


func _billboard() -> Basis:
    var camera := get_viewport().get_camera_3d()
    return camera.global_basis if is_instance_valid(camera) else Basis.IDENTITY


func route_point(route_index: int, index: int) -> Vector3:
    # The same coordinates drive the renderer and its headless regression.
    # Some headless Godot backends do not expose Multimesh GPU buffer readback.
    if route_index < 0 or route_index >= _goals.size():
        return Vector3.ZERO
    if index < 0 or index >= WISPS_PER_ROUTE:
        return Vector3.ZERO
    var offset := _goals[route_index] - _origin
    var flat := Vector3(offset.x, 0.0, offset.z)
    var distance := flat.length()
    if distance < 0.65:
        return _origin
    var direction := flat / distance
    var fraction := float(index + 1) / float(WISPS_PER_ROUTE + 1)
    var reach := minf(distance, 18.0)
    var travel := 0.65 + fraction * maxf(0.0, reach - 0.65)
    var phase := float(index) * 0.85 + float(route_index) * 1.37
    var y_offset := 0.0 if _reduced_motion else sin(_clock * 1.5 + phase) * 0.17
    var at := _origin + direction * travel
    at.y = 0.73 + y_offset
    return at


func _draw_routes() -> void:
    if _guides.is_empty():
        return
    var facing := _billboard()
    for route_index in range(_guides.size()):
        var node := _guides[route_index]
        node.visible = route_index < _goals.size()
        if not node.visible:
            continue
        var offset := _goals[route_index] - _origin
        var flat := Vector3(offset.x, 0.0, offset.z)
        var distance := flat.length()
        if distance < 0.65:
            node.visible = false
            continue
        var batch: MultiMesh = node.multimesh
        for i in range(WISPS_PER_ROUTE):
            var at := route_point(route_index, i)
            var size := 0.18 + 0.055 * pow(sin(float(i) * 1.31), 2.0)
            batch.set_instance_transform(
                i, Transform3D(facing.scaled(Vector3.ONE * size), at)
            )


func _draw_celebration() -> void:
    if not is_instance_valid(_celebration) or _celebration_age < 0.0:
        return
    var progress := (
        0.0 if _reduced_motion else clampf(_celebration_age / CELEBRATION_SECONDS, 0.0, 1.0)
    )
    var facing := _billboard()
    for i in range(CELEBRATION_WISPS):
        var angle := float(i) * TAU / float(CELEBRATION_WISPS)
        var radius := 0.35 + progress * 1.7
        var at := _celebration_at + Vector3(
            cos(angle) * radius,
            sin(angle * 3.0) * 0.25 + progress * 1.15,
            sin(angle) * radius
        )
        var size := 0.25 * (1.0 - progress * 0.8)
        _celebration.multimesh.set_instance_transform(
            i, Transform3D(facing.scaled(Vector3.ONE * size), at)
        )
