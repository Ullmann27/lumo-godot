extends RefCounted
## Gebäude der Siedlung als Blender-Modelle (tools/lumo_village_art).
## Beide Orte nutzen dieselben Modelle; Wohnhäuser haben drei Fassungen.
## Darstellung wählt nie Kosten, Erträge, KI-Züge oder Siegbedingungen.
const KIT = preload("res://scripts/creative/creative_kit.gd")
const ART = preload("res://scripts/creative/build_village_art.gd")
const MODELS := {
	"house": ["house_a", "house_b", "house_c"],
	"farm": ["farm"],
	"lumber": ["lumber"],
	"quarry": ["quarry"],
	"market": ["market"],
	"school": ["school"],
	"well": ["well"],
	"grain": ["grain"],
	"bakery": ["bakery"],
	"road": ["road"],
	"clinic": ["clinic"],
}
const TITLES := {
	"house": "Wohnhaus",
	"farm": "Bauernhof",
	"lumber": "Holzwerkstatt",
	"quarry": "Steinbruch",
	"market": "Markt",
	"school": "Lernhaus",
	"well": "Brunnen",
	"grain": "Kornfeld",
	"bakery": "Bäckerei",
	"road": "Wegeplatz",
	"clinic": "Fürsorgehaus"
}
## Schornsteinköpfe (lokal) für den gebündelten Rauch.
const CHIMNEYS := {
	"house_a": [Vector3(0.9, 4.15, -0.5)],
	"house_b": [Vector3(-1.0, 4.0, -0.4)],
	"house_c": [Vector3(-1.0, 5.65, -0.6), Vector3(1.1, 5.55, 0.5)],
	"bakery": [Vector3(-1.0, 4.65, -0.45)],
	"clinic": [Vector3(1.0, 4.05, -0.5)],
}
const FOOTPRINT := 4.4


static func model_for(kind: String, variant := 0) -> String:
	var choices: Array = MODELS.get(kind, ["house_a"])
	return str(choices[posmod(variant, choices.size())])


static func create(kind: String, opponent := false, variant := 0) -> StaticBody3D:
	var model := model_for(kind, variant)
	var entry = ART.bundle(model)
	var body := StaticBody3D.new()
	body.name = "Facility_" + kind
	body.set_meta("settlement_visual_asset", entry)
	var visual := ART.instance(model)
	visual.name = "Visual"
	body.add_child(visual)
	var size := Vector3(3.6, 3.2, 3.6)
	if entry.aabb.size != Vector3.ZERO:
		var box: AABB = entry.aabb
		size = Vector3(
			minf(box.size.x, FOOTPRINT), clampf(box.end.y, 0.4, 7.0), minf(box.size.z, FOOTPRINT)
		)
	var kit := KIT.new()
	kit.collision(body, Vector3(0, size.y * 0.5, 0), size * 0.96)
	if opponent:
		var flag := kit.box(body, Vector3(-size.x * 0.5 + 0.1, 0.2, size.z * 0.5), Vector3(0.5, 0.06, 0.06), Color("e89b58"))
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sign := Label3D.new()
	sign.name = "FacilitySign"
	sign.text = TITLES.get(kind, kind)
	sign.position = Vector3(0, size.y + 0.55, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 40
	sign.pixel_size = 0.006
	sign.modulate = Color("fff6dd")
	sign.outline_modulate = Color("193b47")
	sign.outline_size = 10
	sign.visibility_range_end = 17
	sign.no_depth_test = false
	body.add_child(sign)
	var spinning: Array[Node3D] = []
	for child in visual.get_children():
		if str(child.name).begins_with("Spin_"):
			spinning.append(child)
	body.set_meta("spin_parts", spinning)
	body.set_meta("chimneys", CHIMNEYS.get(model, []))
	body.set_meta("facility_model", model)
	body.set_meta("facility_kind", kind)
	body.set_meta("opponent", opponent)
	return body


## Baufortschritt: Gerüst steht, das Gebäude wächst aus dem Fundament,
## dann wird das Gerüst abgebaut. Reine Darstellung (kein Spielzustand).
static func animate_construction(body: StaticBody3D, duration := 2.6) -> void:
	var visual := body.get_node_or_null("Visual") as Node3D
	if visual == null or not body.is_inside_tree():
		return
	var scaffold := ART.instance("scaffold") if ART.exists("scaffold") else null
	if scaffold != null:
		scaffold.name = "Scaffold"
		body.add_child(scaffold)
	body.set_meta("under_construction", true)
	visual.scale = Vector3(1.0, 0.04, 1.0)
	var tween := body.create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if scaffold != null:
		tween.tween_property(scaffold, "scale", Vector3(1.0, 0.02, 1.0), 0.45).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(scaffold.queue_free)
	tween.tween_callback(func(): body.set_meta("under_construction", false))
