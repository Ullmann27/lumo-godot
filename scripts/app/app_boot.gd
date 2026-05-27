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
	SceneRouter.goto("intro")
