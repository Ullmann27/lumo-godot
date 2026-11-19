extends SceneTree
## Every rival figure is a real rigged animal like Lumo: one skeleton with the
## body and face bones, the clips race, garage and table call, three detail
## levels that really get lighter, and source files within the mobile budget.

const DRIVER = preload("res://scripts/games/kart_production_driver.gd")
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const CONTRACT = preload("res://scripts/games/kart_rival_model_contract.gd")
const CLIPS := [
	"idle",
	"kart_seated",
	"kart_steer_left",
	"kart_steer_right",
	"kart_jump",
	"celebrate",
	"kart_celebrate",
	"kart_hit",
	"greeting_wave",
	"agree_nod",
	"point_portal",
	"card_play",
]
const FACE_BONES := ["Jaw", "Eye.L", "Eye.R", "Lid.L", "Lid.R"]
const MAX_FILE_BYTES := 1572864
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[RivalRig] " + message)


func _bone_moves(animation: Animation, track_path: String) -> bool:
	for track in range(animation.get_track_count()):
		if str(animation.track_get_path(track)) != track_path:
			continue
		if (
			animation.track_get_type(track) != Animation.TYPE_ROTATION_3D
			or animation.track_get_key_count(track) < 2
		):
			continue
		var first: Quaternion = animation.track_get_key_value(track, 0)
		for key in range(1, animation.track_get_key_count(track)):
			var value: Quaternion = animation.track_get_key_value(track, key)
			if absf(first.dot(value)) < 0.99995:
				return true
	return false


## Signed volume with Godot's clockwise front faces. A skin that was exported
## inside out is negative: the camera then sees the inner back of the head and
## the light muzzle and inner ears vanish although the vertex colours exist.
func _enclosed_volume(mesh: Mesh) -> float:
	var total := 0.0
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			var a := vertices[indices[t]]
			total += a.dot(vertices[indices[t + 2]].cross(vertices[indices[t + 1]]))
	return total / 6.0


func _level(id: String, level: int) -> int:
	var path := ROSTER.racing_model_path(id, level)
	_check(not path.is_empty(), "Authored LOD path: %s/%d" % [id, level])
	if path.is_empty():
		return -1
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		_check(
			file.get_length() <= MAX_FILE_BYTES,
			"File within 1.5 MB: %s (%d bytes)" % [path, file.get_length()]
		)
		file.close()
	var packed := load(path) as PackedScene
	_check(packed != null, "Imported scene: " + path)
	if packed == null:
		return -1
	var model := packed.instantiate()
	var verified: Dictionary = CONTRACT.inspect(model)
	_check(
		bool(verified.get("valid", false)),
		"Kart rival contract accepts " + path + " " + str(verified.get("reason", ""))
	)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	_check(
		skeletons.size() == 1 and players.size() == 1,
		"One skeleton and one animation player: " + path
	)
	var triangles := int(verified.get("triangles", -1))
	if skeletons.size() == 1 and players.size() == 1:
		var skeleton: Skeleton3D = skeletons[0]
		var player: AnimationPlayer = players[0]
		_check(
			skeleton.get_bone_count() == DRIVER.BONES.size(), "Body and face bones only: " + path
		)
		for bone in DRIVER.BONES:
			_check(skeleton.find_bone(bone) >= 0, "Bone %s in %s" % [bone, path])
		for clip in CLIPS:
			_check(player.has_animation(clip), "Clip %s in %s" % [clip, path])
		if player.has_animation("kart_seated"):
			var seated := player.get_animation("kart_seated")
			var prefix := str(player.get_node(player.root_node).get_path_to(skeleton))
			_check(
				_bone_moves(seated, prefix + ":Lid.L") and _bone_moves(seated, prefix + ":Lid.R"),
				"Seated clip blinks: " + path
			)
			_check(_bone_moves(seated, prefix + ":Eye.L"), "Seated clip moves the eyes: " + path)
		if player.has_animation("celebrate"):
			var prefix2 := str(player.get_node(player.root_node).get_path_to(skeleton))
			_check(
				_bone_moves(player.get_animation("celebrate"), prefix2 + ":Jaw"),
				"Celebration opens the mouth: " + path
			)
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var volume := _enclosed_volume(mesh.mesh)
			_check(
				volume > 0.02, "Skin faces outward (enclosed volume %.3f m3): %s" % [volume, path]
			)
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
				_check(
					material != null and material.cull_mode == BaseMaterial3D.CULL_BACK,
					"Single-sided surfaces: " + path
				)
	model.free()
	return triangles


func _run() -> void:
	var ids: Array[String] = []
	for entry in ROSTER.all():
		ids.append(str(entry.id))
	_check(ids == ["lion", "owl", "rabbit", "squirrel", "turtle", "frog"], "Six roster animals")
	for id in ids:
		var counts: Array[int] = []
		for level in range(3):
			counts.append(_level(id, level))
		_check(
			counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > 0,
			"Three real detail levels for %s: %s" % [id, str(counts)]
		)
		_check(counts[0] <= 30000, "LOD0 within the phone budget for %s: %d" % [id, counts[0]])
		print("[RivalRig] ", id, " triangles ", counts)
	print("[RivalRig] checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
