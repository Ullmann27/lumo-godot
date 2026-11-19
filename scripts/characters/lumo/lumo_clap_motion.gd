extends Node
## Lumo klatscht: eine Klatsch-Bewegung über die vorhandenen Armknochen des
## Originalmodells (UpperArm/Forearm links und rechts). Das Modell hat keinen
## Klatsch-Clip; dieser Knoten ergänzt ihn, ohne Modell, Skelett oder Clips zu
## ersetzen. Er läuft nach dem Charakter (process_priority), legt seine Pose
## über die gerade abgespielte Animation und gibt die Arme danach unverändert
## zurück. Zweigelenk-IK: Schulter bleibt, Ellbogen zeigt nach unten-außen,
## die Handflächen treffen sich vor der Brust – je Silbe ein Klatscher.
## Ruhige Bewegung: Die Hände legen sich einmal ruhig zusammen und bleiben dort.

signal clapped(index: int)

const SIDES := {"L": 1.0, "R": -1.0}
## Hände vor der Brust: Höhe und Abstand nach vorn (Skelett-Einheiten des
## Originalmodells, Körperhöhe ≈ 1,46).
const CHEST_HEIGHT := 0.98
const CHEST_FORWARD := 0.3
const OPEN_GAP := 0.44
const TOUCH_GAP := 0.035
const RAISE := 0.28
const LOWER := 0.35

var skeleton: Skeleton3D
var bones: Dictionary = {}
var active := false
var calm := false
var hold := false
var suspended := false
var count := 0
var interval := 0.5
var clock := 0.0
var fired := 0
var weight := 0.0
var _base: Dictionary = {}
var _written: Dictionary = {}


func _init() -> void:
	name = "LumoKlatschen"
	# Nach dem Charakter: erst spielt der Clip, dann legen wir die Arme an.
	process_priority = 1000


func bind(target: Skeleton3D) -> bool:
	if target == null:
		return false
	for bone in [
		"Chest",
		"UpperArm.L",
		"Forearm.L",
		"Wrist.L",
		"Hand.L",
		"UpperArm.R",
		"Forearm.R",
		"Wrist.R",
		"Hand.R"
	]:
		var index := target.find_bone(bone)
		if index < 0:
			return false
		bones[bone] = index
	skeleton = target
	return true


## Klatscht `beats`-mal im Abstand `seconds`. Ruhig: Hände legen sich einmal
## zusammen und bleiben, bis stop() kommt.
func start(beats: int, seconds: float, quiet: bool) -> void:
	if skeleton == null:
		return
	count = clampi(beats, 1, 8)
	interval = clampf(seconds, 0.3, 1.2)
	calm = quiet
	hold = quiet
	clock = 0.0
	fired = 0
	active = true
	if calm:
		weight = 1.0
		_apply(1.0, TOUCH_GAP * 2.0)
		for index in range(count):
			fired += 1
			clapped.emit(index)


func stop() -> void:
	active = false
	hold = false
	_restore()
	weight = 0.0


func duration() -> float:
	return RAISE + interval * (count - 1) + 0.25 + LOWER


func is_clapping() -> bool:
	return active


## Abstand der Handflächen in Weltmetern (für Tests und Bildprüfung).
func hand_gap() -> float:
	if skeleton == null:
		return INF
	var left := skeleton.to_global(skeleton.get_bone_global_pose(int(bones["Hand.L"])).origin)
	var right := skeleton.to_global(skeleton.get_bone_global_pose(int(bones["Hand.R"])).origin)
	return left.distance_to(right)


func _process(delta: float) -> void:
	if not active or skeleton == null:
		return
	if calm:
		# Die Pose bleibt stehen, auch wenn der Charakter neu abtastet.
		_restore_if_untouched()
		_apply(1.0, TOUCH_GAP * 2.0)
		return
	if not suspended:
		clock += minf(delta, 0.1)
	var end := duration()
	if clock >= end:
		stop()
		return
	weight = clampf(minf(clock / RAISE, (end - clock) / LOWER), 0.0, 1.0)
	weight = weight * weight * (3.0 - 2.0 * weight)
	# Je Silbe ein Klatscher: Hände treffen sich, bleiben kurz zusammen
	# (auch bei langsamen Bildern sichtbar) und gehen wieder auseinander.
	var pulse := 0.0
	var hit := -1
	for beat in range(count):
		var offset := absf(clock - (RAISE + beat * interval))
		pulse = maxf(pulse, 1.0 if offset < 0.06 else exp(-pow((offset - 0.06) / 0.09, 2.0)))
		if fired == beat and clock >= RAISE + beat * interval - 0.03:
			hit = beat
	_restore_if_untouched()
	_apply(weight, lerpf(OPEN_GAP, TOUCH_GAP, pulse))
	if hit >= 0:
		fired += 1
		clapped.emit(hit)


## Hat der Clip die Armknochen in diesem Bild nicht neu gesetzt (konstante
## Spuren werden übersprungen), stellt er unsere letzte Pose nicht zurück –
## dann tun wir es, sonst würde sich die Bewegung aufaddieren.
func _restore_if_untouched() -> void:
	for index in _written:
		var now := skeleton.get_bone_pose_rotation(index)
		if now.is_equal_approx(_written[index]):
			skeleton.set_bone_pose_rotation(index, _base[index])
	_written.clear()
	skeleton.force_update_all_bone_transforms()


func _restore() -> void:
	if skeleton == null:
		return
	_restore_if_untouched()
	_base.clear()


func _apply(amount: float, gap: float) -> void:
	if amount <= 0.001:
		return
	var chest := skeleton.get_bone_global_pose(int(bones.Chest)).origin
	var center := Vector3(chest.x, CHEST_HEIGHT, chest.z + CHEST_FORWARD)
	for side: String in SIDES:
		var sign_value: float = SIDES[side]
		var upper := int(bones["UpperArm." + side])
		var fore := int(bones["Forearm." + side])
		var hand := int(bones["Hand." + side])
		_remember(upper)
		_remember(fore)
		var shoulder := skeleton.get_bone_global_pose(upper).origin
		var elbow := skeleton.get_bone_global_pose(fore).origin
		var palm := skeleton.get_bone_global_pose(hand).origin
		var goal := palm.lerp(center + Vector3(sign_value * gap * 0.5, 0, 0), amount)
		var upper_length := shoulder.distance_to(elbow)
		var lower_length := elbow.distance_to(palm)
		var reach := clampf(
			shoulder.distance_to(goal),
			absf(upper_length - lower_length) + 0.002,
			(upper_length + lower_length) * 0.995
		)
		var direction := (goal - shoulder).normalized()
		var cos_a := clampf(
			(
				(upper_length * upper_length + reach * reach - lower_length * lower_length)
				/ (2.0 * upper_length * reach)
			),
			-1.0,
			1.0
		)
		# Ellbogen nach unten, etwas nach außen und hinten.
		var pole := Vector3(sign_value * 0.6, -1.0, -0.35)
		var across := (pole - direction * pole.dot(direction)).normalized()
		var new_elbow := (
			shoulder
			+ (direction * cos_a + across * sqrt(maxf(0.0, 1.0 - cos_a * cos_a))) * upper_length
		)
		_turn(upper, elbow - shoulder, new_elbow - shoulder)
		var moved_elbow := skeleton.get_bone_global_pose(fore).origin
		var moved_palm := skeleton.get_bone_global_pose(hand).origin
		_turn(fore, moved_palm - moved_elbow, shoulder + direction * reach - moved_elbow)
	for index in _base:
		_written[index] = skeleton.get_bone_pose_rotation(index)


## Merkt die abgetastete Clip-Pose (nach dem Zurückstellen) als Ausgangslage.
func _remember(index: int) -> void:
	_base[index] = skeleton.get_bone_pose_rotation(index)


## Dreht den Knochen (Skelettraum) so, dass `from` auf `to` zeigt.
func _turn(index: int, from: Vector3, to: Vector3) -> void:
	if from.length() < 0.0001 or to.length() < 0.0001:
		return
	var rotation := Quaternion(from.normalized(), to.normalized())
	var bone_basis := skeleton.get_bone_global_pose(index).basis.orthonormalized()
	var parent := skeleton.get_bone_parent(index)
	var parent_basis := (
		skeleton.get_bone_global_pose(parent).basis.orthonormalized()
		if parent >= 0
		else Basis.IDENTITY
	)
	var local := (parent_basis.inverse() * (Basis(rotation) * bone_basis)).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(index, local.normalized())
	skeleton.force_update_all_bone_transforms()
