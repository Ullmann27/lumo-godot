extends Node3D
## Wenige echte Lichter fuer viele Leuchten: die naechsten Laternen vor der Kamera
## bekommen ein OmniLight3D, alle anderen leuchten nur ueber Emission/Lichtkarten.
## Anzahl je Profil (LOW 0, MEDIUM 2, HIGH 4, ULTRA 8). Keine Schatten.

var heads := PackedVector3Array()
var colors: Array[Color] = []
var lights: Array[OmniLight3D] = []
var energy: float = 1.0
var light_range: float = 11.0
var _timer: float = 0.0


func setup(points: PackedVector3Array, tints: Array[Color], count: int, power: float, reach: float) -> void:
	heads = points
	colors = tints
	energy = power
	light_range = reach
	for i in range(count):
		var light := OmniLight3D.new()
		light.name = "LampLight%d" % i
		light.omni_range = light_range
		light.omni_attenuation = 1.4
		light.light_energy = energy
		light.shadow_enabled = false
		light.light_specular = 0.6
		light.visible = false
		lights.append(light)
		add_child(light)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or lights.is_empty():
		return
	_timer = 0.12
	refresh()


## Ordnet die Lichter den naechsten Laternen vor der Kamera zu.
func refresh() -> void:
	var viewport := get_viewport()
	var camera: Camera3D = viewport.get_camera_3d() if viewport != null else null
	if camera == null:
		return
	var eye: Vector3 = camera.global_position
	var ahead: Vector3 = -camera.global_transform.basis.z
	var best: Array = []
	for i in range(heads.size()):
		var offset: Vector3 = heads[i] - eye
		var dist: float = offset.length()
		if dist > 70.0:
			continue
		# Leuchten vor der Kamera zaehlen mehr als solche hinter ihr.
		var score: float = dist * (1.0 if offset.dot(ahead) > -2.0 else 2.5)
		best.append([score, i])
	best.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in range(lights.size()):
		var light: OmniLight3D = lights[k]
		if k < best.size():
			var index: int = best[k][1]
			light.global_position = heads[index] - Vector3.UP * 0.35
			light.light_color = colors[index]
			light.visible = true
		else:
			light.visible = false
