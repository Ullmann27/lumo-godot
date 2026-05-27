## Globaler Event-Bus (Autoload).
##
## Idee: jeder Knoten kann `EventBus.scene_loaded.emit(...)` rufen, jeder
## andere kann `EventBus.scene_loaded.connect(my_handler)` lauschen.
## Ergebnis: keine direkten Knoten-zu-Knoten-Referenzen, lose Kopplung,
## latenzfreie Signal-Pipeline.
##
## Registrierung in project.godot:
##   [autoload]
##   EventBus="*res://scripts/event_bus.gd"
extends Node

## Wird gefeuert sobald die Hauptszene den ersten Frame fertig hat.
signal scene_loaded(scene_name: String)

## Wird gefeuert wenn ein procedurally geladenes Asset im Scene-Tree ist.
signal asset_instanced(asset_path: String, node: Node)

## Wird gefeuert wenn der Asset-Loader alle .glb-Dateien abgeklappert hat.
signal assets_load_complete(count: int)

## Wird gefeuert bei Cube-Interaktion (Tap/Klick) - Demo-Signal.
signal cube_interacted(intensity: float)

## Wird gefeuert wenn der Rotor seine Geschwindigkeit aendert.
signal rotation_speed_changed(speed_y: float, speed_x: float)


func _ready() -> void:
	# Print fuers Smoke-Test-Log damit man sieht, dass der Autoload lief.
	print("[EventBus] online - signals registered")
