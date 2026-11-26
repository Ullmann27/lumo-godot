class_name LumoQuality
extends RefCounted
## LumoRenderKit · one quality tier for every Lumo world.
##
## SettingsStore persists the selected tier. Shared environments retain their
## three base budgets, while Kart's scenery and effects also use Sehr hoch.
## Budgets are plain numbers a scene reads; nothing here touches the tree.
## Fold7 values are NOT device-measured yet; they keep today's behaviour.

const TIERS: Array[String] = ["low", "medium", "high"]
const GRAPHICS_CHOICES: Array[String] = ["low", "medium", "high", "ultra"]
const GRAPHICS_LABELS := {
	"low": "Leicht", "medium": "Ausgewogen", "high": "Hoch", "ultra": "Sehr hoch",
}
const BUDGETS: Dictionary = {
	"low":
	{
		"shadows": false,
		"shadow_distance": 0.0,
		"decor_density": 0.35,
		"cloud_count": 14,
		"backdrop_islands": 3,
		"sparkles": 0,
		"camera_far": 260.0,
	},
	"medium":
	{
		"shadows": true,
		"shadow_distance": 45.0,
		"decor_density": 0.7,
		"cloud_count": 30,
		"backdrop_islands": 5,
		"sparkles": 24,
		"camera_far": 340.0,
	},
	"high":
	{
		"shadows": true,
		"shadow_distance": 70.0,
		"decor_density": 1.0,
		"cloud_count": 46,
		"backdrop_islands": 7,
		"sparkles": 48,
		"camera_far": 450.0,
	},
}


static func _performance() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return null
	return loop.root.get_node_or_null("PerformanceManager")


## Active app-wide tier ("low" | "medium" | "high").
static func tier() -> String:
	var performance: Node = _performance()
	if performance != null and performance.has_method("get_profile_name"):
		var name: String = str(performance.call("get_profile_name"))
		if name in TIERS:
			return name
	return "medium"


static func base_tier(name: String) -> String:
	return "high" if name == "ultra" else name


static func graphics_choice() -> String:
	var performance: Node = _performance()
	return str(performance.call("get_graphics_choice")) if performance != null else "medium"


static func set_graphics_choice(name: String, persist: bool = true) -> void:
	var performance: Node = _performance()
	if performance != null and name in GRAPHICS_CHOICES:
		performance.call("set_graphics_choice", name, persist)


## Make a base tier the app-wide choice and persist it.
static func set_tier(name: String) -> void:
	if name in TIERS:
		set_graphics_choice(name)


## Render budget for a tier; an unknown name falls back to the active tier.
static func budget(name: String = "") -> Dictionary:
	var key: String = base_tier(name) if name in GRAPHICS_CHOICES else tier()
	return BUDGETS[key]
