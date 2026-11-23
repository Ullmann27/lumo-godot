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
        _add(shapes, "box", Vector3(1.32 * width, 0.042, 0.19), Vector3(0, 0.19, -1.10), "carbon")
        _add(shapes, "box", Vector3(1.17 * width, 0.014, 0.022), Vector3(0, 0.218, -1.202), "light")
        for side in [-1.0, 1.0]:
            _add(shapes, "box", Vector3(0.045, 0.065, 0.91), Vector3(side * 0.66 * width, 0.22, -0.02), "carbon")
            _add(shapes, "box", Vector3(0.014, 0.014, 0.68), Vector3(side * 0.69 * width, 0.258, -0.02), "light")
            _add(shapes, "box", Vector3(0.22, 0.025, 0.15), Vector3(side * 0.44 * width, 0.25, -0.98), "paint", Basis(Vector3.FORWARD, side * 0.09))
        for index in range(5):
            _add(shapes, "box", Vector3(0.025, 0.11, 0.26), Vector3((index - 2) * 0.145 * width, 0.185, 0.99), "carbon", Basis(Vector3.RIGHT, -0.18))
        _add(shapes, "box", Vector3(0.78 * width, 0.027, 0.08), Vector3(0, 0.25, 1.10), "metal")
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
            _add(s, "cylinder", Vector3(0.024, 0.24, 0), Vector3(-0.16, 0.06, 0.10), "metal")
            _add(s, "cylinder", Vector3(0.043, 0.14, 0), Vector3(-0.16, 0.02, 0.10), "paint")
            for index in range(7):
                _add(s, "torus", Vector3(0.038, 0.048, 0), Vector3(-0.16, -0.035 + index * 0.020, 0.10), "metal")
            _add(s, "box", Vector3(0.05, 0.10, 0.055), Vector3(-0.10, 0.06, 0.10), "carbon")
            _add(s, "box", Vector3(0.055, 0.014, 0.035), Vector3(-0.10, 0.116, 0.10), "light")
        "Steer_Vector":
            _add(s, "cylinder", Vector3(0.026, 1.15, 0), Vector3(0, 0.06, 0), "metal", axle_x)
            _add(s, "box", Vector3(0.25, 0.09, 0.14), Vector3(0, 0.06, 0), "carbon")
            for side in [-1.0, 1.0]:
                _add(s, "cylinder", Vector3(0.052, 0.13, 0), Vector3(side * 0.31, 0.06, 0), "paint", axle_x)
                _add(s, "torus", Vector3(0.045, 0.056, 0), Vector3(side * 0.31, 0.06, 0), "light", axle_x)
        "Brake_Ceramic":
            _add(s, "capsule", Vector3(0.043, 0.19, 0.82), Vector3(0.214, 0.10, 0), "paint")
            _add(s, "box", Vector3(0.065, 0.12, 0.044), Vector3(0.216, 0.10, 0), "carbon")
            for index in range(3):
                _add(s, "box", Vector3(0.012, 0.014, 0.053), Vector3(0.252, 0.060 + index * 0.033, 0), "light")
        "Brake_CeramicDisc":
            _add(s, "cylinder", Vector3(0.228, 0.018, 0), Vector3(0.205, 0, 0), "carbon", axle_x)
            _add(s, "torus", Vector3(0.202, 0.225, 0), Vector3(0.216, 0, 0), "metal", axle_x)
            _add(s, "cylinder", Vector3(0.072, 0.027, 0), Vector3(0.213, 0, 0), "metal", axle_x)
            for index in range(18):
                var a := index * TAU / 18.0
                _add(s, "box", Vector3(0.003, 0.007, 0.043), Vector3(0.218, sin(a) * 0.165, cos(a) * 0.165), "metal", Basis(Vector3.RIGHT, -a))
        "Gear_Dual":
            _add(s, "capsule", Vector3(0.105, 0.42, 0.86), Vector3(0, 0.045, 0), "paint", axle_x)
            for side in [-1.0, 1.0]:
                _add(s, "torus", Vector3(0.078, 0.108, 0), Vector3(side * 0.11, 0.045, 0), "metal", axle_x)
                _add(s, "torus", Vector3(0.100, 0.112, 0), Vector3(side * 0.15, 0.045, 0), "light", axle_x)
            for index in range(4):
                _add(s, "box", Vector3(0.29, 0.018, 0.016), Vector3(0, 0.13, -0.07 + index * 0.045), "carbon")
        "Ballast_Carbon":
            for side in [-1.0, 1.0]:
                _add(s, "box", Vector3(0.065, 0.085, 1.28), Vector3(side * 0.40, 0.19, 0), "carbon")
                _add(s, "box", Vector3(0.012, 0.016, 0.88), Vector3(side * 0.436, 0.23, 0), "light")
                for index in range(5):
                    _add(s, "box", Vector3(0.085, 0.012, 0.028), Vector3(side * 0.40, 0.238, -0.50 + index * 0.25), "metal")
            _add(s, "box", Vector3(0.77, 0.04, 0.08), Vector3(0, 0.19, -0.54), "paint")
            _add(s, "box", Vector3(0.77, 0.04, 0.08), Vector3(0, 0.19, 0.54), "paint")
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
