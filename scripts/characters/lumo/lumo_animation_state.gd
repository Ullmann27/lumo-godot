## LumoAnimationState
##
## Zentraler State-Enum/-Map fuer alle Lumo-Verhalten. Wird vom
## BehaviorController benutzt um zu pruefen welche Animation aktiv ist
## und ob ein Wechsel sinnvoll ist.
class_name LumoAnimationState
extends RefCounted

# Alle Pflicht-Animationen aus dem Production-Plan.
const STATES: Array[String] = [
	"idle",
	"idle_bounce",
	"blink",
	"greeting_wave",
	"listen",
	"speak_explain",
	"encourage",
	"celebrate",
	"walk_loop",
	"jump_hop",
	"point_portal",
	"reward_star",
	"turn_left",
	"turn_right",
]

# Animationen die kein State-Wechsel sind sondern Overlay (z.B. Blink
# kann ueber Idle laufen, Mouth-Animation ueberlagert ebenfalls).
const OVERLAY_STATES: Array[String] = ["blink"]

# Loop-Animationen (laufen bis explizit gestoppt).
const LOOP_STATES: Array[String] = ["idle", "idle_bounce", "listen", "walk_loop"]


static func is_valid(state_name: String) -> bool:
	return STATES.has(state_name)


static func is_overlay(state_name: String) -> bool:
	return OVERLAY_STATES.has(state_name)


static func is_loop(state_name: String) -> bool:
	return LOOP_STATES.has(state_name)
