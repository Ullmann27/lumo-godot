## AppBoot - Script auf scenes/app/boot.tscn.
##
## Sehr kurzer Bildschirm der nur die Autoloads aufwacht, ein Hallo
## ausgibt und dann zum Intro routet. Kein 3D, keine Logik.
extends Node


func _ready() -> void:
	EventBus.boot_started.emit()
	print("[Boot] starting...")
	# Warte 1 Frame damit alle Autoloads ihr _ready() durch haben
	# (PerformanceManager braucht das fuer Profile-Apply).
	await get_tree().process_frame
	# Kurzer Splash-Moment damit der User wahrnimmt: App startet
	await get_tree().create_timer(0.5).timeout
	var options: Dictionary = {}
	if OS.has_feature("web"):
		var raw = JavaScriptBridge.eval("JSON.stringify(Object.fromEntries(new URL(window.location.href).searchParams))")
		var parsed = JSON.parse_string(str(raw))
		if parsed is Dictionary:
			options = parsed
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var pair = arg.trim_prefix("--").split("=", true, 1)
			options[pair[0]] = pair[1]
	SceneRouter.launch_options = options
	var target: String = str(options.get("scene", ""))
	SceneRouter.goto(target if target in ["kart", "home"] else "intro")
