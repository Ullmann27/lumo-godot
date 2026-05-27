## Haupt-Controller fuer Main.tscn.
##
## Verbindet alle Subsysteme ueber den EventBus:
##  - feuert `scene_loaded` nach dem ersten frischen Frame
##  - lauscht auf `assets_load_complete` und logged
##  - lauscht auf `rotation_speed_changed` und logged
##
## Hauptzweck: Demo dass die reaktive Architektur lebt.
extends Node3D


func _ready() -> void:
	EventBus.assets_load_complete.connect(_on_assets_loaded)
	EventBus.rotation_speed_changed.connect(_on_rotation_changed)
	EventBus.asset_instanced.connect(_on_asset_instanced)
	# Warte einen Frame damit Child-Knoten ihre _ready() durch haben.
	await get_tree().process_frame
	EventBus.scene_loaded.emit(name)
	print("[Main] scene_loaded emitted (%s)" % name)


func _on_assets_loaded(count: int) -> void:
	print("[Main] EventBus saw assets_load_complete: %d items" % count)


func _on_rotation_changed(speed_y: float, speed_x: float) -> void:
	print("[Main] rotation_speed_changed -> y=%.2f x=%.2f" % [speed_y, speed_x])


func _on_asset_instanced(path: String, node: Node) -> void:
	print("[Main] asset_instanced -> %s (%s)" % [path, node.name])
