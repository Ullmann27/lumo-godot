extends SceneTree
## Runs the real optional controller with a small World-shaped fixture. This
## verifies callbacks, carried meshes and saving; it is not a full World render.

const CONTROLLER = preload("res://scripts/creative/lumo_world_errands_ui.gd")
const POST = preload("res://scripts/creative/lumo_world_errands.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
var checks := 0
var failures: Array[String] = []


class ButtonKit extends RefCounted:
	static func button(text: String, action: Callable, width := 82.0, _color := Color.TRANSPARENT) -> Button:
		var control := Button.new()
		control.text = text
		control.custom_minimum_size = Vector2(width, 48)
		control.pressed.connect(action)
		return control


class Chapter extends RefCounted:
	var complete := false
	func is_complete() -> bool:
		return complete


class WorldFixture extends Node3D:
	const KIT = ButtonKit
	var model = Chapter.new()
	var grade := 2
	var player := CharacterBody3D.new()
	var fox := Node3D.new()
	var kart_body := CharacterBody3D.new()
	var driving := false
	var paused := false
	var reduced_motion := true
	var modal_box := VBoxContainer.new()
	var status_label := Label.new()
	var save_success := true
	var saved: Dictionary = {}
	var post: Node3D
	var dialog_title := ""
	var dialog_body := ""
	var briefing_text := ""
	func _ready() -> void:
		add_child(player)
		player.add_child(fox)
		add_child(kart_body)
		add_child(modal_box)
		add_child(status_label)
	func _open_dialog(title: String, text: String) -> void:
		dialog_title = title
		dialog_body = text
		paused = true
		for child in modal_box.get_children():
			child.free()
	func _close_dialog() -> void:
		paused = false
	func _update_mission() -> void:
		briefing_text = post.briefing()
	func _save() -> bool:
		if save_success:
			saved = post.to_data()
		return save_success


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		push_error("[LumoWorldErrandsController] " + description)


func _press(world: WorldFixture, text: String) -> void:
	for child in world.modal_box.get_children():
		if child is Button and child.text == text:
			_check(child.custom_minimum_size.y >= 48, "delivery action keeps a 48px touch target")
			child.pressed.emit()
			return
	_check(false, "required interaction button is reachable: " + text)


func _world(saved: Dictionary = {}) -> WorldFixture:
	var world := WorldFixture.new()
	root.add_child(world)
	world.post = CONTROLLER.new()
	world.add_child(world.post)
	world.post.setup(world, saved)
	return world


func _run() -> void:
	var world := _world()
	world.player.position = POST.FRIENDS.nelli.at
	_check(not world.post.available(world.player.position), "chapter locks resident errands")
	world.model.complete = true
	world.post._process(0)
	_check(world.post.destination_marker.visible and not world.post.parcel.visible, "unlocked chapter displays first pickup marker only")
	_check(world.post.interact(world.player.position), "actual controller opens the resident offer")
	_press(world, "Lieferung mitnehmen")
	world.post._process(0)
	_check(world.post.model.carrying() and world.post.parcel.visible, "pickup callback shows real carried parcel geometry")
	_check(not world.post.destination_marker.visible, "pickup keeps the destination a reading puzzle")
	_check(world.saved.active == "seeds_for_bruno", "pickup callback writes the pending delivery")
	world.driving = true
	world.kart_body.position = Vector3(101, 0.2, 18)
	world.kart_body.rotation.y = PI * 0.5
	world.post._process(0)
	_check(world.post.parcel.global_position.distance_to(world.kart_body.global_position) < 2.0, "the same parcel travels with the Kart")
	_check(not world.post.available(world.player.position), "driving cannot initiate resident dialogue")
	world.driving = false
	world.player.position = POST.FRIENDS.tilda.at
	world.post._process(0)
	_check(world.post.interact(world.player.position), "wrong recipient still offers gentle help")
	_check(world.post.model.carrying(), "wrong recipient leaves parcel intact")
	_press(world, "Zeige mir den Weg")
	world.post._process(0)
	_check(world.post.destination_marker.visible and world.post.guidance().at == POST.FRIENDS.bruno.at, "requested hint activates the correct physical destination")
	world.player.position = POST.FRIENDS.bruno.at
	world.save_success = false
	world.post.interact(world.player.position)
	_press(world, "Lieferung abgeben")
	world.post._process(0)
	_check(world.post.model.completed.size() == 1 and not world.post.parcel.visible, "handover removes parcel and records one stamp in memory")
	_check("Speichern ist noch nicht möglich" in world.status_label.text, "save failure is visible rather than silently treated as persisted")
	_check(world.saved.completed.is_empty(), "failed storage does not claim a persisted stamp")
	world.save_success = true
	_check(world._save(), "World can retry the unchanged delivery state")
	var restored := _world(JSON.parse_string(JSON.stringify(world.saved)))
	restored.model.complete = true
	restored.post._process(0)
	_check(restored.post.model.stamps() == ["Gartenfreund"], "saved friendship stamp survives a controller restart")
	_check(not restored.post.parcel.visible and restored.post.guidance().at == POST.FRIENDS.bruno.at, "restart displays next sender without stale parcel")
	var corrupt := _world({"version": 10, "completed": []})
	corrupt.model.complete = true
	_check(not corrupt.post.save_valid and not corrupt.post.available(POST.FRIENDS.nelli.at), "unknown saved version disables only the additive errands")
	world.queue_free()
	restored.queue_free()
	corrupt.queue_free()
	await process_frame
	await process_frame
	_check(await TEARDOWN.release_audio(self, root, "[LumoWorldErrandsController]"), "autoload click playback releases before exit")
	print("[LumoWorldErrandsController] %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
