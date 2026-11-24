extends RefCounted
## Original procedural hardware. Geometry is built once per process and shared.
## Each component is one mesh with at most four material surfaces, no colliders
## and no per-frame builder. Mechanical anchors remain owned by the production kart.
const NAMES: Array[String] = [
    "Engine_Axial", "Tire_Performance", "Wing_Venturi", "Booster_Capacitor",
    "Damper_Adaptive", "Steer_Vector", "Brake_Ceramic", "Brake_CeramicDisc",
    "Gear_Dual", "Ballast_Carbon",
]
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


static func populate(parent: Node3D) -> void:
    for component in NAMES:
        parent.add_child(part(component))


static func part(component: String) -> Node3D:
    var result := Node3D.new()
    result.name = component
    result.set_meta("evolution_revision", 1)
    if not _meshes.has(component):
        _meshes[component] = _bake(_shapes(component))
    var model := MeshInstance3D.new()
    model.name = "HardwareMesh"
    model.mesh = _meshes[component]
    model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    result.add_child(model)
    return result


static func vehicle_trim(variant: String) -> Node3D:
    var key := "ModernTrim_" + variant
    if not _meshes.has(key):
        var shapes: Array[Dictionary] = []
        var width := 0.91 if variant == "glider" else (1.10 if variant == "turbo" else 1.0)
        _add(shapes, "box", Vector3(1.32 * width, 0.042, 0.20), Vector3(0, 0.16, -1.23), "carbon")
        _add(shapes, "box", Vector3(1.17 * width, 0.014, 0.022), Vector3(0, 0.188, -1.337), "light")
        for side in [-1.0, 1.0]:
            _add(shapes, "box", Vector3(0.025, 0.065, 0.48), Vector3(side * 0.835 * width, 0.10, 0), "carbon")
            _add(shapes, "box", Vector3(0.012, 0.012, 0.40), Vector3(side * 0.854 * width, 0.128, 0), "light")
            _add(shapes, "box", Vector3(0.22, 0.025, 0.15), Vector3(side * 0.44 * width, 0.19, -1.19), "paint", Basis(Vector3.FORWARD, side * 0.09))
        for index in range(5):
            _add(shapes, "box", Vector3(0.025, 0.11, 0.26), Vector3((index - 2) * 0.145 * width, 0.14, 1.15), "carbon", Basis(Vector3.RIGHT, -0.18))
        _add(shapes, "box", Vector3(0.78 * width, 0.027, 0.08), Vector3(0, 0.22, 1.27), "metal")
        _meshes[key] = _bake(shapes)
    var result := Node3D.new()
    result.name = "EvolutionCoachwork"
    result.set_meta("evolution_revision", 1)
    var model := MeshInstance3D.new()
    model.name = "BatchedSplitterAndDiffuser"
    model.mesh = _meshes[key]
    model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    result.add_child(model)
    return result


static func _shapes(component: String) -> Array[Dictionary]:
    var s: Array[Dictionary] = []
    var axle_x := Basis(Vector3.FORWARD, PI / 2.0)
    var axle_z := Basis(Vector3.RIGHT, PI / 2.0)
    match component:
        "Engine_Axial":
            _add(s, "box", Vector3(0.43, 0.055, 0.29), Vector3(0, 0.025, 0), "carbon")
            for side in [-1.0, 1.0]:
                _add(s, "cylinder", Vector3(0.095, 0.24, 0), Vector3(side * 0.11, 0.125, 0), "paint", axle_z)
                _add(s, "torus", Vector3(0.070, 0.098, 0), Vector3(side * 0.11, 0.125, 0.126), "metal", axle_z)
                _add(s, "cylinder", Vector3(0.052, 0.012, 0), Vector3(side * 0.11, 0.125, 0.129), "light", axle_z)
                for fin in range(5):
                    _add(s, "torus", Vector3(0.091, 0.100, 0), Vector3(side * 0.11, 0.125, -0.09 + fin * 0.035), "metal", axle_z)
            _add(s, "box", Vector3(0.055, 0.035, 0.17), Vector3(0, 0.23, 0), "light")
        "Tire_Performance":
            _add(s, "torus", Vector3(0.321, 0.354, 0), Vector3.ZERO, "carbon", axle_x)
            _add(s, "torus", Vector3(0.220, 0.247, 0), Vector3(0.198, 0, 0), "metal", axle_x)
            _add(s, "torus", Vector3(0.278, 0.285, 0), Vector3(0.194, 0, 0), "light", axle_x)
            for index in range(10):
                var a := index * TAU / 10.0
                _add(s, "box", Vector3(0.016, 0.021, 0.13), Vector3(0.201, sin(a) * 0.16, cos(a) * 0.16), "metal", Basis(Vector3.RIGHT, -a))
            for index in range(24):
                var a := index * TAU / 24.0
                _add(s, "box", Vector3(0.23, 0.008, 0.022), Vector3(0, cos(a) * 0.350, sin(a) * 0.350), "carbon", Basis(Vector3.RIGHT, a))
        "Wing_Venturi":
            for side in [-1.0, 1.0]:
                _add(s, "box", Vector3(0.038, 0.16, 0.08), Vector3(side * 0.32, 0.08, 0), "metal")
                _add(s, "box", Vector3(0.028, 0.16, 0.31), Vector3(side * 0.62, 0.18, 0), "paint")
                _add(s, "box", Vector3(0.010, 0.012, 0.22), Vector3(side * 0.638, 0.255, 0), "light")
            _add(s, "capsule", Vector3(0.060, 1.28, 1.70), Vector3(0, 0.17, 0), "carbon", axle_x)
            _add(s, "box", Vector3(1.15, 0.026, 0.10), Vector3(0, 0.24, 0.12), "paint", Basis(Vector3.RIGHT, -0.13))
            for index in range(7):
                _add(s, "box", Vector3(0.018, 0.04, 0.17), Vector3((index - 3) * 0.16, 0.12, 0), "metal")
        "Booster_Capacitor":
            _add(s, "box", Vector3(0.14, 0.028, 0.26), Vector3(0, 0.015, 0.03), "carbon")
            for offset in [-0.043, 0.043]:
                _add(s, "cylinder", Vector3(0.038, 0.20, 0), Vector3(offset, 0.085, 0.03), "metal", axle_z)
                _add(s, "torus", Vector3(0.030, 0.042, 0), Vector3(offset, 0.085, 0.134), "light", axle_z)
                for band in [-0.035, 0.085]:
                    _add(s, "torus", Vector3(0.036, 0.045, 0), Vector3(offset, 0.085, band), "paint", axle_z)
            _add(s, "box", Vector3(0.12, 0.016, 0.06), Vector3(0, 0.13, 0.03), "light")
        "Damper_Adaptive":
            # The same wheel-carrier endpoints used by the authored production suspension.
            var low := Vector3(-0.215, 0.10, 0.0)
            var high := Vector3(-0.40, 0.29, 0.0)
            var damper_axis := Basis(Quaternion(Vector3.UP, (high - low).normalized()))
            _add(s, "cylinder", Vector3(0.024, low.distance_to(high), 0), low.lerp(high, 0.5), "metal", damper_axis)
            _add(s, "cylinder", Vector3(0.040, 0.14, 0), low.lerp(high, 0.58), "paint", damper_axis)
            for index in range(7):
                _add(s, "torus", Vector3(0.038, 0.048, 0), low.lerp(high, 0.23 + index * 0.10), "metal", damper_axis)
            for endpoint in [low, high]:
                _add(s, "torus", Vector3(0.015, 0.028, 0), endpoint, "metal", axle_z)
            var controller := low.lerp(high, 0.68) + Vector3(0.055, 0.020, 0.0)
            _add(s, "box", Vector3(0.05, 0.075, 0.055), controller, "carbon", damper_axis)
            _add(s, "box", Vector3(0.014, 0.050, 0.058), controller + Vector3(0.018, 0, 0), "light", damper_axis)
        "Steer_Vector":
            _add(s, "cylinder", Vector3(0.026, 1.15, 0), Vector3(0, -0.015, 0.075), "metal", axle_x)
            _add(s, "box", Vector3(0.25, 0.09, 0.14), Vector3(0, -0.015, 0.075), "carbon")
            for side in [-1.0, 1.0]:
                _add(s, "cylinder", Vector3(0.052, 0.13, 0), Vector3(side * 0.31, -0.015, 0.075), "paint", axle_x)
                _add(s, "torus", Vector3(0.045, 0.056, 0), Vector3(side * 0.31, -0.015, 0.075), "light", axle_x)
        "Brake_Ceramic":
            # Fixed caliper behind the rim; the separate disc follows the spinning rotor.
            _add(s, "capsule", Vector3(0.034, 0.14, 0.82), Vector3(0.103, 0.12, 0.10), "paint")
            _add(s, "box", Vector3(0.055, 0.095, 0.040), Vector3(0.103, 0.12, 0.10), "carbon")
            for index in range(3):
                _add(s, "box", Vector3(0.012, 0.012, 0.045), Vector3(0.134, 0.090 + index * 0.030, 0.10), "light")
        "Brake_CeramicDisc":
            _add(s, "cylinder", Vector3(0.192, 0.018, 0), Vector3(0.085, 0, 0), "carbon", axle_x)
            _add(s, "torus", Vector3(0.175, 0.190, 0), Vector3(0.096, 0, 0), "metal", axle_x)
            _add(s, "cylinder", Vector3(0.072, 0.027, 0), Vector3(0.093, 0, 0), "metal", axle_x)
            for index in range(18):
                var a := index * TAU / 18.0
                _add(s, "box", Vector3(0.003, 0.007, 0.034), Vector3(0.098, sin(a) * 0.145, cos(a) * 0.145), "metal", Basis(Vector3.RIGHT, -a))
        "Gear_Dual":
            _add(s, "capsule", Vector3(0.105, 0.42, 0.86), Vector3(0, 0.045, 0), "paint", axle_x)
            for side in [-1.0, 1.0]:
                _add(s, "torus", Vector3(0.078, 0.108, 0), Vector3(side * 0.11, 0.045, 0), "metal", axle_x)
                _add(s, "torus", Vector3(0.100, 0.112, 0), Vector3(side * 0.15, 0.045, 0), "light", axle_x)
            for index in range(4):
                _add(s, "box", Vector3(0.29, 0.018, 0.016), Vector3(0, 0.13, -0.07 + index * 0.045), "carbon")
        "Ballast_Carbon":
            # External sills between the wheels, scaled by the production platform's stance.
            for side in [-1.0, 1.0]:
                _add(s, "box", Vector3(0.020, 0.10, 0.48), Vector3(side * 0.843, 0.16, 0), "carbon")
                _add(s, "box", Vector3(0.010, 0.014, 0.40), Vector3(side * 0.859, 0.201, 0), "light")
                for index in range(5):
                    _add(s, "box", Vector3(0.024, 0.014, 0.024), Vector3(side * 0.846, 0.12, -0.20 + index * 0.10), "metal")
            _add(s, "box", Vector3(1.2, 0.025, 0.48), Vector3(0, 0.07, 0), "carbon")
            _add(s, "box", Vector3(1.2, 0.025, 0.045), Vector3(0, 0.088, -0.23), "paint")
            _add(s, "box", Vector3(1.2, 0.025, 0.045), Vector3(0, 0.088, 0.23), "paint")
    return s


static func _add(target: Array[Dictionary], kind: String, size: Vector3, at: Vector3,
        finish: String, basis: Basis = Basis.IDENTITY) -> void:
    target.append({"kind": kind, "size": size, "at": at, "finish": finish, "basis": basis})


static func _primitive(shape: Dictionary) -> PrimitiveMesh:
    var dimensions: Vector3 = shape.size
    match str(shape.kind):
        "cylinder":
            var mesh := CylinderMesh.new()
            mesh.top_radius = dimensions.x
            mesh.bottom_radius = dimensions.x
            mesh.height = dimensions.y
            mesh.radial_segments = 20
            mesh.rings = 1
            return mesh
        "torus":
            var mesh := TorusMesh.new()
            mesh.inner_radius = dimensions.x
            mesh.outer_radius = dimensions.y
            mesh.rings = 24
            mesh.ring_segments = 6
            return mesh
        "capsule":
            var mesh := CapsuleMesh.new()
            mesh.radius = dimensions.x
            mesh.height = dimensions.y
            mesh.radial_segments = 20
            mesh.rings = 4
            return mesh
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    return mesh


static func _bake(shapes: Array[Dictionary]) -> ArrayMesh:
    var result := ArrayMesh.new()
    for finish in ["carbon", "metal", "paint", "light"]:
        var builder := SurfaceTool.new()
        builder.begin(Mesh.PRIMITIVE_TRIANGLES)
        var count := 0
        for shape in shapes:
            if str(shape.finish) != finish:
                continue
            var basis: Basis = shape.basis
            if str(shape.kind) == "capsule":
                basis = basis.scaled(Vector3(1, 1, float(shape.size.z)))
            builder.append_from(_primitive(shape), 0, Transform3D(basis, shape.at))
            count += 1
        if count > 0:
            builder.commit(result)
            result.surface_set_material(result.get_surface_count() - 1, _material(finish))
    return result


static func _material(finish: String) -> StandardMaterial3D:
    if _materials.has(finish):
        return _materials[finish]
    var result := StandardMaterial3D.new()
    result.resource_name = "PartPaint" if finish == "paint" else "Evolution_" + finish
    result.albedo_color = Color({"carbon": "131d2b", "metal": "b7c9df", "paint": "e8eef6", "light": "56e9ff"}[finish])
    result.metallic = 0.70 if finish == "metal" else (0.30 if finish == "paint" else 0.12)
    result.roughness = 0.23 if finish == "metal" else (0.29 if finish == "paint" else 0.40)
    if finish == "paint":
        result.clearcoat_enabled = true
        result.clearcoat = 0.65
        result.clearcoat_roughness = 0.18
    if finish == "light":
        result.emission_enabled = true
        result.emission = result.albedo_color
        result.emission_energy_multiplier = 1.15
    _materials[finish] = result
    return result
