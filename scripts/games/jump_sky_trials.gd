extends Node3D
## Physical crossing tests use the same transforms as the three Blender props.
## Marks survive a fall. Boosts and the short brush against a comet are local
## to an attempt and leave the main route, currency and learning stops intact.
const SUN = preload("res://assets/games/jump/sun_ring.glb")
const PAD = preload("res://assets/games/jump/wind_pad.glb")
const BAR = preload("res://assets/games/jump/comet_bar.glb")
const OPENING := [
	"Spring durch den Sonnenring!",
	"Spring vom Pfeilbrett in den Windring!",
	"Spring über den Schweif des Kometen!",
]
var rings: Array[Node3D] = []
var pads: Array[Node3D] = []
var bars: Array[Node3D] = []
var stamps: Dictionary = {}
var boost := 0.0
var stumble := 0.0
var clock := 0.0
var course := 0
signal contact(cue: String, sound: String)


func build(islands: Array[Vector3], course_index: int) -> void:
	course = course_index
	var sections := [0, 1, 2, 4, 5, 7, 8, 10]
	for index: int in sections:
		var origin := islands[index]
		var mid := origin.lerp(islands[index + 1], .51)
		if index == 0:
			mid.x = origin.x
		var side := 0.0 if index == 0 else (1.0 if index % 2 else -1.0)
		if course == 2 and index not in [2, 5, 8]:
			var bar := _prop(BAR, "Komet", index, origin + Vector3(side * .55, .97, -.38))
			bars.append(bar)
		else:
			var high := course == 1 and index not in [1, 5, 8]
			if high:
				var pad := _prop(PAD, "Windbrett", index, origin + Vector3(side * .8, .33, -1.6))
				pads.append(pad)
			var ring := _prop(SUN, "Sonnenring", index, mid + Vector3(side * .94, 3.35 if high else 2.39, 0))
			rings.append(ring)


func _prop(model: PackedScene, prefix: String, index: int, at: Vector3) -> Node3D:
	var prop: Node3D = model.instantiate()
	prop.name = prefix + str(index)
	prop.position = at
	prop.set_meta("anchor", at)
	add_child(prop)
	return prop


func step(delta: float) -> void:
	boost = maxf(0.0, boost - delta)
	stumble = maxf(0.0, stumble - delta)
	clock += delta
	for ring in rings:
		var at: Vector3 = ring.get_meta("anchor")
		if course == 1:
			ring.position.x = at.x + .75 * sin(clock * 1.55 + at.z)
		ring.rotation.z = .075 * sin(clock * 2.4 + at.z)
	for bar in bars:
		var at: Vector3 = bar.get_meta("anchor")
		bar.position.x = at.x + 1.04 * sin(clock * 1.85 + at.z)
		bar.position.y = at.y + .15 * sin(clock * 2.2 + at.z)


func launch_speed(at: Vector3, ordinary: float) -> float:
	for pad in pads:
		var local := at - pad.position
		if absf(local.x) < 1.03 and absf(local.z) < 1.1 and absf(local.y) < .45:
			contact.emit("Aufwind! Ziele auf den Ring.", "whoosh")
			return 10.75
	return ordinary


func crossed(before: Vector3, after: Vector3) -> void:
	if before.z <= after.z:
		return
	for ring in rings:
		if not ring.visible or not _crossed_z(ring.position.z, before, after):
			continue
		var torso := _crossing(ring.position.z, before, after) + Vector3.UP * .68
		if Vector2(torso.x - ring.position.x, torso.y - ring.position.y).length() <= 1.24:
			boost = .68
			_stamp(ring, "Ring getroffen! Rückenwind!", "coin")
	for bar in bars:
		if not bar.visible or not _crossed_z(bar.position.z, before, after):
			continue
		var feet := _crossing(bar.position.z, before, after)
		if absf(feet.x - bar.position.x) > 1.85:
			continue
		if feet.y > bar.position.y + .12:
			_stamp(bar, "Komet übersprungen!", "star_collected")
		else:
			stumble = .25
			contact.emit("Streifschuss! Lauf gleich weiter.", "piece_drop")


func _crossed_z(z: float, before: Vector3, after: Vector3) -> bool:
	return before.z > z and after.z <= z


func _crossing(z: float, before: Vector3, after: Vector3) -> Vector3:
	return before.lerp(after, (before.z - z) / (before.z - after.z))


func _stamp(prop: Node3D, cue: String, sound: String) -> void:
	stamps[str(prop.name)] = true
	prop.hide()
	contact.emit(cue, sound)


func restore(saved: Dictionary) -> void:
	stamps = saved.duplicate()
	for prop in rings + bars:
		prop.visible = not stamps.has(str(prop.name))


func count_marks() -> int:
	return rings.size() + bars.size()
