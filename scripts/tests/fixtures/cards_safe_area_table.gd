extends "res://scripts/games/cards/cards_table.gd"
## Only platform observations and the external app-return boundary are isolated.
var display_insets := Rect2()
var inset_reads := 0
var return_calls := 0


func _safe_area_insets() -> Rect2:
	inset_reads += 1
	return display_insets


func _get_safe_area_observation() -> Dictionary:
	return _android_safe_area


func _observation_source() -> String:
	return "fixture"


func _leave() -> void:
	# The production Back button still receives a genuine touch and calls this.
	return_calls += 1
