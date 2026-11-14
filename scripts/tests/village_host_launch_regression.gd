extends SceneTree
## A direct Flutter "Dorf & Wirtschaft" request must survive Android -> HostBridge -> Boot.
const BRIDGE = preload("res://scripts/systems/host_bridge.gd")
const BOOT = preload("res://scripts/app/app_boot.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var good := BRIDGE.validated_options({
		"game": "settlement",
		"livingVillage": true,
		"settlementMode": "settlement",
		"grade": 2,
		"subject": "Mathematik",
		"childKey": "child-test",
		"buildSlot": 3
	})
	if good.get("scene", "") != "settlement":
		errors.append("Economic village was silently rerouted away from settlement")
	if good.get("livingVillage", false) != true:
		errors.append("Validated launch lost explicit village request")
	if good.get("childKey") != "child-test" or good.get("grade") != 2:
		errors.append("Original child identity or grade was lost")
	if not BOOT.TITLE_BY_SCENE.has("settlement"):
		errors.append("Android boot does not label this new village scene")
	if not BOOT.COVER_BY_SCENE.has("settlement"):
		errors.append("Village opening lacks a real game cover")
	if not root.get_node("SceneRouter").SCENES.has("settlement"):
		errors.append("SceneRouter lacks the real settlement scene")
	var forbidden := BRIDGE.validated_options({
		"game": "settlement", "livingVillage": false
	})
	if forbidden.get("scene") == "settlement":
		errors.append("Unsupported classic settlement should not be launched from the village portal")
	if not errors.is_empty():
		for item in errors:
			printerr("[VillageHost] FAIL " + item)
		quit(1)
		return
	print("[VillageHost] PASS Flutter village request, native boot scene and child context")
	quit(0)
