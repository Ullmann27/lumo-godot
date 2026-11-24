extends "res://scripts/games/cards/cards_table.gd"
## Nur die Plattformgrenzen sind ersetzt: gemessene Ränder und die Rückkehr zur App.
var display_insets := Rect2()
var inset_reads := 0
var return_calls := 0
var observation: Dictionary = {}


func _safe_area_insets() -> Rect2:
	inset_reads += 1
	return display_insets


func _get_safe_area_observation() -> Dictionary:
	return observation


func _leave() -> void:
	# Der echte Zurück-Knopf wird berührt und landet hier.
	return_calls += 1
