extends "res://scripts/creative/lumo_world_open_world.gd"
## Uses established landmarks and the shared route/dialog engine. The purchase
## is a one-off step. Its receipt, display props and budget follow saved progress.
const CONTENT := "res://assets/creative/lumo_world/sternenstadt/auftraege.json"
const AREA := Rect2(175, -76, 100, 87)
const REACH := 3.4
const BUDGET := 6
const STOCK: Array[Dictionary] = [
	{"name": "Zwei Äpfel", "price": 2},
	{"name": "Kleine Laterne", "price": 4},
	{"name": "Stifte", "price": 5},
]
const LANTERN := 1
const CITY_GREEN := Color("559d84")
const WARM := Color("ffe3a2")
var shop_caption: Label3D


func _init() -> void:
	model = QUESTS.new(JSON.parse_string(FileAccess.get_file_as_string(CONTENT)))


func setup(owner_world: Node3D, saved: Variant = {}) -> bool:
	routines.configure(model.content.get("routines", {}))
	var valid := super.setup(owner_world, saved)
	name = "SternenstadtAuftraege"
	return valid


func region_contains(at: Vector3) -> bool:
	return AREA.has_point(Vector2(at.x, at.z))


func tick(at: Vector3, driving: bool, delta: float) -> void:
	if not region_contains(at):
		return
	routines.elapsed = world.open_world.routines.elapsed
	super.tick(at, driving, delta)


func _build_paths() -> void:
	# The route is over existing roads. The atlas uses the same route data.
	pass


func _build_places() -> void:
	var booth := _static(self, "StadtmarktStand")
	booth.position = model.place("stadt_stand").position + Vector3(0, 0, -1.6)
	_solid(booth, Vector3(0, 0.44, 0), Vector3(3.4, 0.88, 1.0), Color.WHITE).material_override = ADVENTURE.material("wood")
	for x in [-1.55, 1.55]:
		kit.cylinder(booth, Vector3(x, 1.59, -0.47), 0.065, 1.74, Color("966c50"), 9)
	for stripe in range(9):
		var cloth := kit.box(booth, Vector3(-1.6 + float(stripe) * 0.4, 2.48, 0), Vector3(0.4, 0.06, 1.35), CITY_GREEN if stripe % 2 == 0 else Color("eee1ba"))
		cloth.rotation.x = -0.08
	for index in range(2):
		kit.sphere(booth, Vector3(-0.95 + float(index) * 0.20, 1.05, 0.1), Vector3.ONE * 0.20, Color("be5b46"))
	kit.cylinder(booth, Vector3(0, 1.05, 0.1), 0.16, 0.32, Color("c68138"), 12)
	kit.sphere(booth, Vector3(0, 1.07, 0.1), Vector3(0.25, 0.14, 0.25), WARM, true)
	for index in range(4):
		kit.box(booth, Vector3(0.63 + float(index) * 0.09, 0.95, 0.06), Vector3(0.042, 0.042, 0.36), [CITY_GREEN, WARM, Color("a15c54"), Color("487a93")][index])
	shop_caption = world.art._sign(self, "Aminas Marktstand", booth.position + Vector3.UP * 2.99, WARM)
	shop_caption.font_size = 34
	shop_caption.visibility_range_end = 28.0
	for pair in [
		["klinik_tor", Vector3(-1.5, 0, -2)],
		["markt_passage", Vector3(1.3, 0, -3)],
		["park_eingang", Vector3(2.4, 0, -3)],
	]:
		var place := model.place(str(pair[0]))
		var at: Vector3 = place.position + pair[1]
		var label: Label3D = world.art._sign(self, str(place.title), at + Vector3.UP * 2.5, WARM)
		label.font_size = 27
		label.visibility_range_end = 23.0
		kit.cylinder(self, at + Vector3.UP * 0.9, 0.066, 1.8, Color("97714e"), 9)


func purchase_receipt() -> Dictionary:
	if int(model.progress.get("marktlicht", 0)) < 2:
		return {}
	var price := int(STOCK[LANTERN].price)
	return {"item": str(STOCK[LANTERN].name), "paid": price, "remaining": BUDGET - price}


func refresh() -> void:
	super.refresh()
	if is_instance_valid(shop_caption) and not purchase_receipt().is_empty():
		shop_caption.text = "Laterne abgeholt · 2 Marken übrig"


func _active_work(at: Vector3) -> String:
	if not unlocked() or world.driving:
		return ""
	for id in ["parkblick", "marktlicht"]:
		var step := model.current_step(id)
		if str(step.get("kind", "")) == "event":
			var target := model.step_target(step)
			if at.distance_squared_to(target) <= REACH * REACH:
				return id
	return ""


func available(at: Vector3) -> bool:
	return not _active_work(at).is_empty() or super.available(at)


func action_label(at: Vector3) -> String:
	match _active_work(at):
		"parkblick":
			return "Bänke ansehen"
		"marktlicht":
			return "Marktstand öffnen"
	return "Ansprechen" if super.available(at) else ""


func interact(at: Vector3) -> bool:
	if not unlocked() or world.driving or world.paused:
		return false
	var id := _active_work(at)
	if id.is_empty():
		return super.interact(at)
	_show_work(id)
	return true


func _show_work(id: String, help := "") -> void:
	if id == "parkblick":
		world._open_dialog("Freundschaftspark", "Schau beim Holztisch nach: Wie viele Bänke stehen direkt daran?" + help)
		for count in range(1, 4):
			var choice := KIT.button("%d" % count, _submit.bind(id, count), 170)
			choice.name = "ParkBaenke_%d" % count
			world.modal_box.add_child(choice)
	else:
		world._open_dialog("Aminas Marktstand", "Du hast %d Auftragsmarken. Wähle den Artikel für den Parkeingang." % BUDGET + help)
		for index in range(STOCK.size()):
			var offer := STOCK[index]
			var choice := KIT.button("%s · %d Marken" % [str(offer.name), int(offer.price)], _submit.bind(id, index), 175)
			choice.name = "StadtWare_%d" % index
			world.modal_box.add_child(choice)
	world.modal_box.add_child(KIT.button("Weiter erkunden", world._close_dialog, 175, CITY_GREEN))


func _submit(id: String, option: int) -> void:
	if not world.paused or _active_work(world.player.position) != id:
		return
	if option != (2 if id == "parkblick" else LANTERN):
		var clue := "Zähle am Tisch die beiden langen Sitze." if id == "parkblick" else "Die Marken sind für die Laterne. Dein Guthaben bleibt bei sechs."
		_show_work(id, "\n\n" + clue)
		return
	var event := "parkbank_gezaehlt" if id == "parkblick" else "stadt_laterne_gekauft"
	var applied := model.notify_event(event)
	if applied.size() != 1:
		return
	world._close_dialog()
	var message := _step_message(id, false)
	if id == "marktlicht":
		var receipt := purchase_receipt()
		message = "Laterne gekauft. %d Marken bezahlt, %d Marken übrig. Berichte Amina davon." % [receipt.paid, receipt.remaining]
	_commit(message)
	world.fox.gesture("celebrate")


func append_journal() -> void:
	world.modal_box.add_child(KIT.label("Sternenstadt", 21))
	world.modal_box.add_child(KIT.button("Sternenstadt-Aufträge und Album", open_from_world, 192, CITY_GREEN))


func open_from_world() -> void:
	world._close_dialog()
	open_journal()
