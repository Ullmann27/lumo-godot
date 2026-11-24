extends Node3D
## PackedScene adapter for the existing part mounting pipeline.
const GEOMETRY = preload("res://scripts/games/kart_evolution_geometry.gd")

func _init() -> void:
    GEOMETRY.populate(self)
