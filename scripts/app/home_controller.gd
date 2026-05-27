## HomeController - Hauptszene nach Intro.
##
## Instanziiert Lumo-Companion + 3 Portale + MultiMesh-Sternenfeld +
## Billboard-Decorations. Wendet das generierte Insel-Material aus dem
## AssetLoader auf die Bodenplane an. Lauscht auf EventBus.portal_selected.
extends Node3D

const COMPANION_SCENE: PackedScene = preload("res://scenes/characters/lumo/lumo_character.tscn")
const PORTAL_SCENE: PackedScene = preload("res://scenes/hub/hub_portal.tscn")
const STAR_FIELD_SCENE: PackedScene = preload("res://scenes/hub/star_field.tscn")

const PORTAL_LAYOUT: Array = [
	{"type": "learn", "position": Vector3(-3.0, 0.6, 0.5)},
	{"type": "games", "position": Vector3(0.0, 1.6, -2.0)},
	{"type": "parent", "position": Vector3(3.0, 0.6, 0.5)},
]

const BILLBOARD_MATERIAL_IDS: Array[String] = [
	"mat_billboard_crystal",
	"mat_billboard_book",
]


func _ready() -> void:
	EventBus.portal_selected.connect(_on_portal_selected)
	_apply_island_material()
	_apply_sky_backdrop()
	_spawn_companion()
	_spawn_portals()
	_spawn_star_field()
	_spawn_billboards()
	await get_tree().process_frame
	EventBus.scene_loaded.emit("home_3d")
	print("[Home] scene_loaded")


## Wendet das generierte Stone-Warm Material auf die Insel-Plane an.
func _apply_island_material() -> void:
	var island: MeshInstance3D = $Island as MeshInstance3D
	if island == null:
		return
	var mat: Material = AssetLoader.get_material("mat_stone_warm")
	if mat != null:
		island.material_override = mat


## Wendet einen Sky-Gradient auf die optionale Backdrop-Plane an.
func _apply_sky_backdrop() -> void:
	var backdrop: MeshInstance3D = get_node_or_null("Backdrop") as MeshInstance3D
	if backdrop == null:
		return
	var mat: Material = AssetLoader.get_material("mat_sky_backdrop")
	if mat != null:
		backdrop.material_override = mat


func _spawn_companion() -> void:
	var companion: Node3D = COMPANION_SCENE.instantiate() as Node3D
	companion.position = Vector3(0.0, 0.0, 0.0)
	add_child(companion)
	# Begruessung ausloesen sobald LUMO bereit ist - geht ueber EventBus
	# damit wir hier nicht direkt auf den Knoten zugreifen muessen.
	EventBus.companion_ready.connect(_on_companion_ready, CONNECT_ONE_SHOT)


func _on_companion_ready() -> void:
	# greet einmal, danach bleibt LUMO im idle_bounce (auto-applied vom
	# LumoCharacterController).
	for node in get_children():
		if node is LumoCharacterController:
			(node as LumoCharacterController).play_behavior("greet")
			break


func _spawn_portals() -> void:
	for entry in PORTAL_LAYOUT:
		var portal: Node3D = PORTAL_SCENE.instantiate() as Node3D
		portal.position = entry["position"]
		if portal.has_method("set_portal_type"):
			portal.call("set_portal_type", entry["type"])
		add_child(portal)


func _spawn_star_field() -> void:
	var stars: Node3D = STAR_FIELD_SCENE.instantiate() as Node3D
	stars.position = Vector3(0.0, 3.5, 0.0)
	# Anzahl je Quality-Profil reduzieren
	var count: int = 40
	if Engine.has_singleton("PerformanceManager"):
		var pm: Node = Engine.get_singleton("PerformanceManager")
		if pm.has_method("get_star_count"):
			count = pm.call("get_star_count")
	if "star_count" in stars:
		stars.set("star_count", count)
	add_child(stars)


## Streut Billboard-Decorations (Kristall/Buch) um die Insel - Anzahl
## abhaengig vom Quality-Profil (LOW=0, MEDIUM=3, HIGH=6).
func _spawn_billboards() -> void:
	var count: int = 3
	if Engine.has_singleton("PerformanceManager"):
		var pm: Node = Engine.get_singleton("PerformanceManager")
		if pm.has_method("get_billboard_count"):
			count = pm.call("get_billboard_count")
	if count <= 0:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1337
	for i in range(count):
		var mat_id: String = BILLBOARD_MATERIAL_IDS[i % BILLBOARD_MATERIAL_IDS.size()]
		var mat: Material = AssetLoader.get_material(mat_id)
		if mat == null:
			continue
		var bb: MeshInstance3D = MeshInstance3D.new()
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.9, 0.9)
		bb.mesh = quad
		bb.material_override = mat
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(3.5, 5.5)
		bb.position = Vector3(cos(angle) * radius, 1.2 + rng.randf() * 0.6, sin(angle) * radius)
		# Y-Billboard damit das Quad zur Kamera schaut
		var st_mat: StandardMaterial3D = mat as StandardMaterial3D
		if st_mat != null:
			st_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(bb)


func _on_portal_selected(portal_type: String) -> void:
	print("portal_%s_selected" % portal_type)
	# Lumo zeigt erst auf das Portal, danach Szenenwechsel via Router.
	for node in get_children():
		if node is LumoCharacterController:
			(node as LumoCharacterController).play_behavior("point_portal")
			break
	# Kurz warten damit der Tap-Pulse + point-Geste sichtbar sind, dann goto.
	var tw: Tween = create_tween()
	tw.tween_interval(0.55)
	tw.tween_callback(func(): SceneRouter.goto(portal_type))
