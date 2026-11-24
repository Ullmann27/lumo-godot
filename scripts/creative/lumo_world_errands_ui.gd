extends Node3D
## Small additive World controller: existing residents, existing dialog surface,
## one carried parcel and one optional destination marker. No external assets.

const STATE = preload("res://scripts/creative/lumo_world_errands.gd")

var model = STATE.new()
var world: Node3D
var parcel: Node3D
var destination_marker: Node3D
var animation_time := 0.0
var save_valid := true
var marker_target: Dictionary = {}
var previous_unlocked := false


func setup(owner_world: Node3D, saved: Variant = {}) -> bool:
	world = owner_world
	name = "FriendPost"
	var restored: bool = model.restore(saved)
	save_valid = restored
	if parcel == null:
		_build_visuals()
	_refresh_guidance()
	return restored


func unlocked() -> bool:
	return save_valid and is_instance_valid(world) and world.model.is_complete()


func available(at: Vector3) -> bool:
	return unlocked() and not world.driving and not STATE.friend_at(at).is_empty()


func briefing() -> String:
	return model.summary(int(world.grade), unlocked()) if is_instance_valid(world) else ""


func to_data() -> Dictionary:
	return model.to_data()


func guidance() -> Dictionary:
	return model.guidance(unlocked())


func interact(at: Vector3) -> bool:
	if not available(at) or world.paused:
		return false
	var friend_id := STATE.friend_at(at)
	var friend: Dictionary = STATE.FRIENDS[friend_id]
	var delivery: Dictionary = model.current(int(world.grade))
	if model.is_complete():
		world._open_dialog(str(friend.name) + " · Danke, Lumo!", "Alle drei Lieferungen sind angekommen. Deine Freundschaftsstempel bleiben gespeichert:\n\n" + " · ".join(model.stamps()))
	elif model.carrying():
		if friend_id == str(delivery.recipient):
			world._open_dialog(str(friend.name) + " · Das ist für mich!", "Du hast den Hinweis verstanden und " + str(delivery.parcel) + " zum richtigen Freund gebracht.")
			world.modal_box.add_child(world.KIT.button("Lieferung abgeben", _deliver, 180, Color("1b7d63")))
		else:
			var introduction := "Dein Päckchen bleibt sicher bei dir. Lies den Hinweis noch einmal in Ruhe."
			if friend_id != str(delivery.sender):
				introduction = "Diese Lieferung ist für einen anderen Freund. Du verlierst nichts. Wir finden den richtigen Ort!"
			world._open_dialog(str(friend.name) + " · Ein kleiner Hinweis", introduction + "\n\n" + model.clue(int(world.grade)))
			world.modal_box.add_child(world.KIT.button("Zeige mir den Weg", _show_destination, 180))
	elif friend_id == str(delivery.sender):
		world._open_dialog(str(delivery.title), str(delivery.introduction) + "\n\n" + model.clue(int(world.grade)))
		world.modal_box.add_child(world.KIT.button("Lieferung mitnehmen", _pickup, 180, Color("1b7d63")))
	else:
		var sender: Dictionary = STATE.FRIENDS[str(delivery.sender)]
		world._open_dialog(str(friend.name) + " · Freunde helfen einander", "Besuche " + str(sender.name) + " " + str(sender.place) + ". Dort wartet die nächste Freundepost auf dich.")
	world.modal_box.add_child(world.KIT.button("Weiter erkunden", world._close_dialog, 180))
	return true


func _pickup() -> void:
	if not model.pickup(world.player.position, unlocked()):
		return
	_finish_interaction("Die Lieferung reist jetzt mit dir, auch im Kart. " + model.clue(int(world.grade)))


func _deliver() -> void:
	var delivery: Dictionary = model.current(int(world.grade))
	if not model.deliver(world.player.position, unlocked()):
		return
	_finish_interaction(str(delivery.thanks))


func _show_destination() -> void:
	if not model.show_destination(unlocked()):
		return
	var delivery: Dictionary = model.current(int(world.grade))
	var friend: Dictionary = STATE.FRIENDS[str(delivery.recipient)]
	_finish_interaction("Der helle Brief zeigt dir den Weg zu " + str(friend.name) + " " + str(friend.place) + ".")


func _finish_interaction(message: String) -> void:
	_refresh_guidance()
	world._close_dialog()
	world._update_mission()
	world.status_label.text = message
	if not world._save():
		world.status_label.text = message + " Speichern ist noch nicht möglich. Bitte bleibe in der Welt; wir versuchen es erneut."


func _refresh_guidance() -> void:
	previous_unlocked = unlocked()
	marker_target = model.guidance(previous_unlocked)


func _build_visuals() -> void:
	var paper := _material(Color("e7c785"))
	var ribbon := _material(Color("c55b40"))
	var label := _material(Color("fff6da"))
	parcel = Node3D.new()
	parcel.name = "CarriedFriendPost"
	add_child(parcel)
	_box(parcel, "PaperParcel", Vector3(0.55, 0.42, 0.30), Vector3.ZERO, paper)
	_box(parcel, "RibbonAcross", Vector3(0.56, 0.08, 0.31), Vector3.ZERO, ribbon)
	_box(parcel, "RibbonAround", Vector3(0.08, 0.43, 0.31), Vector3.ZERO, ribbon)
	_box(parcel, "AddressLabel", Vector3(0.19, 0.11, 0.012), Vector3(0.14, 0.095, 0.157), label)
	parcel.visible = false
	destination_marker = Node3D.new()
	destination_marker.name = "FriendPostGuidance"
	add_child(destination_marker)
	var light_paper := _material(Color("fff1b3"), true)
	_box(destination_marker, "Envelope", Vector3(0.70, 0.46, 0.10), Vector3.ZERO, light_paper)
	_box(destination_marker, "EnvelopeSeal", Vector3(0.15, 0.15, 0.12), Vector3.ZERO, ribbon)
	destination_marker.visible = false


static func _material(color: Color, glow := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.82
	if glow:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 0.6
	return result


static func _box(parent: Node3D, mesh_name: String, size: Vector3, at: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


func _process(delta: float) -> void:
	if not is_instance_valid(world) or parcel == null or not is_instance_valid(world.player):
		return
	var ready := unlocked()
	if ready != previous_unlocked:
		_refresh_guidance()
	parcel.visible = ready and model.carrying()
	if parcel.visible:
		if world.driving:
			parcel.global_basis = world.kart_body.global_basis.orthonormalized()
			parcel.global_position = world.kart_body.global_position + parcel.global_basis * Vector3(0, 0.85, 0.85)
		else:
			parcel.global_basis = world.fox.global_basis.orthonormalized()
			parcel.global_position = world.player.global_position + parcel.global_basis * Vector3(0, 1.0, 0.36)
	destination_marker.visible = not marker_target.is_empty()
	if destination_marker.visible:
		if not world.paused and not world.reduced_motion:
			animation_time += minf(delta, 0.1)
			destination_marker.rotation.y = animation_time * 0.7
		var lift := 0.0 if world.reduced_motion else sin(animation_time * 2.0) * 0.12
		destination_marker.global_position = world.to_global(marker_target.at + Vector3.UP * (3.3 + lift))
