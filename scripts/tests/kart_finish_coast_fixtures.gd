extends "res://scripts/games/kart_island.gd"

var result_seen := false
var confetti_calls := 0


func _ready() -> void:
	pass


func _update_hud() -> void:
	pass


func _show_result() -> void:
	result_seen = true


func _sound_effect(_kind: String) -> void:
	pass


func _spawn_finish_confetti() -> void:
	confetti_calls += 1
