extends "res://scripts/games/kart_island.gd"
## Loaded after autoload initialization; delegates the unchanged production atomic writer.
var save_attempts: Array[Dictionary] = []


func _save_session() -> void:
	save_attempts.append({"elapsed": elapsed, "countdown": countdown, "result_id": result_id})
	super._save_session()
