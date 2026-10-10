extends PathFollow3D
## Small animated beacon; path has no CollisionShape3D and never controls a kart.
@export var cycle_seconds: float = 6.0
var reduced_motion: bool = false


func _process(delta: float) -> void:
    if reduced_motion or cycle_seconds <= 0.0:
        return
    progress_ratio = fposmod(progress_ratio + delta / cycle_seconds, 1.0)
