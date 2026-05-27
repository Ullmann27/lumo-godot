## Globaler Event-Bus (Autoload als 'EventBus').
##
## Lose Knoten-Kopplung: jeder Knoten emittiert ein Signal, jeder
## andere kann es abonnieren - ohne direkte Node-Referenzen. So bleibt
## Boot/Intro/Home/Portal architekturell entkoppelt.
##
## Registriert in project.godot:
##   [autoload]
##   EventBus="*res://scripts/systems/event_bus.gd"
extends Node

# ── App-Lifecycle ─────────────────────────────────────────────────
signal boot_started
signal scene_loaded(scene_name: String)
signal scene_changed(from_id: String, to_id: String)

# ── Asset-Pipeline ────────────────────────────────────────────────
signal asset_loader_ready(model_count: int)
signal assets_load_complete(count: int)
signal asset_instanced(asset_path: String, node: Node)

# ── Performance / Runtime ─────────────────────────────────────────
signal quality_profile_changed(profile_name: String)
signal platform_detected(platform_name: String)

# ── Portal-Interaktion ────────────────────────────────────────────
signal portal_selected(portal_type: String)
signal portal_hovered(portal_type: String, hovered: bool)

# ── Companion ─────────────────────────────────────────────────────
signal companion_ready
signal companion_reaction(reaction: String)

# ── LUMO Character (animiertes Charakter-System) ──────────────────
signal lumo_behavior_started(behavior: String)
signal lumo_behavior_finished(behavior: String)
signal lumo_mouth_shape_changed(shape: String)
signal lumo_eye_state_changed(state: String)
signal lumo_showcase_ready

# ── Legacy (Demo-Cube, falls jemand spaeter so etwas wiederbelebt) ─
signal cube_interacted(intensity: float)
signal rotation_speed_changed(speed_y: float, speed_x: float)


func _ready() -> void:
	print("[EventBus] online - signals registered")
