extends "res://scripts/games/kart_items/ext/kart_item_ext_effect.gd"
## STERNEN-DUPLIKAT – das Kart wirft für 6 s eine holografische Kopie neben sich. Gegnerische
## Zielsysteme verlieren das echte Kart: anfliegende Sternraketen biegen zur Kopie ab und
## zerplatzen dort, neue Angriffe (Blitz, Frost, Meteor, Wirbel, Welle, Falle) treffen die Kopie.
## Ein Treffer löst die Kopie auf. Das echte Kart bleibt voll steuerbar und eindeutig erkennbar
## (fest und farbig, die Kopie ist durchscheinend cyan mit wandernden Lichtzeilen).
##   0.00–0.30 s  AUSLÖSER  Lichtblitz am Kart, Kopie gleitet seitlich heraus (2,1 m daneben,
##                          0,8 m dahinter – auf der Seite mit mehr Platz).
##   0.30–6.0 s   WIRKEN    Kopie fährt mit, leicht versetzt pendelnd; Raketen/Angriffe aufs
##                          Kart werden zur Kopie umgelenkt.
##   Treffer      EINSCHLAG Kopie flackert, zerfällt in Lichtsplitter („DUPLIKAT!“).
##   5.4–6.0 s    ABKLINGEN Kopie wird durchsichtiger und erlischt.
## Kein Angriff: Schild/Schonzeit des Besitzers bleiben unberührt; die Kopie fängt höchstens
## einen Treffer. KI setzt sie ein, wenn sie bedroht ist (Raketen-Lock oder Anflug).

const FX = preload("res://scripts/games/kart_items/ext/kart_item_ext_fx.gd")
const HOLO = preload("res://assets/shaders/kart_holo_decoy.gdshader")
const LIFE: float = 6.0
const SLIDE: float = 0.3
const SIDE: float = 2.1
const BACK: float = 0.8
const LURE_RANGE: float = 35.0
const MAX_PARTS: int = 60


func _init() -> void:
	pool_cap = 4


func use(owner: int, item_id: String, _row: Dictionary) -> bool:
	if not _entry_for(owner).is_empty():
		return false
	var wall: float = float(
		host.race._wall_lateral_at(fposmod(host.progress(owner), host.track_length()))
	)
	var side: float = 1.0 if host.lateral(owner) <= 0.0 else -1.0
	if absf(host.lateral(owner) + side * SIDE) > wall - 0.6:
		side = -side
	active.append({"owner": owner, "item": item_id, "age": 0.0, "side": side, "popped": -1.0})
	if owner == -1:
		host.say("Sternen-Duplikat! Raketen jagen jetzt deine Lichtkopie.")
		host.sound("decoy_up")
	elif host.eye().distance_to(host.kart_centre(owner)) < 45.0:
		host.sound("decoy_up", 1.1)
	return true


func rival_wants(index: int, _item_id: String, context: Dictionary) -> bool:
	if bool(context.get("threatened", false)) or host.incoming_for(index) < 2.0:
		return true
	return host.race.lock_target == index and float(host.race.lock_progress) > 0.4


func _entry_for(key: int) -> Dictionary:
	for entry in active:
		if int(entry.owner) == key:
			return entry
	return {}


func has_decoy(key: int) -> bool:
	var entry: Dictionary = _entry_for(key)
	return not entry.is_empty() and float(entry.popped) < 0.0 and float(entry.age) < LIFE


## Weltposition der Kopie (folgt dem echten Kart).
func decoy_position(entry: Dictionary) -> Vector3:
	var key: int = int(entry.owner)
	var slide: float = smoothstep(0.0, 1.0, float(entry.age) / SLIDE)
	var sway: float = 0.0 if host.reduced_motion else sin(float(entry.age) * 1.7) * 0.25
	var lateral: float = host.lateral(key) + float(entry.side) * (SIDE + sway) * slide
	return host.track_global(host.progress(key) - BACK * slide, lateral, 0.03)


func decoy_lateral(entry: Dictionary) -> float:
	return (
		host.lateral(int(entry.owner))
		+ float(entry.side) * SIDE * smoothstep(0.0, 1.0, float(entry.age) / SLIDE)
	)


## Vom Wirt aufgerufen, bevor ein neuer Treffer gilt: die Kopie fängt ihn ab.
func absorb(key: int, _at: Vector3) -> bool:
	if not has_decoy(key):
		return false
	var entry: Dictionary = _entry_for(key)
	entry.popped = float(entry.age)
	stats.absorbed = int(stats.get("absorbed", 0)) + 1
	if host.involves_player(key, key) or host.eye().distance_to(host.kart_centre(key)) < 45.0:
		host.sound("decoy_pop")
	return true


func _valid_saved(entry: Dictionary) -> bool:
	return super._valid_saved(entry) and entry.has("side") and host._valid_key(int(entry.owner))


func tick(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for entry in active:
		entry.age = float(entry.age) + delta
		if has_decoy(int(entry.owner)):
			_lure_rockets(entry)
		var done: bool = (
			float(entry.age) > LIFE
			or (float(entry.popped) >= 0.0 and float(entry.age) > float(entry.popped) + 0.5)
		)
		if done:
			release(entry)
			continue
		var rig: Node3D = acquire(entry)
		if rig != null:
			_draw(entry, rig)
		keep.append(entry)
	active = keep


## Sternraketen, die das Kart jagen, verlieren das Ziel und biegen zur Kopie ab.
func _lure_rockets(entry: Dictionary) -> void:
	var runtime = host.race.item_runtime
	if not is_instance_valid(runtime):
		return
	var key: int = int(entry.owner)
	var decoy_l: float = decoy_lateral(entry)
	var decoy_p: float = host.progress(key) - BACK
	var caught: Dictionary = {}
	for rocket in runtime.projectiles:
		if str(rocket.kind) != "homing":
			continue
		var chasing: bool = int(rocket.target) == key or int(rocket.get("lured_by", -99)) == key
		if not chasing:
			continue
		var gap: float = decoy_p - float(rocket.progress)
		if gap > LURE_RANGE:
			continue
		if int(rocket.target) == key:
			rocket.target = -99
			rocket.lured_by = key
			stats.lured = int(stats.get("lured", 0)) + 1
		rocket.lateral = move_toward(float(rocket.lateral), decoy_l, 9.0 * 1.0 / 60.0)
		if gap < 1.6:
			caught[int(rocket.get("pair", 0))] = rocket
	if caught.is_empty():
		return
	# Das Raketenpaar zerplatzt an der Kopie (gilt als ein Treffer der Kopie).
	var keep: Array[Dictionary] = []
	for rocket in runtime.projectiles:
		if caught.has(int(rocket.get("pair", 0))) and int(rocket.get("lured_by", -99)) == key:
			runtime._retire(rocket, true)
		else:
			keep.append(rocket)
	runtime.projectiles = keep
	host.race._fx("rocket_pop", decoy_position(entry) + Vector3.UP * 0.8)
	absorb(key, decoy_position(entry))
	if key == -1:
		host.say("Die Raketen haben deine Lichtkopie erwischt – du fährst weiter!")


func build_rig() -> Node3D:
	var rig := Node3D.new()
	rig.name = "StarDecoy"
	rig.top_level = true
	var body := Node3D.new()
	body.name = "Body"
	rig.add_child(body)
	var flash: MeshInstance3D = FX.sprite(
		3.0, FX.glow_unique(Color(0.6, 0.95, 1.0, 1.0), true, FX.soft_dot())
	)
	flash.name = "Flash"
	rig.add_child(flash)
	var shard_recipe := {
		"amount": host.budget(44),
		"lifetime": 0.7,
		"size": 0.16,
		"one_shot": true,
		"explosiveness": 0.95,
		"spread": 180.0,
		"speed_min": 2.0,
		"speed_max": 5.0,
		"gravity": Vector3(0, -2, 0),
		"box": Vector3(0.7, 0.4, 0.9),
		"colors": [Color(1, 1, 1, 1), Color(0.4, 0.9, 1.0, 1), Color(0.4, 0.6, 1.0, 0)],
	}
	var shards: CPUParticles3D = FX.emitter(shard_recipe)
	shards.name = "Shards"
	rig.add_child(shards)
	return rig


## Die Kopie entsteht aus den echten Meshes des Karts (inkl. Fahrer), mit Holo-Material.
func _build_copy(rig: Node3D, key: int) -> void:
	var body: Node3D = rig.get_node("Body")
	for child in body.get_children():
		child.queue_free()
	var kart: Node3D = host.kart(key)
	if not is_instance_valid(kart):
		return
	var material := ShaderMaterial.new()
	material.shader = HOLO
	material.set_shader_parameter("time_offset", randf() * 10.0)
	rig.set_meta("material", material)
	var inverse: Transform3D = kart.global_transform.affine_inverse()
	var count: int = 0
	for node in kart.find_children("*", "MeshInstance3D", true, false):
		var source := node as MeshInstance3D
		# Gehäutete Teile (Fahrer-Rig) blieben ohne Skelett in Ruhepose: weglassen.
		if (
			source.mesh == null
			or source.skin != null
			or not source.is_visible_in_tree()
			or count >= MAX_PARTS
		):
			continue
		var aabb: AABB = source.mesh.get_aabb()
		if aabb.size.length() < 0.05:
			continue
		var part := MeshInstance3D.new()
		part.mesh = source.mesh
		part.skeleton = NodePath()
		part.material_override = material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.transform = inverse * source.global_transform
		body.add_child(part)
		count += 1
	rig.set_meta("parts", count)


func reset_rig(rig: Node3D, entry: Dictionary) -> void:
	_build_copy(rig, int(entry.owner))
	rig.set_meta("burst", false)


func _draw(entry: Dictionary, rig: Node3D) -> void:
	var key: int = int(entry.owner)
	var kart: Node3D = host.kart(key)
	if not is_instance_valid(kart):
		return
	var age: float = float(entry.age)
	var at: Vector3 = decoy_position(entry)
	var body: Node3D = rig.get_node("Body")
	var popped: bool = float(entry.popped) >= 0.0
	var fade: float = 1.0 - clampf((age - (LIFE - 0.6)) / 0.6, 0.0, 1.0)
	if popped:
		fade = 1.0 - clampf((age - float(entry.popped)) / 0.25, 0.0, 1.0)
	var slide: float = smoothstep(0.0, 1.0, age / SLIDE)
	rig.global_transform = Transform3D(
		kart.global_basis.orthonormalized(), at - kart.global_basis.y.normalized() * 0.03
	)
	body.position = Vector3.ZERO
	body.scale = Vector3.ONE * (0.92 + 0.08 * slide)
	body.visible = fade > 0.0
	var material: ShaderMaterial = rig.get_meta("material") if rig.has_meta("material") else null
	if material != null:
		material.set_shader_parameter("strength", fade * (0.6 + 0.4 * slide))
		material.set_shader_parameter(
			"flicker", 0.0 if host.reduced_motion else (1.0 if not popped else 4.0)
		)
	var flash: MeshInstance3D = rig.get_node("Flash")
	flash.visible = age < SLIDE + 0.1
	if flash.visible:
		flash.global_position = kart.global_position + kart.global_basis.y.normalized() * 0.8
		(flash.material_override as StandardMaterial3D).albedo_color.a = 1.0 - age / (SLIDE + 0.1)
	if popped and not bool(rig.get_meta("burst", false)):
		rig.set_meta("burst", true)
		FX.burst(rig.get_node("Shards"), at + Vector3.UP * 0.7, Vector3.UP)
		host.race._popup("DUPLIKAT!", at + Vector3.UP * 2.0, Color("2bb8d6"))
