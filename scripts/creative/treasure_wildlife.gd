extends Node3D
## Tiere der Schatzinsel: Krabben am Strand (seitwärts trippelnd), Möwen über dem
## Meer (kreisend, Flügelschlag im Shader), Schmetterlinge an Blumen. Jede Art ist
## ein MultiMesh (ein Draw-Call); pro Bild werden nur Transformationen gesetzt.
## Reine Dekoration ohne Kollision; "Ruhige Bewegung" verlangsamt alles stark.

const KIT = preload("res://scripts/creative/adventure_kit.gd")
const NATURE = preload("res://scripts/creative/treasure_island_nature.gd")
const STATE = preload("res://scripts/creative/treasure_state.gd")

var reduced_motion := false
var crabs: MultiMeshInstance3D
var gulls: MultiMeshInstance3D
var butterflies: MultiMeshInstance3D
var _crab_homes: Array[Vector3] = []
var _gull_orbits: Array[Vector4] = []
var _fly_homes: Array[Vector3] = []
var _time := 0.0


func _ready() -> void:
	var budget: Dictionary = LumoQuality.budget()
	var density: float = clampf(float(budget.get("decor_density", 1.0)), 0.35, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33017
	# Krabben am Sandstreifen.
	var tries := 0
	while _crab_homes.size() < int(round(14.0 * density)) and tries < 800:
		tries += 1
		var a := rng.randf() * TAU
		var dist := rng.randf_range(30.0, 60.0)
		var x := cos(a) * dist
		var z := -29.0 + sin(a) * dist
		var r := NATURE.rim(x, z)
		if r < 0.4 or r > 0.72 or absf(x) < 5.0:
			continue
		_crab_homes.append(Vector3(x, NATURE.height(x, z), z))
	crabs = _spawn("WildCrabs", "crab", _crab_homes.size(), false)
	# Möwen kreisen über Strand und Meer.
	for i in range(int(round(9.0 * density))):
		var center := Vector3(rng.randf_range(-30, 30), rng.randf_range(9.0, 15.0), rng.randf_range(-60, 12))
		_gull_orbits.append(Vector4(center.x, center.y, center.z, rng.randf_range(6.0, 13.0)))
	gulls = _spawn("WildGulls", "gull", _gull_orbits.size(), true)
	# Schmetterlinge an Blumen, am Weg und im Mondgarten.
	var spots: Array[Vector3] = [STATE.CLUES[4].at, Vector3(-5, 0, 6), Vector3(5, 0, -8), Vector3(-6, 0, -26), Vector3(6, 0, -40), STATE.CLUES[0].at + Vector3(3, 0, 2)]
	for i in range(int(round(18.0 * density))):
		var base: Vector3 = spots[i % spots.size()]
		_fly_homes.append(base + Vector3(rng.randf_range(-3, 3), rng.randf_range(0.8, 2.2), rng.randf_range(-3, 3)))
	butterflies = _spawn("WildButterflies", "butterfly", _fly_homes.size(), true)
	_update(0.0)


func _spawn(node_name: String, model: String, count: int, custom: bool) -> MultiMeshInstance3D:
	if count <= 0:
		return null
	var placeholder: Array[Transform3D] = []
	for i in range(count):
		placeholder.append(Transform3D.IDENTITY)
	var node := KIT.scatter(self, node_name, "fauna", model, placeholder, model == "crab", 0.0, custom)
	return node


func _process(delta: float) -> void:
	_time += delta * (0.25 if reduced_motion else 1.0)
	_update(_time)


func _update(t: float) -> void:
	if crabs != null:
		for i in range(_crab_homes.size()):
			var home: Vector3 = _crab_homes[i]
			var phase := float(i) * 1.7
			# Seitwärts hin und her mit kurzen Pausen.
			var walk := sin(t * 0.55 + phase)
			var side := clampf(walk * 1.6, -1.0, 1.0) * 1.4
			var yaw := phase * 2.0
			var at := home + Vector3(cos(yaw), 0, -sin(yaw)) * side
			at.y = NATURE.height(at.x, at.z) - 0.04
			var bob := absf(sin(t * 9.0 + phase)) * 0.03 * absf(cos(t * 0.55 + phase))
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 0.75)
			crabs.multimesh.set_instance_transform(i, Transform3D(basis, at + Vector3.UP * bob))
	if gulls != null:
		for i in range(_gull_orbits.size()):
			var o: Vector4 = _gull_orbits[i]
			var speed := 0.16 + 0.03 * float(i % 3)
			var a := t * speed + float(i) * 2.1
			var p := Vector3(o.x + cos(a) * o.w, o.y + sin(a * 2.0) * 0.8, o.z + sin(a) * o.w)
			var tangent := Vector3(-sin(a), 0, cos(a))
			var basis := Basis.looking_at(tangent, Vector3.UP)
			basis = basis * Basis(Vector3.FORWARD, 0.25)
			gulls.multimesh.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * 0.8), p))
	if butterflies != null:
		for i in range(_fly_homes.size()):
			var h: Vector3 = _fly_homes[i]
			var ph := float(i) * 1.37
			var p := h + Vector3(sin(t * 0.7 + ph) * 1.4, sin(t * 1.3 + ph * 2.0) * 0.45, cos(t * 0.5 + ph) * 1.2)
			var vel := Vector3(cos(t * 0.7 + ph) * 0.98, 0.0, -sin(t * 0.5 + ph) * 0.6)
			var basis := Basis.looking_at(vel.normalized() if vel.length() > 0.01 else Vector3.FORWARD, Vector3.UP)
			butterflies.multimesh.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * 0.9), p))
