extends "res://scripts/tests/kart_home_experience_regression.gd"
## Run with a real X11 renderer. --baseline captures the unmodified earlier
## Spatial API for comparison; it never supplies Home implementation evidence.
func _initialize() -> void:
	capture = true
	marker = "[KartHomeExperienceCapture]"
	call_deferred("_run")
