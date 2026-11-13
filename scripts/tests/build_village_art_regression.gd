extends SceneTree
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const RESIDENTS = preload("res://scripts/creative/build_settlement_residents.gd")
const VISUAL = preload("res://scripts/creative/build_settlement_visual.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_warning(message)


func _legacy_coordinate(index: int) -> Vector2i:
	if index < 9:
		return Vector2i(index % 3 - 1, index / 3 - 1)
	if index < 13:
		return Vector2i(2, index - 10)
	if index < 16:
		return Vector2i(index - 14, 2)
	if index < 21:
		return Vector2i(-2, index - 18)
	return Vector2i(index - 22, -2)


func _run() -> void:
	var coordinates: Dictionary = {}
	for index in range(REGION.MAX_PLOTS):
		var point := REGION.plot_coordinate(index)
		_check(not coordinates.has(point), "Every plot has one unique address: " + str(index))
		_check(absi(point.x) <= 16 and absi(point.y) <= 16, "Plot inside 33x33 bounds")
		coordinates[point] = true
		if index < 25:
			_check(point == _legacy_coordinate(index), "Existing save keeps plot address: " + str(index))
	_check(coordinates.size() == 1089, "Full contiguous 1089-cell district")
	_check(REGION.extent_for_plots(1089) < REGION.HALF_EXTENT, "Largest building district fits walkable land")
	var region = REGION.new()
	root.add_child(region)
	region.build_landscape("rival")
	_check(int(region.get_meta("scenery_chunks")) == 32, "Two towns have bounded 4x4 decoration chunks")
	_check(region.find_children("VillageRiverBridge*", "StaticBody3D", false, false).size() == 3, "Three real bridge collision bodies")
	var collision := region.get_node("PlayerLand").find_children("*", "CollisionShape3D", true, false)
	_check(not collision.is_empty(), "Walkable player land collision exists")
	for kind in ["house", "farm", "lumber", "quarry", "market", "school", "well", "grain", "bakery", "road", "clinic"]:
		var building = VISUAL.create(kind)
		root.add_child(building)
		_check(building.find_children("*", "MeshInstance3D", true, false).size() > 0, "Real merged geometry: " + kind)
		_check(building.find_children("*", "CollisionShape3D", true, false).size() > 0, "Real collider: " + kind)
		_check(str(building.get_meta("facility_kind")) == kind, "Facility identity: " + kind)
		building.free()
	var families: Array = []
	var buildings: Array = []
	for index in range(30):
		var id := "b" + str(index)
		buildings.append({"id": id, "kind": "house", "plot": index})
		families.append({"building_id": id, "adults": 2, "children": 1, "supplied_days": 12})
	buildings.append({"id": "market", "kind": "market", "plot": 31})
	var town := {"population": 90, "buildings": buildings, "households": families, "deliveries": [{"remaining": 1}]}
	var original := town.duplicate(true)
	var residents = RESIDENTS.new()
	root.add_child(residents)
	residents.sync(town, false)
	await process_frame
	_check(int(residents.debug_snapshot().visible_residents) == RESIDENTS.MAX_VISIBLE_RESIDENTS, "Large population is represented by capped real crowd")
	_check(bool(residents.debug_snapshot().has_delivery_cart), "Market has visible merchant and cart")
	_check(town == original, "Renderer never mutates economic or family state")
	var first_actor: Node3D = residents.get_node("VillageFamilies").get_child(0)
	var first_id := first_actor.get_instance_id()
	residents.sync(town, false)
	_check(residents.get_node("VillageFamilies").get_child(0).get_instance_id() == first_id, "Unchanged model reuses resident nodes")
	var before := first_actor.position
	residents.advance(0.10, true)
	_check(first_actor.position == before and float(residents.debug_snapshot().clock) == 0.0, "Pause stops crowd and delivery clock")
	residents.advance(0.10, false)
	_check(first_actor.position != before, "Residents move on actual visual update")
	for friend_scene in RESIDENTS.FRIENDS:
		var friend: Node3D = friend_scene.instantiate()
		root.add_child(friend)
		var skeleton := friend.find_child("Skeleton3D", true, false) as Skeleton3D
		var player := friend.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_check(skeleton != null and skeleton.get_bone_count() == 7, "Original village friend has actual seven-bone rig")
		_check(player != null and player.get_animation_list().size() >= 1, "Village friend has imported animation")
		var mesh_count := 0
		for mesh in friend.find_children("*", "MeshInstance3D", true, false):
			mesh_count += 1
			_check(mesh.mesh.get_surface_count() == 1, "Each friend uses one material surface")
		_check(mesh_count == 1, "Each friend uses one skinned mesh")
		friend.free()
	residents.free()
	region.free()
	await process_frame
	print("[VillageArt] ", checks, " checks / ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
